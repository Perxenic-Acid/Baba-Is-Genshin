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
local s=fixture({{'ROCK','IS','MOVE'}})
local n=step(s);assert(n.world.entities[2].x==7)
s.world.entities[2].x=24;n=step(s);assert(n.world.entities[2].x==23 and n.world.entities[2].direction=='Left')
s=fixture({{'ROCK','IS','MOVE'},{'FLAG','IS','STOP'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=7,y=3,direction='None'}
s.world.entities[4]={id=4,kind='object',class='object',archetype='flag',x=5,y=3,direction='None'}
n=step(s);assert(n.world.entities[2].x==6 and n.world.entities[2].direction=='Left')
s=fixture({{'ROCK','IS','MOVE'},{'ROCK','IS','MOVE'}});n=step(s);assert(n.world.entities[2].x==8)
s=fixture({{'ROCK','IS','MOVE'},{'ROCK','IS','NOT','MOVE'}});n=step(s);assert(n.world.entities[2].x==6)
-- SLEEP disables self-propulsion and YOU but remains externally pushable/shiftable.
s=fixture({{'AVATAR','IS','YOU','AND','SLEEP'},{'ROCK','IS','MOVE','AND','SLEEP'}})
n=step(s,right);assert(n.world.entities[1].x==2 and n.world.entities[1].direction=='Right' and n.world.entities[2].x==6)
s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','PUSH','AND','SLEEP'}})
s.world.entities[2].x=3;s.world.entities[2].y=2;n=step(s,right);assert(n.world.entities[2].x==4)
-- STILL and directional locks block passive PUSH; SLEEP does not do so.
for _,word in ipairs({'STILL','LOCKEDRIGHT'}) do
    s=fixture({{'AVATAR','IS','YOU'},{'ROCK','IS','PUSH','AND',word}})
    s.world.entities[2].x=3;s.world.entities[2].y=2;n=step(s,right)
    assert(n.world.entities[1].x==2 and n.world.entities[2].x==3)
end
s=fixture({{'AVATAR','IS','YOU','AND','STILL'}});s.world.entities[1].direction='Up'
n=step(s,right);assert(n.world.entities[1].x==2 and n.world.entities[1].direction=='Right')
s=fixture({{'AVATAR','IS','YOU','AND','LOCKEDLEFT'}});n=step(s,right);assert(n.world.entities[1].x==3)
-- Nudges have fixed displacement but preserve the nudged unit's facing.
for _,spec in ipairs({{'NUDGERIGHT',1,0},{'NUDGEUP',0,-1},{'NUDGELEFT',-1,0},{'NUDGEDOWN',0,1}}) do
    s=fixture({{'ROCK','IS',spec[1]}});s.world.entities[2].direction='Up';n=step(s)
    assert(n.world.entities[2].x==6+spec[2] and n.world.entities[2].y==3+spec[3] and n.world.entities[2].direction=='Up')
end
s=fixture({{'ROCK','IS','NUDGERIGHT'},{'ROCK','IS','NUDGERIGHT'}});n=step(s);assert(n.world.entities[2].x==8)
-- Cardinal property tie-breaking and duplicate weights, followed by TURN/DETURN.
s=fixture({{'ROCK','IS','UP'},{'ROCK','IS','RIGHT'}});n=step(s);assert(n.world.entities[2].direction=='Up')
s=fixture({{'ROCK','IS','UP'},{'ROCK','IS','RIGHT'},{'ROCK','IS','RIGHT'}});n=step(s);assert(n.world.entities[2].direction=='Right')
s=fixture({{'ROCK','IS','TURN'}});n=step(s);assert(n.world.entities[2].direction=='Down')
s=fixture({{'ROCK','IS','DETURN'}});n=step(s);assert(n.world.entities[2].direction=='Up')
s=fixture({{'ROCK','IS','TURN'},{'ROCK','IS','TURN'},{'ROCK','IS','DETURN'}});n=step(s);assert(n.world.entities[2].direction=='Down')
s=fixture({{'ROCK','IS','LEFT','AND','SLEEP'}});n=step(s);assert(n.world.entities[2].direction=='Right')
s=fixture({{'ROCK','IS','MOVE','AND','RIGHT'}});n=step(s);assert(n.world.entities[2].x==7 and n.world.entities[2].direction=='Right')
-- Automatic movement deaths use the existing source frame and HAS/Undo contract.
s=fixture({{'ROCK','IS','MOVE','AND','WEAK'},{'ROCK','HAS','FLAG'}});s.world.entities[2].x=24
n=step(s);assert(not n.world.entities[2])
local born=n.world.entities[s.world.next_entity_id];assert(born.archetype=='flag' and born.x==24 and born.y==3)
-- A late error discards movement and orientation and leaves the original history intact.
s=fixture({{'ROCK','IS','MOVE','AND','TURN'}})
local bad={};for k,v in pairs(services) do bad[k]=v end
bad.orient=function() return nil,'injected' end
local failed,e=RW_PlanTurn(s.world,{type='wait'},bad)
assert(not failed and e.stage=='orientation' and s.world.entities[2].x==6 and #s.history==0)
print('PASS: MOVE bounce/multiplicity/NOT, SLEEP vs passive movement, STILL/directional locks, nudges, weighted directions/TURN, HAS/Undo and late rollback')

-- Original take-8 ignores a source's SLEEP for displacement; moveblock's final
-- facing alignment alone checks the sleeping source. Sleeping riders can ride.
s=fixture({{'ROCK','IS','SHIFT','AND','SLEEP'},{'AVATAR','IS','SLEEP'}})
s.world.entities[1].x=6;s.world.entities[1].y=3
n=step(s);assert(n.world.entities[1].x==7)
s=fixture({{'ROCK','IS','SHIFT'},{'AVATAR','IS','STILL'}})
s.world.entities[1].x=6;s.world.entities[1].y=3
n=step(s);assert(n.world.entities[1].x==6)
print('PASS: SLEEP SHIFT source still displaces riders; STILL riders skip shift impulse collection')

s=fixture({{'AVATAR','IS','YOU'},{'ROCK','ON','AVATAR','IS','MOVE'}})
s.world.entities[2].x=3;s.world.entities[2].y=2
n=step(s,right);assert(n.world.entities[1].x==3 and n.world.entities[2].x==4)
print('PASS: automatic spatial capabilities re-evaluate after YOU before impulse collection')
