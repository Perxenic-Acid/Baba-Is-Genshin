local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={status=RW_PlanRuleStatus,status_required=RW_StatusInitializationNeeded,
    orient=RW_ResolveOrientation,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world;w.height=32
    assert(w.language.properties.BROKEN=="broken","BROKEN missing from public vocabulary")
    w.language.nouns.ROCK="rock";w.language.nouns.CURSOR="cursor";w.language.nouns.FLAG="flag"
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=9,y=2,direction="Right"},
        [2]={id=2,kind="object",class="object",archetype="cursor",x=7,y=2,direction="Right"},
        [3]={id=3,kind="object",class="object",archetype="level_block",x=7,y=2,direction="None",level_link={target="child",definition_id="child",source_type="level_block"}},
        [4]={id=4,kind="object",class="object",archetype="rock",x=8,y=3,direction="Right"}}
    w.next_entity_id=10
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="Right"}
    end end
    return s
end
for _,case in ipairs({{"TEXT",false},{"ROCK",true},{"ROCK",false}}) do
    local rows={{case[1],"FACING","LEFT","IS","BROKEN"},{case[1],"IS","LEFT"}}
    if case[2] then rows[#rows+1]={"ROCK","IS","WORD"} end
    local s=fixture(rows);local p,e=RW_PlanTurn(s.world,{type="wait"},services);assert(p,e and e.reason)
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
    local id=case[1]=="TEXT" and 10 or 4
    assert(n.world.entities[id].direction=="Left")
    local barrier
    for i,stage in ipairs(p.stages) do if stage.name=="code_status_after_orientation" then barrier=i;assert(p.stages[i-1].name=="orientation") end end
    if case[1]=="TEXT" or case[2] then assert(barrier and n.world.entities[id].broken==1)
    else assert(not barrier and not n.world.entities[id].broken) end
    assert(RW_Undo(n).world==s.world and s.world.entities[id].direction=="Right")
end
local s=fixture({{"TEXT","FACING","LEFT","IS","BROKEN"},{"TEXT","IS","LEFT"}})
local limited={};for k,v in pairs(services) do limited[k]=v end
limited.evaluate=function(w) if w.entities[10].broken==1 then return nil,"rule_complexity_limit" end;return services.evaluate(w) end
local p,e=RW_PlanTurn(s.world,{type="wait"},limited);assert(p,e and e.reason)
local n,r=RW_Commit(s,p);assert(r.accepted and n.world.too_complex and n.world.entities[10].broken==1)
assert(RW_Undo(n).world==s.world)
-- Full tree integration uses public tokens and initialized selector status on F.
local nav={};for k,v in pairs(services) do nav[k]=v end
nav.active=RW_GetActiveLevel;nav.update=RW_UpdateActiveLevel;nav.update_instance=RW_UpdateLevelInstance
nav.enter=RW_EnterLevel;nav.return_level=RW_ReturnLevel;nav.selectors=RW_LevelSelectorIDs;nav.place_selectors=RW_PlaceLevelSelectors
nav.bind_entry=RW_BindLevelEntry;nav.commit_session=RW_Commit;nav.outcome=RW_RecordLevelOutcome
nav.candidates=RW_LevelSelectionCandidates;nav.win=RW_HasWinContact;nav.level_outcome=RW_ResolveLevelPropertyOutcome
nav.initialize=function(w) return RW_InitializeLevelWorld(w,nav) end
s=fixture({{"CURSOR","IS","BROKEN"},{"AVATAR","IS","YOU"}})
local child=fixture({}).world
local defs={root=assert(RW_CreateLevelDefinition("root",s.world)),child=assert(RW_CreateLevelDefinition("child",child))}
local root=assert(RW_CreateLevelTree(defs,"root"));root=assert(RW_InitializeLevelBoundary(root,{root.active_id},nav))
p,e=RW_PlanLevelAction(root,{type="confirm"},nav);assert(not p and e.reason=="no_selected_level")
-- Removal does not mutate saved status during display/F; next input releases it.
local session=RW_GetActiveLevel(root);local deletion=assert(RW_PlanDelete(session.world,{12}))
local cleared,accepted=RW_Commit(session,deletion);assert(accepted.accepted)
root=assert(RW_UpdateActiveLevel(root,cleared))
p,e=RW_PlanLevelAction(root,{type="confirm"},nav);assert(not p and e.reason=="no_selected_level")
p,e=RW_PlanLevelAction(root,{type="wait"},nav);assert(p,e and e.reason)
local ready,res=RW_CommitLevelTree(root,p);assert(res.accepted)
assert(RW_GetActiveLevel(ready).world.entities[2].broken==0)
p,e=RW_PlanLevelAction(ready,{type="confirm"},nav);assert(p,e and e.reason)
local entered,res=RW_CommitLevelTree(ready,p);assert(res.accepted and entered.active_id~=root.active_id)
assert(RW_UndoLevelTree(entered).active_id==root.active_id)
-- BROKEN YOU cannot win by overlapping an independent WIN source.
for broken=0,1 do
    s=fixture({{"AVATAR","IS","YOU"},{"FLAG","IS","WIN"}})
    if broken==1 then
        local w=s.world
        for x,word in ipairs({"AVATAR","IS","BROKEN"}) do local id=w.next_entity_id;w.next_entity_id=id+1
            w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=12,direction="Right"} end
    end
    s.world.entities[5]={id=5,kind="object",class="object",archetype="flag",x=9,y=2,direction="None"}
    defs={root=assert(RW_CreateLevelDefinition("root",fixture({}).world)),child=assert(RW_CreateLevelDefinition("child",s.world))}
    root=assert(RW_CreateLevelTree(defs,"root"));local active=assert(RW_EnterLevel(root,"3","child"));active=assert(RW_BindLevelEntry(active,3))
    active=assert(RW_InitializeLevelBoundary(active,{active.active_id},nav))
    p,e=RW_PlanLevelAction(active,{type="wait"},nav);assert(p,e and e.reason)
    local result,res=RW_CommitLevelTree(active,p);assert(res.accepted)
    assert((result.active_id==active.active_id)==(broken==1))
    assert(RW_UndoLevelTree(result).active_id==active.active_id)
end
print("PASS: public BROKEN vocabulary, orientation Text/WORD barriers, ordinary latching, terminal Undo, first-F selector release, independent YOU/WIN and tree Undo")
