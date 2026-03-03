------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Core/Config.lua - Default configuration values
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.defaults = {
    enabled = true,
    locked = false,
    scale = 1.0,
    alpha = 1.0,
    iconCount = 4,        -- how many ability suggestions to show
    iconSize = 48,        -- pixel size per icon
    iconSpacing = 4,      -- gap between icons
    updateInterval = 0.1, -- seconds between APL re-evaluations
    debug = false,
    position = nil,       -- { point, relPoint, x, y }
}

function Hekolo:GetSetting(key)
    if HekoloDB and HekoloDB[key] ~= nil then
        return HekoloDB[key]
    end
    return self.defaults[key]
end

function Hekolo:SetSetting(key, value)
    if not HekoloDB then HekoloDB = {} end
    HekoloDB[key] = value
end
