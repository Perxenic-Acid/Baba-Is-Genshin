local function recursive_frame(archetype)
    local rules={}
    local function effect(trait) return {op="grant_trait",target={kind="archetype",value=archetype},trait=trait} end
    for i=0,82 do
        rules[#rules+1]={when={op="spatial",clauses={{relation="feeling",negated=false,parameters={{tag="property",name="limit_"..(i+1)}}}}},
            effects={effect(i==0 and "broken" or "limit_"..i)}}
    end
    rules[#rules+1]={when={op="always"},effects={effect("limit_83")}}
    return rules
end
local function fixture()
    local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=20
    for id=1,3 do w.entities[id]={id=id,kind="object",class="object",archetype=id==1 and "avatar" or "crate",x=id+2,y=3,direction="Down",
        level_link={target="child",definition_id="child",source_type="crate"}} end
    return s
end
local function plan(w,relations,raw)
    local changes,e,allocation,converted,terminal=RW_PlanConversions(w,relations,raw)
    assert(changes,e);assert(terminal=="word_rule_limit")
    return {consumes_turn=true,changes=changes,id_allocation=allocation,infinite_loop=true},converted
end
local healthy={op="transform",source_type="avatar",target_type="flag"}
for _,targets in ipairs({{"rock"},{"flag","rock","flag"},{"flag","flag","rock"}}) do
    local s=fixture();local relations={healthy}
    for _,target in ipairs(targets) do relations[#relations+1]={op="transform",source_type="crate",target_type=target} end
    local p=plan(s.world,relations,recursive_frame("rock"))
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
    assert(n.world.entities[1].archetype=="flag","earlier source conversion lost")
    assert(n.world.entities[2].archetype=="crate" and n.world.entities[3].archetype=="crate","unfinished source group lost parent/later source")
    local count=targets[1]=="rock" and 1 or #targets==3 and targets[2]=="rock" and 2 or 3
    assert(n.world.next_entity_id==20+count)
    for index=1,count do
        local e=n.world.entities[19+index];assert(e.archetype==targets[index] and e.direction=="Down" and e.level_link.definition_id=="child")
    end
    assert(not n.world.entities[20+count] and s.world.entities[1].archetype=="avatar" and s.world.next_entity_id==20)
    assert(RW_Undo(n).world==s.world)
end
-- Earlier completed duplicate groups keep their IDs; interrupted group allocation
-- starts at their committed frontier, without recycling those earlier products.
local prior=fixture()
local rels={healthy,{op="transform",source_type="avatar",target_type="flag"},
    {op="transform",source_type="crate",target_type="flag"},{op="transform",source_type="crate",target_type="rock"}}
local pref=plan(prior.world,rels,recursive_frame("rock"))
local after,res=RW_Commit(prior,pref);assert(res.accepted and after.world.next_entity_id==23)
assert(after.world.entities[1].archetype=="flag" and after.world.entities[20].archetype=="flag")
assert(after.world.entities[21].archetype=="flag" and after.world.entities[22].archetype=="rock" and after.world.entities[2].archetype=="crate")
-- A relation-condition limit before any birth preserves only prior groups.
local query_raw=recursive_frame("crate")
local guarded={healthy,{op="transform",source_type="crate",target_type="rock",when=query_raw[1].when,condition_rules=query_raw}}
local no_birth=plan(prior.world,guarded,query_raw)
assert(not no_birth.id_allocation)
after,res=RW_Commit(prior,no_birth);assert(res.accepted and after.world.entities[1].archetype=="flag" and after.world.entities[2].archetype=="crate")
assert(after.world.next_entity_id==20 and RW_Undo(after).world==prior.world)
-- Same-name BECOME still creates a trigger product beside the retained parent.
local s=fixture();local relations={healthy,{op="become",source_type="crate",target_type="crate",when={op="always"}}}
local p,converted=plan(s.world,relations,recursive_frame("crate"));assert(converted[2])
local n,r=RW_Commit(s,p);assert(r.accepted and n.world.entities[2].archetype=="crate" and n.world.entities[20].archetype=="crate")
-- WRITE/retype does not leak the speculative primary retype when Text status fails.
local raw=recursive_frame("unused")
for _,rule in ipairs(raw) do for _,effect in ipairs(rule.effects) do effect.target={kind="class",value="text"} end end
relations={healthy,{op="write_text",source_type="crate",target_text="FLAG"}}
p=plan(s.world,relations,raw);n,r=RW_Commit(s,p)
assert(r.accepted and n.world.entities[2].class=="object" and n.world.entities[20].class=="text" and n.world.entities[20].text.name=="FLAG")
assert(n.world.entities[20].level_link.definition_id=="child" and RW_Undo(n).world==s.world)
-- Virtual EMPTY stops at the first triggering cell and allocates no proxy IDs.
s=fixture();s.world.entities={};relations={{op="transform",source_type="@empty",target_type="rock"}}
p=plan(s.world,relations,recursive_frame("rock"));n,r=RW_Commit(s,p)
assert(r.accepted and n.world.next_entity_id==21 and n.world.entities[20].x==1 and n.world.entities[20].y==1)
for id in pairs(n.world.entities) do assert(id>0) end
-- Production scheduler consumes the fifth conversion result and never evaluates
-- the partial terminal board or runs MORE/contact phases afterward.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
s=fixture();local stopped=false
relations={healthy,{op="transform",source_type="crate",target_type="flag"},{op="transform",source_type="crate",target_type="rock"}}
raw=recursive_frame("rock")
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=function(w,r,rules)
        local ops,e,a,ids,limit=RW_PlanConversions(w,r,rules);stopped=limit~=nil;return ops,e,a,ids,limit
    end,
    more=function() error("MORE after conversion terminal") end,
    evaluate=function(w) assert(not stopped,"terminal conversion was compiled");local f=assert(RW_CompileWorld(w,cs));return f.effects,nil,relations,raw end}
local turn,e=RW_PlanTurn(s.world,{type="wait"},services);assert(turn,e and e.reason)
assert(turn.infinite_loop and turn.stages[#turn.stages].name=="conversion")
n,r=RW_Commit(s,turn);assert(r.accepted and n.world.entities[2].archetype=="crate" and n.world.next_entity_id==22)
assert(RW_Undo(n).world==s.world)
local rejected,e=RW_PlanTurn(n.world,{type="wait"},services);assert(not rejected and e.reason=="infinite_loop_undo_only")
-- Scheduler classifies a reported parser limit as TOO COMPLEX, preserving ops.
stopped=false
services.convert=function(w,r,rules)
    local ops,e,a,ids=RW_PlanConversions(w,r,rules);stopped=true;return ops,e,a,ids,"rule_complexity_limit"
end
turn,e=RW_PlanTurn(s.world,{type="wait"},services);assert(turn,e and e.reason)
assert(turn.too_complex and not turn.infinite_loop)
n,r=RW_Commit(s,turn);assert(r.accepted and n.world.too_complex and n.world.entities[2].archetype=="crate")
assert(RW_Undo(n).world==s.world)
-- Ordinary declaration errors continue to reject rather than return terminal ops.
local bad=recursive_frame("rock");bad[1].when.clauses[1].negated=nil
local ops,why=RW_PlanConversions(s.world,relations,bad);assert(not ops and why=="invalid_spatial_clause")
print("PASS: conversion status-limit product groups, prior sources, primary/duplicate/WRITE/BECOME/EMPTY, retained parents, links/IDs, scheduler stop and Undo")
