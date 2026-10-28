-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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
local function only(rows)
 local s=fixture(rows);s.world.entities[3]=nil;return s
end
local s=only({{'ROCK','IS','MORE'}});local f=s.world.next_entity_id;local n,p=step(s)
assert(n.world.next_entity_id==f+4)
local expected={{4,2},{3,1},{2,2},{3,3}}
for i,pos in ipairs(expected) do local e=n.world.entities[f+i-1]
 assert(e.archetype=='rock' and e.x==pos[1] and e.y==pos[2] and e.direction=='Down')
end
local phases={};for i,v in ipairs(p.stages) do phases[v.name]=i end
assert(phases.conversion<phases.more and phases.more<phases.sink)
-- Borders and real STOP/PUSH block growth across FLOAT layers.
s=only({{'ROCK','IS','MORE','AND','FLOAT'},{'CRATE','IS','STOP'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='crate',x=4,y=2,direction='None'}
f=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==f+3)
s=only({{'ROCK','IS','MORE'}});s.world.entities[2].x=1;s.world.entities[2].y=1
f=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==f+2)
-- Same-noun newborns block later sources, but never grow recursively this turn.
s=fixture({{'ROCK','IS','MORE'}});s.world.entities[3].x=5
f=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==f+7)
local center=0;for _,e in pairs(n.world.entities) do if e.archetype=='rock' and e.x==4 and e.y==2 then center=center+1 end end
assert(center==1)
-- Conditional and negated MORE; declarations do not multiply a single source.
s=only({{'ROCK','ON','AVATAR','IS','MORE'}});f=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==f+4)
s=only({{'ROCK','IS','MORE'},{'ROCK','IS','NOT','MORE'}});f=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==f)
s=only({{'ROCK','IS','MORE'},{'ROCK','IS','MORE'}});f=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==f+4)
-- Empty STOP is a blocker; inert occupants can be overlapped.
s=only({{'ROCK','IS','MORE'},{'EMPTY','IS','STOP'}});f=s.world.next_entity_id;n=step(s)
assert(n.world.next_entity_id==f)
s=only({{'ROCK','IS','MORE'}})
s.world.entities[2].level_link={target='child',definition_id='fixture',source_type='rock'}
s.world.entities[4]={id=4,kind='object',class='object',archetype='flag',x=4,y=2,direction='None'}
f=s.world.next_entity_id;n=step(s)
assert(n.world.entities[f].x==4 and n.world.entities[f].level_link.definition_id=='fixture')
-- MORE copies retain Text identity, facing and their explicit token.
s=only({})
s.world.entities[4]={id=4,kind='object',class='text',text={name='ROCK'},x=6,y=3,direction='Up'}
s.world.rule_sources[#s.world.rule_sources+1]={when={op='always'},effects={{op='grant_trait',target={kind='id',value=4},trait='more'}}}
f=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==f+4 and n.world.entities[f].text.name=='ROCK' and n.world.entities[f].direction=='Up')
-- New MORE copies have WEAK grace while the original remains vulnerable.
s=only({{'ROCK','IS','MORE','AND','WEAK'}})
s.world.entities[4]={id=4,kind='object',class='object',archetype='flag',x=4,y=2,direction='None'}
f=s.world.next_entity_id;n=step(s)
assert(not n.world.entities[2] and n.world.entities[f] and n.world.entities[f].x==4)
-- Late errors leave the allocator and original board untouched.
s=only({{'ROCK','IS','MORE'}});local bad={};for k,v in pairs(services) do bad[k]=v end
bad.contact=function() return nil,'injected' end;f=s.world.next_entity_id
local failed,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},bad)
assert(not failed and s.world.next_entity_id==f and #s.history==0)
s=only({{'ROCK','WRITE','MORE'}});n=step(s);assert(n.world.entities[2].text.name=='MORE')
print('PASS: MORE four-way growth, borders/STOP/PUSH/EMPTY, same-noun deduplication, Text/metadata/facing, conditions/NOT, newborn grace and Undo')
