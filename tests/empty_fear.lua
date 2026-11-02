-- Virtual FEAR follows the production rule/script bridge and whole-turn scheduler.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 fear=function(w,r,raw) local t,e=RW_ResolveFearTargets(w,r,raw);if not t then return nil,e end;return RW_ResolveFear(w,t) end,
 destroy=function(w,ids,c,k,d,r) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},d,r) end,
 contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(count,extra)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=24,30;w.next_entity_id=10
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={[1]={id=1,kind='object',class='object',archetype='rock',x=6,y=3,direction='Left'},
 [2]={id=2,kind='object',class='object',archetype='avatar',x=4,y=3,direction='Up'}}
 local rows={{'EMPTY','IS','RIGHT'},{'ROCK','IS','PUSH'}}
 for i=1,count do rows[#rows+1]={'EMPTY','FACING','ROCK','FEAR','AVATAR'} end
 for _,row in ipairs(extra or {}) do rows[#rows+1]=row end
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'}
 end end
 return s
end
local function step(s)
 local p,e=RW_PlanTurn(s.world,{type='wait'},services);assert(p,e and e.reason)
 for _,c in ipairs(p.changes) do assert(c.entity_id>0) end
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world)
 for id,entity in pairs(n.world.entities) do assert(id>0 and entity.class~='empty') end
 assert(not s.world.empty_cells and not s.world.trait_counts)
 return n,p
end
for count=1,3 do
 local s=fixture(count);local n=step(s);assert(n.world.entities[1].x==6+count and n.world.entities[1].direction=='Right',count..':'..n.world.entities[1].x..':'..n.world.entities[1].direction)
 assert(n.world.next_entity_id==s.world.next_entity_id and n.world.random_state==nil)
end
for _,trait in ipairs({'SLEEP','STILL','LOCKEDRIGHT','BROKEN'}) do
 local s=fixture(1,{{'EMPTY','IS',trait}});local n=step(s);assert(n.world.entities[1].x==6)
end
for count=0,4 do
 local extra={};for i=1,count do extra[#extra+1]={'EMPTY','IS','REVERSE'} end
 local n=step(fixture(1,extra));assert(n.world.entities[1].x==(count%2==0 and 7 or 6))
end
local s=fixture(1,{{'EMPTY','FEAR','NOT','AVATAR'}});local n=step(s);assert(n.world.entities[1].x==6)
-- Direction is queried from FOLLOW rather than saved virtual facing.
s=fixture(1,{{'EMPTY','FOLLOW','ROCK'},{'EMPTY','IS','NOT','RIGHT'}})
n=step(s);assert(n.world.entities[1].x==7)
-- Failed weak PUSH dependencies remain real victims with real HAS products.
s=fixture(1,{{'ROCK','IS','WEAK'},{'ROCK','HAS','FLAG'},{'FLAG','IS','STOP'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=7,y=3,direction='None'}
n=step(s);assert(not n.world.entities[1] and n.world.entities[s.world.next_entity_id].archetype=='flag')
-- A late rejected transaction cannot leave dependency motion or allocations behind.
s=fixture(2);local plan;n,plan=step(s)
local bad={kind='delete',entity_id=999999,from={}};plan.stages[#plan.stages+1]={name='late_bad',plan={consumes_turn=true,changes={bad}}};plan.changes[#plan.changes+1]=bad
local same,result=RW_Commit(s,plan);assert(not result.accepted and same==s and s.world.entities[1].x==6)
print('PASS: EMPTY FEAR per-cell predicates/negative grants, duplicate strength, FOLLOW/BROKEN/SLEEP/locks/REVERSE, real WEAK/HAS, positive-only transactions and Undo')-- Text and vacant targets share native cardinal matching; FLOAT never filters FEAR.
for _,target in ipairs({'TEXT','EMPTY'}) do
 s=fixture(2,{{'EMPTY','IS','FLOAT'}})
 for _,entity in pairs(s.world.entities) do
  if entity.class=='text' and entity.text.name=='AVATAR' then entity.text.name=target end
 end
 if target=='TEXT' then s.world.entities[2]={id=2,kind='object',class='text',text={name='IS'},x=4,y=3,direction='None'} end
 n=step(s);assert(n.world.entities[1].x==8)
end
-- Same-name stacked witnesses do not increase strength.
s=fixture(1);s.world.entities[3]={id=3,kind='object',class='object',archetype='avatar',x=4,y=3,direction='Down'}
n=step(s);assert(n.world.entities[1].x==7)
print('PASS: EMPTY FEAR Text/vacancy targets, FLOAT independence and stacked witness strength')
