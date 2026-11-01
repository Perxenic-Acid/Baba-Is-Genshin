local root=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(root..name,"rb"));local s=f:read("*a"):gsub("\r\n","\n");f:close();return s end
local tools,blocks,undo=read("tools.lua"),read("blocks.lua"),read("undo.lua")
local function prefix(source,start,finish)
 local a=assert(source:find(start,1,true));local b=assert(source:find(finish,a,true));return source:sub(a,b-1)
end
local env=setmetatable({XPOS="x",YPOS="y",DIR="dir",ID="id",TILING="tiling",UNITNAME="name",UNITTYPE="type",MOVED="moved",
 DEAD="dead",particles=function() end,addundo=function() end,
 generaldata2={values={}},UNDOTOOLTIPTIMER="timer",last_key=4,Fixedseed=17,wordunits={},wordrelatedunits={},visiontargets={},doundo=true},{__index=_G})
assert(load(prefix(tools,"function update(unitid,x,y,dir_)","local ox,oy = x-oldx,y-oldy").."end end end","@installed_update_retention","t",env))()
assert(load(prefix(tools,"function updatedir(unitid,dir,noundo_)","unit.values[DIR] = dir").."end end end","@installed_updatedir_retention","t",env))()
assert(load(assert(undo:match("^(.-)function addundo")),"@installed_newundo_retention","t",env))()
local index=prefix(blocks,"local undooffset = #undobuffer - unit.back_init","if (currentundo ~= nil) then")
local native_back=assert(load("return function(unit) "..index.." end end","@installed_back_retain","t",env))()
local dirs={"Right","Up","Left","Down","Mid","None"};local cases=0
local function fixture(direction)
 local s=RW_CreateSession();s.world.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction=direction or "Right"}};return s
end
local function count_flag(retain)
 env.undobuffer={{}};env.updateundo=retain;env.newundo();assert(#env.undobuffer==(retain and 2 or 1))
end
for old,from in ipairs(dirs) do for new,to in ipairs(dirs) do for distance=0,2 do
 for _,kind in ipairs({"move","direction"}) do
  local s=fixture(from);local w=s.world
  local unit={values={x=2,y=2,dir=old-1,id=1},strings={name="avatar",type="object"}}
  env.mmf={newObject=function() return unit end};env.updateundo=false
  local op
  if kind=="move" then
   env.update(1,2+distance,2,new-1)
   op={kind="move",entity_id=1,from={x=2,y=2,direction=from},to={x=2+distance,y=2,direction=to}}
  else env.updatedir(1,new-1);op={kind="direction",entity_id=1,from=from,to=to} end
  local changes=(kind=="direction" and from==to) and {} or {op}
  local retain,why=RW_BackRetainDecision(w,{consumes_turn=true,changes=changes},false)
  assert(type(retain)=="boolean",why)
  assert(retain==env.updateundo,"native update retain mismatch");count_flag(retain);cases=cases+1
 end
end end end
for count=1,8 do for clock=0,10 do for _,dead in ipairs({false,true}) do
 env.undobuffer={};for i=1,count do env.undobuffer[i]={} end;env.updateundo=false
 native_back({back_init=clock,values={x=2,y=2},flags={dead=dead}})
 local expected=env.updateundo
 local active=RW_BackFrameIndex(clock,count,dead)~=nil
 assert(RW_BackRetainDecision(fixture().world,{consumes_turn=true,changes={}},active)==expected)
 count_flag(expected);cases=cases+1
end end end
local s=fixture();local p={consumes_turn=true,changes={{kind="back_init",entity_id=1,to=2},{kind="followed",entity_id=1,to=2},
 {kind="broken",entity_id=1,to=1}},input_state={from="none",to="wait"},chance_state={from=1,to=48271},random_state={from=1,to=48271}}
assert(RW_BackRetainDecision(s.world,p,false)==false)
local forward={kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Right"}}
local backward={kind="move",entity_id=1,from={x=3,y=2,direction="Right"},to={x=2,y=2,direction="Right"}}
p=assert(RW_PlanStages(s.world,{{name="forward",plan={consumes_turn=true,changes={forward}}},{name="backward",plan={consumes_turn=true,changes={backward}}}}))
assert(RW_BackRetainDecision(s.world,p,false))
assert(RW_PreviewPlan(s.world,p).entities[1].x==s.world.entities[1].x)
-- Validation covers the complete plan even when its first phase would retain.
p.stages[2].plan.changes[1].from.x=11
local retain,why=RW_BackRetainDecision(s.world,p,false);assert(retain==nil and why=="stale_operation")
for _,spec in ipairs({
 {changes={{kind="transform",entity_id=1,from="avatar",to="flag"}}},
 {changes={},back_conversions={{source=s.world.entities[1],removed=true,product_ids={1}}}},
 {changes={},board_shift={from={x=0,y=0,direction="None"},to={x=0,y=0,direction="None"}}},
 {changes={},too_complex=true}}) do spec.consumes_turn=true;assert(RW_BackRetainDecision(s.world,spec,false)) end
assert(cases==392)
print("PASS: installed update/updatedir/BACK/newundo retention oracle (392 cases), metadata pruning, net-zero phase retention and complete-plan validation")
