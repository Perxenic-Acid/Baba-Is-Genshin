-- Execute the installed grouprules() and invertconds(), normalize only host APIs.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua');dofile('external_lua_file/properties.lua')
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
assert(load(conditions_source:sub(1,assert(conditions_source:find('condlist =',1,true))-1),'@original_testcond','t',env))()
env.XPOS=1;env.YPOS=2;env.DIR=3;env.UNITNAME=1;env.UNITTYPE=2
local current_lonely
 env.mmf={newObject=function() return {values={1,1,0},strings={'rock','object'}} end}
env.conditions={};env.unitreference={text_lonely='lonely'};env.features={{}};env.featureindex={}
env.condlist={lonely=function(params,checked) return current_lonely,checked end,never=function(params,checked) return false,checked end}
local checked,skipped=0,0
local invalid_original=false
env.MF_alert=function() invalid_original=true end
for channel=1,3 do for rocks=0,2 do for flags=0,2 do for condition=0,2 do
for exclusion=0,2 do for _,stack in ipairs({false,true}) do for mode=1,8 do
 local name='group'..(channel==1 and '' or channel)
 local w=RW_CreateSession().world;w.width=20;w.height=20;w.entities={};w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag"
 for id,kind in ipairs({'rock','flag','avatar'}) do w.entities[id]={id=id,kind='object',class='object',archetype=kind,x=id*4,y=3,direction='Right'} end
 if stack then w.entities[4]={id=4,kind='object',class='object',archetype='wall',x=4,y=3} end
 local ast={};env.groupfeatures={};env.objectlist={rock=true,flag=true,avatar=true}
 local captured={};env.addoption=function(rule,conds) captured[#captured+1]={rule,conds} end
 local function neg(term) return {tag='not',operand=term} end
 local function add(subject,verb,object,cond,rawsubject,rawobject,rawconds,ordinary)
  ast[#ast+1]={subject=subject,verb=verb,object=object,when=cond}
  local raw={{rawsubject,verb,rawobject},rawconds or {},{}, {}}
  if ordinary then captured[#captured+1]=raw else env.groupfeatures[#env.groupfeatures+1]=raw end
 end
 local membership_when=when(condition>0)
 if condition==2 then membership_when.clauses[1].negated=true end
 local raw_when=condition==0 and {} or {{condition==1 and 'lonely' or 'not lonely',{}}}
 for i=1,rocks do add(noun('rock'),'is',team(name),membership_when,'rock',name,raw_when) end
 for i=1,flags do add(noun('flag'),'is',team(name),when(false),'flag',name) end
 if exclusion>0 then add(noun('rock'),'is',neg(team(name)),when(exclusion==2),'rock','not '..name,exclusion==2 and {{'lonely',{}}} or {}) end
 if mode==1 then add(neg(team(name)),'has',noun('avatar'),when(false),'not '..name,'avatar')
 elseif mode==2 then
  add(noun('avatar'),'has',noun('rock'),when(false),'avatar','rock',nil,true)
  add(noun('avatar'),'has',noun('flag'),when(false),'avatar','flag',nil,true)
  add(noun('avatar'),'has',neg(team(name)),when(false),'avatar','not '..name)
 elseif mode==3 then add(team(name),'has',team(name),when(false),name,name)
 elseif mode==4 then add(neg(team(name)),'has',team(name),when(false),'not '..name,name)
 elseif mode==5 then
  add(team(name),'has',team(name),when(false),name,name)
  add(team(name),'has',neg(team(name)),when(true),name,'not '..name,{{'lonely',{}}})
 elseif mode==6 then add(team(name),'is',neg(team(name)),when(false),name,'not '..name)
 elseif mode==7 then add(neg(team(name)),'is',team(name),when(false),'not '..name,name)
 else add(neg(team(name)),'is',neg(team(name)),when(false),'not '..name,'not '..name) end
 env.grouprules()
 local g,d,relations=RW_LowerRuleAST(ast,nil,w);assert(g and #d==0)
 local projected=assert(RW_ProjectWorld(w,assert(RW_EvaluateRules(w,g))))
 for id=1,3 do
  local lonely=true;for other,e in pairs(w.entities) do if other~=id and e.x==w.entities[id].x and e.y==w.entities[id].y then lonely=false end end
  current_lonely=lonely
  local function active(conditions) return env.testcond(conditions,100+id) end
  invalid_original=false
  local expected,denied={},{};local crash=false
  for _,item in ipairs(captured) do local r=item[1]
   if r[1]==w.entities[id].archetype and active(item[2]) then
    if r[2]=='has' then
     if r[3]:sub(1,4)=='not ' then denied[r[3]:sub(5)]=true else expected[r[3]]=(expected[r[3]] or 0)+1 end
    elseif r[2]=='is' and r[3]=='crash' then crash=true end
   end
  end
  local actual={};for _,product in ipairs(RW_PlanHasBirths(w,{id},relations)) do actual[product.archetype]=(actual[product.archetype] or 0)+1 end
  if not invalid_original then
  for _,kind in ipairs({'rock','flag','avatar'}) do
   assert((denied[kind] and 0 or expected[kind] or 0)==(actual[kind] or 0),'installed GROUP complement HAS mismatch: '..mode..':'..rocks..':'..flags..':'..condition..':'..exclusion)
  end
  assert((projected.entities[id].behaviors.crash==true)==crash,'installed same-group CRASH mismatch')
  else skipped=skipped+1 end
 end
 checked=checked+1
end end end end end end end
assert(checked==3888 and skipped==324,'original malformed-condition scope changed')
print('PASS: installed NOT GROUP consumers/targets, cartesian groups, exclusions and same-group CRASH ('..checked..' cases; '..skipped..' malformed original identity frames excluded)')
