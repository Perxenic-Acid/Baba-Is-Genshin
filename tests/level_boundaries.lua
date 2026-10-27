-- Boundaries restore authored runtime; only scoped LEVEL conversions/results persist.
local definitions, root_id = RW_GetNavigationDefinitions()
local root = assert(RW_CreateLevelTree(definitions,root_id))
local session = RW_GetActiveLevel(root)
local initial = session.world
local plan = {consumes_turn=true,changes={
    {kind="move",entity_id=1,from={x=initial.entities[1].x,y=initial.entities[1].y},to={x=5,y=5}},
    {kind="transform",entity_id=4,from="crate",to="rock"}},
    board_shift={from={x=0,y=0,direction="None"},to={x=2,y=-1,direction="Up"}}}
local changed, accepted = RW_Commit(session,plan)
assert(accepted.accepted and changed.world.board_offset.x == 2)
local unchanged, stale = RW_Commit(changed,plan)
assert(unchanged == changed and not stale.accepted)
local invalid = {consumes_turn=true,changes={},board_shift={
    from={x=0,y=0,direction="None"},to={x=0.5,y=0,direction="Right"}}}
assert(not select(2,RW_Commit(session,invalid)).accepted)
local created = RW_Commit(changed,assert(RW_PlanCreate(changed.world,{
    {kind="object",class="object",archetype="rock",direction="Left",x=4,y=4}})))
local dirty = assert(RW_UpdateActiveLevel(root,created))
local child = assert(RW_EnterLevel(dirty,"block:13","navigation.puzzle"))
child = assert(RW_BindLevelEntry(child,13))
local clean = child.instances[root.active_id]
assert(clean.world.entities[1].x == initial.entities[1].x)
assert(clean.world.entities[4].archetype == "crate" and not clean.world.board_offset)
assert(clean.world.next_entity_id == initial.next_entity_id and #clean.history == 0)
local transformed = assert(RW_RecordLevelOutcome(child,"transform","rock"))
local returned = assert(RW_ReturnLevel(transformed))
assert(RW_GetActiveLevel(returned).world.entities[13].archetype == "rock")
local reentered = assert(RW_EnterLevel(returned,"block:13","navigation.puzzle"))
assert(reentered.active_id == child.active_id and reentered.outcomes[child.active_id].kind == "transform")
assert(reentered.instances[root.active_id].world.entities[13].archetype == "rock")
local committed, result = RW_CommitLevelTree(dirty,{before=dirty,after=reentered})
assert(result.accepted)
local undone = RW_UndoLevelTree(committed)
assert(undone.active_id == dirty.active_id and RW_GetActiveLevel(undone).world == created.world)
assert(RW_GetActiveLevel(undone).world.board_offset.x == 2)
assert(not root.level_transforms[root.active_id])
print("PASS: boundary reload/reset, persistent scoped conversion/result, board shift validation and whole-tree Undo")
