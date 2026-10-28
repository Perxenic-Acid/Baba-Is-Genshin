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

local function frame(s)
    return assert(RW_CompileWorld(s.world,cs))
end
local function projected(s)
    return assert(RW_ProjectWorld(s.world,frame(s).effects))
end
local vectors={NEXTTO={1,0},ABOVE={0,3},BELOW={0,-2},BESIDELEFT={3,0},BESIDERIGHT={-3,0},FACING={1,0}}
for relation,offset in pairs(vectors) do
    local s=fixture({{'ROCK',relation,'FLAG','IS','PUSH'}})
    s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=6+offset[1],y=3+offset[2],direction='Left'}
    s.world.entities[4]={id=4,kind='object',class='object',archetype='rock',x=12,y=4,direction='Down'}
    local f=frame(s);assert(#f.deferred==0)
    local p=projected(s)
    assert(p.entities[2].behaviors.push and not p.entities[4].behaviors.push,relation)
end
local s=fixture({{'ROCK','FACING','RIGHT','IS','PUSH'}})
assert(projected(s).entities[2].behaviors.push)
s.world.entities[2].direction='Up';assert(not projected(s).entities[2].behaviors.push)
s=fixture({{'ROCK','FACING','NOT','RIGHT','IS','PUSH'}})
assert(not projected(s).entities[2].behaviors.push)
s.world.entities[2].direction='Up';assert(projected(s).entities[2].behaviors.push)
s=fixture({{'ROCK','NOT','FACING','RIGHT','IS','PUSH'}})
s.world.entities[2].direction='Up';assert(projected(s).entities[2].behaviors.push)
-- NEXTTO excludes diagonals and co-location, NEAR includes both.
s=fixture({{'ROCK','NEXTTO','FLAG','IS','PUSH'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=7,y=4,direction='None'}
assert(not projected(s).entities[2].behaviors.push)
s.world.entities[3].x=6;s.world.entities[3].y=3;assert(not projected(s).entities[2].behaviors.push)
-- Distinct AND witnesses, including repeated noun parameters.
s=fixture({{'ROCK','NEXTTO','FLAG','AND','FLAG','IS','PUSH'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=7,y=3,direction='None'}
assert(not projected(s).entities[2].behaviors.push)
s.world.entities[4]={id=4,kind='object',class='object',archetype='flag',x=6,y=4,direction='None'}
assert(projected(s).entities[2].behaviors.push)
-- Conditional conversion and HAS keep source-local spatial conditions.
s=fixture({{'ROCK','ABOVE','FLAG','IS','TEXT'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=6,y=5,direction='None'}
local n=step(s);assert(n.world.entities[2].text.name=='ROCK')
s=fixture({{'ROCK','IS','DEFEAT','AND','YOU'},{'ROCK','FACING','FLAG','HAS','FLAG'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=7,y=3,direction='None'}
n=step(s);assert(not n.world.entities[2] and n.world.entities[s.world.next_entity_id].archetype=='flag')
-- Only direction properties may be FACING arguments; IS/HAS don't gain noun coercions.
s=fixture({{'ROCK','FACING','WIN','IS','PUSH'}})
assert(not projected(s).entities[2].behaviors.push)
print('PASS: spatial extension parser/activation/NOT/AND, per-identity queries, conditional TEXT/HAS and Undo')
