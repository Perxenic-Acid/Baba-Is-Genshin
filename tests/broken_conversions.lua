local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=function(w,ids,c) return RW_InitializeBirthSpecifications(w,assert(RW_PlanHasBirths(w,ids,c)),rules) end,
        create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
    make=function(w,r,c,rules)
        local products,rng=RW_PlanMakeProducts(w,r,c)
        local p=assert(RW_PlanCreate(w,assert(RW_InitializeBirthSpecifications(w,products,rules))))
        p.random_state=rng;return p
    end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world;w.height=24
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Left",
        level_link={target="child",definition_id="conversion.child",source_type="avatar"}}}
    w.next_entity_id=10;w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag";w.language.properties.BROKEN="broken"
    w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        assert(x<=w.width and 4+row*2<=w.height)
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="None"}
    end end
    return s
end
local function wait(s)
    local p,e=RW_PlanTurn(s.world,{type="wait"},services);assert(p,e and (e.stage..":"..e.reason))
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
    for id in pairs(n.world.entities) do assert(id>0,"temporary source witness escaped into world") end
    return n,p
end
local s=fixture({{"AVATAR","IS","ROCK"},{"ROCK","IS","BROKEN"},{"ROCK","IS","CRASH","AND","YOU"}})
local n,plan=wait(s)
assert(n.world.entities[1].archetype=="rock" and n.world.entities[1].broken==1 and not n.world.infinite_loop)
assert(n.world.entities[1].direction=="Left" and n.world.entities[1].level_link.definition_id=="conversion.child")
assert(not s.world.entities[1].broken and RW_Undo(n).world==s.world)
-- Conversion products still see the old source until its entire product group
-- has been initialized, even though the first persistent identity is reused.
s=fixture({{"AVATAR","IS","ROCK","AND","FLAG"},{"ROCK","ON","AVATAR","IS","BROKEN"},
    {"FLAG","ON","AVATAR","IS","BROKEN"},{"ROCK","IS","CRASH"},{"FLAG","IS","CRASH"},{"AVATAR","HAS","FLAG"}})
local id=s.world.next_entity_id
n,plan=wait(s)
assert(n.world.entities[1].broken==1 and n.world.entities[id].broken==1 and not n.world.infinite_loop)
assert(n.world.next_entity_id==id+1 and n.world.entities[id].level_link.definition_id=="conversion.child")
assert(RW_Undo(n).world==s.world)
local released,terminal=wait(n);assert(terminal.infinite_loop and released.world.entities[1].broken==0 and released.world.entities[id].broken==0)
-- Ordered duplicate products: only the second ROCK sees the first ROCK.
s=fixture({{"AVATAR","IS","ROCK","AND","ROCK"},{"ROCK","ON","ROCK","IS","BROKEN"}})
id=s.world.next_entity_id
n,plan=wait(s)
assert(not n.world.entities[1].broken and n.world.entities[id].broken==1)
assert(n.world.entities[id].direction=="Left" and n.world.next_entity_id==id+1)
-- Same-name BECOME is a new product even without a transform/retype operation.
s=fixture({{"AVATAR","BECOME","AVATAR"},{"AVATAR","ON","AVATAR","IS","BROKEN"},
    {"AVATAR","MAKE","FLAG"},{"AVATAR","IS","CRASH"}})
id=s.world.next_entity_id
n,plan=wait(s)
assert(n.world.entities[1].broken==1 and n.world.next_entity_id==id and not n.world.infinite_loop)
assert(RW_Undo(n).world==s.world)
-- WRITE/retype initializes status directly in its replacement specification.
s=fixture({{"AVATAR","WRITE","ROCK"},{"TEXT","IS","BROKEN"}})
n,plan=wait(s)
assert(n.world.entities[1].class=="text" and n.world.entities[1].text.name=="ROCK" and n.world.entities[1].broken==1)
assert(n.world.entities[1].level_link.definition_id=="conversion.child" and RW_Undo(n).world==s.world)
print("PASS: conversion-primary/extra BROKEN, old-source witnesses, ordered duplicate products, same-name BECOME, WRITE, late MAKE/CRASH, links, identity and Undo")
