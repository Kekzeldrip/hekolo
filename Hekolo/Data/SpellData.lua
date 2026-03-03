------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Data/SpellData.lua - Spell ID mappings and class data
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.SpellData = {}

------------------------------------------------------------------------
-- Power type constants (matching Enum.PowerType)
------------------------------------------------------------------------

Hekolo.PowerType = {
    Mana        = 0,
    Rage        = 1,
    Focus       = 2,
    Energy      = 3,
    ComboPoints = 4,
    Runes       = 5,
    RunicPower  = 6,
    SoulShards  = 7,
    LunarPower  = 8,
    HolyPower   = 9,
    Maelstrom   = 11,
    Chi         = 12,
    Insanity    = 13,
    ArcaneCharges = 16,
    Fury        = 17,
    Pain        = 18,
    Essence     = 19,
}

------------------------------------------------------------------------
-- Class/spec power mappings
------------------------------------------------------------------------

Hekolo.SpecPower = {
    -- Warrior
    [71]  = Hekolo.PowerType.Rage,   -- Arms
    [72]  = Hekolo.PowerType.Rage,   -- Fury
    [73]  = Hekolo.PowerType.Rage,   -- Protection

    -- Paladin
    [65]  = Hekolo.PowerType.Mana,   -- Holy
    [66]  = Hekolo.PowerType.Mana,   -- Protection
    [70]  = Hekolo.PowerType.HolyPower, -- Retribution

    -- Hunter
    [253] = Hekolo.PowerType.Focus,  -- Beast Mastery
    [254] = Hekolo.PowerType.Focus,  -- Marksmanship
    [255] = Hekolo.PowerType.Focus,  -- Survival

    -- Rogue
    [259] = Hekolo.PowerType.Energy, -- Assassination
    [260] = Hekolo.PowerType.Energy, -- Outlaw
    [261] = Hekolo.PowerType.Energy, -- Subtlety

    -- Priest
    [256] = Hekolo.PowerType.Mana,   -- Discipline
    [257] = Hekolo.PowerType.Mana,   -- Holy
    [258] = Hekolo.PowerType.Insanity, -- Shadow

    -- Death Knight
    [250] = Hekolo.PowerType.RunicPower, -- Blood
    [251] = Hekolo.PowerType.RunicPower, -- Frost
    [252] = Hekolo.PowerType.RunicPower, -- Unholy

    -- Shaman
    [262] = Hekolo.PowerType.Maelstrom, -- Elemental
    [263] = Hekolo.PowerType.Maelstrom,  -- Enhancement
    [264] = Hekolo.PowerType.Mana,      -- Restoration

    -- Mage
    [62]  = Hekolo.PowerType.ArcaneCharges, -- Arcane
    [63]  = Hekolo.PowerType.Mana,   -- Fire
    [64]  = Hekolo.PowerType.Mana,   -- Frost

    -- Warlock
    [265] = Hekolo.PowerType.SoulShards, -- Affliction
    [266] = Hekolo.PowerType.SoulShards, -- Demonology
    [267] = Hekolo.PowerType.SoulShards, -- Destruction

    -- Monk
    [268] = Hekolo.PowerType.Energy, -- Brewmaster
    [270] = Hekolo.PowerType.Mana,   -- Mistweaver
    [269] = Hekolo.PowerType.Energy, -- Windwalker

    -- Druid
    [102] = Hekolo.PowerType.LunarPower, -- Balance
    [103] = Hekolo.PowerType.Energy,     -- Feral
    [104] = Hekolo.PowerType.Rage,       -- Guardian
    [105] = Hekolo.PowerType.Mana,       -- Restoration

    -- Demon Hunter
    [577] = Hekolo.PowerType.Fury,   -- Havoc
    [581] = Hekolo.PowerType.Pain,   -- Vengeance

    -- Evoker
    [1467] = Hekolo.PowerType.Essence, -- Devastation
    [1468] = Hekolo.PowerType.Mana,    -- Preservation
    [1473] = Hekolo.PowerType.Essence, -- Augmentation
}

------------------------------------------------------------------------
-- GCD info - global cooldown spell (universally visible in 12.0)
------------------------------------------------------------------------

Hekolo.GCD_SPELL_ID = 61304 -- GCD dummy, whitelisted in 12.0

------------------------------------------------------------------------
-- Warrior - Arms spell IDs
------------------------------------------------------------------------

Hekolo.SpellData[71] = { -- Arms Warrior
    mortal_strike       = 12294,
    overpower           = 7384,
    slam                = 1464,
    execute             = 163201,
    colossus_smash      = 167105,
    warbreaker           = 262161,
    bladestorm          = 227847,
    cleave              = 845,
    whirlwind           = 1680,
    sweeping_strikes    = 260708,
    avatar              = 107574,
    rend                = 772,
    heroic_throw        = 57755,
    charge              = 100,
    battle_shout        = 6673,
    die_by_the_sword    = 118038,
    rally               = 97462,
    pummel              = 6552,
    thunderclap         = 396719,
    thunder_clap        = 396719,
    skullsplitter       = 260643,
}

------------------------------------------------------------------------
-- Warrior - Fury spell IDs
------------------------------------------------------------------------

Hekolo.SpellData[72] = { -- Fury Warrior
    bloodthirst         = 23881,
    raging_blow         = 85288,
    rampage             = 184367,
    execute             = 280735,
    whirlwind           = 190411,
    odyns_fury          = 385059,
    ravager             = 228920,
    avatar              = 107574,
    recklessness        = 1719,
    enraged_regeneration = 184364,
    heroic_throw        = 57755,
    charge              = 100,
    battle_shout        = 6673,
    pummel              = 6552,
    slam                = 1464,
    thunderclap         = 396719,
    thunder_clap        = 396719,
    crushing_blow       = 335097,
    bloodbath           = 335096,
}

------------------------------------------------------------------------
-- Demon Hunter - Havoc spell IDs
------------------------------------------------------------------------

Hekolo.SpellData[577] = { -- Havoc Demon Hunter
    demons_bite         = 162243,
    chaos_strike        = 162794,
    blade_dance         = 188499,
    eye_beam            = 198013,
    fel_rush            = 195072,
    vengeful_retreat    = 198793,
    throw_glaive        = 185123,
    immolation_aura     = 258920,
    metamorphosis       = 191427,
    the_hunt            = 370965,
    essence_break       = 258860,
    glaive_tempest      = 342817,
    annihilation        = 201427,
    death_sweep         = 210152,
    fel_barrage         = 258925,
    felblade            = 232893,
    sigil_of_flame      = 204596,
    disrupt             = 183752,
}

------------------------------------------------------------------------
-- Shaman - Enhancement spell IDs
------------------------------------------------------------------------

Hekolo.SpellData[263] = { -- Enhancement Shaman
    stormstrike         = 17364,
    windstrike          = 115356,
    lava_lash           = 60103,
    crash_lightning     = 187874,
    chain_lightning     = 188443,
    lightning_bolt      = 188196,
    flame_shock         = 188389,
    frost_shock         = 196840,
    sundering           = 197214,
    doom_winds          = 384352,
    ascendance          = 114051,
    feral_spirit        = 51533,
    windfury_weapon     = 33757,
    flametongue_weapon  = 318038,
    lightning_shield    = 192106,
    tempest             = 454009,
    voltaic_blaze       = 470057,
    surging_totem       = 444995,
    primordial_storm    = 375982,
    fire_nova           = 333974,
    elemental_blast     = 117014,
    ice_strike          = 342240,
}

------------------------------------------------------------------------
-- Buff/Debuff spell IDs used in conditions
------------------------------------------------------------------------

Hekolo.AuraData = {
    -- Warrior
    colossus_smash      = 208086, -- debuff
    deep_wounds         = 262115, -- debuff
    overpower           = 7384,   -- buff (overpower stacks)
    test_of_might       = 385013, -- buff
    sweeping_strikes    = 260708,
    avatar              = 107574,
    rend                = 772,    -- debuff
    sudden_death        = 29725,  -- proc buff
    in_for_the_kill     = 248621, -- buff
    battlelord          = 386631, -- proc buff

    -- Warrior Fury
    enrage              = 184362,
    recklessness        = 1719,
    whirlwind_buff      = 85739,
    bloodcraze          = 393951,
    ashen_juggernaut    = 392537,

    -- DH Havoc
    metamorphosis_dh    = 162264,
    momentum            = 208628,
    inertia             = 427641,
    inner_demon         = 390145,
    essence_break_debuff = 320338,
    immolation_aura_buff = 258920,
    unbound_chaos       = 347462,
    furious_gaze        = 343312,

    -- Shaman Enhancement
    maelstrom_weapon     = 344179,
    doom_winds_buff      = 384352,
    ascendance_buff      = 114051,
    hot_hand             = 215785,
    crash_lightning_buff = 187878,
    converging_storms    = 198300,
    lashing_flames       = 390491,
    flame_shock_dot      = 188389,
    whirling_fire        = 444995,
    whirling_air         = 444995,
    whirling_earth       = 444995,
    primordial_storm_buff = 375982,
    lightning_shield_buff = 192106,
}
