local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function fixture()
 local s=RW_CreateSession();local w=s.world;w.width=12;w.height=10;w.next_entity_id=20
 w.entities={};return s
end
local function object(w,id,name,direction)
 w.entities[id]={id=id,kind="object",class="object",archetype=name,x=2,y=2,direction=direction}
end
local file=assert(io.open("C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua","rb"))
local source=file:read("*a"):gsub("\r\n","\n");file:close()
local alignment=assert(source:match('(\t\tfor a,unitid in ipairs%(isshift%) do.-)\n\t\tdoupdate%(%)'))
local env=setmetatable({featureindex={},XPOS="x",YPOS="y",DIR="direction",ID="id",UNITNAME="name",DEAD="dead"},{__index=_G})
local native=assert(load("return function(isshift) "..alignment.." end","@installed_SHIFT_alignment","t",env))()
local directions={"Right","Up","Left","Down"};local cases=0
for n=1,3 do for _,facing in ipairs(directions) do for _,heading in ipairs(directions) do
for sleep=0,1 do for layer=0,1 do for reversed=0,1 do
 local s=fixture();local w=s.world;local ids,belts={},{}
 for id=1,n do object(w,id,"belt",id%2==0 and "Down" or heading);ids[#ids+1]=id;belts[#belts+1]=id end
 object(w,10,"rock",facing);ids[#ids+1]=10
 if reversed==1 then local order={};for i=#ids,1,-1 do order[#order+1]=ids[i] end;w.unit_order=order
  local order={};for i=#belts,1,-1 do order[#order+1]=belts[i] end;belts=order end
 local effects={{op="grant_trait",entity_ids=ids,trait="still"},{op="grant_trait",entity_ids=belts,trait="shift"}}
 if sleep==1 then effects[#effects+1]={op="grant_trait",entity_ids={1},trait="sleep"} end
 if layer==1 then effects[#effects+1]={op="grant_trait",entity_ids={10},trait="float"} end
 local projected=assert(RW_ProjectWorld(w,effects));local units={};local golden={}
 for id,u in pairs(projected.entities) do units[id]={fixed=id+100,values={id=id,x=u.x,y=u.y,direction=u.direction},strings={name=u.archetype},flags={dead=false}} end
 -- Native handles 1 and 2 are reserved LEVEL/EMPTY, unlike our physical IDs.
 env.mmf={newObject=function(handle) return units[handle-100] end}
 env.findallhere=function(x,y,except) local result={};for _,id in ipairs(w.unit_order or ids) do if id+100~=except then result[#result+1]=id+100 end end;return result end
 env.floating=function(a,b) return (projected.entities[a-100].behaviors.float==true)==(projected.entities[b-100].behaviors.float==true) end
 env.issleep=function(handle) return projected.entities[handle-100].behaviors.sleep==true end
 env.isgone=function() return false end
 env.addundo=function(row) golden[#golden+1]=copy(row) end
 env.updatecode=0
 local handles={};for _,id in ipairs(belts) do handles[#handles+1]=id+100 end;native(handles)
 assert(env.updatecode==0,"native direct SHIFT alignment never invalidates code, including changed facing")
 local plan=assert(RW_ResolveShift(projected));local rows=plan.motion_history or {}
 assert(#rows==#golden,table.concat({"SHIFT row mismatch",n,facing,heading,sleep,layer,reversed,#rows,#golden},":"))
 for i,row in ipairs(rows) do local expected=golden[i]
  assert(row.entity_id==expected[9] and row.from.direction==expected[5] and row.to.direction==expected[8])
  assert(row.from.x==expected[3] and row.from.y==expected[4] and row.to.x==expected[6] and row.to.y==expected[7])
 end
 local after,e=RW_PreviewPlan(w,plan);assert(after,e)
 assert(RW_BackRetainDecision(w,plan,false)==false,"native direct SHIFT alignment does not set updateundo, even when facing changes")
 for id,u in pairs(after.entities) do assert(u.direction==units[id].values.direction) end
 cases=cases+1
end end end end end end
assert(cases==384)
print("PASS: installed SHIFT alignment history oracle (384 cases), no-ops, stacked sources, unit order, SLEEP and FLOAT")

-- Multiple impulse rounds, PUSH dependencies and blocked WEAK deaths must retain
-- a complete motion path whose inverse agrees with the authoritative snapshots.
for _,heading in ipairs(directions) do for sources=1,2 do for push=0,1 do for weak=0,1 do
 local s=fixture();local w=s.world;local belts={}
 for id=1,sources do object(w,id,"belt",heading);belts[#belts+1]=id end
 object(w,10,"avatar","Down");object(w,11,"rock","Left");object(w,12,"wall","Up")
 local v=({Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}})[heading]
 for _,u in pairs(w.entities) do u.x,u.y=5,5 end
 w.entities[11].x,w.entities[11].y=5+v[1],5+v[2]
 w.entities[12].x,w.entities[12].y=5+v[1]*2,5+v[2]*2
 local effects={{op="grant_trait",entity_ids=belts,trait="shift"},{op="grant_trait",entity_ids=belts,trait="still"},
  {op="grant_trait",entity_ids={12},trait="stop"}}
 if push==1 then effects[#effects+1]={op="grant_trait",entity_ids={11},trait="push"} end
 if weak==1 then effects[#effects+1]={op="grant_trait",entity_ids={10},trait="weak"} end
 local plan=assert(RW_ResolveShift(assert(RW_ProjectWorld(w,effects))))
 local after,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 local record=RW_GetTurnRecord(after,1);local selections={}
 for id in pairs(w.entities) do selections[#selections+1]={entity_id=id,before_world=w,record=record} end
 local back=assert(RW_PlanBackFramePlayback(after.world,selections));local reversed=assert(RW_PreviewPlan(after.world,back))
 for id,u in pairs(w.entities) do local actual=reversed.entities[id]
  assert(actual.x==u.x and actual.y==u.y and actual.direction==u.direction,"SHIFT history must invert every displacement/facing path")
 end
end end end end
print("PASS: SHIFT multi-impulse/PUSH/blocked-WEAK history path validation and inverse playback (32 cases)")

-- A no-op update is still a historical BACK update, so it suppresses TELE.
local s=fixture();object(s.world,1,"belt","Right");object(s.world,10,"avatar","Right")
local projected=assert(RW_ProjectWorld(s.world,{{op="grant_trait",entity_ids={1},trait="shift"},{op="grant_trait",entity_ids={1,10},trait="still"}}))
local plan=assert(RW_ResolveShift(projected));assert(#plan.changes==0 and #plan.motion_history==1)
assert(RW_BackRetainDecision(s.world,plan,false)==false)
plan.back_frame={from=1,retain=true}
local past,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
local record=assert(RW_GetTurnRecord(past,1));local rows=assert(RW_BackHistoryRows(s.world,record))
assert(#rows==1 and rows[1].kind=="update" and not rows[1].moved)
plan.motion_history[1].from.direction="Left";assert(RW_GetTurnRecord(past,1).phases[1].motion_history[1].from.direction=="Right")
record.phases[1].motion_history[1].to.direction="Down";record=RW_GetTurnRecord(past,1)
local back=assert(RW_PlanBackFramePlayback(past.world,{{entity_id=10,before_world=s.world,record=record}}))
assert(#back.changes==0 and back.tele_suppressed[10])
local diagnostic=assert(RW_PlanBackMotion(past.world,{{entity_id=10,before=s.world.entities[10],record=record}}))
assert(#diagnostic.changes==0 and diagnostic.tele_suppressed[10])
local telebase=copy(past.world);object(telebase,2,"belt","Right");telebase.entities[2].x=8
local teleworld=assert(RW_ProjectWorld(telebase,{{op="grant_trait",entity_ids={1,2},trait="tele"}}))
local suppressed=assert(RW_ResolveTele(teleworld,back.tele_suppressed));local free=assert(RW_ResolveTele(teleworld))
assert(#suppressed.changes==0 and not suppressed.random_state and #free.changes==1 and free.random_state)
assert(not past.world.motion_history and RW_Undo(past).world==s.world)

-- Ordered net-zero updates retain history even if the final board is identical.
local history={consumes_turn=true,changes={},motion_history={
 {kind="move",entity_id=10,from={x=2,y=2,direction="Right"},to={x=2,y=2,direction="Up"}},
 {kind="move",entity_id=10,from={x=2,y=2,direction="Up"},to={x=2,y=2,direction="Right"}}}}
assert(RW_BackRetainDecision(s.world,history,false)==true)
for _,mutate in ipairs({
 function(p) p.motion_history[1].from.x=3 end,
 function(p) p.motion_history[2].to.direction="Down" end,
 function(p) p.motion_history[2].from=nil end,
 function(p) p.motion_history[2].to.x=99 end,
 function(p) p.motion_history[1].entity_id=999 end,
 function(p) p.motion_history[1].retain="yes" end,
 function(p) p.changes={{kind="broken",entity_id=10,from=0,to=1}} end,
}) do
 local bad=copy(history);mutate(bad);local rejected,r=RW_Commit(s,bad);assert(not r.accepted and rejected==s)
end
local staged=assert(RW_PlanStages(s.world,{{name="shift",plan=history}}))
local invalid=copy(staged);invalid.motion_history=history.motion_history;assert(not RW_PreviewPlan(s.world,invalid))
local after,r=RW_Commit(s,staged);assert(r.accepted,r.reason);assert(RW_Undo(after).world==s.world)
local rollback=copy(staged);rollback.stages[#rollback.stages+1]={name="late",plan={consumes_turn=true,changes={{kind="direction",entity_id=10,from="Down",to="Up"}}}}
local rejected,r=RW_Commit(s,rollback);assert(not r.accepted and rejected==s and #s.history==0)
print("PASS: SHIFT history-only BACK/TELE suppression, RNG purity, retained net-zero paths, ownership, stale validation, late failure and Undo")
