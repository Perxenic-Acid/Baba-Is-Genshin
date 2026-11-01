local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function fixture()
 local s=RW_CreateSession();local w=s.world;w.width=12;w.height=10;w.next_entity_id=10
 w.entities={}
 for id=1,3 do w.entities[id]={id=id,kind="object",class="object",archetype=id==1 and "avatar" or "rock",x=id==3 and 8 or 2,y=2,direction="Right"} end
 return s
end
local function project(w)
 return assert(RW_ProjectWorld(w,{{op="grant_trait",entity_ids={2,3},trait="tele"}}))
end
local function sequence(s,back)
 local after=assert(RW_PreviewPlan(s.world,back))
 local tele=assert(RW_ResolveTele(project(after),back.tele_suppressed))
 local changes={};for _,p in ipairs({back,tele}) do for _,op in ipairs(p.changes) do changes[#changes+1]=op end end
 local plan={consumes_turn=true,changes=changes,stages={{name="back",plan=back},{name="tele",plan=tele}}}
 local next,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 assert(RW_Undo(next).world==s.world)
 assert(not next.world.tele_suppressed and not next.turn_records[1].phases[1].tele_suppressed)
 for _,e in pairs(next.world.entities) do assert(e.tele_suppressed==nil) end
 return next,tele,plan
end
for _,kind in ipairs({"move","direction","unchanged"}) do for guard=0,1 do
 local old=fixture();local op
 if kind=="move" then op={kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Up"}}
 else op={kind="direction",entity_id=1,from="Right",to="Up"} end
 local past,r=RW_Commit(old,{consumes_turn=true,changes={op}});assert(r.accepted)
 local s=fixture();s.world.entities[1].direction=kind=="unchanged" and "Right" or "Up"
 local back=assert(RW_PlanBackFramePlayback(s.world,{{entity_id=1,before_world=old.world,record=RW_GetTurnRecord(past,1)}},guard==1 and {[1]=true} or nil))
 assert((back.tele_suppressed[1]==true)==(guard==0))
 local next,tele=sequence(s,back)
 assert(next.world.entities[1].x==(guard==0 and 2 or 8))
 assert((tele.random_state~=nil)==(guard==1))
 -- A new call without the transient marks can teleport the same identity.
 local free=assert(RW_ResolveTele(project(next.world)))
 assert(#free.changes==1 and free.random_state)
end end

-- Restore a conversion onto the same physical slot. Any old update-row mark
-- belongs to the retired native handle, not the new alias sharing its slot.
local old=fixture()
local p={consumes_turn=true,changes={{kind="direction",entity_id=1,from="Right",to="Up"},
 {kind="transform",entity_id=1,from="avatar",to="flag"}}}
local past,r=RW_Commit(old,p);assert(r.accepted)
local s=fixture();s.world.entities[1]=copy(past.world.entities[1])
local back=assert(RW_PlanBackFramePlayback(s.world,{{entity_id=1,before_world=old.world,record=RW_GetTurnRecord(past,1)}}))
assert(back.tele_suppressed[1]==nil)
local next,tele,plan=sequence(s,back)
local restore_source=s
assert(next.world.entities[1].archetype=="avatar" and next.world.entities[1].x==8 and tele.random_state)

-- Marks use physical handles: an alias sharing the logical ID still teleports.
s=fixture();s.world.entities[4]=copy(s.world.entities[1]);s.world.entities[4].id=4;s.world.entities[4].back_identity=1
local tele=assert(RW_ResolveTele(project(s.world),{[1]=true}))
assert(#tele.changes==1 and tele.changes[1].entity_id==4)
-- A marked TELE source may still transport other riders; it is not disabled.
tele=assert(RW_ResolveTele(project(s.world),{[2]=true}))
assert(#tele.changes==2)
for _,bad in ipairs({false,{[1]=false},{[999]=true},{unexpected=true}}) do
 local p,why=RW_ResolveTele(project(s.world),bad);assert(not p and why=="invalid_tele_suppression")
end
local invalid=copy(plan);invalid.stages[2].plan.changes[1].from.x=11
assert(RW_PreviewPlan(restore_source.world,invalid.stages[1].plan))
local rejected,result=RW_Commit(restore_source,invalid)
assert(not result.accepted and rejected==restore_source and restore_source.world.entities[1].archetype=="flag")
print("PASS: BACK-to-TELE motion/direction/net-zero suppression, paradox, replaced handles, shared aliases, RNG, transient marks, atomic rejection and Undo")
