-- Installed LEVEL SINK and floating_level with native selection/deletion order.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({XPOS=1,YPOS=2,FLOAT=3,UNITNAME=1,UNITTYPE=2,SHAKE=1,generaldata={values={}},
 checkeffecthistory=function()return 1,0 end,setsoundname=function()end,MF_particles=function()end,getcolour=function()return 0,0 end},{__index=_G})
local source=read('tools.lua');local a=assert(source:find('function floating_level(',1,true));local b=assert(source:find('function emptydir(',a,true))
assert(load(source:sub(a,b-1),'@installed_sink_floating','t',env))()
source=read('blocks.lua');a=assert(source:find('elseif (action == "sink") then',1,true));b=assert(source:find('elseif (action == "boom") then',a,true))
local native=assert(load('return function(lsafe)local action="sink"; if false then '..source:sub(a,b-1)..' end; suffix=true end','@installed_level_sink','t',env))()
local cases=0
for mask=0,15 do for floats=0,15 do for safes=0,3 do for _,mapsafe in ipairs({false,true}) do for _,mapfloat in ipairs({false,true}) do for order=1,2 do
 local w=RW_CreateSession().world;w.entities={};w.unit_order=order==1 and {10,11,12,13} or {13,12,11,10};w.rule_sources={}
 local objects,safe={},{};env.units={};env.deleted={}
 for index=0,3 do if math.floor(mask/2^index)%2==1 then
  local id=index+10;local floating=math.floor(floats/2^index)%2==1;local grant_safe=math.floor(safes/2^(index%2))%2==1
  local text=index%2==0;local broken=index==3
  w.entities[id]={id=id,kind='object',class=text and 'text' or 'object',archetype='rock',text=text and {name='ROCK'} or nil,
   x=index+1,y=1,direction='Right',broken=broken and 1 or nil,behaviors={float=floating}}
  objects[id]={fixed=id,values={index+1,1,floating and 1 or 0},strings={'rock',text and 'text' or 'object'}}
  safe[id]=grant_safe and not broken
  if grant_safe then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait='safe',target={kind='id',value=id}}}} end
 end end
 for _,id in ipairs(w.unit_order) do if objects[id] then env.units[#env.units+1]=objects[id] end end
 if mapfloat then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='float',when={op='always'}}}} end
 env.findfeature=function()return mapfloat and {{{'level','is','float'},{}}} or nil end
 env.testcond=function()return true end;env.issafe=function(id)return safe[id] end
 env.mmf={newObject=function(id)return objects[id] end}
 local destroyed,deleted=false,{};env.destroylevel=function()destroyed=true end;env.delete=function(id)deleted[#deleted+1]=id end;env.suffix=false
 native(mapsafe)
 local actual,why=RW_ResolveScopedSinkTargets(w,{},mapsafe);assert(actual,why)
 assert((actual.level_destroy==true)==destroyed and env.suffix==not destroyed and #actual.ids==#deleted,'LEVEL SINK layer/SAFE/early return mismatch')
 for i,id in ipairs(deleted) do assert(actual.ids[i]==id,'LEVEL SINK unit-list selection order mismatch') end
 cases=cases+1
end end end end end end
print('PASS: installed LEVEL SINK/floating_level, real/Text/BROKEN witnesses, independent SAFE/FLOAT, return and unit order ('..cases..' cases)')

-- Unsafe map retirement precedes any target SAFE query. A protected map must
-- propagate that query's diagnostics instead of treating the victim as absent.
do
 local w=RW_CreateSession().world;w.entities={[10]={id=10,kind='object',class='object',archetype='rock',x=1,y=1,direction='Right',behaviors={}}}
 local marker={op='spatial',clauses={},sink_safe_marker=true}
 local rules={{when=marker,effects={{op='grant_trait',trait='safe',target={kind='id',value=10}}}}}
 local original=RW_TestEntityCondition;local calls=0
 RW_TestEntityCondition=function(world,c,e)if c.sink_safe_marker then calls=calls+1;return nil,'word_rule_limit' end;return original(world,c,e) end
 local ok,actual,why=pcall(RW_ResolveScopedSinkTargets,w,rules,false)
 RW_TestEntityCondition=original;assert(ok,actual);assert(actual.level_destroy and calls==0)
 RW_TestEntityCondition=function(world,c,e)if c.sink_safe_marker then calls=calls+1;return nil,'word_rule_limit' end;return original(world,c,e) end
 local ok,actual,why=pcall(RW_ResolveScopedSinkTargets,w,rules,true)
 RW_TestEntityCondition=original;assert(ok,actual);assert(not actual and why=='word_rule_limit' and calls==1)
end
print('PASS: SINK map retirement short-circuits target SAFE queries; protected maps retain query failures')
