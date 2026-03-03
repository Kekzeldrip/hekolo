------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- UI/Options.lua - Options panel
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.Options = {}

local Options = Hekolo.Options
local optionsFrame = nil

------------------------------------------------------------------------
-- Create the options panel
------------------------------------------------------------------------

function Options:CreatePanel()
    if optionsFrame then return end

    optionsFrame = CreateFrame("Frame", "HekoloOptionsFrame", UIParent, "BackdropTemplate")
    optionsFrame:SetSize(400, 340)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)

    optionsFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    optionsFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    optionsFrame:SetBackdropBorderColor(0.3, 0.7, 0.4, 0.9)

    -- Title
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cFF00CC66Hekolo|r Options")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    local yOffset = -40

    -- Enable/Disable toggle
    local enableCheck = CreateFrame("CheckButton", "HekoloOptEnable", optionsFrame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 16, yOffset)
    enableCheck.text = enableCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableCheck.text:SetPoint("LEFT", enableCheck, "RIGHT", 4, 0)
    enableCheck.text:SetText("Enable Hekolo")
    enableCheck:SetChecked(Hekolo:GetSetting("enabled"))
    enableCheck:SetScript("OnClick", function(self)
        Hekolo.enabled = self:GetChecked()
        Hekolo:SetSetting("enabled", Hekolo.enabled)
    end)
    yOffset = yOffset - 30

    -- Lock display toggle
    local lockCheck = CreateFrame("CheckButton", "HekoloOptLock", optionsFrame, "UICheckButtonTemplate")
    lockCheck:SetPoint("TOPLEFT", 16, yOffset)
    lockCheck.text = lockCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockCheck.text:SetPoint("LEFT", lockCheck, "RIGHT", 4, 0)
    lockCheck.text:SetText("Lock Display Position")
    lockCheck:SetChecked(Hekolo:GetSetting("locked"))
    lockCheck:SetScript("OnClick", function(self)
        Hekolo:SetSetting("locked", self:GetChecked())
        if Hekolo.Display then
            Hekolo.Display:SetMovable(not self:GetChecked())
        end
    end)
    yOffset = yOffset - 30

    -- Debug mode toggle
    local debugCheck = CreateFrame("CheckButton", "HekoloOptDebug", optionsFrame, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", 16, yOffset)
    debugCheck.text = debugCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugCheck.text:SetPoint("LEFT", debugCheck, "RIGHT", 4, 0)
    debugCheck.text:SetText("Debug Mode")
    debugCheck:SetChecked(Hekolo:GetSetting("debug"))
    debugCheck:SetScript("OnClick", function(self)
        Hekolo.debug = self:GetChecked()
        Hekolo:SetSetting("debug", Hekolo.debug)
    end)
    yOffset = yOffset - 40

    -- Scale slider
    local scaleSlider = CreateFrame("Slider", "HekoloOptScale", optionsFrame, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 20, yOffset)
    scaleSlider:SetSize(340, 18)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetValue(Hekolo:GetSetting("scale"))
    scaleSlider.Low:SetText("0.5")
    scaleSlider.High:SetText("2.0")
    scaleSlider.Text:SetText("Scale: " .. string.format("%.1f", Hekolo:GetSetting("scale")))
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        Hekolo:SetSetting("scale", value)
        self.Text:SetText("Scale: " .. string.format("%.1f", value))
    end)
    yOffset = yOffset - 40

    -- Alpha slider
    local alphaSlider = CreateFrame("Slider", "HekoloOptAlpha", optionsFrame, "OptionsSliderTemplate")
    alphaSlider:SetPoint("TOPLEFT", 20, yOffset)
    alphaSlider:SetSize(340, 18)
    alphaSlider:SetMinMaxValues(0.2, 1.0)
    alphaSlider:SetValueStep(0.1)
    alphaSlider:SetObeyStepOnDrag(true)
    alphaSlider:SetValue(Hekolo:GetSetting("alpha"))
    alphaSlider.Low:SetText("0.2")
    alphaSlider.High:SetText("1.0")
    alphaSlider.Text:SetText("Alpha: " .. string.format("%.1f", Hekolo:GetSetting("alpha")))
    alphaSlider:SetScript("OnValueChanged", function(self, value)
        Hekolo:SetSetting("alpha", value)
        self.Text:SetText("Alpha: " .. string.format("%.1f", value))
    end)
    yOffset = yOffset - 40

    -- Icon count slider
    local iconCountSlider = CreateFrame("Slider", "HekoloOptIcons", optionsFrame, "OptionsSliderTemplate")
    iconCountSlider:SetPoint("TOPLEFT", 20, yOffset)
    iconCountSlider:SetSize(340, 18)
    iconCountSlider:SetMinMaxValues(1, 6)
    iconCountSlider:SetValueStep(1)
    iconCountSlider:SetObeyStepOnDrag(true)
    iconCountSlider:SetValue(Hekolo:GetSetting("iconCount"))
    iconCountSlider.Low:SetText("1")
    iconCountSlider.High:SetText("6")
    iconCountSlider.Text:SetText("Icons: " .. Hekolo:GetSetting("iconCount"))
    iconCountSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        Hekolo:SetSetting("iconCount", value)
        self.Text:SetText("Icons: " .. value)
    end)
    yOffset = yOffset - 50

    -- Info text
    local info = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("BOTTOMLEFT", 16, 16)
    info:SetText("|cFF888888Hekolo v" .. Hekolo.version ..
        " | Built for WoW 12.0 (Midnight)|r\n" ..
        "|cFF666666Uses 12.0-compatible APIs: C_Spell, C_UnitAuras, UnitPowerPercent|r")

    optionsFrame:Hide()
end

------------------------------------------------------------------------
-- Toggle options panel
------------------------------------------------------------------------

function Options:Toggle()
    if not optionsFrame then
        self:CreatePanel()
    end

    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        optionsFrame:Show()
    end
end
