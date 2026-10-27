-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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
    assert(#n.history==#s.history+1);return n,plan
end
local s=fixture({{'AVATAR','IS','WEAK'},{'ROCK','IS','STOP'},{'AVATAR','HAS','CRATE'}})
local f=s.world.next_entity_id;local n,p=step(s)
assert(not n.world.entities[1] and n.world.entities[2] and n.world.entities[f].x==2)
assert(n.world.entities[f].direction=='Right')
local stages={};for i,v in ipairs(p.stages) do stages[v.name]=i end
assert(stages.sink<stages.weak and stages.weak<stages.melt)
-- Safe blocked YOU turns without shattering; boundary uses the same rule.
s=fixture({{'AVATAR','IS','WEAK','AND','SAFE'},{'ROCK','IS','STOP'}})
n=step(s);assert(n.world.entities[1].x==2 and n.world.entities[1].direction=='Right')
s=fixture({{'AVATAR','IS','WEAK'},{'AVATAR','HAS','CRATE'}})
s.world.entities[1].x=s.world.width;f=s.world.next_entity_id;n=step(s)
assert(not n.world.entities[1] and n.world.entities[f].x==s.world.width)
-- PUSH WEAK moves when free, and shatters when blocked by STOP or the edge.
s=fixture({{'ROCK','IS','WEAK','AND','PUSH'}});n=step(s)
assert(n.world.entities[1].x==3 and n.world.entities[2].x==4)
s=fixture({{'ROCK','IS','WEAK','AND','PUSH'},{'CRATE','IS','STOP'},{'ROCK','HAS','FLAG'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=4,y=2,direction='None'}
f=s.world.next_entity_id;n=step(s)
assert(n.world.entities[1].x==3 and not n.world.entities[2] and n.world.entities[4])
assert(n.world.entities[f].x==3 and n.world.entities[f].direction=='Right')
-- Both safe: failed PUSH remains blocking and there are no births.
s=fixture({{'ROCK','IS','WEAK','AND','PUSH','AND','SAFE'},{'CRATE','IS','STOP'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=4,y=2,direction='None'}
n=step(s);assert(n.world.entities[1].x==2 and n.world.entities[2].x==3)
-- A bare WEAK STOP is permeable; SAFE protects it but does not restore STOP.
for _,safe in ipairs({false,true}) do
 local row={'ROCK','IS','WEAK','AND','STOP'};if safe then row={'ROCK','IS','WEAK','AND','STOP','AND','SAFE'} end
 s=fixture({row});n=step(s)
 assert(n.world.entities[1].x==3 and (n.world.entities[2]~=nil)==safe)
end
-- No self-contact: isolated WEAK lives; all unsafe overlapping WEAK die as a batch.
s=fixture({{'ROCK','IS','WEAK'}});n=step(s)
assert(not n.world.entities[2] and n.world.entities[3])
s=fixture({{'AVATAR','IS','WEAK'},{'ROCK','IS','WEAK'}});n=step(s)
assert(not n.world.entities[1] and not n.world.entities[2] and n.world.entities[3])
-- WEAK precedes MELT: a weak HOT source disappears before heating YOU.
s=fixture({{'ROCK','IS','WEAK','AND','HOT'},{'AVATAR','IS','MELT'}});n=step(s)
assert(n.world.entities[1] and not n.world.entities[2])
-- SINK HAS newborn survives WEAK this turn, then loses protection next turn.
s=fixture({{'ROCK','IS','SINK','AND','SAFE'},{'AVATAR','HAS','CRATE'},{'CRATE','IS','WEAK'}})
f=s.world.next_entity_id;n=step(s);assert(n.world.entities[f] and n.world.entities[2])
for _,entity in pairs(n.world.entities) do
 if entity.text and entity.text.name=='SINK' then entity.text.name='SAFE' end
end
local nn=step(n);assert(not nn.world.entities[f])
-- Conditional WEAK and negative grants are per identity.
s=fixture({{'ROCK','ON','AVATAR','IS','WEAK'}});n=step(s)
assert(not n.world.entities[2] and n.world.entities[3])
s=fixture({{'ROCK','IS','WEAK'},{'ROCK','IS','NOT','WEAK'}});n=step(s)
assert(n.world.entities[2])
-- A failed weak root discards speculative pushes from other overlap occupants.
s=fixture({{'AVATAR','IS','WEAK'},{'ROCK','IS','PUSH'},{'CRATE','IS','STOP'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=3,y=2,direction='None'}
n=step(s);assert(not n.world.entities[1] and n.world.entities[2].x==3)
-- Failure after destruction and HAS allocation leaves the source untouched.
s=fixture({{'AVATAR','IS','WEAK'},{'ROCK','IS','STOP'},{'AVATAR','HAS','CRATE'}})
local bad={};for k,v in pairs(services) do bad[k]=v end
bad.contact=function() return nil,'injected' end
local failed,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},bad)
assert(not failed and s.world.entities[1].x==2 and #s.history==0)
s=fixture({{'ROCK','WRITE','WEAK'}});n=step(s);assert(n.world.entities[2].text.name=='WEAK')
print('PASS: WEAK blocked YOU, PUSH, SAFE, STOP, overlap, HAS newborn grace, conditions, NOT, phase order, rollback and Undo')

-- Conversion products are not protected as HAS newborns: original convert.lua clears new.
s=fixture({{'ROCK','IS','CRATE','AND','FLAG'},{'CRATE','IS','WEAK'}})
n=step(s)
local flags=0;for _,entity in pairs(n.world.entities) do
 assert(entity.archetype~='crate');if entity.archetype=='flag' then flags=flags+1 end
end
assert(flags==2)
-- Movement HAS also receives newborn grace despite a survivor on the same tile.
s=fixture({{'AVATAR','IS','OPEN','AND','SAFE'},{'ROCK','IS','SHUT'},{'ROCK','HAS','CRATE'},{'CRATE','IS','WEAK'}})
f=s.world.next_entity_id;n=step(s);assert(n.world.entities[f] and n.world.entities[f].x==3)
print('PASS: HAS grace expires next turn; conversion products remain vulnerable immediately')
