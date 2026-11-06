-- TELE uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={hold=function(w,r) return RW_ResolveHold(w,r,RW_QueryHoldLocked) end,tele=RW_ResolveTele,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.entities={
        [1]={id=1,kind='object',class='object',archetype='avatar',x=2,y=2,direction='Left'},
        [2]={id=2,kind='object',class='object',archetype='rock',x=3,y=2,direction='Down'},
        [3]={id=3,kind='object',class='object',archetype='rock',x=7,y=2,direction='None'}}
    w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
    w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',
        target={kind='archetype',value='avatar'},trait='you'}}}
    w.next_entity_id=10
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=4+row*2,direction='None'}
    end end
    return s
end


local s=fixture({{'ROCK','IS','HOLD'}});s.world.entities[1].x=3;s.world.entities[3]=nil
local function step(session,action)
 local plan,err=RW_PlanTurn(session.world,action or {type='wait'},services);assert(plan,err and err.reason)
 local n,r=RW_Commit(session,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==session.world);return n
end
local n=step(s);assert(n.world.entities[1].holder==2)
local plan={consumes_turn=true,changes={{kind='move',entity_id=2,from={x=3,y=2,direction='Down'},to={x=7,y=2,direction='Down'}}}}
local moved,report=RW_Commit(n,plan);assert(report.accepted)
local carried=step(moved);assert(carried.world.entities[1].x==7 and carried.world.entities[1].direction=='Left' and carried.world.entities[1].holder==2)
local deletion=assert(RW_PlanDelete(carried.world,{2}));local removed,r=RW_Commit(carried,deletion);assert(r.accepted)
local released=step(removed);assert(released.world.entities[1].holder==0)
local stale=RW_PreviewPlan(n.world,{consumes_turn=true,changes={{kind='holder',entity_id=1,from=99,to=0}}});assert(not stale)
assert(s.world.entities[1].holder==nil)
print('PASS: HOLD acquisition, persistent following, facing, holder deletion/release, stale metadata and Undo')

-- Scoped HOLD freezes only real units on the map FLOAT layer.
for _,map_float in ipairs({false,true}) do for _,unit_float in ipairs({false,true}) do
 local sample=fixture({});sample.world.language.nouns.LEVEL={tag='level',block_type='level_block'}
 local ast={{subject={tag='noun',type={tag='level',block_type='level_block'}},verb='is',object={tag='property',name='hold'},when={op='always'}}}
 if map_float then ast[#ast+1]={subject=ast[1].subject,verb='is',object={tag='property',name='float'},when={op='always'}} end
 local g,d,relations=RW_LowerRuleAST(ast,nil,sample.world);assert(#d==0)
 local effects=assert(RW_EvaluateRules(sample.world,g));local traits={};for _,r in ipairs(relations) do if r.op=='level_trait' then traits[#traits+1]=r.trait end end
 local projected=assert(RW_ProjectWorld(sample.world,effects,traits))
 for _,e in pairs(projected.entities) do e.behaviors={} end
 projected.entities[1].behaviors={control=true,float=unit_float};projected.entities[1].x=1
 local motion=assert(RW_ResolveTurn(projected,{type='move',dx=1,dy=0}))
 local moved=false;for _,c in ipairs(motion.changes) do if c.entity_id==1 and c.kind=='move' then moved=true end end
 assert(moved==(map_float~=unit_float),'LEVEL HOLD must use map FLOAT layer')
end end
print('PASS: scoped LEVEL HOLD real-unit movement and FLOAT separation')

for _,frozen in ipairs({false,true}) do
 local sample=fixture({});sample.world.entities[3]=nil
 local w=assert(RW_ProjectWorld(sample.world,{}));w.level_behaviors={hold=frozen}
 w.entities[1].x,w.entities[1].y=2,2;w.entities[2].x,w.entities[2].y=3,2
 w.entities[1].behaviors={control=true,float=true};w.entities[2].behaviors={push=true}
 local push=assert(RW_ResolveTurn(w,{type='move',dx=1,dy=0}));local moved=false
 for _,c in ipairs(push.changes) do if c.kind=='move' and c.entity_id==2 then moved=true end end
 assert(moved~=frozen,'scoped HOLD passive PUSH')
 w.entities[1].x=3;w.entities[2].x=2;w.entities[2].behaviors={pull=true}
 local pull=assert(RW_ResolveTurn(w,{type='move',dx=1,dy=0}));local pulled=false
 for _,c in ipairs(pull.changes) do if c.kind=='move' and c.entity_id==2 then pulled=true end end
 assert(pulled~=frozen,'scoped HOLD passive PULL')
 w.entities[2].x=3
 w.entities[2].behaviors={fall=true}
 local fall=assert(RW_ResolveFall(w));local moved=false
 for _,c in ipairs(fall.changes) do if c.kind=='move' and c.entity_id==2 then moved=true end end
 assert(moved~=frozen,'scoped HOLD FALL')
 w.entities[1].x=3;w.entities[1].behaviors={shift=true};w.entities[1].direction='Right';w.entities[2].behaviors={}
 local shift=assert(RW_ResolveShift(w));local moved=false
 for _,c in ipairs(shift.changes) do if c.kind=='move' and c.entity_id==2 then moved=true end end
 assert(moved~=frozen,'scoped HOLD SHIFT rider')
end
print('PASS: scoped LEVEL HOLD blocks passive PUSH, FALL and SHIFT without disabling other layers')
local function chain(rows,reverse)
 local s=fixture(rows);local w=s.world
 w.entities[1].x=3;w.entities[1].holder=2;w.entities[2].x=7;w.entities[3].x=11
 w.entities[4]={id=4,kind='object',class='object',archetype='flag',x=3,y=2,direction='Up',holder=3}
 w.unit_order=reverse and {4,1,2,3} or {1,4,2,3};for id=10,w.next_entity_id-1 do table.insert(w.unit_order,id) end
 return s
end
for _,trait in ipairs({'STILL','LOCKEDRIGHT','LOCKEDLEFT'}) do for reverse=0,1 do for count=0,2 do
 local rows={{'ROCK','IS','HOLD'},{'FLAG','ON','AVATAR','IS',trait}}
 for i=1,count do rows[#rows+1]={'FLAG','IS','REVERSE'} end
 local s=chain(rows,reverse==1);local n=step(s,{type='wait'})
 local locked=trait=='STILL' or (trait=='LOCKEDRIGHT' and count%2==0) or (trait=='LOCKEDLEFT' and count%2==1)
 local expected=reverse==1 and locked and 3 or 11
 assert(n.world.entities[1].x==7 and n.world.entities[4].x==expected,'HOLD live lock '..trait..' '..reverse..' '..count)
 assert((n.world.entities[4].holder or 0)==(expected==3 and 0 or 3) and n.world.entities[4].direction=='Up')
end end end
for _,reason in ipairs({'word_rule_limit','word_rule_cycle','rule_complexity_limit','injected'}) do
 local s=chain({{'ROCK','IS','HOLD'}},false);local svc={};for k,v in pairs(services) do svc[k]=v end
 svc.hold=function(w,r) return RW_ResolveHold(w,r,function(context,e,dx,dy,rules)
  if e.id==4 then return nil,reason end
  return RW_QueryHoldLocked(context,e,dx,dy,rules)
 end)end
 svc.contact=function()error('HOLD limit must stop contact phases')end
 local p,e=RW_PlanTurn(s.world,{type='wait'},svc)
 if reason=='injected' then assert(not p and e.reason==reason)
 else
  assert(p and (p.infinite_loop or p.too_complex));local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
  assert(n.world.entities[1].x==7 and n.world.entities[4].x==3 and n.world.entities[4].holder==3)
  assert(RW_Undo(n).world==s.world)
 end
end
print('PASS: HOLD live STILL/directional locks, weighted REVERSE, release/facing, terminal prefixes, rejection and Undo')
-- LEVEL HOLD uses the real unit's frozen layer and the declaration map layer.
for hold=0,1 do for mapfloat=0,1 do for unitfloat=0,1 do
 local rows={{'ROCK','IS','HOLD'}}
 if hold==1 then rows[#rows+1]={'LEVEL','IS','HOLD'} end
 if mapfloat==1 then rows[#rows+1]={'LEVEL','IS','FLOAT'} end
 if unitfloat==1 then rows[#rows+1]={'AVATAR','IS','FLOAT'} end
 local s=chain(rows,false);s.world.language.nouns.LEVEL={tag='level',block_type='level_block'};local n=step(s,{type='wait'})
 assert(n.world.entities[1].x==((hold==1 and mapfloat==unitfloat) and 3 or 7),'dynamic HOLD map layer '..hold..' '..mapfloat..' '..unitfloat..' actual '..n.world.entities[1].x)
end end end
print('PASS: HOLD raw LEVEL HOLD/FLOAT versus frozen rider layer')
-- An earlier held arrival appends behind existing witnesses in the query map.
s=chain({{'ROCK','IS','HOLD'},{'ROCK','IS','HIDE'},{'FLAG','SEEING','NOT','ROCK','AND','NOT','AVATAR','IS','STILL'},{'WATER','IS','STILL'}},false)
s.world.language.nouns.WATER='water';s.world.entities[4].direction='Right'
s.world.entities[5]={id=5,kind='object',class='object',archetype='water',x=7,y=2,direction='Left'}
table.insert(s.world.unit_order,5,5)
n=step(s,{type='wait'});assert(n.world.entities[1].x==7 and n.world.entities[4].x==11,'HOLD query must see Water before newly arrived Avatar')
print('PASS: HOLD live SEEING witnesses preserve destination arrival order')
