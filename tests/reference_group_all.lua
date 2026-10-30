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
local checked=0
for _,mixed in ipairs({false,true}) do for channel=1,3 do for _,inverse in ipairs({false,true}) do for ban=0,2 do
for _,conditional in ipairs({false,true}) do for copies=1,2 do
for _,rhs in ipairs({false,true}) do for _,transfer in ipairs({false,true}) do
 local name=channel==1 and 'group' or 'group'..channel
 local w=RW_CreateSession().world;w.entities={};w.width=20;w.height=20
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 for id,kind in ipairs({'rock','flag','avatar'}) do w.entities[id]={id=id,kind='object',class='object',archetype=kind,x=id*4,y=3,direction='Right'} end
 w.entities[4]={id=4,kind='object',class='text',text={name='IS'},x=4,y=3,direction='None'}
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true};for _,kind in ipairs(RW_NounPalette(w)) do env.objectlist[kind]=true end
 local ast={}
 local function add(subject,verb,object,condition,rawsubject,rawobject,rawconds)
  ast[#ast+1]={subject=subject,verb=verb,object=object,when=condition}
  env.addoption({rawsubject,verb,rawobject},rawconds or {},{},false,nil,{})
 end
 if mixed then add({tag='not',operand={tag='special',name='all'}},'is',{tag='not',operand={tag='property',name='float'}},when(false),'not all','not float') end
 for i=1,copies do add(inverse and {tag='not',operand={tag='special',name='all'}} or {tag='special',name='all'},'is',team(name),when(conditional),(inverse and 'not ' or '')..'all',name,conditional and {{'lonely',{}}} or {}) end
 if ban>0 then add({tag='special',name='all'},'is',{tag='not',operand=team(name)},when(ban==2),'all','not '..name,ban==2 and {{'lonely',{}}} or {}) end
 if transfer then add(team(name),'is',team('group3'),when(false),name,'group3');name='group3' end
 if rhs then add(noun('avatar'),'has',team(name),when(false),'avatar',name)
 else add(team(name),'has',noun('flag'),when(false),name,'flag') end
 env.subrules();env.grouprules()
 local g,d,relations=RW_LowerRuleAST(ast,nil,w);assert(g,'ALL lowering failed');for _,rule in ipairs(d) do assert(rule.subject.tag=='special' and rule.subject.name=='empty','unexpected ALL deferred '..checked) end
 local has={};for _,r in ipairs(relations) do if r.op=='has' then has[#has+1]=r end end;relations=has
 local function active(conditions,entity)
  local lonely=true;for id,e in pairs(w.entities) do if id~=entity.id and e.x==entity.x and e.y==entity.y then lonely=false end end
  for _,clause in ipairs(conditions) do local c=clause[1]:gsub('[()]','')
   if c=='never' or (c=='lonely' and not lonely) or (c=='not lonely' and lonely) then return false end
  end
  return true
 end
 for id=1,3 do
  local expected={}
  for _,entry in ipairs(env.features) do local rule=entry[1]
   if rule[1]==w.entities[id].archetype and rule[2]=='has' and active(entry[2],w.entities[id]) then
    local products=rule[3]=='all' and RW_NounPalette(w) or {rule[3]}
    for _,product in ipairs(products) do if product~='empty' and product:sub(1,5)~='group' then
     if product=='text' then product='text_'..w.entities[id].archetype end
     expected[product]=(expected[product] or 0)+1
    end end
   end
  end
  local births,err=RW_PlanHasBirths(w,{id},relations);assert(births,tostring(checked)..':'..tostring(err))
  local actual={};for _,product in ipairs(births) do
   local key=product.class=='text' and 'text_'..w.entities[id].archetype or product.archetype
   actual[key]=(actual[key] or 0)+1
  end
  for key,count in pairs(expected) do assert(actual[key]==count,'ALL product mismatch '..checked..':'..key..':'..count..'/'..tostring(actual[key])) end
  for key,count in pairs(actual) do assert(expected[key]==count,'unexpected ALL product '..checked..':'..key) end
 end
 checked=checked+1
end end end end end end end end
assert(checked==576)
print('PASS: installed addoption/subrules/grouprules ALL/NOT ALL membership, exclusions, duplicate products, conditions and transfers ('..checked..' cases)')

