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
local checked=0
for channel=1,3 do for membership=0,3 do for scenario=1,4 do for copies=1,2 do
for ban=0,2 do for _,conditional in ipairs({false,true}) do for _,target_cond in ipairs({false,true}) do
 local name=channel==1 and 'group' or 'group'..channel
 local other=channel==3 and 'group' or 'group'..(channel+1)
 local w=RW_CreateSession().world;w.entities={};w.width=20;w.height=20
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 for id,kind in ipairs({'rock','flag','avatar'}) do w.entities[id]={id=id,kind='object',class='object',archetype=kind,x=id*4,y=3,direction='Right'} end
 w.entities[4]={id=4,kind='object',class='text',text={name='IS'},x=4,y=3,direction='None'}
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true,group=true,group2=true,group3=true};for _,kind in ipairs(RW_NounPalette(w)) do env.objectlist[kind]=true end
 local ast={}
 local function term(raw)
  if raw=='all' then return {tag='special',name='all'} end
  if raw:sub(1,4)=='not ' then return {tag='not',operand=term(raw:sub(5))} end
  return raw:sub(1,5)=='group' and team(raw) or noun(raw)
 end
 local function add(subject,verb,object,condition)
  ast[#ast+1]={subject=term(subject),verb=verb,object=term(object),when=when(condition)}
  env.addoption({subject,verb,object},condition and {{'lonely',{}}} or {},{},false,nil,{})
 end
 if membership>0 then add(membership==1 and 'rock' or membership==2 and 'all' or 'not all','is',name,false) end
 add('flag','is',other,false)
 local source_name,target_name
 if scenario==1 then source_name,target_name='avatar',name
 elseif scenario==2 then source_name,target_name=name,'avatar'
 elseif scenario==3 then source_name,target_name=name,other
 else source_name,target_name=other,name end
 add(target_name,'has','flag',target_cond)
 for i=1,copies do add(source_name,'mimic',target_name,conditional) end
 if ban>0 then add(source_name,'mimic','not '..target_name,ban==2) end
 env.subrules();env.grouprules()
 local g,d,relations=RW_LowerRuleAST(ast,nil,w);assert(g,'MIMIC group lowering failed')
 for _,r in ipairs(d) do assert(r.subject.tag=='special' and r.subject.name=='empty','unexpected MIMIC GROUP deferred '..checked) end
 local has={};for _,r in ipairs(relations) do if r.op=='has' then has[#has+1]=r end end
 local function active(conditions,entity)
  local lonely=true;for id,e in pairs(w.entities) do if id~=entity.id and e.x==entity.x and e.y==entity.y then lonely=false end end
  for _,clause in ipairs(conditions) do local c=clause[1]:gsub('[()]','')
   if c=='never' or (c=='lonely' and not lonely) or (c=='not lonely' and lonely) then return false end
  end
  return true
 end
 for id=1,3 do
  local expected=0
  for _,entry in ipairs(env.features) do local rule=entry[1]
   if rule[1]==w.entities[id].archetype and rule[2]=='has' and rule[3]=='flag' and active(entry[2],w.entities[id]) then expected=expected+1 end
  end
  local births,err=RW_PlanHasBirths(w,{id},has);assert(births,err)
  assert(#births==expected,'GROUP MIMIC source mismatch '..checked..':'..id..':'..expected..'/'..#births)
 end
 checked=checked+1
end end end end end end end
assert(checked==1152)
print('PASS: installed addoption/subrules/grouprules GROUP MIMIC raw-copy order, ALL/NOT ALL, empty groups, channels, conditions, duplicate and negative copies ('..checked..' cases)')
