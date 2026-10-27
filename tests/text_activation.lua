-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
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
local s=fixture({{'ROCK','IS','PUSH','AND','WIN'},{'CRATE','ON','FLAG','IS','SAFE'},{'ROCK','IS','NOT','PUSH'}})
local w=s.world
w.entities[w.next_entity_id]={id=w.next_entity_id,kind='object',class='text',text={name='FLOAT'},x=11,y=2,direction='None'}
local frame=assert(RW_CompileWorld(w,cs))
for id,e in pairs(w.entities) do if e.class=='text' then
 assert((frame.active_text_ids[id]==true)==(e.text.name~='FLOAT'))
end end
-- The condition has no Crate/Flag witness, yet every token is syntactically active.
local found=false
for _,ast in ipairs(frame.ast) do if ast.when.op=='spatial' then
 for _,id in ipairs(ast.source.entity_ids) do assert(frame.active_text_ids[id]) end;found=true
end end
assert(found and not frame.active_text_ids[1])
-- Disconnect a complete sentence and recompile: no inherited highlight from last frame.
for _,e in pairs(w.entities) do if e.text and e.text.name=='AND' then e.y=e.y-1 end end
local broken=assert(RW_CompileWorld(w,cs));local win
for id,e in pairs(w.entities) do if e.text and e.text.name=='WIN' then win=id end end
assert(frame.active_text_ids[win] and not broken.active_text_ids[win])
print('PASS: activation tracks complete AST sentence/AND/NOT/conditions, isolated Text and retraction')
