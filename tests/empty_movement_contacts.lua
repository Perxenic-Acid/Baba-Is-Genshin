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

-- Real mover/EMPTY unlock uses target-before-mover HAS and independent SAFE.
for _,case in ipairs({{false,false},{true,false},{false,true},{true,true}}) do
 local mover_safe,empty_safe=case[1],case[2]
 local traits={'SHUT','STOP'};if empty_safe then traits[#traits+1]='SAFE' end
 local extra={{'AVATAR','IS','OPEN'},{'AVATAR','HAS','ROCK'}}
 if mover_safe then extra[#extra+1]={'AVATAR','IS','SAFE'} end
 s=fixture(traits,extra);n=run(s)
 local base=s.world.next_entity_id
 if mover_safe and empty_safe then assert(n.world.entities[1].x==4 and n.world.next_entity_id==base)
 elseif mover_safe then assert(n.world.entities[1].x==5 and n.world.entities[base].archetype=='flag' and n.world.entities[base].x==5)
 elseif empty_safe then assert(not n.world.entities[1] and n.world.entities[base].archetype=='rock' and n.world.entities[base].x==4)
 else
  assert(not n.world.entities[1] and n.world.entities[base].archetype=='flag' and n.world.entities[base].x==5)
  assert(n.world.entities[base+1].archetype=='rock' and n.world.entities[base+1].x==4)
 end
end
s=fixture({'SHUT','PUSH','STILL','WEAK'},{{'AVATAR','IS','OPEN'},{'AVATAR','HAS','ROCK'}})
n=run(s);assert(not n.world.entities[1] and n.world.next_entity_id==s.world.next_entity_id+2)
s=fixture({'SHUT','STOP','FLOAT'},{{'AVATAR','IS','OPEN'}});n=run(s);assert(n.world.entities[1].x==4 and n.world.next_entity_id==s.world.next_entity_id)
s=fixture({'OPEN','STOP'},{{'AVATAR','IS','SHUT'},{'AVATAR','IS','PHANTOM'}})
n=run(s);assert(n.world.entities[1].x==5 and n.world.next_entity_id==s.world.next_entity_id)
-- Earlier cell products participate in the later real victim's conditional HAS.
s=fixture({'SHUT','STOP'},{{'AVATAR','IS','OPEN'},{'AVATAR','WITHOUT','FLAG','HAS','ROCK'}})
n=run(s);assert(not n.world.entities[1] and n.world.next_entity_id==s.world.next_entity_id+1)
print('PASS: EMPTY unlock independent SAFE/FLOAT/PHANTOM, target-first mixed HAS/allocators, WEAK dedup, source positions, conditional witnesses and Undo')

-- Unlock in a PUSH dependency retains source frames; unrelated blockers roll it back.
for _,blocked in ipairs({false,true}) do
 local extra={{'ROCK','IS','OPEN'},{'ROCK','IS','PUSH'},{'ROCK','HAS','ROCK'}}
 if blocked then extra[#extra+1]={'FLAG','IS','STOP'} end
 s=fixture({'SHUT','STOP'},extra);s.world.entities[1].x=3
 s.world.entities[3]={id=3,kind='object',class='object',archetype='rock',x=4,y=3,direction='Up'}
 if blocked then s.world.entities[4]={id=4,kind='object',class='object',archetype='flag',x=4,y=3,direction='Down'} end
 n=run(s)
 if blocked then assert(n.world.entities[1].x==3 and n.world.entities[3] and n.world.next_entity_id==s.world.next_entity_id)
 else
  assert(n.world.entities[1].x==4 and not n.world.entities[3] and n.world.entities[2].x==6)
  assert(n.world.entities[s.world.next_entity_id].x==5 and n.world.entities[s.world.next_entity_id+1].x==4)
 end
end
print('PASS: EMPTY unlock PUSH dependency origins and unrelated-blocker atomic rollback')

services.empty_eaters=RW_ResolveEmptyEatSources
-- EAT is a source predicate, not a property of the target vacancy.
for _,traits in ipairs({{}, {'STOP'}, {'PUSH','STILL'}, {'WEAK','SHUT','STOP'}}) do
 s=fixture(traits,{{'AVATAR','EAT','EMPTY'},{'AVATAR','EAT','EMPTY'},{'AVATAR','IS','OPEN'}})
 n=run(s);assert(n.world.next_entity_id==s.world.next_entity_id+1)
 assert(n.world.entities[s.world.next_entity_id].x==5 and not n.world.empty_eaters)
 if #traits==3 then assert(not n.world.entities[1]) else assert(n.world.entities[1].x==5) end
end
for _,traits in ipairs({{'SAFE','STOP'},{'FLOAT','STOP'}}) do
 s=fixture(traits,{{'AVATAR','EAT','EMPTY'}});n=run(s)
 assert(n.world.entities[1].x==4 and n.world.next_entity_id==s.world.next_entity_id)
end
s=fixture({'STOP','FLOAT'},{{'AVATAR','EAT','EMPTY'},{'AVATAR','IS','FLOAT'}});n=run(s);assert(n.world.entities[1].x==5)
s=fixture({'STOP'},{{'AVATAR','EAT','EMPTY'},{'AVATAR','IS','PHANTOM'}});n=run(s);assert(n.world.entities[1].x==5 and n.world.next_entity_id==s.world.next_entity_id)
-- Conditions use the eater's origin, not the target coordinates passed by check().
s=fixture({'STOP'},{{'AVATAR','ON','ROCK','EAT','EMPTY'}});n=run(s);assert(n.world.entities[1].x==4)
s=fixture({'STOP'},{{'AVATAR','NEAR','ROCK','EAT','EMPTY'}});n=run(s);assert(n.world.entities[1].x==4)
s=fixture({'STOP'},{{'AVATAR','NEAR','FLAG','EAT','EMPTY'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=3,y=3,direction='None'}
n=run(s);assert(n.world.entities[1].x==5 and n.world.entities[s.world.next_entity_id])
s=fixture({'STOP'},{{'AVATAR','EAT','EMPTY'},{'AVATAR','EAT','NOT','EMPTY'}});n=run(s);assert(n.world.entities[1].x==4)
s=fixture({'STOP'},{{'AVATAR','EAT','EMPTY'},{'AVATAR','IS','BROKEN'}});s.world.entities[1].broken=1;n=run(s);assert(n.world.entities[1].x==4 and n.world.next_entity_id==s.world.next_entity_id)
print('PASS: real EAT EMPTY entry without target traits, duplicate/negative/spatial predicates, origin conditions, SAFE/FLOAT/PHANTOM/BROKEN and unlock/WEAK order with Undo')

-- Refresh eater conditions after YOU, before autonomous motion.
services.automatic=RW_ResolveAutomatic
s=fixture({},{{'AVATAR','NEAR','FLAG','EAT','EMPTY'},{'AVATAR','IS','MOVE'}})
s.world.entities[1].direction='Right';s.world.entities[2].x=8
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=6,y=4,direction='None'}
n=run(s);assert(n.world.entities[1].x==6 and n.world.next_entity_id==s.world.next_entity_id+1)
assert(n.world.entities[s.world.next_entity_id].x==6 and n.world.entities[s.world.next_entity_id].y==3)
services.automatic=nil
-- Passive real/Text PUSH participants retain their own EAT capability.
for _,text in ipairs({false,true}) do
 local extra=text and {{'TEXT','EAT','EMPTY'}} or {{'ROCK','EAT','EMPTY'},{'ROCK','IS','PUSH'}}
 s=fixture({'STOP'},extra);s.world.entities[1].x=3
 s.world.entities[3]=text and {id=3,kind='object',class='text',text={name='ROCK'},x=4,y=3,direction='Up'}
  or {id=3,kind='object',class='object',archetype='rock',x=4,y=3,direction='Up'}
 n=run(s);assert(n.world.entities[1].x==4 and n.world.entities[3].x==5 and n.world.entities[s.world.next_entity_id].x==5)
end
print('PASS: EMPTY EAT conditions refresh between YOU/automatic phases, and passive Object/Text PUSH participants eat independently')

-- A YOU EMPTY proxy may unlock a real unit; only cell HAS is persisted for it.
for _,case in ipairs({{false,false},{true,false},{false,true},{true,true}}) do
 local source_safe,target_safe=case[1],case[2]
 local traits={'YOU','OPEN'};if source_safe then traits[#traits+1]='SAFE' end
 local extra={{'ROCK','IS','SHUT'},{'ROCK','IS','STOP'},{'ROCK','HAS','AVATAR'}}
 if target_safe then extra[#extra+1]={'ROCK','IS','SAFE'} end
 s=fixture(traits,extra)
 for id,e in pairs(s.world.entities) do if e.class=='text' and e.y==8 then s.world.entities[id]=nil end end
 n=run(s);local base=s.world.next_entity_id
 assert(n.world.entities[1].x==4)
 if source_safe and target_safe then assert(n.world.entities[2] and n.world.next_entity_id==base)
 elseif source_safe then assert(not n.world.entities[2] and n.world.entities[base].archetype=='avatar' and n.world.entities[base].x==6)
 elseif target_safe then assert(n.world.entities[2] and n.world.entities[base].archetype=='flag' and n.world.entities[base].x==5)
 else
  assert(not n.world.entities[2] and n.world.entities[base].archetype=='avatar' and n.world.entities[base].x==6)
  assert(n.world.entities[base+1].archetype=='flag' and n.world.entities[base+1].x==5)
 end
 for id,e in pairs(n.world.entities) do assert(type(id)=='number' and id>0 and e.class~='empty') end
end
print('PASS: virtual YOU EMPTY unlocks real units with independent SAFE, ordered real/cell HAS, positive-only Commit and Undo')

-- Automatic/Fear adapters retire virtual movers while retaining their cell deaths.
services.automatic=function(w,r,raw) return RW_ResolveAutomatic(w,assert(RW_CollectEmptyMotionDirections(w,raw))) end
s=fixture({'MOVE','OPEN'},{{'ROCK','IS','SHUT'},{'ROCK','IS','STOP'},{'ROCK','HAS','AVATAR'}})
for id,e in pairs(s.world.entities) do if e.class=='text' and e.y==8 then s.world.entities[id]=nil end end
n=run(s,{type='wait'});assert(not n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id+2)
services.automatic=nil;services.fear=function(w,r,raw) return RW_ResolveFear(w,assert(RW_ResolveFearTargets(w,r,raw))) end
s=fixture({'OPEN'},{{'EMPTY','FACING','ROCK','FEAR','ROCK'},{'FLAG','IS','SHUT'},{'FLAG','IS','STOP'},{'FLAG','HAS','AVATAR'}})
for id,e in pairs(s.world.entities) do if e.class=='text' and e.y==8 then s.world.entities[id]=nil end end
s.world.entities[1].archetype='flag'
n=run(s,{type='wait'});assert(not n.world.entities[1] and n.world.next_entity_id==s.world.next_entity_id+2)
assert(n.world.entities[s.world.next_entity_id].x==4 and n.world.entities[s.world.next_entity_id+1].x==5)
services.fear=nil
print('PASS: automatic/FEAR virtual unlock retirement, ordered real/cell HAS and positive-only Undo')

-- Blocked virtual WEAK roots now retire through the same cell-HAS transaction.
for _,guard in ipairs({'NONE','SAFE','STILL','SLEEP'}) do
 local traits={'YOU','WEAK'};if guard~='NONE' then traits[#traits+1]=guard end
 s=fixture(traits,{{'ROCK','IS','STOP'}})
 for id,e in pairs(s.world.entities) do if e.class=='text' and e.y==8 then s.world.entities[id]=nil end end
 n=run(s);assert(n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id+(guard=='NONE' and 1 or 0))
 if guard=='NONE' then assert(n.world.entities[s.world.next_entity_id].x==5) end
end
services.automatic=function(w,r,raw) return RW_ResolveAutomatic(w,assert(RW_CollectEmptyMotionDirections(w,raw))) end
-- MOVE gets one bounce before root WEAK; AUTO and directional nudges do not.
for _,virtual in ipairs({false,true}) do for _,both_sides in ipairs({false,true}) do
 local traits=virtual and {'MOVE','WEAK'} or {}
 local extra={{'ROCK','IS','STOP'}}
 if virtual then if both_sides then extra[#extra+1]={'AVATAR','IS','STOP'} end
 else
  extra[#extra+1]={'AVATAR','IS','MOVE'};extra[#extra+1]={'AVATAR','IS','WEAK'};extra[#extra+1]={'AVATAR','HAS','FLAG'}
  if both_sides then extra[#extra+1]={'FLAG','IS','STOP'} end
 end
 s=fixture(traits,extra)
 if virtual then
  for id,e in pairs(s.world.entities) do if e.class=='text' and e.y==8 then s.world.entities[id]=nil end end
 else
  s.world.entities[1].x=5;s.world.entities[1].direction='Right'
  if both_sides then s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=4,y=3,direction='None'} end
 end
 n=run(s,{type='wait'})
 assert(n.world.next_entity_id==s.world.next_entity_id+(both_sides and 1 or 0))
 if not virtual then assert((n.world.entities[1]~=nil)==not both_sides);if not both_sides then assert(n.world.entities[1].x==4) end end
 if both_sides then
  local born=n.world.entities[s.world.next_entity_id];assert(born.x==5 and born.direction==(virtual and 'Right' or 'Left'))
 end
end end
s=fixture({'NUDGERIGHT','WEAK'},{{'ROCK','IS','STOP'}})
for id,e in pairs(s.world.entities) do if e.class=='text' and e.y==8 then s.world.entities[id]=nil end end
n=run(s,{type='wait'});assert(n.world.entities[s.world.next_entity_id].x==5)
services.automatic=nil
print('PASS: blocked virtual WEAK YOU/nudges, SAFE/STILL/SLEEP, real/virtual MOVE bounce-before-break, cell-vs-intrinsic HAS facing and Undo')
