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





local s=fixture({{'ROCK','BECOME','FLAG'}})
local n=step(s);assert(n.world.entities[2].archetype=='flag' and n.world.entities[2].direction=='Right')
s=fixture({{'ROCK','IS','ROCK'},{'ROCK','BECOME','FLAG'}})
n=step(s);assert(n.world.entities[2].archetype=='flag','IS identity protection must not block BECOME')
s=fixture({{'ROCK','BECOME','ROCK'},{'ROCK','IS','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+1)
local names={};for _,e in pairs(n.world.entities) do if e.class=='object' and e.x==6 and e.y==3 then names[e.archetype]=true end end
assert(names.rock and names.flag,'BECOME self is a product, not protection')
s=fixture({{'ROCK','BECOME','ROCK'},{'ROCK','BECOME','ROCK'}})
n=step(s);assert(n.world.entities[2].archetype=='rock' and n.world.next_entity_id==s.world.next_entity_id+1)
s=fixture({{'ROCK','IS','NOT','FLAG'},{'ROCK','BECOME','FLAG'}})
n=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','BECOME','NOT','FLAG'},{'ROCK','IS','FLAG'}})
n=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','BECOME','FLAG'},{'ROCK','BECOME','NOT','FLAG'}})
n=step(s);assert(n.world.entities[2].archetype=='rock')
s=fixture({{'ROCK','BECOME','NOT','ROCK'},{'ROCK','HAS','FLAG'}})
n=step(s);assert(not n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id)
s=fixture({{'ROCK','IS','NOT','ROCK'},{'ROCK','BECOME','FLAG'}})
n=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','BECOME','TEXT'}})
s.world.entities[2].level_link={target='parent',source_type='rock',label='linked'}
n=step(s);assert(n.world.entities[2].text.name=='ROCK' and n.world.entities[2].level_link.target=='parent')
s=fixture({{'TEXT','BECOME','TEXT'}})
n=step(s);for _,e in pairs(n.world.entities) do if e.class=='text' then assert(e.text.name=='TEXT') end end
s=fixture({{'ROCK','ON','FLAG','BECOME','AVATAR'}})
object(s.world,3,'flag',6,3);object(s.world,4,'rock',9,3)
n=step(s);assert(n.world.entities[2].archetype=='avatar' and n.world.entities[4].archetype=='rock')
-- BECOME self's transient converted status affects subsequent MAKE despite no field change.
s=fixture({{'ROCK','BECOME','ROCK'},{'ROCK','MAKE','ROCK'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+1)
local again=step(n);assert(again.world.next_entity_id==n.world.next_entity_id+2)
s=fixture({{'ROCK','BECOME','EMPTY'}});n=step(s);assert(not n.world.entities[2])
s=fixture({{'EMPTY','BECOME','FLAG'}});s.world.width,s.world.height=8,8
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+59)
s=fixture({{'ROCK','BECOME','ALL'}})
n=step(s);assert(n.world.entities[2].archetype=='rock' and n.world.next_entity_id==s.world.next_entity_id+#RW_NounPalette(s.world)-1)
print('PASS: BECOME vs IS protection/NOT, self multiplicity, TEXT/EMPTY/ALL, conditions, links, MAKE converted tracking, no HAS and Undo')
