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
    w.language.properties.SELECT='select';w.language.nouns.LEVEL={tag='level',block_type='level_block'}
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

for count=0,4 do
    local rows={{'AVATAR','IS','YOU'}}
    for i=1,count do rows[#rows+1]={'AVATAR','IS','REVERSE'} end
    local s=fixture(rows);s.world.entities[1].x=10
    local n=step(s,{type='move',dx=1,dy=0})
    assert(n.world.entities[1].x==(count%2==1 and 9 or 11))
    assert(n.world.entities[1].direction=='Right')
end
local s=fixture({{'AVATAR','IS','YOU','AND','REVERSE'},{'ROCK','IS','PUSH','AND','REVERSE'}})
s.world.entities[1].x=7
local n=step(s,{type='move',dx=1,dy=0})
-- No collision: move onto the row below the rock.
assert(n.world.entities[1].x==6)
s.world.entities[2].y=2
n=step(s,{type='move',dx=1,dy=0})
assert(n.world.entities[2].x==5 and n.world.entities[2].direction=='Left')
assert(n.world.entities[1].direction=='Right')
s=fixture({{'ROCK','IS','MOVE','AND','REVERSE'}})
n=step(s);assert(n.world.entities[2].x==5 and n.world.entities[2].direction=='Right')
s=fixture({{'ROCK','IS','NUDGERIGHT','AND','REVERSE'}})
n=step(s);assert(n.world.entities[2].x==5 and n.world.entities[2].direction=='Right')
s=fixture({{'ROCK','IS','FALL','AND','REVERSE'}})
n=step(s);assert(n.world.entities[2].y==1 and n.world.entities[2].direction=='Right')
s=fixture({{'AVATAR','IS','YOU','AND','REVERSE','AND','LOCKEDLEFT'}})
n=step(s,{type='move',dx=1,dy=0});assert(n.world.entities[1].x==1 and n.world.entities[1].direction=='Right')
s=fixture({{'AVATAR','IS','YOU','AND','REVERSE','AND','LOCKEDRIGHT'}})
n=step(s,{type='move',dx=1,dy=0});assert(n.world.entities[1].x==2)
s=fixture({{'ROCK','IS','SHIFT'},{'AVATAR','IS','REVERSE'}})
s.world.entities[1].x,s.world.entities[1].y=6,3
n=step(s);assert(n.world.entities[1].x==5)

-- SELECT follows the reversed path and faces its actual travel direction.
s=fixture({{'AVATAR','IS','SELECT','AND','REVERSE'}})
object(s.world,3,'level_block',1,2)
n=step(s,{type='move',dx=1,dy=0})
assert(n.world.entities[1].x==1 and n.world.entities[1].direction=='Left')
s=fixture({{'LEVEL','IS','YOU','AND','REVERSE'}})
n=step(s,{type='move',dx=1,dy=0})
assert(n.world.board_offset.x==-1 and n.world.board_offset.direction=='Left')
print('PASS: REVERSE parity, facing, dependencies, MOVE/nudge/FALL/SHIFT, SELECT/LEVEL, locks and atomic Undo')

s=fixture({{'ROCK','IS','FALL','AND','FALLRIGHT','AND','REVERSE'}})
n=step(s);assert(n.world.entities[2].x==1 and n.world.entities[2].y==1)
