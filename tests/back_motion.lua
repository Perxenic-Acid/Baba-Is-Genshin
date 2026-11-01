local function entity(x,y,d) return {id=1,kind="object",class="object",archetype="avatar",x=x,y=y,direction=d,level_link={target="parent",source_type="level_block"}} end
local function world(x,y,d) local s=RW_CreateSession();s.world.width=10;s.world.height=10;s.world.entities={[1]=entity(x,y,d)};s.world.next_entity_id=10;return s end
local before=entity(2,2,"Right")
local records={
 {phases={{changes={{kind="direction",entity_id=1,from="Right",to="Up"}}}}},
 {phases={{changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Right"}}}}}},
 {phases={{changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Right"}}}},
  {changes={{kind="direction",entity_id=1,from="Right",to="Up"}}},
  {changes={{kind="move",entity_id=1,from={x=3,y=2,direction="Up"},to={x=2,y=2,direction="Left"}}}}}},
 {phases={{changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Right"}},
 {kind="direction",entity_id=1,from="Right",to="Up"}}}}},
 {phases={{changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=2,y=2,direction="Down"}}}}}},
 {phases={{changes={{kind="move",entity_id=1,from={x=2,y=2},to={x=3,y=2}}}}}}
}
local s=world(6,5,"Down")
local p,e=RW_PlanBackMotion(s.world,{{entity_id=1,before=before,record=records[3]}});assert(p,e)
local n,r=RW_Commit(s,p);assert(r.accepted and n.world.entities[1].x==2 and n.world.entities[1].y==2 and n.world.entities[1].direction=="Right")
assert(n.world.entities[1].level_link.target=="parent" and p.tele_suppressed[1]);assert(RW_Undo(n).world==s.world)
p=assert(RW_PlanBackMotion(s.world,{{entity_id=1,before=before,record=records[1]}}));n,r=RW_Commit(s,p)
assert(r.accepted and n.world.entities[1].x==6 and n.world.entities[1].y==5 and n.world.entities[1].direction=="Right")
-- No ordinary solver: history positions may overlap STOP/PUSH across FLOAT;
-- SLEEP/STILL/locks/REVERSE do not alter this explicit historical displacement.
s.world.entities[1].traits={sleep=true,still=true,lockedleft=true,reverse=true,float=true}
s.world.entities[2]={id=2,kind="object",class="object",archetype="rock",x=2,y=2,direction="Up",traits={block_entry=true,pushable=true}}
p=assert(RW_PlanBackMotion(s.world,{{entity_id=1,before=before,record=records[2]}}));n,r=RW_Commit(s,p);assert(r.accepted and n.world.entities[1].x==2 and n.world.entities[2].x==2)
-- Update rows suppress TELE even if the final state equals the current state.
s=world(2,2,"Right");p=assert(RW_PlanBackMotion(s.world,{{entity_id=1,before=before,record=records[2]}}));assert(#p.changes==0 and p.tele_suppressed[1])
-- Lifecycle records must not silently pass as complete BACK playback.
for _,kind in ipairs({"transform","retype","create","delete"}) do
 local record={phases={{changes={{kind=kind,entity_id=1}}}}}
 local p,e=RW_PlanBackMotion(s.world,{{entity_id=1,before=before,record=record}});assert(not p and e=="back_conversion_history_pending")
end
local p,e=RW_PlanBackMotion(s.world,{{entity_id=1,before=entity(3,2,"Right"),record=records[2]}});assert(not p and e=="stale_back_source")
assert(not RW_PlanBackMotion(s.world,{{entity_id=1,before=before,record=records[2]},{entity_id=1,before=before,record=records[2]}}))
s.world.too_complex=true;p,e=RW_PlanBackMotion(s.world,{});assert(not p and e=="too_complex_undo_only")
print("PASS: BACK motion absolute/net-zero/direction-only history, inherited facing, collision/lock independence, links/Undo, transient TELE marks and explicit unsupported lifecycle")

-- Run the installed update-row branch unchanged, with queued addaction dispatch.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],"rb"));local source=f:read("*a");f:close()
local section=assert(source:match('if %(style == "update"%) and %(line%[9%] == unit%.values%[ID%]%) then(.-)elseif %(style == "create"%)'))
local original_code='return function(currentundo,unit,unitid,paradox) for _,line in ipairs(currentundo) do if (line[1]=="update") and (line[9]==unit.values[ID]) then '..section..' end end end'
local env=setmetatable({ID="id",XPOS="x",YPOS="y",particles=function() end},{__index=_G})
local original=assert(load(original_code,"@installed_BACK_updates","t",env))()
local dirs={Right=0,Up=1,Left=2,Down=3,Mid=4,None=5};local names={[0]="Right","Up","Left","Down","Mid","None"}
local cases=0
for _,record in ipairs(records) do for _,at in ipairs({{2,2,"Left"},{6,5,"Down"},{3,2,"None"},{4,4,"Mid"}}) do for guard=0,2 do
 local lines={};local x,y,d=2,2,"Right"
 for _,phase in ipairs(record.phases) do for _,op in ipairs(phase.changes) do
  local nx,ny,nd=x,y,d
  if op.kind=="move" then nx,ny=op.to.x,op.to.y;nd=op.to.direction or d else nd=op.to end
  table.insert(lines,1,{"update","avatar",x,y,dirs[d],nx,ny,dirs[nd],1});x,y,d=nx,ny,nd
 end end
 local actions={};env.objectdata={};env.addaction=function(_,a) actions[#actions+1]=a end
 local paradox={};if guard==1 then paradox[1]=true elseif guard==2 then paradox[1]=false end
 original(lines,{values={id=1,x=at[1],y=at[2]}},11,paradox)
 x,y,d=at[1],at[2],at[3]
 for _,a in ipairs(actions) do if a[1]=="update" then x,y,d=a[2],a[3],names[a[4]] else d=names[a[2]] end end
 local s=world(at[1],at[2],at[3]);local p,e=RW_PlanBackMotion(s.world,{{entity_id=1,before=before,record=record}},paradox);assert(p,e)
 local after,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 local unit=after.world.entities[1];assert(unit.x==x and unit.y==y and unit.direction==d,"installed BACK update mismatch")
 assert((p.tele_suppressed[1]==true)==(env.objectdata[11]~=nil));assert(RW_Undo(after).world==s.world)
 cases=cases+1
end end end
assert(cases==72);print("PASS: installed BACK queued update/direction/paradox/TELE oracle (72 cases)")
