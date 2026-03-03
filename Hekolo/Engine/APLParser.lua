------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Engine/APLParser.lua - SimulationCraft APL string parser
--
-- Parses SimC APL text format into structured action lists.
-- Format: actions[.listname]+=/spell_name[,param=value][,if=condition]
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.APLParser = {}

local APLParser = Hekolo.APLParser

------------------------------------------------------------------------
-- Parse a full APL string into action lists
------------------------------------------------------------------------

function APLParser:Parse(aplText)
    if not aplText or aplText == "" then return nil end

    -- Result: table of action lists
    -- { default = { {action=..., conditions=..., ...}, ... },
    --   precombat = { ... },
    --   aoe = { ... } }
    local actionLists = {}

    for line in aplText:gmatch("[^\r\n]+") do
        line = strtrim(line)

        -- Skip comments and empty lines
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local listName, actionStr = self:ParseLine(line)
            if listName and actionStr then
                if not actionLists[listName] then
                    actionLists[listName] = {}
                end
                local action = self:ParseAction(actionStr)
                if action then
                    table.insert(actionLists[listName], action)
                end
            end
        end
    end

    return actionLists
end

------------------------------------------------------------------------
-- Parse a single APL line to extract list name and action string
-- Format: actions[.listname]+=/actionstring
-- or:     actions[.listname]=/actionstring (first action, resets list)
------------------------------------------------------------------------

function APLParser:ParseLine(line)
    -- Match: actions.listname+=/... or actions+=/... or actions=/...
    local listName, actionStr

    -- Pattern: actions.xxx+=/yyy or actions.xxx=/yyy
    listName, actionStr = line:match("^actions%.([%w_]+)%+?=/(.+)$")
    if listName and actionStr then
        return listName, strtrim(actionStr)
    end

    -- Pattern: actions+=/yyy or actions=/yyy (default list)
    actionStr = line:match("^actions%+?=/(.+)$")
    if actionStr then
        return "default", strtrim(actionStr)
    end

    return nil, nil
end

------------------------------------------------------------------------
-- Parse an action string into structured action data
-- Format: spell_name,param1=val1,param2=val2,if=condition
------------------------------------------------------------------------

function APLParser:ParseAction(actionStr)
    if not actionStr or actionStr == "" then return nil end

    local action = {
        type = "spell",      -- spell, run_action_list, call_action_list, variable, etc.
        name = nil,          -- spell/action name
        conditions = nil,    -- compiled condition AST
        conditionStr = nil,  -- raw condition string for debugging
        params = {},         -- additional parameters
    }

    -- Split by commas, but be careful with nested expressions
    local parts = self:SplitAction(actionStr)

    if #parts == 0 then return nil end

    -- First part is the action/spell name
    action.name = parts[1]

    -- Determine action type
    if action.name == "run_action_list" or action.name == "call_action_list" then
        action.type = "action_list"
    elseif action.name == "variable" then
        action.type = "variable"
    elseif action.name == "potion" or action.name == "food" or action.name == "flask"
        or action.name == "augmentation" or action.name == "snapshot_stats" then
        action.type = "skip" -- non-combat actions we don't need
    elseif action.name == "auto_attack" then
        action.type = "skip"
    elseif action.name == "use_item" or action.name == "use_items" then
        action.type = "item"
    else
        action.type = "spell"
    end

    -- Parse remaining parameters
    for i = 2, #parts do
        local key, value = parts[i]:match("^([%w_]+)=(.+)$")
        if key and value then
            if key == "if" then
                action.conditionStr = value
                action.conditions = Hekolo.Conditions:Compile(value)
            elseif key == "name" then
                if action.type == "action_list" then
                    action.listName = value
                elseif action.type == "variable" then
                    action.varName = value
                else
                    action.params[key] = value
                end
            elseif key == "value" then
                if action.type == "variable" then
                    action.varValue = value
                    action.varValueAST = Hekolo.Conditions:Compile(value)
                else
                    action.params[key] = value
                end
            elseif key == "op" then
                action.varOp = value
            elseif key == "target_if" then
                -- target_if conditions are simplified
                action.params[key] = value
            elseif key == "cycle_targets" then
                action.params[key] = value
            else
                action.params[key] = value
            end
        end
    end

    return action
end

------------------------------------------------------------------------
-- Split action string by commas, respecting parentheses in conditions
------------------------------------------------------------------------

function APLParser:SplitAction(str)
    local parts = {}
    local current = ""
    local depth = 0

    for i = 1, #str do
        local ch = str:sub(i, i)
        if ch == "(" then
            depth = depth + 1
            current = current .. ch
        elseif ch == ")" then
            depth = depth - 1
            current = current .. ch
        elseif ch == "," and depth == 0 then
            table.insert(parts, strtrim(current))
            current = ""
        else
            current = current .. ch
        end
    end

    if current ~= "" then
        table.insert(parts, strtrim(current))
    end

    return parts
end

------------------------------------------------------------------------
-- Utility: normalize a SimC spell name to our internal format
-- "Mortal Strike" -> "mortal_strike"
------------------------------------------------------------------------

function APLParser:NormalizeSpellName(name)
    if not name then return nil end
    return name:lower():gsub("%s+", "_"):gsub("[^%w_]", "")
end
