local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={status_required=RW_StatusInitializationNeeded,status=RW_PlanRuleStatus,
    active=RW_GetActiveLevel,update=RW_UpdateActiveLevel,update_instance=RW_UpdateLevelInstance,
    enter=RW_EnterLevel,return_level=RW_ReturnLevel,selectors=RW_LevelSelectorIDs,place_selectors=RW_PlaceLevelSelectors,
    bind_entry=RW_BindLevelEntry,commit_session=RW_Commit,outcome=RW_RecordLevelOutcome,candidates=RW_LevelSelectionCandidates,
    win=RW_HasWinContact,level_outcome=RW_ResolveLevelPropertyOutcome,
    project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules,f.code_status end}
services.initialize=function(w) return RW_InitializeLevelWorld(w,services) end
local function world(name,blocked)
    local w=RW_CreateSession().world;w.height=24;w.language.nouns.BOUNDARY_MARKER=name
    w.language.nouns.CURSOR="cursor";w.language.nouns.ROCK="rock";w.language.properties.BROKEN="broken"
    w.entities={
        [1]={id=1,kind="object",class="object",archetype="cursor",x=2,y=2,direction="Right"},
        [2]={id=2,kind="object",class="object",archetype="level_block",x=2,y=2,direction="None",
            level_link=name=="root" and {target="child",definition_id="child",source_type="level_block"} or {target="parent",source_type="level_block"}},
        [3]={id=3,kind="object",class="object",archetype="avatar",x=8,y=2,direction="Down"},
        [4]={id=4,kind="object",class="object",archetype="rock",x=9,y=2,direction="Left",broken=1}}
    w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={
        {op="grant_trait",target={kind="archetype",value="cursor"},trait="select"},
        {op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
    w.next_entity_id=10
    local rows={{"AVATAR","IS","BROKEN"}}
    if blocked then rows[#rows+1]={"CURSOR","IS","BROKEN"} end
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=5+row*2,direction="None"}
    end end
    return w
end
local function fixture(blocked)
    local defs={root=assert(RW_CreateLevelDefinition("root",world("root",false))),
        child=assert(RW_CreateLevelDefinition("child",world("child",blocked)))}
    return assert(RW_CreateLevelTree(defs,"root"))
end
local function initialize(tree)
    return assert(RW_InitializeLevelBoundary(tree,{tree.active_id},services))
end
local function step(tree,action)
    local plan,e=RW_PlanLevelAction(tree,action,services);assert(plan,e and e.reason)
    local n,r=RW_CommitLevelTree(tree,plan);assert(r.accepted,r.reason)
    return n
end
local raw=fixture(false);local initial=RW_GetActiveLevel(raw).world
local root=initialize(raw);local w=RW_GetActiveLevel(root).world
assert(w.entities[3].broken==1 and w.entities[4].broken==0)
assert(not initial.entities[3].broken and initial.entities[4].broken==1)
assert(#root.history==0 and #RW_GetActiveLevel(root).history==0)
assert(w.next_entity_id==initial.next_entity_id and w.chance_seed==initial.chance_seed and w.random_state==initial.random_state and w.last_input==initial.last_input)
assert(not root.definitions.root.initial_world.entities[3].broken,"initializer mutated authored definition")
local child=step(root,{type="confirm"});local childid=child.active_id
assert(childid~=root.active_id and child.instances[root.active_id].world.entities[3].broken==1)
assert(RW_GetActiveLevel(child).world.entities[3].broken==1 and RW_GetActiveLevel(child).world.entities[4].broken==0)
assert(#child.history==1 and #RW_GetActiveLevel(child).history==0)
local returned=step(child,{type="confirm"})
assert(returned.active_id==root.active_id and returned.instances[childid].world.entities[3].broken==1)
assert(RW_GetActiveLevel(returned).world.entities[3].broken==1 and #returned.history==2)
assert(RW_UndoLevelTree(returned).active_id==childid)
local undone=RW_UndoLevelTree(child);assert(undone.active_id==root.active_id and undone.instances[root.active_id].world==w)
-- First confirm in a newly loaded child sees BROKEN before any move/wait input.
root=initialize(fixture(true));child=step(root,{type="confirm"})
assert(RW_GetActiveLevel(child).world.entities[1].broken==1)
local rejected,e=RW_PlanLevelAction(child,{type="confirm"},services)
assert(not rejected and e.reason=="no_selected_level" and #child.history==1)
-- A failed child initializer discards the whole boundary, including parent reset
-- and newly allocated child instance; the original tree is unchanged.
root=initialize(fixture(false));local failing={};for k,v in pairs(services) do failing[k]=v end
failing.initialize=function(w) if w.language.nouns.BOUNDARY_MARKER=="child" then return nil,"child_initialization_failure" end return services.initialize(w) end
rejected,e=RW_PlanLevelAction(root,{type="confirm"},failing)
assert(not rejected and e.reason=="child_initialization_failure" and root.next_instance_id==2 and #root.history==0)
assert(not root.instances["instance:2"] and RW_GetActiveLevel(root).world.entities[3].broken==1)
-- Unrelated suspended siblings are not reinitialized as part of another entry.
local sibling=assert(RW_EnterLevel(root,"sibling","child"));local siblingid=sibling.active_id
root=initialize(assert(RW_ReturnLevel(sibling)));local saved=root.instances[siblingid]
child=step(root,{type="confirm"});assert(child.instances[siblingid]==saved)
-- A normal WIN exit uses the same reload initialization and whole-tree Undo.
local parent_world=world("root",false);local child_world=world("child",false)
child_world.entities[5]={id=5,kind="object",class="object",archetype="flag",x=9,y=2,direction="None"}
child_world.rule_sources[#child_world.rule_sources+1]={when={op="always"},effects={
    {op="grant_trait",target={kind="archetype",value="rock"},trait="you"},
    {op="grant_trait",target={kind="archetype",value="flag"},trait="win"}}}
local defs={root=assert(RW_CreateLevelDefinition("root",parent_world)),child=assert(RW_CreateLevelDefinition("child",child_world))}
root=initialize(assert(RW_CreateLevelTree(defs,"root")));child=step(root,{type="confirm"})
returned=step(child,{type="wait"})
assert(returned.active_id==root.active_id and returned.outcomes[child.active_id].kind=="win")
assert(RW_GetActiveLevel(returned).world.entities[3].broken==1)
undone=RW_UndoLevelTree(returned);assert(undone.active_id==child.active_id and RW_GetActiveLevel(undone).world==RW_GetActiveLevel(child).world)
-- A scoped LEVEL conversion changes the parent entrance. After selector placement
-- at that entrance, conditional BROKEN must use its final position before F.
local function sentence(w,words,y)
    for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=y,direction="None"}
    end
end
parent_world=world("root",false);parent_world.entities[2].x=3
sentence(parent_world,{"CURSOR","ON","ROCK","IS","BROKEN"},11)
child_world=world("child",false);child_world.language.nouns.LEVEL={tag="level",block_type="level_block"}
sentence(child_world,{"LEVEL","IS","ROCK"},11)
defs={root=assert(RW_CreateLevelDefinition("root",parent_world)),child=assert(RW_CreateLevelDefinition("child",child_world))}
root=initialize(assert(RW_CreateLevelTree(defs,"root")))
root=step(root,{type="move",dx=1,dy=0});child=step(root,{type="confirm"})
returned=step(child,{type="wait"})
w=RW_GetActiveLevel(returned).world
assert(returned.active_id==root.active_id and w.entities[2].archetype=="rock")
assert(w.entities[1].x==3 and w.entities[1].broken==1,"selector status used authored rather than final entry position")
rejected,e=RW_PlanLevelAction(returned,{type="confirm"},services);assert(not rejected and e.reason=="no_selected_level")
assert(RW_UndoLevelTree(returned).active_id==child.active_id)
-- A parent compile terminal created by a persistent entrance conversion commits
-- that boundary and returns an only-Undo board, rather than rejecting the trigger.
for _,with_broken in ipairs({false,true}) do
    parent_world=world("root",false)
    if not with_broken then parent_world.entities[12].text.name="YOU";parent_world.entities[4].broken=nil end
    child_world=world("child",false);child_world.language.nouns.LEVEL={tag="level",block_type="level_block"}
    sentence(child_world,{"LEVEL","IS","ROCK"},11)
    defs={root=assert(RW_CreateLevelDefinition("root",parent_world)),child=assert(RW_CreateLevelDefinition("child",child_world))}
    root=initialize(assert(RW_CreateLevelTree(defs,"root")));child=step(root,{type="confirm"})
    local guarded={};for k,v in pairs(services) do guarded[k]=v end
    guarded.evaluate=function(w)
        assert(not w.infinite_loop and not w.too_complex,"terminal boundary was compiled again")
        if w.language.nouns.BOUNDARY_MARKER=="root" and w.entities[2].archetype=="rock" then return nil,"word_rule_limit" end
        return services.evaluate(w)
    end
    guarded.initialize=function(w) return RW_InitializeLevelWorld(w,guarded) end
    local p,e=RW_PlanLevelAction(child,{type="wait"},guarded);assert(p,e and e.reason)
    local locked,result=RW_CommitLevelTree(child,p);assert(result.accepted,result.reason)
    assert(locked.active_id==root.active_id and RW_GetActiveLevel(locked).world.infinite_loop)
    assert(RW_GetActiveLevel(locked).world.entities[2].archetype=="rock" and RW_UndoLevelTree(locked).active_id==child.active_id)
end
-- Fast path: a board with no possible BROKEN source never compiles again at boot.
w=RW_CreateSession().world
local no_compile={status_required=RW_StatusInitializationNeeded,status=RW_PlanRuleStatus,
    evaluate=function() error("plain board initialization compiled") end}
assert(RW_InitializeLevelWorld(w,no_compile)==w)
-- Property aliases and object WORD tokens must also activate the detector.
w=world("root",false);w.language.properties.DAMAGED="broken";w.language.properties.BROKEN=nil
w.entities[12].text.name="DAMAGED"
assert(RW_StatusInitializationNeeded(w) and assert(RW_InitializeLevelWorld(w,services)).entities[3].broken==1)
w=RW_CreateSession().world;w.height=24;w.language.nouns.ROCK="rock";w.language.nouns.DAMAGED="rock";w.language.properties.DAMAGED="broken"
w.entities={
    [1]={id=1,kind="object",class="object",archetype="avatar",x=8,y=2,direction="None"},
    [2]={id=2,kind="object",class="object",archetype="rock",x=3,y=6,direction="None"}}
w.next_entity_id=10
for row,words in ipairs({{"AVATAR","IS"},{"ROCK","IS","WORD"}}) do for x,word in ipairs(words) do
    local id=w.next_entity_id;w.next_entity_id=id+1
    w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row==1 and 6 or 9,direction="None"}
end end
assert(RW_StatusInitializationNeeded(w) and assert(RW_InitializeLevelWorld(w,services)).entities[1].broken==1)
-- Compile terminals are represented on the loaded board without input/RNG/history.
for _,case in ipairs({{"word_rule_limit","infinite_loop"},{"rule_complexity_limit","too_complex"}}) do
    local terminal_services={};for k,v in pairs(services) do terminal_services[k]=v end
    terminal_services.evaluate=function() return nil,case[1] end
    local loaded=assert(RW_InitializeLevelWorld(w,terminal_services))
    assert(loaded[case[2]] and not w[case[2]] and loaded.chance_seed==w.chance_seed)
end
local status_failure={};for k,v in pairs(services) do status_failure[k]=v end
status_failure.status=function() return nil,"word_rule_limit" end
assert(assert(RW_InitializeLevelWorld(w,status_failure)).infinite_loop and not w.infinite_loop)
print("PASS: BROKEN boot/entry/return initialization, first-confirm SELECT gating, runtime reset, tree Undo/allocator purity, sibling isolation, aliases/WORD and terminal boards")
