-- Production compiler and transaction pipeline for WRITE, SAFE and CRASH.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w)
        local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules
    end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.entities={
        [1]={id=1,kind='object',class='object',archetype='avatar',x=3,y=3,direction='Right'},
        [2]={id=2,kind='object',class='object',archetype='rock',x=4,y=3,direction='Left'}}
    w.language.nouns.ROCK='rock'
    w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',
        target={kind='archetype',value='avatar'},trait='you'}}}
    w.next_entity_id=3
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=4+row*2,direction='None'}
    end end
    return s
end
local function step(s)
    local plan,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
    local next_s,r=RW_Commit(s,plan);assert(r.accepted,r.reason);return next_s,plan
end
for _,word in ipairs({'ROCK','PUSH','TEXT','EMPTY','CRASH','SAFE'}) do
    local s=fixture({{'ROCK','WRITE',word}});local n=step(s)
    assert(n.world.entities[2].class=='text' and n.world.entities[2].text.name==word)
    assert(n.world.entities[2].direction=='Left' and RW_Undo(n).world==s.world)
end
local s=fixture({{'ROCK','WRITE','CRATE'},{'ROCK','WRITE','CRATE'}})
local frontier=s.world.next_entity_id;local n=step(s)
assert(n.world.entities[2].text.name=='CRATE' and n.world.entities[frontier].text.name=='CRATE')
for _,rows in ipairs({
    {{'ROCK','WRITE','CRATE'},{'ROCK','IS','ROCK'}},
    {{'ROCK','WRITE','CRATE'},{'ROCK','IS','NOT','TEXT'}},
    {{'ROCK','WRITE','CRATE'},{'ROCK','WRITE','NOT','CRATE'}}}) do
    s=fixture(rows);n=step(s);assert(n.world.entities[2].archetype=='rock')
end
s=fixture({{'TEXT','WRITE','CRATE'}});n=step(s)
assert(n.world.entities[3].text.name=='CRATE' and n.world.entities[4].text.name=='CRATE')
s=fixture({{'EMPTY','WRITE','ROCK'}});n=step(s)
assert(n.world.entities[s.world.next_entity_id].text.name=='ROCK')
-- SAFE protects each victim independently, including a safe SINK source.
s=fixture({{'ROCK','IS','DEFEAT'},{'AVATAR','IS','SAFE'}});n=step(s);assert(n.world.entities[1])
s=fixture({{'ROCK','IS','SINK'},{'AVATAR','IS','SAFE'}});n=step(s)
assert(n.world.entities[1] and not n.world.entities[2])
s=fixture({{'ROCK','IS','SINK','AND','SAFE'}});n=step(s)
assert(not n.world.entities[1] and n.world.entities[2])
s=fixture({{'ROCK','IS','SINK','AND','SAFE'},{'AVATAR','IS','SAFE'}});n=step(s)
assert(n.world.entities[1] and n.world.entities[2])
s=fixture({{'AVATAR','IS','SAFE'},{'AVATAR','IS','NOT','SAFE'},{'ROCK','IS','DEFEAT'}})
n=step(s);assert(not n.world.entities[1])
s=fixture({{'ROCK','IS','SAFE'},{'ROCK','WRITE','CRATE'}});n=step(s)
assert(n.world.entities[2].text.name=='CRATE')
-- CRASH requires a surviving unit; SAFE does not suppress it.
for _,rows in ipairs({{{'ROCK','IS','CRASH'}},{{'ROCK','IS','CRASH','AND','SAFE'}}}) do
    s=fixture(rows);local plan;n,plan=step(s)
    assert(plan.infinite_loop and n.world.infinite_loop and n.world.entities[1].x==4)
    assert(RW_Undo(n).world==s.world)
end
s=fixture({{'ROCK','IS','CRASH','AND','SINK'}});n=step(s)
assert(not n.world.infinite_loop and not n.world.entities[2])
s=fixture({{'ROCK','IS','CRASH'},{'ROCK','IS','NOT','CRASH'}});n=step(s)
assert(not n.world.infinite_loop)
s=fixture({{'EMPTY','IS','CRASH'}});n=step(s);assert(not n.world.infinite_loop)
-- Too Complex is a separate persisted/validated undo-only terminal state.
s=fixture({});local terminal,r=RW_Commit(s,{consumes_turn=true,changes={},too_complex=true})
assert(r.accepted and terminal.world.too_complex and not terminal.world.infinite_loop)
local plan,e=RW_PlanTurn(terminal.world,{type='move',dx=1,dy=0},services)
assert(not plan and e.reason=='too_complex_undo_only')
assert(RW_Undo(terminal).world==s.world)
assert(not RW_PreviewPlan(s.world,{consumes_turn=true,changes={},too_complex='bad'}))
print('PASS: WRITE nouns/properties/Text/Empty/multiplicity/vetoes, SAFE contacts/conversion, surviving CRASH, Too Complex state/Undo')

local function frame(w) local f,e=RW_CompileWorld(w,cs);assert(f,e and e.reason);return f end
s=fixture({{'ROCK','WRITE','ALL'},{'ROCK','WRITE','NOT','ALL'},{'ROCK','WRITE','CRATE'}})
local f=frame(s.world);assert(#f.relations==1 and f.relations[1].target_text=='CRATE')
s=fixture({{'ALL','WRITE','ALL'}})
f=frame(s.world);assert(#f.relations==2 * (#RW_NounPalette(s.world))^2)
s=fixture({{'ROCK','IS','DEFEAT','AND','SAFE'}})
n=step(s);assert(not n.world.entities[1] and n.world.entities[2])
s=fixture({{'AVATAR','IS','SAFE','AND','DEFEAT'}})
n=step(s);assert(n.world.entities[1])
assert(not RW_PreviewPlan(s.world,{consumes_turn=true,changes={},too_complex=true,infinite_loop=true}))
print('PASS: WRITE ALL provenance/multiplicity, SAFE hazard still active, SAFE self-DEFEAT and exclusive terminal states')
