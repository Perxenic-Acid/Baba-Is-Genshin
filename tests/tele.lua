-- TELE uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={tele=RW_ResolveTele,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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

local function step(s,action)
 local plan,e=RW_PlanTurn(s.world,action or {type='wait'},services);assert(plan,e and e.reason)
 local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world)
 assert(#n.history==#s.history+1);return n,plan
end
local function overlap(s) s.world.entities[1].x=3;return s end
local s=overlap(fixture({{'ROCK','IS','TELE','AND','STOP','AND','PUSH'}}))
local n,p=step(s);assert(n.world.entities[1].x==7 and n.world.entities[1].direction=='Left')
assert(s.world.random_state==nil and n.world.random_state and n.world.entities[2].x==3)
local phases={};for i,stage in ipairs(p.stages) do phases[stage.name]=i end
assert(phases.conversion<phases.more and phases.more<phases.tele and phases.tele<phases.sink)
local replay=step(s);assert(replay.world.entities[1].x==n.world.entities[1].x and replay.world.random_state==n.world.random_state)
for _,extra in ipairs({'STILL','FLOAT'}) do
 s=overlap(fixture({{'ROCK','IS','TELE'},{'AVATAR','IS',extra}}));n=step(s)
 assert(n.world.entities[1].x==3 and n.world.random_state==nil)
end
s=overlap(fixture({{'ROCK','IS','TELE'},{'AVATAR','IS','SLEEP'}}));n=step(s);assert(n.world.entities[1].x==7)
s=overlap(fixture({{'ROCK','IS','TELE'},{'ROCK','IS','NOT','TELE'}}));n=step(s);assert(n.world.entities[1].x==3)
s=overlap(fixture({{'ROCK','IS','TELE'},{'AVATAR','HAS','FLAG'}}))
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=7,y=2,direction='None'}
s.world.rule_sources[#s.world.rule_sources+1]={when={op='always'},effects={{op='grant_trait',target={kind='archetype',value='crate'},trait='defeat'},{op='grant_trait',target={kind='archetype',value='crate'},trait='still'}}}
n=step(s);assert(not n.world.entities[1]);local flag=false;for _,e in pairs(n.world.entities) do if e.archetype=='flag' and e.x==7 and e.y==2 then flag=true end end;assert(flag,'arrival DEFEAT/HAS uses teleported position')
s=overlap(fixture({{'ROCK','IS','TELE'},{'AVATAR','IS','TELE'}}));n=step(s);assert(n.world.entities[1].x==7,'a rider with TELE can use a differently named network')
s=overlap(fixture({{'ROCK','IS','TELE'}}));s.world.entities[3]=nil;n=step(s);assert(n.world.random_state==nil and n.world.entities[1].x==3)
-- A teleported Text completes an inverse GROUP cycle; commit the arrival then lock.
s=fixture({});s.world.width,s.world.height=24,24;s.world.entities[1].x=2
s.world.entities[2].x,s.world.entities[2].y=4,9;s.world.entities[3].x,s.world.entities[3].y=4,8
local function text(token,x,y)
 local id=s.world.next_entity_id;s.world.next_entity_id=id+1
 s.world.entities[id]={id=id,kind='object',class='text',text={name=token},x=x,y=y,direction='None'};return id
end
for row,words in ipairs({{'NOT','GROUP2','IS','GROUP'},{'NOT','GROUP','IS'}}) do for x,token in ipairs(words) do text(token,x,6+row) end end
for x,token in ipairs({'ROCK','IS','TELE'}) do text(token,x,16) end
local word=text('GROUP2',4,9)
n,p=step(s);assert(n.world.infinite_loop and n.world.entities[word].y==8,'TELE-triggered loop must retain the completed sentence')
local blocked,why=RW_PlanTurn(n.world,{type='wait'},services);assert(not blocked and why.reason=='infinite_loop_undo_only')
assert(RW_Undo(n).world.entities[word].y==9 and not s.world.random_state)
print('PASS: TELE stage ordering, collision bypass, direction, STILL/FLOAT/SLEEP, denial, arrival DEFEAT/HAS, replay/RNG/Undo and triggering Infinite Loop')
