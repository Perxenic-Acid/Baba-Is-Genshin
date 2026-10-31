local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local function world(rows)
    local w=RW_CreateSession().world;w.height=32
    w.language.properties.BROKEN="broken";w.language.nouns.ROCK="rock";w.language.nouns.LEVEL={tag="level",block_type="level_block"}
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=9,y=2,direction="Left"},
        [2]={id=2,kind="object",class="object",archetype="level_block",x=9,y=3,direction="None"}}
    w.next_entity_id=10
    w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="None"}
    end end
    return w
end
local function compile(w) return assert(RW_CompileWorld(w,cs)) end
for grant=0,1 do for deny=0,1 do for reversed=0,1 do
    local rows={{"LEVEL","IS","WIN"},{"LEVEL","IS","DEFEAT"},{"LEVEL","IS","HOLD"},
        {"LEVEL","IS","POWER3"},{"POWERED3","AVATAR","IS","PUSH"},{"LEVEL","IS","ROCK"},{"LEVEL","IS","LEVEL"}}
    if grant==1 then table.insert(rows,reversed==1 and 1 or #rows+1,{"LEVEL","IS","BROKEN"}) end
    if deny==1 then table.insert(rows,reversed==1 and 1 or #rows+1,{"LEVEL","IS","NOT","BROKEN"}) end
    local w=world(rows);local f=compile(w);local disabled=grant==1 and deny==0
    local traits,scoped={},0
    for _,r in ipairs(f.relations) do
        if r.op=="level_trait" then traits[#traits+1]=r.trait end
        if r.op=="level_trait" or r.op=="deny_level_trait" or r.op=="transform_level" or r.op=="protect_level" then scoped=scoped+1 end
    end
    local p=assert(RW_ProjectWorld(w,f.effects,traits))
    if disabled then
        assert(scoped==0,"broken LEVEL retained scoped consumer")
    else
        assert(scoped>=6 and p.entities[1].behaviors.push)
        local ordered={};for _,t in ipairs(traits) do if t=="win" or t=="defeat" then ordered[#ordered+1]=t end end;assert(ordered[1]=="win" and ordered[2]=="defeat","terminal source order changed")
    end
    -- The real level block remains a separate physical identity. Lowering must
    -- retain its BROKEN declaration for status initialization rather than erase it.
    local status=assert(RW_PlanRuleStatus(w,f.rules));local n=assert(RW_PreviewPlan(w,status))
    assert((n.entities[2].broken==1)==disabled and not w.entities[2].broken)
    if disabled then
        local refreshed=compile(n);local projected=assert(RW_ProjectWorld(n,refreshed.effects))
        assert(not projected.entities[1].behaviors.push,"disabled scoped/physical LEVEL still supplied POWER")
    end
end end end
local services={active=RW_GetActiveLevel,update=RW_UpdateActiveLevel,enter=RW_EnterLevel,return_level=RW_ReturnLevel,
    selectors=RW_LevelSelectorIDs,place_selectors=RW_PlaceLevelSelectors,bind_entry=RW_BindLevelEntry,
    commit_session=RW_Commit,outcome=RW_RecordLevelOutcome,candidates=RW_LevelSelectionCandidates,
    win=RW_HasWinContact,level_outcome=RW_ResolveLevelPropertyOutcome,status=RW_PlanRuleStatus,
    project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,
    evaluate=function(w) local f=compile(w);return f.effects,nil,f.relations,f.rules,f.code_status end}
for _,consumer in ipairs({"WIN","DEFEAT","ROCK","TEXT"}) do for broken=0,1 do
    local rows={{"LEVEL","IS",consumer}}
    if broken==1 then rows[#rows+1]={"LEVEL","IS","BROKEN"} end
    local parent=world({});parent.entities[2].level_link={target="child",definition_id="child",source_type="level_block"}
    local defs={root=assert(RW_CreateLevelDefinition("root",parent)),child=assert(RW_CreateLevelDefinition("child",world(rows)))}
    local root=assert(RW_CreateLevelTree(defs,"root"));local entered=assert(RW_EnterLevel(root,"2","child"));entered=assert(RW_BindLevelEntry(entered,2))
    local plan,err=RW_PlanLevelAction(entered,{type="wait"},services);assert(plan,err and err.reason)
    local n,r=RW_CommitLevelTree(entered,plan);assert(r.accepted,r.reason)
    if broken==1 then
        assert(n.active_id==entered.active_id and not RW_GetActiveLevel(n).defeated)
        assert(RW_GetActiveLevel(n).world.entities[1].archetype=="avatar")
    elseif consumer=="DEFEAT" then assert(RW_GetActiveLevel(n).defeated)
    else assert(n.active_id==root.active_id) end
    assert(RW_UndoLevelTree(n).active_id==entered.active_id)
end end
-- Installed virtual LEVEL branch: no unit.broken lookup; isitbroken uses the
-- synthetic identity and explicit ignorebroken forwarding, as for Empty.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],"rb"));local src=file:read("*a");file:close()
for broken=0,1 do for ignore=0,1 do
    local calls=0
    local env=setmetatable({features={true},featureindex={broken={true}},parsesurrounds=function() return {dir="0"} end,
        isitbroken=function(name,id,x,y,checked)
            assert(name=="level" and id==1 and type(checked)=="table");calls=calls+1;return broken
        end},{__index=_G})
    assert(load(src,"@installed_level_conditions","t",env))()
    assert(env.testcond({},1,nil,nil,nil,nil,nil,ignore==1)==(broken==0 or ignore==1))
    assert(calls==(ignore==1 and 0 or 1))
end end
print("PASS: scoped LEVEL BROKEN grant/deny, ordered terminal/conversion/HOLD/POWER gating, real block status, tree outcomes and Undo, installed virtual query branch")
