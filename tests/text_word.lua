local compile_services={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(world,effective,kind,contents)
        return RW_PlanContactPhase(world,effective,kind,contents,{victims=RW_ResolveContactVictims,
            births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete})
    end,
    evaluate=function(world)
        local frame,err=RW_CompileWorld(world,compile_services)
        if not frame then return nil,err.reason end
        return frame.effects,nil,frame.relations,frame.rules
    end}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
local up={type="move",dx=0,dy=-1}
local right={type="move",dx=1,dy=0}
local function step(session,action)
    local plan,err=RW_PlanTurn(session.world,action or up,services)
    assert(plan,err and err.reason)
    local result,status=RW_Commit(session,plan)
    assert(status.accepted,status.reason)
    return result,plan
end
local function frame(world) local f,e=RW_CompileWorld(world,compile_services); assert(f,e and e.reason); return f end
local definitions=RW_GetNavigationDefinitions()
local lab=assert(RW_InstantiateLevel(definitions["navigation.text_word"],"test:word"))
assert(not frame(lab.world).word_tokens[3])
local moved=step((step(lab))) -- Push WORD into ROCK IS WORD.
local enabled=frame(moved.world)
assert(enabled.word_tokens[3] == "ROCK" and enabled.iterations == 2)
assert(moved.world.entities[3].class == "object" and not moved.world.entities[3].text)
assert(#RW_ReadLines(moved.world)[3].cells[4] == 0)
assert(RW_ReadLines(moved.world,enabled.word_tokens)[3].cells[4][1].id == 3)
-- A WORD object can be a rule subject; its own physical identity is the provenance.
local with_you=RW_Commit(moved,assert(RW_PlanCreate(moved.world,{
    {kind="object",class="text",text={name="YOU"},x=6,y=3,direction="None"}})))
local rules=frame(with_you.world)
local found=false
for _,rule in ipairs(rules.ast) do
    if rule.object.tag == "property" and rule.object.name == "you" then
        assert(rule.source.entity_ids[1] == 3); found=true
    end
end
assert(found and RW_ProjectWorld(with_you.world,rules.effects).entities[3].behaviors.control)
local driven=step(with_you,right)
assert(driven.world.entities[3].x == 5 and RW_Undo(driven).world == with_you.world)
-- A WORD object can also supply a noun on the right-hand side.
local rhs=copy(moved.world)
rhs.language.nouns.FLAG="flag"
for index,word in ipairs({"FLAG","IS"}) do
    local id=rhs.next_entity_id
    rhs.entities[id]={id=id,kind="object",class="text",text={name=word},x=1+index,y=3,direction="None"}
    rhs.next_entity_id=id+1
end
local rhs_found=false
for _,relation in ipairs(frame(rhs).relations) do
    if relation.op == "transform" and relation.source_type == "flag" and relation.target_type == "rock" then rhs_found=true end
end
assert(rhs_found)
-- WORD never intrinsically grants PUSH; the laboratory deliberately has a separate base rule.
local no_push=copy(moved.world)
table.remove(no_push.rule_sources,#no_push.rule_sources)
local np=frame(no_push)
assert(RW_ProjectWorld(no_push,np.effects).entities[3].behaviors.word)
assert(not RW_ProjectWorld(no_push,np.effects).entities[3].behaviors.push)
-- Cold grounding retracts WORD even if an object could otherwise support its own WORD sentence.
local self_supported=copy(moved.world)
local new_id=self_supported.next_entity_id
self_supported.entities[new_id]={id=new_id,kind="object",class="text",text={name="WORD"},x=6,y=3,direction="None"}
self_supported.next_entity_id=new_id+1
assert(frame(self_supported).word_tokens[3])
self_supported.entities[2].x=3 -- Break the independent physical-text seed.
assert(not frame(self_supported).word_tokens[3])
-- IS TEXT is an identity-preserving, fully validated class conversion.
local text=copy(lab)
text.world.entities[8].x,text.world.entities[8].y=6,5
text.world.entities[3].direction="Mid"
text.world.entities[3].level_link={target="parent",label="K"}
local converted,conversion_plan=step(text,{type="move",dx=0,dy=1})
local entity=converted.world.entities[3]
assert(entity.class == "text" and entity.text.name == "ROCK" and not entity.archetype)
assert(entity.x == 4 and entity.y == 3 and entity.direction == "Mid" and entity.level_link.label == "K")
assert(entity.level_link ~= text.world.entities[3].level_link)
assert(RW_CreateLevelDefinition("text-link",converted.world))
assert(converted.world.next_entity_id == text.world.next_entity_id)
assert(RW_ProjectWorld(converted.world,frame(converted.world).effects).entities[3].behaviors.push)
assert(RW_Undo(converted).world == text.world)
local bad=copy(conversion_plan)
bad.stages[2].plan.changes[1].to.text.name=""
local unchanged,rejected=RW_Commit(text,bad)
assert(unchanged == text and not rejected.accepted and rejected.phase == "conversion")
assert(text.world.entities[1].y == 8)
-- Mixed and repeated TEXT outputs preserve multiplicity, metadata and allocator Undo.
local operations,why,allocation=RW_PlanConversions(text.world,{
    {op="transform_text",source_type="rock"},{op="transform",source_type="rock",target_type="avatar"},
    {op="transform_text",source_type="rock"}})
assert(operations and not why and #operations == 3)
local multi,result=RW_Commit(text,{consumes_turn=true,changes=operations,id_allocation=allocation})
assert(result.accepted and multi.world.entities[3].class == "text")
assert(multi.world.entities[allocation.from].archetype == "avatar")
assert(multi.world.entities[allocation.from+1].text.name == "ROCK")
assert(RW_Undo(multi).world == text.world)
local flat={consumes_turn=true,changes={operations[1],{kind="move",entity_id=3,from={x=4,y=3},to={x=5,y=3}}}}
assert(select(2,RW_Commit(text,flat)).reason == "conflicting_retype")
local function simple(sentences)
    local session=RW_CreateSession()
    session.world.entities={[1]={id=1,kind="object",class="object",archetype="rock",x=2,y=2,direction="None"}}
    session.world.language.nouns.ROCK="rock"
    session.world.next_entity_id=10
    for row,words in ipairs(sentences) do
        for x,word in ipairs(words) do
            local id=session.world.next_entity_id
            session.world.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=5+row,direction="None"}
            session.world.next_entity_id=id+1
        end
    end
    return session
end
local negative=simple({{"ROCK","IS","WORD"},{"ROCK","IS","NOT","WORD"}})
assert(not frame(negative.world).word_tokens[1])
local negative_text=simple({{"ROCK","IS","TEXT"},{"ROCK","IS","NOT","TEXT"}})
assert(step(negative_text,right).world.entities[1].class == "object")
local identity=simple({{"ROCK","IS","TEXT"},{"ROCK","IS","ROCK"}})
assert(step(identity,right).world.entities[1].class == "object")
local negative_noun=simple({{"ROCK","IS","AVATAR"},{"ROCK","IS","NOT","AVATAR"}})
assert(step(negative_noun,right).world.entities[1].archetype == "rock")
-- Property denial overrides a positive configured rule, including TEXT IS PUSH.
local deny_push=simple({{"TEXT","IS","NOT","PUSH"}})
local denied=frame(deny_push.world)
assert(not RW_ProjectWorld(deny_push.world,denied.effects).entities[10].behaviors.push)
-- A self-negating WORD loop commits the triggering move and locks until Undo.
local cycle=simple({{"ROCK","IS","WORD"}})
cycle.world.entities[2]={id=2,kind="object",class="object",archetype="avatar",x=4,y=4,direction="None"}
cycle.world.rule_sources[#cycle.world.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
for _,spec in ipairs({{"IS",3,2},{"NOT",4,3},{"WORD",5,2}}) do
    local id=cycle.world.next_entity_id
    cycle.world.entities[id]={id=id,kind="object",class="text",text={name=spec[1]},x=spec[2],y=spec[3],direction="None"}
    cycle.world.next_entity_id=id+1
end
assert(frame(cycle.world).word_tokens[1])
local terminal,terminal_plan=step(cycle,up)
assert(terminal_plan.infinite_loop and terminal.world.infinite_loop and terminal.world.entities[2].y == 3)
assert(#terminal.history == 1 and not cycle.world.infinite_loop and cycle.world.entities[2].y == 4)
local locked,why=RW_PlanTurn(terminal.world,up,services)
assert(not locked and why.reason == "infinite_loop_undo_only")
local rejected,result=RW_Commit(terminal,{consumes_turn=true,changes={}})
assert(rejected == terminal and not result.accepted)
assert(RW_Undo(terminal).world == cycle.world)
-- Subject NOT now expands over the authored ordinary noun palette.
local subject_not=simple({{"NOT","ROCK","IS","WORD"}})
assert(#frame(subject_not.world).deferred == 0 and not frame(subject_not.world).word_tokens[1])
-- Malformed lexical overlays are rejected at the Reader boundary.
assert(not RW_ReadLines(lab.world,{[999]="ROCK"}))
assert(not RW_ReadLines(lab.world,{[2]="ROCK"}))
print("PASS: IS TEXT retype/identity/multiplicity, WORD grounded reading/retraction, RHS NOT, Infinite Loop lock and Undo")
