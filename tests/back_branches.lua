local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function fixture()
 local s=RW_CreateSession();s.world.width=12;s.world.height=10;s.world.next_entity_id=10
 s.world.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Up",followed=7,back_init=3,level_link={target="parent",source_type="avatar"}}};return s
end
local function conversion(w,source,targets)
 local relations={};for _,target in ipairs(targets) do relations[#relations+1]={op="transform",source_type=source,target_type=target} end
 local ops,e,a,_,_,events=RW_PlanConversions(w,relations);assert(ops,e)
 return {consumes_turn=true,changes=ops,id_allocation=a,back_conversions=events}
end
local s=fixture();local p=conversion(s.world,"avatar",{"rock","flag"});local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
local before=copy(s.world);local record=assert(RW_GetTurnRecord(n,1))
n.world.entities[10].x=7;n.world.entities[10].y=6;n.world.entities[10].direction="Left"
local plan,e=RW_PlanBackFramePlayback(n.world,{{entity_id=10,before_world=before,record=record}});assert(plan,e)
local restored,r=RW_Commit(n,plan);assert(r.accepted,r.reason)
assert(restored.world.entities[10].archetype=="avatar" and restored.world.entities[10].x==7 and restored.world.entities[10].direction=="Up")
assert(restored.world.entities[10].back_identity==1 and RW_GetBackIdentity(restored.world.entities[10])==1)
assert(restored.world.entities[1].archetype=="rock" and restored.world.entities[10].level_link.target=="parent")
assert(RW_Undo(restored).world==n.world)
local guard=assert(RW_PlanBackFramePlayback(n.world,{{entity_id=10,before_world=before,record=record}},{[1]=false}));assert(#guard.changes==0)
local unrelated=assert(RW_PlanBackFramePlayback(n.world,{{entity_id=10,before_world=before,record=record}},{[10]=false}));assert(unrelated.changes[1].kind=="back_restore")
-- Both branches can coexist with the same native identity and unique instances.
local both=assert(RW_PlanBackFramePlayback(n.world,{{entity_id=10,before_world=before,record=record},{entity_id=1,before_world=before,record=record}}))
local b,r=RW_Commit(n,both);assert(r.accepted and b.world.entities[1].archetype=="avatar" and b.world.entities[10].archetype=="avatar")
assert(RW_GetBackIdentity(b.world.entities[1])==RW_GetBackIdentity(b.world.entities[10]))
-- Aliased instances match older source motion, including all duplicate-ID updates.
local w=copy(b.world);local first=copy(w.entities[1]);local second=copy(w.entities[10]);second.x=4;second.y=3;w.entities[10]=second
local move={consumes_turn=true,changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Up"},to={x=3,y=2,direction="Right"}},{kind="move",entity_id=10,from={x=4,y=3,direction="Up"},to={x=5,y=3,direction="Down"}}}}
local historical={world=w,history={}};local moved,r=RW_Commit(historical,move);assert(r.accepted)
local current=copy(moved.world);current.entities[1].x=8;current.entities[10].x=9
local shared=assert(RW_PlanBackFramePlayback(current,{{entity_id=1,before_world=w,record=RW_GetTurnRecord(moved,1)},{entity_id=10,before_world=w,record=RW_GetTurnRecord(moved,1)}}))
local after=assert(RW_PreviewPlan(current,shared));assert(after.entities[1].x==2 and after.entities[10].x==2 and after.entities[10].y==2)
assert(shared.tele_suppressed[1] and shared.tele_suppressed[10])
-- Ordinary births and EMPTY products have no physical removal partner: BACK
-- removes them without recursively running HAS.
local birth=assert(RW_PlanCreate(s.world,{{kind="object",class="object",archetype="rock",x=5,y=5,direction="Down"}}));local born,r=RW_Commit(s,birth);assert(r.accepted)
local vanish=assert(RW_PlanBackFramePlayback(born.world,{{entity_id=10,before_world=s.world,record=RW_GetTurnRecord(born,1)}}))
assert(#vanish.changes==1 and vanish.changes[1].kind=="delete" and not vanish.id_allocation)
local gone,r=RW_Commit(born,vanish);assert(r.accepted and not gone.world.entities[10] and RW_Undo(gone).world==born.world)
-- Allocated conversions from an aliased source get fresh native identities.
local fresh=conversion(b.world,"avatar",{"rock","flag"});local converted=assert(RW_PreviewPlan(b.world,fresh))
for _,op in ipairs(fresh.changes) do if op.kind=="create" then assert(op.to.back_identity==nil and RW_GetBackIdentity(op.to)==op.entity_id) end end
print("PASS: BACK branch source restoration, source-vs-unit paradox guards, shared logical/unique physical IDs, older duplicate-ID motion, birth deletion, fresh conversion aliases and Undo")

-- Repeated primary conversions create every matching removal partner for every
-- matching create row: two conversions produce four restored instances.
s=fixture();local one=conversion(s.world,"avatar",{"rock"});local middle=assert(RW_PreviewPlan(s.world,one));local two=conversion(middle,"rock",{"flag"})
p=assert(RW_PlanStages(s.world,{{name="one",plan=one},{name="two",plan=two}}));local repeated,r=RW_Commit(s,p);assert(r.accepted)
local rec=assert(RW_GetTurnRecord(repeated,1));local current=copy(repeated.world);current.entities[1].x=8;current.entities[1].y=7
local multiplied=assert(RW_PlanBackFramePlayback(current,{{entity_id=1,before_world=s.world,record=rec}}))
local out=assert(RW_PreviewPlan(current,multiplied));local count=0;local names={}
for _,u in pairs(out.entities) do count=count+1;names[u.archetype]=(names[u.archetype] or 0)+1;assert(u.x==8 and u.y==7 and RW_GetBackIdentity(u)==1) end
assert(count==4 and names.avatar==2 and names.rock==2 and out.next_entity_id==13)
assert(multiplied.id_allocation.from==10 and multiplied.id_allocation.to==13 and next(multiplied.tele_suppressed)==nil)
local committed,r=RW_Commit({world=current,history={}},multiplied);assert(r.accepted)
assert(RW_Undo(committed).world==current)
-- The resulting journal can itself be translated; all three extra instances
-- retain create/back source identity instead of masquerading as ordinary births.
local rows=assert(RW_BackHistoryRows(current,RW_GetTurnRecord(committed,1)));local creates=0
for _,row in ipairs(rows) do if row.kind=="create" then creates=creates+1;assert(row.identity==1 and row.base==1) end end
assert(creates==4)
local bad=copy(multiplied);bad.changes[#bad.changes].back_source_identity=99
local same,r=RW_Commit({world=current,history={}},bad);assert(not r.accepted)
print("PASS: repeated conversion BACK create/remove cartesian multiplicity, atomic fresh allocation, shared identity journals and allocator Undo")

local file=assert(io.open("C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua","rb"));local original=file:read("*a"):gsub("\r\n","\n");file:close()
local branch=assert(original:match('elseif %(style == "create"%) and %(line%[3%] == unit%.values%[ID%]%) then(.-)\n\t\t\t\t\tend\n\t\t\t\tend\n\t\t\tend\n\t\tend'))
local env=setmetatable({},{__index=_G})
for name in ("ID DIR XPOS YPOS ONLINE UNITNAME UNITTYPE U_LEVELFILE U_LEVELNAME MAPLEVEL VISUALLEVEL VISUALSTYLE COMPLETED COLOUR CLEARCOLOUR UNITSIGNTEXT"):gmatch("%S+") do env[name]=name end
local native=assert(load('return function(unit,currentundo,unitid,paradox,line) if true then '..branch..' end',"@installed_BACK_branch_cartesian","t",env))()
for _,name in ipairs({"MF_setcolourfromstring","addunitmap","dynamic","addundo","MF_alert","MF_specialremove"}) do env[name]=function() end end
local cases=0
for _,scenario in ipairs({"primary","branch","repeat","birth"}) do for _,at in ipairs({{7,6},{3,2}}) do for guard=0,2 do
 local initial=fixture();local first=conversion(initial.world,"avatar",{"rock","flag"})
 local base,record,id,golden
 local function removal(name) return {"remove",name,2,2,1,1,1,"parent","child",2,1,3,true,"1,2","1,3",7,3} end
 if scenario=="repeat" then
  local a=conversion(initial.world,"avatar",{"rock"});local mid=assert(RW_PreviewPlan(initial.world,a));local b=conversion(mid,"rock",{"flag"})
  local turn=assert(RW_PlanStages(initial.world,{{name="a",plan=a},{name="b",plan=b}}));local n,r=RW_Commit(initial,turn);assert(r.accepted)
  base=copy(n.world);record=RW_GetTurnRecord(n,1);id=1
  golden={removal("rock"),{"create","flag",1,1,"convert"},removal("avatar"),{"create","rock",1,1,"convert"}}
 elseif scenario=="birth" then
  local p=assert(RW_PlanCreate(initial.world,{{kind="object",class="object",archetype="rock",x=5,y=5,direction="Down"}}));local n,r=RW_Commit(initial,p);assert(r.accepted)
  base=copy(n.world);record=RW_GetTurnRecord(n,1);id=10;golden={{"create","rock",10,-1,"create"}}
 else
  local n,r=RW_Commit(initial,first);assert(r.accepted);base=copy(n.world);record=RW_GetTurnRecord(n,1);id=scenario=="branch" and 10 or 1
  golden={removal("avatar"),{"create","flag",10,1,"convert"},{"create","rock",1,1,"convert"}}
 end
 base.entities[id].x,base.entities[id].y=at[1],at[2]
 golden.wordunits={};golden.wordrelatedunits={}
 local births,objects,retired={}, {},false
 env.unitreference={avatar="avatar",rock="rock",flag="flag"}
 env.MF_emptycreate=function(name,x,y)
  local handle=20+#births;local u={className=name,values={XPOS=x,YPOS=y},strings={UNITNAME=name,UNITTYPE="object"},flags={}}
  births[#births+1]=u;objects[handle]=u;return handle
 end
 env.mmf={newObject=function(handle) return assert(objects[handle]) end}
 env.addunit=function(handle) local u=objects[handle];u.originalname=u.strings.UNITNAME;u.back_init=0;u.broken=0;u.holder=0;u.followed=-1 end
 env.delunit=function() retired=true end
 local unit={values={XPOS=at[1],YPOS=at[2],DIR=2,ID=id},strings={UNITNAME=base.entities[id].archetype},flags={}}
 local paradox={};if guard==1 then paradox[1]=false elseif guard==2 then paradox[id]=false end
 for _,row in ipairs(golden) do if row[1]=="create" and row[3]==id then native(unit,golden,11,paradox,row) end end
 local p,e=RW_PlanBackFramePlayback(base,{{entity_id=id,before_world=initial.world,record=record}},paradox);assert(p,e)
 if retired and #births==0 then assert(#p.changes==1 and p.changes[1].kind=="delete")
 elseif retired then
  assert(#p.changes==#births)
  for index,u in ipairs(births) do local product=p.changes[index].to
   assert(product.archetype==u.strings.UNITNAME and product.x==u.values.XPOS and product.y==u.values.YPOS and product.direction=="Up")
   assert(RW_GetBackIdentity(product)==u.values.ID and product.back_init==u.back_init and product.followed==u.followed)
   assert(RW_GetOriginalName(product)==u.originalname and product.level_link.target==u.strings.U_LEVELFILE)
  end
 else assert(#p.changes==0) end
 local after,r=RW_Commit({world=base,history={}},p);assert(r.accepted,r.reason);assert(RW_Undo(after).world==base)
 cases=cases+1
end end end
assert(cases==24);print("PASS: unchanged installed BACK branch/repeated/birth create-remove oracle (24 cases), ordered multiplicity, source guards, shared identities and atomic Undo")

local s=fixture();local p=conversion(s.world,"avatar",{"rock","flag"});p.back_frame={from=1,retain=true}
local session,r=RW_Commit(s,p);assert(r.accepted)
session=RW_Commit(session,{consumes_turn=true,changes={{kind="back_init",entity_id=10,from=3,to=2}},back_frame={from=2,retain=true}})
local playback,e=RW_PlanBackHistoryMotion(session,{consumes_turn=true,changes={}},{[10]=true});assert(playback,e)
assert(playback.back_retain and playback.changes[1].kind=="back_restore" and playback.changes[1].to.back_identity==1)
playback.back_frame={from=3,retain=true};local restored,r=RW_Commit(session,playback);assert(r.accepted and restored.world.entities[10].archetype=="avatar")
assert(RW_Undo(restored).world==session.world)
-- Pre-provenance journals cannot distinguish allocated conversions from births.
local ordinary=assert(RW_PlanCreate(s.world,{{kind="object",class="object",archetype="rock",x=5,y=5,direction="Down"}}));local born=RW_Commit(s,ordinary)
local legacy=RW_GetTurnRecord(born,1);legacy.phases[1].back_format=nil
local rows,e=RW_BackHistoryRows(s.world,legacy);assert(not rows and e=="back_creation_provenance_unavailable")
print("PASS: branch BACK native-clock selection/Undo and explicit legacy creation provenance rejection")

local repeated_session=fixture();local a=conversion(repeated_session.world,"avatar",{"rock"});local mid=assert(RW_PreviewPlan(repeated_session.world,a));local b=conversion(mid,"rock",{"flag"})
local transaction=assert(RW_PlanStages(repeated_session.world,{{name="a",plan=a},{name="b",plan=b}}));local repeated=RW_Commit(repeated_session,transaction)
local frame=RW_GetTurnRecord(repeated,1)
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",repeated.world))},"root"));local active=RW_GetActiveLevel(tree)
local playback=assert(RW_PlanBackFramePlayback(active.world,{{entity_id=1,before_world=repeated_session.world,record=frame}}))
local committed,r=RW_Commit(active,playback);assert(r.accepted)
local update=assert(RW_UpdateActiveLevel(tree,committed));local next_tree,r=RW_CommitLevelTree(tree,{before=tree,after=update});assert(r.accepted)
assert(RW_GetActiveLevel(next_tree).world.next_entity_id==13 and RW_GetActiveLevel(next_tree).world.entities[12].back_identity==1)
local undone=RW_UndoLevelTree(next_tree);assert(RW_GetActiveLevel(undone)==active and active.world.next_entity_id==10)
local invalid=copy(playback);invalid.changes[1].source.id=nil
local same,r=RW_Commit(active,invalid);assert(same==active and not r.accepted)
for _,value in ipairs({0,-1,"1",false}) do
 local invalid=copy(playback);invalid.changes[#invalid.changes].to.back_identity=value
 local same,r=RW_Commit(active,invalid);assert(same==active and not r.accepted)
end
print("PASS: full-tree BACK alias/allocation restoration and malformed source/alias rejection")
