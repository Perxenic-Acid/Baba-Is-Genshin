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


local names={'RED','ORANGE','YELLOW','LIME','GREEN','CYAN','BLUE','PURPLE','PINK','ROSY','BLACK','GREY','SILVER','WHITE','BROWN'}
local palette={{2,2},{2,3},{2,4},{5,3},{5,2},{1,4},{3,2},{3,1},{4,1},{4,2},{0,4},{0,1},{0,2},{0,3},{6,1}}
for i,name in ipairs(names) do
 local s=fixture({{'AVATAR','IS',name}});local frame=assert(RW_CompileWorld(s.world,cs));local w=assert(RW_ProjectWorld(s.world,frame.effects))
 local filter=w.entities[1].colour_filters[1];assert(filter.name==name:lower() and filter.palette[1]==palette[i][1] and filter.palette[2]==palette[i][2])
 assert(#w.entities[2].colour_filters==0 and not s.world.entities[1].colour_filters)
end
local s=fixture({{'AVATAR','IS','BLUE','AND','RED','AND','RED'},{'AVATAR','IS','NOT','BLUE'}})
local frame=assert(RW_CompileWorld(s.world,cs));local w=assert(RW_ProjectWorld(s.world,frame.effects));assert(#w.entities[1].colour_filters==1 and w.entities[1].colour_filters[1].name=='red')
local reset=assert(RW_ProjectWorld(w,{}));assert(#reset.entities[1].colour_filters==0,'stale filters must clear')
s=fixture({{'AVATAR','IS','BLUE','AND','RED','AND','RED'}})
frame=assert(RW_CompileWorld(s.world,cs));w=assert(RW_ProjectWorld(s.world,frame.effects))
assert(#w.entities[1].colour_filters==2 and w.entities[1].colour_filters[1].name=='red' and w.entities[1].colour_filters[2].name=='blue')
s=fixture({{'ROCK','IS','RED','AND','MORE'}})
local plan,err=RW_PlanTurn(s.world,{type='wait'},services);assert(plan,err and err.reason)
local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
for _,e in pairs(n.world.entities) do assert(not e.colour_filters,'filter metadata must not persist through MORE') end
assert(RW_Undo(n).world==s.world)
local g,d,relations=RW_LowerRuleAST({{subject={tag='noun',type={tag='level',block_type='level_block'}},verb='is',object={tag='property',name='green'},when={op='always'}}},nil,s.world)
local traits={};for _,v in ipairs(relations) do if v.op=='level_trait' then traits[#traits+1]=v.trait end end
w=assert(RW_ProjectWorld(s.world,assert(RW_EvaluateRules(s.world,g)),traits));assert(w.level_colour_filters[1].name=='green')
print('PASS: fifteen colour filters/palette mapping, distinct stacking, NOT/retraction, scoped LEVEL, MORE isolation and Undo')
