local function fixture()
 local s=RW_CreateSession();s.world.width=8;s.world.height=8;s.world.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Right"}};s.world.next_entity_id=10;return s
end
local s=fixture()
local stages={
 {name="movement",plan={consumes_turn=true,changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Right"}}}}},
 {name="follow",plan={consumes_turn=true,changes={{kind="direction",entity_id=1,from="Right",to="Up"}}}},
 {name="shift",plan={consumes_turn=true,changes={{kind="move",entity_id=1,from={x=3,y=2,direction="Up"},to={x=2,y=2,direction="Left"}}}}}}
local p=assert(RW_PlanStages(s.world,stages));local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
assert(n.world.entities[1].x==s.world.entities[1].x and n.world.entities[1].y==s.world.entities[1].y)
local record=assert(RW_GetTurnRecord(n,1));assert(#record.phases==3 and record.phases[1].changes[1].to.x==3 and record.phases[3].changes[1].from.x==3)
p.stages[1].plan.changes[1].to.x=7;record.phases[1].changes[1].from.x=8
assert(RW_GetTurnRecord(n,1).phases[1].changes[1].from.x==2 and RW_GetTurnRecord(n,1).phases[1].changes[1].to.x==3)
local restored=RW_Undo(n);assert(restored.world==s.world and restored.turn_records==nil)
-- Conversion create/remove operations and allocator metadata remain in their phase.
local create=assert(RW_PlanCreate(n.world,{{kind="object",class="object",archetype="flag",x=2,y=2,direction="Left"}}))
local after=assert(RW_PreviewPlan(n.world,create));local delete=assert(RW_PlanDelete(after,{1}))
local transaction=assert(RW_PlanStages(n.world,{{name="birth",plan=create},{name="death",plan=delete}}))
local born,res=RW_Commit(n,transaction);assert(res.accepted)
record=assert(RW_GetTurnRecord(born,1));assert(record.phases[1].changes[1].kind=="create" and record.phases[1].id_allocation.to==11)
assert(record.phases[2].changes[1].kind=="delete" and record.phases[2].changes[1].from.archetype=="avatar")
assert(#RW_GetTurnRecord(born,2).phases==3)
-- Metadata-only accepted waits remain distinct historical turns.
local wait={consumes_turn=true,reason="wait",changes={},input_state={from="none",to="wait"},chance_state={from=1,to=48271}}
local waited,res=RW_Commit(born,wait);assert(res.accepted)
record=assert(RW_GetTurnRecord(waited,1));assert(record.reason=="wait" and #record.phases[1].changes==0 and record.phases[1].chance_state.to==48271)
local failed={consumes_turn=true,changes={{kind="direction",entity_id=10,from="Up",to="Right"}}}
local unchanged,res=RW_Commit(waited,failed);assert(not res.accepted and unchanged==waited and unchanged.turn_records==waited.turn_records)
-- Legacy snapshot-only history is marked unavailable, never fabricated.
local legacy=fixture();legacy.history={legacy.world}
local l,res=RW_Commit(legacy,{consumes_turn=true,changes={}});assert(res.accepted and l.turn_records[1]==false)
local missing,why=RW_GetTurnRecord(l,2);assert(not missing and why=="history_unavailable")
local back=RW_Undo(l);assert(back.turn_records==nil and #back.history==1)
-- Cap journals in lockstep with snapshots; Undo removes both aligned entries.
local capped=fixture()
for i=1,130 do local e=capped.world.entities[1];local plan={consumes_turn=true,changes={{kind="direction",entity_id=1,from=e.direction,to=e.direction=="Right" and "Left" or "Right"}}}
 capped,res=RW_Commit(capped,plan);assert(res.accepted) end
assert(#capped.history==128 and #capped.turn_records==128 and RW_GetTurnRecord(capped,128))
assert(not RW_GetTurnRecord(capped,129))
for i=1,128 do capped,res=RW_Undo(capped);assert(res.accepted) end
assert(#capped.history==0 and capped.turn_records==nil)
local malformed=fixture();malformed.turn_records={{phases={}}}
local _,res=RW_Commit(malformed,{consumes_turn=true,changes={}});assert(not res.accepted and res.reason=="invalid_turn_records")
-- Terminal commits retain their journal and still allow undo.
for _,flag in ipairs({"too_complex","infinite_loop"}) do
 local base=fixture();local plan={consumes_turn=true,changes={}};plan[flag]=true
 local terminal,res=RW_Commit(base,plan);assert(res.accepted and RW_GetTurnRecord(terminal,1)[flag])
 local u,res=RW_Undo(terminal);assert(res.accepted and u.world==base.world and not u.turn_records)
end
print("PASS: turn journals preserve net-zero sequential motion, conversion/create/delete, metadata-only turns, ownership, rejection, cap/legacy alignment, terminal states and Undo")

-- Installed addundo inserts newest operation rows first. Reversing our phase/
-- operation traversal preserves the same update sequence without flattening it.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/undo.lua]],"rb"));local source=f:read("*a");f:close()
local insertion=assert(source:match("(function addundo%(line,uid_%).-)\nfunction undo%(%)"))
local env=setmetatable({doundo=true,undobuffer={{}},generaldata={flags={logging=false}},LOGGING="logging"},{__index=_G})
assert(load(insertion,"@installed_addundo","t",env))()
for _,line in ipairs({{"update","avatar",2,2,0,3,2,0,1},{"update","avatar",3,2,0,3,2,1,1},{"update","avatar",3,2,1,2,2,2,1}}) do env.addundo(line) end
local turns=assert(RW_GetTurnRecord(n,1));local k=1;local dirs={Right=0,Up=1,Left=2,Down=3}
for i=#turns.phases,1,-1 do for j=#turns.phases[i].changes,1,-1 do
 local op=turns.phases[i].changes[j];local line=env.undobuffer[1][k]
 assert(line[9]==op.entity_id and line[5]==dirs[type(op.from)=="table" and op.from.direction or op.from])
 if op.kind=="move" then assert(line[3]==op.from.x and line[4]==op.from.y) end;k=k+1
end end
assert(k==4);print("PASS: installed addundo newest-first update order matches reverse phase journal traversal")

local root=fixture().world;root.entities[1].level_link={target="child",definition_id="child",source_type="avatar"}
local child=fixture().world
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",root)),child=assert(RW_CreateLevelDefinition("child",child))},"root"))
local parent_id=tree.active_id;tree=assert(RW_EnterLevel(tree,"1","child"));tree=assert(RW_BindLevelEntry(tree,1))
local child_id=tree.active_id;local session=RW_GetActiveLevel(tree)
local moved,res=RW_Commit(session,{consumes_turn=true,changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Right"}}}});assert(res.accepted)
local updated=assert(RW_UpdateActiveLevel(tree,moved));local completed,res=RW_CommitLevelTree(tree,{before=tree,after=updated});assert(res.accepted)
assert(RW_GetTurnRecord(RW_GetActiveLevel(completed),1) and completed.instances[parent_id].turn_records==nil)
local undone=RW_UndoLevelTree(completed);assert(undone.instances[child_id]==tree.instances[child_id] and not RW_GetActiveLevel(undone).turn_records)
local reloaded=assert(RW_ReloadLevel(completed,child_id));assert(not RW_GetActiveLevel(reloaded).turn_records and #RW_GetActiveLevel(reloaded).history==0)
local reset,res=RW_CommitLevelTree(completed,{before=completed,after=reloaded});assert(res.accepted)
local restored=RW_UndoLevelTree(reset);assert(restored.instances[child_id]==completed.instances[child_id] and RW_GetTurnRecord(RW_GetActiveLevel(restored),1))
print("PASS: tree journal sibling isolation, boundary reset and whole-tree Undo restoration")
