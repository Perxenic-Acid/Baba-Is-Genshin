-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={automatic=RW_ResolveAutomatic,orient=RW_ResolveOrientation,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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

local right={type='move',dx=1,dy=0}
local function object(w,id,name,x,y,direction)
    w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=y,direction=direction or 'Up'}
end
local s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','PULL'}})
s.world.entities[1].x=4;s.world.entities[1].y=3;s.world.entities[2].x=3
object(s.world,3,'rock',2,3)
local n=step(s,right)
assert(n.world.entities[1].x==5 and n.world.entities[2].x==4 and n.world.entities[3].x==3)
assert(n.world.entities[2].direction=='Right' and n.world.entities[3].direction=='Right')
-- PULL is solid from the front, PUSH+PULL can be pushed.
s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','PULL'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;n=step(s,right);assert(n.world.entities[1].x==2)
s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','PULL','AND','PUSH'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;n=step(s,right);assert(n.world.entities[2].x==4)
-- Pull failure leaves the mover free, and a blocked WEAK trailing object survives.
s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','PULL','AND','WEAK'},{'FLAG','IS','STOP'}})
s.world.entities[1].x=4;s.world.entities[1].y=3;s.world.entities[2].x=3
object(s.world,3,'flag',4,3)
n=step(s,right);assert(n.world.entities[1].x==5 and n.world.entities[2].x==3)
s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','PULL','AND','STILL'}})
s.world.entities[1].x=4;s.world.entities[1].y=3;s.world.entities[2].x=3
n=step(s,right);assert(n.world.entities[1].x==5 and n.world.entities[2].x==3)
-- Pushed objects may themselves pull a trailing chain.
s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','PUSH'},{'FLAG','IS','PULL'}})
s.world.entities[2].x=3;s.world.entities[2].y=2
object(s.world,3,'flag',2,2)
n=step(s,right);assert(n.world.entities[1].x==3 and n.world.entities[2].x==4 and n.world.entities[3].x==3)
-- SWAP target vs SWAP mover; target keeps its own facing, FLOAT does not filter.
s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','SWAP','AND','STOP','AND','FLOAT'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;s.world.entities[2].direction='Up'
n=step(s,right);assert(n.world.entities[1].x==3 and n.world.entities[2].x==2 and n.world.entities[2].direction=='Up')
s=fixture({{'AVATAR','IS','YOU','AND','SWAP'},{'ROCK','IS','STOP'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;object(s.world,3,'rock',3,2)
n=step(s,right);assert(n.world.entities[1].x==3 and n.world.entities[2].x==2 and n.world.entities[3].x==2)
s=fixture({{'AVATAR','IS','YOU','AND','SWAP'},{'ROCK','IS','STOP','AND','STILL'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;n=step(s,right)
assert(n.world.entities[1].x==3 and n.world.entities[2].x==3)
-- Unrelated blockers still cancel a target SWAP; no speculative swap leaks.
s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','SWAP'},{'FLAG','IS','STOP'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;object(s.world,3,'flag',3,2)
n=step(s,right);assert(n.world.entities[1].x==2 and n.world.entities[2].x==3)
-- PHANTOM bypasses STOP/PUSH/PULL solidity; subsequent contacts still apply.
s=fixture({{'AVATAR','IS','YOU','AND','PHANTOM'},{'ROCK','IS','PUSH','AND','STOP'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;n=step(s,right)
assert(n.world.entities[1].x==3 and n.world.entities[2].x==3)
s=fixture({{'AVATAR','IS','YOU','AND','PHANTOM'},{'ROCK','IS','DEFEAT','AND','STOP'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;n=step(s,right);assert(not n.world.entities[1])
s=fixture({{'AVATAR','IS','YOU','AND','PHANTOM','AND','NOT','PHANTOM'},{'ROCK','IS','STOP'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;n=step(s,right);assert(n.world.entities[1].x==2)
-- Newly implemented PULL also blocks MORE (regardless of FLOAT).
s=fixture({{'ROCK','IS','MORE'},{'FLAG','IS','PULL','AND','FLOAT'}})
object(s.world,3,'flag',7,3);n=step(s)
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then assert(e.x~=7 or e.y~=3) end end
print('PASS: PULL chains/front solidity/failure isolation, SWAP stacks/STILL/layers, PHANTOM collisions vs contacts, MORE and Undo')
