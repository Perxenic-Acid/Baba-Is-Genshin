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
-- Execute the original parser's NOT-prefix toggle, then its full semantic passes.
local toggle=assert(source:match('(if %(prefix == "not "%) then.-end)'))
local prefix=assert(load('return function(count) local prefix=""; for i=1,count do '..toggle..' end; return prefix end','@original_not_prefix','t',env))()
local function term(base,count)
 local t=base=='all' and {tag='special',name='all'} or base=='group' and team(base) or noun(base)
 for i=1,count do t={tag='not',operand=t} end;return t
end
local checked,limited=0,0
for _,declaration in ipairs({'crate','all','group'})do for dn=0,3 do
for _,imitator in ipairs({'rock','all','group'})do for sn=0,3 do
for _,target in ipairs({'crate','all','group'})do for tn=0,3 do
for _,conditional in ipairs({false,true})do
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={
  [1]={id=1,kind='object',class='object',archetype='rock',x=4,y=3,direction='Right'},
  [2]={id=2,kind='object',class='object',archetype='crate',x=8,y=3,direction='Left'},
  [3]={id=3,kind='object',class='text',text={name='IS'},x=4,y=3,direction='None'}}
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true,group=true,group2=true,group3=true}
 for _,kind in ipairs(RW_NounPalette(w))do env.objectlist[kind]=true end
 local ast={};local function add(sub,subn,verb,obj,objn,condition)
  ast[#ast+1]={subject=term(sub,subn),verb=verb,object=term(obj,objn),when=when(condition)}
  env.addoption({prefix(subn)..sub,verb,prefix(objn)..obj},condition and {{'lonely',{}}} or {},{},false,nil,{})
 end
 add('rock',0,'is','group',0,false)
 add(declaration,dn,'has','flag',0,conditional)
 add(imitator,sn,'mimic',target,tn,conditional)
 local native_ok,why=pcall(function()env.subrules();env.grouprules()end)
 local generated,deferred,relations=RW_LowerRuleAST(ast,nil,w)
 local context=checked..':'..declaration..':'..dn..':'..imitator..':'..sn..':'..target..':'..tn
 if not native_ok then
  assert(tostring(why):find('toocomplex',1,true),why)
  assert(not generated and deferred=='rule_complexity_limit','NOT parity native limit '..context);limited=limited+1
 else
  assert(generated,'NOT parity unexpected project limit '..context)
  for _,r in ipairs(deferred)do assert(r.subject.tag=='special' and r.subject.name=='empty','NOT parity deferred '..context)end
  local has={};for _,r in ipairs(relations)do if r.op=='has' then has[#has+1]=r end end
  for id,unit in ipairs(w.entities)do
   local lonely=id==2;local expected=0
   for _,row in ipairs(env.features)do local r=row[1]
    if r[1]==(unit.class=='text' and 'text' or unit.archetype) and r[2]=='has' and r[3]=='flag' then
     local active=true;for _,c in ipairs(row[2])do local n=c[1]:gsub('[()]','')
      if n=='never' or n=='lonely' and not lonely or n=='not lonely' and lonely then active=false end
     end
     if active then expected=expected+1 end
    end
   end
   local births=assert(RW_PlanHasBirths(w,{id},has))
   assert(#births==expected,'NOT parity products '..context..':'..id..':'..#births..'/'..expected)
  end
 end
 checked=checked+1
end end end end end end end
assert(checked==3456)
print('PASS: installed parser NOT-prefix parity and addoption/subrules/grouprules, copied declarations and MIMIC subjects/targets ('..checked..' cases, '..limited..' limits)')
