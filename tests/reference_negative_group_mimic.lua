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
-- Native baseline for the next endpoint gap. subrules precedes grouprules:
-- NOT GROUP can generate later MIMIC declarations, but copying is not rerun.
local checked=0
for channel=1,3 do for membership=0,3 do for copies=1,2 do
for _,target in ipairs({'avatar','group2','all'}) do for _,conditional in ipairs({false,true}) do for _,negative in ipairs({false,true}) do
 local name=channel==1 and 'group' or 'group'..channel
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true,group=true,group2=true,group3=true}
 for _,kind in ipairs(RW_NounPalette(w))do env.objectlist[kind]=true end
 local function add(sub,verb,obj,condition)
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
 checked=checked+1
end end end end end end
assert(checked==288)
print('PASS: installed NOT GROUP MIMIC baseline, three channels, ALL/ordinary/GROUP targets, memberships, duplicate and conditional rules ('..checked..' cases)')
