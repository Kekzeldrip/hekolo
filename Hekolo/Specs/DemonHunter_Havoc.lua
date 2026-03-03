------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Specs/DemonHunter_Havoc.lua - Havoc Demon Hunter default APL
--
-- Based on SimulationCraft APL for Havoc Demon Hunter
-- Simplified for 12.0 API limitations
------------------------------------------------------------------------

local addonName, Hekolo = ...

-- Havoc Demon Hunter spec ID: 577
local SPEC_ID = 577

local aplString = [[
# Havoc Demon Hunter APL - Hekolo Edition (12.0 compatible)

# Default rotation
actions+=/the_hunt,if=!buff.metamorphosis_dh.up&cooldown.eye_beam.remains>5
actions+=/metamorphosis,if=!buff.metamorphosis_dh.up&cooldown.eye_beam.remains>10&target.time_to_die>15
actions+=/eye_beam,if=fury>30
actions+=/essence_break,if=cooldown.eye_beam.remains>4
actions+=/death_sweep,if=buff.metamorphosis_dh.up
actions+=/blade_dance,if=!buff.metamorphosis_dh.up
actions+=/glaive_tempest,if=spell_targets>1
actions+=/immolation_aura,if=fury<80
actions+=/annihilation,if=buff.metamorphosis_dh.up
actions+=/felblade,if=fury<70
actions+=/chaos_strike,if=fury>40
actions+=/sigil_of_flame,if=fury<60
actions+=/fel_rush,if=!buff.momentum.up&talent.momentum.enabled
actions+=/throw_glaive,if=spell_targets>1|fury<30
actions+=/demons_bite

# AoE rotation
actions.aoe+=/eye_beam,if=fury>30
actions.aoe+=/blade_dance
actions.aoe+=/death_sweep,if=buff.metamorphosis_dh.up
actions.aoe+=/glaive_tempest
actions.aoe+=/immolation_aura
actions.aoe+=/sigil_of_flame
actions.aoe+=/fel_barrage,if=fury>50
actions.aoe+=/throw_glaive
actions.aoe+=/chaos_strike,if=fury>60
actions.aoe+=/demons_bite

# Cooldowns
actions.cooldowns+=/metamorphosis,if=!buff.metamorphosis_dh.up&target.time_to_die>25
actions.cooldowns+=/the_hunt
]]

-- Register on load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        Hekolo:RegisterAPL(SPEC_ID, "Havoc Demon Hunter (Default)", aplString)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
