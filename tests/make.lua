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

-- EMPTY sources are snapshot cells, not allocated proxy entities. Duplicate
-- declarations share vacancies and do not see earlier MAKE products as blockers.
local function empty_fixture(rows)
    local s=fixture(rows);s.world.width,s.world.height=8,16;return s
end
local function vacancies(w)
    local occupied={};for _,e in pairs(w.entities) do occupied[e.x..':'..e.y]=true end
    local cells={};for y=1,w.height do for x=1,w.width do
        if not occupied[x..':'..y] then cells[x..':'..y]=true end
    end end;return cells
end
s=empty_fixture({{'EMPTY','MAKE','FLAG'},{'EMPTY','MAKE','FLAG'}})
local cells=vacancies(s.world);local count=0;for _ in pairs(cells) do count=count+1 end
local before_rng=s.world.random_state or 1
n,p=step(s);local seen={};local births=0
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then
    assert(id>0 and e.archetype=='flag' and cells[e.x..':'..e.y] and not e.level_link)
    seen[e.x..':'..e.y]=(seen[e.x..':'..e.y] or 0)+1;births=births+1
end end
assert(births==count*2 and n.world.next_entity_id==s.world.next_entity_id+births)
for key in pairs(cells) do assert(seen[key]==2) end
local restored_empty=RW_Undo(n);local replay=step(restored_empty);assert(replay.world.random_state==n.world.random_state)
assert(s.world.random_state==nil and before_rng==1)
-- Once occupied, those cells stop being EMPTY on the following turn.
local next_turn=step(n);assert(next_turn.world.next_entity_id==n.world.next_entity_id)
s=empty_fixture({{'EMPTY','NEAR','ROCK','MAKE','TEXT'}})
n=step(s);births=0
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then
    assert(e.class=='text' and e.text.name=='EMPTY' and math.abs(e.x-6)<=1 and math.abs(e.y-3)<=1)
    births=births+1
end end
assert(births==8)
s=empty_fixture({{'EMPTY','MAKE','FLAG'},{'EMPTY','NEAR','ROCK','MAKE','NOT','FLAG'}})
cells=vacancies(s.world);n=step(s)
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then
    assert(math.abs(e.x-6)>1 or math.abs(e.y-3)>1)
end end
s=empty_fixture({{'EMPTY','IS','BROKEN'},{'EMPTY','MAKE','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id and n.world.random_state==nil)
s=empty_fixture({{'EMPTY','MAKE','FLAG'},{'FLAG','IS','CRASH'}})
n=step(s);assert(n.world.infinite_loop and RW_Undo(n).world==s.world)
print('PASS: EMPTY MAKE snapshot vacancies/duplicates/TEXT/spatial NOT/BROKEN, allocator/RNG replay, late CRASH and Undo')
s=empty_fixture({{'EMPTY','MAKE','ALL'}})
cells=vacancies(s.world);count=0;for _ in pairs(cells) do count=count+1 end
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id+count*#RW_NounPalette(s.world))
s=empty_fixture({{'EMPTY','MAKE','FLAG'},{'EMPTY','MAKE','NOT','FLAG'}})
n=step(s);assert(n.world.next_entity_id==s.world.next_entity_id and n.world.random_state==nil)
local bad,why=RW_PlanMakeProducts(s.world,{{op='make',source_type='@empty',target_type='flag',when={op='invalid'}}})
assert(not bad and why=='invalid_spatial_condition' and s.world.random_state==nil,tostring(why))

-- EMPTY orientation is queried from the frozen declaration frame, without an ID.
s=empty_fixture({{'EMPTY','NEAR','ROCK','MAKE','FLAG'},{'EMPTY','IS','LEFT'}})
n=step(s);births=0
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then assert(e.direction=='Left');births=births+1 end end
assert(births==8 and n.world.random_state==nil)
s=empty_fixture({{'EMPTY','NEAR','ROCK','MAKE','FLAG'},{'EMPTY','FOLLOW','ROCK'}})
n=step(s)
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then
    local dx,dy=6-e.x,3-e.y
    local expected=math.abs(dx)<=math.abs(dy) and (dy>=0 and 'Down' or 'Up') or (dx>0 and 'Right' or 'Left')
    assert(e.direction==expected)
end end
assert(n.world.random_state==nil)
local function empty_direction(rows,x,y)
    local s=empty_fixture(rows);local frame=assert(RW_CompileWorld(s.world,cs))
    return assert(RW_QueryEmptyDirection(s.world,x or 6,y or 4,frame.rules)),s,frame
end
assert(empty_direction({{'EMPTY','IS','RIGHT'},{'EMPTY','IS','UP'}})=='Up')
assert(empty_direction({{'EMPTY','IS','UP'},{'EMPTY','IS','RIGHT'}})=='Right')
assert(empty_direction({{'EMPTY','FOLLOW','ROCK'},{'EMPTY','IS','LEFT'}})=='Left')
assert(empty_direction({{'EMPTY','IS','LEFT'},{'EMPTY','FOLLOW','ROCK'}})=='Up')
assert(empty_direction({{'EMPTY','FOLLOW','ROCK'},{'EMPTY','FOLLOW','AVATAR'}})=='Up')
assert(empty_direction({{'EMPTY','FOLLOW','ALL'}})=='None')
assert(empty_direction({{'EMPTY','FOLLOW','EMPTY'}})=='None')
assert(empty_direction({{'EMPTY','IS','UP'},{'EMPTY','IS','NOT','UP'}})=='None')
assert(empty_direction({{'EMPTY','FOLLOW','ROCK'},{'EMPTY','FOLLOW','NOT','ROCK'}})=='None')
assert(empty_direction({{'EMPTY','IS','UP'},{'EMPTY','IS','SLEEP'}})=='None')
assert(empty_direction({{'EMPTY','IS','UP'},{'EMPTY','IS','BROKEN'}})=='None')
assert(empty_direction({{'EMPTY','FACING','ROCK','IS','UP'}})=='None')
assert(empty_direction({{'EMPTY','SEEING','ROCK','IS','UP'}})=='None')
assert(empty_direction({{'EMPTY','NOT','FACING','ROCK','IS','UP'}})=='Up')
assert(empty_direction({{'EMPTY','NEAR','ROCK','IS','LEFT'}},1,1)=='None')
assert(empty_direction({{'EMPTY','NEAR','ROCK','IS','LEFT'}})=='Left')
print('PASS: EMPTY MAKE ordered directions/FOLLOW/NOT, per-cell conditions, SLEEP/BROKEN, positive FACING/SEEING autofail, RNG-free facing and Undo')

-- Directional EMPTY observers use the same declaration frame as their consumers.
s=empty_fixture({{'EMPTY','IS','UP'},{'EMPTY','FACING','ROCK','MAKE','FLAG'}})
n=step(s);births=0
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then
    assert(e.archetype=='flag' and e.x==6 and e.y==4 and e.direction=='Up');births=births+1
end end
assert(births==1 and n.world.random_state==nil)
s=empty_fixture({{'EMPTY','IS','UP'},{'EMPTY','SEEING','ROCK','MAKE','FLAG'}})
n=step(s);births=0
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then assert(e.x==6 and e.y>3 and e.direction=='Up');births=births+1 end end
assert(births==13)
s=empty_fixture({{'EMPTY','IS','UP'},{'EMPTY','SEEING','ROCK','MAKE','FLAG'},{'FLAG','IS','STOP'}})
object(s.world,3,'flag',6,5)
n=step(s);births=0
for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id then assert(e.x==6 and e.y==4);births=births+1 end end
assert(births==1)
local function empty_control(rows,populate)
    local s=empty_fixture(rows);if populate then populate(s.world) end
    local frame=assert(RW_CompileWorld(s.world,cs));local projected=assert(RW_ProjectWorld(s.world,frame.effects))
    assert(not s.world._condition_guard and not s.world._condition_rules)
    return projected.entities[1].behaviors.control==true
end
assert(empty_control({{'EMPTY','IS','RIGHT'},{'AVATAR','FACEDBY','EMPTY','IS','YOU'}}))
assert(not empty_control({{'AVATAR','FACEDBY','EMPTY','IS','YOU'}}))
assert(not empty_control({{'EMPTY','FOLLOW','AVATAR'},{'AVATAR','FACEDBY','NOT','EMPTY','IS','YOU'}}))
assert(empty_control({{'EMPTY','FOLLOW','AVATAR'},{'AVATAR','FACEDBY','NOT','EMPTY','IS','YOU'}},function(w) object(w,3,'rock',1,2) end))
assert(not empty_control({{'EMPTY','IS','RIGHT'},{'AVATAR','FACEDBY','EMPTY','IS','YOU'}},function(w)
    object(w,3,'rock',1,2);object(w,4,'rock',2,1);object(w,5,'rock',3,2);object(w,6,'rock',2,3)
end))
-- Recursion is query-local: repeated calls neither leak guards nor save direction.
local direction,es,ef=empty_direction({{'EMPTY','NOT','FACING','ROCK','IS','UP'}})
for i=1,4 do assert(RW_QueryEmptyDirection(es.world,6,4,ef.rules)==direction) end
assert(not es.world._condition_guard and not es.world._condition_rules)
print('PASS: queried EMPTY FACING/SEEING/FACEDBY, current-frame direction/FOLLOW, occlusion, occupied observers, recursion isolation and transactional MAKE Undo')
local guard_world={width=3,height=3,entities={},rule_sources={{when={op='invalid'},effects={{op='grant_trait',trait='left',target={kind='empty',value='empty'}}}}},_condition_guard={}}
local failed,reason=RW_QueryEmptyDirection(guard_world,2,2)
assert(not failed and reason=='invalid_spatial_condition' and next(guard_world._condition_guard)==nil)
guard_world.rule_sources[1].when={op='always'}
assert(RW_QueryEmptyDirection(guard_world,2,2)=='Left' and next(guard_world._condition_guard)==nil)
guard_world._condition_depth=80
failed,reason=RW_QueryEmptyDirection(guard_world,2,2)
assert(not failed and reason=='word_rule_limit' and next(guard_world._condition_guard)==nil)

-- Source creation order controls allocation and the assignment of pure RNG draws.
do
    local s=fixture({{'ROCK','MAKE','FLAG'},{'ROCK','MAKE','FLAG'}})
    object(s.world,3,'rock',9,3,'None');s.world.entities[2].direction='None'
    local order={3,2,1};local rest={}
    for id in pairs(s.world.entities) do if id>3 then rest[#rest+1]=id end end
    table.sort(rest);for _,id in ipairs(rest) do order[#order+1]=id end
    s.world.unit_order=order;s.world.random_state=17
    local first=s.world.next_entity_id
    local n=step(s)
    local state=17;local directions={'Right','Up','Left','Down'}
    for i,source_id in ipairs({3,2,3,2}) do
        state=(state*48271)%2147483647
        local product=n.world.entities[first+i-1]
        assert(product and product.archetype=='flag' and product.x==s.world.entities[source_id].x
            and product.direction==directions[state%4+1],'scheduled MAKE must allocate and draw in unit-list order')
    end
    assert(n.world.random_state==state and s.world.random_state==17)
    assert(RW_Undo(n).world==s.world,'MAKE order and RNG must restore with Undo')
end
print('PASS: scheduled MAKE unit order, duplicate allocation, per-source RNG and Undo')

do
    for _,reverse in ipairs({false,true}) do
        local s=empty_fixture({{'EMPTY','FOLLOW','ROCK'},{'EMPTY','MAKE','FLAG'}})
        object(s.world,3,'rock',2,3)
        local order=reverse and {3,2,1} or {1,2,3};local rest={}
        for id in pairs(s.world.entities) do if id>3 then rest[#rest+1]=id end end
        table.sort(rest);for _,id in ipairs(rest) do order[#order+1]=id end
        s.world.unit_order=order
        local frame=assert(RW_CompileWorld(s.world,cs))
        local expected=reverse and 'Right' or 'Left'
        assert(RW_QueryEmptyDirection(s.world,4,3,frame.rules)==expected,'EMPTY FOLLOW equal-distance last unit-list witness')
        local n=step(s);local found=false
        for id,e in pairs(n.world.entities) do if id>=s.world.next_entity_id and e.x==4 and e.y==3 then
            assert(e.archetype=='flag' and e.direction==expected);found=true
        end end
        assert(found and n.world.random_state==nil and RW_Undo(n).world==s.world)
    end
end
print('PASS: EMPTY FOLLOW unit-list ties feed scheduled MAKE facing without RNG, with Undo')
