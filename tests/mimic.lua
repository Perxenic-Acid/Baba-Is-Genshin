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





local s=fixture({{'ROCK','MIMIC','AVATAR'},{'AVATAR','IS','YOU'}})
local frame=assert(RW_CompileWorld(s.world,cs));assert(#frame.deferred==0)
local n=step(s,{type='move',dx=1,dy=0});assert(n.world.entities[2].x==7)
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','IS','PUSH'},{'AVATAR','MIMIC','ROCK'}})
frame=assert(RW_CompileWorld(s.world,cs))
local function trait(frame,id,name)
    local p=assert(RW_ProjectWorld(s.world,frame.effects));return (p.entities[id].traits or {})[name]
end
assert(trait(frame,2,'pushable'));assert(not trait(frame,1,'pushable'),'no transitive MIMIC')
s=fixture({{'ROCK','MIMIC','FLAG'},{'ROCK','MIMIC','NOT','FLAG'},{'FLAG','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(not trait(frame,2,'pushable'))
s=fixture({{'ROCK','ON','AVATAR','MIMIC','FLAG'},{'FLAG','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(not trait(frame,2,'pushable'))
s.world.entities[1].x=6;s.world.entities[1].y=3
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,2,'pushable'))
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','ON','AVATAR','IS','PUSH'}})
s.world.entities[1].x=6;s.world.entities[1].y=3
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,2,'pushable'),'copied condition evaluated at imitator')
s=fixture({{'ROCK','MIMIC','FLAG'},{'ROCK','ON','AVATAR','MIMIC','NOT','FLAG'},{'FLAG','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,2,'pushable'))
s.world.entities[1].x=6;s.world.entities[1].y=3
frame=assert(RW_CompileWorld(s.world,cs));assert(not trait(frame,2,'pushable'))
s=fixture({{'ROCK','MIMIC','FLAG'},{'ROCK','MIMIC','FLAG'},{'FLAG','BECOME','CRATE'}})
n=step(s);local count=0;for _,e in pairs(n.world.entities) do if e.archetype=='crate' then count=count+1 end end
assert(count==2,'duplicate copied conversions')
s=fixture({{'ROCK','MIMIC','ROCK'},{'ROCK','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,2,'pushable'))
s=fixture({{'TEXT','MIMIC','ROCK'},{'ROCK','IS','SAFE'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,10,'safe'))
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','IS','NOT','PUSH'},{'ROCK','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(not trait(frame,2,'pushable'))
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','HAS','CRATE'},{'ROCK','IS','YOU','AND','DEFEAT'}})
n=step(s);assert(not n.world.entities[2]);local born=false
for _,e in pairs(n.world.entities) do if e.archetype=='crate' and e.x==6 and e.y==3 then born=true end end
assert(born,'copied HAS participates in frozen contact destruction')
local ast={{verb='mimic',subject={tag='noun',type={tag='object',name='rock'}},object={tag='noun',type={tag='object',name='flag'}},when={op='always'}}}
for i=1,251 do ast[#ast+1]={verb='is',subject={tag='noun',type={tag='object',name='flag'}},object={tag='property',name='pushable'},when={op='always'}} end
local g,err=RW_LowerRuleAST(ast,nil,s.world);assert(not g and err=='rule_complexity_limit')
table.remove(ast);assert(RW_LowerRuleAST(ast,nil,s.world))
print('PASS: MIMIC one generation, per-identity combined/negative conditions, self/duplicate conversions, limit and Undo')
