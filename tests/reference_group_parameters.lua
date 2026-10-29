-- Execute the installed grouprules() and invertconds(), normalize only host APIs.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('function grouprules()',1,true));local b=assert(source:find('function copyrule(',a,true))
local ia=assert(source:find('function invertconds(',1,true));local ib=assert(source:find('function rulelog(',ia,true))
local env=setmetatable({},{__index=_G})
env.copyconds=function(dst,src) for _,v in ipairs(src or {}) do dst[#dst+1]=v end;return dst end
env.concatenate=function(...) local dst={};for _,src in ipairs({...}) do for _,v in ipairs(src) do dst[#dst+1]=v end end;return dst end
env.findnoun=function() return false end
env.MF_alert=function() end;env.destroylevel=function() error('unexpected group recursion') end
assert(load(source:sub(ia,ib-1),'@original_invertconds','t',env))()
assert(load(source:sub(a,b-1),'@original_groups','t',env))()
local function noun(name) return {tag='noun',type={tag='object',name=name}} end
local function team(name) return {tag='noun',type={tag='group',name=name}} end
local function when(lonely) return lonely and {op='spatial',clauses={{relation='lonely',negated=false,parameters={}}}} or {op='always'} end
local cf=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'))
local conditions_source=cf:read('*a');cf:close()
assert(load(conditions_source,'@original_conditions','t',env))()
local tf=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local tools_source=tf:read('*a');tf:close()
local ta=assert(tools_source:find('function findnoun(',1,true));local tb=assert(tools_source:find('function groupcheck(',ta,true))
assert(load(tools_source:sub(ta,tb-1),'@original_findgroup','t',env))()
env.XPOS=1;env.YPOS=2;env.DIR=3;env.UNITNAME=1;env.UNITTYPE=2
 env.conditions={};env.unitreference={text_lonely='lonely',text_on='on',text_near='near',text_without='without'}
env.features={{}};env.featureindex={};env.nlist={full={'group','all','text','empty','level'},short={'group','all','text','empty'}}
local current_world
 env.mmf={newObject=function(id) local e=current_world.entities[id];return {values={e.x,e.y,0},strings={e.archetype,'object'}} end}
for _,relation in ipairs({'on','near','without'}) do
 env.condlist[relation]=function(params,checked,_,data)
  -- Primitive conditions already have their own regressions. Here they consume
  -- the exact parameter list produced by installed testcond/findgroup.
  local terms={};for i=#params,1,-1 do terms[#terms+1]=noun(params[i]) end
  local value=RW_TestEntityCondition(current_world,{op='spatial',clauses={{relation=relation,negated=data.notcond,parameters=terms}}},current_world.entities[data.unitid])
  return data.notcond and not value or not data.notcond and value,checked
 end
end
local checked=0
for channel=1,3 do for duplicates=0,2 do for flags=0,1 do for condition=0,2 do
for ban=0,2 do for _,remote in ipairs({false,true}) do for form=1,5 do
for _,relation in ipairs({'on','near','without'}) do for _,negative in ipairs({false,true}) do
 local name='group'..(channel==1 and '' or channel)
 local w=RW_CreateSession().world;w.width=8;w.height=8;w.entities={};w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 local function object(id,kind,x,y) w.entities[id]={id=id,kind='object',class='object',archetype=kind,x=x,y=y,direction='Right'} end
 object(10,'avatar',3,3);object(11,'rock',3,3);object(13,'flag',remote and 3 or 4,3)
 if remote then object(12,'rock',7,7) end
 current_world=w;env.roomsizex=8;env.unitmap={};env.unitlists={};env.objectlist={}
 for _,kind in ipairs(RW_NounPalette(w)) do env.objectlist[kind]=true end
 for id,e in pairs(w.entities) do
  env.unitlists[e.archetype]=env.unitlists[e.archetype] or {};table.insert(env.unitlists[e.archetype],id)
  local tile=e.x+e.y*8;env.unitmap[tile]=env.unitmap[tile] or {};table.insert(env.unitmap[tile],id)
 end
 local ast={};env.groupfeatures={};env.addoption=function() end
 local function add(term,rawkind,count,cond,rawconds,negative_member)
  for i=1,count do
   ast[#ast+1]={subject=term,verb='is',object=negative_member and {tag='not',operand=team(name)} or team(name),when=cond}
   env.groupfeatures[#env.groupfeatures+1]={{rawkind,'is',(negative_member and 'not ' or '')..name},rawconds,{}, {}}
  end
 end
 local cond=when(condition>0);if condition==2 then cond.clauses[1].negated=true end
 add(noun('rock'),'rock',duplicates,cond,condition==0 and {} or {{condition==1 and 'lonely' or 'not lonely',{}}})
 add(noun('flag'),'flag',flags,when(false),{})
 if ban>0 then add(noun('rock'),'rock',1,when(ban==2),ban==2 and {{'lonely',{}}} or {},true) end
 env.grouprules()
 local rawparams=form==1 and {name} or form==2 and {'not '..name} or form==3 and {name,'rock'} or form==4 and {'rock',name} or {name,name}
 local params={};for _,value in ipairs(rawparams) do
  if value=='rock' then params[#params+1]=noun('rock')
  elseif value:sub(1,4)=='not ' then params[#params+1]={tag='not',operand=team(name)}
  else params[#params+1]=team(name) end
 end
 ast[#ast+1]={subject=noun('avatar'),verb='is',object={tag='property',name='safe'},when={op='spatial',clauses={{relation=relation,negated=negative,parameters=params}}}}
 local generated,deferred=RW_LowerRuleAST(ast,nil,w);assert(generated and #deferred==0)
 local effects=assert(RW_EvaluateRules(w,generated));local actual=false
 for _,effect in ipairs(effects) do if effect.trait=='safe' then for _,id in ipairs(effect.entity_ids) do if id==10 then actual=true end end end end
 local expected=env.testcond({{(negative and 'not ' or '')..relation,rawparams}},10)
 assert(actual==expected,'installed GROUP parameter mismatch: '..channel..':'..duplicates..':'..flags..':'..condition..':'..ban..':'..tostring(remote)..':'..form..':'..relation..':'..tostring(negative))
 checked=checked+1
end end end end end end end end end
print('PASS: installed findgroup/testcond parameter promotion, duplicates, complements, ordering, empty groups and conditions ('..checked..' cases)')
