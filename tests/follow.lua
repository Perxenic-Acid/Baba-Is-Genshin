-- FOLLOW uses production parsing, scheduling, metadata Commit and whole-turn Undo.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={follow=function(w,r) return RW_ResolveFollow(w,RW_ResolveVerbTargets(w,r,"follow")) end,fear=function(w,r) return RW_ResolveFear(w,RW_ResolveFearTargets(w,r)) end,fall=RW_ResolveFall,automatic=RW_ResolveAutomatic,orient=RW_ResolveOrientation,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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


local s=fixture({{'ROCK','FOLLOW','AVATAR'}})
local n=step(s);assert(n.world.entities[2].x==6 and n.world.entities[2].y==3 and n.world.entities[2].direction=='Left')
s=fixture({{'ROCK','FOLLOW','AVATAR'},{'ROCK','IS','MOVE'}})
n=step(s);assert(n.world.entities[2].x==7 and n.world.entities[2].direction=='Left')
local next=step(n);assert(next.world.entities[2].x==6)
s=fixture({{'ROCK','FOLLOW','AVATAR'},{'ROCK','IS','SLEEP'}})
n=step(s);assert(n.world.entities[2].direction=='Right')
s=fixture({{'ROCK','FOLLOW','AVATAR'},{'ROCK','IS','STILL','AND','REVERSE'}})
n=step(s);assert(n.world.entities[2].direction=='Left')
s=fixture({{'ROCK','FOLLOW','AVATAR'},{'ROCK','FOLLOW','NOT','AVATAR'}})
n=step(s);assert(n.world.entities[2].direction=='Right')
-- Nearest uses Manhattan distance; equal axes choose vertical.
s=fixture({{'ROCK','FOLLOW','AVATAR'}});s.world.entities[1].x,s.world.entities[1].y=8,5
n=step(s);assert(n.world.entities[2].direction=='Down')
-- Adjacent forward wins; the remembered adjacent target is retained next turn.
s=fixture({{'ROCK','FOLLOW','AVATAR'}})
s.world.entities[1].x,s.world.entities[1].y=7,3
object(s.world,3,'avatar',6,2)
n=step(s);assert(n.world.entities[2].followed==1 and n.world.entities[2].direction=='Right')
next=step(n);assert(next.world.entities[2].followed==1)
local stale={consumes_turn=true,changes={{kind='followed',entity_id=2,from=3,to=1}}}
local _,r=RW_Commit(n,stale);assert(not r.accepted and r.reason=='stale_followed')
-- Losing adjacency clears memory while distant tracking still turns.
n.world.entities[1].x=10;n.world.entities[3].y=1
next=step(n);assert(next.world.entities[2].followed==-1 and next.world.entities[2].direction=='Up')
s=fixture({{'ROCK','ON','FLAG','FOLLOW','AVATAR'}})
n=step(s);assert(n.world.entities[2].direction=='Right')
object(s.world,3,'flag',6,3);n=step(s);assert(n.world.entities[2].direction=='Left')
-- Zero-distance/self targets do not turn or create memory.
s=fixture({{'ROCK','FOLLOW','ROCK'}});n=step(s);assert(n.world.entities[2].direction=='Right')
print('PASS: FOLLOW nearest/ties/adjacent memory, MOVE timing, SLEEP/STILL/REVERSE, conditions/NOT, stale plans and Undo')

s=fixture({{'ROCK','FOLLOW','TEXT'}})
s.world.entities[3]={id=3,kind='object',class='text',text={name='NOT'},x=6,y=2,direction='None'}
n=step(s);assert(n.world.entities[2].direction=='Up' and n.world.entities[2].followed==3)
s=fixture({{'ROCK','FOLLOW','AVATAR'},{'ROCK','FACING','LEFT','IS','WIN'}})
n=step(s)
local frame=assert(RW_CompileWorld(n.world,cs))
local effective=assert(RW_ProjectWorld(n.world,frame.effects))
assert(effective.entities[2].behaviors.win,'FACING conditions must see the completed FOLLOW turn')
