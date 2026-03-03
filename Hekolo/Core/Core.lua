------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Core/Core.lua - Addon initialization and global namespace
------------------------------------------------------------------------

-- Create addon namespace
local addonName, Hekolo = ...
_G.Hekolo = Hekolo

Hekolo.version = "1.0.0"
Hekolo.interfaceVersion = 120001

-- Addon state
Hekolo.enabled = true
Hekolo.inCombat = false
Hekolo.playerClass = nil
Hekolo.playerSpec = nil
Hekolo.playerSpecID = nil
Hekolo.playerLevel = 0

-- Registered APLs: specID -> { name, actions (parsed) }
Hekolo.apls = {}

-- Debug mode
Hekolo.debug = false

------------------------------------------------------------------------
-- Utility functions
------------------------------------------------------------------------

function Hekolo:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66Hekolo|r: " .. tostring(msg))
end

function Hekolo:Debug(msg)
    if self.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66Hekolo|r|cFFAAAAFF[D]|r: " .. tostring(msg))
    end
end

function Hekolo:Error(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66Hekolo|r|cFFFF3333[E]|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Initialization
------------------------------------------------------------------------

function Hekolo:Initialize()
    -- Get player info
    local _, englishClass = UnitClass("player")
    self.playerClass = englishClass
    self.playerLevel = UnitLevel("player")

    -- Get current specialization
    self:UpdateSpec()

    -- Initialize saved variables
    if not HekoloDB then
        HekoloDB = {
            enabled = true,
            locked = false,
            scale = 1.0,
            alpha = 1.0,
            iconCount = 4,
            iconSize = 48,
            iconSpacing = 4,
            updateInterval = 0.1,
            debug = false,
            position = nil,
        }
    end

    self.enabled = HekoloDB.enabled
    self.debug = HekoloDB.debug

    self:Print("v" .. self.version .. " loaded. Type /hekolo for options.")
    self:Debug("Player class: " .. tostring(self.playerClass))
    self:Debug("Player spec: " .. tostring(self.playerSpec) .. " (ID: " .. tostring(self.playerSpecID) .. ")")
end

function Hekolo:UpdateSpec()
    local specIndex = GetSpecialization()
    if not specIndex or specIndex <= 0 then
        self:ScheduleSpecRetry()
        return
    end

    -- Primary method: GetSpecializationInfo
    local specID, specName = GetSpecializationInfo(specIndex)
    if specID and specID > 0 and specName then
        self.playerSpecID = specID
        self.playerSpec = specName
        return
    end

    -- Fallback: GetSpecializationInfoForClassID (requires classID)
    if GetSpecializationInfoForClassID then
        local _, _, classID = UnitClass("player")
        if classID then
            specID, specName = GetSpecializationInfoForClassID(classID, specIndex)
            if specID and specID > 0 and specName then
                self.playerSpecID = specID
                self.playerSpec = specName
                return
            end
        end
    end

    -- If still no valid spec, schedule a retry
    self:ScheduleSpecRetry()
end

function Hekolo:ScheduleSpecRetry()
    if self._specRetryTimer then return end -- already scheduled
    if not C_Timer or not C_Timer.After then return end

    self._specRetryTimer = true
    C_Timer.After(1.0, function()
        self._specRetryTimer = nil
        self:UpdateSpec()
        if self.playerSpecID and self.playerSpecID > 0 then
            self:Debug("Spec detected (retry): " .. tostring(self.playerSpec) .. " (ID: " .. tostring(self.playerSpecID) .. ")")
        end
    end)
end

------------------------------------------------------------------------
-- APL registration
------------------------------------------------------------------------

function Hekolo:RegisterAPL(specID, name, aplString)
    if not specID or not aplString then
        self:Error("RegisterAPL: specID and aplString required")
        return
    end

    local parsed = self.APLParser:Parse(aplString)
    if parsed then
        self.apls[specID] = {
            name = name or ("APL for spec " .. specID),
            actions = parsed,
            raw = aplString,
        }
        local listCount = 0
        for _ in pairs(parsed) do listCount = listCount + 1 end
        self:Debug("Registered APL '" .. (name or "unnamed") .. "' for spec " .. specID .. " (" .. listCount .. " action lists)")
    else
        self:Error("Failed to parse APL for spec " .. specID)
    end
end

function Hekolo:GetCurrentAPL()
    if self.playerSpecID and self.apls[self.playerSpecID] then
        return self.apls[self.playerSpecID]
    end
    return nil
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

SLASH_HEKOLO1 = "/hekolo"
SLASH_HEKOLO2 = "/hek"

SlashCmdList["HEKOLO"] = function(msg)
    msg = strtrim(msg):lower()

    if msg == "toggle" or msg == "" then
        Hekolo.enabled = not Hekolo.enabled
        HekoloDB.enabled = Hekolo.enabled
        Hekolo:Print(Hekolo.enabled and "Enabled" or "Disabled")
        if Hekolo.Display then
            if Hekolo.enabled then
                Hekolo.Display:Show()
            else
                Hekolo.Display:Hide()
            end
        end
    elseif msg == "lock" then
        HekoloDB.locked = not HekoloDB.locked
        Hekolo:Print(HekoloDB.locked and "Display locked" or "Display unlocked (drag to move)")
        if Hekolo.Display then
            Hekolo.Display:SetMovable(not HekoloDB.locked)
        end
    elseif msg == "debug" then
        Hekolo.debug = not Hekolo.debug
        HekoloDB.debug = Hekolo.debug
        Hekolo:Print("Debug mode: " .. (Hekolo.debug and "ON" or "OFF"))
    elseif msg == "config" or msg == "options" then
        if Hekolo.Options then
            Hekolo.Options:Toggle()
        end
    elseif msg == "reset" then
        HekoloDB.position = nil
        if Hekolo.Display then
            Hekolo.Display:ResetPosition()
        end
        Hekolo:Print("Display position reset.")
    elseif msg == "help" then
        Hekolo:Print("Commands:")
        Hekolo:Print("  /hekolo - Toggle addon on/off")
        Hekolo:Print("  /hekolo lock - Lock/unlock display position")
        Hekolo:Print("  /hekolo debug - Toggle debug output")
        Hekolo:Print("  /hekolo config - Open options panel")
        Hekolo:Print("  /hekolo reset - Reset display position")
        Hekolo:Print("  /hekolo help - Show this help")
    else
        Hekolo:Print("Unknown command. Type /hekolo help for usage.")
    end
end
