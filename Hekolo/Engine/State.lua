------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Engine/State.lua - Game state snapshot using 12.0-compatible APIs
--
-- NOTE on WoW 12.0 API changes:
--   - UnitHealth/UnitPower return "secret" values in combat
--   - Use UnitHealthPercent/UnitPowerPercent instead (non-secret)
--   - C_Spell.GetSpellCooldown works only for whitelisted spells
--   - C_UnitAuras.GetAuraDataByIndex replaces the old UnitAura/UnitBuff
--   - Many combat log events are restricted
--
-- Aura and cooldown data is now managed by dedicated trackers:
--   - AuraTracker: event-driven aura cache with CDM hooks for
--     accurate combat data (inspired by TellMeWhen)
--   - CooldownTracker: event-driven cooldown cache with
--     SPELL_UPDATE_COOLDOWN/CHARGES invalidation
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.State = {}

local State = Hekolo.State

-- Cached state data (refreshed each snapshot)
State.time = 0
State.gcd_remains = 0
State.gcd_duration = 0
State.health_pct = 100
State.power_pct = 100
State.power_max = 100  -- approximate, may be percentage-based
State.level = 0
State.target_exists = false
State.target_health_pct = 100
State.in_combat = false
State.spell_targets = 1 -- estimated from nameplates

-- Resource snapshots
State.resource = 0      -- current primary resource (percentage)
State.combo_points = 0

-- Buffs: name -> { up, remains, stacks, duration }
State.buffs = {}
-- Debuffs on target: name -> { up, remains, stacks, duration }
State.debuffs = {}
-- Cooldowns: spellName -> { remains, charges, max_charges, duration }
State.cooldowns = {}

------------------------------------------------------------------------
-- Snapshot: capture current game state
------------------------------------------------------------------------

function State:Snapshot()
    self.time = GetTime()
    self.in_combat = Hekolo.inCombat
    self.level = UnitLevel("player")

    -- GCD via the whitelisted dummy spell (61304)
    self:UpdateGCD()

    -- Health (percent-based, 12.0 compatible)
    self:UpdateHealth()

    -- Primary resource (percent-based, 12.0 compatible)
    self:UpdatePower()

    -- Combo points / secondary resource
    self:UpdateComboPoints()

    -- Target info
    self:UpdateTarget()

    -- Buffs and debuffs
    self:UpdateAuras()

    -- Cooldowns
    self:UpdateCooldowns()

    -- Enemy count estimate
    self:UpdateTargetCount()
end

------------------------------------------------------------------------
-- GCD tracking via whitelisted spell 61304
------------------------------------------------------------------------

function State:UpdateGCD()
    local spellCDInfo = C_Spell.GetSpellCooldown(Hekolo.GCD_SPELL_ID)
    if spellCDInfo and spellCDInfo.startTime and spellCDInfo.duration then
        local startTime = spellCDInfo.startTime
        local duration = spellCDInfo.duration
        if startTime > 0 and duration > 0 then
            local remaining = (startTime + duration) - GetTime()
            self.gcd_remains = math.max(0, remaining)
            self.gcd_duration = duration
        else
            self.gcd_remains = 0
            self.gcd_duration = duration > 0 and duration or 1.5
        end
    else
        self.gcd_remains = 0
        self.gcd_duration = 1.5
    end
end

------------------------------------------------------------------------
-- Health (uses UnitHealthPercent - non-secret in 12.0)
------------------------------------------------------------------------

function State:UpdateHealth()
    -- UnitHealthPercent returns a percentage (0-100), not a secret value
    if UnitHealthPercent then
        self.health_pct = UnitHealthPercent("player") or 100
    else
        -- Fallback for testing or if function doesn't exist
        local max = UnitHealthMax("player")
        if max and max > 0 then
            local cur = UnitHealth("player")
            self.health_pct = (cur / max) * 100
        else
            self.health_pct = 100
        end
    end
end

------------------------------------------------------------------------
-- Power (uses UnitPowerPercent - non-secret in 12.0)
------------------------------------------------------------------------

function State:UpdatePower()
    local specID = Hekolo.playerSpecID
    local powerType = specID and Hekolo.SpecPower[specID]

    if powerType then
        if UnitPowerPercent then
            self.power_pct = UnitPowerPercent("player", powerType) or 0
        else
            local max = UnitPowerMax("player", powerType)
            if max and max > 0 then
                local cur = UnitPower("player", powerType)
                self.power_pct = (cur / max) * 100
            else
                self.power_pct = 0
            end
        end
        -- For specs with small max resources, try to get actual values
        -- In 12.0, these may be secret in combat; we use % as fallback
        self.resource = self.power_pct
    else
        self.power_pct = 0
        self.resource = 0
    end
end

------------------------------------------------------------------------
-- Combo points (for rogues, ferals, etc.)
------------------------------------------------------------------------

function State:UpdateComboPoints()
    if GetComboPoints then
        self.combo_points = GetComboPoints("player", "target") or 0
    elseif UnitPower then
        self.combo_points = UnitPower("player", Hekolo.PowerType.ComboPoints) or 0
    else
        self.combo_points = 0
    end
end

------------------------------------------------------------------------
-- Target info
------------------------------------------------------------------------

function State:UpdateTarget()
    self.target_exists = UnitExists("target") and (not UnitIsFriend("player", "target"))

    if self.target_exists then
        if UnitHealthPercent then
            self.target_health_pct = UnitHealthPercent("target") or 100
        else
            local max = UnitHealthMax("target")
            if max and max > 0 then
                local cur = UnitHealth("target")
                self.target_health_pct = (cur / max) * 100
            else
                self.target_health_pct = 100
            end
        end
    else
        self.target_health_pct = 100
    end
end

------------------------------------------------------------------------
-- Aura tracking via AuraTracker (event-driven with CDM hooks)
--
-- The AuraTracker maintains an event-driven cache that is updated
-- incrementally via UNIT_AURA events. It hooks Blizzard's Cooldown
-- Data Manager frames to recover spell identity for secret auras
-- in combat (inspired by TellMeWhen's approach).
------------------------------------------------------------------------

function State:UpdateAuras()
    wipe(self.buffs)
    wipe(self.debuffs)

    local tracker = Hekolo.AuraTracker

    if tracker then
        -- Check for secret state transitions
        tracker:CheckSecrets()

        -- Copy cached player buffs into state
        local playerBuffs = tracker:GetPlayerBuffs()
        if playerBuffs then
            for key, entry in pairs(playerBuffs) do
                if type(entry) == "table" and entry.up then
                    self.buffs[key] = entry
                end
            end
        end

        -- Copy cached target debuffs into state
        if self.target_exists then
            local targetDebuffs = tracker:GetTargetDebuffs()
            if targetDebuffs then
                for key, entry in pairs(targetDebuffs) do
                    if type(entry) == "table" and entry.up then
                        self.debuffs[key] = entry
                    end
                end
            end
        end
    else
        -- Fallback: direct scan if AuraTracker not available
        self:ScanAurasDirect("player", "HELPFUL", self.buffs)
        if self.target_exists then
            self:ScanAurasDirect("target", "HARMFUL|PLAYER", self.debuffs)
        end
    end
end

-- Direct scan fallback (used when AuraTracker is not initialized)
function State:ScanAurasDirect(unit, filter, dest)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local i = 1
        while true do
            local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
            if not auraData then break end

            local name = auraData.name
            local spellId = auraData.spellId
            if name then
                local lowerName = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
                local remaining = 0
                if auraData.expirationTime and auraData.expirationTime > 0 then
                    remaining = math.max(0, auraData.expirationTime - GetTime())
                end

                local entry = {
                    up = true,
                    remains = remaining,
                    stacks = auraData.applications or 1,
                    duration = auraData.duration or 0,
                    spellId = spellId,
                }

                dest[lowerName] = entry
                if spellId then
                    dest[spellId] = entry
                end
            end
            i = i + 1
        end
    elseif UnitBuff or UnitDebuff then
        -- Legacy fallback using UnitBuff/UnitDebuff if available
        local func = filter:find("HELPFUL") and UnitBuff or UnitDebuff
        if not func then return end

        local i = 1
        while true do
            local name, icon, count, _, duration, expirationTime, _, _, _, spellId = func(unit, i, filter)
            if not name then break end

            local lowerName = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
            local remaining = 0
            if expirationTime and expirationTime > 0 then
                remaining = math.max(0, expirationTime - GetTime())
            end

            local entry = {
                up = true,
                remains = remaining,
                stacks = count or 1,
                duration = duration or 0,
                spellId = spellId,
            }

            dest[lowerName] = entry
            if spellId then
                dest[spellId] = entry
            end
            i = i + 1
        end
    end
end

------------------------------------------------------------------------
-- Cooldown tracking via CooldownTracker (event-driven caching)
--
-- The CooldownTracker caches C_Spell.GetSpellCooldown and
-- C_Spell.GetSpellCharges results, invalidating them only on
-- SPELL_UPDATE_COOLDOWN and SPELL_UPDATE_CHARGES events.
-- This avoids redundant API calls and mirrors TellMeWhen's
-- approach for accurate cooldown data in combat.
------------------------------------------------------------------------

function State:UpdateCooldowns()
    wipe(self.cooldowns)

    local specID = Hekolo.playerSpecID
    local spellData = specID and Hekolo.SpellData[specID]
    if not spellData then return end

    for spellName, spellID in pairs(spellData) do
        self:UpdateSpellCooldown(spellName, spellID)
    end
end

function State:UpdateSpellCooldown(spellName, spellID)
    local tracker = Hekolo.CooldownTracker

    local cdInfo, chargeInfo
    if tracker then
        cdInfo = tracker:GetSpellCooldown(spellID)
        chargeInfo = tracker:GetSpellCharges(spellID)
    else
        -- Fallback: direct API call
        cdInfo = C_Spell.GetSpellCooldown(spellID)
        chargeInfo = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(spellID)
    end

    local remains = 0
    local charges = 1
    local maxCharges = 1
    local duration = 0

    if cdInfo then
        local startTime = cdInfo.startTime or 0
        local cdDuration = cdInfo.duration or 0
        if startTime > 0 and cdDuration > 0 then
            remains = math.max(0, (startTime + cdDuration) - GetTime())
        end
        duration = cdDuration
    end

    if chargeInfo then
        charges = chargeInfo.currentCharges or 1
        maxCharges = chargeInfo.maxCharges or 1
        if charges < maxCharges and chargeInfo.cooldownStartTime then
            local chargeRemains = math.max(0, (chargeInfo.cooldownStartTime + (chargeInfo.cooldownDuration or 0)) - GetTime())
            -- If we have charges, the ability is usable even if a charge is recharging
            if charges > 0 then
                remains = 0
            else
                remains = chargeRemains
            end
        end
        duration = chargeInfo.cooldownDuration or duration
    end

    -- Check if this is just the GCD (not a real cooldown)
    if remains > 0 and remains <= self.gcd_remains + 0.05 then
        remains = 0 -- it's just the GCD, not the actual cooldown
    end

    self.cooldowns[spellName] = {
        remains = remains,
        charges = charges,
        max_charges = maxCharges,
        duration = duration,
        ready = remains <= 0,
    }
end

------------------------------------------------------------------------
-- Enemy count estimation (via visible nameplates)
------------------------------------------------------------------------

function State:UpdateTargetCount()
    local count = 0
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if plates then
            for _, plate in ipairs(plates) do
                local unit = plate.namePlateUnitToken
                if unit and UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit) then
                    count = count + 1
                end
            end
        end
    end
    self.spell_targets = math.max(1, count)
end

------------------------------------------------------------------------
-- State query helpers (used by condition evaluator)
------------------------------------------------------------------------

function State:GetBuff(name)
    return self.buffs[name] or { up = false, remains = 0, stacks = 0, duration = 0 }
end

function State:GetDebuff(name)
    return self.debuffs[name] or { up = false, remains = 0, stacks = 0, duration = 0 }
end

function State:GetCooldown(spellName)
    return self.cooldowns[spellName] or { remains = 0, charges = 1, max_charges = 1, duration = 0, ready = true }
end

function State:IsSpellReady(spellName)
    local cd = self:GetCooldown(spellName)
    return cd.ready and self.gcd_remains <= 0
end

function State:IsSpellUsable(spellID)
    if C_Spell and C_Spell.IsSpellUsable then
        return C_Spell.IsSpellUsable(spellID)
    elseif IsUsableSpell then
        return IsUsableSpell(spellID)
    end
    return true -- assume usable if we can't check
end
