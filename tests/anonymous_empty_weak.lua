local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 destroy=function(w,ids,c,k,d,r,n) return RW_PlanDestructionPhase(w,ids,c,k,{
  births=RW_InitializeHasBirths,empty_births=RW_InitializeEmptyHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},d,r,n) end,
 contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(extra,push)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=20,40;w.next_entity_id=10
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.language.nouns.WALL='wall'
 w.entities={[1]={id=1,kind='object',class='object',archetype='avatar',x=4,y=3,direction='Left'},
  [2]={id=2,kind='object',class='object',archetype='rock',x=6,y=3,direction='Up'}}
 local rows={{'AVATAR','IS','YOU'},{'EMPTY','IS','RIGHT'},{'EMPTY','FACING','ROCK','IS','PUSH'},
  {'EMPTY','FACING','ROCK','IS','WEAK'},{'EMPTY','FACING','ROCK','IS','FLOAT'},{'EMPTY','HAS','FLAG'}}
 if not push then rows[#rows+1]={'ROCK','IS','STOP'} end
 for _,row in ipairs(extra or {}) do rows[#rows+1]=row end
 for y,words in ipairs(rows) do for x,name in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=6+y*2,direction='None'}
 end end
 return s
end
local function run(s)
 local plan,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
 for _,op in ipairs(plan.changes) do assert(op.entity_id>0) end
 local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
 assert(RW_Undo(n).world==s.world and not n.world.empty_deleted)
 return n
end
local s=fixture();local n=run(s)
assert(n.world.entities[1].x==5 and n.world.entities[2].x==6)
assert(n.world.entities[s.world.next_entity_id].archetype=='flag' and n.world.entities[s.world.next_entity_id].x==5)
for _,trait in ipairs({'SAFE','STILL','LOCKEDRIGHT'}) do
 s=fixture({{'EMPTY','FACING','ROCK','IS',trait}});n=run(s)
 assert(n.world.entities[1].x==4 and n.world.next_entity_id==s.world.next_entity_id)
end
s=fixture({{'EMPTY','FACING','ROCK','IS','SLEEP'}});n=run(s);assert(n.world.entities[1].x==5)
s=fixture(nil,true);n=run(s);assert(n.world.entities[1].x==5 and n.world.next_entity_id==s.world.next_entity_id)
-- A moved real dependency is rolled back before only the anonymous root breaks.
s=fixture({{'ROCK','IS','PUSH'},{'WALL','IS','STOP'}},true)
s.world.entities[3]={id=3,kind='object',class='object',archetype='wall',x=6,y=3,direction='Down'}
n=run(s);assert(n.world.entities[1].x==5 and n.world.entities[2].x==6 and n.world.entities[2].direction=='Up')
assert(n.world.next_entity_id==s.world.next_entity_id+1)
local edge={width=8,height=8,entities={[1]={id=1,x=7,y=4,behaviors={}}},
 empty_cells={['8:4']={x=8,y=4,behaviors={push=true,weak=true,float=true}}}}
local plan=assert(RW_ResolveMovement(edge,{type='move',entity_id=1,dx=1,dy=0}))
assert(#plan.changes==1 and plan.changes[1].to.x==8 and #plan.destructions==1 and plan.destructions[1].x==8)
print('PASS: anonymous EMPTY PUSH WEAK blocked/free, SAFE/STILL/locks/SLEEP, dependency rollback, cell HAS and positive-only Undo')
