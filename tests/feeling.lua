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





local function projection(s)
    local f=assert(RW_CompileWorld(s.world,cs));return assert(RW_ProjectWorld(s.world,f.effects)),f
end
local s=fixture({{'ROCK','IS','PUSH'},{'ROCK','FEELING','PUSH','IS','FLOAT'}})
local w,f=projection(s);assert(w.entities[2].behaviors.float)
for id=13,17 do assert(f.active_text_ids[id]) end
s=fixture({{'ROCK','FEELING','NOT','PUSH','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float,'NOT PUSH is another property, not absence')
s=fixture({{'ROCK','IS','SAFE'},{'ROCK','IS','PUSH'},{'ROCK','FEELING','NOT','PUSH','IS','FLOAT'}})
w=projection(s);assert(w.entities[2].behaviors.float,'NOT PUSH may succeed even when PUSH is also present')
s=fixture({{'ROCK','IS','NOT','PUSH'},{'ROCK','FEELING','PUSH','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float)
s=fixture({{'ROCK','IS','PUSH'},{'ROCK','IS','NOT','PUSH'},{'ROCK','FEELING','PUSH','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float,'denial suppresses positive property')
s=fixture({{'ROCK','IS','PUSH'},{'ROCK','FEELING','PUSH','AND','PUSH','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float,'one declaration cannot satisfy two FEELING parameters')
s=fixture({{'ROCK','IS','PUSH'},{'ROCK','IS','PUSH'},{'ROCK','FEELING','PUSH','AND','PUSH','IS','FLOAT'}})
w=projection(s);assert(w.entities[2].behaviors.float)
s=fixture({{'ROCK','NEAR','AVATAR','IS','PUSH'},{'ROCK','FEELING','PUSH','IS','FLOAT'}})
s.world.entities[1].x=5;s.world.entities[1].y=3;object(s.world,3,'rock',10,3)
w=projection(s);assert(w.entities[2].behaviors.float and not w.entities[3].behaviors.float)
s.world.entities[1].x=2;w=projection(s);assert(not w.entities[2].behaviors.float,'recompile current conditions, not last-frame facts')
s=fixture({{'ROCK','IS','RIGHT'},{'ROCK','FEELING','RIGHT','IS','FLOAT'}})
s.world.entities[2].direction='Left';w=projection(s);assert(w.entities[2].behaviors.float,'FEELING RIGHT is a rule-derived property')
s=fixture({{'ROCK','IS','PUSH'},{'ROCK','FEELING','PUSH','BECOME','FLAG'}})
local n,p=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','IS','YOU','AND','DEFEAT'},{'ROCK','FEELING','YOU','HAS','FLAG'}})
n,p=step(s);local born=false;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then born=true end end;assert(born)
s=fixture({{'ROCK','IS','PUSH'},{'ROCK','FEELING','PUSH','IS','WORD'}})
w,f=projection(s);assert(f.word_tokens[2]=='ROCK')
s=fixture({{'ROCK','FEELING','PUSH','IS','PUSH'},{'ROCK','FEELING','PUSH','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.push and not w.entities[2].behaviors.float,'self-support is not grounded')
s=fixture({{'ROCK','FEELING','PUSH','IS','FLOAT'},{'ROCK','FEELING','FLOAT','IS','PUSH'}})
w=projection(s);assert(not w.entities[2].behaviors.push and not w.entities[2].behaviors.float,'mutual support is bounded')
s=fixture({{'TEXT','FEELING','PUSH','IS','FLOAT'}})
w=projection(s);assert(w.entities[10].behaviors.float,'physical Text can feel default PUSH')
s=fixture({{'EMPTY','IS','SAFE'},{'EMPTY','FEELING','SAFE','IS','FLOAT'}})
w=projection(s);assert(w.empty_cells['1:1'].behaviors.float)
s=fixture({{'ROCK','IS','PUSH'},{'ROCK','NOT','FEELING','PUSH','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float)
s=fixture({{'ROCK','FEELING','FLAG','IS','PUSH'}})
f=assert(RW_CompileWorld(s.world,cs));for _,rule in ipairs(f.ast) do for _,clause in ipairs(rule.when.clauses or {}) do assert(clause.relation~='feeling','FEELING only accepts property arguments') end end
s=fixture({{'ROCK','SEEING','AVATAR','IS','PUSH'},{'ROCK','FEELING','PUSH','BECOME','FLAG'}})
s.world.entities[2].direction='Left';s.world.entities[1].x=2;s.world.entities[1].y=3
n,p=step(s);assert(n.world.entities[2].archetype=='flag','SEEING grant available through FEELING conversion frame')
assert(not n.world._condition_rules and not n.world._condition_guard and not n.world._feeling_checked)
print('PASS: FEELING rule properties, positive/complement/NOT, condition multiplicity, identity/EMPTY/Text, conversion/HAS/WORD/SEEING, bounded grounding and Undo')
