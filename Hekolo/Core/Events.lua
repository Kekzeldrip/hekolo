------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Core/Events.lua - Event handling and update loop
--
-- Registers events for the trackers inspired by TellMeWhen:
--   - UNIT_AURA: drives incremental aura cache updates
--   - SPELL_UPDATE_COOLDOWN: invalidates cooldown cache
--   - SPELL_UPDATE_CHARGES: invalidates charge cache
--   - SPELLS_CHANGED: full cache reset on talent/spec changes
--   - UNIT_SPELL_HASTE: haste changes affect cooldown durations
------------------------------------------------------------------------

local addonName, Hekolo = ...

------------------------------------------------------------------------
-- Event frame
------------------------------------------------------------------------

local EventFrame = CreateFrame("Frame", "HekoloEventFrame", UIParent)
EventFrame:Hide()

local throttle = 0
local UPDATE_INTERVAL = 0.1 -- default, overridden by config

------------------------------------------------------------------------
-- Event handlers
------------------------------------------------------------------------

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            Hekolo:Initialize()
            if Hekolo.Display then
                Hekolo.Display:Init()
            end
            -- Initialize trackers
            if Hekolo.AuraTracker then
                Hekolo.AuraTracker:Initialize()
            end
            if Hekolo.CooldownTracker then
                Hekolo.CooldownTracker:Initialize()
            end
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        Hekolo:UpdateSpec()

    elseif event == "PLAYER_ENTERING_WORLD" then
        Hekolo:UpdateSpec()
        -- Reset tracker caches on world transitions
        if Hekolo.AuraTracker then
            Hekolo.AuraTracker:Reset()
        end
        if Hekolo.CooldownTracker then
            Hekolo.CooldownTracker:Reset()
        end

    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        Hekolo:UpdateSpec()
        if Hekolo.Display then
            Hekolo.Display:UpdateLayout()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        Hekolo.inCombat = true
        if Hekolo.enabled and Hekolo.Display then
            EventFrame:Show() -- start the update loop
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        Hekolo.inCombat = false
        -- Keep running for a brief moment to clear display, then stop
        C_Timer.After(2.0, function()
            if not Hekolo.inCombat then
                EventFrame:Hide()
                if Hekolo.Display then
                    Hekolo.Display:ClearIcons()
                end
            end
        end)

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Force an immediate update when target changes
        throttle = UPDATE_INTERVAL
        -- Refresh target auras via tracker
        if Hekolo.AuraTracker then
            Hekolo.AuraTracker:RefreshUnit("target")
        end

    elseif event == "UNIT_POWER_FREQUENT" then
        local unit = ...
        if unit == "player" then
            throttle = UPDATE_INTERVAL -- trigger update on resource change
        end

    -- Event-driven aura tracking (TellMeWhen-inspired)
    elseif event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if Hekolo.AuraTracker then
            Hekolo.AuraTracker:OnUnitAura(unit, updateInfo)
        end

    -- Event-driven cooldown cache invalidation
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if Hekolo.CooldownTracker then
            Hekolo.CooldownTracker:OnSpellUpdateCooldown()
        end

    elseif event == "SPELL_UPDATE_CHARGES" then
        if Hekolo.CooldownTracker then
            Hekolo.CooldownTracker:OnSpellUpdateCharges()
        end

    elseif event == "SPELLS_CHANGED" then
        if Hekolo.CooldownTracker then
            Hekolo.CooldownTracker:OnSpellsChanged()
        end

    elseif event == "UNIT_SPELL_HASTE" then
        local unit = ...
        if unit == "player" and Hekolo.CooldownTracker then
            Hekolo.CooldownTracker:OnUnitSpellHaste()
        end
    end
end

------------------------------------------------------------------------
-- Update loop: runs during combat to evaluate APL and update display
------------------------------------------------------------------------

local function OnUpdate(self, elapsed)
    throttle = throttle + elapsed
    if throttle < UPDATE_INTERVAL then return end
    throttle = 0

    if not Hekolo.enabled then return end
    if not Hekolo.inCombat then return end

    local apl = Hekolo:GetCurrentAPL()
    if not apl then return end

    -- Snapshot current game state
    Hekolo.State:Snapshot()

    -- Evaluate APL and get recommended actions
    local recommendations = Hekolo.APLEngine:Evaluate(apl, Hekolo.State)

    -- Update display with recommendations
    if Hekolo.Display and recommendations then
        Hekolo.Display:SetRecommendations(recommendations)
    end
end

------------------------------------------------------------------------
-- Register events
------------------------------------------------------------------------

EventFrame:SetScript("OnEvent", OnEvent)
EventFrame:SetScript("OnUpdate", OnUpdate)

EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
EventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
EventFrame:RegisterEvent("UNIT_POWER_FREQUENT")

-- TellMeWhen-inspired event-driven tracking
EventFrame:RegisterEvent("UNIT_AURA")           -- incremental aura updates
EventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN") -- cooldown cache invalidation
EventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")  -- charge cache invalidation
EventFrame:RegisterEvent("SPELLS_CHANGED")        -- cache invalidation on spell changes
