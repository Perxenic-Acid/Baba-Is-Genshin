local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function read(path) local f=assert(io.open(path,"rb"));local s=f:read("*a"):gsub("\r\n","\n");f:close();return s end
local root="C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/"
local blocks,tools=read(root.."blocks.lua"),read(root.."tools.lua")
local branch=assert(blocks:match('if %(style == "update"%) and %(line%[9%] == unit%.values%[ID%]%) then(.-)elseif %(style == "create"%)'))
local env=setmetatable({featureindex={},objectdata={},particles=function() end,updateunitmap=function() end},{__index=_G})
for word in ("ID DIR XPOS YPOS TILING UNITNAME UNITTYPE MOVED POSITIONING"):gmatch("%S+") do env[word]=word end
local native=assert(load('return function(rows,unit,unitid,paradox) for _,line in ipairs(rows) do if line[9]==unit.values[ID] then '..branch..' end end end',"@installed_BACK_queue_history","t",env))()
assert(load(assert(tools:match('(function update%(.-)\nfunction updatedir')),"@installed_update_history","t",env))()
assert(load(assert(tools:match('(function updatedir%(.-)\nfunction findtext')),"@installed_updatedir_history","t",env))()
local function fixture(x,y,d)
 local s=RW_CreateSession();s.world.width=12;s.world.height=10;s.world.next_entity_id=20
 s.world.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=x,y=y,direction=d}};return s
end
local records={
 {phases={{changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Right"}}}},
  {changes={{kind="move",entity_id=1,from={x=3,y=2,direction="Right"},to={x=2,y=2,direction="Right"}}}}}},
 {phases={{changes={{kind="direction",entity_id=1,from="Right",to="Up"}}},
  {changes={{kind="direction",entity_id=1,from="Up",to="Right"}}}}},
 {phases={{changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Down"}}}}}}
}
local original=fixture(2,2,"Right").world;local cases=0
for _,record in ipairs(records) do for _,at in ipairs({{2,2},{3,2},{8,6}}) do
for _,facing in ipairs({"Right","Up","Down","None"}) do for guard=0,1 do for _,class in ipairs({"object","text"}) do for copies=1,3 do
 local s=fixture(at[1],at[2],facing);if class=="text" then s.world.entities[1].class="text";s.world.entities[1].archetype=nil;s.world.entities[1].text={name="FLAG"} end
 local oldrows=assert(RW_BackHistoryRows(original,record));local native_rows={}
 -- BACK decides update vs updatedir using historical displacement, while the
 -- actual host functions independently filter unchanged dispatched actions.
 for _,row in ipairs(oldrows) do native_rows[#native_rows+1]={"update","avatar",row.x,row.y,row.direction,row.moved and row.x+1 or row.x,row.y,row.direction,1} end
 local unit={fixed=101,values={ID=1,XPOS=at[1],YPOS=at[2],DIR=facing,TILING=0,MOVED=1},strings={UNITNAME="avatar",UNITTYPE=class},x=0,y=0}
 env.mmf={newObject=function(handle) assert(handle==101);return unit end};env.objectdata={};env.updateundo=false;env.updatecode=0
 local actions,logged={},{};env.addaction=function(_,a) actions[#actions+1]=a end
 env.addundo=function(row) table.insert(logged,1,copy(row)) end
 local paradox=guard==1 and {[1]=true} or {}
 local instances={};for i=1,copies do native(native_rows,unit,101,paradox);instances[#instances+1]=1 end
 for _,a in ipairs(actions) do if a[1]=="update" then env.update(101,a[2],a[3],a[4]) else env.updatedir(101,a[2]) end end
 local plan=assert(RW_PlanBackFramePlayback(s.world,{{entity_id=1,before_world=original,record=record}},paradox,nil,instances))
 local after,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 local rows=assert(RW_BackHistoryRows(s.world,RW_GetTurnRecord(after,1)))
 assert(#rows==#logged,"BACK must journal the dispatched effective path, not just its final delta")
 for i,row in ipairs(rows) do local golden=logged[i]
  assert(row.kind=="update" and row.identity==golden[9] and row.x==golden[3] and row.y==golden[4] and row.direction==golden[5])
  assert(row.moved==(golden[3]~=golden[6] or golden[4]~=golden[7]))
 end
 local e=after.world.entities[1];assert(e.x==unit.values.XPOS and e.y==unit.values.YPOS and e.direction==unit.values.DIR)
 assert(env.updatecode==((class=="text" and #logged>0) and 1 or 0),"native updatecode must follow effective Text dispatch, including zero-net paths")
 assert((plan.tele_suppressed[1]==true)==(env.objectdata[101]~=nil));assert(RW_Undo(after).world==s.world)
 cases=cases+1
end end end end end end
assert(cases==432)
print("PASS: installed repeated BACK queue plus update/updatedir emitted-history oracle (432 cases), duplicate declarations, net-zero paths, filtered no-ops, Object/Text, paradox and Undo")

-- A retained zero-net BACK phase remains an input to later BACK, including TELE
-- suppression. A pure dispatched no-op instead produces no new history row.
local s=fixture(2,2,"Right")
local plan=assert(RW_PlanBackFramePlayback(s.world,{{entity_id=1,before_world=original,record=records[1]}}))
assert(#plan.changes==0 and #plan.motion_history==2)
local past,r=RW_Commit(s,plan);assert(r.accepted)
local nextback=assert(RW_PlanBackFramePlayback(past.world,{{entity_id=1,before_world=s.world,record=RW_GetTurnRecord(past,1)}}))
assert(#nextback.changes==0 and #nextback.motion_history==2 and nextback.tele_suppressed[1])
local diagnostic=assert(RW_PlanBackMotion(s.world,{{entity_id=1,before=original.entities[1],record=records[1]}}))
assert(#diagnostic.changes==0 and #diagnostic.motion_history==2)
local noop=assert(RW_PlanBackFramePlayback(s.world,{{entity_id=1,before_world=original,record=records[3]}}))
assert(#noop.changes==0 and not noop.motion_history and noop.tele_suppressed[1])

-- Mixed conversion playback retires only its own handle. All surviving queued
-- motion executes after immediate create/remove, as in native doupdate order.
local source=fixture(2,2,"Right");source.world.entities[2]=copy(source.world.entities[1]);source.world.entities[2].id=2
local ops,e,a,_,_,events=RW_PlanConversions(source.world,{{op="transform",source_type="avatar",target_type="rock"}});assert(ops,e)
local converted,r=RW_Commit(source,{consumes_turn=true,changes=ops,id_allocation=a,back_conversions=events});assert(r.accepted)
local mixed=copy(converted.world);mixed.entities[1]=copy(source.world.entities[1])
local p=assert(RW_PlanBackFramePlayback(mixed,{{entity_id=1,before_world=original,record=records[1]},
 {entity_id=2,before_world=source.world,record=RW_GetTurnRecord(converted,1)}}))
assert(#p.changes==1 and p.changes[1].kind=="back_restore" and #p.motion_history==2)
for _,row in ipairs(p.motion_history) do assert(row.before_change==#p.changes+1) end
local after,r=RW_Commit({world=mixed,history={}},p);assert(r.accepted,r.reason)
local rows=assert(RW_BackHistoryRows(mixed,RW_GetTurnRecord(after,1)))
assert(rows[1].kind=="update" and rows[2].kind=="update" and rows[3].kind=="create" and rows[4].kind=="remove")
assert(p.tele_suppressed[1] and not p.tele_suppressed[2] and after.world.entities[2].archetype=="avatar")
local legacy=assert(RW_PlanBackPlayback(mixed,{{entity_id=1,before=original.entities[1],record=records[1]},
 {entity_id=2,before=source.world.entities[2],record=RW_GetTurnRecord(converted,1)}}))
assert(#legacy.motion_history==2 and legacy.motion_history[1].before_change==#legacy.changes+1)
local oldpath,r=RW_Commit({world=mixed,history={}},legacy);assert(r.accepted,r.reason)
local oldrows=assert(RW_BackHistoryRows(mixed,RW_GetTurnRecord(oldpath,1)))
assert(oldrows[1].kind=="update" and oldrows[3].kind=="create" and RW_Undo(oldpath).world==mixed)
for _,mutate in ipairs({
 function(q) q.motion_history[1].before_change=0 end,
 function(q) q.motion_history[1].before_change=false end,
 function(q) q.motion_history[1].before_change=#q.changes+2 end,
 function(q) q.motion_history[2].before_change=1 end,
 function(q) q.motion_history[1].entity_id=2 end,
 function(q) q.motion_history[2].from.direction="Left" end,
 function(q) q.back_conversions={} end,
}) do local bad=copy(p);mutate(bad);local rejected,r=RW_Commit({world=mixed,history={}},bad);assert(not r.accepted) end
assert(RW_Undo(after).world==mixed)
print("PASS: repeated BACK net-zero history, diagnostic parity, no-op filtering, mixed motion/restoration dispatch order, retired handles, anchor validation and Undo")

local aliases=fixture(2,2,"Right");aliases.world.entities[2]=copy(aliases.world.entities[1]);aliases.world.entities[2].id=2;aliases.world.entities[2].back_identity=1
local selections={{entity_id=1,before_world=original,record=records[1]},{entity_id=2,before_world=original,record=records[1]}}
local repeated=assert(RW_PlanBackFramePlayback(aliases.world,selections,nil,nil,{1,2,1}))
local physical={1,1,2,2,1,1};assert(#repeated.changes==0 and #repeated.motion_history==#physical)
for i,id in ipairs(physical) do assert(repeated.motion_history[i].entity_id==id) end
local after,r=RW_Commit(aliases,repeated);assert(r.accepted,r.reason)
assert(repeated.tele_suppressed[1] and repeated.tele_suppressed[2] and RW_Undo(after).world==aliases.world)
for _,bad in ipairs({false,{}, {1,999}, {[1]=1,[3]=2}}) do
 local p,e=RW_PlanBackFramePlayback(aliases.world,selections,nil,nil,bad);assert(not p and e=="invalid_back_instances")
end
local retired=assert(RW_PlanBackFramePlayback(mixed,{{entity_id=1,before_world=original,record=records[1]},
 {entity_id=2,before_world=source.world,record=RW_GetTurnRecord(converted,1)}},nil,nil,{1,2,1,2}))
assert(#retired.changes==1 and retired.changes[1].entity_id==2 and #retired.motion_history==4)
assert(not retired.tele_suppressed[2] and not retired.id_allocation)
print("PASS: BACK duplicate instance order keeps aliased physical handles distinct, validates coverage and never routes old selections onto replacements")
