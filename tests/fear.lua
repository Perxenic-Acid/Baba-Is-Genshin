-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={fear=function(w,r) return RW_ResolveFear(w,RW_ResolveFearTargets(w,r)) end,fall=RW_ResolveFall,automatic=RW_ResolveAutomatic,orient=RW_ResolveOrientation,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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
    local s=fixture(rows);s.world.entities[1].x,s.world.entities[1].y=5,3
    return s
end
local s=setup({{'ROCK','FEAR','AVATAR'}})
local n=step(s);assert(n.world.entities[2].x==7 and n.world.entities[2].direction=='Right')
s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','FEAR','AVATAR'}})
n=step(s);assert(n.world.entities[2].x==8)
s=setup({{'ROCK','FEAR','AVATAR'}});object(s.world,3,'avatar',5,3)
n=step(s);assert(n.world.entities[2].x==7,'stacked witnesses must not multiply fear')
s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','FEAR','NOT','AVATAR'}})
n=step(s);assert(n.world.entities[2].x==6)
s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','IS','SLEEP'}})
n=step(s);assert(n.world.entities[2].x==6)
s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','IS','STILL'}})
s.world.entities[2].direction='Left';n=step(s)
assert(n.world.entities[2].x==6 and n.world.entities[2].direction=='Right')
s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','IS','REVERSE'}})
n=step(s);assert(n.world.entities[2].x==5 and n.world.entities[2].direction=='Right')
s=setup({{'ROCK','FEAR','AVATAR'},{'FLAG','IS','PUSH'}});object(s.world,3,'flag',7,3)
n=step(s);assert(n.world.entities[2].x==7 and n.world.entities[3].x==8)
s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','IS','WEAK'},{'ROCK','HAS','FLAG'},{'FLAG','IS','STOP'}})
object(s.world,3,'flag',7,3);n=step(s)
assert(not n.world.entities[2] and n.world.entities[s.world.next_entity_id].archetype=='flag')
assert(n.world.entities[s.world.next_entity_id].x==6)
s=setup({{'ROCK','ON','FLAG','FEAR','AVATAR'}});object(s.world,3,'flag',6,3);object(s.world,4,'rock',9,3)
n=step(s);assert(n.world.entities[2].x==7 and n.world.entities[4].x==9)
s=setup({{'AVATAR','IS','YOU'},{'ROCK','FEAR','AVATAR'}})
s.world.entities[1].x=4;n=step(s,{type='move',dx=1,dy=0})
assert(n.world.entities[2].x==7,'FEAR queries the post-YOU snapshot')
s=setup({{'ROCK','FEAR','TEXT'}})
object(s.world,3,'flag',5,3);s.world.entities[1].x=2
s.world.entities[3].class='text';s.world.entities[3].archetype=nil;s.world.entities[3].text={name='NOT'}
n=step(s);assert(n.world.entities[2].x==7)
s=setup({{'ROCK','FEAR','EMPTY'}});n=step(s);assert(n.world.entities[2].x==5 and n.world.entities[2].y==3)
s=setup({{'ROCK','FEAR','ALL'}});n=step(s);assert(n.world.entities[2].x==7)

-- HAS products from FEAR destruction receive the same current-turn WEAK grace.
s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','IS','WEAK'},{'ROCK','HAS','FLAG'},
    {'WALL','IS','STOP'},{'FLAG','IS','WEAK'}})
s.world.language.nouns.WALL='wall'
object(s.world,3,'wall',7,3);object(s.world,4,'crate',6,3)
n=step(s);assert(not n.world.entities[2])
assert(n.world.entities[s.world.next_entity_id].archetype=='flag')
for _,lock in ipairs({'LOCKEDLEFT','LOCKEDRIGHT'}) do
    s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','IS','REVERSE','AND',lock}})
    n=step(s);assert(n.world.entities[2].x==6)
end
-- Spatial negative declarations veto only the matching source instance.
s=setup({{'ROCK','FEAR','AVATAR'},{'ROCK','ON','FLAG','FEAR','NOT','AVATAR'}})
object(s.world,3,'flag',6,3)
n=step(s);assert(n.world.entities[2].x==6)

s=setup({{'TEXT','FEAR','AVATAR'}})
s.world.entities[3]={id=3,kind='object',class='text',text={name='ROCK'},x=6,y=3,direction='Right'}
n=step(s);assert(n.world.entities[3].x==7 and n.world.entities[3].text.name=='ROCK')
print('PASS: FEAR multiplicity, bans, conditions, phase ordering, PUSH, WEAK/HAS grace, SLEEP/STILL/REVERSE, TEXT sources, EMPTY/ALL and Undo')
