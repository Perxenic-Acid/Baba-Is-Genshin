-- Level templates and runtime sessions have separate ownership.
local definition = RW_GetDefaultLevelDefinition()
local owned = assert(RW_CreateLevelDefinition("puzzle", definition.initial_world))
definition.initial_world.entities[1].x = 9
assert(owned.initial_world.entities[1].x == 2)
local a = assert(RW_InstantiateLevel(owned, "map/door-a"))
local b = assert(RW_InstantiateLevel(owned, "map/door-b"))
assert(a.world.entities[1].id == b.world.entities[1].id)
assert(a.instance_id ~= b.instance_id and a.definition_id == b.definition_id)
local services = {
    evaluate = function(world)
        local ast = assert(RW_ParseRuleAST(RW_ReadLines(world), world.language))
        local generated, deferred, conversions = RW_LowerRuleAST(ast, world.semantics)
        assert(generated and deferred)
        local sources = {}
        for _, rule in ipairs(world.rule_sources or {}) do sources[#sources+1] = rule end
        for _, rule in ipairs(generated) do sources[#sources+1] = rule end
        local effects, err = RW_EvaluateRules(world, sources)
        return effects, err, conversions
    end,
    project = RW_ProjectWorld, resolve = RW_ResolveTurn,
    preview = RW_PreviewPlan, convert = RW_PlanConversions
}
local move_plan = assert(RW_PlanTurn(b.world, {type="move",dx=1,dy=0}, services))
local moved, move_result = RW_Commit(b, move_plan)
assert(move_result.accepted and moved.world.entities[1].x == 3)
assert(moved.world.entities[4].x == 4 and moved.world.entities[5].direction == "Right")
assert(moved.instance_id == b.instance_id and a.world.entities[1].x == 2)
assert(RW_Undo(moved).world == b.world)
local creation = assert(RW_PlanCreate(a.world, {{kind="object", class="text",
    text={name="IS"}, x=8, y=8, direction="None"}}))
local created, accepted = RW_Commit(a, creation)
assert(accepted.accepted and created.world.next_entity_id == 13)
assert(b.world.next_entity_id == 12 and not owned.initial_world.entities[12])
assert(created.instance_id == a.instance_id and #b.history == 0)
local reset = assert(RW_InstantiateLevel(owned, a.instance_id))
assert(reset.world.next_entity_id == 12 and #reset.history == 0)
local undone = RW_Undo(created)
assert(undone.world == a.world and undone.definition_id == "puzzle")
local bad_plan = {consumes_turn=true, changes={{kind="direction", entity_id=1, from="Up", to="Left"}}}
local rejected, result = RW_Commit(created, bad_plan)
assert(rejected == created and not result.accepted)
-- Configuration and all nested state are copied separately per instance.
a.world.language.nouns.CRATE = "other"
a.world.rule_sources[1].effects[1].trait = "other"
assert(b.world.language.nouns.CRATE == "crate")
assert(b.world.rule_sources[1].effects[1].trait == "pushable")
assert(owned.initial_world.language.nouns.CRATE == "crate")
local function invalid(edit)
    local d = RW_GetDefaultLevelDefinition()
    edit(d)
    local instance, reason = RW_InstantiateLevel(d, "bad")
    assert(instance == nil and reason == "invalid_level_definition")
end
for _, edit in ipairs({
    function(d) d.id = "" end,
    function(d) d.history = {} end,
    function(d) d.initial_world.width = 0 end,
    function(d) d.initial_world.height = 1.5 end,
    function(d) d.initial_world.next_entity_id = 1 end,
    function(d) d.initial_world.entities[1].id = 2 end,
    function(d) d.initial_world.entities[1].x = 99 end,
    function(d) d.initial_world.entities[1].direction = "north" end,
    function(d) d.initial_world.entities[1].traits = {} end,
    function(d) d.initial_world.entities[1].behaviors = {} end,
    function(d) d.initial_world.history = {} end,
    function(d) d.initial_world.language = false end,
    function(d) d.initial_world.language.callback = function() end end,
    function(d) d.initial_world.language.cycle = d end,
    function(d) setmetatable(d.initial_world.entities, {}) end
}) do invalid(edit) end
assert(not RW_InstantiateLevel(owned, ""))
assert(not RW_InstantiateLevel(owned, 1))
-- Empty maps and sparse stable identities are valid level definitions too.
local empty = assert(RW_CreateLevelDefinition("empty", {width=1,height=1,
    entities={},next_entity_id=42,language={},rule_sources={}}))
assert(RW_InstantiateLevel(empty,"empty/1").world.next_entity_id == 42)
assert(RW_LevelInstanceSelfTest())
print("PASS: level definitions, independent instances, lifecycle/Undo and invalid templates")
