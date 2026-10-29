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
local checked=0
for channel=1,3 do for rocks=0,2 do for flags=0,2 do
for _,conditional in ipairs({false,true}) do for ban=0,2 do for _,stack in ipairs({false,true}) do
for _,rhs in ipairs({false,true}) do
 local name='group'..(channel==1 and '' or channel)
 local w=RW_CreateSession().world;w.entities={};w.width=20;w.height=20
 for id,kind in ipairs({'rock','flag','avatar'}) do
  w.entities[id]={id=id,kind='object',class='object',archetype=kind,x=id*4,y=3,direction='Right'}
 end
 if stack then w.entities[4]={id=4,kind='object',class='object',archetype='wall',x=4,y=3} end
 local ast={};env.groupfeatures={};env.objectlist={rock=true,flag=true,avatar=true}
 local captured={};env.addoption=function(rule,conds) captured[#captured+1]={rule,conds} end
 local function add(subject,verb,object,condition,rawsubject,rawobject,rawconds)
  ast[#ast+1]={subject=subject,verb=verb,object=object,when=condition}
  env.groupfeatures[#env.groupfeatures+1]={{rawsubject,verb,rawobject},rawconds or {},{}, {}}
 end
 for _,entry in ipairs({{'rock',rocks},{'flag',flags}}) do for i=1,entry[2] do
  add(noun(entry[1]),'is',team(name),when(conditional),entry[1],name,conditional and {{'lonely',{}}} or {})
 end end
 if ban>0 then add(noun('rock'),'is',{tag='not',operand=team(name)},when(ban==2),'rock','not '..name,ban==2 and {{'lonely',{}}} or {}) end
 if rhs then add(noun('avatar'),'has',team(name),when(false),'avatar',name)
 else add(team(name),'has',noun('avatar'),when(false),name,'avatar') end
 env.grouprules()
 local g,d,relations=RW_LowerRuleAST(ast,nil,w);assert(g and #d==0)
 local function active(conditions,entity)
  local lonely=true;for id,e in pairs(w.entities) do if id~=entity.id and e.x==entity.x and e.y==entity.y then lonely=false end end
  for _,clause in ipairs(conditions) do
   local c=clause[1]:gsub('[()]','')
   if c=='never' or (c=='lonely' and not lonely) or (c=='not lonely' and lonely) then return false end
  end
  return true
 end
 for id=1,3 do
  local expected={}
  for _,rule in ipairs(captured) do
   if rule[1][1]==w.entities[id].archetype and rule[1][2]=='has' and active(rule[2],w.entities[id]) then
    local product=rule[1][3];expected[product]=(expected[product] or 0)+1
   end
  end
  local actual={};for _,product in ipairs(RW_PlanHasBirths(w,{id},relations)) do
   actual[product.archetype]=(actual[product.archetype] or 0)+1
  end
  for _,kind in ipairs({'rock','flag','avatar'}) do assert((expected[kind] or 0)==(actual[kind] or 0),'installed group expansion mismatch') end
 end
 checked=checked+1
end end end end end end end
print('PASS: installed GROUP channels, duplicate/conditional/excluded memberships and source/RHS HAS ('..checked..' cases)')
