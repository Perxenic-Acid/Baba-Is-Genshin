-- FOLLOW uses production parsing, scheduling, metadata Commit and whole-turn Undo.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={make=function(w,r,c)
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



local s=fixture({{'ROCK','MAKE','FLAG'}})
local n=step(s);local id=s.world.next_entity_id
assert(n.world.entities[2].archetype=='rock' and n.world.entities[id].archetype=='flag')
assert(n.world.entities[id].x==6 and n.world.entities[id].y==3 and n.world.entities[id].direction=='Right')
local again=step(n);assert(again.world.next_entity_id==n.world.next_entity_id,'old matching occupant prevents MAKE')
s=fixture({{'ROCK','MAKE','FLAG'},{'ROCK','MAKE','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+2,'same-phase products do not block duplicate MAKE')
s=fixture({{'ROCK','MAKE','ROCK'}});n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id)
s=fixture({{'ROCK','MAKE','TEXT'}});n=step(s)
assert(n.world.entities[s.world.next_entity_id].text.name=='ROCK')
s=fixture({{'ROCK','MAKE','TEXT'}})
s.world.entities[3]={id=3,kind='object',class='text',text={name='NOT'},x=6,y=3,direction='None'}
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id,'any old Text blocks MAKE TEXT')
s=fixture({{'TEXT','MAKE','TEXT'}});n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id)
s=fixture({{'ROCK','MAKE','FLAG'},{'ROCK','MAKE','NOT','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id)
s=fixture({{'ROCK','ON','AVATAR','MAKE','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id)
s.world.entities[1].x,s.world.entities[1].y=6,3;n=step(s)
assert(n.world.next_entity_id==s.world.next_entity_id+1)
-- MAKE occurs after destruction: destroyed producers do not create.
s=fixture({{'ROCK','MAKE','FLAG'},{'ROCK','IS','SINK'}})
object(s.world,3,'avatar',6,3);n=step(s)
assert(not n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id)
-- Newborns get no earlier contact/MAKE pass in the same turn.
s=fixture({{'ROCK','MAKE','FLAG'},{'FLAG','IS','SINK'},{'FLAG','MAKE','AVATAR'}})
n=step(s);assert(n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id+1)
again=step(n);assert(not again.world.entities[2] and not again.world.entities[s.world.next_entity_id])
-- A converted matching object is ignored by the same-cell blocker check.
s=fixture({{'ROCK','MAKE','FLAG'},{'AVATAR','IS','FLAG'}})
s.world.entities[1].x,s.world.entities[1].y=6,3
n=step(s);assert(n.world.entities[1].archetype=='flag' and n.world.next_entity_id==s.world.next_entity_id+1)
-- Identity links are carried to every product, including Text.
s=fixture({{'ROCK','MAKE','TEXT'}})
s.world.entities[2].level_link={target='parent',source_type='rock',label='Linked'}
n=step(s);assert(n.world.entities[s.world.next_entity_id].level_link.target=='parent')
-- Direction randomness is private plan state; planning twice and Undo/replay agree.
s=fixture({{'ROCK','MAKE','FLAG'}});s.world.entities[2].direction='None'
local p=assert(RW_PlanTurn(s.world,{type='wait'},services))
local q=assert(RW_PlanTurn(s.world,{type='wait'},services))
assert(s.world.random_state==nil)
n=step(s);local restored=RW_Undo(n);local replay=step(restored)
assert(n.world.random_state==replay.world.random_state and n.world.random_state~=nil)
assert(n.world.entities[s.world.next_entity_id].direction==replay.world.entities[s.world.next_entity_id].direction)
local rngp,rngq
for _,stage in ipairs(p.stages) do if stage.name=='make' then rngp=stage.plan.random_state end end
for _,stage in ipairs(q.stages) do if stage.name=='make' then rngq=stage.plan.random_state end end
assert(rngp.to==rngq.to)
local _,r=RW_Commit(n,{consumes_turn=true,changes={},random_state={from=1,to=2}})
assert(not r.accepted and r.reason=='stale_random_state')
local _,r=RW_Commit(s,{consumes_turn=true,changes={},random_state={from=1,to=0}})
assert(not r.accepted and r.reason=='invalid_random_state')
-- Even blocked producers consume their original random direction draw.
s=fixture({{'ROCK','MAKE','ROCK'}});s.world.entities[2].direction='None'
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id and n.world.random_state~=nil)

-- RHS ALL expands ordinary authored vocabulary; ALL MAKE ALL keeps both axes.
s=fixture({{'ROCK','MAKE','ALL'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+#RW_NounPalette(s.world)-1)
s=fixture({{'ALL','MAKE','ALL'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+4*(#RW_NounPalette(s.world)-1))
-- MAKE products do not run an earlier WEAK pass in their birth turn.
s=fixture({{'ROCK','MAKE','FLAG'},{'FLAG','IS','WEAK'},{'FLAG','HAS','AVATAR'}})
n=step(s);id=s.world.next_entity_id
assert(n.world.entities[id] and n.world.entities[2])
again=step(n);assert(not again.world.entities[id] and again.world.entities[again.world.next_entity_id-1].archetype=='flag')
-- Surviving MAKE products still trigger CRASH in the late frozen frame.
s=fixture({{'ROCK','MAKE','FLAG'},{'FLAG','IS','CRASH'}})
n=step(s);assert(n.world.infinite_loop and n.world.entities[s.world.next_entity_id].archetype=='flag')
local blocked,why=RW_PlanTurn(n.world,{type='wait'},services)
assert(not blocked and why.reason=='infinite_loop_undo_only' and RW_Undo(n).world==s.world)
-- Failure of a later stage cannot leak either allocated products or random state.
s=fixture({{'ROCK','MAKE','FLAG'}});s.world.entities[2].direction='None'
p=assert(RW_PlanTurn(s.world,{type='wait'},services))
p.stages[#p.stages+1]={name='late_failure',plan={consumes_turn=true,changes={{kind='delete',entity_id=999,from={}}}}}
p.changes[#p.changes+1]=p.stages[#p.stages].plan.changes[1]
local same,r=RW_Commit(s,p)
assert(not r.accepted and same==s and s.world.random_state==nil and not s.world.entities[s.world.next_entity_id])
-- World random state has an authored schema and cannot bypass no-turn rules.
local definition=RW_GetDefaultLevelDefinition();definition.initial_world.random_state=0
assert(not RW_InstantiateLevel(definition,'invalid-rng'))
local _,r=RW_Commit(s,{consumes_turn=false,changes={},random_state={from=1,to=2}})
assert(not r.accepted and r.reason=='invalid_no_turn_plan')
print('PASS: MAKE duplicates/old blockers/conversions/TEXT/ALL/links, conditions/NOT, late contacts/CRASH, random-state Undo/replay and atomic failure')
