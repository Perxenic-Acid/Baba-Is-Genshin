-- Repeated physical rules are instances, even when their noun targets coincide.
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,evaluate=function(world)
        local ast=assert(RW_ParseRuleAST(RW_ReadLines(world),world.language))
        local generated,deferred,conversions=RW_LowerRuleAST(ast,world.semantics)
        assert(generated,deferred)
        local effects,err=RW_EvaluateRules(world,generated)
        return effects,err,conversions
    end}
local function stacked(is_count,first_count,and_count,last_count)
    local session=RW_CreateSession()
    session.world.entities={[1]={id=1,kind="object",class="object",archetype="crate",x=2,y=4,direction="Mid"}}
    session.world.language.operators={AND="and"}
    session.world.language.nouns.ROCK="rock"
    session.world.next_entity_id=2
    local slots={{"CRATE",1},{"IS",is_count},{"ROCK",first_count}}
    if and_count then slots[4]={"AND",and_count}; slots[5]={"ROCK",last_count} end
    for x,slot in ipairs(slots) do
        for _=1,slot[2] do
            local id=session.world.next_entity_id
            session.world.entities[id]={id=id,kind="object",class="text",direction="None",x=x,y=1,text={name=slot[1]}}
            session.world.next_entity_id=id+1
        end
    end
    return session
end
for _,case in ipairs({{3,2,false,false,6},{1,1,1,1,2},{3,2,2,2,48},{1,2,2,3,24}}) do
    local session=stacked(case[1],case[2],case[3],case[4])
    local ast=assert(RW_ParseRuleAST(RW_ReadLines(session.world),session.world.language))
    assert(#ast == case[5],"Wrong multiplicity of complete sentences/AND terms")
    if case[5] == 48 then
        local sentences={}
        for _,rule in ipairs(ast) do
            local ids=rule.source.sentence_entity_ids
            assert(#ids == 5)
            local key=table.concat(ids,",")
            sentences[key]=(sentences[key] or 0)+1
        end
        local count=0
        for _,terms in pairs(sentences) do assert(terms == 2); count=count+1 end
        assert(count == 24)
    end
    local frontier=session.world.next_entity_id
    local plan=assert(RW_PlanTurn(session.world,{type="move",dx=1,dy=0},services))
    local completed,result=RW_Commit(session,plan)
    assert(result.accepted and #completed.history == 1)
    local count=0
    for _,entity in pairs(completed.world.entities) do
        if entity.class == "object" then
            assert(entity.archetype == "rock" and entity.x == 2 and entity.y == 4 and entity.direction == "Mid")
            count=count+1
        end
    end
    assert(count == case[5] and completed.world.next_entity_id == frontier+case[5]-1)
    local restored=RW_Undo(completed)
    assert(restored.world == session.world and restored.world.entities[1].archetype == "crate")
    assert(restored.world.next_entity_id == frontier and not restored.world.entities[frontier])
end
print("PASS: stacked physical rule multiplicity, complete AND paths (24 sentences/48 products), atomic allocation and Undo")
