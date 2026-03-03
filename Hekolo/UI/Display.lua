------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- UI/Display.lua - Main visual display for ability recommendations
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.Display = {}

local Display = Hekolo.Display

-- Frame references
local mainFrame = nil
local iconFrames = {}

------------------------------------------------------------------------
-- Initialize the display
------------------------------------------------------------------------

function Display:Init()
    if mainFrame then return end -- already initialized

    local iconSize = Hekolo:GetSetting("iconSize")
    local iconCount = Hekolo:GetSetting("iconCount")
    local iconSpacing = Hekolo:GetSetting("iconSpacing")
    local scale = Hekolo:GetSetting("scale")

    -- Main container frame
    mainFrame = CreateFrame("Frame", "HekoloDisplayFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(
        (iconSize * iconCount) + (iconSpacing * (iconCount - 1)) + 8,
        iconSize + 8
    )
    mainFrame:SetScale(scale)

    -- Position
    local pos = Hekolo:GetSetting("position")
    if pos then
        mainFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    end

    -- Background (BackdropTemplate is required in modern WoW)
    if mainFrame.SetBackdrop then
        mainFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        mainFrame:SetBackdropColor(0, 0, 0, 0.6)
        mainFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    end

    -- Make movable when unlocked
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self)
        if not Hekolo:GetSetting("locked") then
            self:StartMoving()
        end
    end)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relPoint, x, y = self:GetPoint()
        Hekolo:SetSetting("position", {
            point = point,
            relPoint = relPoint,
            x = x,
            y = y,
        })
    end)

    -- Tooltip on hover
    mainFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Hekolo", 0, 0.8, 0.4)
        GameTooltip:AddLine("Drag to move (when unlocked)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("/hekolo lock - toggle lock", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    mainFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Create icon frames
    self:CreateIcons(iconCount, iconSize, iconSpacing)

    -- Set frame strata high enough to be visible
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetFrameLevel(10)

    -- Initially hidden until combat
    if Hekolo.enabled then
        mainFrame:Show()
    else
        mainFrame:Hide()
    end

    self:ClearIcons()
end

------------------------------------------------------------------------
-- Create ability icon frames
------------------------------------------------------------------------

function Display:CreateIcons(count, size, spacing)
    for i = 1, count do
        local frame = CreateFrame("Frame", "HekoloIcon" .. i, mainFrame)
        frame:SetSize(size, size)

        if i == 1 then
            frame:SetPoint("LEFT", mainFrame, "LEFT", 4, 0)
        else
            frame:SetPoint("LEFT", iconFrames[i - 1], "RIGHT", spacing, 0)
        end

        -- Icon texture
        frame.icon = frame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetAllPoints()
        frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim borders

        -- Border highlight (brighter for first icon)
        frame.border = frame:CreateTexture(nil, "OVERLAY")
        frame.border:SetPoint("TOPLEFT", -1, 1)
        frame.border:SetPoint("BOTTOMRIGHT", 1, -1)
        frame.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        frame.border:SetBlendMode("ADD")
        if i == 1 then
            frame.border:SetVertexColor(0.2, 0.8, 0.2, 0.8) -- green glow for primary
        else
            frame.border:SetVertexColor(0.4, 0.4, 0.4, 0.4)
        end

        -- Cooldown overlay (for showing GCD or cooldown spin)
        frame.cooldown = CreateFrame("Cooldown", "HekoloIconCD" .. i, frame, "CooldownFrameTemplate")
        frame.cooldown:SetAllPoints()
        frame.cooldown:SetDrawEdge(false)

        -- Keybind text (small overlay)
        frame.keybind = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        frame.keybind:SetPoint("TOPRIGHT", -2, -2)
        frame.keybind:SetText("")

        -- Queue position number
        frame.queueNum = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        frame.queueNum:SetPoint("BOTTOMLEFT", 2, 2)
        frame.queueNum:SetText(tostring(i))
        frame.queueNum:SetTextColor(0.7, 0.7, 0.7, 0.6)

        -- Scale: first icon larger
        if i == 1 then
            local scale = 1.2
            frame:SetSize(size * scale, size * scale)
        end

        frame:Hide()
        iconFrames[i] = frame
    end
end

------------------------------------------------------------------------
-- Set recommendations (called from engine)
------------------------------------------------------------------------

function Display:SetRecommendations(recommendations)
    if not mainFrame then return end
    if not recommendations or #recommendations == 0 then
        self:ClearIcons()
        return
    end

    local count = Hekolo:GetSetting("iconCount")

    for i = 1, count do
        local frame = iconFrames[i]
        if not frame then break end

        local rec = recommendations[i]
        if rec then
            frame.icon:SetTexture(rec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            frame:Show()

            -- Tooltip
            frame.spellID = rec.spellID
            frame:EnableMouse(true)
            frame:SetScript("OnEnter", function(self)
                if self.spellID then
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetSpellByID(self.spellID)
                    GameTooltip:Show()
                end
            end)
            frame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        else
            frame.icon:SetTexture(nil)
            frame:Hide()
        end
    end

    mainFrame:SetAlpha(Hekolo:GetSetting("alpha"))
end

------------------------------------------------------------------------
-- Clear all icons
------------------------------------------------------------------------

function Display:ClearIcons()
    for _, frame in ipairs(iconFrames) do
        frame.icon:SetTexture(nil)
        frame:Hide()
    end
    if mainFrame then
        mainFrame:SetAlpha(0.3)
    end
end

------------------------------------------------------------------------
-- Show/Hide
------------------------------------------------------------------------

function Display:Show()
    if mainFrame then mainFrame:Show() end
end

function Display:Hide()
    if mainFrame then mainFrame:Hide() end
end

------------------------------------------------------------------------
-- Update layout (on spec change, etc.)
------------------------------------------------------------------------

function Display:UpdateLayout()
    self:ClearIcons()
end

------------------------------------------------------------------------
-- Reset position
------------------------------------------------------------------------

function Display:ResetPosition()
    if mainFrame then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
        Hekolo:SetSetting("position", nil)
    end
end

------------------------------------------------------------------------
-- Set movable state
------------------------------------------------------------------------

function Display:SetMovable(movable)
    if mainFrame then
        mainFrame:SetMovable(movable)
    end
end
