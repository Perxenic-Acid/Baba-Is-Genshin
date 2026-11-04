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
local checked,limited=0,0
-- Execute the actual literal HAS ALL route rather than guessing that a raw
-- ALL declaration is equivalent to another palette of concrete HAS records.
do
 local root=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
 local function read(name)
  local file=assert(io.open(root..name,'rb'));local data=file:read('*a');file:close();return data
 end
 local native=setmetatable({}, {__index=env})
 local tools_source,syntax_source=read('tools.lua'),read('syntax.lua')
 local first=assert(tools_source:find('function findtype(',1,true))
 local last=assert(tools_source:find('function findobstacle(',first,true))
 assert(load(tools_source:sub(first,last-1),'@original_findtype','t',native))()
 first=assert(syntax_source:find('function createall(',1,true))
 last=assert(syntax_source:find('function createall_single(',first,true))
 assert(load(syntax_source:sub(first,last-1),'@original_createall','t',native))()
 first=assert(tools_source:find('function inside(',1,true))
 last=assert(tools_source:find('function animate(',first,true))
 assert(load(tools_source:sub(first,last-1),'@original_inside','t',native))()
 native.UNITNAME,native.UNITTYPE=1,2;native.roomsizex=8
 native.unitmap={[18]={1,2}}
 local units={{strings={'rock','object'}},{strings={'crate','object'}}}
 native.mmf={newObject=function(id) return units[id] end}
 native.testcond=function() return true end
 native.objectlist={all=true,rock=true,crate=true}
 native.unitreference={rock=true,crate=true}
 native.featureindex={rock={{{'rock','has','all'},{}}}}
 local births={};native.create=function(name) births[#births+1]=name end
 native.inside('rock',2,2,0,1)
 assert(#births==0,'literal native HAS ALL must not synthesize another palette')
 native.featureindex.rock[#native.featureindex.rock+1]={{'rock','has','crate'},{}}
 native.inside('rock',2,2,0,1)
 assert(#births==1 and births[1]=='crate','concrete native HAS product must still run')
 print('PASS: installed inside/createall/findtype distinguishes raw HAS ALL from concrete HAS births')
end
for _,declaration_source in ipairs({'crate','all','not rock','not all'}) do
for _,mimic_target in ipairs({'crate','empty','text','all'}) do
for _,mimic_source in ipairs({'rock','not rock'}) do for mimic_ban=0,2 do
for declarations=1,2 do for copies=1,2 do for ban=0,2 do
for declaration_condition=0,1 do for mimic_condition=0,1 do for overlap=0,1 do for all_ban=0,2 do
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
 for i=1,declarations do add(declaration_source,'has','all',declaration_condition) end
 if ban>0 then add(declaration_source,'has','not flag',ban-1) end
 if all_ban>0 then add(declaration_source,'has','not all',all_ban-1) end
 add('crate','has','rock',0)
 for i=1,copies do add(mimic_source,'mimic',mimic_target,mimic_condition) end
 if mimic_ban>0 then add(mimic_source,'mimic','not '..mimic_target,mimic_ban-1) end
 local native_ok,native_error=pcall(env.subrules)
 local generated,deferred,relations=RW_LowerRuleAST(ast,nil,w)
 if not native_ok then
  assert(tostring(native_error):find('toocomplex',1,true),native_error)
  assert(not generated and deferred=='rule_complexity_limit','RHS ALL native limit mismatch '..checked)
  limited=limited+1
 else
 assert(generated and #deferred==0,'RHS ALL unexpected project limit '..checked)
 local has={};for _,relation in ipairs(relations) do if relation.op=='has' then has[#has+1]=relation end end
 local function active(conditions,id)
  local unit=w.entities[id];local lonely=true
  for other_id,other in pairs(w.entities) do if other_id~=id and other.x==unit.x and other.y==unit.y then lonely=false end end
  for _,c in ipairs(conditions) do
   local name=c[1]:gsub('[()]','')
   if name=='never' or name=='lonely' and not lonely or name=='not lonely' and lonely then return false end
  end
  return true
 end
 for id=1,(overlap==1 and 3 or 2) do
  local products,denied={},false
  for _,row in ipairs(env.features) do local r=row[1]
   if r[1]==(w.entities[id].class=='text' and 'text' or w.entities[id].archetype) and r[2]=='has' and active(row[2],id) then
    local ordinary=false;for _,name in ipairs(RW_NounPalette(w)) do if r[3]==name then ordinary=true end end
    if ordinary then products[#products+1]=r[3] elseif r[3]=='not flag' then denied=true end
   end
  end
  local expected={};for _,name in ipairs(products) do if name~='flag' or not denied then expected[#expected+1]=name end end
  local births,err=RW_PlanHasBirths(w,{id},has);assert(births,err)
  assert(#births==#expected,'ALL before MIMIC mismatch '..checked..':'..id..':'..#births..'/'..#expected)
  local counts={};for _,name in ipairs(expected) do counts[name]=(counts[name] or 0)+1 end
  for _,birth in ipairs(births) do counts[birth.archetype]=(counts[birth.archetype] or 0)-1 end
  for _,count in pairs(counts) do assert(count==0,'RHS ALL MIMIC multiplicity mismatch '..checked) end

 end
 end
 checked=checked+1
end end end end end end end end end end end
print('PASS: installed pre-MIMIC RHS ALL expansion, raw literals, dual axes, NOT subjects, conditional bans and per-imitator HAS products ('..checked..' cases, '..limited..' native-limit cases)')
