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

for count=1,3 do for _,safe in ipairs({false,true}) do
 local words={'ROCK','IS','BOOM'};for i=2,count do words[#words+1]='AND';words[#words+1]='BOOM' end
 local s=fixture({words,{'AVATAR','HAS','FLAG'}})
 s.world.entities[1].x,s.world.entities[1].y=3+count-1,2
 s.world.entities[3]=nil
 if safe then s.world.rule_sources[#s.world.rule_sources+1]={when={op='always'},effects={{op='grant_trait',target={kind='archetype',value='avatar'},trait='safe'}}} end
 local p,e=RW_PlanTurn(s.world,{type='wait'},services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 assert(not n.world.entities[2] and (n.world.entities[1]~=nil)==safe)
 local flags=0;for _,unit in pairs(n.world.entities) do if unit.archetype=='flag' then flags=flags+1 end end
 assert(flags==(safe and 0 or 1));assert(RW_Undo(n).world==s.world)
end end
print('PASS: BOOM repeated radius, SAFE victims, HAS and Undo')

for _,layer in ipairs({false,true}) do
 local s=fixture({{'ROCK','IS','BOOM','AND','BOOM'},{'AVATAR','IS','FLOAT'}})
 s.world.entities[1].x=3;s.world.entities[3]=nil
 local frame=assert(RW_CompileWorld(s.world,cs));local w=assert(RW_ProjectWorld(s.world,frame.effects))
 w.entities[2].behaviors.float=layer
 local victims=assert(RW_ResolveContactVictims(w,'boom'));local avatar=false
 for _,id in ipairs(victims) do if id==1 then avatar=true end end
 assert(avatar==layer)
end
print('PASS: BOOM contact layer isolation')
