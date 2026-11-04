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
local function cond(mode)
 return mode==0 and {op='always'} or {op='spatial',clauses={{relation='lonely',negated=mode==2,parameters={}}}}
end
local checked=0
for _,declaration_source in ipairs({'all','not rock','not crate','not all'}) do
for _,mimic_target in ipairs({'crate','empty','text'}) do
for declarations=1,2 do for copies=1,2 do for ban=0,2 do
for declaration_condition=0,2 do for mimic_condition=0,2 do for overlap=0,1 do
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={[1]={id=1,class='object',kind='object',archetype='rock',x=4,y=3,direction='Right'},
 [2]={id=2,class='object',kind='object',archetype='crate',x=8,y=3,direction='Right'}}
 if overlap==1 then w.entities[3]={id=3,class='text',kind='object',text={name='IS'},x=4,y=3,direction='None'} end
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true};for _,name in ipairs(RW_NounPalette(w)) do env.objectlist[name]=true end
 local ast={}
 local function add(sub,verb,obj,mode)
  ast[#ast+1]={subject=term(sub),verb=verb,object=term(obj),when=cond(mode)}
  env.addoption({sub,verb,obj},mode==0 and {} or {{mode==1 and 'lonely' or 'not lonely',{}}},{},false,nil,{})
 end
 for i=1,declarations do add(declaration_source,'has','flag',declaration_condition) end
 if ban>0 then add(declaration_source,'has','not flag',ban-1) end
 add('crate','has','rock',0)
 for i=1,copies do add('rock','mimic',mimic_target,mimic_condition) end
 env.subrules()
 local _,deferred,relations=RW_LowerRuleAST(ast,nil,w);assert(#deferred==0)
 local has={};for _,relation in ipairs(relations) do if relation.op=='has' then has[#has+1]=relation end end
 local function active(conditions,id)
  local lonely=id~=1 or overlap==0
  for _,c in ipairs(conditions) do
   local name=c[1]:gsub('[()]','')
   if name=='never' or name=='lonely' and not lonely or name=='not lonely' and lonely then return false end
  end
  return true
 end
 for id=1,2 do
  local products,denied={},false
  for _,row in ipairs(env.features) do local r=row[1]
   if r[1]==w.entities[id].archetype and r[2]=='has' and active(row[2],id) then
    if r[3]=='flag' or r[3]=='rock' then products[#products+1]=r[3] elseif r[3]=='not flag' then denied=true end
   end
  end
  local expected={};for _,name in ipairs(products) do if name~='flag' or not denied then expected[#expected+1]=name end end
  local births,err=RW_PlanHasBirths(w,{id},has);assert(births,err)
  assert(#births==#expected,'ALL before MIMIC mismatch '..checked..':'..id..':'..#births..'/'..#expected)
  if id==1 then for index,name in ipairs(expected) do
   assert(births[index].archetype==name,'MIMIC target declaration order mismatch '..checked..':'..index)
  end end
 end
 checked=checked+1
end end end end end end end end
print('PASS: installed ALL/NOT noun/NOT ALL expansion before MIMIC, ordinary/EMPTY/Text targets, HAS duplicates/bans, per-imitator LONELY and base multiplicity ('..checked..' cases)')
