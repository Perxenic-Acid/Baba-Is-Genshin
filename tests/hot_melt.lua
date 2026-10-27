-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.entities={
        [1]={id=1,kind='object',class='object',archetype='avatar',x=2,y=2,direction='Left'},
        [2]={id=2,kind='object',class='object',archetype='rock',x=3,y=2,direction='Down'},
        [3]={id=3,kind='object',class='object',archetype='rock',x=7,y=2,direction='None'}}
    w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
    w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',
        target={kind='archetype',value='avatar'},trait='you'}}}
    w.next_entity_id=10
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=4+row*2,direction='None'}
    end end
    return s
end
local function step(s)
    local plan,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
    local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world)
    assert(#n.history==1);return n,plan
end
local s=fixture({{'ROCK','IS','HOT'},{'AVATAR','IS','MELT'}})
local n,plan=step(s);assert(not n.world.entities[1] and n.world.entities[2] and n.world.entities[3])
local positions={};for index,stage in ipairs(plan.stages) do positions[stage.name]=index end
assert(positions.sink < positions.melt and positions.melt < positions.defeat)
assert(plan.stages[positions.melt].plan.events[1].cause=='melt')
s=fixture({{'ROCK','IS','HOT','AND','MELT'}});n=step(s)
assert(not n.world.entities[2] and not n.world.entities[3] and n.world.entities[1])
s=fixture({{'ROCK','IS','HOT','AND','MELT'},{'AVATAR','IS','MELT'}});n=step(s)
assert(not n.world.entities[1] and not n.world.entities[2]) -- same-phase HOT survives until all victims selected
s=fixture({{'ROCK','IS','HOT','AND','SAFE'},{'AVATAR','IS','MELT'}});n=step(s)
assert(not n.world.entities[1] and n.world.entities[2])
s=fixture({{'ROCK','IS','HOT'},{'AVATAR','IS','MELT','AND','SAFE'},{'AVATAR','HAS','CRATE'}})
local frontier=s.world.next_entity_id;n=step(s)
assert(n.world.entities[1] and n.world.next_entity_id==frontier)
s=fixture({{'ROCK','IS','HOT'},{'AVATAR','IS','MELT','AND','SAFE'},{'AVATAR','IS','NOT','SAFE'}})
n=step(s);assert(not n.world.entities[1])
s=fixture({{'ROCK','IS','HOT'},{'ROCK','IS','NOT','HOT'},{'AVATAR','IS','MELT'}})
n=step(s);assert(n.world.entities[1])
s=fixture({{'ROCK','IS','HOT'},{'AVATAR','IS','MELT'},{'AVATAR','IS','NOT','MELT'}})
n=step(s);assert(n.world.entities[1])
s=fixture({{'ROCK','IS','HOT'},{'AVATAR','IS','MELT'},{'AVATAR','HAS','CRATE'},{'AVATAR','HAS','CRATE'}})
frontier=s.world.next_entity_id;n=step(s)
assert(n.world.next_entity_id==frontier+2 and n.world.entities[frontier].archetype=='crate')
assert(n.world.entities[frontier+1].direction=='Right' and n.world.entities[frontier].x==3)
-- MELT does not require YOU, unlike DEFEAT.
s=fixture({{'ROCK','IS','MELT'},{'CRATE','IS','HOT'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=3,y=2,direction='None'}
n=step(s);assert(not n.world.entities[2] and n.world.entities[3] and n.world.entities[1] and n.world.entities[4])
-- Conditional HOT is per identity, including multiple simultaneous YOU.
s=fixture({{'ROCK','ON','CRATE','IS','HOT'},{'AVATAR','IS','MELT'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=3,y=2,direction='None'}
s.world.entities[5]={id=5,kind='object',class='object',archetype='avatar',x=6,y=2,direction='None'}
n=step(s);assert(not n.world.entities[1] and n.world.entities[5] and n.world.entities[2])
-- Phase ordering: melt removes a self-melting hazard before DEFEAT can kill YOU.
s=fixture({{'ROCK','IS','HOT','AND','MELT','AND','DEFEAT'}});n=step(s)
assert(n.world.entities[1] and not n.world.entities[2])
-- SINK/HAS products reach MELT, but a deleted HOT source cannot heat them.
s=fixture({{'ROCK','IS','HOT','AND','SINK'},{'ROCK','HAS','FLAG'},{'FLAG','IS','MELT'}})
frontier=s.world.next_entity_id;n=step(s)
assert(not n.world.entities[1] and not n.world.entities[2] and n.world.entities[frontier].archetype=='flag')
-- Text destroys with the frozen HAS declarations even when those words melt too.
s=fixture({{'TEXT','IS','HOT','AND','MELT'},{'TEXT','HAS','CRATE'}})
frontier=s.world.next_entity_id;local texts=0
for _,e in pairs(s.world.entities) do if e.class=='text' then texts=texts+1 end end
n=step(s);assert(n.world.next_entity_id==frontier+texts)
for _,e in pairs(n.world.entities) do assert(e.class~='text') end
-- A later failure rejects the whole turn, including already planned HAS allocation.
s=fixture({{'ROCK','IS','HOT'},{'AVATAR','IS','MELT'},{'AVATAR','HAS','CRATE'}})
local bad={};for k,v in pairs(services) do bad[k]=v end
bad.contact=function(w,p,k,c) if k=='defeat' then return nil,'injected_late_failure' end
    return services.contact(w,p,k,c) end
frontier=s.world.next_entity_id
local failed,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},bad)
assert(not failed and e.stage=='defeat' and e.reason=='injected_late_failure')
assert(s.world.entities[1].x==2 and s.world.next_entity_id==frontier and #s.history==0)
print('PASS: HOT/MELT self/contact/SAFE/NOT/conditional heat, non-YOU, frozen phases/HAS multiplicity/directions/Text, rollback and Undo')

s=fixture({{'ROCK','IS','HOT','AND','MELT','AND','CRASH'}})
n=step(s);assert(not n.world.entities[2] and not n.world.infinite_loop)
for _,word in ipairs({'HOT','MELT'}) do
    s=fixture({{'ROCK','WRITE',word}});n=step(s)
    assert(n.world.entities[2].class=='text' and n.world.entities[2].text.name==word)
end
print('PASS: MELT precedes CRASH, WRITE HOT/MELT vocabulary')
