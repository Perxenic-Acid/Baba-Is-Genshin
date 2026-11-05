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
for _,declaration_source in ipairs({'crate','all','not rock','not all'}) do
for _,mimic_target in ipairs({'crate','empty','text','all'}) do
for _,mimic_source in ipairs({'all','rock','not rock'}) do for mimic_ban=0,2 do
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
 for i=1,declarations do add(declaration_source,'write','all',declaration_condition) end
 if ban>0 then add(declaration_source,'write','not flag',ban-1) end
 if all_ban>0 then add(declaration_source,'write','not all',all_ban-1) end
 add('crate','write','rock',0)
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
 local has={};for _,relation in ipairs(relations) do if relation.op=='write_text' then has[#has+1]=relation end end
 local function active(conditions,id)
  local unit=w.entities[id];local lonely=true
  for other_id,other in pairs(w.entities) do if other_id~=id and other.x==unit.x and other.y==unit.y then lonely=false end end
  for _,c in ipairs(conditions) do
   local name=c[1]:gsub('[()]','')
   if name=='never' or name=='lonely' and not lonely or name=='not lonely' and lonely then return false end
  end
  return true
 end
 local changes,err,allocation=RW_PlanConversions(w,has);assert(changes,err)
 local projected,why=RW_PreviewPlan(w,{consumes_turn=true,changes=changes,id_allocation=allocation});assert(projected,why)
 for id=1,(overlap==1 and 3 or 2) do
  local expected={}
  for source_id,observer in pairs(w.entities) do if observer.x==w.entities[id].x and observer.y==w.entities[id].y then
  local products,denied={},{}
  for _,row in ipairs(env.features) do local r=row[1]
   if r[1]==(observer.class=='text' and 'text' or observer.archetype) and r[2]=='write' and active(row[2],source_id) then
    local ordinary=false;for _,name in ipairs(RW_NounPalette(w)) do if r[3]==name then ordinary=true end end
    if ordinary or r[3]=='all' then products[#products+1]=r[3] elseif r[3]:sub(1,4)=='not ' then denied[r[3]:sub(5)]=true end
   end
  end
  local issued=0
  for _,name in ipairs(products) do if not denied[name] then expected[#expected+1]=name;issued=issued+1 end end
  if issued==0 then expected[#expected+1]=observer.class=='text' and observer.text.name:lower() or observer.archetype end
  end end
  local actual={}
  for _,unit in pairs(projected.entities) do if unit.x==w.entities[id].x and unit.y==w.entities[id].y then
   -- Compare aggregate products from all overlapping source identities.
   actual[#actual+1]=unit.class=='text' and unit.text.name:lower() or unit.archetype
  end end
   local counts={};for _,name in ipairs(expected) do counts[name]=(counts[name] or 0)+1 end
   for _,name in ipairs(actual) do counts[name]=(counts[name] or 0)-1 end
   for name,count in pairs(counts) do assert(count==0,'WRITE ALL conversion mismatch '..checked..':'..id..':'..name..':'..count) end

 end
 end
 checked=checked+1
 if checked%1000==0 then print('WRITE ALL oracle cases checked: '..checked);io.flush() end
end end end end end end end end end end end
print('PASS: installed WRITE ALL literal/concrete products, MIMIC/NOT/conditions/limits and converted multisets ('..checked..' cases, '..limited..' native-limit cases)')
