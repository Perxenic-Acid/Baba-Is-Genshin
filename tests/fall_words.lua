-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={fall=RW_ResolveFall,automatic=RW_ResolveAutomatic,orient=RW_ResolveOrientation,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules end}

local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.width,w.height=24,24;w.entities={};w.next_entity_id=10
    w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
    w.entities[1]={id=1,kind='object',class='object',archetype='avatar',x=2,y=2,direction='Right'}
    w.entities[2]={id=2,kind='object',class='object',archetype='rock',x=6,y=3,direction='Right'}
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row,direction='None'}
    end end
    return s
end
local function step(s,action)
    local p,e=RW_PlanTurn(s.world,action or {type='wait'},services);assert(p,e and e.reason)
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
    assert(RW_Undo(n).world==s.world and #n.history==#s.history+1)
    return n,p
end

local function object(w,id,name,x,y,dir)
    w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=y,direction=dir or 'Left'}
end
for _,spec in ipairs({{'FALL',6,24},{'FALLRIGHT',24,3},{'FALLUP',6,1},{'FALLLEFT',1,3}}) do
    local s=fixture({{'ROCK','IS',spec[1]}})
    -- Keep falling noun away from physical rule Text which is valid support.
    for id,e in pairs(s.world.entities) do if e.class=='text' then e.x=e.x+10 end end
    local n=step(s)
    assert(n.world.entities[2].x==spec[2] and n.world.entities[2].y==spec[3],spec[1])
    assert(n.world.entities[2].direction=='Right')
end
local s=fixture({{'ROCK','IS','FALL'},{'FLAG','IS','PUSH'}})
object(s.world,3,'flag',6,8)
local n=step(s);assert(n.world.entities[2].y==7 and n.world.entities[3].y==8)
s=fixture({{'ROCK','IS','FALL'},{'FLAG','IS','PULL'}});object(s.world,3,'flag',6,8)
n=step(s);assert(n.world.entities[2].y==7)
s=fixture({{'ROCK','IS','FALL','AND','STILL'}});n=step(s);assert(n.world.entities[2].y==3)
s=fixture({{'ROCK','IS','FALL','AND','SLEEP'}});n=step(s);assert(n.world.entities[2].y==24)
s=fixture({{'ROCK','IS','FALL','AND','LOCKEDDOWN'}});n=step(s);assert(n.world.entities[2].y==3)
s=fixture({{'ROCK','IS','FALL','AND','FALLUP'}});n=step(s);assert(n.world.entities[2].y==3)
s=fixture({{'ROCK','IS','FALL','AND','FALLUP'},{'ROCK','IS','FALL'}});n=step(s);assert(n.world.entities[2].y==24)
-- Multiple falling PUSH objects settle without pushing their supports away.
s=fixture({{'ROCK','IS','FALL','AND','PUSH'}});object(s.world,3,'rock',6,5)
n=step(s);assert(n.world.entities[2].y==23 and n.world.entities[3].y==24)
-- WEAK falling units stop rather than shatter merely from resting on support.
s=fixture({{'ROCK','IS','FALL','AND','WEAK'},{'FLAG','IS','STOP'}});object(s.world,3,'flag',6,8)
n=step(s);assert(n.world.entities[2] and n.world.entities[2].y==7)
-- Unsafe bare WEAK obstacles encountered mid-fall are destroyed with HAS.
s=fixture({{'ROCK','IS','FALL'},{'FLAG','IS','WEAK','AND','STOP'},{'FLAG','HAS','AVATAR'}})
object(s.world,3,'flag',6,5)
n=step(s);assert(not n.world.entities[3] and n.world.entities[2].y==24)
assert(n.world.entities[s.world.next_entity_id].archetype=='avatar' and n.world.entities[s.world.next_entity_id].y==5)
-- SWAP does not move its partner during FALL; the falling object can overlap it.
s=fixture({{'ROCK','IS','FALL'},{'FLAG','IS','SWAP','AND','STOP'}});object(s.world,3,'flag',6,8)
n=step(s);assert(n.world.entities[2].y==24 and n.world.entities[3].y==8)
print('PASS: four FALL directions, weighted cancellation, support/PULL/PUSH stacks, SLEEP/STILL/locks, WEAK/HAS/SWAP and Undo')
