local function clone(v) if type(v)~="table" then return v end;local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r end
local function fixture()
 local s=RW_CreateSession();s.world.width=12;s.world.height=10;s.world.next_entity_id=10;s.world.entities={
 [1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Up"},
 [2]={id=2,kind="object",class="object",archetype="rock",x=5,y=2,direction="Right",back_identity=1},
 [3]={id=3,kind="object",class="object",archetype="crate",x=8,y=2,direction="Left",holder=1}};return s
end
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local f=assert(io.open(base.."syntax.lua","rb"));local syntax=f:read("*a"):gsub("\r\n","\n");f:close()
local f=assert(io.open(base.."tools.lua","rb"));local tools=f:read("*a"):gsub("\r\n","\n");f:close()
local insertion=assert(syntax:match("^(.-)\n\tlocal unit = units%[unitid%]"))
local removal=assert(tools:match("(for i,v in ipairs%(units%) do.-)\n\tfor i,data in pairs%(updatelist%) do"))
local lookup=assert(tools:match("(function getunitid%(id%).-)\nfunction newid"))
local env=setmetatable({units={},ID="ID",objects={}},{__index=_G})
env.mmf={newObject=function(handle) return assert(env.objects[handle]) end}
env.MF_alert=function() error("missing native identity") end
assert(load(insertion.." end","@installed_addunit_insertion","t",env))()
local remove=assert(load("return function(unitid) "..removal.." end","@installed_delunit_removal","t",env))()
assert(load(lookup,"@installed_getunitid_order","t",env))()
local handles,next_handle={},100
local function create(id,entity)
 local handle=next_handle;next_handle=next_handle+1
 env.objects[handle]={fixed=handle,physical=id,values={ID=RW_GetBackIdentity(entity)}};env.addunit(handle);handles[id]=handle
 return handle
end
local s=fixture();for id=1,3 do create(id,s.world.entities[id]) end
local births={}
for turn=1,80 do
 local mode=turn%5;local plan
 if mode==1 then local e=s.world.entities[1];plan={consumes_turn=true,changes={{kind="transform",entity_id=1,from=e.archetype,to=e.archetype=="avatar" and "wall" or "avatar"}}}
 elseif mode==2 then local e=s.world.entities[2];local source=clone(e);plan={consumes_turn=true,changes={{kind="back_restore",entity_id=2,from=clone(e),source=source,to=RW_BackRestoredEntity(source,e)}}}
 elseif mode==3 then
  local source=clone(s.world.entities[1]);plan={consumes_turn=true,changes={},back_conversions={{source=source,product_ids={1},removed=true}}}
 elseif mode==4 then plan=assert(RW_PlanCreate(s.world,{{kind="object",class="object",archetype="flag",x=10,y=9,direction="None"}}));births[#births+1]=s.world.next_entity_id
 else plan=assert(RW_PlanDelete(s.world,{table.remove(births,1)})) end
 local old=s;local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 if plan.back_conversions then
  for _,event in ipairs(plan.back_conversions) do local old_handle=handles[event.source.id]
   for _,id in ipairs(event.product_ids) do create(id,n.world.entities[id]) end
   if event.removed then remove(old_handle) end
  end
 else
  for _,op in ipairs(plan.changes) do
   if op.kind=="delete" then remove(handles[op.entity_id]);handles[op.entity_id]=nil
   elseif op.kind=="create" then create(op.entity_id,n.world.entities[op.entity_id])
   elseif op.kind=="transform" or op.kind=="retype" or op.kind=="back_restore" then local old_handle=handles[op.entity_id];create(op.entity_id,n.world.entities[op.entity_id]);remove(old_handle) end
  end
 end
 local ids=assert(RW_UnitIds(n.world));assert(#ids==#env.units)
 for index,u in ipairs(env.units) do assert(ids[index]==u.physical,"native add/remove unit order mismatch") end
 local first
 for _,id in ipairs(ids) do if RW_GetBackIdentity(n.world.entities[id])==1 then first=id;break end end
 assert(env.objects[env.getunitid(1)].physical==first)
 assert(RW_Undo(n).world==old.world)
 s=n
end
print("PASS: installed addunit/delunit/getunitid order oracle (80 structural turns), replacement, same-name conversion, birth/deletion, shared lookup and Undo")
local ids=RW_UnitIds(s.world);ids[1]=99;assert(RW_UnitIds(s.world)[1]~=99)
local start=fixture();local create_plan=assert(RW_PlanCreate(start.world,{{kind="object",class="object",archetype="flag",x=9,y=9,direction="None"}}))
local one={kind="transform",entity_id=1,from="avatar",to="wall"};local a={consumes_turn=true,changes={one,create_plan.changes[1]},id_allocation=create_plan.id_allocation}
local b={consumes_turn=true,changes={create_plan.changes[1],one},id_allocation=create_plan.id_allocation}
local x=assert(RW_PreviewPlan(start.world,a));local y=assert(RW_PreviewPlan(start.world,b))
assert(table.concat(RW_UnitIds(x),",")==table.concat(RW_UnitIds(y),","))
a.unit_sequence={10,1};local explicit=assert(RW_PreviewPlan(start.world,a));assert(table.concat(RW_UnitIds(explicit),",")=="2,3,10,1")
local compiled={consumes_turn=true,changes={},back_conversions={{source=clone(start.world.entities[1]),product_ids={1},removed=true}}}
local changed,r=RW_Commit(start,compiled);assert(r.accepted and r.changed and changed.world~=start.world and table.concat(RW_UnitIds(changed.world),",")=="2,3,1")
local record=RW_GetTurnRecord(changed,1);local rows=assert(RW_BackHistoryRows(start.world,record));assert(#rows==2 and rows[1].kind=="remove")
for _,bad in ipairs({{}, {1,1,2}, {1,2}, {1,2,99}, false}) do
 local invalid=clone(start);invalid.world.unit_order=bad
 local same,r=RW_Commit(invalid,{consumes_turn=true,changes={}});assert(same==invalid and not r.accepted and r.reason=="invalid_unit_order")
 assert(not RW_CreateLevelDefinition("bad",invalid.world))
end
for _,sequence in ipairs({{1},{1,1},{1,99},false}) do
 local bad=clone(a);bad.unit_sequence=sequence;local same,r=RW_Commit(start,bad);assert(same==start and not r.accepted and r.reason=="invalid_unit_sequence")
end
local stages=assert(RW_PlanStages(start.world,{{name="replacement",plan=compiled},{name="wait",plan={consumes_turn=true,changes={}}}}))
local staged,r=RW_Commit(start,stages);assert(r.accepted and r.changed and table.concat(RW_UnitIds(staged.world),",")=="2,3,1")
local bad=clone(stages);bad.stages[2].plan.changes={{kind="direction",entity_id=2,from="Left",to="Down"}};bad.changes=clone(bad.stages[2].plan.changes)
local same,r=RW_Commit(start,bad);assert(same==start and not r.accepted and start.world.unit_order==nil)
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",start.world))},"root"));local session=RW_GetActiveLevel(tree)
local next_session,r=RW_Commit(session,compiled);assert(r.accepted)
local updated=assert(RW_UpdateActiveLevel(tree,next_session));local next_tree,r=RW_CommitLevelTree(tree,{before=tree,after=updated});assert(r.accepted)
local reloaded=assert(RW_ReloadLevel(next_tree,next_tree.active_id));assert(RW_GetActiveLevel(reloaded).world.unit_order==nil)
local boundary,r=RW_CommitLevelTree(next_tree,{before=next_tree,after=reloaded});assert(r.accepted)
assert(RW_UndoLevelTree(boundary).instances[tree.active_id]==next_session and RW_GetActiveLevel(RW_UndoLevelTree(next_tree))==session)
print("PASS: unit-order ownership, simultaneous flat plans vs explicit native sequence, order-only changes, metadata validation, late rejection, boundary and whole-tree Undo")
