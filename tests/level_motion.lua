-- Unchanged installed levelblock motion branches with host scrolling captured.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local blocks,tools=read('blocks.lua'),read('tools.lua')
local a=assert(blocks:find('elseif (action == "move") then',1,true))
local b=assert(blocks:find('elseif (action == "empty") then',a,true))
local env=setmetatable({ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}},tilesize=1},{__index=_G})
local native=assert(load('return function(action,lstill,lsleep) if false then '..blocks:sub(a,b-1)..' end end','@installed_level_motion','t',env))()
local function install(first,last)
 local x=assert(tools:find('function '..first..'(',1,true));local y=assert(tools:find('function '..last..'(',x+1,true))
 assert(load(tools:sub(x,y-1),'@installed_'..first,'t',env))()
end
install('cantmove','findnoun');install('reversedir','reversecheck');install('reversecheck','simplecheck')
local names={'Right','Up','Left','Down','None'}
local cases,start_cases=0,0
local sequences={{'move'},{'move','move'},{'chill'},{'chill','move'},{'move','chill'},
 {'chill','chill','move'},{'nudgeright','nudgeup','nudgeleft','nudgedown'},
 {'fall'},{'fallright'},{'fallup'},{'fallleft'},
 {'fall','fallright','fallup','fallleft','move','chill','move'},
 {'turn'},{'deturn'},{'turn','move'},{'move','turn'},
 {'chill','turn','move'},{'turn','deturn','move'},
 {'turn','turn','turn','turn'},{'deturn','deturn'},
 {'turn','nudgeright','fall','chill','deturn','move'}}
for dir=0,4 do for reverse=0,2 do for _,sleep in ipairs({false,true}) do
 for _,lock in ipairs({'none','still','lockedright','lockedup','lockedleft','lockeddown'}) do
  for _,sequence in ipairs(sequences) do for _,seed in ipairs({1,2,17}) do
   local traits,counts={},{}
   local function add(t) traits[#traits+1]=t;counts[t]=(counts[t] or 0)+1 end
   for _,t in ipairs(sequence) do add(t) end
   for i=1,reverse do add('reverse') end
   if sleep then add('sleep') end;if lock~='none' then add(lock) end
   env.hasfeature=function(_,_,trait) return counts[trait] and 1 or nil end
   env.hasfeature_count=function(_,_,trait) return counts[trait] or 0 end
   env.featureindex=reverse>0 and {reverse={}} or {}
   env.addundo=function() end
   env.mapdir,env.Xoffset,env.Yoffset=dir,3,-2
   env.maprotation=({[1]=0,[2]=90,[17]=270})[seed]
   local old_rotation=env.maprotation
   env.MF_levelrotation=function() end
   env.MF_scrollroom=function(x,y) env.Xoffset,env.Yoffset=env.Xoffset+x,env.Yoffset+y end
   local rng=seed
   env.fixedrandom=function() rng=(rng*48271)%2147483647;return rng%4 end
   local still=env.cantmove('level',1,env.mapdir)
   for _,t in ipairs(traits) do env.rule={'level','is',t};native(t,still,sleep) end
   local w={entities={},board_offset={x=3,y=-2,direction=names[dir+1],rotation=old_rotation},random_state=seed}
   local p=RW_ResolveLevelMotion(w,traits)
   local shift=p.board_shift and p.board_shift.to or w.board_offset
   assert(shift.x==env.Xoffset and shift.y==env.Yoffset,'installed LEVEL scroll mismatch')
   assert(shift.direction==names[env.mapdir+1],'installed LEVEL facing mismatch')
   assert((shift.rotation or 0)==env.maprotation,'installed LEVEL rotation mismatch')
   assert((p.random_state and p.random_state.to or seed)==rng,'LEVEL RNG draw order mismatch')
   assert(w.board_offset.x==3 and w.random_state==seed,'motion preview mutated input')
   cases=cases+1
  end end
 end
end end end
-- startblock assigns the last active cardinal declaration without sleep/locks.
do
 local first=assert(blocks:find('if (light == false) and (featureindex["level"] ~= nil) then',1,true))
 local last=assert(blocks:find('for i,unit in ipairs(units) do',first,true))
 local start=assert(load('return function(light) '..blocks:sub(first,last-1)..' end','@installed_level_start','t',env))()
 env.testcond=function(conds) return conds.active end
 local rows={{},{'right'},{'up'},{'left'},{'down'},{'right','left'},
  {'up','up','down','right'},{'sleep','still','right'},{'turn','left','deturn'}}
 for dir=0,4 do for rotation=0,270,90 do for _,row in ipairs(rows) do for disabled=0,#row do
  local entries,traits={},{}
  for i,t in ipairs(row) do entries[#entries+1]={{'level','is',t},{active=i~=disabled}}
   if i~=disabled then traits[#traits+1]=t end
  end
  env.featureindex={level=entries};env.mapdir=dir;env.maprotation=rotation
  start(false)
  local old={x=3,y=4,direction=names[dir+1],rotation=rotation}
  local p=RW_ResolveLevelStart({board_offset=old},traits)
  local to=p.board_shift and p.board_shift.to or old
  assert(to.direction==names[env.mapdir+1] and (to.rotation or 0)==env.maprotation,'installed startblock rotation mismatch')
  assert(to.x==3 and to.y==4)
  start_cases=start_cases+1
 end end end end
end
-- Absent map state retains native Down across successive accepted MOVE turns.
do
 local s=RW_CreateSession();local p=RW_ResolveLevelMotion(s.world,{'move'})
 local n,r=RW_Commit(s,p);assert(r.accepted and n.world.board_offset.y==1 and n.world.board_offset.direction=='Down')
 local n2,r=RW_Commit(n,RW_ResolveLevelMotion(n.world,{'move'}));assert(r.accepted and n2.world.board_offset.y==2)
 assert(RW_Undo(n2).world==n.world and RW_Undo(n).world==s.world)
 local _,bad=RW_Commit(n,p);assert(not bad.accepted and bad.reason=='stale_board_shift')
end

local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,
 project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,
 refresh=RW_EvaluateRules,level_traits=RW_QueryLevelTraits,orient=RW_ResolveOrientation,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
  births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
  return f.effects,nil,f.relations,f.rules,f.code_status end,
 level_motion=function(w,traits)
  local stop
  for index,trait in ipairs(traits) do if RW_ResolveLevelPropertyOutcome(w,{trait}) then stop=index;break end end
  return RW_ResolveLevelMotion(w,traits,stop)
 end}
services.level_start=function(w)
 if not RW_LevelStartNeeded(w) then return {consumes_turn=true,changes={}} end
 local frame,e=RW_CompileWorld(w,cs);if not frame then return nil,e.reason end
 local traits,e=RW_QueryLevelTraits(w,frame.rules);if not traits then return nil,e end
 return RW_ResolveLevelStart(w,traits)
end
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.entities={};w.width,w.height=32,32;w.next_entity_id=1
 w.language.nouns.LEVEL={tag='level',block_type='level_block'}
 w.language.properties.CHILL='chill';w.language.properties.MOVE='move'
 w.language.properties.FALL='fall';w.language.properties.FALLRIGHT='fallright'
 w.language.properties.NUDGERIGHT='nudgeright';w.language.properties.LOCKEDDOWN='lockeddown'
 w.language.prefixes=w.language.prefixes or {};w.language.prefixes.IDLE='idle'
 w.language.operators={AND='and',NOT='not'}
 for y,row in ipairs(rows) do for x,token in ipairs(row) do
  local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=token},x=x,y=2*y,direction='None'}
 end end
 return s
end
local function turn(s,action)
 local p,e=RW_PlanTurn(s.world,action or {type='wait'},services);assert(p,e and e.stage..':'..tostring(e.reason))
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 assert(RW_Undo(n).world==s.world,'scoped motion Undo lost earlier phases')
 return n,p
end
do
 local s=fixture({{'LEVEL','IS','RIGHT'},{'LEVEL','IS','LEFT'},{'LEVEL','IS','SLEEP'}})
 local w=assert(RW_InitializeLevelWorld(s.world,services))
 assert(w.board_offset.direction=='Left' and w.board_offset.rotation==270)
 assert(not w.random_state and not w.last_input and not w.chance_seed and #s.history==0 and not s.world.board_offset)
 local valid=RW_CreateLevelDefinition('rotation',w);assert(valid)
 local bad=RW_ResolveLevelStart(w,{'up'});bad.board_shift.from.rotation=90
 local _,r=RW_Commit({world=w,history={}},bad);assert(not r.accepted and r.reason=='stale_board_shift')
 local bad=RW_ResolveLevelStart(w,{'up'});bad.board_shift.to.rotation=45
 local _,r=RW_Commit({world=w,history={}},bad);assert(not r.accepted and r.reason=='invalid_board_shift')
 local badworld={};for k,v in pairs(w) do badworld[k]=v end
 badworld.board_offset={x=0,y=0,direction='Right',rotation=45}
 assert(not RW_CreateLevelDefinition('bad_rotation',badworld))
 local no=fixture({{'LEVEL','IS','RIGHT'},{'LEVEL','IS','NOT','RIGHT'}})
 assert(not RW_InitializeLevelWorld(no.world,services).board_offset)
 local no=fixture({{'LEVEL','IS','RIGHT'},{'LEVEL','IS','BROKEN'}})
 assert(not RW_InitializeLevelWorld(no.world,services).board_offset)
 local no=fixture({{'IDLE','LEVEL','IS','RIGHT'}})
 assert(not RW_InitializeLevelWorld(no.world,services).board_offset)
 local world={entities={},rule_sources={},language={nouns={},properties={}}}
 assert(not RW_LevelStartNeeded(world))
 world.entities[1]={class='text',text={name='R'}};world.entities[2]={class='object',archetype='custom_level'}
 world.language={nouns={L={tag='level',block_type='custom_level'}},properties={R='right'}}
 assert(RW_LevelStartNeeded(world),'WORD/custom LEVEL candidate missed boot orientation guard')
 local saved=services.level_start;services.level_start=function() return nil,'rule_complexity_limit' end
 local w=assert(RW_InitializeLevelWorld(s.world,services));assert(w.too_complex and not w.board_offset)
 services.level_start=function() error('terminal init must not query orientation') end
 assert(RW_InitializeLevelWorld(w,services)==w)
 services.level_start=saved
end
local s=fixture({{'LEVEL','IS','CHILL','AND','MOVE'}})
local n,p=turn(s);assert(n.world.random_state==48271 and n.world.board_offset.x==0 and n.world.board_offset.y==2)
assert(n.world.board_offset.direction=='Down')
assert(p.stages[#p.stages].name=='level_motion')
local turned=fixture({{'LEVEL','IS','CHILL','AND','TURN','AND','MOVE'}})
local t=turn(turned);assert(t.world.board_offset.x==-1 and t.world.board_offset.y==1
 and t.world.board_offset.direction=='Left' and t.world.board_offset.rotation==0)
local sleeping=fixture({{'LEVEL','IS','TURN'},{'LEVEL','IS','SLEEP'},{'LEVEL','IS','STILL'}})
local t=turn(sleeping);assert(t.world.board_offset.direction=='Left' and t.world.board_offset.rotation==0)
local moving=fixture({{'LEVEL','IS','YOU'}});moving.world.board_offset={x=0,y=0,direction='Down',rotation=270}
local t=turn(moving,{type='move',dx=1,dy=0});assert(t.world.board_offset.x==1 and t.world.board_offset.rotation==270)
do
 local s=RW_CreateSession();s.world.board_offset={x=0,y=0,direction='Down',rotation=0}
 local p=RW_ResolveLevelMotion(s.world,{'turn','turn','turn','turn'})
 assert(p.board_shift.to.direction=='Down' and p.board_shift.to.rotation==90 and RW_BackRetainDecision(s.world,p,false))
 local n,r=RW_Commit(s,p);assert(r.accepted and n.world.board_offset.rotation==90)
 local record=assert(RW_GetTurnRecord(n,1));assert(record.phases[1].board_shift.to.rotation==90)
 assert(RW_BackHistoryRows(s.world,record));assert(RW_Undo(n).world==s.world)
end
local n2=turn(s);assert(n2.world.random_state==n.world.random_state and n2.world.board_offset.y==2)
local s=fixture({{'LEVEL','IS','CHILL'},{'LEVEL','IS','SLEEP'},{'LEVEL','IS','FALLRIGHT'}})
local n=turn(s);assert(n.world.random_state==48271 and n.world.board_offset.x==35 and n.world.board_offset.y==0)
local s=fixture({{'LEVEL','IS','CHILL'},{'LEVEL','IS','LOCKEDDOWN'}})
local n=turn(s);assert(n.world.random_state==48271 and n.world.board_offset.y==0)
-- Native lstill uses the initial mapdir lock, not the CHILL draw direction.
s.world.random_state=2;local n=turn(s);assert(n.world.board_offset.x==0 and n.world.board_offset.y==0 and n.world.board_offset.direction=='Left')
local s=fixture({{'LEVEL','IS','MOVE'},{'LEVEL','IS','DEFEAT'},{'LEVEL','IS','CHILL'}})
local n=turn(s);assert(n.world.board_offset.y==1 and not n.world.random_state)
local s=fixture({{'LEVEL','IS','WIN'},{'LEVEL','IS','MOVE'}})
local n=turn(s);assert(n.world.board_offset.y==1,'WIN without YOU must not stop scoped motion')
local s=fixture({{'LEVEL','IS','YOU'},{'LEVEL','IS','WIN'},{'LEVEL','IS','CHILL'}})
local n=turn(s);assert(not n.world.random_state and not n.world.board_offset)
local s=fixture({{'IDLE','LEVEL','IS','MOVE'}})
local n=turn(s);assert(n.world.board_offset.y==1)
local n=turn(s,{type='move',dx=1,dy=0});assert(not n.world.board_offset)
local s=fixture({{'LEVEL','IS','CHILL'},{'LEVEL','IS','NOT','CHILL'}})
local n=turn(s);assert(not n.world.random_state and not n.world.board_offset)
local s=fixture({{'LEVEL','IS','CHILL'},{'LEVEL','IS','BROKEN'}})
local n=turn(s);assert(not n.world.random_state and not n.world.board_offset)
local s=fixture({{'LEVEL','IS','CHILL'},{'LEVEL','IS','SLEEP'}})
s.world.board_offset={x=4,y=5,direction='Down'}
local n,p=turn(s);assert(n.world.random_state==48271 and n.world.board_offset.x==4 and n.world.board_offset.y==5)
assert(not p.stages[#p.stages].plan.board_shift and p.stages[#p.stages].plan.random_state,'RNG-only scoped motion lost its stage')
local s=fixture({{'LEVEL','IS','CHILL'},{'TEXT','IS','CRASH'}})
local n=turn(s);assert(n.world.infinite_loop and not n.world.random_state and not n.world.board_offset)
local s=fixture({{'AVATAR','IS','YOU'},{'AVATAR','IS','DEFEAT'},{'LEVEL','IS','WIN'},{'LEVEL','IS','CHILL'}})
local id=s.world.next_entity_id;s.world.next_entity_id=id+1
s.world.entities[id]={id=id,kind='object',class='object',archetype='avatar',x=20,y=20,direction='Up'}
local n=turn(s);assert(not n.world.entities[id] and n.world.random_state==48271,'late LEVEL motion used pre-contact YOU evidence')
-- A stale RNG stage or late planner failure must not commit preceding phases.
local s=fixture({{'LEVEL','IS','CHILL'}});local n,p=turn(s)
local stage=p.stages[#p.stages];stage.plan.random_state.from=17
local _,r=RW_Commit(s,p);assert(not r.accepted and not s.world.random_state and not s.world.board_offset)
local good=services.level_motion;services.level_motion=function() return nil,'injected_level_motion_failure' end
local p,e=RW_PlanTurn(s.world,{type='wait'},services)
assert(not p and e.stage=='level_motion' and e.reason=='injected_level_motion_failure' and s.world.last_input==nil)
services.level_motion=good
-- Boundary work and scoped scroll remain one outer tree transaction.
do
 local child=fixture({{'LEVEL','IS','MOVE'},{'LEVEL','IS','WIN'}}).world
 child.rule_sources[#child.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait='you',target={kind='id',value=1}}}}
 local root=RW_CreateSession().world;root.entities={[1]={id=1,kind='object',class='object',archetype='level_block',x=3,y=3,direction='Down',
  level_link={target='child',definition_id='child',source_type='level_block'}}};root.next_entity_id=2
 local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition('root',root)),child=assert(RW_CreateLevelDefinition('child',child))},'root'))
 local parent=tree.active_id;tree=assert(RW_EnterLevel(tree,'1','child'));tree=assert(RW_BindLevelEntry(tree,1))
 for k,v in pairs({active=RW_GetActiveLevel,update=RW_UpdateActiveLevel,enter=RW_EnterLevel,return_level=RW_ReturnLevel,
  selectors=RW_LevelSelectorIDs,place_selectors=RW_PlaceLevelSelectors,bind_entry=RW_BindLevelEntry,commit_session=RW_Commit,
  outcome=RW_RecordLevelOutcome,candidates=RW_LevelSelectionCandidates,win=RW_HasWinContact,level_outcome=RW_ResolveLevelPropertyOutcome}) do services[k]=v end
 local before=RW_GetActiveLevel(tree).world
 local p,e=RW_PlanLevelAction(tree,{type='wait'},services);assert(p,e and e.reason)
 local n,r=RW_CommitLevelTree(tree,p);assert(r.accepted and n.active_id==parent and n.outcomes[tree.active_id].kind=='win')
 local undo=RW_UndoLevelTree(n);assert(undo.active_id==tree.active_id and RW_GetActiveLevel(undo).world==before)
end
-- Exercise the actual mapped bootstrap adapter, not just injected services.
do
 local root=fixture({{'LEVEL','IS','LEFT'}}).world
 local entrance=root.next_entity_id;root.next_entity_id=entrance+2
 root.entities[entrance]={id=entrance,kind='object',class='object',archetype='level_block',x=15,y=15,direction='Down',
  level_link={target='child',definition_id='child',source_type='level_block'}}
 root.entities[entrance+1]={id=entrance+1,kind='object',class='object',archetype='cursor',x=15,y=15,direction='Right'}
 local child=fixture({{'LEVEL','IS','RIGHT'},{'LEVEL','IS','TURN'}}).world
 local id=child.next_entity_id;child.next_entity_id=id+2
 child.entities[id]={id=id,kind='object',class='object',archetype='level_block',x=21,y=21,direction='Down',
  level_link={target='parent',source_type='level_block'}}
 child.entities[id+1]={id=id+1,kind='object',class='object',archetype='cursor',x=21,y=21,direction='Right'}
 local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition('root',root)),child=assert(RW_CreateLevelDefinition('child',child))},'root'))
 services.initialize=function(w) return RW_InitializeLevelWorld(w,services) end
 services.update_instance=RW_UpdateLevelInstance
 tree=assert(RW_InitializeLevelBoundary(tree,{tree.active_id},services))
 local parent=tree.active_id;assert(RW_GetActiveLevel(tree).world.board_offset.rotation==270)
 local function action(t,a)
  local p,e=RW_PlanLevelAction(t,a,services);assert(p,e and e.reason)
  local n,r=RW_CommitLevelTree(t,p);assert(r.accepted,r.reason);return n
 end
 tree=action(tree,{type='confirm'})
 assert(tree.active_id~=parent and RW_GetActiveLevel(tree).world.board_offset.rotation==90)
 tree=action(tree,{type='wait'})
 local before=RW_GetActiveLevel(tree).world;assert(before.board_offset.direction=='Down' and before.board_offset.rotation==90)
 local returned=action(tree,{type='confirm'})
 assert(returned.active_id==parent and RW_GetActiveLevel(returned).world.board_offset.rotation==270)
 local undo=RW_UndoLevelTree(returned)
 assert(undo.active_id==tree.active_id and RW_GetActiveLevel(undo).world==before,'boundary Undo lost map rotation/facing')
end
-- Exercise the actual mapped bootstrap adapter, not just injected services.
do
 local old_script,old_enum,old_render,old_definitions=script,Enum,RW_Render,RW_GetNavigationDefinitions
 local old_printerr=printerr;local display,depth;local listeners={};local mapped={}
 for _,name in ipairs({'world','reader','grammar','rules','properties','movement','renderer'}) do
  mapped[#mapped+1]={path=name,alive=true,Invoke=function(_,method,...) return assert(_G[method],method)(...) end}
 end
 local w=fixture({{'LEVEL','IS','CHILL','AND','MOVE'}}).world
 RW_GetNavigationDefinitions=function() return {test={id='test',initial_world=w}},'test' end
 RW_Render=function(world,d) display,depth=world,d end
 printerr=function(...) error(table.concat({...},' ')) end
 Enum={KeyEventType={KeyboardJumpKeyDown='wait',KeyboardCraftspersonKey12Down='undo',KeyboardInteractKeyDown='confirm'}}
 script={object={GetScripts=function() return mapped end,
  AddKeyEventListener=function(_,key,callback) if key then listeners[key]=callback end end}}
 OnStart();assert(display and not display.board_offset and depth==0)
 listeners.wait();assert(display.random_state==48271 and display.board_offset.y==2 and depth==1)
 listeners.undo();assert(not display.random_state and not display.board_offset and depth==0)
 w=fixture({{'LEVEL','IS','RIGHT'},{'LEVEL','IS','MOVE'}}).world
 OnStart();assert(display.board_offset.direction=='Right' and display.board_offset.rotation==90 and depth==0)
 listeners.wait();assert(display.board_offset.x==1 and display.board_offset.y==0 and display.board_offset.rotation==90)
 listeners.undo();assert(display.board_offset.x==0 and display.board_offset.rotation==90 and depth==0)
 script,Enum,RW_Render,RW_GetNavigationDefinitions,printerr=old_script,old_enum,old_render,old_definitions,old_printerr
end
print('PASS: LEVEL start orientation/rotation and late MOVE/CHILL/nudges/FALL/TURN/DETURN, conditions/NOT/BROKEN, terminal order, RNG/rollback/Undo; '..cases..' installed motion/lock and '..start_cases..' startblock oracle cases')
