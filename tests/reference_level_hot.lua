-- Execute the installed LEVEL HOT branch, including repeated MELT declarations.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({XPOS=1,YPOS=2,SHAKE=1,generaldata={values={}},MF_particles=function()end,
 checkeffecthistory=function()return 1,0 end,setsoundname=function()end},{__index=_G})
local source=read('blocks.lua');local a=assert(source:find('elseif (action == "hot") then',1,true));local b=assert(source:find('elseif (action == "melt") then',a,true))
local native=assert(load('return function()local action="hot"; if false then '..source:sub(a,b-1)..' end end','@installed_level_hot','t',env))()
local function noun(n)return {tag='noun',type={tag='object',name=n}} end
local cases=0
for mask=0,7 do for floats=0,7 do for safes=0,3 do for copies=1,3 do for _,mapfloat in ipairs({false,true}) do for _,has in ipairs({false,true}) do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.width,w.height=8,8;w.next_entity_id=20;w.unit_order={};w.rule_sources={}
 local units,order={},{};local frontier=20
 for index=0,2 do if math.floor(mask/2^index)%2==1 then
  local id=index+10;local floating=math.floor(floats/2^index)%2==1;local safe=math.floor(safes/2^(index%2))%2==1
  w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=index+1,y=1,direction='Right'}
  w.unit_order[#w.unit_order+1]=id;units[id]={values={index+1,1},float=floating,safe=safe};order[#order+1]=id
  for _,trait in ipairs({'float','safe'}) do if trait=='float' and floating or trait=='safe' and safe then
   w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait=trait,target={kind='id',value=id}}}}
  end end
 end end
 local ast={};for i=1,copies do ast[#ast+1]={subject=noun('rock'),verb='is',object={tag='property',name='melt'},when={op='always'}} end
 if has then ast[#ast+1]={subject=noun('rock'),verb='has',object=noun('rock'),when={op='always'}} end
 local rules,deferred,relations=RW_LowerRuleAST(ast,nil,w);assert(rules and #deferred==0)
 if mapfloat then rules[#rules+1]={when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='float',when={op='always'}}}} end
 env.findfeature=function()local rows={};for i=1,copies do rows[i]={'rock',{}} end;return rows end
 env.findall=function()local ids={};for _,id in ipairs(order) do if units[id] then ids[#ids+1]=id end end;return ids end
 env.issafe=function(id)return units[id].safe end;env.floating_level=function(id)return units[id].float==mapfloat end
 env.mmf={newObject=function(id)return units[id] end}
 env.delete=function(id)
  local old=units[id];units[id]=nil
  if has then units[frontier]={values={old.values[1],old.values[2]},float=false,safe=false};order[#order+1]=frontier;frontier=frontier+1 end
 end
 native()
 local current=w
 for _,declaration in ipairs(RW_LevelHotDeclarations(w,rules)) do
  local effects=assert(RW_EvaluateRules(current,rules));local projected=assert(RW_ProjectWorld(current,effects,mapfloat and {'float'} or {}))
  local ids=assert(RW_LevelHotTargets(projected,rules,declaration));local layers={}
  for _,id in ipairs(ids) do layers[id]=projected.entities[id].behaviors.float==true end
  local phase=assert(RW_PlanDestructionPhase(current,ids,relations,'level_hot',{
   initialized_births=function(a,b,c,d,n)return RW_InitializeHasBirths(a,b,c,d,n,false,{kind='level_hot',layers=layers}) end,
   create=RW_PlanCreate,delete=RW_PlanDelete},nil,rules))
  current=assert(RW_PreviewPlan(current,phase))
 end
 assert(current.next_entity_id==frontier,'HOT duplicate HAS allocator mismatch')
 for id,e in pairs(current.entities) do assert(units[id] and e.x==units[id].values[1] and e.y==units[id].values[2],'unexpected HOT survivor/product') end
 for id in pairs(units) do assert(current.entities[id],'missing HOT survivor/product') end
 cases=cases+1
end end end end end end
print('PASS: installed LEVEL HOT serial destruction, duplicate MELT/HAS, SAFE/FLOAT and identities/allocator ('..cases..' cases)')

-- Serial eligibility limits keep prior deaths/births and retain the triggering
-- candidate. A skipped SAFE victim consumes no inside() facing draw.
do
 local session=RW_CreateSession();local w=session.world;w.entities={};w.next_entity_id=20
 for _,id in ipairs({10,11}) do w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=id-9,y=1,direction='None'} end
 local _,_,contents=RW_LowerRuleAST({{subject=noun('rock'),verb='has',object=noun('flag'),when={op='always'}}},nil,w)
 local marker={op='spatial',clauses={},hot_eligibility_marker=true}
 local rules={{when=marker,effects={{op='grant_trait',trait='safe',target={kind='id',value=11}}}}}
 local original=RW_TestEntityCondition
 for _,reason in ipairs({'word_rule_limit','rule_complexity_limit','invalid_hot_eligibility'}) do
  RW_TestEntityCondition=function(world,c,e)if c.hot_eligibility_marker then return nil,reason end;return original(world,c,e) end
  local ok,p,why=pcall(RW_PlanDestructionPhase,w,{10,11},contents,'level_hot',{
   initialized_births=function(a,b,c,d,n)return RW_InitializeHasBirths(a,b,c,d,n,false,{kind='level_hot',layers={}}) end,
   create=RW_PlanCreate,delete=RW_PlanDelete},nil,rules)
  RW_TestEntityCondition=original;assert(ok,p)
  if reason=='invalid_hot_eligibility' then assert(not p and why==reason)
  else
   assert(p.random_state.to==48271 and #p.events==1 and p.events[1].entity_id==10)
   assert(reason=='word_rule_limit' and p.infinite_loop or reason=='rule_complexity_limit' and p.too_complex)
   local n,result=RW_Commit(session,p);assert(result.accepted,result.reason)
   assert(not n.world.entities[10] and n.world.entities[11] and n.world.entities[20].archetype=='flag')
   assert(RW_Undo(n).world==w)
  end
 end
 local p=assert(RW_PlanDestructionPhase(w,{11},contents,'level_hot',{
  initialized_births=function(a,b,c,d,n)return RW_InitializeHasBirths(a,b,c,d,n,false,{kind='level_hot',layers={}}) end,
  create=RW_PlanCreate,delete=RW_PlanDelete},nil,{{when={op='always'},effects={{op='grant_trait',trait='safe',target={kind='id',value=11}}}}}))
 assert(#p.changes==0 and not p.random_state and #p.events==0)
end
print('PASS: HOT serial eligibility terminal prefixes, RNG, skipped victims, ordinary atomic rejection and Undo')

-- Native findall tests only the current declaration. A later positive MELT
-- condition must not execute while selecting the earlier unconditional group.
do
 local w=RW_CreateSession().world;w.entities={[10]={id=10,kind='object',class='object',archetype='rock',x=1,y=1,direction='Right'}};w.unit_order={10};w.next_entity_id=20
 local target={kind='archetype',value='rock'}
 local late={op='spatial',clauses={},late_melt_marker=true}
 local tools=read('tools.lua');local first=assert(tools:find('function findall(',1,true));local last=assert(tools:find('\nfunction ',first+1,true))
 local native_calls=0
 local native_env=setmetatable({unitlists={rock={10}},mmf={newObject=function()return {broken=0} end},getname=function()return 'rock' end,
  testcond=function(c)if c==late then native_calls=native_calls+1;error('word_rule_limit') end;return true end},{__index=_G})
 assert(load(tools:sub(first,last-1),'@installed_hot_single_findall','t',native_env))()
 assert(#native_env.findall({'rock',{}})==1)
 native_env.unitlists.rock={};assert(#native_env.findall({'rock',late})==0 and native_calls==0)
 local rules={{when={op='always'},effects={{op='grant_trait',trait='melt',target=target}}},
  {when=late,effects={{op='grant_trait',trait='melt',target=target}}}}
 local original=RW_TestEntityCondition;local calls=0
 RW_TestEntityCondition=function(world,c,e)
  if c.late_melt_marker then calls=calls+1;return nil,'word_rule_limit' end
  return original(world,c,e)
 end
 local declarations=RW_LevelHotDeclarations(w,rules)
 local ok,ids,why=pcall(RW_LevelHotTargets,w,rules,declarations[1])
 RW_TestEntityCondition=original;assert(ok,ids)
 assert(ids and #ids==1 and ids[1]==10 and calls==0,'earlier MELT group evaluated a later positive declaration: '..tostring(why))
 local once={op='spatial',clauses={},first_melt_marker=true};rules[1].when=once
 local first_calls=0
 RW_TestEntityCondition=function(world,c,e)
  if c.first_melt_marker then first_calls=first_calls+1;return true end
  if c.late_melt_marker then error('later positive queried') end
  return original(world,c,e)
 end
 local ok,ids=pcall(RW_LevelHotTargets,w,rules,RW_LevelHotDeclarations(w,rules)[1])
 RW_TestEntityCondition=original;assert(ok,ids);assert(#ids==1 and first_calls==1,'current MELT declaration queried more than once')
 -- Negative declarations still protect the same current group.
 rules[#rules+1]={when={op='always'},effects={{op='deny_trait',trait='melt',target=target}}}
 assert(#assert(RW_LevelHotTargets(w,rules,declarations[1]))==0)
end
print('PASS: HOT MELT selection isolates positive declarations while retaining negative protection')
