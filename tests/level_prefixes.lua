local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,
 project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 status=RW_PlanRuleStatus,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end,
 erase=function(w) local ids={};for id in pairs(w.entities) do ids[#ids+1]=id end;return RW_PlanDelete(w,ids) end}
services.active=RW_GetActiveLevel;services.update=RW_UpdateActiveLevel;services.enter=RW_EnterLevel;services.return_level=RW_ReturnLevel
services.selectors=RW_LevelSelectorIDs;services.place_selectors=RW_PlaceLevelSelectors;services.bind_entry=RW_BindLevelEntry
services.commit_session=RW_Commit;services.outcome=RW_RecordLevelOutcome;services.candidates=RW_LevelSelectionCandidates
services.win=RW_HasWinContact;services.level_outcome=RW_ResolveLevelPropertyOutcome
local function fixture(rows)
 local root=RW_CreateSession().world
 root.entities={[1]={id=1,kind='object',class='object',archetype='level_block',x=3,y=3,direction='Left',level_link={target='child',definition_id='child',source_type='level_block'}}};root.next_entity_id=10
 local w=RW_CreateSession().world;w.width=32;w.height=32
 w.language.nouns.LEVEL={tag='level',block_type='level_block'};w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={[1]={id=1,kind='object',class='object',archetype='avatar',x=22,y=22,direction='Up'},
 [2]={id=2,kind='object',class='object',archetype='level_block',x=20,y=20,direction='Down',original_name='rock'}};w.next_entity_id=10
 w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',target={kind='id',value=1},trait='you'}}}
 for y,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=2*y,direction='None'} end end
 local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition('root',root)),child=assert(RW_CreateLevelDefinition('child',w))},'root'))
 local parent=tree.active_id;tree=assert(RW_EnterLevel(tree,'1','child'));tree=assert(RW_BindLevelEntry(tree,1));return tree,parent
end
local wait={type='wait'};local right={type='move',dx=1,dy=0}
local function act(tree,action)
 local p,e=RW_PlanLevelAction(tree,action,services);assert(p,e and (e.stage or '')..':'..tostring(e.reason))
 local n,r=RW_CommitLevelTree(tree,p);assert(r.accepted,r.reason)
 assert(RW_GetActiveLevel(RW_UndoLevelTree(n)).world==RW_GetActiveLevel(tree).world)
 return n,p
end
for _,action in ipairs({wait,right}) do
 local tree,parent=fixture({{'IDLE','LEVEL','BECOME','FLAG'}})
 local n,p=act(tree,action)
 if action==wait then assert(n.active_id==parent and RW_GetActiveLevel(n).world.entities[1].archetype=='flag')
 else assert(n.active_id==tree.active_id and RW_GetActiveLevel(n).world.entities[2].archetype=='level_block') end
end
local tree,parent=fixture({{'NOT','IDLE','LEVEL','BECOME','TEXT'}})
local n=act(tree,right);assert(n.active_id==parent and RW_GetActiveLevel(n).world.entities[1].text.name=='LEVEL')
local tree,parent=fixture({{'IDLE','LEVEL','IS','WIN'}})
local n=act(tree,wait);assert(n.active_id==parent and n.outcomes[tree.active_id].kind=='win')
local tree=fixture({{'IDLE','LEVEL','IS','SAFE'}})
local w=RW_GetActiveLevel(tree).world
for _,last in ipairs({'wait','move'}) do
 w.last_input=last
 local frame=assert(RW_CompileWorld(w,cs));assert(#frame.deferred==0)
 local projected=assert(RW_ProjectWorld(w,frame.effects))
 assert((projected.entities[2].behaviors.safe==true)==(last=='wait'))
 local scoped=false;for _,r in ipairs(frame.relations) do if r.op=='level_trait' and r.trait=='safe' then scoped=true end end
 assert(scoped==(last=='wait'))
 for id,e in pairs(w.entities) do if e.class=='text' then assert(frame.active_text_ids[id]) end end
end
print('PASS: scoped and real LEVEL input prefixes share parsing but keep independent declarations, current command, conversion/outcome and Undo')

for _,rows in ipairs({
 {{'IDLE','LEVEL','IS','BROKEN'},{'LEVEL','BECOME','FLAG'}},
 {{'IDLE','LEVEL','IS','LEVEL'},{'LEVEL','IS','FLAG'}}
}) do
 local tree,parent=fixture(rows)
 local idle=act(tree,wait);assert(idle.active_id==tree.active_id)
 local moved=act(tree,right);assert(moved.active_id==parent)
end
local tree=fixture({{'IDLE','LEVEL','BECOME','NOT','LEVEL'}})
local n=act(tree,wait);assert(not next(RW_GetActiveLevel(n).world.entities))
local n=act(tree,right);assert(next(RW_GetActiveLevel(n).world.entities))

local differed={often=false,seldom=false};local checked=0
for _,prefix in ipairs({'OFTEN','SELDOM'}) do
 local tree=fixture({{prefix,'LEVEL','BECOME','FLAG'}});local w=RW_GetActiveLevel(tree).world
 for seed=1,32 do
  w.chance_seed=seed
  local context={};for k,v in pairs(w) do context[k]=v end
  context.chance_seed=(seed*48271)%2147483647;context.last_input='wait'
  local frame=assert(RW_CompileWorld(context,cs));assert(#frame.deferred==0)
  local condition=frame.ast[1].when
  local scoped=RW_TestEntityCondition(context,condition,{id=0,class='level',x=0,y=0,direction='None'});assert(scoped~=nil)
  local real=RW_TestEntityCondition(context,condition,context.entities[2])
  local p,e=RW_PlanTurn(w,wait,services);assert(p,e and e.reason)
  assert((p.level_transform=='flag')==scoped)
  local after=assert(RW_PreviewPlan(w,p));assert((after.entities[2].archetype=='flag')==real)
  local committed,r=RW_Commit(RW_GetActiveLevel(tree),p);assert(r.accepted,r.reason)
  assert(committed.world.chance_seed==context.chance_seed and RW_Undo(committed).world==w)
  if scoped~=real then differed[prefix:lower()]=true end
  local again=assert(RW_PlanTurn(w,wait,services));assert(again.level_transform==p.level_transform)
  assert(w.chance_seed==seed and not w._condition_rules and not w._condition_guard)
  checked=checked+1
 end
end
assert(differed.often and differed.seldom and checked==64)
-- Parent-dependent spatial tests remain deferred, including mixtures with IDLE.
for _,words in ipairs({{'LEVEL','ON','ROCK','IS','SAFE'},{'IDLE','LEVEL','ON','ROCK','IS','SAFE'}}) do
 local tree=fixture({words});local frame=assert(RW_CompileWorld(RW_GetActiveLevel(tree).world,cs));assert(#frame.deferred>0)
end
print('PASS: scoped input-prefix BROKEN/protection/destruction, 64 pure chance plans with independent map/physical identities, and explicit spatial deferral')
