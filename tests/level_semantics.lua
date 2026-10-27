-- Source-referenced regressions for scoped LEVEL and identity-bound destinations.
local services = {
    active=RW_GetActiveLevel, update=RW_UpdateActiveLevel, enter=RW_EnterLevel,
    return_level=RW_ReturnLevel, bind_entry=RW_BindLevelEntry, commit_session=RW_Commit,
    outcome=RW_RecordLevelOutcome, candidates=RW_LevelSelectionCandidates,
    win=RW_HasWinContact, level_outcome=RW_ResolveLevelPropertyOutcome,
    project=RW_ProjectWorld, resolve=RW_ResolveTurn, preview=RW_PreviewPlan, convert=RW_PlanConversions,
    evaluate=function(world)
        local ast = assert(RW_ParseRuleAST(RW_ReadLines(world),world.language))
        local generated, deferred, conversions = RW_LowerRuleAST(ast,world.semantics)
        assert(generated,deferred)
        local effects, err = RW_EvaluateRules(world,generated)
        return effects, err, conversions
    end
}
assert(select(2,RW_ResolveLevelPropertyOutcome({}, {"win",false})) == "invalid_level_property")
local up, down, right, confirm = {type="move",dx=0,dy=-1}, {type="move",dx=0,dy=1},
    {type="move",dx=1,dy=0}, {type="confirm"}
local function step(tree,action)
    local plan, err = RW_PlanLevelAction(tree,action,services)
    assert(plan,err and err.reason)
    local next_tree, result = RW_CommitLevelTree(tree,plan)
    assert(result.accepted,result.reason)
    return next_tree
end
local function enter_case(column)
    local definitions,id = RW_GetNavigationDefinitions()
    definitions[id].initial_world.entities[12].x = column
    local root = assert(RW_CreateLevelTree(definitions,id))
    return step(step(root,down),confirm),root
end
for column, expected in ipairs({"win","defeat","win","defeat","transform"}) do
    local entered, root = enter_case(column)
    local result = step(entered,up) -- Push LEVEL into the complete sentence.
    local outcome = assert(result.outcomes[entered.active_id])
    assert(outcome.kind == expected,column .. ": wrong terminal result")
    assert(#result.history == #entered.history+1)
    if expected == "defeat" then
        assert(result.active_id == entered.active_id and #result.stack == 1)
        local bypass, rejected = RW_CommitLevelTree(result,{before=result,after=result})
        assert(bypass == result and not rejected.accepted and rejected.reason == "level_defeated_undo_only")
        for _, action in ipairs({up,down,right,confirm}) do
            local bad, err = RW_PlanLevelAction(result,action,services)
            assert(not bad and err.reason == "level_defeated_undo_only")
        end
    else
        assert(result.active_id == root.active_id and #result.stack == 0)
    end
    if expected == "transform" then
        assert(outcome.target_type == "rock")
        assert(RW_GetActiveLevel(result).world.entities[36+column].archetype == "rock")
        assert(step(result,confirm).active_id == entered.active_id, "Converted LEVEL no longer responds to SELECT")
    end
    local undone = RW_UndoLevelTree(result)
    assert(undone.active_id == entered.active_id and not undone.outcomes[entered.active_id])
    assert(RW_GetActiveLevel(undone).world.entities[16].y == 9)
    assert(undone.instances[root.active_id].world.entities[36+column].archetype == "level_block")
end
-- Parse AND as ordered typed properties, retain provenance through the conjunction.
local defs = RW_GetNavigationDefinitions()
for _, pair in ipairs({{"win_defeat","win","defeat"},{"defeat_win","defeat","win"}}) do
    local world = defs["navigation." .. pair[1]].initial_world
    world.entities[16].y = 8
    local ast = assert(RW_ParseRuleAST(RW_ReadLines(world),world.language))
    local generated, deferred, conversions = RW_LowerRuleAST(ast)
    local traits, sources = {}, {}
    for _, item in ipairs(conversions) do
        if item.op == "level_trait" then traits[#traits+1]=item.trait; sources[#sources+1]=item.source end
    end
    assert(#traits == 2 and traits[1] == pair[2] and traits[2] == pair[3])
    assert(#sources[1].entity_ids == 3 and #sources[2].entity_ids == 5)
    assert(sources[2].rhs_index == 2 and sources[2].entity_ids[4] == 19)
end
-- Direct scoped WIN does not require a specially named flag or even a YOU object.
local definitions = RW_GetNavigationDefinitions()
local world = definitions["navigation.win"].initial_world
world.entities[16].y = 8
world.entities[11].text.name = "PUSH" -- Remove AVATAR IS YOU.
local standalone = assert(RW_CreateLevelTree(definitions,"navigation.win"))
local won = step(standalone,right)
assert(won.outcomes[won.active_id].kind == "win")
-- Noun IS LEVEL: both entities convert, only the explicitly configured ID is usable.
local entered = enter_case(6)
local converted = step(entered,up)
local w = RW_GetActiveLevel(converted).world
assert(w.entities[4].archetype == "level_block" and w.entities[5].archetype == "level_block")
assert(w.entities[4].level_link and not w.entities[5].level_link)
converted = step(step(step(converted,down),right),right)
assert(RW_GetActiveLevel(converted).world.entities[12].x == 3)
local nested = step(converted,confirm)
assert(#nested.stack == 2)
local returned = step(step(nested,right),confirm)
assert(returned.active_id == entered.active_id)
local blank = step(returned,right)
local bad, err = RW_PlanLevelAction(blank,confirm,services)
assert(not bad and err.reason == "unavailable_level")
assert(RW_GetActiveLevel(blank).world.entities[12].x == 4)
-- Replacing the bound entity with a new unconfigured ID must not inherit its link.
local session = RW_GetActiveLevel(converted)
local deleted = RW_Commit(session,assert(RW_PlanDelete(session.world,{4})))
local created = RW_Commit(deleted,assert(RW_PlanCreate(deleted.world,{
    {kind="object",class="object",archetype="level_block",direction="None",x=3,y=2}})))
assert(not created.world.entities[created.world.next_entity_id-1].level_link)
local replacement = assert(RW_UpdateActiveLevel(converted,created))
local rejected, failure = RW_PlanLevelAction(replacement,confirm,services)
assert(not rejected and failure.reason == "unavailable_level")
-- WIN is a property on arbitrary entities, including Text, and is retracted normally.
local projected = assert(RW_ProjectWorld(w,{
    {op="grant_trait",entity_ids={4},trait="you"},
    {op="grant_trait",entity_ids={6},trait="win"}}))
projected.entities[6].x,projected.entities[6].y = projected.entities[4].x,projected.entities[4].y
assert(RW_HasWinContact(projected))
assert(not RW_HasWinContact(assert(RW_ProjectWorld(projected,{}))))
print("PASS: ordered LEVEL terminal properties, defeat lock/Undo, retained links and Noun IS LEVEL usability")
