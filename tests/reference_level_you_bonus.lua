-- Installed LEVEL YOU's serial BONUS scan (not ordinary local BONUS pickup).
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local f=assert(io.open(base..'blocks.lua','rb'));local source=f:read('*a');f:close()
local start=assert(source:find('function levelblock()',1,true))
local a=assert(source:find('if (bonus ~= nil) then',start,true))
local b=assert(source:find('if (#findallfeature("empty","is","win")',a,true))
local env=setmetatable({XPOS=1,YPOS=2,SHAKE=1,generaldata={values={}},
 checkeffecthistory=function()return 1,0 end,setsoundname=function()end,MF_particles=function()end,MF_playsound=function()end},{__index=_G})
local native=assert(load('return function(bonus)local canbonus=false;'..source:sub(a,b-1)..';return canbonus end','@installed_level_you_bonus','t',env))()
local function noun(n)return {tag='noun',type={tag='object',name=n}} end
local cases=0
for mask=0,7 do for floats=0,7 do for safes=0,3 do for copies=1,3 do
for _,mapfloat in ipairs({false,true}) do for _,has in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.entities={};w.unit_order={};w.rule_sources={};w.next_entity_id=20
 local units,order={},{};local frontier=20;local deaths=0
 for i=0,2 do if math.floor(mask/2^i)%2==1 then
  local id=10+i;local floating=math.floor(floats/2^i)%2==1;local safe=math.floor(safes/2^(i%2))%2==1
  w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=i+1,y=1,direction='Right'};w.unit_order[#w.unit_order+1]=id
  units[id]={values={i+1,1},float=floating,safe=safe};order[#order+1]=id
  for _,trait in ipairs({'float','safe'}) do if trait=='float' and floating or trait=='safe' and safe then
   w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait=trait,target={kind='id',value=id}}}}
  end end
 end end
 local ast={};local declarations={}
 for i=1,copies do ast[#ast+1]={subject=noun('rock'),verb='is',object={tag='property',name='bonus'},when={op='always'}};declarations[i]={'rock',{}} end
 if has then ast[#ast+1]={subject=noun('rock'),verb='has',object=noun('rock'),when={op='always'}} end
 local rules,_,contents=RW_LowerRuleAST(ast,nil,w);assert(rules)
 if mapfloat then rules[#rules+1]={when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='float',when={op='always'}}}} end
 env.findall=function()local ids={};for _,id in ipairs(order) do if units[id] then ids[#ids+1]=id end end;return ids end
 env.issafe=function(id)return units[id].safe end;env.floating_level=function(id)return units[id].float==mapfloat end
 env.mmf={newObject=function(id)return units[id] end}
 env.delete=function(id)
  local old=units[id];units[id]=nil;deaths=deaths+1
  if has then units[frontier]={values={old.values[1],old.values[2]},float=false,safe=false};order[#order+1]=frontier;frontier=frontier+1 end
 end
 local reward=native(declarations)
 local current=w;local removed=0
 for _,declaration in ipairs(RW_LevelContactDeclarations(w,rules,'bonus')) do
  local effective=assert(RW_ProjectWorld(current,assert(RW_EvaluateRules(current,rules)),mapfloat and {'float'} or {}))
  local ids=assert(RW_LevelContactTargets(effective,rules,declaration,'bonus'));local layers={}
  for _,id in ipairs(ids) do layers[id]=(effective.entities[id].behaviors or {}).float==true end
  local phase=assert(RW_PlanDestructionPhase(current,ids,contents,'level_you_bonus',{
   initialized_births=function(a,b,c,d,n)return RW_InitializeHasBirths(a,b,c,d,n,false,{kind='level_you_bonus',layers=layers}) end,
   create=RW_PlanCreate,delete=RW_PlanDelete},nil,rules))
  removed=removed+#phase.events;current=assert(RW_PreviewPlan(current,phase))
 end
 assert(reward==(removed>0) and removed==deaths and current.next_entity_id==frontier,'LEVEL YOU BONUS serial destruction/reward contract')
 for id,e in pairs(current.entities) do assert(units[id] and e.x==units[id].values[1] and e.y==units[id].values[2]) end
 for id in pairs(units) do assert(current.entities[id]) end
 cases=cases+1
end end end end end end
print('PASS: installed LEVEL YOU serial BONUS selection, independent SAFE/FLOAT, duplicate groups and HAS newborns ('..cases..' cases)')
do
 local session=RW_CreateSession();local w=session.world;w.entities={};w.next_entity_id=20
 for _,id in ipairs({10,11}) do w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=id-9,y=1,direction='Right'} end
 local _,_,contents=RW_LowerRuleAST({{subject=noun('rock'),verb='has',object=noun('flag'),when={op='always'}}},nil,w)
 local marker={op='spatial',clauses={},you_bonus_safe_marker=true}
 local rules={{when=marker,effects={{op='grant_trait',trait='safe',target={kind='id',value=11}}}}}
 local original=RW_TestEntityCondition
 for _,reason in ipairs({'word_rule_limit','rule_complexity_limit','invalid_you_bonus_safe'}) do
  RW_TestEntityCondition=function(world,c,e)if c.you_bonus_safe_marker then return nil,reason end;return original(world,c,e) end
  local p,why=RW_PlanDestructionPhase(w,{10,11},contents,'level_you_bonus',{
   initialized_births=function(a,b,c,d,n)return RW_InitializeHasBirths(a,b,c,d,n,false,{kind='level_you_bonus',layers={}}) end,
   create=RW_PlanCreate,delete=RW_PlanDelete},nil,rules)
  RW_TestEntityCondition=original
  if reason=='invalid_you_bonus_safe' then assert(not p and why==reason)
  else
   local n,r=RW_Commit(session,p);assert(r.accepted and not n.world.entities[10] and n.world.entities[11] and n.world.entities[20].archetype=='flag')
   assert(#p.events==1 and p.events[1].cause=='level_you_bonus' and not p.bonus_state and RW_Undo(n).world==w,'incomplete LEVEL YOU scan must not issue its final reward')
  end
 end
 print('PASS: LEVEL YOU BONUS serial query limits preserve completed deaths/HAS without early reward; ordinary errors reject atomically')
end
