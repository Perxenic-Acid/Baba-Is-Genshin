local source=assert(io.open("C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua","rb")):read("*a"):gsub("\r\n","\n")
local status=assert(source:match('(if %(featureindex%["back"%] ~= nil%) then.-)\n\t\t\tend\n\t\tend'))
local index=assert(source:match('(local undooffset = #undobuffer %- unit.back_init.-)\n\t\t\t\tparticles'))
local env=setmetatable({ID="id",DEAD="dead",getname=function() return "avatar" end},{__index=_G})
local statusfn=assert(load('return function(unit,name) '..status..' end',"@installed_BACK_status","t",env))()
-- Preserve original eligibility branch and index expression; no particle/host code.
local indexfn=assert(load('return function(unit) '..index..' return undotargetid end end',"@installed_BACK_index","t",env))()
local cases=0
for count=0,12 do for initial=0,15 do for active=0,2 do
 local s=RW_CreateSession();local id=1;s.world.entities[id].back_init=initial
 env.undobuffer={};for n=1,count do env.undobuffer[n]={} end
 env.featureindex=active==0 and {} or {back={}}
 env.hasfeature=function() if active==2 then return {} end end
 local rows={};env.addundo=function(row) rows[#rows+1]=row end
 local unit={back_init=initial,values={id=id},flags={dead=false}}
 statusfn(unit,"avatar")
 local p,e=RW_PlanBackStatus(s.world,active==2 and {[id]=true} or {},count);assert(p,e)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 assert(n.world.entities[id].back_init==unit.back_init,"native BACK status mismatch")
 assert(#p.changes==#rows);assert(s.world.entities[id].back_init==initial)
 if #rows>0 then assert(rows[1][4]==initial) end
 assert(RW_Undo(n).world==s.world)
 for _,dead in ipairs({false,true}) do
  unit.flags.dead=dead
  local native=indexfn(unit);local actual=RW_BackFrameIndex(unit.back_init,count,dead)
  assert(actual==native,"native BACK index mismatch")
 end
 cases=cases+1
end end end
local s=RW_CreateSession();local p=assert(RW_PlanBackStatus(s.world,{[1]=true},3))
assert(s.world.entities[1].back_init==nil and p.changes[1].from==nil and p.changes[1].to==4)
local n,r=RW_Commit(s,p);assert(r.accepted and n.world.entities[1].back_init==4)
local off=assert(RW_PlanBackStatus(n.world,{},4));local cleared,rr=RW_Commit(n,off);assert(rr.accepted and cleared.world.entities[1].back_init==0)
local re=assert(RW_PlanBackStatus(cleared.world,{[1]=true},7));assert(re.changes[1].to==8)
local stale=assert(RW_PlanBackStatus(s.world,{[1]=true},3));stale.changes[1].from=0
local rejected,why=RW_Commit(s,stale);assert(rejected==s and not why.accepted and why.reason=="stale_back_init")
for _,bad in ipairs({-1,0.5,"x",false}) do
 local b={consumes_turn=true,changes={{kind="back_init",entity_id=1,to=bad}}}
 local same,result=RW_Commit(s,b);assert(same==s and not result.accepted)
end
assert(not RW_PlanBackStatus(s.world,{[999]=true},1));assert(not RW_PlanBackStatus(s.world,{[1]=false},1))
assert(not RW_BackFrameIndex(-1,3));assert(RW_BackFrameIndex(4,3)==-1)
-- Clock-only rows neither move nor suppress TELE in motion playback.
local mp=assert(RW_PlanBackMotion(n.world,{{entity_id=1,before=s.world.entities[1],record=assert(RW_GetTurnRecord(n,1))}}))
assert(#mp.changes==0 and next(mp.tele_suppressed)==nil)
s.world.too_complex=true;assert(not RW_PlanBackStatus(s.world,{},1))
assert(cases==624);print("PASS: BACK status/index installed source oracle (624 cases), clock-only Commit/Undo, stale validation, reactivation and absent negative frames")
