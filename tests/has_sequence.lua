local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=24,30;w.next_entity_id=10
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={[1]={id=1,kind='object',class='object',archetype='avatar',x=5,y=3,direction='Up'}}
 for y,words in ipairs(rows) do for x,name in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=6+y*2,direction='None'}
 end end
 local f,e=RW_CompileWorld(w,cs);assert(f,e and e.reason);return s,f
end
local function names(products)
 local result={};for _,p in ipairs(products) do result[#result+1]=p.class=='text' and 'text_'..p.text.name or p.archetype end
 return table.concat(result,',')
end
local services={initialized_births=function(w,ids,c,r,n,kind)
 return RW_InitializeHasBirths(w,ids,c,r,n,kind=='weak' or kind=='melt' or kind=='eat') end,
 births=RW_InitializeHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}
local cases={
 {{{'AVATAR','HAS','FLAG'},{'AVATAR','WITHOUT','FLAG','HAS','ROCK'}},'flag'},
 {{{'AVATAR','WITHOUT','FLAG','HAS','ROCK'},{'AVATAR','HAS','FLAG'}},'rock,flag'},
 {{{'AVATAR','HAS','FLAG'},{'AVATAR','ON','FLAG','HAS','ROCK'}},'flag,rock'},
 {{{'AVATAR','HAS','FLAG'},{'AVATAR','HAS','FLAG'},{'AVATAR','WITHOUT','FLAG','HAS','ROCK'}},'flag,flag'},
 {{{'AVATAR','ON','FLAG','HAS','ROCK'},{'AVATAR','HAS','FLAG'}},'flag'},
 {{{'AVATAR','HAS','TEXT'},{'AVATAR','ON','TEXT','HAS','ROCK'}},'text_AVATAR,rock'},
 {{{'AVATAR','HAS','FLAG'},{'AVATAR','ON','FLAG','HAS','ROCK'},{'FLAG','IS','BROKEN'}},'flag,rock'}
}
for _,case in ipairs(cases) do
 local s,f=fixture(case[1]);local p,e,_,completed=RW_InitializeHasBirths(s.world,{1},f.relations,f.rules)
 assert(p,e);assert(names(p)==case[2],names(p)..' expected '..case[2]);assert(#completed==1 and completed[1]==1)
 for _,product in ipairs(p) do assert(product.direction=='Up' and not product.id) end
 assert(s.world.entities[1] and not s.world.entities[s.world.next_entity_id])
 for _,deaths in ipairs({false,{{entity_id=1,x=5,y=3,direction='Up',cause='sink',frame=s.world.entities}}}) do
  local plan,why=RW_PlanDestructionPhase(s.world,{1},f.relations,'sink',services,deaths or nil,f.rules)
  assert(plan,why);local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
  assert(not n.world.entities[1] and n.world.next_entity_id==s.world.next_entity_id+#p)
  assert(RW_Undo(n).world==s.world)
 end
end
-- A completed parent is absent from later parents' conditions; the current
-- parent is still present for newborn status and spatial witnesses.
local s,f=fixture({{'AVATAR','WITHOUT','AVATAR','HAS','FLAG'}})
s.world.entities[2]={id=2,kind='object',class='object',archetype='avatar',x=8,y=3,direction='Left'}
local p,e=RW_InitializeHasBirths(s.world,{1,2},f.relations,f.rules);assert(p,e)
assert(#p==1 and p[1].x==8)
local simultaneous,why=RW_InitializeHasBirths(s.world,{1,2},f.relations,f.rules,nil,true)
assert(simultaneous,why);assert(#simultaneous==0)
s,f=fixture({{'AVATAR','HAS','FLAG'},{'AVATAR','HAS','ROCK'},{'FLAG','ON','AVATAR','IS','BROKEN'}})
p,e=RW_InitializeHasBirths(s.world,{1},f.relations,f.rules);assert(p,e);assert(p[1].broken==1)
-- A query limit before any product still completes earlier empty parents and
-- retains the triggering parent, without guessing boundaries by product count.
s,f=fixture({{'AVATAR','HAS','FLAG'},{'AVATAR','HAS','ROCK'}})
s.world.entities[2]={id=2,kind='object',class='object',archetype='avatar',x=8,y=3,direction='Left'}
local original=RW_RelationApplies
for _,trigger in ipairs({'flag','rock'}) do
for _,kind in ipairs({'sink','melt'}) do
for _,reason in ipairs({'word_rule_limit','rule_complexity_limit','ordinary_error'}) do
 RW_RelationApplies=function(w,r,entity)
  if entity.id==1 then return false end
  if r.product.archetype==trigger then return nil,reason end
  return original(w,r,entity)
 end
 local plan,why=RW_PlanDestructionPhase(s.world,{1,2},f.relations,kind,services,nil,f.rules)
 RW_RelationApplies=original
 if reason=='ordinary_error' then assert(not plan and why==reason)
 else
  assert(plan,why);local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
  assert((n.world.entities[1]~=nil)==(kind=='melt') and n.world.entities[2])
  if trigger=='flag' then assert(n.world.next_entity_id==s.world.next_entity_id)
  else assert(n.world.entities[s.world.next_entity_id].archetype=='flag') end
  assert(reason=='word_rule_limit' and n.world.infinite_loop or reason=='rule_complexity_limit' and n.world.too_complex)
  assert(RW_Undo(n).world==s.world)
 end
end
end
end
print('PASS: sequential real HAS clauses/parents, spatial/global/Text/BROKEN witnesses, exact terminal parent boundaries, movement/contact adapters and Undo')

-- Native inside() draws even without products, once per None-facing parent.
s,f=fixture({{'AVATAR','HAS','FLAG'},{'AVATAR','HAS','ROCK'}})
s.world.random_state=17;s.world.entities[1].direction='None'
s.world.entities[2]={id=2,kind='object',class='object',archetype='avatar',x=8,y=3,direction='None'}
local first=17*48271%2147483647;local second=first*48271%2147483647
local products,why,prefix,completed,rng=RW_InitializeHasBirths(s.world,{1,2},f.relations,f.rules)
assert(products,why);assert(#products==4 and rng.from==17 and rng.to==second)
for i,product in ipairs(products) do assert(product.direction==({'Right','Up','Left','Down'})[(i<=2 and first or second)%4+1]) end
for _,deaths in ipairs({false,{
 {entity_id=1,frame=s.world.entities,cause='weak'},
 {entity_id=2,frame=s.world.entities,cause='weak'}}}) do
 local plan,e=RW_PlanDestructionPhase(s.world,{1,2},f.relations,'sink',services,deaths or nil,f.rules)
 assert(plan,e);assert(plan.random_state.to==second)
 local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
 assert(n.world.random_state==second and RW_Undo(n).world==s.world)
end
products,why,prefix,completed,rng=RW_InitializeHasBirths(s.world,{1,2},{},f.rules)
assert(products,why);assert(#products==0 and rng.to==second)
s.world.entities[1].direction='Mid'
products,why,prefix,completed,rng=RW_InitializeHasBirths(s.world,{1},f.relations,f.rules)
assert(products,why);assert(not rng and products[1].direction=='Mid')
s.world.entities[1].direction='None'
original=RW_RelationApplies
RW_RelationApplies=function(w,r,entity)
 if entity.id==2 and r.product.archetype=='rock' then return nil,'rule_complexity_limit' end
 return original(w,r,entity)
end
local plan,e=RW_PlanDestructionPhase(s.world,{1,2},f.relations,'sink',services,nil,f.rules)
RW_RelationApplies=original
assert(plan,e);local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
assert(n.world.too_complex and n.world.random_state==second and n.world.next_entity_id==s.world.next_entity_id+3)
assert(not n.world.entities[1] and n.world.entities[2] and RW_Undo(n).world==s.world)
assert(s.world.random_state==17)
print('PASS: real HAS None shared/per-parent/random-only orientation, Mid extension, serial death RNG, terminal prefixes and Undo')

-- Unrelated source declarations must never run their conditions at a victim.
s,f=fixture({{'AVATAR','HAS','FLAG'},{'ROCK','HAS','ROCK'},{'TEXT','HAS','ROCK'}})
original=RW_RelationApplies
local unrelated=0
RW_RelationApplies=function(w,r,entity)
 if r.target.kind=='archetype' and r.target.value=='rock' or r.target.kind=='class' and r.target.value=='text' then
  unrelated=unrelated+1;return nil,'rule_complexity_limit'
 end
 return original(w,r,entity)
end
local flat,flat_error=RW_PlanHasBirths(s.world,{1},f.relations)
local stream,stream_error=RW_InitializeHasBirths(s.world,{1},f.relations,f.rules)
RW_RelationApplies=original
assert(flat,flat_error);assert(stream,stream_error)
assert(unrelated==0 and names(flat)=='flag' and names(stream)=='flag')
print('PASS: HAS source matching precedes condition/limit queries for flat and initialized streams')
