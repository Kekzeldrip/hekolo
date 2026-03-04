------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Engine/AuraTracker.lua - Event-driven aura tracking with CDM hooks
--
-- Inspired by TellMeWhen's approach to accurate combat data:
--   - Hooks Blizzard's Cooldown Data Manager (CDM) viewer frames
--     to recover spell identity for secret auras
--   - Uses C_UnitAuras.IsAuraFilteredOutByInstanceID to determine
--     aura ownership and type when fields are secret
--   - Event-driven via UNIT_AURA for incremental updates
--   - Handles C_Secrets.ShouldAurasBeSecret for 12.0 secret states
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.AuraTracker = {}

local AuraTracker = Hekolo.AuraTracker

------------------------------------------------------------------------
-- Internal state
------------------------------------------------------------------------

-- Aura cache: unit -> { [spellId|lowerName] -> aura entry }
local auraCache = {
    player = {},
    target = {},
}

-- CDM data: maps unit -> auraInstanceID -> { spellId, name, filter }
local cdmData = {
    player = {},
    target = {},
}

-- Track whether CDM frames have been hooked
local cdmHooked = false

-- Track hooked frames to avoid double-hooking
local hookedFrames = {}

-- Whether secrets are currently active
local secretsActive = false

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
-- Helper: check if auras should currently be secret
------------------------------------------------------------------------

local function shouldAurasBeSecret()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        return C_Secrets.ShouldAurasBeSecret()
    end
    return false
end

------------------------------------------------------------------------
-- CDM (Cooldown Data Manager) frame hooks
--
-- Blizzard's built-in cooldown viewer frames display buff/debuff data
-- using non-secret spell IDs. By hooking SetAuraInstanceInfo on these
-- frames, we can recover the identity of secret auras.
------------------------------------------------------------------------

local function GetViewerItemSpellId(frame)
    if not frame.cooldownInfo or not frame.cooldownID then
        return nil
    end

    local cooldownInfo = frame.cooldownInfo
    local spellID = cooldownInfo.spellID

    -- linkedSpellIDs maps passive talents to their actual buff spells
    if cooldownInfo.linkedSpellIDs and cooldownInfo.linkedSpellIDs[1] then
        spellID = cooldownInfo.linkedSpellIDs[1]
    end

    return spellID
end

local function HookCDMFrame(viewer, frame)
    if not frame.SetAuraInstanceInfo or hookedFrames[frame] then
        return
    end

    hookedFrames[frame] = true

    hooksecurefunc(frame, "SetAuraInstanceInfo", function(self, cdmAuraInstance)
        local spellID = GetViewerItemSpellId(self)
        if not spellID then return end

        local auraInstanceID = cdmAuraInstance.auraInstanceID
        local unit = self.auraDataUnit
        if not unit or not cdmData[unit] then return end

        local existing = cdmData[unit][auraInstanceID]
        if existing and existing.spellId == spellID then
            return -- Already up to date
        end

        local spellName
        if C_Spell and C_Spell.GetSpellName then
            spellName = C_Spell.GetSpellName(spellID)
        elseif GetSpellInfo then
            spellName = GetSpellInfo(spellID)
        end

        cdmData[unit][auraInstanceID] = {
            spellId = spellID,
            name = spellName or "",
            filter = "PLAYER|INCLUDE_NAME_PLATE_ONLY|" ..
                     (unit == "player" and "HELPFUL" or "HARMFUL"),
        }

        -- Trigger a cache refresh for this unit
        AuraTracker:RefreshUnit(unit)
    end)
end

local function HookCDMViewers()
    if cdmHooked then return end

    local viewers = {
        EssentialCooldownViewer,
        BuffIconCooldownViewer,
        BuffBarCooldownViewer,
        UtilityCooldownViewer,
    }

    for i = #viewers, 1, -1 do
        if not viewers[i] then
            table.remove(viewers, i)
        end
    end

    if #viewers == 0 then return end

    for _, viewer in ipairs(viewers) do
        if viewer.OnAcquireItemFrame then
            hooksecurefunc(viewer, "OnAcquireItemFrame", HookCDMFrame)
        end

        -- Hook existing child frames
        if viewer.GetChildren then
            local children = { viewer:GetChildren() }
            for _, frame in ipairs(children) do
                HookCDMFrame(viewer, frame)
            end
        end
    end

    cdmHooked = true
end

------------------------------------------------------------------------
-- Augment an aura instance with CDM data when fields are secret
------------------------------------------------------------------------

local function AugmentAuraInstance(unit, auraData)
    if not auraData then return auraData end

    -- If expirationTime is not secret, aura data is fully available
    if not isSecretValue(auraData.expirationTime or 0) then
        return auraData
    end

    -- Try to recover identity from CDM data
    local instanceID = auraData.auraInstanceID
    if instanceID and cdmData[unit] and cdmData[unit][instanceID] then
        local cdm = cdmData[unit][instanceID]

        -- Verify the CDM data still matches this aura using filter check
        local valid = true
        if unit ~= "player" and C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID then
            valid = not C_UnitAuras.IsAuraFilteredOutByInstanceID(
                unit, instanceID, cdm.filter
            )
        end

        if valid then
            auraData.spellId = cdm.spellId
            auraData.name = cdm.name
            auraData.sourceUnit = "player"
        end
    end

    -- Use IsAuraFilteredOutByInstanceID to determine aura properties
    if C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID and instanceID then
        local isHelpful = not C_UnitAuras.IsAuraFilteredOutByInstanceID(
            unit, instanceID, "HELPFUL|INCLUDE_NAME_PLATE_ONLY"
        )
        auraData.isHelpful = isHelpful
        auraData.isHarmful = not isHelpful

        -- Check if this is the player's own aura
        local filter = "PLAYER|INCLUDE_NAME_PLATE_ONLY" ..
                       (isHelpful and "|HELPFUL" or "|HARMFUL")
        auraData.isMine = not C_UnitAuras.IsAuraFilteredOutByInstanceID(
            unit, instanceID, filter
        )
    end

    return auraData
end

------------------------------------------------------------------------
-- Scan all auras for a unit and populate cache
------------------------------------------------------------------------

local function ScanUnit(unit, filter, dest)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return
    end

    local i = 1
    while true do
        local auraData = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not auraData then break end

        -- Augment with CDM data if fields are secret
        auraData = AugmentAuraInstance(unit, auraData)

        local name = auraData.name
        local spellId = auraData.spellId

        if name and not isSecretValue(name) then
            local lowerName = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
            local remaining = 0
            local expirationTime = auraData.expirationTime

            if expirationTime and not isSecretValue(expirationTime)
               and expirationTime > 0 then
                remaining = math.max(0, expirationTime - GetTime())
            elseif expirationTime and isSecretValue(expirationTime) then
                -- For secret expiration times, use duration as estimate
                -- if we know the aura is active
                remaining = auraData.duration or 0
            end

            local duration = auraData.duration
            if isSecretValue(duration) then
                duration = 0
            end

            local stacks = auraData.applications
            if not stacks or isSecretValue(stacks) then
                stacks = 1
            end

            local entry = {
                up = true,
                remains = remaining,
                stacks = stacks,
                duration = duration or 0,
                spellId = spellId,
                auraInstanceID = auraData.auraInstanceID,
            }

            dest[lowerName] = entry
            if spellId and not isSecretValue(spellId) then
                dest[spellId] = entry
            end
        end

        i = i + 1
    end
end

------------------------------------------------------------------------
-- Refresh aura cache for a specific unit
------------------------------------------------------------------------

function AuraTracker:RefreshUnit(unit)
    if unit == "player" then
        wipe(auraCache.player)
        ScanUnit("player", "HELPFUL", auraCache.player)
    elseif unit == "target" then
        wipe(auraCache.target)
        if UnitExists("target") and not UnitIsFriend("player", "target") then
            ScanUnit("target", "HARMFUL|PLAYER", auraCache.target)
        end
    end
end

------------------------------------------------------------------------
-- Get cached auras (called from State.lua)
------------------------------------------------------------------------

function AuraTracker:GetPlayerBuffs()
    return auraCache.player
end

function AuraTracker:GetTargetDebuffs()
    return auraCache.target
end

------------------------------------------------------------------------
-- Process UNIT_AURA event with incremental update info
------------------------------------------------------------------------

function AuraTracker:OnUnitAura(unit, updateInfo)
    if unit ~= "player" and unit ~= "target" then return end

    -- Full update or no update info: rescan everything
    if not updateInfo or updateInfo.isFullUpdate then
        self:RefreshUnit(unit)
        return
    end

    -- Incremental update: handle added, updated, removed auras
    local cache = (unit == "player") and auraCache.player or auraCache.target
    local filter = (unit == "player") and "HELPFUL" or "HARMFUL|PLAYER"
    local needsFullRefresh = false

    -- Handle removed auras
    if updateInfo.removedAuraInstanceIDs then
        for _, instanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
            -- Remove from cache by finding entries with this instanceID
            for key, entry in pairs(cache) do
                if entry.auraInstanceID == instanceID then
                    cache[key] = nil
                end
            end
            -- Clean up CDM data
            if cdmData[unit] then
                cdmData[unit][instanceID] = nil
            end
        end
    end

    -- Handle added auras
    if updateInfo.addedAuras then
        for _, auraData in ipairs(updateInfo.addedAuras) do
            auraData = AugmentAuraInstance(unit, auraData)
            local name = auraData.name
            local spellId = auraData.spellId

            if name and not isSecretValue(name) then
                local lowerName = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
                local remaining = 0
                local expirationTime = auraData.expirationTime

                if expirationTime and not isSecretValue(expirationTime)
                   and expirationTime > 0 then
                    remaining = math.max(0, expirationTime - GetTime())
                elseif expirationTime and isSecretValue(expirationTime) then
                    remaining = auraData.duration or 0
                end

                local duration = auraData.duration
                if isSecretValue(duration) then duration = 0 end

                local stacks = auraData.applications
                if not stacks or isSecretValue(stacks) then stacks = 1 end

                local entry = {
                    up = true,
                    remains = remaining,
                    stacks = stacks,
                    duration = duration or 0,
                    spellId = spellId,
                    auraInstanceID = auraData.auraInstanceID,
                }

                cache[lowerName] = entry
                if spellId and not isSecretValue(spellId) then
                    cache[spellId] = entry
                end
            end
        end
    end

    -- Handle updated auras
    if updateInfo.updatedAuraInstanceIDs then
        for _, instanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
            -- Re-fetch the aura data for this instance
            if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
                local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, instanceID)
                if auraData then
                    auraData = AugmentAuraInstance(unit, auraData)
                    local name = auraData.name
                    local spellId = auraData.spellId

                    if name and not isSecretValue(name) then
                        local lowerName = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
                        local remaining = 0
                        local expirationTime = auraData.expirationTime

                        if expirationTime and not isSecretValue(expirationTime)
                           and expirationTime > 0 then
                            remaining = math.max(0, expirationTime - GetTime())
                        elseif expirationTime and isSecretValue(expirationTime) then
                            remaining = auraData.duration or 0
                        end

                        local duration = auraData.duration
                        if isSecretValue(duration) then duration = 0 end

                        local stacks = auraData.applications
                        if not stacks or isSecretValue(stacks) then stacks = 1 end

                        local entry = {
                            up = true,
                            remains = remaining,
                            stacks = stacks,
                            duration = duration or 0,
                            spellId = spellId,
                            auraInstanceID = instanceID,
                        }

                        cache[lowerName] = entry
                        if spellId and not isSecretValue(spellId) then
                            cache[spellId] = entry
                        end
                    end
                end
            else
                -- Cannot do incremental update without this API
                needsFullRefresh = true
            end
        end
    end

    if needsFullRefresh then
        self:RefreshUnit(unit)
    end
end

------------------------------------------------------------------------
-- Handle secrets state change (check periodically)
------------------------------------------------------------------------

function AuraTracker:CheckSecrets()
    local nowSecret = shouldAurasBeSecret()
    if nowSecret ~= secretsActive then
        secretsActive = nowSecret
        if not secretsActive then
            -- Secrets just ended: refresh all aura data
            self:RefreshUnit("player")
            self:RefreshUnit("target")
        end
    end
end

------------------------------------------------------------------------
-- Initialize CDM hooks and aura tracking
------------------------------------------------------------------------

function AuraTracker:Initialize()
    -- Attempt to hook CDM viewer frames for spell identity recovery
    -- Wrapped in pcall since these frames may not exist in all environments
    pcall(HookCDMViewers)

    -- Initial aura scan
    self:RefreshUnit("player")
    self:RefreshUnit("target")
end

------------------------------------------------------------------------
-- Reset all cached data (e.g., on PLAYER_ENTERING_WORLD)
------------------------------------------------------------------------

function AuraTracker:Reset()
    wipe(auraCache.player)
    wipe(auraCache.target)
    wipe(cdmData.player)
    wipe(cdmData.target)
end
