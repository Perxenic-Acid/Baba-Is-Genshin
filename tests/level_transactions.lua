-- Real modules, independent of the native fixture and input binding.
local services = {
    active=RW_GetActiveLevel, update=RW_UpdateActiveLevel, enter=RW_EnterLevel,
    return_level=RW_ReturnLevel, selectors=RW_LevelSelectorIDs, place_selectors=RW_PlaceLevelSelectors, bind_entry=RW_BindLevelEntry,
    commit_session=RW_Commit, outcome=RW_RecordLevelOutcome,
    candidates=RW_LevelSelectionCandidates, win=RW_HasWinContact,
    level_outcome=RW_ResolveLevelPropertyOutcome,
    project=RW_ProjectWorld, resolve=RW_ResolveTurn, preview=RW_PreviewPlan,
    convert=RW_PlanConversions,
    evaluate=function(world)
        local ast, err = RW_ParseRuleAST(RW_ReadLines(world),world.language)
        if not ast then return nil, err end
        local generated, deferred, conversions = RW_LowerRuleAST(ast,world.semantics)
        if not generated then return nil, deferred end
        local effects, evaluation_error = RW_EvaluateRules(world,generated)
        return effects, evaluation_error, conversions
    end
}
local function root()
    local definitions, id = RW_GetNavigationDefinitions()
    return assert(RW_CreateLevelTree(definitions,id))
end
local function step(tree,action)
    local plan, err = RW_PlanLevelAction(tree,action,services)
    assert(plan, err and err.reason)
    local next_tree, result = RW_CommitLevelTree(tree,plan)
    assert(result.accepted)
    return next_tree,plan
end
local up = {type="move",dx=0,dy=-1}
local down = {type="move",dx=0,dy=1}
local right = {type="move",dx=1,dy=0}
local confirm = {type="confirm"}
local initial = root()
local no_entry, no_entry_err = RW_PlanLevelAction(initial,confirm,services)
assert(not no_entry and no_entry_err.reason == "no_selected_level")
assert(#initial.history == 0 and initial.next_instance_id == 2)
local selected = step(initial,up)
assert(#selected.stack == 0)
local entered, enter_plan = step(selected,confirm)
assert(#entered.history == 2 and entered.next_instance_id == 3)
local restored = RW_UndoLevelTree(entered)
assert(restored.active_id == initial.active_id and restored.next_instance_id == 2)
assert(not restored.instances[entered.active_id] and not restored.children[initial.active_id])
local replayed = step(restored,confirm)
assert(replayed.active_id == entered.active_id)
local corrupted = {before=selected,after={}}
local unchanged, corrupt_result = RW_CommitLevelTree(selected,corrupted)
assert(unchanged == selected and not corrupt_result.accepted)
local stale, result = RW_CommitLevelTree(entered,enter_plan)
assert(stale == entered and not result.accepted)
local won = step(entered,down)
assert(won.active_id == initial.active_id and #won.history == 3)
assert(won.outcomes[entered.active_id].kind == "win")
local unwin = RW_UndoLevelTree(won)
assert(unwin.active_id == entered.active_id and not unwin.outcomes[entered.active_id])
assert(RW_GetActiveLevel(unwin).world.entities[1].y == 2)
local pushed = step(entered,right)
local returned = step(pushed,confirm)
local revisited = step(returned,confirm)
assert(revisited.active_id == entered.active_id and RW_GetActiveLevel(revisited).world.entities[4].x == 3)
local undo_return = RW_UndoLevelTree(returned)
assert(undo_return.active_id == entered.active_id and #undo_return.stack == 1)
-- Conversion atomically writes a suspended parent's block and exits the child.
local selected_t = step(step(initial,up),right)
local t = step(selected_t,confirm)
local converted = step(t,up)
assert(converted.outcomes[t.active_id].kind == "transform")
assert(RW_GetActiveLevel(converted).world.entities[15].archetype == "crate")
local effects = assert(services.evaluate(RW_GetActiveLevel(converted).world))
local projected = assert(RW_ProjectWorld(RW_GetActiveLevel(converted).world,effects))
assert(RW_LevelSelectionCandidates(projected)[1] == 15, "Transformed level lost its destination")
assert(step(converted,confirm).active_id == t.active_id)
local unconvert = RW_UndoLevelTree(converted)
assert(unconvert.active_id == t.active_id and not unconvert.outcomes[t.active_id])
assert(unconvert.instances[initial.active_id].world.entities[15].archetype == "level_block")
assert(RW_GetActiveLevel(unconvert).world.entities[18].y == 9)
-- Rule-derived SELECT, independent of the object class/name. Retraction is immediate.
local world = RW_GetDefaultLevelDefinition().initial_world
world.entities[1].x,world.entities[1].y = 2,1
world.entities[2].x,world.entities[2].y = 2,1
world.entities[2].archetype = "portal"
world.entities[2].level_link = {source_type="portal",target="parent"}
local projection = assert(RW_ProjectWorld(world,{{op="grant_trait",entity_ids={1},trait="you"}}))
assert(#RW_LevelSelectionCandidates(projection) == 0)
projection = assert(RW_ProjectWorld(world,{{op="grant_trait",entity_ids={6},trait="select"}}))
projection.entities[6].x,projection.entities[6].y = 2,1
assert(RW_LevelSelectionCandidates(projection)[1] == 2, "Text SELECT was excluded")
projection = assert(RW_ProjectWorld(projection,{}))
assert(#RW_LevelSelectionCandidates(projection) == 0)
-- SELECT cannot satisfy WIN; an arbitrary YOU object can.
world.entities[3].x,world.entities[3].y = 2,1
projection = assert(RW_ProjectWorld(world,{
    {op="grant_trait",entity_ids={1},trait="select"},
    {op="grant_trait",entity_ids={3},trait="win"}}))
assert(not RW_HasWinContact(projection))
projection = assert(RW_ProjectWorld(world,{
    {op="grant_trait",entity_ids={2},trait="you"},
    {op="grant_trait",entity_ids={3},trait="win"}}))
assert(RW_HasWinContact(projection))
-- Multiple selected blocks are rejected rather than chosen by hash iteration.
world.entities[4].x,world.entities[4].y = 2,1
world.entities[4].archetype = "portal"
world.entities[4].level_link = {source_type="portal",target="parent"}
world.rule_sources[#world.rule_sources+1] = {when={op="always"},effects={
    {op="grant_trait",target={kind="id",value=1},trait="select"}}}
local d = assert(RW_CreateLevelDefinition("ambiguous",world))
local ambiguous = assert(RW_CreateLevelTree({ambiguous=d},"ambiguous"))
local bad, failure = RW_PlanLevelAction(ambiguous,confirm,services)
assert(not bad and failure.reason == "choose_level" and #ambiguous.history == 0)
-- Any post-movement failure rejects the complete tree transaction.
local project = services.project
local calls = 0
services.project = function(w,e)
    calls = calls+1
    if calls == 3 then return nil,"injected_post_failure" end
    return project(w,e)
end
local failed = RW_PlanLevelAction(entered,right,services)
assert(not failed and #entered.history == 2 and RW_GetActiveLevel(entered).world.entities[4].x == 3)
services.project = project
-- A level object that is itself SELECT is not a selectable target (original cursor rule).
projection = assert(RW_ProjectWorld(world,{{op="grant_trait",entity_ids={1,2,4},trait="select"}}))
assert(#RW_LevelSelectionCandidates(projection) == 0)
-- Scoped LEVEL identity protects conversion; conflicting targets reject the whole turn.
local function conversion_fixture(extra_token)
    local definitions, id = RW_GetNavigationDefinitions()
    local w = definitions["navigation.transform"].initial_world
    w.entities[18].y = 8 -- LEVEL IS CRATE already complete.
    if extra_token then
        for i, token in ipairs({"LEVEL","IS",extra_token}) do
            w.entities[18+i] = {id=18+i,kind="object",class="text",direction="None",
                x=4+i,y=11,text={name=token}}
        end
        w.next_entity_id = 22
    end
    local tree = assert(RW_CreateLevelTree(definitions,id))
    return step(step(step(tree,up),right),confirm), definitions
end
local protected = conversion_fixture("LEVEL")
local protected_after = step(protected,up)
assert(protected_after.active_id == protected.active_id)
assert(protected_after.instances[initial.active_id].world.entities[15].archetype == "level_block")
local conflicting = conversion_fixture("AVATAR")
local conflict, conflict_error = RW_PlanLevelAction(conflicting,up,services)
assert(not conflict and conflict_error.reason == "conflicting_level_transforms")
assert(#conflicting.history == 3)
local _, definitions = conversion_fixture()
local orphan_root = assert(RW_CreateLevelTree(definitions,"navigation.transform"))
local orphan, orphan_error = RW_PlanLevelAction(orphan_root,up,services)
assert(not orphan and orphan_error.reason == "no_parent_level_block" and #orphan_root.history == 0)
assert(RW_LevelSelectionSelfTest())
print("PASS: whole-tree atomic Undo/replay, SELECT authority/retraction, all exits and rejection boundaries")
