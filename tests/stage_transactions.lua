-- Phase-local snapshots permit edits to newly created/converted entities.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for key,item in pairs(value) do result[key]=copy(item) end
    return result
end
local session=RW_CreateSession()
local id=session.world.next_entity_id
local create=assert(RW_PlanCreate(session.world,{{kind="object",class="object",archetype="crate",x=6,y=6,direction="None"}}))
local first=assert(RW_PreviewPlan(session.world,create))
local move={consumes_turn=true,changes={
    {kind="move",entity_id=id,from={x=6,y=6,direction="None"},to={x=7,y=6,direction="Right"}},
    {kind="transform",entity_id=id,from="crate",to="rock"}},
    board_shift={from={x=0,y=0,direction="None"},to={x=1,y=0,direction="Right"}}}
local second=assert(RW_PreviewPlan(first,move))
local remove=assert(RW_PlanDelete(second,{id}))
local third=assert(RW_PreviewPlan(second,remove))
local last=assert(RW_PlanCreate(third,{{kind="object",class="text",text={name="ROCK"},x=7,y=6,direction="Right"}}))
local stages={{name="spawn",plan=create},{name="move_convert",plan=move},
    {name="destroy",plan=remove},{name="spawn_after",plan=last}}
local plan,err,preview=RW_PlanStages(session.world,stages)
assert(plan,err)
assert(preview.entities[id] == nil and preview.entities[id+1].text.name == "ROCK")
assert(preview.next_entity_id == id+2 and preview.board_offset.x == 1)
assert(not session.world.entities[id] and session.world.next_entity_id == id)
-- Constructor owns its inputs, including operation payloads.
move.changes[1].to.x=99
assert(plan.stages[2].plan.changes[1].to.x == 7)
local completed,result=RW_Commit(session,plan)
assert(result.accepted and result.changed and #completed.history == 1)
assert(completed.world.next_entity_id == id+2 and not completed.world.entities[id])
local restored=RW_Undo(completed)
assert(restored.world == session.world and #restored.history == 0)
local replay,replayed=RW_Commit(restored,plan)
assert(replayed.accepted and replay.world.entities[id+1].text.name == "ROCK")
-- Every stage precondition is rechecked at Commit; a late failure rolls back all.
local broken=copy(plan)
broken.stages[4].plan.id_allocation.from=id
local unchanged,rejected=RW_Commit(session,broken)
assert(unchanged == session and not rejected.accepted and rejected.reason == "stale_id_allocation" and rejected.phase == "spawn_after")
assert(not session.world.entities[id] and #session.history == 0)
local mismatch=copy(plan); mismatch.changes[1].to.x=8
assert(not select(2,RW_Commit(session,mismatch)).accepted)
local duplicate=copy(plan); duplicate.stages[4].name="spawn"
assert(select(2,RW_Commit(session,duplicate)).reason == "invalid_stage")
local nested=copy(plan); nested.stages[4].plan=plan
assert(select(2,RW_Commit(session,nested)).reason == "invalid_stage")
assert(not RW_PlanStages(session.world,{}))
assert(not RW_PlanStages(session.world,{{name="bad",plan={consumes_turn=false,changes={}}}}))
-- Repeated writes across phases use the preceding snapshot, not original values.
local a={consumes_turn=true,changes={{kind="transform",entity_id=4,from="crate",to="rock"}}}
local b={consumes_turn=true,changes={{kind="transform",entity_id=4,from="rock",to="avatar"}}}
local chain=assert(RW_PlanStages(session.world,{{name="first",plan=a},{name="second",plan=b}}))
assert(RW_Commit(session,chain).world.entities[4].archetype == "avatar")
local wrong=copy(chain); wrong.stages[2].plan.changes[1].from="crate"
assert(select(2,RW_Commit(session,wrong)).reason == "stale_transformation")
-- Rules added/removed within one transaction can be evaluated between phases.
local specs={}
for index,word in ipairs({"CRATE","IS","YOU"}) do
    specs[index]={kind="object",class="text",text={name=word},x=6+index,y=8,direction="None"}
end
local symbols=assert(RW_PlanCreate(session.world,specs))
local with_symbols=assert(RW_PreviewPlan(session.world,symbols))
local function crate_control(world)
    local ast=assert(RW_ParseRuleAST(RW_ReadLines(world),world.language))
    local generated=assert(RW_LowerRuleAST(ast,world.semantics))
    local effective=assert(RW_ProjectWorld(world,assert(RW_EvaluateRules(world,generated))))
    return effective.entities[4].behaviors.control == true
end
assert(crate_control(with_symbols))
local erase=assert(RW_PlanDelete(with_symbols,{id+1}))
local syntax=assert(RW_PlanStages(session.world,{{name="text_create",plan=symbols},{name="text_delete",plan=erase}}))
local without=assert(RW_PreviewPlan(session.world,syntax))
assert(not crate_control(without))
assert(#RW_Commit(session,syntax).history == 1)
print("PASS: sequential phase snapshots, create/edit/delete/recreate, rule refresh, late rollback, validation and single Undo")
