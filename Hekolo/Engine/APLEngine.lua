------------------------------------------------------------------------
-- Hekolo - Rotation Helper for WoW 12.0 (Midnight)
-- Engine/APLEngine.lua - APL evaluation engine
--
-- Iterates through parsed action lists and evaluates each action's
-- conditions against the current game state to determine which
-- abilities should be recommended.
------------------------------------------------------------------------

local addonName, Hekolo = ...

Hekolo.APLEngine = {}

local APLEngine = Hekolo.APLEngine

-- Maximum recommendations to return per evaluation
local MAX_RECOMMENDATIONS = 4

------------------------------------------------------------------------
-- Evaluate an APL against current state
-- Returns a list of recommended actions: { {name, spellID, icon}, ... }
------------------------------------------------------------------------

function APLEngine:Evaluate(apl, state)
    if not apl or not apl.actions then return {} end

    -- Initialize variables table for this evaluation pass
    state.variables = state.variables or {}

    -- Result list
    local recommendations = {}

    -- Start with the default action list
    local defaultList = apl.actions["default"]
    if not defaultList then
        -- Try the first available list
        for listName, actions in pairs(apl.actions) do
            if listName ~= "precombat" then
                defaultList = actions
                break
            end
        end
    end

    if not defaultList then return {} end

    -- Walk through the action list
    self:EvaluateList(defaultList, apl.actions, state, recommendations, 0)

    return recommendations
end

------------------------------------------------------------------------
-- Evaluate a single action list
------------------------------------------------------------------------

function APLEngine:EvaluateList(actionList, allLists, state, recommendations, depth)
    if depth > 10 then return false end -- prevent infinite recursion
    if #recommendations >= MAX_RECOMMENDATIONS then return true end

    for _, action in ipairs(actionList) do
        if #recommendations >= MAX_RECOMMENDATIONS then return true end

        local result = self:EvaluateAction(action, allLists, state, recommendations, depth)
        if result == "stop" then
            return true -- run_action_list stops processing of the calling list
        end
    end

    return false
end

------------------------------------------------------------------------
-- Evaluate a single action
------------------------------------------------------------------------

function APLEngine:EvaluateAction(action, allLists, state, recommendations, depth)
    if not action then return nil end

    -- Skip non-combat actions
    if action.type == "skip" then
        return nil
    end

    -- Handle variable definitions
    if action.type == "variable" then
        self:HandleVariable(action, state)
        return nil
    end

    -- Check conditions
    if action.conditions then
        local condResult = Hekolo.Conditions:Evaluate(action.conditions, state)
        if not Hekolo.Conditions:IsTrue(condResult) then
            return nil -- conditions not met, skip this action
        end
    end

    -- Handle action list calls
    if action.type == "action_list" then
        local listName = action.listName
        if listName and allLists[listName] then
            local stopped = self:EvaluateList(allLists[listName], allLists, state, recommendations, depth + 1)
            if action.name == "run_action_list" and stopped then
                return "stop"
            end
        end
        return nil
    end

    -- Handle item usage
    if action.type == "item" then
        -- Item use is limited in 12.0, skip for now
        return nil
    end

    -- Regular spell action
    if action.type == "spell" then
        local spellName = action.name
        local specID = Hekolo.playerSpecID
        local spellData = specID and Hekolo.SpellData[specID]

        if spellData then
            local spellID = spellData[spellName]
            if spellID then
                -- Check if spell is on cooldown
                local cd = state:GetCooldown(spellName)
                if cd.ready or cd.remains <= state.gcd_remains then
                    -- Check if spell is usable (resource cost, etc.)
                    if state:IsSpellUsable(spellID) then
                        local icon = self:GetSpellIcon(spellID)
                        table.insert(recommendations, {
                            name = spellName,
                            spellID = spellID,
                            icon = icon,
                        })
                        -- If we're at max recommendations, stop
                        if #recommendations >= MAX_RECOMMENDATIONS then
                            return "stop"
                        end
                    end
                end
            else
                Hekolo:Debug("Unknown spell in APL: " .. tostring(spellName))
            end
        end
    end

    return nil
end

------------------------------------------------------------------------
-- Handle APL variable set/compute
------------------------------------------------------------------------

function APLEngine:HandleVariable(action, state)
    if not action.varName then return end

    local op = action.varOp or "set"
    local value = 0

    if action.varValueAST then
        value = Hekolo.Conditions:Evaluate(action.varValueAST, state)
    end

    state.variables = state.variables or {}

    if op == "set" or op == "setif" then
        -- For setif, also check the conditions
        if op == "setif" and action.conditions then
            local condResult = Hekolo.Conditions:Evaluate(action.conditions, state)
            if Hekolo.Conditions:IsTrue(condResult) then
                state.variables[action.varName] = value
            end
        else
            state.variables[action.varName] = value
        end
    elseif op == "add" then
        state.variables[action.varName] = (state.variables[action.varName] or 0) + value
    elseif op == "sub" then
        state.variables[action.varName] = (state.variables[action.varName] or 0) - value
    elseif op == "min" then
        local current = state.variables[action.varName] or value
        state.variables[action.varName] = math.min(current, value)
    elseif op == "max" then
        local current = state.variables[action.varName] or value
        state.variables[action.varName] = math.max(current, value)
    elseif op == "reset" then
        state.variables[action.varName] = 0
    end
end

------------------------------------------------------------------------
-- Get spell icon texture
------------------------------------------------------------------------

function APLEngine:GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    elseif GetSpellTexture then
        return GetSpellTexture(spellID)
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end
