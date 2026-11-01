local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function fixture(text)
 local s=RW_CreateSession();s.world.width=10;s.world.height=10;s.world.next_entity_id=10
 s.world.entities={[1]={id=1,kind="object",class=text and "text" or "object",archetype=not text and "avatar" or nil,text=text and {name="AVATAR"} or nil,x=2,y=2,direction="Up",original_name="flag",broken=1,holder=8,followed=7,back_init=3,level_link={target="parent",source_type="avatar"}}}
 return s
end
local function history(text)
 local s=fixture(text);local before=copy(s.world.entities[1]);s.world.entities[1].broken=nil
 -- The public conversion planner is used to obtain real transform/retype rows.
 local ops,e,allocation=RW_PlanConversions(s.world,{{op="transform",source_type=text and "@text" or "avatar",target_type="rock"}});assert(ops,e)
 before=copy(s.world.entities[1])
 local converted,r=RW_Commit(s,{consumes_turn=true,changes=ops,id_allocation=allocation});assert(r.accepted)
 local record=assert(RW_GetTurnRecord(converted,1));return before,record,converted
end
for _,text in ipairs({false,true}) do
 local before,record,current=history(text)
 local old=copy(current.world.entities[1]);old.x,old.y,old.direction=6,5,"Left";old.broken=1;old.holder=9;old.followed=4;old.back_init=8
 current.world.entities[1]=old
 local p,e=RW_PlanBackPlayback(current.world,{{entity_id=1,before=before,record=record}});assert(p,e)
 assert(#p.changes==1 and p.changes[1].kind=="back_restore" and next(p.tele_suppressed)==nil)
 local restored,r=RW_Commit(current,p);assert(r.accepted,r.reason);local unit=restored.world.entities[1]
 assert(unit.x==6 and unit.y==5 and unit.direction=="Up" and unit.class==before.class)
 assert(unit.archetype==before.archetype and (not text or unit.text.name=="AVATAR"))
 assert(unit.back_init==3 and unit.followed==7 and not unit.holder and not unit.broken and not unit.original_name)
 assert(RW_GetOriginalName(unit)==(text and "text_AVATAR" or "avatar"))
 assert(unit.level_link.target=="parent" and RW_Undo(restored).world==current.world)
 local guard=assert(RW_PlanBackPlayback(current.world,{{entity_id=1,before=before,record=record}},{[1]=false}));assert(#guard.changes==0)
 local stale=copy(p);stale.changes[1].from.direction="Right";local same,r=RW_Commit(current,stale);assert(same==current and not r.accepted)
 local forged=copy(p);forged.changes[1].to.original_name="flag";local same,r=RW_Commit(current,forged);assert(same==current and not r.accepted)
end
-- Native conversion restoration deletes the queued-update handle: earlier/later
-- movement rows cannot drag the newly restored handle to a historical position.
local before,record,current=history(false)
table.insert(record.phases,1,{changes={{kind="move",entity_id=1,from={x=1,y=2,direction="Up"},to={x=2,y=2,direction="Up"}}}})
before.x=1
record.phases[#record.phases+1]={changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Up"},to={x=3,y=2,direction="Right"}}}}
current.world.entities[1].x=7
local p,e=RW_PlanBackPlayback(current.world,{{entity_id=1,before=before,record=record}});assert(p,e);assert(p.changes[1].to.x==7 and p.changes[1].to.direction=="Up")
local double=copy(record);double.phases[#double.phases+1]={changes={{kind="transform",entity_id=1,from="rock",to="flag"}}}
local no,e=RW_PlanBackPlayback(current.world,{{entity_id=1,before=before,record=double}});assert(not no and e=="back_conversion_history_pending")
local conflict=copy(p);conflict.changes[#conflict.changes+1]={kind="direction",entity_id=1,from="Up",to="Right"};local same,r=RW_Commit(current,conflict);assert(same==current and not r.accepted)
print("PASS: BACK primary transform/retype restoration at current position, direction/clocks/links/follow memory, origin/status reset, handle-independent motion, explicit repeated lifecycle gap and atomic Undo")

local f=assert(io.open("C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua","rb"));local source=f:read("*a"):gsub("\r\n","\n");f:close()
local branch=assert(source:match('elseif %(style == "create"%) and %(line%[3%] == unit%.values%[ID%]%) then(.-)\n\t\t\t\t\tend\n\t\t\t\tend\n\t\t\tend\n\t\tend'))
local env=setmetatable({},{__index=_G})
for name in ("ID DIR XPOS YPOS ONLINE UNITNAME UNITTYPE U_LEVELFILE U_LEVELNAME MAPLEVEL VISUALLEVEL VISUALSTYLE COMPLETED COLOUR CLEARCOLOUR UNITSIGNTEXT"):gmatch("%S+") do env[name]=name end
local native=assert(load('return function(unit,currentundo,unitid,paradox,line) if true then '..branch..' end',"@installed_BACK_create","t",env))()
for _,name in ipairs({"MF_setcolourfromstring","addunitmap","dynamic","addundo","MF_alert","delunit","MF_specialremove"}) do env[name]=function() end end
local dirs={Right=0,Up=1,Left=2,Down=3,Mid=4,None=5}
local cases=0
for _,text in ipairs({false,true}) do for _,at in ipairs({{6,5},{3,2},{2,2}}) do for guard=0,2 do for _,direction in ipairs({"Left","Mid","None"}) do
 local before,record,current=history(text);local source_name=text and "text_AVATAR" or "avatar"
 local u=current.world.entities[1];u.x,u.y,u.direction=at[1],at[2],direction
 local created={};env.unitreference={[source_name]=source_name}
 env.MF_emptycreate=function(name,x,y)
  created[22]={className=name,values={XPOS=x,YPOS=y},strings={UNITNAME=name,UNITTYPE=text and "text" or "object"},flags={}}
  return 22
 end
 env.mmf={newObject=function(id) return assert(created[id]) end}
 env.addunit=function(id,undoing)
  assert(undoing==true);local new=created[id];new.originalname=new.strings.UNITNAME;new.back_init=0;new.broken=0;new.holder=0;new.followed=-1
 end
 local unit={values={XPOS=at[1],YPOS=at[2],DIR=dirs[direction],ID=1},strings={UNITNAME="rock"},flags={}}
 local rows={{"remove",source_name,2,2,1,1,1,"parent","level name",2,1,3,true,"1,2","1,3",7,3}}
 rows.wordunits={};rows.wordrelatedunits={}
 local paradox={};if guard==1 then paradox[1]=true elseif guard==2 then paradox[1]=false end
 native(unit,rows,11,paradox,{"create","rock",1,1,"convert"})
 local plan,e=RW_PlanBackPlayback(current.world,{{entity_id=1,before=before,record=record}},paradox);assert(plan,e)
 local after,r=RW_Commit(current,plan);assert(r.accepted,r.reason)
 if guard==0 then
  local actual=after.world.entities[1];local original=assert(created[22])
  assert(actual.x==original.values.XPOS and actual.y==original.values.YPOS and dirs[actual.direction]==original.values.DIR)
  assert(RW_GetOriginalName(actual)==original.originalname and actual.followed==original.followed and actual.back_init==original.back_init)
  assert((actual.holder or 0)==original.holder and (actual.broken or 0)==original.broken and actual.level_link.target==original.strings.U_LEVELFILE)
 else assert(not created[22] and #plan.changes==0) end
 cases=cases+1
end end end end
assert(cases==54);print("PASS: unchanged installed BACK create/remove restoration oracle (54 cases)")

local session=fixture(false);session.world.entities[1].broken=nil
local ops,e,allocation=RW_PlanConversions(session.world,{{op="transform",source_type="avatar",target_type="rock"}});assert(ops,e)
session=RW_Commit(session,{consumes_turn=true,changes=ops,id_allocation=allocation,back_frame={from=1,retain=true}})
session=RW_Commit(session,{consumes_turn=true,changes={{kind="back_init",entity_id=1,from=3,to=2}},back_frame={from=2,retain=true}})
local prefix={consumes_turn=true,changes={}}
local restore,e=RW_PlanBackHistoryMotion(session,prefix,{[1]=true});assert(restore,e)
assert(restore.back_retain and restore.changes[1].kind=="back_restore" and next(restore.tele_suppressed)==nil)
restore.back_frame={from=3,retain=true};local restored,r=RW_Commit(session,restore);assert(r.accepted and restored.world.entities[1].archetype=="avatar" and restored.world.entities[1].back_init==3)
assert(RW_Undo(restored).world==session.world)
print("PASS: BACK clock-ledger selection integrates primary conversion restoration and source clock/whole-turn Undo")
