# Hekolo - Rotation Helper for WoW 12.0 (Midnight)

A World of Warcraft addon that provides ability rotation suggestions based on SimulationCraft Action Priority Lists (APLs). Built from scratch for the WoW 12.0 "Midnight" API.

## Why Hekolo?

WoW 12.0 (Midnight) introduced the largest addon API overhaul in the game's history. The previous rotation helper **Hekili** can no longer function due to these changes. Hekolo is a spiritual successor built entirely around the new, restricted API.

## WoW 12.0 API Changes (Key Points)

Hekolo is designed around the following 12.0 restrictions:

| Area | Change | Hekolo Approach |
|------|--------|-----------------|
| **Health/Power** | `UnitHealth`/`UnitPower` return "secret" values in combat | Uses `UnitHealthPercent`/`UnitPowerPercent` instead |
| **Spell Cooldowns** | Only whitelisted spells via `C_Spell.GetSpellCooldown` | Event-driven caching via `SPELL_UPDATE_COOLDOWN`/`SPELL_UPDATE_CHARGES` (inspired by TellMeWhen) |
| **Aura Tracking** | `UnitBuff`/`UnitDebuff` removed; aura data may be "secret" in combat | Event-driven via `UNIT_AURA` with CDM hooks to recover secret aura identity (inspired by TellMeWhen) |
| **Combat Automation** | Strict limits on combat decision logic | Displays visual suggestions only; no macro generation |
| **GCD Tracking** | GCD spell 61304 remains whitelisted | Uses this for reliable GCD state |
| **Enemy Info** | Most enemy data is secret | Uses nameplate count for AoE estimation |

## Features

- **SimC APL Engine**: Parses and evaluates SimulationCraft Action Priority Lists
- **Visual Ability Queue**: Shows next 4 recommended abilities as icons
- **12.0 Compatible**: Built exclusively with non-deprecated, non-secret APIs
- **Built-in APLs**: Ships with default rotations for:
  - Warrior (Arms, Fury)
  - Demon Hunter (Havoc)
- **Customizable Display**: Movable, scalable, adjustable transparency
- **Extensible**: Easy to add APLs for additional specs

## Installation

1. Copy the `Hekolo` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory
2. Restart WoW or type `/reload` in-game
3. The addon will auto-detect your spec and load the appropriate APL

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/hekolo` | Toggle addon on/off |
| `/hekolo lock` | Lock/unlock display position |
| `/hekolo debug` | Toggle debug output |
| `/hekolo config` | Open options panel |
| `/hekolo reset` | Reset display position |
| `/hekolo help` | Show all commands |

### Display

- The icon bar appears near the center-bottom of your screen by default
- **First icon** (larger, green glow) = next recommended ability
- **Following icons** = upcoming abilities in the queue
- Drag to reposition when unlocked
- Icons only appear during combat

## Architecture

```
Hekolo/
├── Hekolo.toc              # WoW addon metadata (Interface: 120001)
├── Core/
│   ├── Core.lua            # Addon initialization, slash commands
│   ├── Events.lua          # Event handling, combat update loop
│   └── Config.lua          # Default settings
├── Data/
│   └── SpellData.lua       # Spell IDs, power types, aura data
├── Engine/
│   ├── AuraTracker.lua     # Event-driven aura cache with CDM hooks (TellMeWhen-inspired)
│   ├── CooldownTracker.lua # Event-driven cooldown cache (TellMeWhen-inspired)
│   ├── State.lua           # Game state snapshot (12.0-safe APIs)
│   ├── Conditions.lua      # SimC expression tokenizer, parser, evaluator
│   ├── APLParser.lua       # SimC APL text parser
│   └── APLEngine.lua       # Priority list evaluation engine
├── UI/
│   ├── Display.lua         # Icon-based ability suggestion overlay
│   └── Options.lua         # In-game options panel
├── Specs/
│   ├── Warrior_Arms.lua    # Arms Warrior default APL
│   ├── Warrior_Fury.lua    # Fury Warrior default APL
│   └── DemonHunter_Havoc.lua  # Havoc DH default APL
└── Tests/
    ├── test_apl_parser.lua # Standalone Lua tests for parser & conditions
    └── test_trackers.lua   # Tests for AuraTracker & CooldownTracker
```

## How the Engine Works

1. **State Snapshot** (`Engine/State.lua`): Every 0.1s during combat, captures:
   - GCD state via whitelisted spell 61304
   - Health/power percentages (non-secret)
   - Active buffs/debuffs via event-driven `AuraTracker` with CDM hooks
   - Spell cooldowns via event-driven `CooldownTracker` with cache invalidation
   - Enemy count via nameplate scanning

   **AuraTracker** (`Engine/AuraTracker.lua`): Inspired by TellMeWhen's approach:
   - Listens to `UNIT_AURA` events for incremental aura updates (added/updated/removed)
   - Hooks Blizzard's Cooldown Data Manager (CDM) viewer frames to recover spell identity for secret auras in combat
   - Uses `C_UnitAuras.IsAuraFilteredOutByInstanceID` to determine aura ownership when fields are secret
   - Handles `C_Secrets.ShouldAurasBeSecret` for 12.0 secret state transitions

   **CooldownTracker** (`Engine/CooldownTracker.lua`): Inspired by TellMeWhen's approach:
   - Caches `C_Spell.GetSpellCooldown` / `C_Spell.GetSpellCharges` results
   - Invalidates cache only on `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `SPELLS_CHANGED` events
   - Handles `UNIT_SPELL_HASTE` for haste-affected cooldown durations

2. **APL Parse** (`Engine/APLParser.lua`): Converts SimC APL text into structured action lists:
   - Splits into named action lists (default, cleave, aoe, etc.)
   - Parses each action's spell name, parameters, and conditions
   - Compiles condition expressions into ASTs

3. **Condition Evaluation** (`Engine/Conditions.lua`): Full expression evaluator:
   - Tokenizer → Parser → AST → Evaluator
   - Supports: `&` (AND), `|` (OR), `!` (NOT), comparisons, arithmetic
   - Resolves SimC variables: `buff.X.up`, `cooldown.X.remains`, `rage`, `target.health.pct`, etc.

4. **APL Engine** (`Engine/APLEngine.lua`): Walks the priority list top-to-bottom:
   - Evaluates conditions for each action
   - Checks spell cooldown and usability
   - Collects up to 4 recommended abilities
   - Supports `run_action_list`, `call_action_list`, and `variable` actions

5. **Display** (`UI/Display.lua`): Renders recommendations as an icon bar

## Limitations (12.0 Restrictions)

Due to WoW 12.0's "secret values" system and API restrictions:

- **Resource values are approximate**: We use percentage-based APIs, so exact resource thresholds (e.g., "rage >= 85") are estimates based on typical max values
- **Cooldown data is event-driven**: Uses `SPELL_UPDATE_COOLDOWN` / `SPELL_UPDATE_CHARGES` events with caching for accurate data; spells not reported by these events may still appear "ready"
- **Aura data uses CDM hooks**: Secret aura identity is recovered via Blizzard's Cooldown Data Manager frames (same technique as TellMeWhen); auras without CDM representation may have limited data in combat
- **No combat log parsing**: Cannot track damage events, procs from combat log, or enemy abilities
- **No predictive simulation**: Cannot look ahead multiple GCDs as the original Hekili did
- **Target time-to-die is estimated**: Based on health percentage heuristic, not damage tracking
- **Talent detection simplified**: Assumes talents are taken; cannot verify via restricted API in all cases

## Adding New Specs

Create a new file in `Specs/` following this pattern:

```lua
local addonName, Hekolo = ...

local SPEC_ID = 123  -- your spec ID

local aplString = [[
actions+=/spell_name,if=condition
actions+=/another_spell
]]

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name)
    if name == addonName then
        Hekolo:RegisterAPL(SPEC_ID, "Spec Name (Default)", aplString)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
```

Add the spell IDs to `Data/SpellData.lua` under the spec ID key.

## License

This addon is provided as-is for educational and personal use. SimulationCraft APL logic is adapted from the SimC community project.
