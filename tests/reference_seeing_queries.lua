-- Compare actual installed seeing/simplecheck property query order, not only truth.
local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local s=read('conditions.lua');local a=assert(s:find('seeing = function',1,true));local b=assert(s:find('without = function',a,true))
local env=setmetatable({ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}},roomsizex=9,DIR=1,XPOS=2,YPOS=3},{__index=_G})
local native=assert(load('return {'..s:sub(a,b-1)..'}','@installed_seeing_queries','t',env))().seeing
s=read('tools.lua');a=assert(s:find('function simplecheck(',1,true));assert(load(s:sub(a),'@installed_simplecheck_queries','t',env))()
local saved=RW_TestEntityCondition
local aliases={stop='block_entry',push='pushable',pull='pull',hide='hide',phantom='phantom'}
local cases=0
local ok,why=pcall(function()
 for mask=0,1023 do for reverse=0,1 do
  local w=RW_CreateSession().world;w.width=9;w.height=9;w.entities={};w.rule_sources={}
  local observer={id=10,class='object',archetype='avatar',x=4,y=4,direction='Right'};w.entities[10]=observer
  local stack=reverse==0 and {11,12} or {12,11};w.unit_order={10,stack[1],stack[2]}
  local units,features,probes={},{},{};local expected_trace,actual_trace={},{}
  for i=1,2 do
   local id=10+i;w.entities[id]={id=id,class='object',archetype=i==1 and 'rock' or 'flag',x=5,y=4,direction='None'}
   units[id]={name=w.entities[id].archetype,values={4,5,4}};features[id]={}
   for bit,trait in ipairs({'stop','push','pull','hide','phantom'})do
    local active=math.floor(mask/2^((i-1)*5+bit-1))%2==1;features[id][trait]=active
    local node={op='spatial',clauses={}};probes[node]={key=id..':'..trait,active=active}
    w.rule_sources[#w.rule_sources+1]={when=node,effects={{op='grant_trait',trait=aliases[trait],target={kind='id',value=id}}}}
   end
  end
  env.unitmap={[5+4*9]=stack};env.mmf={newObject=function(id)return units[id]end};env.getname=function(u)return u.name end
  env.inbounds=function(x,y)return x>=1 and x<=9 and y>=1 and y<=9 end
  env.findobstacle=function(x,y)return env.unitmap[x+y*9] or {}end
  env.hasfeature=function(_,_,trait,id)expected_trace[#expected_trace+1]=id..':'..trait;return features[id][trait] and true or nil end
  RW_TestEntityCondition=function(world,node,e)
   local p=probes[node];if p then actual_trace[#actual_trace+1]=p.key;return p.active end
   return saved(world,node,e)
  end
  local expected=native({'rock'},{},{},{unitid=10,x=4,y=4,dir=0,conds={}})
  local actual=saved(w,{op='spatial',clauses={{relation='seeing',negated=false,parameters={{tag='noun',type={tag='object',name='rock'}}}}}},observer)
  assert(actual==expected,'SEEING truth '..mask..':'..reverse)
  assert(table.concat(actual_trace,',')==table.concat(expected_trace,','),'SEEING query trace '..mask..':'..reverse..' expected '..table.concat(expected_trace,',')..' actual '..table.concat(actual_trace,','))
  if mask==1 and reverse==0 then
   -- A later blocker failure must be skipped, but every visibility query runs.
   local failkey='12:stop'
   RW_TestEntityCondition=function(world,node,e)
    local p=probes[node];if p then if p.key==failkey then return nil,'word_rule_limit' end;return p.active end
    return saved(world,node,e)
   end
   local condition={op='spatial',clauses={{relation='seeing',negated=false,parameters={{tag='noun',type={tag='object',name='rock'}}}}}}
   assert(saved(w,condition,observer)==expected,'opaque identity must skip later blocker failure')
   failkey='12:hide';local value,reason=saved(w,condition,observer)
   assert(value==nil and reason=='word_rule_limit','visibility failure must propagate before occlusion')
  end
  cases=cases+1
 end end
end)
RW_TestEntityCondition=saved;assert(ok,why)
print('PASS: installed SEEING visibility/occlusion query order and short circuit ('..cases..' cases)')
