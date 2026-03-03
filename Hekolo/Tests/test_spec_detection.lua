------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Tests/test_spec_detection.lua - Tests for specialization detection
--
-- Run with: lua Tests/test_spec_detection.lua
-- (Does not require WoW environment)
------------------------------------------------------------------------

-- Minimal WoW API stubs for testing outside the game
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
GetTime = function() return 1000.0 end

-- Create the Hekolo namespace manually for testing
local Hekolo = {}
_G.Hekolo = Hekolo
Hekolo.debug = false
Hekolo.playerClass = nil
Hekolo.playerSpec = nil
Hekolo.playerSpecID = nil
Hekolo.playerLevel = 0

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

------------------------------------------------------------------------
-- Stub for C_Timer (not available outside WoW)
------------------------------------------------------------------------
local timerCallbacks = {}
C_Timer = {
    After = function(delay, callback)
        table.insert(timerCallbacks, callback)
    end,
}

local function runTimers()
    local cbs = timerCallbacks
    timerCallbacks = {}
    for _, cb in ipairs(cbs) do cb() end
end

------------------------------------------------------------------------
-- Inline UpdateSpec and ScheduleSpecRetry from Core.lua
------------------------------------------------------------------------

function Hekolo:UpdateSpec()
    local specIndex = GetSpecialization()
    if not specIndex or specIndex <= 0 then
        self:ScheduleSpecRetry()
        return
    end

    -- Primary method: GetSpecializationInfo
    local specID, specName = GetSpecializationInfo(specIndex)
    if specID and specID > 0 and specName then
        self.playerSpecID = specID
        self.playerSpec = specName
        return
    end

    -- Fallback: GetSpecializationInfoForClassID (requires classID)
    if GetSpecializationInfoForClassID then
        local _, _, classID = UnitClass("player")
        if classID then
            specID, specName = GetSpecializationInfoForClassID(classID, specIndex)
            if specID and specID > 0 and specName then
                self.playerSpecID = specID
                self.playerSpec = specName
                return
            end
        end
    end

    -- If still no valid spec, schedule a retry
    self:ScheduleSpecRetry()
end

function Hekolo:ScheduleSpecRetry()
    if self._specRetryTimer then return end
    if not C_Timer or not C_Timer.After then return end

    self._specRetryTimer = true
    C_Timer.After(1.0, function()
        self._specRetryTimer = nil
        self:UpdateSpec()
        if self.playerSpecID and self.playerSpecID > 0 then
            self:Debug("Spec detected (retry): " .. tostring(self.playerSpec) .. " (ID: " .. tostring(self.playerSpecID) .. ")")
        end
    end)
end

------------------------------------------------------------------------
-- Tests: spec detection with valid API returns
------------------------------------------------------------------------

print("\n=== Test: GetSpecializationInfo returns valid data ===")
do
    -- Stub WoW APIs for valid case
    GetSpecialization = function() return 2 end
    GetSpecializationInfo = function(index) return 263, "Enhancement" end
    UnitClass = function(unit) return "Shaman", "SHAMAN", 7 end
    GetSpecializationInfoForClassID = nil

    Hekolo.playerSpecID = nil
    Hekolo.playerSpec = nil
    Hekolo._specRetryTimer = nil

    Hekolo:UpdateSpec()

    assert_eq(Hekolo.playerSpecID, 263, "specID set to 263 (Enhancement Shaman)")
    assert_eq(Hekolo.playerSpec, "Enhancement", "specName set to Enhancement")
end

------------------------------------------------------------------------
-- Tests: GetSpecializationInfo returns (0, nil) - the reported bug
------------------------------------------------------------------------

print("\n=== Test: GetSpecializationInfo returns (0, nil) with fallback ===")
do
    GetSpecialization = function() return 2 end
    GetSpecializationInfo = function(index) return 0, nil end
    UnitClass = function(unit) return "Shaman", "SHAMAN", 7 end
    GetSpecializationInfoForClassID = function(classID, specIndex)
        return 263, "Enhancement"
    end

    Hekolo.playerSpecID = nil
    Hekolo.playerSpec = nil
    Hekolo._specRetryTimer = nil

    Hekolo:UpdateSpec()

    assert_eq(Hekolo.playerSpecID, 263, "Fallback: specID set to 263")
    assert_eq(Hekolo.playerSpec, "Enhancement", "Fallback: specName set to Enhancement")
end

------------------------------------------------------------------------
-- Tests: GetSpecializationInfo returns (0, nil) without fallback
------------------------------------------------------------------------

print("\n=== Test: GetSpecializationInfo returns (0, nil), no fallback, retry scheduled ===")
do
    GetSpecialization = function() return 2 end
    GetSpecializationInfo = function(index) return 0, nil end
    UnitClass = function(unit) return "Shaman", "SHAMAN", 7 end
    GetSpecializationInfoForClassID = nil

    Hekolo.playerSpecID = nil
    Hekolo.playerSpec = nil
    Hekolo._specRetryTimer = nil
    timerCallbacks = {}

    Hekolo:UpdateSpec()

    assert_eq(Hekolo.playerSpecID, nil, "No valid spec set when both methods fail")
    assert_eq(Hekolo.playerSpec, nil, "No valid specName when both methods fail")
    assert_eq(#timerCallbacks, 1, "Retry timer scheduled")
end

------------------------------------------------------------------------
-- Tests: GetSpecialization returns nil
------------------------------------------------------------------------

print("\n=== Test: GetSpecialization returns nil ===")
do
    GetSpecialization = function() return nil end
    GetSpecializationInfo = function(index) return 71, "Arms" end
    UnitClass = function(unit) return "Warrior", "WARRIOR", 1 end
    GetSpecializationInfoForClassID = nil

    Hekolo.playerSpecID = nil
    Hekolo.playerSpec = nil
    Hekolo._specRetryTimer = nil
    timerCallbacks = {}

    Hekolo:UpdateSpec()

    assert_eq(Hekolo.playerSpecID, nil, "No spec when GetSpecialization returns nil")
    assert_eq(Hekolo.playerSpec, nil, "No specName when GetSpecialization returns nil")
    assert_eq(#timerCallbacks, 1, "Retry timer scheduled when no specIndex")
end

------------------------------------------------------------------------
-- Tests: Retry succeeds after initial failure
------------------------------------------------------------------------

print("\n=== Test: Retry succeeds after initial failure ===")
do
    local callCount = 0
    GetSpecialization = function() return 1 end
    GetSpecializationInfo = function(index)
        callCount = callCount + 1
        if callCount <= 1 then
            return 0, nil -- first call fails
        end
        return 71, "Arms" -- subsequent calls succeed
    end
    UnitClass = function(unit) return "Warrior", "WARRIOR", 1 end
    GetSpecializationInfoForClassID = nil

    Hekolo.playerSpecID = nil
    Hekolo.playerSpec = nil
    Hekolo._specRetryTimer = nil
    timerCallbacks = {}

    Hekolo:UpdateSpec()

    assert_eq(Hekolo.playerSpecID, nil, "First call: no spec yet")
    assert_eq(#timerCallbacks, 1, "First call: retry scheduled")

    -- Simulate timer firing
    runTimers()

    assert_eq(Hekolo.playerSpecID, 71, "After retry: specID set to 71 (Arms)")
    assert_eq(Hekolo.playerSpec, "Arms", "After retry: specName set to Arms")
end

------------------------------------------------------------------------
-- Tests: Does not overwrite valid spec with invalid data
------------------------------------------------------------------------

print("\n=== Test: Does not overwrite valid spec with invalid data ===")
do
    GetSpecialization = function() return 1 end
    GetSpecializationInfo = function(index) return 0, nil end
    UnitClass = function(unit) return "Warrior", "WARRIOR", 1 end
    GetSpecializationInfoForClassID = nil

    -- Pre-set valid spec data
    Hekolo.playerSpecID = 72
    Hekolo.playerSpec = "Fury"
    Hekolo._specRetryTimer = nil
    timerCallbacks = {}

    Hekolo:UpdateSpec()

    assert_eq(Hekolo.playerSpecID, 72, "Existing specID preserved")
    assert_eq(Hekolo.playerSpec, "Fury", "Existing specName preserved")
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
