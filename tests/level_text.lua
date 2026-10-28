-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules end}

services.active=RW_GetActiveLevel;services.update=RW_UpdateActiveLevel
services.enter=RW_EnterLevel;services.return_level=RW_ReturnLevel
services.selectors=RW_LevelSelectorIDs;services.place_selectors=RW_PlaceLevelSelectors
services.bind_entry=RW_BindLevelEntry;services.commit_session=RW_Commit
services.outcome=RW_RecordLevelOutcome;services.candidates=RW_LevelSelectionCandidates
services.win=RW_HasWinContact;services.level_outcome=RW_ResolveLevelPropertyOutcome
for _,dies in ipairs({false,true}) do
    local defs,root_id=RW_GetNavigationDefinitions()
    local w=defs['navigation.win'].initial_world
    w.entities[18].text.name='TEXT'
    if dies then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{
        op='grant_trait',target={kind='archetype',value='avatar'},trait='defeat'}}} end
    local root=assert(RW_CreateLevelTree(defs,root_id))
    local entered=assert(RW_EnterLevel(root,'37','navigation.win'))
    entered=assert(RW_BindLevelEntry(entered,37))
    local before=entered.instances[root.active_id].world.entities[37]
    local plan,e=RW_PlanLevelAction(entered,{type='move',dx=0,dy=-1},services)
    assert(plan,e and e.reason)
    local result,r=RW_CommitLevelTree(entered,plan);assert(r.accepted,r.reason)
    assert(result.active_id==root.active_id and result.outcomes[entered.active_id].kind=='transform')
    local block=RW_GetActiveLevel(result).world.entities[37]
    assert(block.class=='text' and block.text.name=='LEVEL' and block.level_link.definition_id==before.level_link.definition_id)
    assert(block.direction==before.direction and block.x==before.x and block.y==before.y)
    local deleted=false
    for _,change in ipairs(plan.changes) do
        if change.kind=='delete' and change.entity_id==1 then deleted=true end
    end
    assert(deleted==dies)
    local restored=RW_UndoLevelTree(result)
    assert(restored.active_id==entered.active_id and RW_GetActiveLevel(restored).world==RW_GetActiveLevel(entered).world)
    local reloaded=assert(RW_ReloadLevel(result,root.active_id))
    assert(RW_GetActiveLevel(reloaded).world.entities[37].text.name=='LEVEL')
    assert(block.level_link.definition_id=='navigation.win')
end
print('PASS: LEVEL IS TEXT with simultaneous YOU death, persistent linked text level and whole-tree Undo')
