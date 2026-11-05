local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,
 project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={level_traits=RW_QueryLevelTraits,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 status=RW_PlanRuleStatus,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end,
 erase=function(w) local ids={};for id in pairs(w.entities) do ids[#ids+1]=id end;return RW_PlanDelete(w,ids) end}
services.active=RW_GetActiveLevel;services.update=RW_UpdateActiveLevel;services.enter=RW_EnterLevel;services.return_level=RW_ReturnLevel
services.selectors=RW_LevelSelectorIDs;services.place_selectors=RW_PlaceLevelSelectors;services.bind_entry=RW_BindLevelEntry
services.commit_session=RW_Commit;services.outcome=RW_RecordLevelOutcome;services.candidates=RW_LevelSelectionCandidates
services.win=RW_HasWinContact;services.level_outcome=RW_ResolveLevelPropertyOutcome
local function fixture(rows,parent_objects)
 local root=RW_CreateSession().world
 root.entities={[1]={id=1,kind='object',class='object',archetype='level_block',x=3,y=3,direction='Left',level_link={target='child',definition_id='child',source_type='level_block'}}};root.next_entity_id=10
 for index,obj in ipairs(parent_objects or {}) do
  local id=index+1;root.entities[id]={id=id,kind='object',class='object',archetype=obj[1],x=3+obj[2],y=3+obj[3],direction='None'}
 end
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
-- All existing spatial condition syntax now lowers for scoped LEVEL.
for _,words in ipairs({{'LEVEL','FACEDBY','ROCK','IS','SAFE'},{'IDLE','LEVEL','FACEDBY','ROCK','IS','SAFE'}}) do
 local tree=fixture({words});local frame=assert(RW_CompileWorld(RW_GetActiveLevel(tree).world,cs));assert(#frame.deferred==0)
end
print('PASS: scoped input-prefix BROKEN/protection/destruction, 64 pure chance plans with independent map/physical identities, and scoped spatial lowering')

for _,case in ipairs({
 {prefix='POWERED',source={'AVATAR','IS','POWER'},fires=true},
 {prefix='POWERED',source={'LEVEL','IS','POWER'},fires=true},
 {prefix='POWERED2',source={'LEVEL','IS','POWER'},fires=false},
 {prefix='POWERED2',source={'LEVEL','IS','POWER2'},fires=true},
 {prefix='POWERED3',source={'LEVEL','IS','POWER3'},fires=true},
 {prefix='POWERED',source={'POWERED','LEVEL','IS','POWER'},fires=false},
 {prefix='POWERED',source={'IDLE','LEVEL','IS','POWER'},fires=true},
 {prefix='POWERED',source={'LEVEL','IS','POWER'},extra={'LEVEL','IS','BROKEN'},fires=false},
 {prefix='POWERED',source={'LEVEL','IS','POWER'},extra={'IDLE','LEVEL','IS','BROKEN'},fires=false}
}) do
 local rows={{case.prefix,'LEVEL','BECOME','FLAG'},case.source}
 if case.extra then rows[#rows+1]=case.extra end
 local tree,parent=fixture(rows);RW_GetActiveLevel(tree).world.entities[2]=nil
 local frame=assert(RW_CompileWorld(RW_GetActiveLevel(tree).world,cs));assert(#frame.deferred==0)
 local n=act(tree,wait);assert((n.active_id==parent)==case.fires,case.prefix..':'..case.source[1])
end
local tree,parent=fixture({{'POWERED','LEVEL','BECOME','FLAG'},{'IDLE','LEVEL','IS','POWER'}})
RW_GetActiveLevel(tree).world.entities[2]=nil
local n=act(tree,right);assert(n.active_id==tree.active_id)
local tree,parent=fixture({{'POWERED','LEVEL','BECOME','FLAG'},{'LEVEL','IS','POWER'},{'IDLE','LEVEL','IS','BROKEN'}})
RW_GetActiveLevel(tree).world.entities[2]=nil
local n=act(tree,right);assert(n.active_id==parent)
-- A frozen rule frame carries declarations, never a latched map POWER Boolean.
local tree=fixture({{'POWERED','LEVEL','IS','POWER'},{'AVATAR','IS','POWER'}})
local w=RW_GetActiveLevel(tree).world;w.entities[2]=nil
local frame=assert(RW_CompileWorld(w,cs));assert(#frame.deferred==0)
local powered={op='spatial',clauses={{relation='powered',negated=false,parameters={}}}}
local context={};for k,v in pairs(w) do context[k]=v end
context._condition_rules=frame.rules;context.entities={}
for id,e in pairs(w.entities) do if id~=1 then context.entities[id]=e end end
local map={id=0,class='level',x=0,y=0,direction='None'}
assert(RW_TestEntityCondition(context,powered,map)==false)
assert(not w._condition_guard and not w._condition_rules)
print('PASS: scoped POWERED channels see complete real/map declarations, conditional input/BROKEN, grounded recursion, frozen-frame source deletion and Undo')

for _,negative in ipairs({false,true}) do
 local words=negative and {'NOT','LONELY','LEVEL','BECOME','FLAG'} or {'LONELY','LEVEL','BECOME','FLAG'}
 local tree,parent=fixture({words});local w=RW_GetActiveLevel(tree).world
 local frame=assert(RW_CompileWorld(w,cs));assert(#frame.deferred==0)
 local n=act(tree,wait);assert((n.active_id==parent)==negative)
 -- Physical Level remains an ordinary, isolated unit and uses its own identity.
 if not negative then assert(RW_GetActiveLevel(n).world.entities[2].archetype=='flag') end
end
print('PASS: scoped LEVEL LONELY is always false, NOT LONELY is true, physical Level stays per-identity and Undo restores both')

for _,case in ipairs({
 {condition={'FEELING','SAFE'},sources={{'LEVEL','IS','SAFE'}},fires=true},
 {condition={'FEELING','SAFE'},sources={{'IDLE','LEVEL','IS','SAFE'}},fires=true},
 {condition={'FEELING','SAFE'},sources={{'LEVEL','IS','SAFE'},{'LEVEL','IS','NOT','SAFE'}},fires=false},
 {condition={'FEELING','NOT','SAFE'},sources={{'LEVEL','IS','FLOAT'}},fires=true},
 {condition={'FEELING','NOT','SAFE'},sources={},fires=false},
 {condition={'FEELING','SAFE','AND','SAFE'},sources={{'LEVEL','IS','SAFE'}},fires=false},
 {condition={'FEELING','SAFE','AND','SAFE'},sources={{'LEVEL','IS','SAFE'},{'LEVEL','IS','SAFE'}},fires=true},
 {condition={'FEELING','SAFE'},sources={{'LEVEL','FEELING','SAFE','IS','SAFE'}},fires=false},
 {condition={'FEELING','SAFE'},sources={{'LEVEL','IS','SAFE'},{'LEVEL','IS','BROKEN'}},fires=false}
}) do
 local words={'LEVEL'};for _,word in ipairs(case.condition) do words[#words+1]=word end
 words[#words+1]='BECOME';words[#words+1]='FLAG'
 local rows={words};for _,row in ipairs(case.sources) do rows[#rows+1]=row end
 local tree,parent=fixture(rows);RW_GetActiveLevel(tree).world.entities[2]=nil
 local f=assert(RW_CompileWorld(RW_GetActiveLevel(tree).world,cs));assert(#f.deferred==0)
 local n=act(tree,wait);assert((n.active_id==parent)==case.fires,table.concat(case.condition,' '))
end
print('PASS: scoped LEVEL FEELING current/conditional properties, complements, duplicate quotas, denials, ungrounded recursion, BROKEN and whole-tree Undo')

local tree=fixture({{'IDLE','LEVEL','IS','SAFE'},{'LEVEL','FEELING','SAFE','IS','POWER'}})
local w=RW_GetActiveLevel(tree).world;w.last_input='wait'
local frame=assert(RW_CompileWorld(w,cs))
local condition={op='spatial',clauses={{relation='feeling',negated=false,parameters={{tag='property',name='safe'}}}}}
local context={};for k,v in pairs(w) do context[k]=v end
context._condition_rules=frame.rules
local map={id=0,class='level',x=0,y=0,direction='None'}
assert(RW_TestEntityCondition(context,condition,map)==true)
context.last_input='move';assert(RW_TestEntityCondition(context,condition,map)==false)
assert(not w._feeling_checked and not w._condition_guard and not w._condition_rules)
print('PASS: scoped FEELING frozen declarations re-evaluate current input without persisting query caches')

for _,case in ipairs({
 {params={'ROCK'},rock=false,fires=true},
 {params={'ROCK'},rock=true,fires=false},
 {params={'ROCK','AND','ROCK'},rock=true,fires=true},
 {params={'LEVEL'},fires=false},
 {params={'LEVEL','AND','LEVEL'},fires=true},
 {params={'NOT','LEVEL'},fires=false},
 {params={'ROCK'},negative=true,rock=false,fires=false},
 {params={'ROCK'},negative=true,rock=true,fires=true},
 {params={'ROCK','AND','FLAG'},negative=true,rock=true,fires=false}
}) do
 local row=case.negative and {'LEVEL','NOT','WITHOUT'} or {'LEVEL','WITHOUT'};for _,word in ipairs(case.params) do row[#row+1]=word end
 row[#row+1]='BECOME';row[#row+1]='FLAG'
 local tree,parent=fixture({row});local w=RW_GetActiveLevel(tree).world
 if case.rock then w.entities[3]={id=3,kind='object',class='object',archetype='rock',x=25,y=25,direction='Right'} end
 local f=assert(RW_CompileWorld(w,cs));assert(#f.deferred==0)
 local n=act(tree,wait);assert((n.active_id==parent)==case.fires,table.concat(row,' '))
end
print('PASS: scoped LEVEL WITHOUT global shortages, duplicate quotas, synthetic/physical LEVEL counts, complements and Undo')

for _,case in ipairs({
 {relation='ON',params={'ROCK'},parent={{'rock',0,0}},fires=true},
 {relation='ON',params={'ROCK'},fires=false},
 {relation='ON',params={'ROCK'},child=true,fires=true},
 {relation='ON',params={'ROCK','AND','ROCK'},parent={{'rock',0,0}},fires=true},
 {relation='ON',params={'ROCK','AND','ROCK'},child=true,fires=false},
 {relation='NEAR',params={'ROCK'},parent={{'rock',1,1}},fires=true},
 {relation='NEXTTO',params={'ROCK'},parent={{'rock',1,1}},fires=true},
 {relation='NEXTTO',params={'ROCK'},parent={{'rock',0,0}},fires=false},
 {relation='ON',params={'TEXT'},fires=true},
 {relation='ON',params={'LEVEL'},fires=true},
 {relation='NEAR',params={'LEVEL'},fires=false},
 {relation='ON',params={'ROCK'},negative=true,fires=true}
}) do
 local row={'LEVEL'};if case.negative then row[#row+1]='NOT' end
 row[#row+1]=case.relation;for _,word in ipairs(case.params) do row[#row+1]=word end
 row[#row+1]='BECOME';row[#row+1]='FLAG'
 local tree,parent=fixture({row},case.parent);local w=RW_GetActiveLevel(tree).world
 if case.child then w.entities[3]={id=3,kind='object',class='object',archetype='rock',x=25,y=25,direction='Right'} end
 local f=assert(RW_CompileWorld(w,cs));assert(#f.deferred==0)
 local n=act(tree,wait);assert((n.active_id==parent)==case.fires,table.concat(row,' '))
end
for _,action in ipairs({wait,right}) do
 local tree,parent=fixture({{'IDLE','LEVEL','ON','ROCK','BECOME','FLAG'}},{{'rock',0,0}})
 local n=act(tree,action);assert((n.active_id==parent)==(action==wait))
end
print('PASS: scoped spatial tree conversions use child contents plus saved parent regions, repeatable names, diagonal NEXTTO, mixed IDLE and whole-tree Undo')

local tree=fixture({{'LEVEL','ON','ROCK','IS','POWER'}})
local w=RW_GetActiveLevel(tree).world
w.entities[3]={id=3,kind='object',class='object',archetype='rock',x=25,y=25,direction='Right'}
local frame=assert(RW_CompileWorld(w,cs))
local condition={op='spatial',clauses={{relation='on',negated=false,parameters={{tag='noun',type={tag='object',name='rock'}}}}}}
local context={};for k,v in pairs(w) do context[k]=v end
context._condition_rules=frame.rules
local map={id=0,class='level',x=0,y=0,direction='None'}
assert(RW_TestEntityCondition(context,condition,map)==true)
context.entities={};for id,e in pairs(w.entities) do if id~=3 then context.entities[id]=e end end
assert(RW_TestEntityCondition(context,condition,map)==false)
assert(w.entities[3] and not w._condition_rules and #w.level_surrounds.o==0)
print('PASS: scoped spatial frozen declarations observe child deletion without changing saved surroundings or source runtime')

for _,case in ipairs({{'ABOVE',0,1},{'BELOW',0,-1},{'BESIDELEFT',1,0},{'BESIDERIGHT',-1,0}}) do
 for _,location in ipairs({'correct','opposite','diagonal','child'}) do
  local x,y=case[2],case[3]
  if location=='opposite' then x,y=-x,-y elseif location=='diagonal' then x,y=1,1 end
  local row={'LEVEL',case[1],'ROCK','BECOME','FLAG'}
  local tree,parent=fixture({row},location~='child' and {{'rock',x,y}} or {})
  local w=RW_GetActiveLevel(tree).world
  if location=='child' then w.entities[3]={id=3,kind='object',class='object',archetype='rock',x=25,y=25,direction='None'} end
  local f=assert(RW_CompileWorld(w,cs));assert(#f.deferred==0)
  local n=act(tree,wait);assert((n.active_id==parent)==(location=='correct' or location=='child'),case[1]..':'..location)
 end
end
print('PASS: scoped LEVEL directional conditions use the correct one-cell parent side or global child witnesses, preserve diagonal exclusion and Undo')

for _,side in ipairs({'ABOVE','BELOW','BESIDELEFT','BESIDERIGHT'}) do
 local tree,parent=fixture({{'LEVEL',side,'EMPTY','BECOME','FLAG'}})
 local n=act(tree,wait);assert((n.active_id==parent)==(side=='BELOW' or side=='BESIDERIGHT'))
end
print('PASS: scoped directional EMPTY retains native lookup asymmetry without crashing on a missing unitlists.empty')

for _,relation in ipairs({'FACING','SEEING'}) do
for _,direction in ipairs({'Right','Up','Left','Down','Mid','None'}) do
 for _,params in ipairs({{'ROCK'},{'ROCK','AND','ROCK'},{'RIGHT'},{'NOT','ROCK'}}) do
  local row={'LEVEL',relation};for _,word in ipairs(params) do row[#row+1]=word end
  row[#row+1]='BECOME';row[#row+1]='FLAG'
  local tree,parent=fixture({row},{{'rock',-1,0}})
  local w=RW_GetActiveLevel(tree).world
  local dirs={Right=0,Up=1,Left=2,Down=3,Mid=4,None=4};w.level_surrounds.dir=dirs[direction]
  local f=assert(RW_CompileWorld(w,cs));assert(#f.deferred==0)
  local n=act(tree,wait)
  local expected=direction=='Left' and params[1]=='ROCK' or direction~='Left' and direction~='Mid' and direction~='None' and params[1]=='NOT'
  assert((n.active_id==parent)==expected,direction..':'..table.concat(params,' '))
 end
end
end
print('PASS: scoped LEVEL FACING/SEEING uses saved entrance direction/region, repeatable names, literal direction arguments, none-facing and whole-tree Undo')

for _,case in ipairs({
 {params={'LEVEL'},fires=true}, {params={'LEVEL','AND','LEVEL'},fires=false},
 {params={'EMPTY'},fires=false}, {params={'NOT','EMPTY'},fires=true},
 {params={'ROCK'},fires=false}, {params={'ROCK'},negative=true,fires=true}
}) do
 local row={'LEVEL'};if case.negative then row[#row+1]='NOT' end
 row[#row+1]='FACEDBY';for _,word in ipairs(case.params) do row[#row+1]=word end
 row[#row+1]='BECOME';row[#row+1]='FLAG'
 local tree,parent=fixture({row},{{'rock',-1,0},{'rock',1,0},{'rock',0,1},{'rock',0,-1}})
 local f=assert(RW_CompileWorld(RW_GetActiveLevel(tree).world,cs));assert(#f.deferred==0)
 local n=act(tree,wait);assert((n.active_id==parent)==case.fires,table.concat(row,' '))
end
print('PASS: scoped LEVEL FACEDBY fixed child origin, parent independence, single LEVEL witness, default EMPTY/NOT and tree conversion/Undo')

for _,destroy in ipairs({false,true}) do for _,negative in ipairs({false,true}) do
 local row=negative and {'LEVEL','NOT','ON','ROCK','IS','WIN'} or {'LEVEL','ON','ROCK','IS','WIN'}
 local tree,parent=fixture({row});local w=RW_GetActiveLevel(tree).world
 w.entities[3]={id=3,kind='object',class='object',archetype='rock',x=25,y=25,direction='Right'}
 if destroy then
  w.entities[4]={id=4,kind='object',class='object',archetype='flag',x=25,y=25,direction='Right'}
  w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait='sink',target={kind='id',value=4}}}}
 end
 local n=act(tree,wait);local expected=negative==destroy
 assert((n.active_id==parent)==expected,'post-SINK scoped WIN:'..tostring(destroy)..':'..tostring(negative))
end end
print('PASS: frozen scoped LEVEL WIN retracts/activates after SINK deletes child witnesses, with tree outcome priority and Undo')

local tree=fixture({{'LEVEL','ON','ROCK','IS','WIN'}});local w=RW_GetActiveLevel(tree).world
w.entities[3]={id=3,kind='object',class='object',archetype='rock',x=25,y=25,direction='Right'}
w.entities[4]={id=4,kind='object',class='object',archetype='flag',x=25,y=25,direction='Right'}
w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait='sink',target={kind='id',value=4}}}}
local broken_services={};for k,v in pairs(services) do broken_services[k]=v end
broken_services.level_traits=function(current,rules)
 if not current.entities[3] then return nil,'injected_scoped_refresh_failure' end
 return RW_QueryLevelTraits(current,rules)
end
local p,e=RW_PlanLevelAction(tree,wait,broken_services)
assert(not p and e.reason=='injected_scoped_refresh_failure')
assert(w.entities[3] and w.entities[4] and RW_GetActiveLevel(tree).world==w and not w._condition_rules)
print('PASS: late scoped property refresh failure rejects atomically without deleting source entities or leaking query state')

for _,traits in ipairs({{'WIN','DEFEAT'},{'DEFEAT','WIN'},{'WIN','WIN'}}) do
 local tree=fixture({{'LEVEL','IS',traits[1],'AND',traits[2]}})
 local w=RW_GetActiveLevel(tree).world;local f=assert(RW_CompileWorld(w,cs))
 local projected=assert(RW_QueryLevelTraits(w,f.rules))
 assert(#projected==2 and projected[1]==traits[1]:lower() and projected[2]==traits[2]:lower())
end
print('PASS: frozen scoped projection preserves WIN/DEFEAT declaration order and duplicate property instances')

services.make=function(w,r,c,rules)
 local products,rng=RW_PlanMakeProducts(w,r,c)
 local plan,why=RW_PlanCreate(w,products);if not plan then return nil,why end
 plan.random_state=rng;return plan
end
for _,negative in ipairs({false,true}) do
 local row=negative and {'LEVEL','NOT','ON','ROCK','IS','WIN'} or {'LEVEL','ON','ROCK','IS','WIN'}
 local tree,parent=fixture({row,{'AVATAR','MAKE','ROCK'}})
 local n=act(tree,wait);assert((n.active_id==parent)==not negative)
end
local tree,parent=fixture({{'LEVEL','ON','FLAG','IS','WIN'},{'ROCK','HAS','FLAG'}})
local w=RW_GetActiveLevel(tree).world
w.entities[3]={id=3,kind='object',class='object',archetype='rock',x=25,y=25,direction='Right'}
w.entities[4]={id=4,kind='object',class='object',archetype='crate',x=25,y=25,direction='Right'}
w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait='sink',target={kind='id',value=4}}}}
local n=act(tree,wait);assert(n.active_id==parent)
local tree=fixture({{'LEVEL','IS','SAFE'}});local count=0
local counted={};for k,v in pairs(services) do counted[k]=v end
counted.level_traits=function(w,rules) count=count+1;return RW_QueryLevelTraits(w,rules) end
local p,e=RW_PlanLevelAction(tree,wait,counted);assert(p,e and e.reason)
assert(count==1,'no-op contact phases must reuse the freshly compiled scoped traits')
local committed,result=RW_CommitLevelTree(tree,p);assert(result.accepted)
assert(RW_GetActiveLevel(RW_UndoLevelTree(committed)).world==RW_GetActiveLevel(tree).world)
print('PASS: MAKE/HAS newborn witnesses refresh scoped WIN; no-op contacts reuse compiled traits with one final query')

for _,case in ipairs({
 {rows={{'LEVEL','WRITE','ROCK'}},fires=true,token='ROCK'},
 {rows={{'IDLE','LEVEL','WRITE','SAFE'}},fires=true,token='SAFE'},
 {rows={{'LEVEL','WRITE','IS'}},fires=true,token='IS'},
 {rows={{'LEVEL','WRITE','LEVEL'}},fires=true,token='LEVEL'},
 {rows={{'LEVEL','WRITE','ROCK'},{'LEVEL','WRITE','NOT','ROCK'}},fires=false},
 {rows={{'LEVEL','WRITE','ROCK'},{'LEVEL','IS','NOT','TEXT'}},fires=false},
 {rows={{'LEVEL','WRITE','ROCK'},{'LEVEL','IS','LEVEL'}},fires=false},
 {rows={{'LEVEL','WRITE','ROCK'},{'LEVEL','IS','BROKEN'}},fires=false}
}) do
 local tree,parent=fixture(case.rows);local w=RW_GetActiveLevel(tree).world
 local f=assert(RW_CompileWorld(w,cs));assert(#f.deferred==0)
 local n=act(tree,wait);assert((n.active_id==parent)==case.fires,table.concat(case.rows[1],' '))
 if case.fires then assert(RW_GetActiveLevel(n).world.entities[1].text.name==case.token) end
end
print('PASS: scoped LEVEL WRITE noun/property/syntax/LEVEL products, input conditions, own NOT, IS NOT TEXT, identity/BROKEN and Undo')

local tree,parent=fixture({{'LEVEL','WRITE','ROCK'},{'LEVEL','WRITE','ROCK'}})
local n=act(tree,wait);local w=RW_GetActiveLevel(n).world
assert(n.active_id==parent and w.entities[1].text.name=='ROCK' and w.entities[10].text.name=='ROCK')
local tree,parent=fixture({{'LEVEL','IS','FLAG'},{'LEVEL','WRITE','ROCK'}})
local n=act(tree,wait);local w=RW_GetActiveLevel(n).world
assert(n.active_id==parent and w.entities[1].archetype=='flag' and w.entities[10].text.name=='ROCK')
local tree,parent=fixture({{'LEVEL','WRITE','ALL'},{'LEVEL','WRITE','NOT','ROCK'}})
local f=assert(RW_CompileWorld(RW_GetActiveLevel(tree).world,cs));local count=0
for _,r in ipairs(f.relations) do if r.op=='transform_level' then assert(r.target_type~='text_rock');count=count+1 end end
assert(count==#RW_NounPalette(RW_GetActiveLevel(tree).world))
local tree,parent=fixture({{'LEVEL','WRITE','ALL'},{'LEVEL','WRITE','NOT','ALL'}})
local n=act(tree,wait);assert(n.active_id==tree.active_id)
local tree,parent=fixture({{'LEVEL','IS','TEXT'},{'LEVEL','IS','NOT','TEXT'}})
local n=act(tree,wait);assert(n.active_id==tree.active_id and RW_GetActiveLevel(n).world.entities[2].class=='object')
local tree,parent=fixture({{'NOT','IDLE','LEVEL','WRITE','ROCK'}})
local n=act(tree,wait);assert(n.active_id==tree.active_id)
local n=act(tree,right);assert(n.active_id==parent and RW_GetActiveLevel(n).world.entities[1].text.name=='ROCK')
-- Physical Level conversions retain their own spatial condition queries.
local tree=fixture({{'LEVEL','ON','ROCK','WRITE','SAFE'},{'LEVEL','NOT','ON','ROCK','WRITE','NOT','SAFE'}})
local w=RW_GetActiveLevel(tree).world
w.entities[3]={id=3,kind='object',class='object',archetype='rock',x=20,y=20,direction='Right'}
local f=assert(RW_CompileWorld(w,cs));local physical={}
for _,r in ipairs(f.relations) do if r.op=='write_text' or r.op=='forbid_transform' or r.op=='protect_transform' then physical[#physical+1]=r end end
local ops=assert(RW_PlanConversions(w,physical,f.rules))
local retyped=false;for _,op in ipairs(ops) do if op.entity_id==2 and op.kind=='retype' then assert(op.to.text.name=='SAFE');retyped=true end end
assert(retyped)
print('PASS: scoped WRITE duplicates/mixed ordered products, ALL own bans, IS Text denial, input refresh and physical Level conversion')

local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]],'rb'))
local source=f:read('*a');f:close()
local scoped=assert(source:match('function dolevelconversions%(%)%s*if.-then%s*(local mats = levelconversions.-)\n\t\tif %(#levelmats > 0%)'))
local env=setmetatable({unitreference={flag='flag',text_rock='text_rock'},tileslist={flag={name='flag'},text_rock={name='text_rock'}},
 changes={},MF_alert=function() end,testcond=function(c) return c.enabled~=false end,destroylevel=function() error('unexpected destruction') end},{__index=_G})
local oracle=assert(load('return function() '..scoped..' return levelmats end','@original_scoped_WRITE_selection','t',env))()
local checked=0
for copies=0,3 do for _,enabled in ipairs({false,true}) do for _,first in ipairs({false,true}) do
 local rows,mats={},{}
 if first then rows[#rows+1]={'LEVEL','IS','FLAG'};mats[#mats+1]={'flag',{},'is'} end
 for i=1,copies do rows[#rows+1]={'IDLE','LEVEL','WRITE','ROCK'};mats[#mats+1]={'rock',{enabled=enabled},'write'} end
 if not first then rows[#rows+1]={'LEVEL','IS','FLAG'};mats[#mats+1]={'flag',{},'is'} end
 local tree=fixture(rows);local w=RW_GetActiveLevel(tree).world;w.last_input=enabled and 'wait' or 'move'
 local frame=assert(RW_CompileWorld(w,cs));local got={}
 for _,r in ipairs(frame.relations) do if r.op=='transform_level' then got[#got+1]=r.target_type end end
 env.levelconversions=mats;local expected=oracle();assert(#got==#expected)
 for i,target in ipairs(expected) do assert(got[i]==target) end
 checked=checked+1
end end end
assert(checked==16);print('PASS: installed scoped WRITE ordered/conditional/duplicate mixed IS product-selection oracle (16 cases)')

for _,ban in ipairs({'WRITE','IS'}) do for _,action in ipairs({wait,right}) do
 local words=ban=='WRITE' and {'IDLE','LEVEL','WRITE','NOT','ROCK'} or {'IDLE','LEVEL','IS','NOT','TEXT'}
 local tree,parent=fixture({{'LEVEL','WRITE','ROCK'},words})
 local n=act(tree,action);assert((n.active_id==parent)==(action==right))
end end
print('PASS: scoped WRITE own/IS NOT TEXT conditional bans refresh independently for move versus wait')
