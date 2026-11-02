local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
 empty_contacts=function(w,p,r,raw,count)
  return RW_PlanEmptyContactPhase(w,RW_ResolveEmptyContactVictims(p),r,raw,
   {products=RW_PlanEmptyHasBirths,initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate},count) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(traits,extra)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=24,30;w.next_entity_id=10
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.language.nouns.LEVEL={tag='level',block_type='level_block'}
 w.entities={[1]={id=1,kind='object',class='object',archetype='rock',x=6,y=3,direction='Left'}}
 local rows={{'EMPTY','IS','RIGHT'}}
 for _,trait in ipairs(traits) do rows[#rows+1]={'EMPTY','FACING','ROCK','IS',trait} end
 for _,row in ipairs(extra or {{'EMPTY','HAS','FLAG'}}) do rows[#rows+1]=row end
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'}
 end end
 return s
end
local function step(s)
 local plan,e=RW_PlanTurn(s.world,{type='wait'},services);assert(plan,e and e.reason)
 for _,c in ipairs(plan.changes) do assert(c.entity_id>0) end
 local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason);assert(RW_Undo(n).world==s.world)
 for id,entity in pairs(n.world.entities) do assert(id>0 and entity.class~='empty') end
 return n,plan
end
for _,pair in ipairs({{'HOT','MELT'},{'MELT','HOT'},{'OPEN','SHUT'},{'SHUT','OPEN'},{'YOU','DEFEAT'},{'DEFEAT','YOU'}}) do
 local s=fixture(pair);local n=step(s);local born=n.world.entities[s.world.next_entity_id]
 assert(born and born.archetype=='flag' and born.x==5 and born.y==3 and born.direction=='Right')
 assert(n.world.next_entity_id==s.world.next_entity_id+1 and not n.world.random_state)
end
for _,traits in ipairs({{'HOT','MELT','SAFE'},{'HOT'},{'MELT'},{'SINK'},{'WEAK'}}) do
 local s=fixture(traits);local n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id and not n.world.random_state)
end
local s=fixture({'HOT','MELT'},{{'EMPTY','HAS','FLAG'},{'EMPTY','HAS','FLAG'},{'EMPTY','HAS','TEXT'}})
local n,plan=step(s);local id=s.world.next_entity_id
assert(n.world.entities[id].archetype=='flag' and n.world.entities[id+1].archetype=='flag' and n.world.entities[id+2].text.name=='EMPTY')
assert(n.world.next_entity_id==id+3)
s=fixture({'HOT','MELT'},{{'EMPTY','HAS','FLAG'},{'EMPTY','HAS','NOT','FLAG'}});n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id)
s=fixture({'HOT','MELT'},{{'EMPTY','FACING','AVATAR','HAS','FLAG'}});n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id)
s=fixture({'HOT','MELT'},{{'EMPTY','HAS','ALL'}});n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+#RW_NounPalette(s.world))
for _,trait in ipairs({'HOT','DEFEAT','OPEN','SHUT'}) do
 local subject=trait=='HOT' and 'MELT' or trait=='DEFEAT' and 'YOU' or trait=='OPEN' and 'SHUT' or 'OPEN'
 s=fixture({subject},{{'LEVEL','IS',trait},{'EMPTY','HAS','FLAG'}});n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+1,trait..':'..n.world.next_entity_id..':'..s.world.next_entity_id)
 s=fixture({subject,'FLOAT'},{{'LEVEL','IS',trait},{'EMPTY','HAS','FLAG'}});n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id)
end
s=fixture({'HOT','MELT'},{{'EMPTY','HAS','FLAG'},{'FLAG','IS','BROKEN'}});n=step(s);assert(n.world.entities[s.world.next_entity_id].broken==1)
s=fixture({'HOT','MELT'},{{'EMPTY','HAS','FLAG'},{'FLAG','IS','CRASH'}});n=step(s);assert(n.world.infinite_loop)
-- Unset inside() orientation draws once per victim, even without a HAS product.
for _,has in ipairs({false,true}) do
 s=fixture({},{{'EMPTY','NEAR','ROCK','IS','HOT'},{'EMPTY','NEAR','ROCK','IS','MELT'}})
 for id,e in pairs(s.world.entities) do if e.class=='text' and e.y==8 then s.world.entities[id]=nil end end
 if has then
  for x,word in ipairs({'EMPTY','HAS','FLAG'}) do local id=s.world.next_entity_id;s.world.next_entity_id=id+1
   s.world.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=20,direction='None'}
  end
 end
 s.world.random_state=7;n,plan=step(s)
 local seed=7;for i=1,8 do seed=seed*48271%2147483647 end
 assert(n.world.random_state==seed and n.world.next_entity_id==s.world.next_entity_id+(has and 8 or 0))
 local stage;for _,entry in ipairs(plan.stages) do if entry.name=='empty_contact' then stage=entry.plan end end
 assert(stage.random_state.from==7);stage.random_state.from=8
 local same,status=RW_Commit(s,plan);assert(not status.accepted and same==s)
end
print('PASS: EMPTY self/scoped contacts, SAFE/FLOAT, cell HAS duplicates/Text/ALL/NOT/conditions/BROKEN/CRASH, RNG-only plans and whole-tree Undo')-- Earlier virtual HAS births must affect later victims' frozen declarations.
s=fixture({},{{'EMPTY','NEAR','ROCK','IS','HOT'},{'EMPTY','NEAR','ROCK','IS','MELT'},
 {'EMPTY','WITHOUT','FLAG','HAS','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+1)
local first=n.world.entities[s.world.next_entity_id];assert(first.x==5 and first.y==2)
-- Stop at a creation limit before later victim orientation draws or allocation.
s=fixture({});s.world.random_state=7
local calls=0
plan=assert(RW_PlanEmptyContactPhase(s.world,{{x=5,y=2},{x=5,y=3}},
 {{op='empty_has',source_type='@empty',product={kind='object',archetype='flag'}}},{},
 {products=RW_PlanEmptyHasBirths,create=RW_PlanCreate,initialize=function(w,products)
  calls=calls+1;return nil,'word_rule_limit',{products[1]}
 end}))
assert(calls==1 and plan.infinite_loop and plan.random_state.to==7*48271%2147483647 and #plan.changes==1)
local result;n,result=RW_Commit(s,plan);assert(result.accepted and n.world.infinite_loop and RW_Undo(n).world==s.world)
print('PASS: serial EMPTY HAS birth witnesses and terminal prefix retain only triggering cell RNG/allocation with Undo')
