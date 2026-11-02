-- Execute installed EMPTY add_moving_units and state-0 direction dispatch.
dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('function add_moving_units(',1,true));local b=source:find('\nfunction ',a+1,true)
local collection=source:sub(a,b and b-1 or #source)
local first=assert(source:find('if (data.unitid == 2) and (((data.reason == "move")',1,true))
local last=assert(source:find('elseif (state == 3) then',first,true))
local dispatch=source:sub(first,last-1)
local env=setmetatable({roomsizex=18},{__index=_G})
local sleep,still,direction,state
env.hasfeature=function() return sleep and true or nil end
env.cantmove=function() return still end
env.emptydir=function() return direction end
env.fixedrandom=function() state=state*48271%2147483647;return state%4 end
assert(load(collection,'@installed_EMPTY_collect','t',env))()
local state0=assert(load('return function(data) local dir=data.dir local name="empty" local x,y=data.xpos,data.ypos local skipthis=false '..dispatch..' return dir,skipthis end','@installed_EMPTY_state0','t',env))()
local names={'Right','Up','Left','Down','None'}
local cases=0
for moves=0,3 do for autos=0,2 do for chills=0,2 do for dir=0,4 do
for mask=0,3 do
 sleep=mask%2==1;still=math.floor(mask/2)==1;direction=dir;state=17
 local list,seen={dir=4},{}
 for _,spec in ipairs({{'move',moves},{'auto',autos},{'chill',chills}}) do
  local data,empties={},{}
  for i=1,spec[2] do data[i]=2;empties[i]={[8+8*18]=true} end
  list,seen=env.add_moving_units(spec[1],data,list,seen,empties)
 end
 for _,node in ipairs(list) do
  assert(node.unitid==2 and node.xpos==8 and node.ypos==8)
  for step=1,node.moves do state0(node) end
 end
 local w={width=18,height=18,entities={[1]={id=1,kind='object',class='object',archetype='rock',x=9,y=8,direction='None',behaviors={push=true}}},random_state=17,
  empty_cells={['8:8']={x=8,y=8,behaviors={move=moves>0,auto=autos>0,chill=chills>0,sleep=sleep,still=still},trait_counts={move=moves,auto=autos,chill=chills}}}}
 local plan=RW_ResolveAutomatic(w,{['8:8']=names[dir+1]})
 assert((plan.random_state and plan.random_state.to or 17)==state,'EMPTY dispatch RNG:'..moves..':'..autos..':'..chills..':'..dir..':'..mask)
 for _,change in ipairs(plan.changes) do assert(change.entity_id==1) end
 if dir==0 and chills==0 and not sleep and not still then
  local max=0;for _,node in ipairs(list) do max=math.max(max,node.moves) end
  local x=9;for _,change in ipairs(plan.changes) do if change.kind=='move' then x=change.to.x end end
  assert(x==9+max,'EMPTY independent original source positions')
 end
 assert(w.entities[1].x==9 and not w.trait_counts and w.random_state==17)
 cases=cases+1
end end end end end
print('PASS: installed EMPTY collection slot merging/origins, MOVE/AUTO/CHILL state-0 RNG and SLEEP/STILL ('..cases..' cases)')
