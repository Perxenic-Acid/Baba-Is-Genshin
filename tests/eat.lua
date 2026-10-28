-- EAT uses the production compiler and frozen destruction/HAS transaction.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={eat=function(w,p,r,c)
    return RW_PlanDestructionPhase(w,RW_ResolveEatVictims(p,RW_ResolveVerbTargets(w,r,"eat")),c,"eat",
        {births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete})
end,make=function(w,r,c)
    local products,rng=RW_PlanMakeProducts(w,r,c)
    local p,e=RW_PlanCreate(w,products);if not p then return nil,e end;p.random_state=rng;return p
end,follow=function(w,r) return RW_ResolveFollow(w,RW_ResolveVerbTargets(w,r,"follow")) end,fear=function(w,r) return RW_ResolveFear(w,RW_ResolveFearTargets(w,r)) end,fall=RW_ResolveFall,automatic=RW_ResolveAutomatic,orient=RW_ResolveOrientation,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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




local function setup(rows)
    local s=fixture(rows);s.world.entities[1].x,s.world.entities[1].y=6,3;return s
end
local s=setup({{'ROCK','EAT','AVATAR'}})
local n=step(s);assert(n.world.entities[2] and not n.world.entities[1])
s=setup({{'ROCK','EAT','ROCK'}});n=step(s);assert(n.world.entities[2])
object(s.world,3,'rock',6,3);n=step(s);assert(not n.world.entities[2] and not n.world.entities[3])
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','EAT','ROCK'}})
n=step(s);assert(not n.world.entities[1] and not n.world.entities[2])
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','IS','SAFE'}})
n=step(s);assert(n.world.entities[1])
s=setup({{'ROCK','EAT','AVATAR'},{'ROCK','IS','SAFE','AND','SLEEP'}})
n=step(s);assert(not n.world.entities[1] and n.world.entities[2])
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','IS','FLOAT'}})
n=step(s);assert(n.world.entities[1])
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','IS','FLOAT'},{'ROCK','IS','FLOAT'}})
n=step(s);assert(not n.world.entities[1])
-- Duplicate EAT declarations select each identity once; HAS remains multiplicative.
s=setup({{'ROCK','EAT','AVATAR'},{'ROCK','EAT','AVATAR'},{'AVATAR','HAS','FLAG'},{'AVATAR','HAS','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+2)
for id=s.world.next_entity_id,n.world.next_entity_id-1 do assert(n.world.entities[id].archetype=='flag') end
s=setup({{'ROCK','ON','FLAG','EAT','AVATAR'}})
n=step(s);assert(n.world.entities[1])
object(s.world,3,'flag',6,3);n=step(s);assert(not n.world.entities[1])
s=setup({{'ROCK','EAT','AVATAR'},{'ROCK','ON','FLAG','EAT','NOT','AVATAR'}})
object(s.world,3,'flag',6,3);object(s.world,4,'rock',9,3);object(s.world,5,'avatar',9,3)
n=step(s);assert(n.world.entities[1] and not n.world.entities[5])
-- Deleted Text does not erase the frozen MAKE declaration halfway through contacts.
s=fixture({{'ROCK','EAT','TEXT'},{'ROCK','MAKE','FLAG'}})
s.world.entities[2].x,s.world.entities[2].y=2,8
n=step(s);assert(not n.world.entities[14] and n.world.entities[s.world.next_entity_id].archetype=='flag')
-- HAS products are not recursively eaten in their birth phase.
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','HAS','AVATAR'}})
n=step(s);local id=s.world.next_entity_id
assert(not n.world.entities[1] and n.world.entities[id].archetype=='avatar')
local again=step(n);assert(not again.world.entities[id] and again.world.next_entity_id==n.world.next_entity_id+1)
-- EAT precedes MAKE; newborn HAS blockers are treated as converted for MAKE.
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','HAS','FLAG'},{'ROCK','MAKE','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+2)
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','MAKE','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id)
-- Sources destroyed by earlier WEAK do not eat.
s=setup({{'ROCK','EAT','AVATAR'},{'ROCK','IS','WEAK'}})
n=step(s);assert(not n.world.entities[2] and n.world.entities[1])
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','IS','CRASH'}})
n=step(s);assert(not n.world.infinite_loop)
s=setup({{'ROCK','EAT','AVATAR'},{'AVATAR','HAS','FLAG'},{'FLAG','IS','CRASH'}})
n=step(s);assert(n.world.infinite_loop and n.world.entities[s.world.next_entity_id].archetype=='flag')
-- Ordinary ALL excludes physical Text and deduplicates self/overlap.
s=setup({{'ROCK','EAT','ALL'}})
object(s.world,3,'flag',6,3);s.world.entities[4]={id=4,kind='object',class='text',text={name='NOT'},x=6,y=3,direction='None'}
n=step(s);assert(not n.world.entities[1] and not n.world.entities[3] and n.world.entities[2] and n.world.entities[4])
s=setup({{'ROCK','EAT','EMPTY'}});n=step(s);assert(n.world.entities[1] and n.world.entities[2])
print('PASS: EAT self/mutual/duplicate targets, SAFE/FLOAT/SLEEP, conditions/NOT, HAS, frozen Text, MAKE/CRASH order and Undo')
