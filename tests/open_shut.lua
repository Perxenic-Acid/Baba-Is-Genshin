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
    assert(#n.history==1);return n,plan
end
local s=fixture({{'AVATAR','IS','OPEN'},{'ROCK','IS','SHUT','AND','STOP'},{'AVATAR','HAS','CRATE'},{'ROCK','HAS','FLAG'}})
local frontier=s.world.next_entity_id
local n,p=step(s)
assert(not n.world.entities[1] and not n.world.entities[2] and n.world.entities[3])
assert(n.world.entities[frontier].archetype=='flag' and n.world.entities[frontier].x==3)
assert(n.world.entities[frontier+1].archetype=='crate' and n.world.entities[frontier+1].x==2)
assert(n.world.entities[frontier+1].direction=='Right')
for _,a in ipairs({false,true}) do for _,b in ipairs({false,true}) do
 local aa={'AVATAR','IS','OPEN'};if a then aa={'AVATAR','IS','OPEN','AND','SAFE'} end
 local bb={'ROCK','IS','SHUT','AND','STOP'};if b then bb={'ROCK','IS','SHUT','AND','STOP','AND','SAFE'} end
 s=fixture({aa,bb});n=step(s)
 assert((n.world.entities[1]~=nil)==a)
 assert((n.world.entities[2]~=nil)==b)
 if a then assert(n.world.entities[1].x==(b and 2 or 3)) end
end end
-- A separate STOP sharing the door blocks the whole speculative unlock.
s=fixture({{'AVATAR','IS','OPEN'},{'ROCK','IS','SHUT','AND','STOP'},{'CRATE','IS','STOP'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=3,y=2,direction='None'}
n=step(s);assert(n.world.entities[1].x==2 and n.world.entities[2] and n.world.entities[4])
-- A pushed key unlocks at its source while YOU advances behind it.
s=fixture({{'ROCK','IS','OPEN','AND','PUSH'},{'CRATE','IS','SHUT','AND','STOP'},{'ROCK','HAS','FLAG'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=4,y=2,direction='None'}
frontier=s.world.next_entity_id;n=step(s)
assert(n.world.entities[1].x==3 and not n.world.entities[2] and not n.world.entities[4])
assert(n.world.entities[frontier].x==3 and n.world.entities[frontier].direction=='Right')
-- Unsafe opener is consumed by the first target; SAFE opener consumes both.
for _,safe in ipairs({false,true}) do
 local aa={'AVATAR','IS','OPEN'};if safe then aa={'AVATAR','IS','OPEN','AND','SAFE'} end
 s=fixture({aa,{'ROCK','IS','SHUT','AND','STOP'}})
 s.world.entities[3].x=3;n=step(s)
 assert(not n.world.entities[2] and (n.world.entities[3]~=nil)==(not safe))
end
-- Same-unit OPEN+SHUT contact and SAFE protection.
for _,safe in ipairs({false,true}) do
 local words={'ROCK','IS','OPEN','AND','SHUT'};if safe then words={'ROCK','IS','OPEN','AND','SHUT','AND','SAFE'} end
 s=fixture({words});n=step(s);assert((n.world.entities[3]~=nil)==safe)
end
-- Conditional HAS uses the death frame before a SAFE opener enters the door cell.
s=fixture({{'AVATAR','IS','OPEN','AND','SAFE'},{'ROCK','IS','SHUT','AND','STOP'},{'ROCK','ON','AVATAR','HAS','FLAG'}})
frontier=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==frontier and n.world.entities[1].x==3)
-- Late failure cannot leak either deaths or allocated HAS identities.
s=fixture({{'AVATAR','IS','OPEN'},{'ROCK','IS','SHUT'},{'ROCK','HAS','FLAG'}})
local bad={};for k,v in pairs(services) do bad[k]=v end
bad.contact=function() return nil,'injected' end
local failed,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},bad)
assert(not failed and s.world.entities[1].x==2 and s.world.entities[2] and #s.history==0)
for _,word in ipairs({'OPEN','SHUT'}) do
 s=fixture({{'ROCK','WRITE',word}});n=step(s);assert(n.world.entities[2].text.name==word)
end
print('PASS: OPEN/SHUT movement, SAFE matrix, blockers, pushed keys, stacked doors, self-contact, conditional HAS, rollback and Undo')

-- Contact selects the first OPEN per noun type, retaining same-type extras.
s=fixture({{'AVATAR','IS','OPEN'},{'ROCK','IS','OPEN'},{'CRATE','IS','SHUT'}})
s.world.entities[1].x=2;s.world.entities[2].x=7;s.world.entities[3].x=7
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=7,y=2,direction='None'}
s.world.entities[5]={id=5,kind='object',class='object',archetype='avatar',x=7,y=2,direction='None'}
-- Use direct contact to avoid the extra YOU moving away.
local frame=assert(RW_CompileWorld(s.world,cs));local projected=assert(RW_ProjectWorld(s.world,frame.effects))
local victims=assert(RW_ResolveContactVictims(projected,'unlock'));local got={}
for _,id in ipairs(victims) do got[id]=true end
assert(got[2] and got[4] and got[5] and not got[3])
s=fixture({{'AVATAR','IS','OPEN'},{'ROCK','IS','SHUT','AND','CRASH'}})
n=step(s);assert(not n.world.entities[1] and not n.world.entities[2])
-- The remote SHUT+CRASH survives and must still trigger INFINITE LOOP.
assert(n.world.infinite_loop)
s=fixture({{'AVATAR','IS','OPEN'},{'AVATAR','IS','NOT','OPEN'},{'ROCK','IS','SHUT','AND','STOP'}})
n=step(s);assert(n.world.entities[1].x==2 and n.world.entities[2])
print('PASS: OPEN/SHUT heterogeneous contact multiplicity, surviving CRASH and NOT override')
