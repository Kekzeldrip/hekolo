------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Core/Events.lua - Event handling and update loop
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
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_LOGIN" then
        Hekolo:UpdateSpec()

    elseif event == "PLAYER_ENTERING_WORLD" then
        Hekolo:UpdateSpec()

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

    elseif event == "UNIT_POWER_FREQUENT" then
        local unit = ...
        if unit == "player" then
            throttle = UPDATE_INTERVAL -- trigger update on resource change
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
