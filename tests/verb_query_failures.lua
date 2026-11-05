local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local original=RW_RelationApplies;local active,diagnostic=false,nil
RW_RelationApplies=function(...)
 if active then return nil,diagnostic end
 return original(...)
end
local cases=0
for _,verb in ipairs({'follow','fear','eat'}) do
 for _,reason in ipairs({'word_rule_limit','word_rule_cycle','rule_complexity_limit','injected_query_error'}) do
  local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=10
  w.language.nouns.ROCK='rock'
  w.entities[1]={id=1,kind='object',class='object',archetype='avatar',x=2,y=2,direction='Right'}
  w.entities[2]={id=2,kind='object',class='object',archetype='rock',x=7,y=2,direction='Left'}
  for row,words in ipairs({{'AVATAR','IS','YOU'},{'AVATAR',verb:upper(),'ROCK'}}) do for x,word in ipairs(words) do
   local id=w.next_entity_id;w.next_entity_id=id+1;w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'}
  end end
  diagnostic=reason
  local function query(world,relations,rules)
   active=true
   local targets,why
   if verb=='fear' then targets,why=RW_ResolveFearTargets(world,relations,rules)
   else targets,why=RW_ResolveVerbTargets(world,relations,verb) end
   active=false
   assert(targets==nil and why==reason,'real relation diagnostics must propagate through target resolution')
   return nil,why
  end
  local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
   evaluate=function(world)local f,e=RW_CompileWorld(world,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end,
   contact=function(world,p,k,c)return RW_PlanContactPhase(world,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete})end}
  services[verb]=verb=='eat' and function(world,_,relations,_,rules)return query(world,relations,rules)end or query
  local plan,why=RW_PlanTurn(w,{type='move',dx=1,dy=0},services)
  if reason=='injected_query_error' then
   assert(not plan and why.stage==verb and why.reason==reason,'ordinary query errors must reject the entire turn')
   assert(w.entities[1].x==2 and w.last_input==nil and #s.history==0)
  else
   assert(plan,why and why.reason)
   assert(reason=='rule_complexity_limit' and plan.too_complex or reason~='rule_complexity_limit' and plan.infinite_loop,'compile-limit states must retain their own terminal classification')
   local committed,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
   assert(committed.world.entities[1].x==3,'late verb-query limits must commit completed movement prefix')
   assert(committed.world.too_complex or committed.world.infinite_loop)
   assert(not RW_PlanTurn(committed.world,{type='wait'},services),'terminal query limit must allow only Undo')
   assert(RW_Undo(committed).world==w,'query limit must restore input and entire prefix with Undo')
  end
  cases=cases+1
 end
end
RW_RelationApplies=original
print('PASS: FOLLOW/FEAR/EAT relation failures, terminal prefix Commit, ordinary atomic rejection and Undo ('..cases..' cases)')
