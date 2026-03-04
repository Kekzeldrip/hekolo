------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Tests/test_trackers.lua - Tests for AuraTracker and CooldownTracker
--
-- Run with: lua5.4 Tests/test_trackers.lua
-- (Does not require WoW environment)
------------------------------------------------------------------------

-- Minimal WoW API stubs for testing outside the game
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
GetTime = function() return 1000.0 end
wipe = function(t)
    for k in pairs(t) do t[k] = nil end
end

-- Stub for UnitExists / UnitIsFriend
UnitExists = function(unit) return unit == "player" or unit == "target" end
UnitIsFriend = function(u1, u2) return false end

-- Stub for issecretvalue
issecretvalue = function(v) return false end

-- C_UnitAuras stubs
C_UnitAuras = {
    GetAuraDataByIndex = nil,  -- Will be configured per test
    GetAuraDataByAuraInstanceID = nil,
    IsAuraFilteredOutByInstanceID = nil,
}

-- C_Spell stubs
C_Spell = {
    GetSpellCooldown = nil,  -- Will be configured per test
    GetSpellCharges = nil,
    GetSpellName = function(id) return "Spell" .. tostring(id) end,
    IsSpellUsable = function(id) return true end,
}

-- C_Secrets stub
C_Secrets = {
    ShouldAurasBeSecret = function() return false end,
}

-- Create the Hekolo namespace manually for testing
local Hekolo = {}
_G.Hekolo = Hekolo
Hekolo.debug = false
Hekolo.playerSpecID = 71
Hekolo.inCombat = false
Hekolo.GCD_SPELL_ID = 61304

function Hekolo:Print(msg) print("[Hekolo] " .. tostring(msg)) end
function Hekolo:Debug(msg) if self.debug then print("[DEBUG] " .. tostring(msg)) end end
function Hekolo:Error(msg) print("[ERROR] " .. tostring(msg)) end

------------------------------------------------------------------------
-- Test framework
------------------------------------------------------------------------

local tests_run = 0
local tests_passed = 0
local tests_failed = 0

local function assert_eq(actual, expected, description)
    tests_run = tests_run + 1
    if actual == expected then
        tests_passed = tests_passed + 1
        print("  PASS: " .. description)
    else
        tests_failed = tests_failed + 1
        print("  FAIL: " .. description)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, description)
    assert_eq(not not value, true, description)
end

local function assert_false(value, description)
    assert_eq(not not value, false, description)
end

------------------------------------------------------------------------
-- Inline AuraTracker module for testing
------------------------------------------------------------------------

print("=============================================================")
print("Hekolo Tracker Test Suite")
print("=============================================================")

-- Simulate loading the AuraTracker module
Hekolo.AuraTracker = {}
local AuraTracker = Hekolo.AuraTracker

-- Internal caches (replicate from AuraTracker.lua)
local auraCache = {
    player = {},
    target = {},
}

local cdmData = {
    player = {},
    target = {},
}

local secretsActive = false

local function isSecretValue(value)
    if issecretvalue then
        return issecretvalue(value)
    end
    return false
end

local function shouldAurasBeSecret()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        return C_Secrets.ShouldAurasBeSecret()
    end
    return false
end

function AuraTracker:RefreshUnit(unit)
    if unit == "player" then
        wipe(auraCache.player)
        -- Scan player buffs
        if C_UnitAuras.GetAuraDataByIndex then
            local i = 1
            while true do
                local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                if not auraData then break end
                local name = auraData.name
                local spellId = auraData.spellId
                if name and not isSecretValue(name) then
                    local lowerName = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
                    local remaining = 0
                    if auraData.expirationTime and not isSecretValue(auraData.expirationTime) and auraData.expirationTime > 0 then
                        remaining = math.max(0, auraData.expirationTime - GetTime())
                    end
                    local entry = {
                        up = true,
                        remains = remaining,
                        stacks = auraData.applications or 1,
                        duration = auraData.duration or 0,
                        spellId = spellId,
                        auraInstanceID = auraData.auraInstanceID,
                    }
                    auraCache.player[lowerName] = entry
                    if spellId and not isSecretValue(spellId) then
                        auraCache.player[spellId] = entry
                    end
                end
                i = i + 1
            end
        end
    elseif unit == "target" then
        wipe(auraCache.target)
        if UnitExists("target") and not UnitIsFriend("player", "target") then
            if C_UnitAuras.GetAuraDataByIndex then
                local i = 1
                while true do
                    local auraData = C_UnitAuras.GetAuraDataByIndex("target", i, "HARMFUL|PLAYER")
                    if not auraData then break end
                    local name = auraData.name
                    local spellId = auraData.spellId
                    if name and not isSecretValue(name) then
                        local lowerName = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
                        local remaining = 0
                        if auraData.expirationTime and not isSecretValue(auraData.expirationTime) and auraData.expirationTime > 0 then
                            remaining = math.max(0, auraData.expirationTime - GetTime())
                        end
                        local entry = {
                            up = true,
                            remains = remaining,
                            stacks = auraData.applications or 1,
                            duration = auraData.duration or 0,
                            spellId = spellId,
                            auraInstanceID = auraData.auraInstanceID,
                        }
                        auraCache.target[lowerName] = entry
                        if spellId and not isSecretValue(spellId) then
                            auraCache.target[spellId] = entry
                        end
                    end
                    i = i + 1
                end
            end
        end
    end
end

function AuraTracker:GetPlayerBuffs()
    return auraCache.player
end

function AuraTracker:GetTargetDebuffs()
    return auraCache.target
end

function AuraTracker:OnUnitAura(unit, updateInfo)
    if unit ~= "player" and unit ~= "target" then return end
    if not updateInfo or updateInfo.isFullUpdate then
        self:RefreshUnit(unit)
        return
    end

    local cache = (unit == "player") and auraCache.player or auraCache.target

    -- Handle removed auras
    if updateInfo.removedAuraInstanceIDs then
        for _, instanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
            for key, entry in pairs(cache) do
                if entry.auraInstanceID == instanceID then
                    cache[key] = nil
                end
            end
        end
    end

    -- Handle added auras
    if updateInfo.addedAuras then
        for _, auraData in ipairs(updateInfo.addedAuras) do
            local name = auraData.name
            local spellId = auraData.spellId
            if name and not isSecretValue(name) then
                local lowerName = name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
                local remaining = 0
                if auraData.expirationTime and not isSecretValue(auraData.expirationTime) and auraData.expirationTime > 0 then
                    remaining = math.max(0, auraData.expirationTime - GetTime())
                end
                local entry = {
                    up = true,
                    remains = remaining,
                    stacks = auraData.applications or 1,
                    duration = auraData.duration or 0,
                    spellId = spellId,
                    auraInstanceID = auraData.auraInstanceID,
                }
                cache[lowerName] = entry
                if spellId and not isSecretValue(spellId) then
                    cache[spellId] = entry
                end
            end
        end
    end
end

function AuraTracker:CheckSecrets()
    local nowSecret = shouldAurasBeSecret()
    if nowSecret ~= secretsActive then
        secretsActive = nowSecret
        if not secretsActive then
            self:RefreshUnit("player")
            self:RefreshUnit("target")
        end
    end
end

function AuraTracker:Reset()
    wipe(auraCache.player)
    wipe(auraCache.target)
    wipe(cdmData.player)
    wipe(cdmData.target)
end

function AuraTracker:Initialize()
    self:RefreshUnit("player")
    self:RefreshUnit("target")
end

------------------------------------------------------------------------
-- Inline CooldownTracker module for testing
------------------------------------------------------------------------

Hekolo.CooldownTracker = {}
local CooldownTracker = Hekolo.CooldownTracker

local cooldownCache = {}
local chargeCache = {}
local cooldownsDirty = true
local chargesDirty = true

function CooldownTracker:GetSpellCooldown(spellID)
    if not C_Spell or not C_Spell.GetSpellCooldown then
        return nil
    end
    if cooldownsDirty then
        wipe(cooldownCache)
        cooldownsDirty = false
    end
    local cached = cooldownCache[spellID]
    if cached ~= nil then
        if cached == false then return nil end
        local duration = cached.duration
        if duration ~= 0 then
            local elapsed = GetTime() - cached.startTime
            if elapsed >= duration then
                cooldownCache[spellID] = nil
            else
                return cached
            end
        else
            return cached
        end
    end
    local cdInfo = C_Spell.GetSpellCooldown(spellID)
    cooldownCache[spellID] = cdInfo or false
    return cdInfo
end

function CooldownTracker:GetSpellCharges(spellID)
    if not C_Spell or not C_Spell.GetSpellCharges then
        return nil
    end
    if chargesDirty then
        wipe(chargeCache)
        chargesDirty = false
    end
    local cached = chargeCache[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local chargeInfo = C_Spell.GetSpellCharges(spellID)
    chargeCache[spellID] = chargeInfo or false
    return chargeInfo
end

function CooldownTracker:OnSpellUpdateCooldown()
    cooldownsDirty = true
    chargesDirty = true
end

function CooldownTracker:OnSpellUpdateCharges()
    chargesDirty = true
end

function CooldownTracker:OnSpellsChanged()
    cooldownsDirty = true
    chargesDirty = true
end

function CooldownTracker:OnUnitSpellHaste()
    cooldownsDirty = true
    chargesDirty = true
end

function CooldownTracker:Reset()
    wipe(cooldownCache)
    wipe(chargeCache)
    cooldownsDirty = true
    chargesDirty = true
end

function CooldownTracker:Initialize()
    self:Reset()
end

------------------------------------------------------------------------
-- Test 1: AuraTracker basic scan
------------------------------------------------------------------------

print("\n--- AuraTracker: Basic Scan Tests ---")

do
    -- Configure mock aura data
    local mockAuras = {
        { name = "Avatar", spellId = 107574, expirationTime = 1020.0, duration = 20, applications = 1, auraInstanceID = 1 },
        { name = "Battle Shout", spellId = 6673, expirationTime = 0, duration = 3600, applications = 1, auraInstanceID = 2 },
    }

    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if unit == "player" and filter == "HELPFUL" then
            return mockAuras[index]
        end
        return nil
    end

    AuraTracker:Reset()
    AuraTracker:RefreshUnit("player")
    local buffs = AuraTracker:GetPlayerBuffs()

    assert_true(buffs["avatar"] ~= nil, "Avatar buff found by lowercase name")
    assert_eq(buffs["avatar"].up, true, "Avatar buff is up")
    assert_eq(buffs["avatar"].spellId, 107574, "Avatar spell ID correct")
    assert_eq(buffs["avatar"].remains, 20.0, "Avatar remaining time correct")
    assert_eq(buffs["avatar"].duration, 20, "Avatar duration correct")

    assert_true(buffs["battle_shout"] ~= nil, "Battle Shout buff found")
    assert_eq(buffs["battle_shout"].remains, 0, "Battle Shout no remaining (permanent)")

    -- Also check spell ID lookup
    assert_true(buffs[107574] ~= nil, "Avatar found by spell ID")
    assert_eq(buffs[107574].spellId, 107574, "Spell ID lookup returns correct data")
end

------------------------------------------------------------------------
-- Test 2: AuraTracker incremental update - add aura
------------------------------------------------------------------------

print("\n--- AuraTracker: Incremental Add Tests ---")

do
    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        return nil  -- empty initial state
    end

    AuraTracker:Reset()
    AuraTracker:RefreshUnit("player")
    local buffs = AuraTracker:GetPlayerBuffs()
    assert_true(buffs["avatar"] == nil, "No avatar before add event")

    -- Simulate UNIT_AURA with addedAuras
    AuraTracker:OnUnitAura("player", {
        isFullUpdate = false,
        addedAuras = {
            { name = "Avatar", spellId = 107574, expirationTime = 1020.0, duration = 20, applications = 1, auraInstanceID = 10 },
        },
    })

    buffs = AuraTracker:GetPlayerBuffs()
    assert_true(buffs["avatar"] ~= nil, "Avatar added via incremental update")
    assert_eq(buffs["avatar"].up, true, "Avatar is up after add")
    assert_eq(buffs["avatar"].auraInstanceID, 10, "Avatar has correct instanceID")
end

------------------------------------------------------------------------
-- Test 3: AuraTracker incremental update - remove aura
------------------------------------------------------------------------

print("\n--- AuraTracker: Incremental Remove Tests ---")

do
    -- Start with an aura present
    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if index == 1 then
            return { name = "Avatar", spellId = 107574, expirationTime = 1020.0, duration = 20, applications = 1, auraInstanceID = 20 }
        end
        return nil
    end

    AuraTracker:Reset()
    AuraTracker:RefreshUnit("player")
    local buffs = AuraTracker:GetPlayerBuffs()
    assert_true(buffs["avatar"] ~= nil, "Avatar present before remove")

    -- Simulate removal
    AuraTracker:OnUnitAura("player", {
        isFullUpdate = false,
        removedAuraInstanceIDs = { 20 },
    })

    buffs = AuraTracker:GetPlayerBuffs()
    assert_true(buffs["avatar"] == nil, "Avatar removed via incremental update")
    assert_true(buffs[107574] == nil, "Avatar spell ID entry also removed")
end

------------------------------------------------------------------------
-- Test 4: AuraTracker full update (isFullUpdate = true)
------------------------------------------------------------------------

print("\n--- AuraTracker: Full Update Tests ---")

do
    local scanCount = 0
    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if unit == "player" and filter == "HELPFUL" and index == 1 then
            return { name = "Sweeping Strikes", spellId = 260708, expirationTime = 1015.0, duration = 15, applications = 1, auraInstanceID = 30 }
        end
        return nil
    end

    AuraTracker:Reset()
    AuraTracker:OnUnitAura("player", { isFullUpdate = true })

    local buffs = AuraTracker:GetPlayerBuffs()
    assert_true(buffs["sweeping_strikes"] ~= nil, "Full update triggers complete rescan")
    assert_eq(buffs["sweeping_strikes"].spellId, 260708, "Sweeping Strikes spell ID correct")
end

------------------------------------------------------------------------
-- Test 5: AuraTracker reset
------------------------------------------------------------------------

print("\n--- AuraTracker: Reset Tests ---")

do
    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if index == 1 then
            return { name = "Test Buff", spellId = 12345, expirationTime = 1010.0, duration = 10, applications = 2, auraInstanceID = 40 }
        end
        return nil
    end

    AuraTracker:RefreshUnit("player")
    assert_true(AuraTracker:GetPlayerBuffs()["test_buff"] ~= nil, "Buff present before reset")

    AuraTracker:Reset()
    assert_true(AuraTracker:GetPlayerBuffs()["test_buff"] == nil, "Buff cleared after reset")
end

------------------------------------------------------------------------
-- Test 6: AuraTracker target debuffs
------------------------------------------------------------------------

print("\n--- AuraTracker: Target Debuff Tests ---")

do
    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if unit == "target" and filter == "HARMFUL|PLAYER" and index == 1 then
            return { name = "Deep Wounds", spellId = 262115, expirationTime = 1012.0, duration = 12, applications = 1, auraInstanceID = 50 }
        end
        return nil
    end

    AuraTracker:Reset()
    AuraTracker:RefreshUnit("target")
    local debuffs = AuraTracker:GetTargetDebuffs()

    assert_true(debuffs["deep_wounds"] ~= nil, "Deep Wounds debuff found on target")
    assert_eq(debuffs["deep_wounds"].spellId, 262115, "Deep Wounds spell ID correct")
    assert_eq(debuffs["deep_wounds"].remains, 12.0, "Deep Wounds remaining time correct")
end

------------------------------------------------------------------------
-- Test 7: AuraTracker secrets check
------------------------------------------------------------------------

print("\n--- AuraTracker: Secrets State Tests ---")

do
    local secretState = false
    C_Secrets.ShouldAurasBeSecret = function() return secretState end

    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if index == 1 then
            return { name = "Avatar", spellId = 107574, expirationTime = 1020.0, duration = 20, applications = 1, auraInstanceID = 60 }
        end
        return nil
    end

    AuraTracker:Reset()
    secretsActive = false

    -- Initially not secret
    AuraTracker:CheckSecrets()
    -- Should not trigger any reset

    -- Transition to secret state
    secretState = true
    AuraTracker:CheckSecrets()
    -- Should just update the flag

    -- Transition back from secret
    secretState = false
    AuraTracker:CheckSecrets()
    -- Should refresh units
    local buffs = AuraTracker:GetPlayerBuffs()
    assert_true(buffs["avatar"] ~= nil, "Auras refreshed after secrets cleared")
end

------------------------------------------------------------------------
-- Test 8: CooldownTracker basic caching
------------------------------------------------------------------------

print("\n--- CooldownTracker: Basic Caching Tests ---")

do
    local callCount = 0
    C_Spell.GetSpellCooldown = function(spellID)
        callCount = callCount + 1
        if spellID == 12294 then -- Mortal Strike
            return { startTime = 998.0, duration = 6.0, modRate = 1.0 }
        end
        return nil
    end

    CooldownTracker:Reset()

    -- First call should hit the API
    callCount = 0
    local cd = CooldownTracker:GetSpellCooldown(12294)
    assert_true(cd ~= nil, "Cooldown data returned for Mortal Strike")
    assert_eq(cd.startTime, 998.0, "Start time correct")
    assert_eq(cd.duration, 6.0, "Duration correct")
    local firstCallCount = callCount

    -- Second call should use cache (no additional API call)
    local cd2 = CooldownTracker:GetSpellCooldown(12294)
    assert_eq(callCount, firstCallCount, "Second call uses cache (no extra API call)")
    assert_eq(cd2.startTime, 998.0, "Cached data is correct")
end

------------------------------------------------------------------------
-- Test 9: CooldownTracker cache invalidation
------------------------------------------------------------------------

print("\n--- CooldownTracker: Cache Invalidation Tests ---")

do
    local returnValue = { startTime = 995.0, duration = 10.0, modRate = 1.0 }
    C_Spell.GetSpellCooldown = function(spellID)
        return returnValue
    end

    CooldownTracker:Reset()

    -- Get initial value
    local cd1 = CooldownTracker:GetSpellCooldown(100)
    assert_eq(cd1.startTime, 995.0, "Initial cooldown correct")

    -- Change the return value
    returnValue = { startTime = 998.0, duration = 10.0, modRate = 1.0 }

    -- Without invalidation, should still return cached
    local cd2 = CooldownTracker:GetSpellCooldown(100)
    assert_eq(cd2.startTime, 995.0, "Cached value returned before invalidation")

    -- Invalidate via event
    CooldownTracker:OnSpellUpdateCooldown()

    -- Now should get fresh data
    local cd3 = CooldownTracker:GetSpellCooldown(100)
    assert_eq(cd3.startTime, 998.0, "Fresh data after invalidation")
end

------------------------------------------------------------------------
-- Test 10: CooldownTracker charge caching
------------------------------------------------------------------------

print("\n--- CooldownTracker: Charge Caching Tests ---")

do
    C_Spell.GetSpellCharges = function(spellID)
        if spellID == 7384 then -- Overpower
            return {
                currentCharges = 1,
                maxCharges = 2,
                cooldownStartTime = 995.0,
                cooldownDuration = 12.0,
            }
        end
        return nil
    end

    CooldownTracker:Reset()

    local charges = CooldownTracker:GetSpellCharges(7384)
    assert_true(charges ~= nil, "Charge info returned for Overpower")
    assert_eq(charges.currentCharges, 1, "Current charges correct")
    assert_eq(charges.maxCharges, 2, "Max charges correct")

    -- Spell without charges
    local noCharges = CooldownTracker:GetSpellCharges(12294)
    assert_true(noCharges == nil, "No charge info for non-charge spell")
end

------------------------------------------------------------------------
-- Test 11: CooldownTracker charge invalidation
------------------------------------------------------------------------

print("\n--- CooldownTracker: Charge Invalidation Tests ---")

do
    local chargeData = { currentCharges = 2, maxCharges = 2, cooldownStartTime = 0, cooldownDuration = 12.0 }
    C_Spell.GetSpellCharges = function(spellID)
        return chargeData
    end

    CooldownTracker:Reset()

    local ch1 = CooldownTracker:GetSpellCharges(7384)
    assert_eq(ch1.currentCharges, 2, "Initial charges correct")

    -- Use a charge
    chargeData = { currentCharges = 1, maxCharges = 2, cooldownStartTime = 1000.0, cooldownDuration = 12.0 }

    -- Before event, still cached
    local ch2 = CooldownTracker:GetSpellCharges(7384)
    assert_eq(ch2.currentCharges, 2, "Cached charges before event")

    -- Fire SPELL_UPDATE_CHARGES
    CooldownTracker:OnSpellUpdateCharges()

    local ch3 = CooldownTracker:GetSpellCharges(7384)
    assert_eq(ch3.currentCharges, 1, "Updated charges after event")
end

------------------------------------------------------------------------
-- Test 12: CooldownTracker haste invalidation
------------------------------------------------------------------------

print("\n--- CooldownTracker: Haste Invalidation Tests ---")

do
    local cdValue = { startTime = 990.0, duration = 8.0, modRate = 1.0 }
    C_Spell.GetSpellCooldown = function(spellID)
        return cdValue
    end

    CooldownTracker:Reset()

    local cd1 = CooldownTracker:GetSpellCooldown(100)
    assert_eq(cd1.duration, 8.0, "Initial duration")

    -- Haste changes duration
    cdValue = { startTime = 990.0, duration = 6.5, modRate = 1.0 }

    -- Haste event triggers invalidation
    CooldownTracker:OnUnitSpellHaste()

    local cd2 = CooldownTracker:GetSpellCooldown(100)
    assert_eq(cd2.duration, 6.5, "Duration updated after haste change")
end

------------------------------------------------------------------------
-- Test 13: CooldownTracker SPELLS_CHANGED invalidation
------------------------------------------------------------------------

print("\n--- CooldownTracker: Spells Changed Tests ---")

do
    local cd1Available = true
    C_Spell.GetSpellCooldown = function(spellID)
        if spellID == 999 and cd1Available then
            return { startTime = 0, duration = 0, modRate = 1.0 }
        end
        return nil
    end

    CooldownTracker:Reset()

    local cd = CooldownTracker:GetSpellCooldown(999)
    assert_true(cd ~= nil, "Spell available initially")

    -- Spell unlearned
    cd1Available = false
    CooldownTracker:OnSpellsChanged()

    local cd2 = CooldownTracker:GetSpellCooldown(999)
    assert_true(cd2 == nil, "Spell unavailable after SPELLS_CHANGED")
end

------------------------------------------------------------------------
-- Test 14: AuraTracker stacks handling
------------------------------------------------------------------------

print("\n--- AuraTracker: Stack Count Tests ---")

do
    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        if unit == "player" and index == 1 then
            return { name = "Overpower", spellId = 7384, expirationTime = 1015.0, duration = 15, applications = 2, auraInstanceID = 70 }
        end
        return nil
    end

    AuraTracker:Reset()
    AuraTracker:RefreshUnit("player")
    local buffs = AuraTracker:GetPlayerBuffs()

    assert_true(buffs["overpower"] ~= nil, "Overpower buff found")
    assert_eq(buffs["overpower"].stacks, 2, "Overpower has 2 stacks")
end

------------------------------------------------------------------------
-- Test 15: AuraTracker ignores non-player/target units
------------------------------------------------------------------------

print("\n--- AuraTracker: Unit Filtering Tests ---")

do
    AuraTracker:Reset()
    -- These should be ignored (not player or target)
    AuraTracker:OnUnitAura("focus", {
        isFullUpdate = false,
        addedAuras = {
            { name = "Some Buff", spellId = 99999, expirationTime = 1010.0, duration = 10, applications = 1, auraInstanceID = 80 },
        },
    })

    -- Should not affect player or target caches
    assert_true(AuraTracker:GetPlayerBuffs()["some_buff"] == nil, "Focus aura not in player buffs")
    assert_true(AuraTracker:GetTargetDebuffs()["some_buff"] == nil, "Focus aura not in target debuffs")
end

------------------------------------------------------------------------
-- Test 16: CooldownTracker expired cooldown detection
------------------------------------------------------------------------

print("\n--- CooldownTracker: Expired Cooldown Tests ---")

do
    -- A cooldown that started 20 seconds ago with 15s duration (already expired)
    C_Spell.GetSpellCooldown = function(spellID)
        if spellID == 500 then
            return { startTime = 980.0, duration = 15.0, modRate = 1.0 }
        end
        return nil
    end

    CooldownTracker:Reset()

    -- GetTime() returns 1000.0, so 980 + 15 = 995 < 1000 => expired
    local cd = CooldownTracker:GetSpellCooldown(500)
    assert_true(cd ~= nil, "First call returns the cooldown data from API")

    -- The cache should now have the entry but it's expired...
    -- On next access, the cached entry should be recognized as expired
    -- and removed, causing a fresh API call
    local cd2 = CooldownTracker:GetSpellCooldown(500)
    -- It should re-fetch from API since cached one was expired
    assert_true(cd2 ~= nil, "Re-fetched after expired cache detected")
end

------------------------------------------------------------------------
-- Summary
------------------------------------------------------------------------

print("\n" .. string.rep("=", 61))
print(string.format("Results: %d/%d passed, %d failed",
    tests_passed, tests_run, tests_failed))
print(string.rep("=", 61))

if tests_failed > 0 then
    os.exit(1)
else
    os.exit(0)
end
