------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Engine/Conditions.lua - SimC expression evaluator
--
-- Evaluates SimC-style condition expressions against the current state.
-- E.g.: "buff.avatar.up&cooldown.colossus_smash.remains<3&rage>=50"
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.Conditions = {}

local Conditions = Hekolo.Conditions

------------------------------------------------------------------------
-- Tokenizer: splits a SimC expression into tokens
------------------------------------------------------------------------

function Conditions:Tokenize(expr)
    local tokens = {}
    local i = 1
    local len = #expr

    while i <= len do
        local ch = expr:sub(i, i)

        -- Skip whitespace
        if ch == " " or ch == "\t" then
            i = i + 1

        -- Operators
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
            -- SimC uses % for division (not modulo); map to /
            table.insert(tokens, { type = "op", value = "/" })
            i = i + 1
        elseif ch == "(" then
            table.insert(tokens, { type = "lparen" })
            i = i + 1
        elseif ch == ")" then
            table.insert(tokens, { type = "rparen" })
            i = i + 1

        -- Numbers
        elseif ch:match("%d") or (ch == "." and expr:sub(i + 1, i + 1):match("%d")) then
            local numStr = ""
            while i <= len and (expr:sub(i, i):match("[%d%.]")) do
                numStr = numStr .. expr:sub(i, i)
                i = i + 1
            end
            table.insert(tokens, { type = "number", value = tonumber(numStr) or 0 })

        -- Identifiers (variable references like buff.avatar.up)
        elseif ch:match("[%a_]") then
            local ident = ""
            while i <= len and expr:sub(i, i):match("[%w_%.]") do
                ident = ident .. expr:sub(i, i)
                i = i + 1
            end
            table.insert(tokens, { type = "ident", value = ident })

        else
            -- Skip unknown characters
            i = i + 1
        end
    end

    return tokens
end

------------------------------------------------------------------------
-- Expression parser: recursive descent for SimC expressions
-- Precedence (low to high):
--   |  (OR)
--   &  (AND)
--   = != < > <= >=  (comparison)
--   + -  (additive)
--   * /  (multiplicative)
--   !  (unary NOT)
--   atoms (numbers, identifiers, parenthesized expressions)
------------------------------------------------------------------------

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

-- Parse full expression (entry point)
function Parser:parseExpression()
    return self:parseOr()
end

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
        if op == "=" then op = "==" end -- SimC uses single = for comparison
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
        else
            break
        end
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
        else
            break
        end
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
    -- Parenthesized expression
    if self:match("lparen") then
        local expr = self:parseExpression()
        self:match("rparen") -- consume closing paren
        return expr
    end

    -- Number literal
    local num = self:match("number")
    if num then
        return { type = "literal", value = num.value }
    end

    -- Identifier (variable reference)
    local ident = self:match("ident")
    if ident then
        return { type = "variable", value = ident.value }
    end

    -- If we reach here, return a default (0)
    return { type = "literal", value = 0 }
end

------------------------------------------------------------------------
-- Compile expression string into AST
------------------------------------------------------------------------

function Conditions:Compile(exprString)
    if not exprString or exprString == "" then
        return { type = "literal", value = 1 } -- always true
    end

    local tokens = self:Tokenize(exprString)
    if #tokens == 0 then
        return { type = "literal", value = 1 }
    end

    local parser = Parser:new(tokens)
    local ast = parser:parseExpression()
    return ast
end

------------------------------------------------------------------------
-- Evaluate compiled AST against current state
------------------------------------------------------------------------

function Conditions:Evaluate(ast, state)
    if not ast then return true end

    if ast.type == "literal" then
        return ast.value

    elseif ast.type == "variable" then
        return self:ResolveVariable(ast.value, state)

    elseif ast.type == "unary" then
        local val = self:Evaluate(ast.operand, state)
        if ast.op == "!" then
            return self:IsTrue(val) and 0 or 1
        end

    elseif ast.type == "binop" then
        if ast.op == "&" then
            local left = self:Evaluate(ast.left, state)
            if not self:IsTrue(left) then return 0 end
            local right = self:Evaluate(ast.right, state)
            return self:IsTrue(right) and 1 or 0

        elseif ast.op == "|" then
            local left = self:Evaluate(ast.left, state)
            if self:IsTrue(left) then return 1 end
            local right = self:Evaluate(ast.right, state)
            return self:IsTrue(right) and 1 or 0

        else
            local left = self:Evaluate(ast.left, state)
            local right = self:Evaluate(ast.right, state)
            left = tonumber(left) or 0
            right = tonumber(right) or 0

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

------------------------------------------------------------------------
-- Truthy check
------------------------------------------------------------------------

function Conditions:IsTrue(value)
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value ~= 0 end
    return value ~= nil and value ~= false
end

------------------------------------------------------------------------
-- Variable resolution: maps SimC variable names to state values
------------------------------------------------------------------------

function Conditions:ResolveVariable(name, state)
    if not name or not state then return 0 end

    -- Split on dots: e.g. "buff.avatar.up" -> { "buff", "avatar", "up" }
    local parts = {}
    for part in name:gmatch("[^%.]+") do
        table.insert(parts, part)
    end

    local category = parts[1]
    local subject = parts[2]
    local property = parts[3]

    -- buff.<name>.<property>
    if category == "buff" and subject then
        local buff = state:GetBuff(subject)
        if not property or property == "up" then
            return buff.up and 1 or 0
        elseif property == "down" then
            return buff.up and 0 or 1
        elseif property == "remains" then
            return buff.remains
        elseif property == "stack" or property == "stacks" then
            return buff.stacks
        elseif property == "duration" then
            return buff.duration
        elseif property == "react" then
            return buff.stacks -- react = stacks for proc buffs
        end
        return 0
    end

    -- debuff.<name>.<property>
    if category == "debuff" and subject then
        local debuff = state:GetDebuff(subject)
        if not property or property == "up" then
            return debuff.up and 1 or 0
        elseif property == "down" then
            return debuff.up and 0 or 1
        elseif property == "remains" then
            return debuff.remains
        elseif property == "stack" or property == "stacks" then
            return debuff.stacks
        elseif property == "duration" then
            return debuff.duration
        end
        return 0
    end

    -- cooldown.<name>.<property>
    if category == "cooldown" and subject then
        local cd = state:GetCooldown(subject)
        if not property or property == "remains" then
            return cd.remains
        elseif property == "ready" or property == "up" then
            return cd.ready and 1 or 0
        elseif property == "charges" then
            return cd.charges
        elseif property == "max_charges" then
            return cd.max_charges
        elseif property == "duration" then
            return cd.duration
        elseif property == "charges_fractional" then
            if cd.max_charges > 1 and cd.duration > 0 then
                local fractional = cd.charges + (1 - (cd.remains / cd.duration))
                return math.min(cd.max_charges, math.max(0, fractional))
            end
            return cd.charges
        end
        return 0
    end

    -- dot.<name>.<property> (alias for debuff)
    if category == "dot" and subject then
        local debuff = state:GetDebuff(subject)
        if not property or property == "up" or property == "ticking" then
            return debuff.up and 1 or 0
        elseif property == "remains" then
            return debuff.remains
        elseif property == "stack" or property == "stacks" then
            return debuff.stacks
        elseif property == "duration" then
            return debuff.duration
        end
        return 0
    end

    -- talent.<name>.enabled  (simplified: assume all are enabled for now)
    if category == "talent" and subject then
        return 1 -- assume talent is taken
    end

    -- target.<property>
    if category == "target" then
        if subject == "health" then
            if property == "pct" or property == "percent" then
                return state.target_health_pct
            end
        elseif subject == "time_to_die" then
            -- Estimate based on health percentage, assume 60s fight baseline
            return math.max(1, state.target_health_pct * 0.6)
        elseif subject == "distance" then
            return 5 -- assume melee range
        end
        return 0
    end

    -- spell_targets / active_enemies
    if category == "spell_targets" or name == "active_enemies" then
        return state.spell_targets
    end

    -- gcd
    if category == "gcd" then
        if subject == "remains" then
            return state.gcd_remains
        elseif subject == "max" or subject == "duration" then
            return state.gcd_duration
        end
        return state.gcd_duration
    end

    -- resource / rage / energy / fury etc.
    if category == "rage" or category == "energy" or category == "fury"
        or category == "focus" or category == "runic_power" or category == "pain"
        or category == "maelstrom" or category == "insanity" or category == "holy_power"
        or category == "soul_shards" or category == "chi" or category == "combo_points"
        or category == "arcane_charges" or category == "lunar_power"
        or category == "mana" or category == "essence" then
        -- In 12.0, we work with percentages; translate to approximate values
        -- SimC conditions often use raw numbers, we approximate
        if not subject or subject == "current" then
            return self:GetResourceValue(category, state)
        elseif subject == "pct" or subject == "percent" then
            return state.power_pct
        elseif subject == "deficit" then
            return self:GetResourceMax(category) - self:GetResourceValue(category, state)
        elseif subject == "max" then
            return self:GetResourceMax(category)
        end
        return self:GetResourceValue(category, state)
    end

    -- health
    if category == "health" then
        if subject == "pct" or subject == "percent" then
            return state.health_pct
        end
        return state.health_pct
    end

    -- combo_points (also as standalone variable)
    if name == "combo_points" then
        return state.combo_points
    end

    -- time (combat time)
    if name == "time" then
        return state.time - (state.combat_start or state.time)
    end

    -- True/false literals
    if name == "true" then return 1 end
    if name == "false" then return 0 end

    -- Prev GCD tracking (simplified)
    if category == "prev_gcd" or category == "prev" then
        return 0 -- Not fully trackable in 12.0, default to false
    end

    -- Variable references (custom variables from APL)
    if category == "variable" and subject then
        -- Custom variables stored in state
        if state.variables and state.variables[subject] then
            return state.variables[subject]
        end
        return 0
    end

    -- Unknown variable
    Hekolo:Debug("Unknown condition variable: " .. name)
    return 0
end

------------------------------------------------------------------------
-- Resource value approximation (from percentage)
------------------------------------------------------------------------

function Conditions:GetResourceValue(category, state)
    -- Convert percentage to approximate raw values based on resource type
    local maxVal = self:GetResourceMax(category)
    return math.floor(state.power_pct * maxVal / 100)
end

function Conditions:GetResourceMax(category)
    -- Typical max values for different resources
    local maxValues = {
        rage = 100,
        energy = 100,
        focus = 100,
        fury = 120,
        pain = 100,
        mana = 100,  -- percentage-based
        runic_power = 125,
        maelstrom = 100,
        insanity = 100,
        holy_power = 5,
        soul_shards = 5,
        chi = 5,
        combo_points = 7,
        arcane_charges = 4,
        lunar_power = 100,
        essence = 5,
    }
    return maxValues[category] or 100
end
