-- Installed subrules/grouprules ordering for late scoped EAT consumers.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]],'rb'))
local source=f:read('*a');f:close()
local env=setmetatable({},{__index=_G})
env.copyconds=function(dst,src) for _,v in ipairs(src or {}) do dst[#dst+1]=v end;return dst end
env.concatenate=function(...) local out={};for _,a in ipairs({...}) do for _,v in ipairs(a) do out[#out+1]=v end end;return out end
env.MF_alert=function() end;env.destroylevel=function() error('unexpected recursion') end
env.nlist={short={'group','all','text','empty','level'}}
env.findnoun=function(n)return n=='all' or n=='text' or n=='empty' or n=='level' or n:sub(1,5)=='group' end
env.getmat=function(n)return env.objectlist[n] and n end
local function install(first,last)
 local a=assert(source:find('function '..first..'(',1,true));local b=assert(source:find('function '..last..'(',a,true))
 assert(load(source:sub(a,b-1),'@installed_scoped_eat_'..first,'t',env))()
end
install('addoption','postrules');install('grouprules','copyrule');install('copyrule','comparerules');install('invertconds','rulelog')
local function noun(n) return {tag='noun',type={tag='object',name=n}} end
local level={tag='noun',type={tag='level',block_type='level_block'}}
local checked=0
for channel=1,3 do for copies=1,3 do for _,member in ipairs({'rock','text','empty','all','level'}) do for _,directall in ipairs({false,true}) do
 local name=channel==1 and 'group' or 'group'..channel;local group={tag='noun',type={tag='group',name=name}}
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.entities={}
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true,group=true,group2=true,group3=true}
 for _,n in ipairs(RW_NounPalette(w)) do env.objectlist[n]=true end
 local ast={}
 local function add(s,v,o,rs,ro)
  ast[#ast+1]={subject=s,verb=v,object=o,when={op='always'}};env.addoption({rs,v,ro},{},{},false,nil,{})
 end
 local term=member=='level' and level or (member=='all' or member=='text' or member=='empty') and {tag='special',name=member} or noun(member)
 for i=1,copies do add(term,'is',group,member,name) end
 add(level,'eat',group,'level',name)
 add(level,'is',{tag='property',name='turn'},'level','turn')
 if directall then add(level,'eat',{tag='special',name='all'},'level','all') end
 env.subrules();env.grouprules()
 local g,d=RW_LowerRuleAST(ast,nil,w);assert(g,d);assert(#d==0)
 local rows=RW_LevelMotionDeclarations(w,g);assert(rows)
 local actual={};for _,r in ipairs(rows) do actual[#actual+1]=r.op=='level_eat' and r.relation.target_type or r.trait end
 -- The native objectlist is a hash table; compare ordinary ALL copies as a
 -- multiset, but require both raw GROUP and TURN to precede every derived row.
 local expected={};for _,entry in ipairs(env.features) do local r=entry[1]
  if r[1]=='level' and (r[2]=='eat' or r[2]=='is' and r[3]=='turn') then
   local target=r[3];if target==name then target='@group:'..name elseif target=='text' or target=='empty' or target=='level' or target=='all' then target='@'..target end
   expected[#expected+1]=target
  end
 end
 assert(actual[1]==expected[1] and actual[2]==expected[2] and #actual==#expected,'scoped GROUP/ALL order or count mismatch')
 local counts={};for _,n in ipairs(expected) do counts[n]=(counts[n] or 0)+1 end
 for _,n in ipairs(actual) do assert(counts[n] and counts[n]>0,'unexpected scoped target '..tostring(n));counts[n]=counts[n]-1 end
 checked=checked+1
end end end end
print('PASS: installed subrules/grouprules scoped EAT GROUP and ALL ordering/multiplicity ('..checked..' cases)')

-- Execute original findgroup plus the actual late EAT branch. Conditions use
-- a concrete position predicate to isolate global noun promotion/aggregation.
local function read(name)
 local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]..name,'rb'));local s=f:read('*a');f:close();return s
end
local tools=read('tools.lua');local a=assert(tools:find('function findgroup(',1,true));local b=assert(tools:find('function groupcheck(',a,true))
assert(load(tools:sub(a,b-1),'@installed_eat_findgroup','t',env))()
local blocks=read('blocks.lua');a=assert(blocks:find('if (rule[1] == "level") and testcond(conds,1) then',assert(blocks:find('local levelteledone = 0',1,true)),true))
b=assert(blocks:find('elseif (rule[1] ~= "level") and (rule[3] == "level") then',a,true))
local native=assert(load('return function(rule) local eaten={};local lsafe=map_safe; '..blocks:sub(a,b-1)..' end return eaten end','@installed_group_eat_selection','t',env))()
local selection_cases=0
env.checkeffecthistory=function() return 1,0 end;env.setsoundname=function() end
for copies=1,3 do for _,conditional in ipairs({false,true}) do for _,levelmember in ipairs({false,true}) do
for _,mapsafe in ipairs({false,true}) do for _,safe in ipairs({false,true}) do for _,occupied in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.width,w.height=8,8;w.entities={};w.language.nouns.ROCK='rock'
 w.entities[10]={id=10,kind='object',class='object',archetype='rock',x=1,y=1,direction='Left'}
 w.entities[11]={id=11,kind='object',class='object',archetype='rock',x=5,y=5,direction='Left'}
 w.entities[12]={id=12,kind='object',class='object',archetype='level_block',x=3,y=3,direction='Left'}
 if occupied then w.entities[13]={id=13,kind='object',class='object',archetype='avatar',x=1,y=1,direction='Left'} end
 w.unit_order={11,10,12};if occupied then w.unit_order[4]=13 end
 local lonely={op='spatial',clauses={{relation='lonely',negated=false,parameters={}}}}
 local members={};env.groupmembers={};env.unitlists={rock={11,10},level={12}}
 for i=1,copies do
  members[#members+1]={name='rock',when=conditional and lonely or {op='always'}}
  env.groupmembers[#env.groupmembers+1]={'rock',conditional and {{'lonely',{}}} or {},'group',false}
 end
 if levelmember then members[#members+1]={name='@level',when={op='always'}};env.groupmembers[#env.groupmembers+1]={'level',{},'group',false} end
 local rules={{when={op='always'},effects={},group_members={group=members}}}
 if safe then rules[#rules+1]={when={op='always'},effects={{op='grant_trait',trait='safe',target={kind='id',value=11}}}} end
 env.map_safe=mapsafe;env.XPOS=1;env.YPOS=2
 env.mmf={newObject=function(id)local e=w.entities[id];return {values={e.x,e.y}} end}
 env.testcond=function(conds,id)
  if id==1 or #conds==0 then return true end
  local e=w.entities[id];for other,o in pairs(w.entities) do if other~=id and e.x==o.x and e.y==o.y then return false end end
  return true
 end
 env.issafe=function(id)return safe and id==11 end
 local destroyed=false;env.destroylevel=function()destroyed=true end
 local ids=native({'level','eat','group'}) or {};local unique,expected={},{}
 for _,id in ipairs(ids) do if not unique[id] then unique[id]=true;expected[#expected+1]=id end end
 local actual,why=RW_ResolveScopedEatTargets(w,rules,{target_type='@group:group',when={op='always'}},mapsafe);assert(actual,why)
 assert((actual.level_destroy==true)==destroyed and #actual.ids==#expected,'GROUP selection/retirement mismatch')
 for i,id in ipairs(expected) do assert(actual.ids[i]==id,'GROUP first member/identity order mismatch') end
 selection_cases=selection_cases+1
end end end end end end
print('PASS: installed findgroup and LEVEL EAT aggregation/conditional promotion/SAFE/LEVEL ('..selection_cases..' cases)')

-- MIMIC must copy the native pre-expanded ALL palette once, rather than
-- re-expanding the additional runtime-only scoped copies in its lookup.
local mimic_cases=0
for _,outgoing in ipairs({false,true}) do for copies=1,3 do for _,ban in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.entities={}
 env.features={};env.featureindex={};env.visualfeatures={};env.notfeatures={};env.condfeatureindex={};env.groupfeatures={}
 env.objectlist={all=true,text=true,empty=true,level=true,group=true};for _,n in ipairs(RW_NounPalette(w)) do env.objectlist[n]=true end
 local ast={};local owner=outgoing and level or noun('rock');local receiver=outgoing and noun('rock') or level
 local ownername=outgoing and 'level' or 'rock';local receivername=outgoing and 'rock' or 'level'
 local function add(s,v,o,rs,ro)
  ast[#ast+1]={subject=s,verb=v,object=o,when={op='always'}};env.addoption({rs,v,ro},{},{},false,nil,{})
 end
 for i=1,copies do add(owner,'eat',{tag='special',name='all'},ownername,'all') end
 if ban then add(owner,'eat',{tag='not',operand={tag='special',name='all'}},ownername,'not all') end
 add(receiver,'mimic',owner,receivername,ownername)
 env.subrules();env.grouprules()
 local g,d,r=RW_LowerRuleAST(ast,nil,w);assert(g,d);assert(#d==0)
 local actual={}
 if outgoing then for _,row in ipairs(r) do if row.op=='eat' and row.source_type=='rock' and RW_RelationApplies(w,row,{id=10,class='object',archetype='rock',x=1,y=1,direction='Right'}) then actual[row.target_type]=(actual[row.target_type] or 0)+1 end end
 else for _,row in ipairs(RW_LevelMotionDeclarations(w,g) or {}) do if row.op=='level_eat' and row.relation.target_type~='@all' and RW_RelationApplies(w,row.relation,{id=0,class='level',x=0,y=0,direction='None'}) then local n=row.relation.target_type;actual[n]=(actual[n] or 0)+1 end end end
 local expected={}
 for _,entry in ipairs(env.features) do local rule=entry[1]
  if rule[1]==receivername and rule[2]=='eat' and rule[3]:sub(1,4)~='not ' and not env.findnoun(rule[3]) then
   local active=true;for _,c in ipairs(entry[2]) do if c[1]=='never' then active=false end end
   if active then expected[rule[3]]=(expected[rule[3]] or 0)+1 end
  end
 end
 for n,count in pairs(expected) do assert(actual[n]==count,'scoped ALL MIMIC multiplicity '..n..':'..count..'/'..tostring(actual[n])) end
 for n,count in pairs(actual) do assert(expected[n]==count,'unexpected scoped ALL MIMIC target '..n..':'..tostring(outgoing)..':'..tostring(ban)..':'..count) end
 mimic_cases=mimic_cases+1
end end end
print('PASS: installed subrules scoped ALL EAT MIMIC in both directions, duplicates and NOT ALL ('..mimic_cases..' cases)')
