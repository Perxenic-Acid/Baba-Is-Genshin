-- TELE uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={hold=RW_ResolveHold,tele=RW_ResolveTele,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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
