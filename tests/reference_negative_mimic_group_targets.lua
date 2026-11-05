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
local function term(raw)
 if raw:sub(1,4)=='not ' then return {tag='not',operand=term(raw:sub(5))} end
 if raw=='all' or raw=='text' or raw=='empty' then return {tag='special',name=raw} end
 if raw=='level' then return {tag='noun',type={tag='level',block_type='level_block'}} end
 return raw:sub(1,5)=='group' and team(raw) or noun(raw)
end
local checked=0
for channel=1,3 do for membership=0,3 do
for _,sub in ipairs({'not rock','not text','not empty','not level','not all','not group'}) do
for _,denied in ipairs({false,true}) do for copies=1,2 do for _,conditional in ipairs({false,true}) do
 local name=channel==1 and 'group' or 'group'..channel
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={
  [1]={id=1,kind='object',class='object',archetype='rock',x=4,y=3,direction='Right'},
  [2]={id=2,kind='object',class='object',archetype='avatar',x=8,y=3,direction='Left'},
  [3]={id=3,kind='object',class='text',text={name='IS'},x=4,y=3,direction='None'}}
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true,group=true,group2=true,group3=true}
 for _,kind in ipairs(RW_NounPalette(w))do env.objectlist[kind]=true end
 local ast={};local function add(s,v,o,c)
  ast[#ast+1]={subject=term(s),verb=v,object=term(o),when=when(c)}
  env.addoption({s,v,o},c and {{'lonely',{}}} or {},{},false,nil,{})
 end
 if membership>0 then add(membership==1 and 'rock' or membership==2 and 'all' or 'not all','is',name,false) end
 add('avatar','has','flag',false);add(name,'has','flag',conditional)
 add('rock','mimic','avatar',false)
 for i=1,copies do add(sub=='not group' and 'not '..name or sub,'mimic',(denied and 'not ' or '')..name,conditional) end
 env.subrules()
 local copied=0
 for _,row in ipairs(env.features)do for _,tag in ipairs(row[4] or {})do if tag=='mimic' then copied=copied+1 end end end
 -- ALL membership also gives AVATAR IS GROUP to the independent imitator.
 assert(copied==(membership==2 and 2 or 1)+(sub=='not all' and not denied and 2*copies or 0),
  'installed GROUP target immediate-expansion exception '..checked)
 env.grouprules()
 local generated,deferred,relations=RW_LowerRuleAST(ast,nil,w);assert(generated)
 for _,rule in ipairs(deferred)do
  assert(rule.verb~='mimic' and rule.subject.tag=='special' and rule.subject.name=='empty',
   'native inert negative MIMIC/GROUP target remains deferred '..checked..':'..sub)
 end
 local has={};for _,r in ipairs(relations)do if r.op=='has' then has[#has+1]=r end end
 for id,unit in ipairs(w.entities)do
  local lonely=true;for other_id,e in pairs(w.entities)do if id~=other_id and e.x==unit.x and e.y==unit.y then lonely=false end end
  local expected=0
  for _,row in ipairs(env.features)do local r=row[1]
   if r[1]==(unit.class=='text' and 'text' or unit.archetype) and r[2]=='has' and r[3]=='flag' then
    local active=true;for _,c in ipairs(row[2])do local n=c[1]:gsub('[()]','')
     if n=='never' or n=='lonely' and not lonely or n=='not lonely' and lonely then active=false end
    end
    if active then expected=expected+1 end
   end
  end
  local births=assert(RW_PlanHasBirths(w,{id},has))
  assert(#births==expected,'negative MIMIC GROUP target product mismatch '..checked..':'..id..':'..#births..'/'..expected)
 end
 checked=checked+1
end end end end end end
assert(checked==576)
print('PASS: installed negative MIMIC GROUP targets, ordinary/Text/Empty/LEVEL/ALL/NOT GROUP subjects, controls, protections and per-identity HAS ('..checked..' cases)')
