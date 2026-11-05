local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local movement,tools=read('movement.lua'),read('tools.lua')
local a=assert(movement:find('local shifts = findallfeature(nil,"is","shift",true)',1,true))
local b=assert(movement:find('local levelshift = findfeature("level","is","shift")',a,true))
local collector=movement:sub(a,b-1)
local function install(env,first,last)
 local x=assert(tools:find('function '..first..'(',1,true));local y=assert(tools:find('function '..last..'(',x+1,true))
 assert(load(tools:sub(x,y-1),'@installed_shift_lock_'..first,'t',env))()
end
local names={'Right','Up','Left','Down'};local locks={'lockedright','lockedup','lockedleft','lockeddown'};local cases=0
for dir=0,3 do for lock=0,4 do for reverse=0,3 do for still=0,1 do for sleeps=0,3 do for floats=0,3 do for hold=0,1 do
 local riderfloat=floats%2==1;local beltfloat=floats>=2
 local caps={reverse=reverse%2==1,still=still==1,sleep=sleeps%2==1,float=riderfloat}
 if lock>0 then caps[locks[lock]]=true end
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=13
 w.level_behaviors={hold=hold==1,float=false};w.trait_counts={[11]={reverse=reverse}}
 w.entities[11]={id=11,kind='object',class='object',archetype='avatar',x=5,y=5,direction='Left',behaviors=caps}
 w.entities[12]={id=12,kind='object',class='object',archetype='rock',x=5,y=5,direction=names[dir+1],behaviors={shift=true,float=beltfloat,sleep=sleeps>=2}}
 local units={
  [11]={values={5,5,2,riderfloat and 1 or 0},strings={'avatar'}},
  [12]={values={5,5,dir,beltfloat and 1 or 0},strings={'rock'}}}
 local env=setmetatable({XPOS=1,YPOS=2,DIR=3,FLOAT=4,UNITNAME=1,roomsizex=12,unitmap={[65]={11,12}},moving_units={},been_seen={},featureindex={reverse={}}},{__index=_G})
 env.mmf={newObject=function(id)return units[id]end};env.getname=function(u)return u.strings[1]end
 env.findallfeature=function()return {12}end;env.findfeature=function()return nil end
 env.floating=function()return riderfloat==beltfloat end
 env.hasfeature=function(name,_,trait,id)
  if name=='level' then return trait=='hold' and hold==1 and true or nil end
  return id==11 and caps[trait] and true or nil
 end
 env.hasfeature_count=function(_,_,trait,id)return trait=='reverse' and id==11 and reverse or 0 end
 install(env,'cantmove','findnoun');install(env,'reversedir','reversecheck');install(env,'reversecheck','simplecheck')
 install(env,'floating_level','emptydir');install(env,'isstill_or_locked','getmat')
 assert(load(collector,'@installed_shift_lock_collection','t',env))()
 local plan=assert(RW_ResolveShift(w))
 assert(#plan.shift_tasks==#env.moving_units,'ordinary SHIFT collector lock/REVERSE mismatch')
 for i,task in ipairs(env.moving_units) do local actual=plan.shift_tasks[i]
  assert(actual.entity_id==task.unitid and actual.direction==names[task.dir+1] and actual.count==task.moves)
 end
 local committed,r=RW_Commit(s,plan)
 if #plan.changes>0 then assert(r.accepted,r.reason) end
 if r.accepted then assert(RW_Undo(committed).world==w) end
 cases=cases+1
end end end end end end end
assert(cases==5120)
print('PASS: installed ordinary SHIFT cantmove/REVERSE parity, all lock directions, STILL/SLEEP, FLOAT/HOLD and Undo ('..cases..' cases)')
