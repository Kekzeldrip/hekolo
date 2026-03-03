------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Tests/test_apl_parser.lua - Standalone tests for APL parser & conditions
--
-- Run with: lua Tests/test_apl_parser.lua
-- (Does not require WoW environment)
------------------------------------------------------------------------

-- Minimal WoW API stubs for testing outside the game
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
GetTime = function() return 1000.0 end

-- Create the Hekolo namespace manually for testing
local Hekolo = {}
_G.Hekolo = Hekolo
Hekolo.debug = false
Hekolo.playerSpecID = 71

function Hekolo:Print(msg) print("[Hekolo] " .. tostring(msg)) end
function Hekolo:Debug(msg) if self.debug then print("[DEBUG] " .. tostring(msg)) end end
function Hekolo:Error(msg) print("[ERROR] " .. tostring(msg)) end

-- Load the modules we need to test
-- We'll inline-simulate the module loading since we can't use WoW's ... syntax
local function loadModule(path)
    -- Read file and execute, providing our namespace
    local chunk, err = loadfile(path)
    if not chunk then
        print("FAIL: Could not load " .. path .. ": " .. tostring(err))
        return false
    end
    -- Override the ... return to provide our addon namespace
    -- We'll set up modules to work without the WoW addon loading
    return true
end

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
-- Inline the Conditions module for testing
------------------------------------------------------------------------

Hekolo.Conditions = {}
local Conditions = Hekolo.Conditions

-- Copy the tokenizer
function Conditions:Tokenize(expr)
    local tokens = {}
    local i = 1
    local len = #expr

    while i <= len do
        local ch = expr:sub(i, i)

        if ch == " " or ch == "\t" then
            i = i + 1
        elseif ch == "&" then
            table.insert(tokens, { type = "op", value = "&" })
            i = i + 1
        elseif ch == "|" then
            table.insert(tokens, { type = "op", value = "|" })
            i = i + 1
        elseif ch == "!" then
            if expr:sub(i, i + 1) == "!=" then
                table.insert(tokens, { type = "op", value = "!=" })
                i = i + 2
            else
                table.insert(tokens, { type = "op", value = "!" })
                i = i + 1
            end
        elseif ch == "=" then
            if expr:sub(i, i + 1) == "==" then
                table.insert(tokens, { type = "op", value = "==" })
                i = i + 2
            else
                table.insert(tokens, { type = "op", value = "=" })
                i = i + 1
            end
        elseif ch == "<" then
            if expr:sub(i, i + 1) == "<=" then
                table.insert(tokens, { type = "op", value = "<=" })
                i = i + 2
            else
                table.insert(tokens, { type = "op", value = "<" })
                i = i + 1
            end
        elseif ch == ">" then
            if expr:sub(i, i + 1) == ">=" then
                table.insert(tokens, { type = "op", value = ">=" })
                i = i + 2
            else
                table.insert(tokens, { type = "op", value = ">" })
                i = i + 1
            end
        elseif ch == "+" then
            table.insert(tokens, { type = "op", value = "+" })
            i = i + 1
        elseif ch == "-" then
            table.insert(tokens, { type = "op", value = "-" })
            i = i + 1
        elseif ch == "*" then
            table.insert(tokens, { type = "op", value = "*" })
            i = i + 1
        elseif ch == "/" then
            table.insert(tokens, { type = "op", value = "/" })
            i = i + 1
        elseif ch == "%" then
            table.insert(tokens, { type = "op", value = "/" })
            i = i + 1
        elseif ch == "(" then
            table.insert(tokens, { type = "lparen" })
            i = i + 1
        elseif ch == ")" then
            table.insert(tokens, { type = "rparen" })
            i = i + 1
        elseif ch:match("%d") or (ch == "." and expr:sub(i + 1, i + 1):match("%d")) then
            local numStr = ""
            while i <= len and (expr:sub(i, i):match("[%d%.]")) do
                numStr = numStr .. expr:sub(i, i)
                i = i + 1
            end
            table.insert(tokens, { type = "number", value = tonumber(numStr) or 0 })
        elseif ch:match("[%a_]") then
            local ident = ""
            while i <= len and expr:sub(i, i):match("[%w_%.]") do
                ident = ident .. expr:sub(i, i)
                i = i + 1
            end
            table.insert(tokens, { type = "ident", value = ident })
        else
            i = i + 1
        end
    end

    return tokens
end

-- Copy the parser
local Parser = {}
Parser.__index = Parser

function Parser:new(tokens)
    return setmetatable({ tokens = tokens, pos = 1 }, Parser)
end

function Parser:peek()
    return self.tokens[self.pos]
end

function Parser:consume()
    local t = self.tokens[self.pos]
    self.pos = self.pos + 1
    return t
end

function Parser:match(tokenType, value)
    local t = self:peek()
    if t and t.type == tokenType and (not value or t.value == value) then
        return self:consume()
    end
    return nil
end

function Parser:parseExpression() return self:parseOr() end

function Parser:parseOr()
    local left = self:parseAnd()
    while self:match("op", "|") do
        local right = self:parseAnd()
        left = { type = "binop", op = "|", left = left, right = right }
    end
    return left
end

function Parser:parseAnd()
    local left = self:parseComparison()
    while self:match("op", "&") do
        local right = self:parseComparison()
        left = { type = "binop", op = "&", left = left, right = right }
    end
    return left
end

function Parser:parseComparison()
    local left = self:parseAdditive()
    local t = self:peek()
    if t and t.type == "op" and (t.value == "=" or t.value == "==" or t.value == "!=" or t.value == "<" or t.value == ">" or t.value == "<=" or t.value == ">=") then
        local op = self:consume().value
        if op == "=" then op = "==" end
        local right = self:parseAdditive()
        return { type = "binop", op = op, left = left, right = right }
    end
    return left
end

function Parser:parseAdditive()
    local left = self:parseMultiplicative()
    while true do
        local t = self:peek()
        if t and t.type == "op" and (t.value == "+" or t.value == "-") then
            local op = self:consume().value
            local right = self:parseMultiplicative()
            left = { type = "binop", op = op, left = left, right = right }
        else break end
    end
    return left
end

function Parser:parseMultiplicative()
    local left = self:parseUnary()
    while true do
        local t = self:peek()
        if t and t.type == "op" and (t.value == "*" or t.value == "/") then
            local op = self:consume().value
            local right = self:parseUnary()
            left = { type = "binop", op = op, left = left, right = right }
        else break end
    end
    return left
end

function Parser:parseUnary()
    if self:match("op", "!") then
        local expr = self:parseUnary()
        return { type = "unary", op = "!", operand = expr }
    end
    return self:parseAtom()
end

function Parser:parseAtom()
    if self:match("lparen") then
        local expr = self:parseExpression()
        self:match("rparen")
        return expr
    end
    local num = self:match("number")
    if num then return { type = "literal", value = num.value } end
    local ident = self:match("ident")
    if ident then return { type = "variable", value = ident.value } end
    return { type = "literal", value = 0 }
end

function Conditions:Compile(exprString)
    if not exprString or exprString == "" then
        return { type = "literal", value = 1 }
    end
    local tokens = self:Tokenize(exprString)
    if #tokens == 0 then return { type = "literal", value = 1 } end
    local parser = Parser:new(tokens)
    return parser:parseExpression()
end

function Conditions:Evaluate(ast, state)
    if not ast then return true end
    if ast.type == "literal" then return ast.value
    elseif ast.type == "variable" then return self:ResolveVariable(ast.value, state)
    elseif ast.type == "unary" then
        local val = self:Evaluate(ast.operand, state)
        if ast.op == "!" then return self:IsTrue(val) and 0 or 1 end
    elseif ast.type == "binop" then
        if ast.op == "&" then
            local left = self:Evaluate(ast.left, state)
            if not self:IsTrue(left) then return 0 end
            return self:IsTrue(self:Evaluate(ast.right, state)) and 1 or 0
        elseif ast.op == "|" then
            local left = self:Evaluate(ast.left, state)
            if self:IsTrue(left) then return 1 end
            return self:IsTrue(self:Evaluate(ast.right, state)) and 1 or 0
        else
            local left = tonumber(self:Evaluate(ast.left, state)) or 0
            local right = tonumber(self:Evaluate(ast.right, state)) or 0
            if ast.op == "==" then return (left == right) and 1 or 0
            elseif ast.op == "!=" then return (left ~= right) and 1 or 0
            elseif ast.op == "<" then return (left < right) and 1 or 0
            elseif ast.op == ">" then return (left > right) and 1 or 0
            elseif ast.op == "<=" then return (left <= right) and 1 or 0
            elseif ast.op == ">=" then return (left >= right) and 1 or 0
            elseif ast.op == "+" then return left + right
            elseif ast.op == "-" then return left - right
            elseif ast.op == "*" then return left * right
            elseif ast.op == "/" then return right ~= 0 and (left / right) or 0
            end
        end
    end
    return 0
end

function Conditions:IsTrue(value)
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value ~= 0 end
    return value ~= nil and value ~= false
end

function Conditions:ResolveVariable(name, state)
    if not name or not state then return 0 end
    local parts = {}
    for part in name:gmatch("[^%.]+") do table.insert(parts, part) end
    local category = parts[1]
    local subject = parts[2]
    local property = parts[3]

    if category == "buff" and subject then
        local buff = state:GetBuff(subject)
        if not property or property == "up" then return buff.up and 1 or 0
        elseif property == "down" then return buff.up and 0 or 1
        elseif property == "remains" then return buff.remains
        elseif property == "stack" or property == "stacks" then return buff.stacks
        end
        return 0
    end

    if category == "debuff" and subject then
        local debuff = state:GetDebuff(subject)
        if not property or property == "up" then return debuff.up and 1 or 0
        elseif property == "down" then return debuff.up and 0 or 1
        elseif property == "remains" then return debuff.remains
        end
        return 0
    end

    if category == "cooldown" and subject then
        local cd = state:GetCooldown(subject)
        if not property or property == "remains" then return cd.remains
        elseif property == "ready" or property == "up" then return cd.ready and 1 or 0
        end
        return 0
    end

    if category == "target" then
        if subject == "health" and property == "pct" then return state.target_health_pct or 100 end
        if subject == "time_to_die" then return 30 end
        return 0
    end

    if category == "spell_targets" or name == "active_enemies" then
        return state.spell_targets or 1
    end

    if category == "rage" or category == "energy" or category == "fury" then
        if not subject then return math.floor((state.power_pct or 0) * 100 / 100) end
        if subject == "deficit" then return 100 - math.floor((state.power_pct or 0) * 100 / 100) end
        return 0
    end

    if name == "true" then return 1 end
    if name == "false" then return 0 end

    return 0
end

------------------------------------------------------------------------
-- Inline the APLParser module for testing
------------------------------------------------------------------------

Hekolo.APLParser = {}
local APLParser = Hekolo.APLParser

function APLParser:Parse(aplText)
    if not aplText or aplText == "" then return nil end
    local actionLists = {}
    for line in aplText:gmatch("[^\r\n]+") do
        line = strtrim(line)
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local listName, actionStr = self:ParseLine(line)
            if listName and actionStr then
                if not actionLists[listName] then actionLists[listName] = {} end
                local action = self:ParseAction(actionStr)
                if action then table.insert(actionLists[listName], action) end
            end
        end
    end
    return actionLists
end

function APLParser:ParseLine(line)
    local listName, actionStr
    listName, actionStr = line:match("^actions%.([%w_]+)%+?=/(.+)$")
    if listName and actionStr then return listName, strtrim(actionStr) end
    actionStr = line:match("^actions%+?=/(.+)$")
    if actionStr then return "default", strtrim(actionStr) end
    return nil, nil
end

function APLParser:ParseAction(actionStr)
    if not actionStr or actionStr == "" then return nil end
    local action = { type = "spell", name = nil, conditions = nil, conditionStr = nil, params = {} }
    local parts = self:SplitAction(actionStr)
    if #parts == 0 then return nil end
    action.name = parts[1]

    if action.name == "run_action_list" or action.name == "call_action_list" then
        action.type = "action_list"
    elseif action.name == "variable" then
        action.type = "variable"
    elseif action.name == "potion" or action.name == "food" or action.name == "flask" or action.name == "snapshot_stats" or action.name == "auto_attack" then
        action.type = "skip"
    else
        action.type = "spell"
    end

    for i = 2, #parts do
        local key, value = parts[i]:match("^([%w_]+)=(.+)$")
        if key and value then
            if key == "if" then
                action.conditionStr = value
                action.conditions = Hekolo.Conditions:Compile(value)
            elseif key == "name" then
                if action.type == "action_list" then action.listName = value
                elseif action.type == "variable" then action.varName = value
                else action.params[key] = value end
            elseif key == "value" and action.type == "variable" then
                action.varValue = value
                action.varValueAST = Hekolo.Conditions:Compile(value)
            elseif key == "op" then action.varOp = value
            else action.params[key] = value end
        end
    end
    return action
end

function APLParser:SplitAction(str)
    local parts = {}
    local current = ""
    local depth = 0
    for i = 1, #str do
        local ch = str:sub(i, i)
        if ch == "(" then depth = depth + 1; current = current .. ch
        elseif ch == ")" then depth = depth - 1; current = current .. ch
        elseif ch == "," and depth == 0 then
            table.insert(parts, strtrim(current)); current = ""
        else current = current .. ch end
    end
    if current ~= "" then table.insert(parts, strtrim(current)) end
    return parts
end

------------------------------------------------------------------------
-- Mock state for testing
------------------------------------------------------------------------

local MockState = {}
MockState.__index = MockState

function MockState:new(overrides)
    local s = setmetatable({}, MockState)
    s.health_pct = 100
    s.power_pct = 50
    s.target_health_pct = 80
    s.target_exists = true
    s.spell_targets = 1
    s.gcd_remains = 0
    s.gcd_duration = 1.5
    s.in_combat = true
    s.combo_points = 0
    s.variables = {}
    s._buffs = {}
    s._debuffs = {}
    s._cooldowns = {}
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

function MockState:GetBuff(name)
    return self._buffs[name] or { up = false, remains = 0, stacks = 0, duration = 0 }
end

function MockState:GetDebuff(name)
    return self._debuffs[name] or { up = false, remains = 0, stacks = 0, duration = 0 }
end

function MockState:GetCooldown(name)
    return self._cooldowns[name] or { remains = 0, charges = 1, max_charges = 1, duration = 0, ready = true }
end

------------------------------------------------------------------------
-- TEST SUITE
------------------------------------------------------------------------

print("=" .. string.rep("=", 60))
print("Hekolo Test Suite")
print("=" .. string.rep("=", 60))

-- Test 1: Tokenizer
print("\n--- Tokenizer Tests ---")

do
    local tokens = Conditions:Tokenize("buff.avatar.up&rage>=50")
    assert_eq(#tokens, 5, "Tokenize 'buff.avatar.up&rage>=50' produces 5 tokens")
    assert_eq(tokens[1].type, "ident", "First token is identifier")
    assert_eq(tokens[1].value, "buff.avatar.up", "First token value is 'buff.avatar.up'")
    assert_eq(tokens[2].type, "op", "Second token is operator")
    assert_eq(tokens[2].value, "&", "Second token is AND")
    assert_eq(tokens[3].type, "ident", "Third token is identifier")
    assert_eq(tokens[3].value, "rage", "Third token value is 'rage'")
    assert_eq(tokens[4].type, "op", "Fourth token is operator >=")
    assert_eq(tokens[4].value, ">=", "Fourth token is >=")
    assert_eq(tokens[5].type, "number", "Fifth token is number")
    assert_eq(tokens[5].value, 50, "Fifth token value is 50")
end

do
    local tokens = Conditions:Tokenize("!buff.enrage.up")
    assert_eq(#tokens, 2, "Tokenize '!buff.enrage.up' produces 2 tokens")
    assert_eq(tokens[1].value, "!", "First token is NOT operator")
    assert_eq(tokens[2].value, "buff.enrage.up", "Second token is variable")
end

do
    local tokens = Conditions:Tokenize("target.health.pct<20|buff.sudden_death.up")
    assert_eq(#tokens, 5, "Tokenize OR expression produces 5 tokens")
    assert_eq(tokens[4].value, "|", "OR operator found")
end

-- Test 2: Expression compiler
print("\n--- Compiler Tests ---")

do
    local ast = Conditions:Compile("1")
    assert_eq(ast.type, "literal", "Compile literal '1' -> literal node")
    assert_eq(ast.value, 1, "Literal value is 1")
end

do
    local ast = Conditions:Compile("buff.avatar.up")
    assert_eq(ast.type, "variable", "Compile variable -> variable node")
    assert_eq(ast.value, "buff.avatar.up", "Variable name preserved")
end

do
    local ast = Conditions:Compile("rage>=50")
    assert_eq(ast.type, "binop", "Compile comparison -> binop")
    assert_eq(ast.op, ">=", "Operator is >=")
    assert_eq(ast.left.value, "rage", "Left side is 'rage'")
    assert_eq(ast.right.value, 50, "Right side is 50")
end

do
    local ast = Conditions:Compile("!buff.enrage.up")
    assert_eq(ast.type, "unary", "Compile NOT -> unary node")
    assert_eq(ast.op, "!", "Operator is !")
end

do
    local ast = Conditions:Compile("a&b|c")
    -- Should parse as (a & b) | c due to precedence
    assert_eq(ast.type, "binop", "Complex expression parsed")
    assert_eq(ast.op, "|", "Top-level op is OR")
    assert_eq(ast.left.op, "&", "Left subtree op is AND")
end

-- Test 3: Expression evaluation with mock state
print("\n--- Evaluation Tests ---")

do
    local state = MockState:new({ power_pct = 80 })
    local ast = Conditions:Compile("rage>=50")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "rage>=50 with 80% power -> true (approx 80 rage)")
end

do
    local state = MockState:new({ power_pct = 30 })
    local ast = Conditions:Compile("rage>=50")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 0, "rage>=50 with 30% power -> false (approx 30 rage)")
end

do
    local state = MockState:new()
    state._buffs["avatar"] = { up = true, remains = 5.0, stacks = 1, duration = 20 }
    local ast = Conditions:Compile("buff.avatar.up")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "buff.avatar.up when buff is active -> true")
end

do
    local state = MockState:new()
    local ast = Conditions:Compile("buff.avatar.up")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 0, "buff.avatar.up when buff is NOT active -> false")
end

do
    local state = MockState:new()
    state._buffs["avatar"] = { up = true, remains = 5.0, stacks = 1, duration = 20 }
    local ast = Conditions:Compile("buff.avatar.down")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 0, "buff.avatar.down when buff IS active -> false")
end

do
    local state = MockState:new()
    state._buffs["enrage"] = { up = true, remains = 3.0, stacks = 1, duration = 8 }
    local ast = Conditions:Compile("!buff.enrage.up")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 0, "!buff.enrage.up when enrage IS active -> false")
end

do
    local state = MockState:new()
    local ast = Conditions:Compile("!buff.enrage.up")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "!buff.enrage.up when enrage is NOT active -> true")
end

do
    local state = MockState:new({ target_health_pct = 15 })
    local ast = Conditions:Compile("target.health.pct<20")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "target.health.pct<20 when target at 15% -> true")
end

do
    local state = MockState:new({ target_health_pct = 80 })
    local ast = Conditions:Compile("target.health.pct<20")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 0, "target.health.pct<20 when target at 80% -> false")
end

do
    local state = MockState:new({ target_health_pct = 15 })
    state._buffs["sudden_death"] = { up = true, remains = 5, stacks = 1, duration = 10 }
    local ast = Conditions:Compile("target.health.pct<20|buff.sudden_death.up")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "OR condition: both true -> true")
end

do
    local state = MockState:new({ target_health_pct = 80 })
    state._buffs["sudden_death"] = { up = true, remains = 5, stacks = 1, duration = 10 }
    local ast = Conditions:Compile("target.health.pct<20|buff.sudden_death.up")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "OR condition: second true -> true")
end

do
    local state = MockState:new({ target_health_pct = 80 })
    local ast = Conditions:Compile("target.health.pct<20|buff.sudden_death.up")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 0, "OR condition: both false -> false")
end

do
    local state = MockState:new({ spell_targets = 3 })
    local ast = Conditions:Compile("spell_targets>1")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "spell_targets>1 with 3 targets -> true")
end

do
    local state = MockState:new({ spell_targets = 1 })
    local ast = Conditions:Compile("spell_targets>1")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 0, "spell_targets>1 with 1 target -> false")
end

-- Test 4: Cooldown conditions
print("\n--- Cooldown Condition Tests ---")

do
    local state = MockState:new()
    state._cooldowns["colossus_smash"] = { remains = 2.0, charges = 0, max_charges = 1, duration = 30, ready = false }
    local ast = Conditions:Compile("cooldown.colossus_smash.remains<3")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "cooldown.colossus_smash.remains<3 with 2s remaining -> true")
end

do
    local state = MockState:new()
    state._cooldowns["colossus_smash"] = { remains = 10.0, charges = 0, max_charges = 1, duration = 30, ready = false }
    local ast = Conditions:Compile("cooldown.colossus_smash.remains<3")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 0, "cooldown.colossus_smash.remains<3 with 10s remaining -> false")
end

do
    local state = MockState:new()
    state._cooldowns["recklessness"] = { remains = 0, charges = 1, max_charges = 1, duration = 90, ready = true }
    local ast = Conditions:Compile("cooldown.recklessness.ready")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "cooldown.recklessness.ready when off cooldown -> true")
end

-- Test 5: Debuff conditions
print("\n--- Debuff Condition Tests ---")

do
    local state = MockState:new()
    state._debuffs["colossus_smash"] = { up = true, remains = 4.0, stacks = 1, duration = 10 }
    local ast = Conditions:Compile("debuff.colossus_smash.up")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "debuff.colossus_smash.up when debuff active -> true")
end

do
    local state = MockState:new()
    local ast = Conditions:Compile("debuff.colossus_smash.down")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 1, "debuff.colossus_smash.down when debuff not active -> true")
end

-- Test 6: Arithmetic
print("\n--- Arithmetic Tests ---")

do
    local state = MockState:new()
    local ast = Conditions:Compile("3+5")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 8, "3+5 = 8")
end

do
    local state = MockState:new()
    local ast = Conditions:Compile("10-3")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 7, "10-3 = 7")
end

do
    local state = MockState:new()
    local ast = Conditions:Compile("4*3")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 12, "4*3 = 12")
end

do
    local state = MockState:new()
    local ast = Conditions:Compile("2+3*4")
    local result = Conditions:Evaluate(ast, state)
    assert_eq(result, 14, "2+3*4 = 14 (respects precedence)")
end

-- Test 7: APL Parser
print("\n--- APL Parser Tests ---")

do
    local apl = APLParser:Parse([[
actions+=/mortal_strike,if=debuff.colossus_smash.up
actions+=/execute,if=target.health.pct<20
actions+=/slam
]])
    assert_true(apl ~= nil, "APL parsed successfully")
    assert_true(apl["default"] ~= nil, "Default action list exists")
    assert_eq(#apl["default"], 3, "Default list has 3 actions")
    assert_eq(apl["default"][1].name, "mortal_strike", "First action is mortal_strike")
    assert_eq(apl["default"][1].conditionStr, "debuff.colossus_smash.up", "First action has condition")
    assert_eq(apl["default"][2].name, "execute", "Second action is execute")
    assert_eq(apl["default"][3].name, "slam", "Third action is slam")
    assert_eq(apl["default"][3].conditions, nil, "Third action has no conditions")
end

do
    local apl = APLParser:Parse([[
actions+=/avatar,if=cooldown.colossus_smash.remains<3|buff.test_of_might.up
actions.cleave+=/whirlwind,if=spell_targets>2
actions.cleave+=/bladestorm
]])
    assert_true(apl["default"] ~= nil, "Default list exists")
    assert_true(apl["cleave"] ~= nil, "Cleave action list exists")
    assert_eq(#apl["default"], 1, "Default list has 1 action")
    assert_eq(#apl["cleave"], 2, "Cleave list has 2 actions")
    assert_eq(apl["cleave"][1].name, "whirlwind", "Cleave first action is whirlwind")
end

do
    -- Test comments and empty lines are skipped
    local apl = APLParser:Parse([[
# This is a comment
actions+=/mortal_strike

# Another comment
actions+=/slam
]])
    assert_eq(#apl["default"], 2, "Comments and blank lines are skipped")
end

do
    -- Test action list references
    local apl = APLParser:Parse([[
actions+=/run_action_list,name=cleave,if=spell_targets>1
actions+=/mortal_strike
actions.cleave+=/whirlwind
]])
    assert_eq(apl["default"][1].type, "action_list", "run_action_list parsed correctly")
    assert_eq(apl["default"][1].listName, "cleave", "Action list name is 'cleave'")
end

do
    -- Test skip actions
    local apl = APLParser:Parse([[
actions+=/potion,name=potion_of_spectral_strength
actions+=/auto_attack
actions+=/mortal_strike
]])
    assert_eq(apl["default"][1].type, "skip", "Potion is skip type")
    assert_eq(apl["default"][2].type, "skip", "Auto attack is skip type")
    assert_eq(apl["default"][3].type, "spell", "Mortal strike is spell type")
end

do
    -- Test variable actions
    local apl = APLParser:Parse([[
actions+=/variable,name=use_cooldowns,value=1,op=set
]])
    assert_eq(apl["default"][1].type, "variable", "Variable action type")
    assert_eq(apl["default"][1].varName, "use_cooldowns", "Variable name parsed")
    assert_eq(apl["default"][1].varOp, "set", "Variable op parsed")
end

-- Test 8: Complex APL (Arms Warrior)
print("\n--- Complex APL Test ---")

do
    local aplString = [[
# Arms Warrior APL
actions+=/avatar,if=cooldown.colossus_smash.remains<3|buff.test_of_might.up
actions+=/sweeping_strikes,if=spell_targets>1
actions+=/colossus_smash,if=debuff.colossus_smash.down
actions+=/rend,if=debuff.rend.remains<4&target.time_to_die>8
actions+=/overpower,if=buff.overpower.stack<2
actions+=/mortal_strike,if=debuff.colossus_smash.up|buff.sudden_death.up
actions+=/execute,if=target.health.pct<20|buff.sudden_death.up
actions+=/overpower
actions+=/slam,if=rage>50
actions+=/bladestorm,if=spell_targets>2|debuff.colossus_smash.up
]]
    local apl = APLParser:Parse(aplString)
    assert_true(apl ~= nil, "Full Arms APL parsed")
    assert_eq(#apl["default"], 10, "Arms APL has 10 actions")

    -- Verify each action parsed correctly
    assert_eq(apl["default"][1].name, "avatar", "Action 1: avatar")
    assert_true(apl["default"][1].conditions ~= nil, "Avatar has conditions")
    assert_eq(apl["default"][4].name, "rend", "Action 4: rend")
    assert_eq(apl["default"][7].name, "execute", "Action 7: execute")
    assert_eq(apl["default"][10].name, "bladestorm", "Action 10: bladestorm")
end

-- Test 9: Combined condition + state evaluation (integration)
print("\n--- Integration Tests ---")

do
    -- Simulate: Arms Warrior, Colossus Smash debuff down, avatar cd almost ready
    local state = MockState:new({ power_pct = 70, target_health_pct = 80, spell_targets = 1 })
    state._cooldowns["colossus_smash"] = { remains = 2.0, charges = 0, max_charges = 1, duration = 30, ready = false }
    state._debuffs["colossus_smash"] = nil -- debuff is down

    -- Test: "cooldown.colossus_smash.remains<3" should be true
    local ast1 = Conditions:Compile("cooldown.colossus_smash.remains<3")
    assert_eq(Conditions:Evaluate(ast1, state), 1, "Integration: CD check passes")

    -- Test: "debuff.colossus_smash.down" should be true (debuff not present)
    local ast2 = Conditions:Compile("debuff.colossus_smash.down")
    assert_eq(Conditions:Evaluate(ast2, state), 1, "Integration: Debuff down check passes")

    -- Test: "rage>50" should be true (70% * 100 = 70 rage)
    local ast3 = Conditions:Compile("rage>50")
    assert_eq(Conditions:Evaluate(ast3, state), 1, "Integration: Rage check passes")
end

do
    -- Test empty/nil expression
    local ast = Conditions:Compile("")
    assert_eq(ast.type, "literal", "Empty expression -> literal 1 (always true)")
    assert_eq(ast.value, 1, "Empty expression value = 1")
end

do
    local ast = Conditions:Compile(nil)
    assert_eq(ast.type, "literal", "nil expression -> literal 1 (always true)")
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
