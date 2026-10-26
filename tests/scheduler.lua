-- Loaded after core modules and bootstrap; uses actual rules/movement/world APIs.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local services = {
    evaluate = function(world)
        local lines, read_error = RW_ReadLines(world)
        if not lines then return nil, read_error end
        local ast, parse_error = RW_ParseRuleAST(lines, world.language)
        if not ast then return nil, parse_error end
        local generated, deferred, conversions = RW_LowerRuleAST(ast, world.semantics)
        if not generated then return nil, deferred end
        local effects, rule_error = RW_EvaluateRules(world, generated)
        return effects, rule_error, conversions
    end,
    project = RW_ProjectWorld, resolve = RW_ResolveTurn,
    preview = RW_PreviewPlan, convert = RW_PlanConversions
}
local s = RW_CreateSession()
s.world.entities[8].text.name = "AVATAR" -- CRATE IS AVATAR
s.world.entities[4].direction = "Mid"
local before = copy(s)
local action = {type = "move", dx = 0, dy = -1}
local plan, planning_error, trace = RW_PlanTurn(s.world, action, services)
assert(plan and not planning_error)
assert(table.concat(trace, ",") ==
    "rules_before,project,movement,preview_movement,rules_after,conversions,preview_complete")
assert(equal(s, before), "Planning mutated authoritative state")
local completed, result = RW_Commit(s, plan)
assert(result.accepted and #completed.history == 1)
assert(completed.world.entities[1].y == 1 and completed.world.entities[1].direction == "Up")
assert(completed.world.entities[4].archetype == "avatar")
assert(completed.world.entities[4].direction == "Mid", "Conversion lost intrinsic direction")
assert(completed.world.entities[5].archetype == "avatar")
local restored = RW_Undo(completed)
assert(equal(restored, s), "Whole scheduled turn did not Undo")

-- Fail at every boundary, including the SECOND evaluation/preview.
for _, failure in ipairs({
    {"evaluate", 1, "rules_before"}, {"project", 1, "project"},
    {"resolve", 1, "movement"}, {"preview", 1, "preview_movement"},
    {"evaluate", 2, "rules_after"}, {"convert", 1, "conversions"},
    {"preview", 2, "preview_complete"}
}) do
    local adapted, calls, reached_failure = {}, {}, false
    for name, service in pairs(services) do
        adapted[name] = function(...)
            assert(not reached_failure, "Ran another stage after failure")
            calls[name] = (calls[name] or 0) + 1
            if name == failure[1] and calls[name] == failure[2] then
                reached_failure = true
                return nil, "injected_failure"
            end
            return service(...)
        end
    end
    local failed, problem = RW_PlanTurn(s.world, action, adapted)
    assert(not failed and problem.stage == failure[3] and problem.reason == "injected_failure")
    assert(reached_failure and equal(s, before), "Failure leaked a partial turn")
end

-- Invalid combined operation is caught before the host can Commit.
local invalid_conversion = {}
for k, v in pairs(services) do invalid_conversion[k] = v end
invalid_conversion.convert = function()
    return {{kind = "transform", entity_id = 4, from = "rock", to = "avatar"}}
end
local bad, error_info = RW_PlanTurn(s.world, action, invalid_conversion)
assert(not bad and error_info.stage == "preview_complete"
    and error_info.reason == "stale_transformation" and equal(s, before))

-- Invalid input skips conversion; effective empty turns retain existing semantics.
local invalid = assert(RW_PlanTurn(s.world, {type = "move", dx = 2, dy = 0}, services))
assert(not invalid.consumes_turn)
local unchanged, rejection = RW_Commit(s, invalid)
assert(unchanged == s and not rejection.accepted)
local nobody = RW_CreateSession()
nobody.world.entities[11].text.name = "PUSH"
local empty = assert(RW_PlanTurn(nobody.world, action, services))
local recorded, empty_result = RW_Commit(nobody, empty)
assert(empty.reason == "no_you" and empty_result.accepted and not empty_result.changed
    and #recorded.history == 1)

-- Keep subplanner-owned lists separate from combined plans.
local captured
local observing = {}
for k, v in pairs(services) do observing[k] = v end
observing.resolve = function(...)
    captured = RW_ResolveTurn(...)
    return captured
end
local combined = assert(RW_PlanTurn(s.world, action, observing))
assert(#captured.changes == 1 and #combined.changes == 3)
assert(equal(s, before))
print("PASS: scheduler atomic conversion/Undo, every failure boundary, complete validation, empty turns")
