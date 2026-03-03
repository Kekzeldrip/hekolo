------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Specs/Warrior_Fury.lua - Fury Warrior default APL
--
-- Based on SimulationCraft APL for Fury Warrior
-- Simplified for 12.0 API limitations
------------------------------------------------------------------------

local addonName, Hekolo = ...

-- Fury Warrior spec ID: 72
local SPEC_ID = 72

local aplString = [[
# Fury Warrior APL - Hekolo Edition (12.0 compatible)

# Default rotation
actions+=/recklessness,if=cooldown.recklessness.ready&(buff.enrage.up|target.time_to_die<12)
actions+=/avatar,if=buff.recklessness.up|target.time_to_die<20
actions+=/rampage,if=rage>90|buff.enrage.down
actions+=/odyns_fury,if=buff.enrage.up&(spell_targets>1|!buff.recklessness.up)
actions+=/execute,if=target.health.pct<20&buff.enrage.up
actions+=/bloodbath,if=buff.enrage.up&rage<80
actions+=/crushing_blow,if=buff.enrage.up&rage<80
actions+=/bloodthirst,if=buff.enrage.down|rage<80
actions+=/raging_blow,if=buff.enrage.up&rage<90
actions+=/whirlwind,if=spell_targets>1&buff.whirlwind_buff.down
actions+=/rampage,if=rage>80
actions+=/execute,if=target.health.pct<20
actions+=/raging_blow
actions+=/bloodthirst
actions+=/whirlwind,if=spell_targets>1
actions+=/slam,if=rage>60

# AoE
actions.aoe+=/whirlwind,if=buff.whirlwind_buff.down
actions.aoe+=/recklessness,if=cooldown.recklessness.ready
actions.aoe+=/odyns_fury
actions.aoe+=/rampage,if=rage>90|buff.enrage.down
actions.aoe+=/whirlwind
actions.aoe+=/bloodthirst
actions.aoe+=/raging_blow
]]

-- Register on load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        Hekolo:RegisterAPL(SPEC_ID, "Fury Warrior (Default)", aplString)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
