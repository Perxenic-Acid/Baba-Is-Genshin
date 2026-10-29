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
local pairs_={{'group','group2'},{'group','group3'},{'group2','group'},{'group2','group3'},{'group3','group'},{'group3','group2'}}
for mask=0,63 do for _,reverse in ipairs({false,true}) do for duplicates=1,2 do
for _,conditional in ipairs({false,true}) do for _,stack in ipairs({false,true}) do for variant=0,3 do
 local w=RW_CreateSession().world;w.width=20;w.height=20;w.entities={}
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
 for i=1,duplicates do add(noun('rock'),'is',team('group'),when(conditional),'rock','group',conditional and {{'lonely',{}}} or {}) end
 add(noun('flag'),'is',team('group'),when(false),'flag','group')
 for slot=1,6 do
  local i=reverse and 7-slot or slot
  if math.floor(mask/2^(i-1))%2==1 then
   local edge=pairs_[i]
   add(team(edge[1]),'is',team(edge[2]),when(false),edge[1],edge[2])
  end
 end
 if variant==1 or variant==2 then
  add(team('group'),'is',{tag='not',operand=team('group2')},when(variant==2),'group','not group2',variant==2 and {{'lonely',{}}} or {})
 elseif variant==3 then
  add(noun('rock'),'is',{tag='not',operand=team('group')},when(true),'rock','not group',{{'lonely',{}}})
 end
 for _,name in ipairs({'group','group2','group3'}) do add(team(name),'has',noun('avatar'),when(false),name,'avatar') end
 env.grouprules()
 local g,d,relations=RW_LowerRuleAST(ast,nil,w);assert(g and #d==0)
 for id=1,2 do
  local lonely=true;for other,e in pairs(w.entities) do if other~=id and e.x==w.entities[id].x and e.y==w.entities[id].y then lonely=false end end
  local expected=0
  for _,rule in ipairs(captured) do if rule[1][1]==w.entities[id].archetype and rule[1][2]=='has' then
   local enabled=true
   for _,clause in ipairs(rule[2]) do
    local c=clause[1]:gsub('[()]','')
    if c=='never' or (c=='lonely' and not lonely) or (c=='not lonely' and lonely) then enabled=false end
   end
   if enabled then expected=expected+1 end
  end end
  assert(#RW_PlanHasBirths(w,{id},relations)==expected,'installed ordered group transfer mismatch')
 end
 checked=checked+1
end end end end end end
print('PASS: installed GROUP ordered transfer graphs, cycles, edge order, duplicate and cumulative conditions ('..checked..' cases)')
