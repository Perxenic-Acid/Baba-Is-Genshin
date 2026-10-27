-- One-to-many conversion through physical rules and the actual turn scheduler.
local services = {project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,evaluate=function(world)
        local ast=assert(RW_ParseRuleAST(RW_ReadLines(world),world.language))
        local generated,deferred,conversions=RW_LowerRuleAST(ast,world.semantics)
        assert(generated,deferred)
        local effects,err=RW_EvaluateRules(world,generated)
        return effects,err,conversions
    end}
local definitions = RW_GetNavigationDefinitions()
local session = assert(RW_InstantiateLevel(definitions["navigation.split"],"test:split"))
local first_id = session.world.next_entity_id
session.world.entities[4].direction = "Mid"
local plan,err = RW_PlanTurn(session.world,{type="move",dx=0,dy=-1},services)
assert(plan,err and err.reason)
assert(plan.id_allocation.from == first_id and plan.id_allocation.to == first_id+2)
local changed,result = RW_Commit(session,plan)
assert(result.accepted and #changed.history == 1)
for index,id in ipairs({4,5}) do
    local original = changed.world.entities[id]
    local product = changed.world.entities[first_id+index-1]
    assert(original.archetype == "level_block" and product.archetype == "rock")
    assert(product.x == original.x and product.y == original.y and product.direction == original.direction)
    if id == 4 then
        assert(product.level_link ~= original.level_link) -- Copies must not alias metadata.
        assert(product.level_link.definition_id == original.level_link.definition_id)
        assert(product.direction == "Mid")
    else assert(not product.level_link and not original.level_link) end
end
local undone = RW_Undo(changed)
assert(undone.world == session.world and undone.world.next_entity_id == first_id)
assert(not undone.world.entities[first_id] and undone.world.entities[4].archetype == "crate")
local replay=RW_Commit(undone,assert(RW_PlanTurn(undone.world,{type="move",dx=0,dy=-1},services)))
assert(replay.world.entities[first_id].archetype == "rock")
-- Two physically separate sentences have the same simultaneous result.
local separate=RW_InstantiateLevel(definitions["navigation.split"],"test:separate")
separate.world.entities[16].y=8
for _, entity in pairs(separate.world.entities) do
    if entity.class == "text" and entity.text.name == "AND" then entity.text.name="PUSH" end
end
for offset,word in ipairs({"CRATE","IS","ROCK"}) do
    local id=separate.world.next_entity_id
    separate.world.entities[id]={id=id,kind="object",class="text",direction="None",x=3+offset,y=6,text={name=word}}
    separate.world.next_entity_id=id+1
end
local separate_plan=assert(RW_PlanTurn(separate.world,{type="move",dx=1,dy=0},services))
local separate_result, accepted=RW_Commit(separate,separate_plan)
assert(accepted.accepted)
local counts={rock=0,level_block=0}
for _, entity in pairs(separate_result.world.entities) do
    if entity.class == "object" and counts[entity.archetype] then counts[entity.archetype]=counts[entity.archetype]+1 end
end
assert(counts.rock == 2 and counts.level_block == 3) -- Includes the existing parent block.
-- Separate rules, duplicate rule instances, identity protection and no within-turn cascade.
local rules = {{op="transform",source_type="crate",target_type="rock"},
    {op="transform",source_type="crate",target_type="level_block"},
    {op="transform",source_type="crate",target_type="rock"},
    {op="transform",source_type="rock",target_type="avatar"}}
local operations,why,allocation=RW_PlanConversions(session.world,rules)
assert(operations and not why and #operations == 6 and allocation.to == first_id+4)
assert(operations[1].to == "rock" and operations[2].to.archetype == "level_block")
rules[#rules+1] = {op="protect_transform",source_type="crate"}
local guarded,_,guard_allocation=RW_PlanConversions(session.world,rules)
assert(#guarded == 0 and not guard_allocation)
-- Exhaustion rejects before any Commit or mutation.
local exhausted=RW_InstantiateLevel(definitions["navigation.split"],"test:exhausted")
exhausted.world.next_entity_id=9007199254740991
local rejected,failure=RW_PlanTurn(exhausted.world,{type="move",dx=0,dy=-1},services)
assert(not rejected and failure.reason == "entity_id_exhausted")
assert(exhausted.world.entities[4].archetype == "crate" and #exhausted.history == 0)
print("PASS: simultaneous noun conversion products, copied links/directions, multiplicity, protection, allocation/Undo/replay")
