dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]],'rb'))
local source=f:read('*a');f:close()
local env=setmetatable({}, {__index=_G})
env.copyconds=function(dst,src) for _,v in ipairs(src or {}) do dst[#dst+1]=v end;return dst end
env.concatenate=function(...) local t={};for _,src in ipairs({...}) do for _,v in ipairs(src) do t[#t+1]=v end end;return t end
env.nlist={short={'all','text','empty','level','group','group2','group3'}}
env.findnoun=function(name) for _,v in ipairs(env.nlist.short) do if name==v then return true end end;return false end
env.getmat=function(name) return env.objectlist[name] and name or nil end
env.MF_alert=function() end;env.destroylevel=function(reason) error(reason) end
local ia=assert(source:find('function invertconds(',1,true));local ib=assert(source:find('function rulelog(',ia,true))
assert(load(source:sub(ia,ib-1),'@original_invertconds','t',env))()
local a=assert(source:find('function addoption(',1,true));local b=assert(source:find('function postrules(',a,true))
assert(load(source:sub(a,b-1),'@original_addoption_subrules','t',env))()
local ca=assert(source:find('function copyrule(',1,true));local cb=assert(source:find('function comparerules(',ca,true))
assert(load(source:sub(ca,cb-1),'@original_copyrule','t',env))()
local function term(name)
 if name:sub(1,4)=='not ' then return {tag='not',operand=term(name:sub(5))} end
 if name=='all' or name=='empty' or name=='text' then return {tag='special',name=name} end
 return {tag='noun',type={tag='object',name=name}}
end
local checked,limited=0,0
for _,first in ipairs({'all','rock'}) do for _,second in ipairs({'all','rock'}) do
for _,target in ipairs({'crate','all'}) do for _,reverse in ipairs({false,true}) do
for _,declarations in ipairs({1,2,10,20,30}) do for _,copies in ipairs({1,2,3}) do
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.rule_sources={}
 w.entities={[1]={id=1,kind='object',class='object',archetype='rock',x=4,y=3,direction='Right'}}
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true};for _,name in ipairs(RW_NounPalette(w))do env.objectlist[name]=true end
 local ast={}
 local function add(sub,verb,obj)
  ast[#ast+1]={subject=term(sub),verb=verb,object=term(obj),when={op='always'}}
  env.addoption({sub,verb,obj},{},{},false,nil,{})
 end
 for i=1,declarations do add('crate','has',i%2==0 and 'rock' or 'flag') end
 add('flag','has','crate')
 local function one()for i=1,copies do add(first,'mimic',target)end end
 local function two()add(second,'mimic','flag')end
 if reverse then two();one() else one();two() end
 local native_ok,why=pcall(env.subrules)
 local generated,deferred,relations=RW_LowerRuleAST(ast,nil,w)
 if not native_ok then
  assert(tostring(why):find('toocomplex',1,true),why)
  assert(not generated and deferred=='rule_complexity_limit','ordered native limit '..checked)
  limited=limited+1
 else
  assert(generated and #deferred==0,'unexpected ordered project limit '..checked)
  local expected={};for _,row in ipairs(env.features)do local r=row[1]
   if r[1]=='rock' and r[2]=='has' then expected[#expected+1]=r[3] end
  end
  local has={};for _,r in ipairs(relations)do if r.op=='has' then has[#has+1]=r end end
  local births=assert(RW_PlanHasBirths(w,{1},has))
  assert(#births==#expected,'ordered product count '..checked)
  -- ALL targets use authored palette order, not native hash traversal order.
  if target~='all' then for i,name in ipairs(expected)do assert(births[i].archetype==name,'ALL source copy order '..checked..':'..i)end end
 end
 checked=checked+1
end end end end end end
assert(checked==240)
print('PASS: installed ALL MIMIC growing-queue order, mixed original/derived declarations and copy limits ('..checked..' cases, '..limited..' limits)')
for _,total in ipairs({249,250,251}) do
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true};for _,name in ipairs(RW_NounPalette(w))do env.objectlist[name]=true end
 local ast={};local function add(sub,verb,obj)
  ast[#ast+1]={subject=term(sub),verb=verb,object=term(obj),when={op='always'}}
  env.addoption({sub,verb,obj},{},{},false,nil,{})
 end
 local width=#RW_NounPalette(w)+1
 for i=1,math.floor(total/width) do add('crate','has','rock') end
 add('all','mimic','crate');add('flag','has','rock')
 for i=1,total%width do add('rock','mimic','flag') end
 local native_ok,why=pcall(env.subrules);local generated,reason=RW_LowerRuleAST(ast,nil,w)
 assert(native_ok==(total<=250),'native ALL copy threshold '..total..':'..tostring(why))
 assert((generated~=nil)==native_ok,'project ALL raw/concrete copy threshold '..total)
 if not native_ok then assert(reason=='rule_complexity_limit') end
end
print('PASS: installed ALL MIMIC raw/concrete copy thresholds at 249/250/251')
