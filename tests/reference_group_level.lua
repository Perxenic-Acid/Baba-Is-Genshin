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

local level={tag='noun',type={tag='level',block_type='level_block'}}
local checked=0
for channel=1,3 do for copies=0,2 do for ban=0,1 do for _,transfer in ipairs({false,true}) do
for _,target in ipairs({'win','defeat','rock','text'}) do
 local w=RW_CreateSession().world;w.entities={};w.width=20;w.height=20
 env.groupfeatures={};env.objectlist={avatar=true,rock=true};local ast={};local captured={}
 env.addoption=function(rule,conds) captured[#captured+1]={rule,conds} end
 local name=channel==1 and 'group' or 'group'..channel
 local function add(subject,object,rawsubject,rawobject)
  ast[#ast+1]={subject=subject,verb='is',object=object,when={op='always'}}
  env.groupfeatures[#env.groupfeatures+1]={{rawsubject,'is',rawobject},{},{},{}}
 end
 for i=1,copies do add(level,team(name),'level',name) end
 if ban==1 then add(level,{tag='not',operand=team(name)},'level','not '..name) end
 if transfer then add(team(name),team('group3'),name,'group3');name='group3' end
 local object=(target=='win' or target=='defeat') and {tag='property',name=target} or target=='text' and {tag='special',name='text'} or noun(target)
 add(team(name),object,name,target);env.grouprules()
 local generated,deferred,relations=RW_LowerRuleAST(ast,nil,w);assert(generated and #deferred==0)
 local expected=0;for _,e in ipairs(captured) do if e[1][1]=='level' and e[1][3]==target then expected=expected+1 end end
 local actual=0;for _,r in ipairs(relations) do
  if ((target=='win' or target=='defeat') and r.op=='level_trait' and r.trait==target)
   or ((target=='rock' or target=='text') and r.op=='transform_level' and r.target_type==(target=='text' and 'text_level' or target)) then actual=actual+1 end
 end
 assert(actual==expected,'scoped LEVEL group mismatch '..checked)
 checked=checked+1
end end end end end
assert(checked==144)
print('PASS: installed scoped LEVEL membership, exclusions, channels/transfers and terminal/conversion declarations ('..checked..' cases)')
