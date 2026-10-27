-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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
local function step(s)
    local plan,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
    local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world)
    assert(#n.history==#s.history+1);return n,plan
end
local function belt(s,id,x,y,direction)
 s.world.entities[id]={id=id,kind='object',class='object',archetype='rock',x=x,y=y,direction=direction}
end
local s=fixture({{'ROCK','IS','SHIFT'}});belt(s,2,3,2,'Up')
local n,p=step(s);assert(n.world.entities[1].x==3 and n.world.entities[1].y==1 and n.world.entities[1].direction=='Up')
assert(n.world.entities[2].x==3 and n.world.entities[2].y==2)
local phase={};for i,v in ipairs(p.stages) do phase[v.name]=i end
assert(phase.movement<phase.shift and phase.shift<phase.conversion)
-- The belt never shifts itself. A rider moved off it by YOU is no longer collected.
s=fixture({{'ROCK','IS','SHIFT'}});belt(s,2,2,2,'Up');n=step(s)
assert(n.world.entities[1].x==3 and n.world.entities[1].y==2 and n.world.entities[2].x==2)
-- Non-YOU Text and objects are riders; FLOAT isolates them.
s=fixture({{'ROCK','IS','SHIFT'}});belt(s,2,5,2,'Right')
s.world.entities[4]={id=4,kind='object',class='text',text={name='NOT'},x=5,y=2,direction='Left'}
n=step(s);assert(n.world.entities[4].x==6 and n.world.entities[4].direction=='Right')
s=fixture({{'ROCK','IS','SHIFT','AND','FLOAT'}});belt(s,2,3,2,'Up');n=step(s)
assert(n.world.entities[1].x==3 and n.world.entities[1].y==2)
-- SHIFT pushes normally, STOP blocks, and blocked riders still turn.
s=fixture({{'ROCK','IS','SHIFT'},{'CRATE','IS','PUSH'}});belt(s,2,3,2,'Right')
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=4,y=2,direction='None'}
n=step(s);assert(n.world.entities[1].x==4 and n.world.entities[4].x==5)
s=fixture({{'ROCK','IS','SHIFT'},{'CRATE','IS','STOP'}});belt(s,2,3,2,'Up')
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=3,y=1,direction='None'}
n=step(s);assert(n.world.entities[1].x==3 and n.world.entities[1].y==2 and n.world.entities[1].direction=='Up')
-- Two sources add two impulses using the first source direction, without recollecting.
s=fixture({{'ROCK','IS','SHIFT'}});belt(s,2,3,2,'Right');belt(s,3,3,2,'Up')
n=step(s);assert(n.world.entities[1].x==5 and n.world.entities[1].y==2)
-- Entering another belt aligns facing at the end, with no extra displacement.
s=fixture({{'ROCK','IS','SHIFT'}});belt(s,2,3,2,'Right');belt(s,3,4,2,'Down')
n=step(s);assert(n.world.entities[1].x==4 and n.world.entities[1].y==2 and n.world.entities[1].direction=='Down')
-- Duplicate rules do not multiply one source's SHIFT property.
s=fixture({{'ROCK','IS','SHIFT'},{'ROCK','IS','SHIFT'}});belt(s,2,3,2,'Right');n=step(s)
assert(n.world.entities[1].x==4)
-- Shift collision destruction/HAS uses the rider source and participates in one Undo.
s=fixture({{'ROCK','IS','SHIFT'},{'AVATAR','IS','WEAK'},{'AVATAR','HAS','CRATE'}});belt(s,2,3,2,'Up')
local f=s.world.next_entity_id
n=step(s);assert(n.world.entities[1] and n.world.entities[1].y==1) -- free movement does not shatter
s.world.entities[4]={id=4,kind='object',class='object',archetype='flag',x=3,y=1,direction='None'}
s.world.rule_sources[#s.world.rule_sources+1]={when={op='always'},effects={{op='grant_trait',target={kind='archetype',value='flag'},trait='block_entry'}}}
n=step(s);assert(not n.world.entities[1] and n.world.entities[f].x==3 and n.world.entities[f].y==2 and n.world.entities[f].direction=='Up')
-- Wait advances SHIFT without moving YOU or SELECT, and can be undone.
s=fixture({{'ROCK','IS','SHIFT'}});belt(s,2,2,2,'Right')
local plan,e=RW_PlanTurn(s.world,{type='wait'},services);assert(plan,e and e.reason)
local waited,r=RW_Commit(s,plan);assert(r.accepted and waited.world.entities[1].x==3)
assert(RW_Undo(waited).world==s.world)
-- Conditions and NOT grants apply before collection.
s=fixture({{'ROCK','ON','AVATAR','IS','SHIFT'}});belt(s,2,3,2,'Up');n=step(s)
assert(n.world.entities[1].y==1)
s=fixture({{'ROCK','IS','SHIFT'},{'ROCK','IS','NOT','SHIFT'}});belt(s,2,3,2,'Up');n=step(s)
assert(n.world.entities[1].y==2)
-- Late failure cannot leak shift movement or HAS allocation.
s=fixture({{'ROCK','IS','SHIFT'}});belt(s,2,3,2,'Right')
local bad={};for k,v in pairs(services) do bad[k]=v end;bad.convert=function() return nil,'injected' end
local failed,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},bad)
assert(not failed and s.world.entities[1].x==2 and #s.history==0)
s=fixture({{'ROCK','WRITE','SHIFT'}});n=step(s);assert(n.world.entities[2].text.name=='SHIFT')
print('PASS: SHIFT direction/collection/stacking, PUSH/STOP, FLOAT, Text, WEAK/HAS, wait, conditions, NOT and Undo')

-- OPEN/SHUT destruction occurs during SHIFT, before conversion and with HAS.
s=fixture({{'ROCK','IS','SHIFT'},{'AVATAR','IS','OPEN'},{'CRATE','IS','SHUT','AND','STOP'},{'AVATAR','HAS','FLAG'}})
belt(s,2,3,2,'Up')
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=3,y=1,direction='None'}
f=s.world.next_entity_id;n,p=step(s)
assert(not n.world.entities[1] and not n.world.entities[4] and n.world.entities[f].archetype=='flag')
assert(n.world.entities[f].x==3 and n.world.entities[f].y==2 and n.world.entities[f].direction=='Up')
local deathstage
for _,stage in ipairs(p.stages) do if stage.name=='shift_destruction' then deathstage=stage.plan end end
assert(deathstage and deathstage.events[1].cause=='unlock')
-- Shift does not escape either undo-only terminal state through wait input.
for _,terminal in ipairs({'infinite_loop','too_complex'}) do
 s=fixture({{'ROCK','IS','SHIFT'}});s.world[terminal]=true
 local denied,e=RW_PlanTurn(s.world,{type='wait'},services)
 assert(not denied and e.stage=='input')
end
print('PASS: SHIFT OPEN/SHUT source-position HAS, cause diagnostics and terminal wait lockout')
