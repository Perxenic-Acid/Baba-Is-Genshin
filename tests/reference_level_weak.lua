-- Installed LEVEL WEAK and floating_level, with host effects captured.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({XPOS=1,YPOS=2,FLOAT=3,UNITNAME=1,UNITTYPE=2},{__index=_G})
local s=read('tools.lua');local a=assert(s:find('function floating_level(',1,true));local b=assert(s:find('function emptydir(',a,true))
assert(load(s:sub(a,b-1),'@installed_weak_floating_level','t',env))()
s=read('blocks.lua');a=assert(s:find('elseif (action == "weak") then',1,true));b=assert(s:find('elseif (action == "hot") then',a,true))
local native=assert(load('return function(lsafe) local action="weak"; if false then '..s:sub(a,b-1)..' end; suffix=true end','@installed_level_weak','t',env))()
local cases=0
for mask=0,15 do for floats=0,15 do for _,mapfloat in ipairs({false,true}) do for _,safe in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.entities={};w.level_behaviors={safe=safe};env.units={};local objects={}
 for index=0,3 do if math.floor(mask/2^index)%2==1 then
  local id=index+10;local floating=math.floor(floats/2^index)%2==1
  local text=index%2==0
  w.entities[id]={id=id,kind='object',class=text and 'text' or 'object',archetype='rock',text=text and {name='ROCK'} or nil,
   x=index+1,y=1,direction='Left',broken=index==3 and 1 or nil,behaviors={float=floating,safe=true}}
  local o={fixed=id,values={index+1,1,floating and 1 or 0},strings={'rock',text and 'text' or 'object'}}
  objects[id]=o;env.units[#env.units+1]=o
 end end
 env.mmf={newObject=function(id)return objects[id] end}
 env.findfeature=function()return mapfloat and {{{'level','is','float'},{}}} or nil end
 env.testcond=function()return true end
 local rows=mapfloat and {{op='level_trait',trait='float',when={op='always'}}} or {}
 w.rule_sources={{when={op='always'},effects={},scoped_conditions=rows}}
 local destroyed=false;env.destroylevel=function()destroyed=true end;env.suffix=false
 native(safe);assert(env.suffix,'native WEAK unexpectedly returns before suffix')
 local actual,why=RW_LevelWeakDestroys(w,{});assert(actual~=nil,why)
 assert(actual==destroyed,'LEVEL WEAK mismatch '..mask..':'..floats..':'..tostring(mapfloat)..':'..tostring(safe)..':'..tostring(actual)..'/'..tostring(destroyed))
 cases=cases+1
end end end end
print('PASS: installed LEVEL WEAK/floating_level, real/Text/SAFE/BROKEN witnesses, map SAFE/FLOAT and nonreturning suffix ('..cases..' cases)')

-- Late query failures retain only recognized terminal prefixes; ordinary errors
-- reject the complete private motion plan, including its preceding TELE draw.
do
 local w=RW_CreateSession().world;w.width,w.height=2,2;w.entities={}
 w.entities[10]={id=10,kind='object',class='object',archetype='rock',x=1,y=1,direction='Right',behaviors={}}
 local rows={{op='level_trait',trait='tele'},{op='level_trait',trait='weak'}}
 for _,reason in ipairs({'word_rule_limit','word_rule_cycle','rule_complexity_limit','invalid_weak_query'}) do
  local p,why=RW_PlanOrderedLevelMotion(w,{'tele','weak'},{},rows,{
   active=function()return true end,reverse=RW_LevelMotionReverse,outcome=RW_ResolveLevelPropertyOutcome,
   resolve=RW_ResolveLevelMotion,layers=RW_LevelTeleLayers,weak=function()return nil,reason end})
  if reason=='invalid_weak_query' then assert(not p and why==reason)
  else assert(p and p.random_state and p.random_state.to==182605794 and not p.level_pending_destroy)
   assert(reason=='rule_complexity_limit' and p.too_complex or reason~='rule_complexity_limit' and p.infinite_loop)
  end
 end
 assert(w.random_state==nil and w.entities[10].x==1)
end
print('PASS: LEVEL WEAK late query terminal prefix and ordinary error atomicity')
