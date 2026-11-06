-- Installed powered/findempty with normalized declaration condition answers.
local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local s=read('conditions.lua');local a=assert(s:find('powered = function',1,true));local b=assert(s:find('idle = function',a,true))
local env=setmetatable({XPOS=1,YPOS=2,roomsizex=5,roomsizey=5},{__index=_G})
local native=assert(load('return {'..s:sub(a,b-1)..'}','@installed_powered_order','t',env))().powered
s=read('tools.lua');a=assert(s:find('function findempty(',1,true));b=assert(s:find('function handleinside(',a,true));assert(load(s:sub(a,b-1),'@installed_powered_findempty','t',env))()
local kinds={'rock','flag','text','empty','level'};local saved=RW_TestEntityCondition;local cases=0
local ok,why=pcall(function()
for channel=1,3 do for _,first in ipairs(kinds)do for _,second in ipairs(kinds)do for mask=0,15 do for reverse=0,1 do
 local suffix=channel==1 and '' or tostring(channel);local trait='power'..suffix
 local w=RW_CreateSession().world;w.width=3;w.height=3;w.entities={};w.rule_sources={}
 local specs={{10,'avatar',1,1},{11,'rock',2,1},{12,'rock',3,1},{13,'flag',2,2},{14,'text',3,3}}
 local units={};env.units={};env.unitlists={};w.unit_order={}
 for _,p in ipairs(specs)do
  w.entities[p[1]]={id=p[1],kind='object',class=p[2]=='text' and 'text' or 'object',archetype=p[2],x=p[3],y=p[4],direction='Right'}
  if p[2]=='text'then w.entities[p[1]].text={name='ROCK'}end
  units[p[1]]={fixed=p[1],values={p[3],p[4]}}
 end
 for i=1,#specs do local p=specs[reverse==0 and i or #specs-i+1];local id,name=p[1],p[2]
  w.unit_order[#w.unit_order+1]=id;env.units[#env.units+1]=units[id]
  env.unitlists[name]=env.unitlists[name] or {};env.unitlists[name][#env.unitlists[name]+1]=id
 end
 env.map={[0]={get_x=function(_,x,y)return x>=1 and x<=3 and y>=1 and y<=3 and 255 or 0 end}}
 env.featureindex={[trait]={}};env.poweredstatus={}
 local probes={};local expected_trace,actual_trace={},{}
 for index,kind in ipairs({first,second})do
  local node={op='spatial',clauses={{relation='idle',negated=false,parameters={}}},query_probe=index};probes[node]=index
  local conds={{'probe',{}}};conds.marker=index
  env.featureindex[trait][index]={{kind,'is',trait},conds}
  if kind=='level'then w.rule_sources[index]={effects={},scoped_conditions={{op='level_trait',trait=trait,when=node}}}
  else w.rule_sources[index]={when=node,effects={{op='grant_trait',trait=trait,target={kind=kind=='empty' and 'empty' or kind=='text' and 'class' or 'archetype',value=kind}}}}end
 end
 local function key(id,x,y)
  if id==1 then return 'L',0 elseif id==2 then return 'E:'..x..':'..y,(x+y*3)%4 end
  return tostring(id),id%4
 end
 local function answer(marker,slot)return math.floor(mask/2^((marker+slot)%4))%2==1 end
 env.testcond=function(conds,id,x,y)
  local who,slot=key(id,x,y);expected_trace[#expected_trace+1]=conds.marker..':'..who;return answer(conds.marker,slot)
 end
 RW_TestEntityCondition=function(world,node,e,autofail)
  local marker=probes[node] or node.query_probe
  if marker then
   local who,slot=key(e.class=='level' and 1 or e.class=='empty' and 2 or e.id,e.x,e.y)
   actual_trace[#actual_trace+1]=marker..':'..who;return answer(marker,slot)
  end
  return saved(world,node,e,autofail)
 end
 local expected=native({}, {}, {}, {x=1,y=1,limit=0,subtype=suffix,conds={}})
 local actual,reason=saved(w,{op='spatial',clauses={{relation='powered'..suffix,negated=false,parameters={}}}},w.entities[10])
 assert(actual==expected,'POWERED truth '..cases..':'..tostring(reason))
 assert(table.concat(actual_trace,';')==table.concat(expected_trace,';'),'POWERED queries '..cases..' expected '..table.concat(expected_trace,';')..' actual '..table.concat(actual_trace,';'))
 -- Compiler scoped rows are published at the end of the generated frame. They
 -- must still query in the same physical AST order as the ordinary declarations.
 local ast={}
 for index,kind in ipairs({first,second})do
  local subject=kind=='text' or kind=='empty'
   if subject then subject={tag='special',name=kind}
   else subject={tag='noun',type=kind=='level' and {tag='level'} or {tag='object',name=kind}}end
  ast[index]={subject=subject,verb='is',object={tag='property',name=trait},when={op='spatial',clauses={{relation='idle',negated=false,parameters={}}},query_probe=index}}
 end
 w.rule_sources={};local generated,deferred=RW_LowerRuleAST(ast,nil,w);assert(generated and #deferred==0)
 w._condition_rules=generated;actual_trace={}
 local compiled,compile_reason=saved(w,{op='spatial',clauses={{relation='powered'..suffix,negated=false,parameters={}}}},w.entities[10])
 assert(compiled==expected,'compiled POWERED truth '..cases..':'..tostring(compile_reason))
 assert(table.concat(actual_trace,';')==table.concat(expected_trace,';'),'compiled POWERED queries '..cases..' expected '..table.concat(expected_trace,';')..' actual '..table.concat(actual_trace,';'))
 if first=='rock' and second=='level' and mask==1 and reverse==0 then
  local failing=2
  RW_TestEntityCondition=function(world,node,e,autofail)
   local marker=probes[node] or node.query_probe
   if marker then
    if marker==failing then return nil,'word_rule_limit' end
    local _,slot=key(e.class=='level' and 1 or e.class=='empty' and 2 or e.id,e.x,e.y);return answer(marker,slot)
   end
   return saved(world,node,e,autofail)
  end
  local condition={op='spatial',clauses={{relation='powered'..suffix,negated=false,parameters={}}}}
  assert(saved(w,condition,w.entities[10])==true,'earlier ordinary power must skip later scoped failure')
  failing=1;local value,reason=saved(w,condition,w.entities[10]);assert(value==nil and reason=='word_rule_limit','required power failure must propagate')
 end
 cases=cases+1
end end end end end
end)
RW_TestEntityCondition=saved;assert(ok,why)
assert(cases==2400)
print('PASS: installed POWERED/findempty declaration-first traversal, real/Text/EMPTY/LEVEL sources, duplicates, three channels and unit/cell order ('..cases..' cases)')
