local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(subject,word)
    local s=RW_CreateSession();local w=s.world;w.height=24
    w.language.properties.BROKEN="broken";w.language.nouns.ROCK="rock";w.language.nouns.WATER="water"
    w.entities={[1]={id=1,kind="object",class="object",archetype="rock",x=9,y=2,direction="Left"},
        [2]={id=2,kind="object",class="object",archetype="water",x=3,y=6,direction="None"}}
    w.next_entity_id=10
    local rows={{subject,"IS","BROKEN"},{"WATER","IS","SINK"}}
    if word then rows[#rows+1]={"ROCK","IS","WORD"} end
    for row,words in ipairs(rows) do for x,token in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=token},x=x,y=4+row*2,direction="None"}
    end end
    return s
end
local function step(s,svc)
    local p,e=RW_PlanTurn(s.world,{type="wait"},svc or services);assert(p,e and (e.stage..":"..e.reason))
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);return n,p
end
for _,case in ipairs({{"TEXT",false},{"ROCK",false},{"ROCK",true}}) do
    local s=fixture(case[1],case[2]);local n,p=step(s)
    assert(not n.world.entities[2] and not n.world.entities[12])
    local index
    for i,stage in ipairs(p.stages) do if stage.name=="code_status_after_contacts" then index=i end end
    if case[1]=="TEXT" then
        assert(index and n.world.entities[10].broken==0 and n.world.entities[13].broken==0)
        local frame=assert(RW_CompileWorld(n.world,cs));local projected=assert(RW_ProjectWorld(n.world,frame.effects))
        assert(projected.entities[10].behaviors.push,"surviving Text retained stale BROKEN after contact deletion")
    elseif case[2] then
        assert(not index and n.world.entities[1].broken==1,"disabled WORD incorrectly re-entered code candidates")
        local later=step(n);assert(later.world.entities[1].broken==0)
    else
        assert(not index and n.world.entities[1].broken==1,"ordinary status refreshed at code-only barrier")
        local later=step(n);assert(later.world.entities[1].broken==0)
    end
    assert(not s.world.entities[10].broken and s.world.entities[12] and RW_Undo(n).world==s.world)
end
-- Contact predicates stay frozen: deleting the BROKEN word does not restore
-- default Text PUSH or expose Text to another frozen contact midway through it.
-- The status change is appended only after all contact stages have completed.
local s=fixture("TEXT",false)
local w=s.world
w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={
    {op="grant_trait",target={kind="class",value="text"},trait="melt"},
    {op="grant_trait",target={kind="archetype",value="rock"},trait="hot"}}}
local loose=w.next_entity_id;w.next_entity_id=loose+1
w.entities[loose]={id=loose,kind="object",class="text",text={name="ROCK"},x=9,y=2,direction="Up"}
local n,p=step(s);local last_contact,status_index
assert(n.world.entities[loose] and n.world.entities[loose].broken==0,"MELT reran after code status release")
local melted=step(n);assert(not melted.world.entities[loose],"released MELT did not apply on next turn")
for i,stage in ipairs(p.stages) do
    if stage.name=="unlock" then last_contact=i elseif stage.name=="code_status_after_contacts" then status_index=i end
end
assert(status_index>last_contact)
-- Late validation failure cannot leak deletion or status; the combined diagnostic
-- change list remains an exact concatenation of sequential stages.
local count=0;for _,stage in ipairs(p.stages) do count=count+#stage.plan.changes end
assert(count==#p.changes)
local bad={};for k,v in pairs(p) do bad[k]=v end
bad.stages={};for i,v in ipairs(p.stages) do bad.stages[i]=v end
bad.stages[#bad.stages+1]={name="stale",plan={consumes_turn=true,changes={{kind="broken",entity_id=10,from=1,to=0}}}}
bad.changes={};for _,stage in ipairs(bad.stages) do for _,change in ipairs(stage.plan.changes) do bad.changes[#bad.changes+1]=change end end
local rejected,r=RW_Commit(s,bad);assert(not r.accepted and rejected==s and s.world.entities[12] and not s.world.entities[10].broken)
-- A second compile failure after the status barrier retains all trigger phases.
local limited={};for k,v in pairs(services) do limited[k]=v end
limited.evaluate=function(w)
    if not w.entities[12] and w.entities[10].broken==0 then return nil,"rule_complexity_limit" end
    return services.evaluate(w)
end
n,p=step(s,limited)
assert(n.world.too_complex and not n.world.entities[12] and n.world.entities[10].broken==0 and RW_Undo(n).world==s.world)
print("PASS: BROKEN final contact code barrier, physical Text release, disabled WORD/ordinary latching, frozen phases, late terminal preservation, rollback and Undo")
