-- EMPTY conversion facing and RNG are part of the production conversion stage.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=10,16;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={[1]={id=1,kind='object',class='object',archetype='rock',x=8,y=2,direction='Right'}};w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=4+row*2,direction='None'}
 end end;return s
end
local function advance(state,count) for i=1,count do state=state*48271%2147483647 end;return state end
local function step(s)
 local p,e=RW_PlanTurn(s.world,{type='wait'},services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world)
 return n,p
end
local base={'EMPTY','NEAR','ROCK','IS','FLAG'}
local s=fixture({base,base});local n,p=step(s);local total,seed=0,1
local dirs={'Right','Up','Left','Down'}
for id=s.world.next_entity_id,n.world.next_entity_id-1 do local e=n.world.entities[id]
 seed=advance(seed,1);assert(e.direction==dirs[seed%4+1] and e.archetype=='flag' and e.original_name=='@empty');total=total+1
end
assert(total==16 and seed==advance(1,16) and n.world.random_state==seed and s.world.random_state==nil)
local initial_conversion;for _,stage in ipairs(p.stages) do if stage.name=='conversion' then initial_conversion=stage.plan end end
assert(initial_conversion.random_state.from==1 and initial_conversion.random_state.to==seed)
local replay=step(s);assert(replay.world.random_state==seed)
local again=step(n);assert(again.world.random_state==seed and again.world.next_entity_id==n.world.next_entity_id)
for _,mode in ipairs({'LEFT','FOLLOW','TEXT'}) do
 local rows=mode=='FOLLOW' and {base,{'EMPTY','FOLLOW','ROCK'}} or mode=='TEXT' and {{'EMPTY','NEAR','ROCK','IS','TEXT'},{'EMPTY','IS','UP'}} or {base,{'EMPTY','IS','LEFT'}}
 s=fixture(rows);n=step(s);assert(n.world.random_state==nil and n.world.next_entity_id==s.world.next_entity_id+8)
 for id=s.world.next_entity_id,n.world.next_entity_id-1 do local e=n.world.entities[id]
  if mode=='FOLLOW' then local dx,dy=8-e.x,2-e.y
   assert(e.direction==(math.abs(dx)<=math.abs(dy) and (dy>=0 and 'Down' or 'Up') or (dx>0 and 'Right' or 'Left')))
  else assert(e.direction==(mode=='TEXT' and 'Up' or 'Left'));if mode=='TEXT' then assert(e.class=='text' and e.text.name=='EMPTY') end end
 end
end
s=fixture({base,{'EMPTY','IS','LEFT'},{'EMPTY','IS','SLEEP'}});n=step(s);assert(n.world.random_state==advance(1,8))
s=fixture({base,{'EMPTY','IS','NOT','FLAG'}});n=step(s);assert(n.world.random_state==nil and n.world.next_entity_id==s.world.next_entity_id)
-- Conversion and later MAKE consume one serial stream, not two reset streams.
services.make=function(w,r,c) local products,rng=RW_PlanMakeProducts(w,r,c);if not products then return nil,rng end
 local plan,e=RW_PlanCreate(w,products);if not plan then return nil,e end;plan.random_state=rng;return plan end
s=fixture({base,base,{'ROCK','MAKE','FLAG'}});s.world.entities[1].direction='None';n,p=step(s)
assert(n.world.random_state==advance(1,17) and n.world.next_entity_id==s.world.next_entity_id+17)
-- Stale metadata and failures after conversion cannot leak RNG or allocations.
local conversion
for _,stage in ipairs(p.stages) do if stage.name=='conversion' then conversion=stage.plan end end
assert(conversion.random_state.to==advance(1,16));conversion.random_state.from=2
local same,r=RW_Commit(s,p);assert(not r.accepted and same==s and s.world.random_state==nil)
conversion.random_state.from=1
p.stages[#p.stages+1]={name='invalid_late',plan={consumes_turn=true,changes={{kind='delete',entity_id=999999,from={}}}}}
p.changes[#p.changes+1]=p.stages[#p.stages].plan.changes[1]
same,r=RW_Commit(s,p);assert(not r.accepted and same==s and s.world.random_state==nil and s.world.next_entity_id<n.world.next_entity_id)
print('PASS: EMPTY conversion direction/FOLLOW/Text/SLEEP, per-product random draws, serial MAKE RNG, stale/late atomic rejection, replay and Undo')
s=fixture({base,{'EMPTY','IS','LEFT'}})
local f=assert(RW_CompileWorld(s.world,cs))
local changes,why,_,_,_,_,rng=RW_PlanConversions(s.world,f.relations)
assert(changes,why);assert(#changes==8 and not rng)
for _,c in ipairs(changes) do assert(c.to.direction=='Left') end
-- ALL keeps one direction per group, and preserves an RNG-only conversion when
-- all individual nouns are denied (the ALL declaration itself still applies).
services.make=nil
local all_rule={'EMPTY','NEAR','ROCK','IS','ALL'}
s=fixture({all_rule});s.world.language.nouns={ROCK='rock',FLAG='flag'}
n=step(s);assert(n.world.random_state==advance(1,8) and n.world.next_entity_id==s.world.next_entity_id+16)
for id=s.world.next_entity_id,n.world.next_entity_id-1,2 do assert(n.world.entities[id].direction==n.world.entities[id+1].direction) end
s=fixture({base,all_rule});s.world.language.nouns={ROCK='rock',FLAG='flag'}
n=step(s);assert(n.world.random_state==advance(1,16) and n.world.next_entity_id==s.world.next_entity_id+24)
for id=s.world.next_entity_id,n.world.next_entity_id-1,3 do assert(n.world.entities[id+1].direction==n.world.entities[id+2].direction) end
s=fixture({all_rule,{'EMPTY','IS','NOT','ROCK'},{'EMPTY','IS','NOT','FLAG'}});s.world.language.nouns={ROCK='rock',FLAG='flag'}
n=step(s);assert(n.world.random_state==advance(1,8) and n.world.next_entity_id==s.world.next_entity_id)
print('PASS: EMPTY ALL shared group direction, mixed ordinary/ALL draw order and RNG-only denied groups with Undo')
for _,verb in ipairs({'BECOME','WRITE'}) do
 s=fixture({{'EMPTY','NEAR','ROCK',verb,'FLAG'},{'EMPTY','IS','DOWN'}})
 n=step(s);assert(n.world.random_state==nil and n.world.next_entity_id==s.world.next_entity_id+8)
 for id=s.world.next_entity_id,n.world.next_entity_id-1 do local e=n.world.entities[id]
  assert(e.direction=='Down' and e.original_name=='@empty')
  if verb=='WRITE' then assert(e.class=='text' and e.text.name=='FLAG') else assert(e.archetype=='flag') end
 end
end
