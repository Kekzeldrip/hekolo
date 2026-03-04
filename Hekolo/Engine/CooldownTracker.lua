------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Engine/CooldownTracker.lua - Event-driven cooldown caching
--
-- Inspired by TellMeWhen's approach:
--   - Caches cooldown data and invalidates on SPELL_UPDATE_COOLDOWN
--   - Caches charge data and invalidates on SPELL_UPDATE_CHARGES
--   - Listens to UNIT_SPELL_HASTE for haste-affected cooldowns
--   - Uses C_Spell.GetSpellCooldown / C_Spell.GetSpellCharges
--   - Handles secret values gracefully
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.CooldownTracker = {}

local CooldownTracker = Hekolo.CooldownTracker

------------------------------------------------------------------------
-- Internal state
------------------------------------------------------------------------

-- Cached cooldown data: spellID -> { startTime, duration, modRate }
local cooldownCache = {}

-- Cached charge data: spellID -> { currentCharges, maxCharges, ... }
local chargeCache = {}

-- Whether caches are stale and need refresh on next query
local cooldownsDirty = true
local chargesDirty = true

------------------------------------------------------------------------
-- Helper: detect if a value is a secret value (WoW 12.0)
------------------------------------------------------------------------

local function isSecretValue(value)
    if issecretvalue then
        return issecretvalue(value)
    end
    return false
end

------------------------------------------------------------------------
-- Get cooldown info for a spell (with caching)
------------------------------------------------------------------------

function CooldownTracker:GetSpellCooldown(spellID)
    if not C_Spell or not C_Spell.GetSpellCooldown then
        return nil
    end

    -- If caches are dirty, wipe them; individual entries will be re-fetched
    if cooldownsDirty then
        wipe(cooldownCache)
        cooldownsDirty = false
    end

    local cached = cooldownCache[spellID]
    if cached ~= nil then
        if cached == false then return nil end

        -- Check if the cached cooldown has elapsed
        local duration = cached.duration
        if not isSecretValue(duration) and duration ~= 0 then
            local elapsed = GetTime() - cached.startTime
            if elapsed >= duration then
                -- Cooldown has expired, discard cache entry
                cooldownCache[spellID] = nil
            else
                return cached
            end
        else
            return cached
        end
    end

    local cdInfo = C_Spell.GetSpellCooldown(spellID)
    cooldownCache[spellID] = cdInfo or false
    return cdInfo
end

------------------------------------------------------------------------
-- Get charge info for a spell (with caching)
------------------------------------------------------------------------

function CooldownTracker:GetSpellCharges(spellID)
    if not C_Spell or not C_Spell.GetSpellCharges then
        return nil
    end

    -- If caches are dirty, wipe them
    if chargesDirty then
        wipe(chargeCache)
        chargesDirty = false
    end

    local cached = chargeCache[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    chargeCache[spellID] = chargeInfo or false
    return chargeInfo
end

------------------------------------------------------------------------
-- Event handlers: invalidate caches when game reports changes
------------------------------------------------------------------------

function CooldownTracker:OnSpellUpdateCooldown()
    cooldownsDirty = true
    -- Also invalidate charges; sometimes charge events don't fire
    chargesDirty = true
end

function CooldownTracker:OnSpellUpdateCharges()
    chargesDirty = true
end

function CooldownTracker:OnSpellsChanged()
    -- Spells may have been learned/unlearned (e.g., PvP talents)
    cooldownsDirty = true
    chargesDirty = true
end

function CooldownTracker:OnUnitSpellHaste()
    -- Haste changes affect cooldown durations but don't always fire
    -- SPELL_UPDATE_COOLDOWN
    cooldownsDirty = true
    chargesDirty = true
end

------------------------------------------------------------------------
-- Reset all cached data
------------------------------------------------------------------------

function CooldownTracker:Reset()
    wipe(cooldownCache)
    wipe(chargeCache)
    cooldownsDirty = true
    chargesDirty = true
end

------------------------------------------------------------------------
-- Initialize (no-op for now; events registered in Events.lua)
------------------------------------------------------------------------

function CooldownTracker:Initialize()
    self:Reset()
end
