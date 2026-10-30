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
local terminal
 env.destroylevel=function(reason) terminal=reason end
local checked,loops=0,0
for channel=1,3 do for _,kind in ipairs({'rock','flag'}) do
for _,relation in ipairs({'on','near','without'}) do for _,negated in ipairs({false,true}) do
for seed=0,2 do for base_copies=1,2 do for recursive_copies=1,2 do
for layout=0,2 do for _,other_group in ipairs({false,true}) do
 local name='group'..(channel==1 and '' or channel)
 local ref=other_group and (channel==3 and 'group' or 'group3') or name
 local w=RW_CreateSession().world;w.width=8;w.height=8;w.entities={};w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 local function object(id,archetype,x,y) w.entities[id]={id=id,kind='object',class='object',archetype=archetype,x=x,y=y,direction='Right'} end
 object(10,'avatar',3,3);object(11,'rock',3,3);object(13,'flag',layout==2 and 6 or 3,layout==2 and 6 or 3)
 if layout>0 then object(12,'rock',layout==1 and 3 or 7,layout==1 and 3 or 7) end
 current_world=w;env.roomsizex=8;env.unitmap={};env.unitlists={};env.objectlist={}
 for _,noun in ipairs(RW_NounPalette(w)) do env.objectlist[noun]=true end
 for id,e in pairs(w.entities) do
  env.unitlists[e.archetype]=env.unitlists[e.archetype] or {};table.insert(env.unitlists[e.archetype],id)
  local tile=e.x+e.y*8;env.unitmap[tile]=env.unitmap[tile] or {};table.insert(env.unitmap[tile],id)
 end
 local ast={};env.groupfeatures={};env.addoption=function() end
 if seed>0 then for i=1,base_copies do
  local base_kind=seed==1 and 'rock' or 'flag'
  ast[#ast+1]={subject=noun(base_kind),verb='is',object=team(name),when=when(false)}
  env.groupfeatures[#env.groupfeatures+1]={{base_kind,'is',name},{},{}, {}}
 end end
 for i=1,recursive_copies do
  ast[#ast+1]={subject=noun(kind),verb='is',object=team(name),when={op='spatial',clauses={{relation=relation,negated=negated,parameters={team(ref)}}}}}
  env.groupfeatures[#env.groupfeatures+1]={{kind,'is',name},{{(negated and 'not ' or '')..relation,{ref}}},{}, {}}
 end
 env.grouprules()
 ast[#ast+1]={subject=noun('avatar'),verb='is',object={tag='property',name='safe'},when={op='spatial',clauses={{relation='near',negated=false,parameters={team(name)}}}}}
 local generated,deferred=RW_LowerRuleAST(ast,nil,w);assert(generated and #deferred==0)
 local effects,err=RW_EvaluateRules(w,generated)
 terminal=nil
 local expected=env.testcond({{'near',{name}}},10)
 if terminal=='infinity' then
  assert(not effects and err=='word_rule_limit','original recursive group loop must propagate terminal error');loops=loops+1
 else
  assert(effects,err)
  local actual=false;for _,effect in ipairs(effects) do for _,id in ipairs(effect.entity_ids) do if effect.trait=='safe' and id==10 then actual=true end end end
  assert(actual==expected,'recursive group source mismatch: '..channel..':'..kind..':'..relation..':'..tostring(negated)..':'..seed..':'..base_copies..':'..recursive_copies..':'..layout..':'..tostring(other_group))
 end
 checked=checked+1
end end end end end end end end end
assert(checked==2592 and loops==324,'installed recursive group scope changed')
print('PASS: installed recursive GROUP previous-round substitution, seeds/duplicates/cross-name references and loop limit ('..checked..' cases; '..loops..' loops)')
