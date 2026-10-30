local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local contacts={victims=RW_ResolveContactVictims,create=RW_PlanCreate,delete=RW_PlanDelete,
    births=function(w,ids,c,rules)
        local p,e=RW_PlanHasBirths(w,ids,c);if not p then return nil,e end
        return RW_InitializeBirthSpecifications(w,p,rules)
    end}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    destroy=function(w,ids,c,k,deaths,rules) return RW_PlanDestructionPhase(w,ids,c,k,contacts,deaths,rules) end,
    contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,contacts,rules) end,
    eat=function(w,p,relations,contents,rules)
        local ids=RW_ResolveEatVictims(p,RW_ResolveVerbTargets(w,relations,"eat"))
        return RW_PlanDestructionPhase(w,ids,contents,"eat",contacts,nil,rules)
    end,
    more=function(w,p,rules) return RW_PlanCreate(w,assert(RW_InitializeBirthSpecifications(w,assert(RW_ResolveMoreProducts(p)),rules))) end,
    make=function(w,relations,converted,rules)
        local p,rng=RW_PlanMakeProducts(w,relations,converted)
        local creation=assert(RW_PlanCreate(w,assert(RW_InitializeBirthSpecifications(w,p,rules))))
        creation.random_state=rng;return creation
    end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world;w.height=24
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Left"}}
    w.language.properties.BROKEN="broken";w.language.nouns.ROCK="rock";w.language.nouns.WATER="water";w.language.nouns.FLAG="flag";w.language.nouns.WALL="wall"
    w.next_entity_id=10
    w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        assert(x<=w.width and 4+row*2<=w.height,"birth test sentence outside board")
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="None"}
    end end
    return s
end
local function wait(s)
    local p,e=RW_PlanTurn(s.world,{type="wait"},services);assert(p,e and (e.stage..":"..e.reason))
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
    return n,p
end
-- HAS newborn is broken before late CRASH. Its parent is still visible to ON
-- during creation, as inside() runs before delete() removes that parent.
local s=fixture({{"AVATAR","IS","DEFEAT"},{"AVATAR","HAS","ROCK"},
    {"ROCK","ON","AVATAR","IS","BROKEN"},{"ROCK","IS","CRASH"}})
local id=s.world.next_entity_id
local n,plan=wait(s)
assert(not n.world.entities[1] and n.world.entities[id].archetype=="rock" and n.world.entities[id].broken==1)
assert(not n.world.infinite_loop and not s.world.entities[id] and RW_Undo(n).world==s.world)
-- At the next input the old ON witness is gone, so release now permits CRASH.
local released,terminal=wait(n)
assert(terminal.infinite_loop and released.world.entities[id].broken==0 and RW_Undo(released).world==n.world)
-- MORE children initialize independently at their actual birth cells. The source
-- is healthy; a child born on ROCK is broken and loses YOU before DEFEAT.
s=fixture({{"AVATAR","IS","MORE"},{"AVATAR","ON","ROCK","IS","BROKEN"},{"ROCK","IS","DEFEAT"}})
s.world.entities[2]={id=2,kind="object",class="object",archetype="rock",x=3,y=2,direction="None"}
n,plan=wait(s)
local child
for eid,e in pairs(n.world.entities) do if e.archetype=="avatar" and e.x==3 and e.y==2 then child=e end end
assert(child and child.broken==1 and n.world.entities[1] and not n.world.entities[1].broken)
assert(RW_Undo(n).world==s.world)
-- Duplicate MAKE products initialize sequentially; only the second can use the
-- first as a non-self ON ROCK witness.
s=fixture({{"AVATAR","MAKE","ROCK","AND","ROCK"},{"ROCK","ON","ROCK","IS","BROKEN"}})
id=s.world.next_entity_id
n,plan=wait(s)
assert(n.world.entities[id] and not n.world.entities[id].broken and n.world.entities[id+1].broken==1)
assert(n.world.next_entity_id==id+2 and RW_Undo(n).world==s.world)
-- Frozen destruction frame survives deletion of the physical BROKEN keyword.
s=fixture({{"AVATAR","IS","DEFEAT"},{"AVATAR","HAS","ROCK"},{"ROCK","IS","BROKEN"},{"WATER","IS","SINK"},{"ROCK","IS","CRASH"}})
local keyword
for eid,e in pairs(s.world.entities) do if e.class=="text" and e.text.name=="BROKEN" then keyword=e end end
s.world.entities[2]={id=2,kind="object",class="object",archetype="water",x=keyword.x,y=keyword.y,direction="None"}
id=s.world.next_entity_id
n,plan=wait(s)
assert(not n.world.entities[keyword.id] and n.world.entities[id].broken==1 and not n.world.infinite_loop)
-- EAT shares the frozen newborn initialization path and the dying witness.
s=fixture({{"AVATAR","EAT","ROCK"},{"ROCK","HAS","FLAG"},{"FLAG","ON","ROCK","IS","BROKEN"},{"FLAG","IS","CRASH"}})
s.world.entities[2]={id=2,kind="object",class="object",archetype="rock",x=2,y=2,direction="Down"}
id=s.world.next_entity_id
n,plan=wait(s)
assert(not n.world.entities[2] and n.world.entities[id].archetype=="flag" and n.world.entities[id].broken==1 and not n.world.infinite_loop)
-- Movement unlock deaths initialize each HAS batch against its own death frame.
-- Allocator offsets include preceding batches, so two newborn contexts cannot
-- reuse the first allocated identity.
s=fixture({{"AVATAR","IS","OPEN"},{"WALL","IS","SHUT"},{"AVATAR","HAS","ROCK"},{"WALL","HAS","ROCK"},
    {"ROCK","ON","AVATAR","IS","BROKEN"},{"ROCK","ON","WALL","IS","BROKEN"},{"ROCK","IS","CRASH"}})
s.world.entities[2]={id=2,kind="object",class="object",archetype="wall",x=3,y=2,direction="Down"}
id=s.world.next_entity_id
local p,e=RW_PlanTurn(s.world,{type="move",dx=1,dy=0},services);assert(p,e and e.reason)
n,plan=RW_Commit(s,p);assert(plan.accepted,plan.reason)
assert(not n.world.entities[1] and not n.world.entities[2] and not n.world.infinite_loop)
assert(n.world.entities[id].broken==1 and n.world.entities[id+1].broken==1 and n.world.next_entity_id==id+2,"unlock birth statuses "..tostring(n.world.entities[id].broken)..":"..tostring(n.world.entities[id+1].broken)..":"..n.world.next_entity_id..":"..id)
assert(RW_Undo(n).world==s.world)
-- Public initializer is pure, resets inherited state, and preserves unrelated
-- identity-bound metadata. Invalid query/spec input cannot leak partial products.
s=fixture({})
local specs={{kind="object",class="object",archetype="rock",x=2,y=2,direction="Down",broken=1,
    level_link={target="child",definition_id="test.child",source_type="rock"}}}
local initialized=assert(RW_InitializeBirthSpecifications(s.world,specs,{}))
assert(not initialized[1].broken and specs[1].broken==1 and initialized[1].direction=="Down")
assert(initialized[1].level_link.definition_id=="test.child" and not s.world.entities[s.world.next_entity_id])
local bad,e=RW_InitializeBirthSpecifications(s.world,{{broken=2}},{});assert(not bad and e=="invalid_birth_status_specification")
print("PASS: newborn BROKEN on HAS/MORE/MAKE, pre-delete witnesses, ordered duplicates, frozen declarations, late CRASH, metadata purity and Undo")
