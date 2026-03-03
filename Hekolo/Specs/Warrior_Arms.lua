------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Specs/Warrior_Arms.lua - Arms Warrior default APL
--
-- Based on SimulationCraft APL for Arms Warrior
-- Simplified for 12.0 API limitations
------------------------------------------------------------------------

local addonName, Hekolo = ...

-- Arms Warrior spec ID: 71
local SPEC_ID = 71

local aplString = [[
# Arms Warrior APL - Hekolo Edition (12.0 compatible)

# Default rotation
actions+=/avatar,if=cooldown.colossus_smash.remains<3|buff.test_of_might.up
actions+=/sweeping_strikes,if=spell_targets>1
actions+=/colossus_smash,if=debuff.colossus_smash.down
actions+=/warbreaker,if=debuff.colossus_smash.down&spell_targets>1
actions+=/thunderclap,if=spell_targets>2&dot.rend.remains<2
actions+=/rend,if=dot.rend.remains<4&target.time_to_die>8
actions+=/skullsplitter,if=rage<60
actions+=/overpower,if=buff.overpower.stack<2
actions+=/mortal_strike,if=debuff.colossus_smash.up|buff.sudden_death.up|dot.deep_wounds.remains<2
actions+=/execute,if=target.health.pct<20|buff.sudden_death.up
actions+=/thunderclap,if=spell_targets>1&dot.rend.remains<4
actions+=/overpower
actions+=/whirlwind,if=spell_targets>1&rage>60
actions+=/slam,if=rage>50
actions+=/bladestorm,if=spell_targets>2|debuff.colossus_smash.up

# Cleave rotation (called when 2+ targets)
actions.cleave+=/sweeping_strikes,if=!buff.sweeping_strikes.up
actions.cleave+=/warbreaker,if=debuff.colossus_smash.down
actions.cleave+=/bladestorm,if=spell_targets>2
actions.cleave+=/cleave,if=!dot.deep_wounds.up
actions.cleave+=/whirlwind,if=spell_targets>2&rage>40
actions.cleave+=/mortal_strike,if=debuff.colossus_smash.up|buff.sweeping_strikes.up
actions.cleave+=/overpower
actions.cleave+=/slam
]]

-- Register on load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        Hekolo:RegisterAPL(SPEC_ID, "Arms Warrior (Default)", aplString)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
