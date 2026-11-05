-- Installed MELT, floating_level and EMPTY findallfeature placeholder path.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({XPOS=1,YPOS=2,FLOAT=3,roomsizex=4,roomsizey=3,featureindex={}},{__index=_G})
local source=read('tools.lua');local a=assert(source:find('function floating_level(',1,true));local b=assert(source:find('function emptydir(',a,true))
assert(load(source:sub(a,b-1),'@installed_melt_floating','t',env))()
source=read('features.lua');a=assert(source:find('function findallfeature(',1,true));b=assert(source:find('function getunitswitheffect(',a,true))
assert(load(source:sub(a,b-1),'@installed_melt_empty_placeholder','t',env))()
source=read('blocks.lua');a=assert(source:find('elseif (action == "melt") then',1,true));b=assert(source:find('elseif (action == "open") then',a,true))
local native=assert(load('return function(lsafe) local action="melt"; if false then '..source:sub(a,b-1)..' end; suffix=true end','@installed_level_melt','t',env))()
local cases=0
for mask=0,3 do for floats=0,3 do for hots=0,3 do for _,mapfloat in ipairs({false,true}) do
for _,safe in ipairs({false,true}) do for _,selfhot in ipairs({false,true}) do for emptyhot=0,2 do for _,emptyfloat in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.width,w.height=2,1;w.entities={};w.level_behaviors={safe=safe}
 w.empty_hot_declared=emptyhot>0;w.empty_float_declared=emptyfloat
 local effects,scoped={},{};local objects,hotrows={},{};env.unitmap={}
 for index=0,1 do if math.floor(mask/2^index)%2==1 then
  local id=index+10;local floating=math.floor(floats/2^index)%2==1;local hot=math.floor(hots/2^index)%2==1
  local e={id=id,kind='object',class=index==0 and 'text' or 'object',archetype='rock',x=index+1,y=1,direction='Right',behaviors={float=floating,safe=true}}
  if e.class=='text' then e.text={name='ROCK'} end
  w.entities[id]=e;objects[id]={values={e.x,e.y,floating and 1 or 0}};env.unitmap[e.x+4]={id}
  if hot then effects[#effects+1]={op='grant_trait',trait='hot',target={kind='id',value=id}};hotrows[#hotrows+1]={tostring(id),{}} end
 end end
 if mapfloat then scoped[#scoped+1]={op='level_trait',trait='float',when={op='always'}} end
 if selfhot then scoped[#scoped+1]={op='level_trait',trait='hot',when={op='always'}};hotrows[#hotrows+1]={'level',{}} end
 local rules={{when={op='always'},effects=effects,scoped_conditions=scoped}}
 env.mmf={newObject=function(id)return objects[id] end}
 env.findfeature=function(name,_,property)
  if property=='float' then
   if name=='level' then return mapfloat and {{'level',{}}} or nil end
   if name=='empty' then return emptyfloat and {{'empty',{}}} or nil end
  elseif property=='hot' then
   if name=='empty' then return emptyhot>0 and {{'empty',emptyhot==2 and {{'on',{'flag'}}} or {}}} or nil end
   return #hotrows>0 and hotrows or nil
  end
 end
 env.findall=function(row)return objects[tonumber(row[1])] and {tonumber(row[1])} or {} end
 env.testcond=function(c,id)return #c==0 or id~=2 end
 local destroyed=false;env.destroylevel=function()destroyed=true end;env.suffix=false
 native(safe)
 local actual,why,stop=RW_LevelMeltDestroys(w,rules);assert(actual~=nil,why)
 assert(actual==destroyed and stop==not env.suffix,'LEVEL MELT source/SAFE/FLOAT/EMPTY return mismatch')
 cases=cases+1
end end end end end end end end
print('PASS: installed LEVEL MELT/floating_level/findallfeature, real/Text/self/EMPTY HOT, SAFE/FLOAT and suffix return ('..cases..' cases)')

-- Projection must retain conditional EMPTY declaration placeholders even when
-- no vacancy qualifies (or exists), rather than inferring presence from cells.
do
 local w=RW_CreateSession().world;w.width,w.height=1,1
 w.entities={[10]={id=10,kind='object',class='object',archetype='rock',x=1,y=1,direction='Right'}}
 local condition={op='spatial',clauses={{relation='on',negated=false,
  parameters={{tag='noun',type={tag='object',name='flag'}}}}}}
 local effects={{op='grant_trait',trait='hot',target={kind='empty',value='empty'},when=condition}}
 local evaluated=assert(RW_EvaluateRules(w,{{when=condition,effects=effects}}))
 local p=assert(RW_ProjectWorld(w,evaluated,{'melt'}))
 assert(p.empty_hot_declared and not next(p.empty_cells))
 local destroys,why,stop=RW_LevelMeltDestroys(p,{})
 assert(destroys and not why and stop,'full board lost conditional EMPTY HOT placeholder')
end

-- One HOT declaration must query concrete units in native unit-list order,
-- including after structural replacement/reinsertion changed identity order.
do
 local tools=read('tools.lua');local first=assert(tools:find('function findall(',1,true));local last=assert(tools:find('\nfunction ',first+1,true))
 assert(load(tools:sub(first,last-1),'@installed_melt_findall_order','t',env))()
 local session=RW_CreateSession();local w=session.world
 w.entities={};w.unit_order={11,10};w.level_behaviors={};w.next_entity_id=12
 local objects={};for _,id in ipairs({10,11}) do
  w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=id-9,y=1,direction='Right',behaviors={}}
  objects[id]={values={id-9,1,0},strings={'rock','object'},broken=0}
 end
 local trace={};env.unitlists={rock={11,10}};env.mmf={newObject=function(id)return objects[id] end}
 env.getname=function()return 'rock' end
 env.testcond=function(_,id)trace[#trace+1]=id;return true end
 env.findall({'rock',{{'oracle',{}}}})
 assert(#trace==2 and trace[1]==11 and trace[2]==10)
 local original=RW_TestEntityCondition;local actual={}
 RW_TestEntityCondition=function(world,c,e)
  if c.oracle_marker then actual[#actual+1]=e.id;return true end
  return original(world,c,e)
 end
 local rules={{when={op='spatial',clauses={},oracle_marker=true},effects={{op='grant_trait',trait='hot',target={kind='archetype',value='rock'}}}}}
 local ok,why=pcall(RW_LevelMeltDestroys,w,rules);RW_TestEntityCondition=original;assert(ok,why)
 assert(#actual==#trace and actual[1]==trace[1] and actual[2]==trace[2],'MELT HOT condition queries lost native unit-list order')
 for _,order in ipairs({{11,10},{10,11}}) do
  w.unit_order=order;env.unitlists.rock=order
  env.testcond=function(_,id)error(id==11 and 'invalid_hot_condition' or 'word_rule_limit',0) end
  local native_ok,native_reason=pcall(env.findall,{'rock',{{'oracle',{}}}})
  assert(not native_ok)
  RW_TestEntityCondition=function(world,c,e)
   if c.oracle_marker then return nil,e.id==11 and 'invalid_hot_condition' or 'word_rule_limit' end
   return original(world,c,e)
  end
  local ok,p,why=pcall(RW_PlanOrderedLevelMotion,w,{'tele','melt'},rules,
   {{op='level_trait',trait='tele'},{op='level_trait',trait='melt'}},
   {active=function()return true end,resolve=RW_ResolveLevelMotion,layers=RW_LevelTeleLayers,
    reverse=RW_LevelMotionReverse,melt=RW_LevelMeltDestroys})
  RW_TestEntityCondition=original;assert(ok,p)
  if native_reason=='invalid_hot_condition' then assert(not p and why==native_reason)
  else
   assert(native_reason=='word_rule_limit' and p.infinite_loop and p.random_state)
   local next_session,result=RW_Commit(session,p);assert(result.accepted,result.reason)
   assert(next_session.world.infinite_loop and next_session.world.random_state==p.random_state.to)
   assert(RW_Undo(next_session).world==w)
  end
 end
 assert(not w.random_state and w.entities[10].x==1 and w.entities[11].x==2)
end
print('PASS: installed findall MELT HOT condition dispatch follows replacement-aware unit_order')
