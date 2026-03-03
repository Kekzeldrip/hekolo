------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Specs/Shaman_Enhancement.lua - Enhancement Shaman default APL
--
-- Based on SimulationCraft APL for Enhancement Shaman
-- Simplified for 12.0 API limitations
------------------------------------------------------------------------

local addonName, Hekolo = ...

-- Enhancement Shaman spec ID: 263
local SPEC_ID = 263

local aplString = [[
# Enhancement Shaman APL - Hekolo Edition (12.0 compatible)

# Precombat
actions.precombat+=/windfury_weapon
actions.precombat+=/flametongue_weapon
actions.precombat+=/lightning_shield

# Default rotation
actions+=/auto_attack
actions+=/call_action_list,name=single_sb,if=spell_targets<=1&!buff.whirling_fire.up
actions+=/call_action_list,name=single_totemic,if=spell_targets<=1&buff.whirling_fire.up
actions+=/call_action_list,name=aoe,if=spell_targets>1

# AoE rotation
actions.aoe+=/voltaic_blaze,if=buff.voltaic_blaze.up
actions.aoe+=/surging_totem,if=!totem.surging_totem.active
actions.aoe+=/ascendance,if=!buff.ascendance_buff.up
actions.aoe+=/call_action_list,name=cooldowns
actions.aoe+=/sundering
actions.aoe+=/lava_lash,if=buff.whirling_fire.up
actions.aoe+=/doom_winds,if=!buff.doom_winds_buff.up
actions.aoe+=/crash_lightning
actions.aoe+=/windstrike,if=buff.ascendance_buff.up
actions.aoe+=/stormstrike
actions.aoe+=/tempest,if=buff.maelstrom_weapon.stack>=5
actions.aoe+=/primordial_storm,if=buff.primordial_storm_buff.up
actions.aoe+=/chain_lightning,if=buff.maelstrom_weapon.stack>=5

# Cooldowns
actions.cooldowns+=/potion
actions.cooldowns+=/blood_fury
actions.cooldowns+=/berserking
actions.cooldowns+=/fireblood
actions.cooldowns+=/ancestral_call

# Single target - Stormbringer
actions.single_sb+=/primordial_storm,if=buff.primordial_storm_buff.up
actions.single_sb+=/voltaic_blaze,if=buff.voltaic_blaze.up
actions.single_sb+=/lava_lash,if=buff.hot_hand.up
actions.single_sb+=/call_action_list,name=cooldowns
actions.single_sb+=/sundering
actions.single_sb+=/doom_winds,if=!buff.doom_winds_buff.up
actions.single_sb+=/crash_lightning,if=buff.crash_lightning_buff.up
actions.single_sb+=/windstrike,if=buff.ascendance_buff.up
actions.single_sb+=/ascendance,if=!buff.ascendance_buff.up
actions.single_sb+=/stormstrike
actions.single_sb+=/tempest,if=buff.maelstrom_weapon.stack>=5
actions.single_sb+=/lightning_bolt,if=buff.maelstrom_weapon.stack>=5
actions.single_sb+=/lava_lash
actions.single_sb+=/stormstrike
actions.single_sb+=/voltaic_blaze
actions.single_sb+=/sundering
actions.single_sb+=/lightning_bolt,if=buff.maelstrom_weapon.stack>=5
actions.single_sb+=/crash_lightning

# Single target - Totemic
actions.single_totemic+=/voltaic_blaze,if=buff.voltaic_blaze.up
actions.single_totemic+=/surging_totem,if=!totem.surging_totem.active
actions.single_totemic+=/call_action_list,name=cooldowns
actions.single_totemic+=/lava_lash,if=buff.whirling_fire.up
actions.single_totemic+=/lava_lash,if=buff.hot_hand.up
actions.single_totemic+=/sundering
actions.single_totemic+=/doom_winds,if=!buff.doom_winds_buff.up
actions.single_totemic+=/crash_lightning,if=buff.crash_lightning_buff.up
actions.single_totemic+=/primordial_storm,if=buff.primordial_storm_buff.up
actions.single_totemic+=/windstrike,if=buff.ascendance_buff.up
actions.single_totemic+=/ascendance,if=!buff.ascendance_buff.up
actions.single_totemic+=/crash_lightning
actions.single_totemic+=/stormstrike
actions.single_totemic+=/lava_lash
actions.single_totemic+=/sundering
actions.single_totemic+=/stormstrike
actions.single_totemic+=/voltaic_blaze
actions.single_totemic+=/crash_lightning
actions.single_totemic+=/lightning_bolt,if=buff.maelstrom_weapon.stack>=5
]]

-- Register on load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        Hekolo:RegisterAPL(SPEC_ID, "Enhancement Shaman (Default)", aplString)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
