-- The same raw-frame direction bridge used by the production mapped scripts.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 automatic=function(w,_,rules) local directions,why=RW_CollectEmptyMotionDirections(w,rules);if not directions then return nil,why end;return RW_ResolveAutomatic(w,directions) end,
 contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
 destroy=function(w,ids,c,k,deaths,rules) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths,rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(rows,seed)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=14,30;w.random_state=seed;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={[1]={id=1,kind='object',class='object',archetype='rock',x=6,y=3,direction='Left'}};w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'}
 end end;return s
end
local function step(s)
 local plan,e=RW_PlanTurn(s.world,{type='wait'},services);assert(plan,e and e.reason)
 for _,c in ipairs(plan.changes) do assert(c.entity_id>0) end
 local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world)
 for id,entity in pairs(n.world.entities) do assert(id>0 and entity.class~='empty') end
 assert(not s.world.empty_cells and not s.world.trait_counts)
 return n,plan
end
local function rows(word,count)
 local r={{'EMPTY','IS','RIGHT'},{'ROCK','IS','PUSH'}}
 for i=1,count or 1 do r[#r+1]={'EMPTY','FACING','ROCK','IS',word} end
 return r
end
for _,word in ipairs({'MOVE','AUTO','NUDGERIGHT'}) do for count=1,3 do
 local s=fixture(rows(word,count));local n=step(s)
 assert(n.world.entities[1].x==7 and n.world.entities[1].direction=='Right' and n.world.random_state==nil)
 assert(n.world.next_entity_id==s.world.next_entity_id)
end end
-- MOVE reverses when blocked; AUTO does not. Virtual facing is not saved.
for _,word in ipairs({'MOVE','AUTO'}) do
 local r=rows(word);r[#r+1]={'ROCK','IS','STOP'};r[2]={'FLAG','IS','PUSH'}
 local s=fixture(r);s.world.entities[2]={id=2,kind='object',class='object',archetype='flag',x=4,y=3,direction='Up'}
 local n=step(s);assert(n.world.entities[1].x==6 and n.world.entities[2].x==(word=='MOVE' and 3 or 4))
 local again=step(n);assert(again.world.entities[2].x==n.world.entities[2].x)
end
-- FOLLOW supplies current per-cell direction to collection.
local s=fixture({{'EMPTY','NEAR','FLAG','IS','MOVE'},{'EMPTY','FOLLOW','ROCK'},{'ROCK','IS','PUSH'}})
s.world.entities[2]={id=2,kind='object',class='object',archetype='flag',x=4,y=3,direction='Up'}
local n=step(s);assert(n.world.entities[1].x==7 and n.world.random_state==nil)
local function advance(seed,count) for i=1,count do seed=seed*48271%2147483647 end;return seed end
s=fixture({{'EMPTY','NEAR','ROCK','IS','MOVE'},{'ROCK','IS','PUSH'}})
n=step(s);assert(n.world.random_state==advance(1,8))
s=fixture({{'EMPTY','NEAR','ROCK','IS','AUTO'},{'ROCK','IS','PUSH'}})
n=step(s);assert(n.world.entities[1].x==6 and n.world.random_state==nil)
for count=1,3 do
 s=fixture(rows('CHILL',count),4);n=step(s);assert(n.world.random_state==advance(4,count))
 local replay=step(s);assert(replay.world.random_state==n.world.random_state and replay.world.entities[1].x==n.world.entities[1].x)
end
-- Shared slot numbers suppress later AUTO/CHILL collection rather than adding steps.
for _,counts in ipairs({{2,3,4},{0,1,2},{1,0,1},{0,0,3}}) do
 local r=rows('MOVE',counts[1])
 for i=1,counts[2] do r[#r+1]={'EMPTY','FACING','ROCK','IS','AUTO'} end
 for i=1,counts[3] do r[#r+1]={'EMPTY','FACING','ROCK','IS','CHILL'} end
 s=fixture(r,4);n=step(s)
 local draws=math.max(0,counts[3]-math.max(counts[1],counts[2]))
 assert((n.world.random_state or 4)==advance(4,draws))
end
for _,spec in ipairs({{'NUDGERIGHT','RIGHT',7,3},{'NUDGEUP','UP',6,2},{'NUDGELEFT','LEFT',5,3},{'NUDGEDOWN','DOWN',6,4}}) do
 local r=rows(spec[1],2);r[1]={'EMPTY','IS',spec[2]}
 s=fixture(r);n=step(s);assert(n.world.entities[1].x==spec[3] and n.world.entities[1].y==spec[4])
end
for _,trait in ipairs({'SLEEP','STILL','LOCKEDRIGHT'}) do
 local r=rows('MOVE');r[#r+1]={'EMPTY','IS',trait};s=fixture(r);n=step(s)
 assert(n.world.entities[1].x==6 and n.world.random_state==nil)
end
for _,trait in ipairs({'SLEEP','STILL'}) do
 local r=rows('CHILL');r[#r+1]={'EMPTY','IS',trait};s=fixture(r);n=step(s);assert(n.world.random_state==nil)
end
for count=0,4 do
 local r=rows('MOVE');for i=1,count do r[#r+1]={'EMPTY','IS','REVERSE'} end
 s=fixture(r);n=step(s);assert(n.world.entities[1].x==(count%2==0 and 7 or 6))
end
-- A real blocked weak dependency still dies with HAS, using a real source frame.
local r=rows('MOVE');r[#r+1]={'ROCK','IS','WEAK'};r[#r+1]={'ROCK','HAS','FLAG'};r[#r+1]={'FLAG','IS','STOP'}
s=fixture(r);s.world.entities[2]={id=2,kind='object',class='object',archetype='flag',x=7,y=3,direction='None'}
n=step(s);assert(not n.world.entities[1] and n.world.entities[s.world.next_entity_id].archetype=='flag')
-- RNG-only automatic plans remain atomic under late/stale rejection.
s=fixture(rows('CHILL'),4);local plan; n,plan=step(s)
local automatic;for _,stage in ipairs(plan.stages) do if stage.name=='automatic' then automatic=stage.plan end end
assert(automatic.random_state.from==4);automatic.random_state.from=5
local same,status=RW_Commit(s,plan);assert(not status.accepted and same==s and s.world.random_state==4)
automatic.random_state.from=4
plan.stages[#plan.stages+1]={name='bad_late',plan={consumes_turn=true,changes={{kind='delete',entity_id=999999,from={}}}}}
plan.changes[#plan.changes+1]=plan.stages[#plan.stages].plan.changes[1]
same,status=RW_Commit(s,plan);assert(not status.accepted and same==s and s.world.random_state==4)
print('PASS: EMPTY MOVE/AUTO/CHILL/nudges, counts/direction/FOLLOW/reversal/locks/REVERSE, real WEAK/HAS, pure RNG, positive-only plans and Undo')
-- Global slots include real matches and EMPTY placeholders with no active cells.
for _,first in ipairs({{'ROCK','IS','MOVE'},{'EMPTY','ON','ROCK','IS','MOVE'}}) do
 local r={{'EMPTY','IS','RIGHT'},{'ROCK','IS','PUSH'},{'ROCK','IS','SLEEP'},first,
  {'EMPTY','FACING','ROCK','IS','MOVE'},{'EMPTY','FACING','ROCK','IS','CHILL'}}
 s=fixture(r,4);n=step(s);assert(n.world.random_state==advance(4,1))
end
-- An earlier slot at a different vacancy suppresses later CHILL everywhere.
s=fixture({{'EMPTY','IS','RIGHT'},{'ROCK','IS','PUSH'},
 {'EMPTY','NEAR','FLAG','IS','MOVE'},{'EMPTY','FACING','ROCK','IS','CHILL'}},4)
s.world.entities[2]={id=2,kind='object',class='object',archetype='flag',x=1,y=3,direction='None'}
n=step(s);assert(n.world.random_state==4 and n.world.entities[1].x==6)
print('PASS: EMPTY physical declaration slots retain real-unit offsets, inactive placeholders and cross-vacancy suppression in whole-turn plans')
