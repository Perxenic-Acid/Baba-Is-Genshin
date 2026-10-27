local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local s = RW_CreateSession()
local valid = {kind = "object", class = "text", x = 2, y = 3,
    direction = "None", text = {name = "PUSH"}}
local baseline_id = s.world.next_entity_id
local plan = assert(RW_PlanCreate(s.world, {valid}))
local function must_reject(candidate)
    local unchanged, result = RW_Commit(s, candidate)
    assert(not result.accepted and unchanged == s, "Invalid lifecycle plan accepted")
    assert(RW_PreviewPlan(s.world, candidate) == nil)
    assert(s.world.next_entity_id == baseline_id and s.world.entities[12] == nil)
end
-- Validate both planner input and tampered raw operations.
for _, mutation in ipairs({
    function(e) e.id = 99 end,
    function(e) e.x = 0 end,
    function(e) e.x = 1.5 end,
    function(e) e.y = 13 end,
    function(e) e.direction = "North" end,
    function(e) e.kind = "text" end,
    function(e) e.class = "other" end,
    function(e) e.text.name = "" end,
    function(e) e.traits = {pushable = true} end,
    function(e) e.behaviors = {control = true} end,
    function(e) e.symbol = "IS" end,
    function(e) e.archetype = "crate" end
}) do
    local specification = copy(valid)
    mutation(specification)
    assert(RW_PlanCreate(s.world, {specification}) == nil)
    local invalid = copy(plan)
    mutation(invalid.changes[1].to)
    must_reject(invalid)
end
local missing_allocation = copy(plan)
missing_allocation.id_allocation = nil
must_reject(missing_allocation)
local skipped_id = copy(plan)
skipped_id.changes[1].entity_id = 13
skipped_id.changes[1].to.id = 13
must_reject(skipped_id)
local bad_allocation = copy(plan)
bad_allocation.id_allocation.to = 100
must_reject(bad_allocation)
local invalid_no_turn = copy(plan)
invalid_no_turn.consumes_turn = false
must_reject(invalid_no_turn)
must_reject({consumes_turn = false, changes = {}, id_allocation = {from = 12, to = 12}})
must_reject({consumes_turn = true, changes = {
    [2] = {kind = "delete", entity_id = 1, from = copy(s.world.entities[1])}}})
assert(RW_PlanCreate(s.world, {[2] = valid}) == nil)
assert(RW_PlanDelete(s.world, {4, 4}) == nil)
assert(RW_PlanDelete(s.world, {999}) == nil)
local duplicate = assert(RW_PlanDelete(s.world, {6}))
duplicate.changes[2] = copy(duplicate.changes[1])
must_reject(duplicate)
local stale = assert(RW_PlanDelete(s.world, {6}))
stale.changes[1].from.direction = "Up"
must_reject(stale)
local new_deleted = copy(plan)
new_deleted.changes[2] = {kind = "delete", entity_id = 12, from = copy(plan.changes[1].to)}
must_reject(new_deleted)
local replace = copy(plan)
replace.changes[1].entity_id = 6
replace.changes[1].to.id = 6
replace.changes[2] = assert(RW_PlanDelete(s.world, {6})).changes[1]
must_reject(replace)
local limit_world = copy(s.world)
limit_world.next_entity_id = 9007199254740991
assert(RW_PlanCreate(limit_world, {valid}) == nil, "ID exhaustion accepted")
local bad_frontier = copy(s.world)
bad_frontier.next_entity_id = 5
assert(RW_PlanCreate(bad_frontier, {valid}) == nil)

-- A created Text derives PUSH through ordinary rules; Commit stays trait-free.
local created, created_result = RW_Commit(s, plan)
assert(created_result.accepted and created.world.entities[12].traits == nil)
local effects = assert(RW_EvaluateRules(created.world, {}))
local projected = assert(RW_ProjectWorld(created.world, effects))
assert(projected.entities[12].traits.pushable)
local push = RW_ResolveMovement(projected, {type = "move", entity_id = 1, dx = 0, dy = 1})
local pushed, push_result = RW_Commit(created, push)
assert(push_result.accepted and pushed.world.entities[12].y == 4
    and pushed.world.entities[12].direction == "Down"
    and pushed.world.entities[12].traits == nil)
local undone = RW_Undo(pushed)
assert(undone.world == created.world and undone.world.entities[12].y == 3)
local no_creation = RW_Undo(undone)
assert(no_creation.world == s.world and no_creation.world.next_entity_id == 12)
local empty = assert(RW_PlanCreate(s.world, {}))
local recorded, empty_result = RW_Commit(s, empty)
assert(empty_result.accepted and not empty_result.changed and #recorded.history == 1
    and recorded.world.next_entity_id == baseline_id)
print("PASS: lifecycle validation, stale plans, trait-free Text PUSH, ID exhaustion and Undo")
