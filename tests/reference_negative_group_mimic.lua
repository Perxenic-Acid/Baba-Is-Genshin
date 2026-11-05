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

-- Exercise original addoption/subrules too: ALL is expanded before grouprules.
assert(load(source:sub(assert(source:find('function addoption(',1,true)),assert(source:find('function postrules(',1,true))-1),'@original_all_subrules','t',env))()
env.nlist={short={'group','all','text','empty','level'}}
env.findnoun=function(name)
 return name=='all' or name=='text' or name=='empty' or name=='level' or name:sub(1,5)=='group'
end

assert(load(source:sub(assert(source:find('function copyrule(',1,true)),assert(source:find('function comparerules(',1,true))-1),'@original_copyrule','t',env))()
env.getmat=function(name) return env.objectlist[name] and name or nil end
-- subrules precedes grouprules:
-- NOT GROUP can generate later MIMIC declarations, but copying is not rerun.
local checked=0
for channel=1,3 do for membership=0,3 do for copies=1,2 do
for _,target in ipairs({'avatar','group2','all'}) do for _,conditional in ipairs({false,true}) do for _,negative in ipairs({false,true}) do
 local name=channel==1 and 'group' or 'group'..channel
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={
  [1]={id=1,kind='object',class='object',archetype='rock',x=4,y=3,direction='Right'},
  [2]={id=2,kind='object',class='object',archetype='avatar',x=8,y=3,direction='Left'},
  [3]={id=3,kind='object',class='text',text={name='IS'},x=4,y=3,direction='None'}}
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true,group=true,group2=true,group3=true}
 for _,kind in ipairs(RW_NounPalette(w))do env.objectlist[kind]=true end
 local ast={}
 local function term(raw)
  if raw:sub(1,4)=='not ' then return {tag='not',operand=term(raw:sub(5))} end
  if raw=='all' then return {tag='special',name='all'} end
  return raw:sub(1,5)=='group' and team(raw) or noun(raw)
 end
 local function add(sub,verb,obj,condition)
  ast[#ast+1]={subject=term(sub),verb=verb,object=term(obj),when=when(condition)}
  env.addoption({sub,verb,obj},condition and {{'lonely',{}}} or {},{},false,nil,{})
 end
 if membership>0 then add(membership==1 and 'rock' or membership==2 and 'all' or 'not all','is',name,false) end
 add(target,'has','flag',conditional)
 for i=1,copies do add((negative and 'not ' or '')..name,'mimic',target,conditional) end
 env.subrules()
 local copies_before_groups=0
 for _,row in ipairs(env.features)do for _,tag in ipairs(row[4] or {})do
  if tag=='mimic' then copies_before_groups=copies_before_groups+1 end
 end end
 assert((copies_before_groups==0)==negative,'native NOT GROUP unexpectedly copied before membership expansion')
 env.grouprules()
 local copies_after_groups=0
 for _,row in ipairs(env.features)do for _,tag in ipairs(row[4] or {})do
  if tag=='mimic' then copies_after_groups=copies_after_groups+1 end
 end end
 assert((copies_after_groups==0)==negative,'native NOT GROUP unexpectedly reran copying after group expansion')
 local generated,deferred,relations=RW_LowerRuleAST(ast,nil,w);assert(generated)
 for _,rule in ipairs(deferred) do
  assert(not negative and rule.subject.tag=='special' and rule.subject.name=='empty',
   'recognized inert NOT GROUP MIMIC must not remain deferred')
 end
 local has={};for _,r in ipairs(relations)do if r.op=='has' then has[#has+1]=r end end
 for id,unit in ipairs(w.entities) do
  local expected=0;local lonely=true
  for other_id,other in pairs(w.entities)do if other_id~=id and other.x==unit.x and other.y==unit.y then lonely=false end end
  for _,row in ipairs(env.features)do local r=row[1]
   if r[1]==(unit.class=='text' and 'text' or unit.archetype) and r[2]=='has' and r[3]=='flag' then
    local active=true;for _,c in ipairs(row[2])do
     local condition=c[1]:gsub('[()]','')
     if condition=='never' or condition=='lonely' and not lonely or condition=='not lonely' and lonely then active=false end
    end
    if active then expected=expected+1 end
   end
  end
  local births=assert(RW_PlanHasBirths(w,{id},has))
  assert(#births==expected,'NOT GROUP MIMIC source parity '..checked..':'..id..':'..#births..'/'..expected..':'..tostring(negative)..':'..target)
 end
 checked=checked+1
end end end end end end
assert(checked==288)
print('PASS: installed NOT GROUP MIMIC timing/runtime parity, positive controls, three channels, ALL/ordinary/GROUP targets, memberships, duplicate and conditional rules ('..checked..' cases)')
