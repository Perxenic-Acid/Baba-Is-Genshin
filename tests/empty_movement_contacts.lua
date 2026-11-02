local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 destroy=function(w,ids,c,k,d,r,n) return RW_PlanDestructionPhase(w,ids,c,k,{
  births=RW_PlanHasBirths,empty_products=RW_PlanEmptyHasBirths,initialize=RW_InitializeBirthSpecifications,
  create=RW_PlanCreate,delete=RW_PlanDelete},d,r,n) end,
 contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(traits,extra)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=20,36;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.next_entity_id=10
 w.entities={[1]={id=1,kind='object',class='object',archetype='avatar',x=4,y=3,direction='Left'},
  [2]={id=2,kind='object',class='object',archetype='rock',x=6,y=3,direction='Up'}}
 local rows={{'AVATAR','IS','YOU'},{'EMPTY','IS','RIGHT'},{'EMPTY','HAS','FLAG'}}
 for _,trait in ipairs(traits) do rows[#rows+1]={'EMPTY','FACING','ROCK','IS',trait} end
 for _,row in ipairs(extra or {}) do rows[#rows+1]=row end
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'}
 end end
 return s
end
local function run(s,action)
 local p,e=RW_PlanTurn(s.world,action or {type='move',dx=1,dy=0},services);assert(p,e and e.reason)
 for _,op in ipairs(p.changes) do assert(type(op.entity_id)=='number' and op.entity_id>0) end
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world)
 assert(not n.world.empty_deleted)
 return n,p
end
for _,traits in ipairs({{'WEAK'},{'WEAK','STOP'},{'WEAK','PUSH','STILL'},{'WEAK','PULL','SWAP'}}) do
 local s=fixture(traits);local n,p=run(s);local born=n.world.entities[s.world.next_entity_id]
 assert(n.world.entities[1].x==5 and born and born.archetype=='flag' and born.x==5 and born.y==3 and born.direction=='Right')
 assert(n.world.next_entity_id==s.world.next_entity_id+1)
end
for _,traits in ipairs({{'WEAK','SAFE','STOP'},{'WEAK','FLOAT','STOP'}}) do
 local s=fixture(traits);local n=run(s);assert(n.world.entities[1].x==4 and n.world.next_entity_id==s.world.next_entity_id)
end
local s=fixture({'WEAK','FLOAT','STOP'},{{'AVATAR','IS','FLOAT'}});local n=run(s);assert(n.world.entities[s.world.next_entity_id])
s=fixture({'WEAK','STOP'},{{'AVATAR','IS','PHANTOM'}});n=run(s);assert(n.world.entities[1].x==5 and n.world.next_entity_id==s.world.next_entity_id)
-- Death-frame HAS conditions observe the old empty cell before the mover enters it.
s=fixture({'WEAK','STOP'},{{'EMPTY','ON','AVATAR','HAS','TEXT'},{'EMPTY','NEAR','AVATAR','HAS','ROCK'}})
n=run(s);assert(n.world.next_entity_id==s.world.next_entity_id+2)
for id=s.world.next_entity_id,n.world.next_entity_id-1 do assert(n.world.entities[id].class~='text') end
-- Newborn status/terminal propagation and allocator/RNG-only effects are atomic.
s=fixture({'WEAK'},{{'FLAG','IS','BROKEN'}});n=run(s);assert(n.world.entities[s.world.next_entity_id].broken==1)
s=fixture({'WEAK'},{{'FLAG','IS','CRASH'}});n=run(s);assert(n.world.infinite_loop)
print('PASS: movement EMPTY WEAK permeability, real-only cell HAS, SAFE/FLOAT/PHANTOM, source frames, status/CRASH, positive transactions and Undo')

-- The shared solver's automatic/FALL phases preserve virtual death records.
services.automatic=RW_ResolveAutomatic
s=fixture({'WEAK','STOP'},{{'AVATAR','IS','MOVE'}});s.world.entities[1].direction='Right'
n=run(s,{type='wait'});assert(n.world.entities[1].x==5 and n.world.entities[s.world.next_entity_id])
services.automatic=nil;services.fall=RW_ResolveFall
s=fixture({'WEAK','STOP'},{{'AVATAR','IS','FALLRIGHT'},{'ROCK','IS','STOP'}})
n=run(s,{type='wait'});assert(n.world.entities[1].x==5 and n.world.entities[s.world.next_entity_id])
services.fall=nil;services.shift=RW_ResolveShift
-- SHIFT queues both arrivals against the same vacancy; delete cache permits one HAS.
s=fixture({'WEAK'},{{'ROCK','IS','SHIFT'}})
s.world.entities[2].direction='Left'
s.world.entities[3]={id=3,kind='object',class='object',archetype='avatar',x=6,y=3,direction='Left'}
s.world.entities[4]={id=4,kind='object',class='object',archetype='rock',x=4,y=3,direction='Right'}
n=run(s,{type='wait'});assert(n.world.entities[1].x==5 and n.world.entities[3].x==5)
assert(n.world.next_entity_id==s.world.next_entity_id+1)
services.shift=nil
print('PASS: automatic/FALL virtual death propagation and simultaneous SHIFT cell dedup with atomic HAS/Undo')

-- A products-query limit retains triggering motion and consumed orientation RNG.
local ordinary_destroy=services.destroy
for _,reason in ipairs({'word_rule_limit','rule_complexity_limit','invalid_empty_test'}) do
 services.destroy=function(w,ids,c,k,d,r,count)
  return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,
   empty_products=function(context) return nil,reason,{from=context.random_state or 1,to=48271} end,
   initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate,delete=RW_PlanDelete},d,r,count)
 end
 s=fixture({'WEAK'});s.world.random_state=1
 local p,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services)
 if reason=='invalid_empty_test' then assert(not p and e.reason==reason and s.world.random_state==1)
 else
  assert(p and (p.infinite_loop or p.too_complex));local result;n,result=RW_Commit(s,p);assert(result.accepted)
  assert(n.world.entities[1].x==5 and n.world.random_state==48271 and n.world.next_entity_id==s.world.next_entity_id)
  assert(RW_Undo(n).world==s.world)
 end
end
services.destroy=ordinary_destroy
print('PASS: EMPTY movement query-limit motion/RNG prefixes, independent terminal states, ordinary-error rejection and Undo')

-- A cell deleted while moving must not run HAS again in the late self-contact scan.
local late_queries=0
services.automatic=RW_ResolveAutomatic
services.empty_contacts=function(w,p,r,raw,count)
 return RW_PlanEmptyLateContacts(w,p,r,raw,{victims=RW_ResolveEmptyContactVictims,boom=RW_ResolveEmptyBoom,
  products=function(...) late_queries=late_queries+1;return RW_PlanEmptyHasBirths(...) end,
  initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate,preview=RW_PreviewPlan,
  destroy=function() error('unexpected real blast') end},count)
end
s=fixture({'WEAK','HOT','MELT'},{{'AVATAR','IS','MOVE'},{'AVATAR','IS','MOVE'},{'EMPTY','FACING','AVATAR','HAS','FLAG'}})
for id,e in pairs(s.world.entities) do if e.class=='text' and e.y==12 then s.world.entities[id]=nil end end
s.world.entities[1].direction='Right'
n=run(s,{type='wait'});assert(n.world.entities[1].x==6 and n.world.next_entity_id==s.world.next_entity_id and late_queries==0)
local next_turn=run(n,{type='wait'});assert(next_turn.world.entities[1].x==8 and late_queries==1)
services.automatic=nil;services.empty_contacts=nil
print('PASS: command-local EMPTY deletion suppresses late conditional HAS and resets next turn without persisted tombstones')

-- Unset EMPTY orientation draws once, even if this death has no HAS products.
for _,has in ipairs({false,true}) do
 s=fixture({'WEAK'});s.world.random_state=7
 for id,e in pairs(s.world.entities) do if e.class=='text' then
  if e.y==10 or not has and e.y==12 then s.world.entities[id]=nil
  elseif e.text.name=='FACING' then e.text={name='NEAR'} end
 end end
 local p;n,p=run(s);local expected=7*48271%2147483647
 assert(n.world.random_state==expected and n.world.next_entity_id==s.world.next_entity_id+(has and 1 or 0))
 if has then assert(n.world.entities[s.world.next_entity_id].direction==({'Right','Up','Left','Down'})[expected%4+1]) end
 local found=false;for _,stage in ipairs(p.stages or {}) do if stage.name=='movement_destruction' then
  stage.plan.random_state.from=9;found=true
 end end;assert(found)
 local unchanged,result=RW_Commit(s,p);assert(not result.accepted and unchanged==s and s.world.random_state==7)
end
print('PASS: EMPTY movement shared inside orientation, RNG-only destruction, stale-stage atomic rejection and Undo')
