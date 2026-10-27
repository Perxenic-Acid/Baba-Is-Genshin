-- Physical grammar -> frozen contact rule frame -> SINK -> DEFEAT -> one Commit.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
local contact_services={victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,
    create=RW_PlanCreate,delete=RW_PlanDelete}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(world,effective,kind,contents)
        return RW_PlanContactPhase(world,effective,kind,contents,contact_services)
    end,
    evaluate=function(world)
        local ast=assert(RW_ParseRuleAST(RW_ReadLines(world),world.language))
        local generated,deferred,relations=RW_LowerRuleAST(ast,world.semantics)
        assert(generated,deferred)
        local effects,err=RW_EvaluateRules(world,generated)
        return effects,err,relations,generated
    end}
local right={type="move",dx=1,dy=0}
local function make(objects,rules)
    local session=RW_CreateSession()
    local world=session.world
    world.entities={}; world.next_entity_id=20
    for id,object in ipairs(objects) do
        world.entities[id]={id=id,kind="object",class="object",archetype=object[1],
            x=object[2],y=object[3],direction=object[4] or "Mid",level_link=copy(object.level_link)}
    end
    for word,kind in pairs({ROCK="rock",SKULL="skull",WATER="water",FLAG="flag",CURSOR="cursor"}) do world.language.nouns[word]=kind end
    world.language.nouns.LEVEL={tag="level",block_type="level_block"}
    world.language.properties.WIN="win"
    for row,words in ipairs(rules) do
        for x,word in ipairs(words) do
            local id=world.next_entity_id
            world.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=5+row,direction="None"}
            world.next_entity_id=id+1
        end
    end
    return session
end
local function step(session,action)
    local plan,err=RW_PlanTurn(session.world,action or right,services)
    assert(plan,err and err.reason)
    local next_session,result=RW_Commit(session,plan)
    assert(result.accepted,result.reason)
    assert(#next_session.history == #session.history+1)
    return next_session,plan
end
local function count(world,kind)
    local n=0; for _,e in pairs(world.entities) do if e.archetype == kind then n=n+1 end end; return n
end
local function basic_rules(kind)
    return {{"AVATAR","IS","YOU"},{kind == "sink" and "WATER" or "SKULL","IS",string.upper(kind)}}
end
-- DEFEAT removes only the touching YOU, never the hazard, SELECT or the level.
local d=make({{"avatar",2,2},{"skull",3,2},{"avatar",6,2},{"cursor",3,2}},basic_rules("defeat"))
local dead,death_plan=step(d)
assert(not dead.world.entities[1] and dead.world.entities[2] and dead.world.entities[3] and dead.world.entities[4])
local defeat_stage
for _,stage in ipairs(death_plan.stages) do if stage.name == "defeat" then defeat_stage=stage.plan end end
assert(not dead.defeated and #defeat_stage.events == 1)
assert(defeat_stage.events[1].cause == "defeat")
assert(RW_Undo(dead).world == d.world)
local self_defeat=make({{"avatar",2,2}},{{"AVATAR","IS","YOU","AND","DEFEAT"}})
local self_dead=step(self_defeat)
assert(not self_dead.world.entities[1] and RW_Undo(self_dead).world == self_defeat.world)
local separate_self=make({{"avatar",2,2}},{{"AVATAR","IS","YOU"},{"AVATAR","IS","DEFEAT"},
    {"AVATAR","HAS","ROCK"}})
local self_born=step(separate_self)
assert(not self_born.world.entities[1] and count(self_born.world,"rock") == 1)
assert(self_born.world.entities[separate_self.world.next_entity_id].direction == "Right")
assert(RW_Undo(self_born).world == separate_self.world)
local mutual=make({{"avatar",2,2},{"avatar",3,2}},{{"AVATAR","IS","YOU","AND","DEFEAT"}})
-- Different input positions both move together, so keep the pair initially overlapped.
mutual.world.entities[2].x=2
local mutual_dead=step(mutual)
assert(not mutual_dead.world.entities[1] and not mutual_dead.world.entities[2])
-- SINK is not self-destruction; all distinct overlapping partners and the sink die.
local alone=make({{"water",3,2}},{{"WATER","IS","SINK"}})
assert(step(alone).world.entities[1])
local s=make({{"avatar",2,2},{"water",3,2},{"crate",3,2}},basic_rules("sink"))
local sunk=step(s)
assert(not sunk.world.entities[1] and not sunk.world.entities[2] and not sunk.world.entities[3])
assert(not sunk.defeated and RW_Undo(sunk).world == s.world)
local double_sink=make({{"water",3,2},{"water",3,2}},{{"WATER","IS","SINK"}})
assert(count(step(double_sink).world,"water") == 0)
-- Pushed destruction, duplicate HAS, direction, identity-bound metadata and Undo/replay.
local h=make({{"avatar",2,2},{"crate",3,2},{"water",4,2}},{{"AVATAR","IS","YOU"},
    {"CRATE","IS","PUSH"},{"WATER","IS","SINK"},{"CRATE","HAS","ROCK","AND","ROCK"}})
h.world.entities[2].level_link={target="child",source_type="crate",definition_id="navigation.puzzle",label="C"}
local frontier=h.world.next_entity_id
local born,born_plan=step(h)
assert(born.world.entities[1].x == 3 and not born.world.entities[2] and not born.world.entities[3])
assert(count(born.world,"rock") == 2 and born.world.next_entity_id == frontier+2)
for id=frontier,frontier+1 do
    local e=born.world.entities[id]
    assert(e.x == 4 and e.y == 2 and e.direction == "Right" and e.level_link.definition_id == "navigation.puzzle")
    assert(e.level_link ~= h.world.entities[2].level_link and not e.behaviors and not e.traits)
end
assert(born.world.entities[frontier].level_link ~= born.world.entities[frontier+1].level_link)
assert(RW_Undo(born).world == h.world)
local replay=RW_Commit(RW_Undo(born),born_plan)
assert(replay.world.entities[frontier+1].archetype == "rock")
local has_self=make({{"avatar",2,2},{"crate",3,2},{"water",4,2}},{{"AVATAR","IS","YOU"},
    {"CRATE","IS","PUSH"},{"WATER","IS","SINK"},{"CRATE","HAS","CRATE"}})
local replacement=step(has_self)
assert(count(replacement.world,"crate") == 1 and count(replacement.world,"water") == 0)
assert(step(replacement).world.entities[replacement.world.next_entity_id-1].x == 5)
-- Separate identical HAS sentences also generate separately.
local repeated=make({{"avatar",2,2},{"skull",3,2}},{{"AVATAR","IS","YOU"},{"SKULL","IS","DEFEAT"},
    {"AVATAR","HAS","ROCK"},{"AVATAR","HAS","ROCK"}})
assert(count(step(repeated).world,"rock") == 2)
-- Conversion is not destruction, and contact rules see the converted archetype.
local conversion=make({{"crate",3,2}},{{"CRATE","IS","ROCK"},{"CRATE","HAS","FLAG"}})
local converted=step(conversion)
assert(count(converted.world,"rock") == 1 and count(converted.world,"flag") == 0)
local converted_sink=make({{"crate",3,2},{"skull",3,2}},{{"CRATE","IS","ROCK"},
    {"ROCK","IS","SINK"},{"ROCK","HAS","FLAG"},{"CRATE","HAS","AVATAR"}})
local converted_born=step(converted_sink)
assert(count(converted_born.world,"flag") == 1 and count(converted_born.world,"avatar") == 0)
-- HAS TEXT creates the container's noun text; TEXT HAS noun covers physical Text.
local has_text=make({{"avatar",2,2},{"skull",3,2}},{{"AVATAR","IS","YOU"},
    {"SKULL","IS","DEFEAT"},{"AVATAR","HAS","TEXT"}})
local text_frontier=has_text.world.next_entity_id
local text_born=step(has_text)
assert(text_born.world.entities[text_frontier].class == "text" and text_born.world.entities[text_frontier].text.name == "AVATAR")
assert(text_born.world.entities[text_frontier].direction == "Right")
local text_has=make({{"water",6,2}},{{"WATER","IS","SINK"},{"TEXT","HAS","ROCK"}})
local text_id=text_has.world.next_entity_id
text_has.world.entities[text_id]={id=text_id,kind="object",class="text",text={name="UNUSED"},direction="Left",x=6,y=2}
text_has.world.next_entity_id=text_id+1
assert(count(step(text_has).world,"rock") == 1)
-- Unconfigured HAS LEVEL remains unusable; HAS is not identity protection.
local has_level=make({{"avatar",2,2},{"skull",3,2}},{{"AVATAR","IS","YOU"},
    {"SKULL","IS","DEFEAT"},{"AVATAR","HAS","LEVEL"}})
local level_born=step(has_level)
assert(level_born.world.entities[has_level.world.next_entity_id].archetype == "level_block")
assert(not level_born.world.entities[has_level.world.next_entity_id].level_link)
-- Freeze the contact rule frame: sinking a DEFEAT/HAS word does not retract it mid-frame.
local frozen=make({{"avatar",2,2},{"skull",3,2},{"water",3,7},{"water",3,9}},
    {{"AVATAR","IS","YOU"},{"SKULL","IS","DEFEAT"},{"WATER","IS","SINK"},{"AVATAR","HAS","ROCK"}})
local frozen_result=step(frozen)
assert(not frozen_result.world.entities[1] and count(frozen_result.world,"rock") == 1)
local effects=assert(services.evaluate(frozen_result.world))
local projected=assert(RW_ProjectWorld(frozen_result.world,effects))
assert(not projected.entities[2].behaviors.defeat) -- Retracted in the next rule compilation.
-- HAS births participate in the later DEFEAT phase, not recursively in earlier SINK.
local ordered=make({{"crate",3,2},{"water",3,2}},{{"CRATE","HAS","AVATAR"},
    {"WATER","HAS","SKULL"},{"AVATAR","IS","YOU"},{"SKULL","IS","DEFEAT"},
    {"WATER","IS","SINK"},{"AVATAR","HAS","FLAG"}})
local ordered_result=step(ordered)
assert(count(ordered_result.world,"avatar") == 0 and count(ordered_result.world,"skull") == 1 and count(ordered_result.world,"flag") == 1)
local late_sink=make({{"avatar",2,2},{"skull",3,2}},{{"AVATAR","IS","YOU"},
    {"SKULL","IS","DEFEAT"},{"AVATAR","HAS","WATER"},{"WATER","IS","SINK"}})
local first_turn=step(late_sink)
assert(count(first_turn.world,"water") == 1 and count(first_turn.world,"skull") == 1)
local second_turn=step(first_turn)
assert(count(second_turn.world,"water") == 0 and count(second_turn.world,"skull") == 0)
-- Late HAS allocation failure rejects the whole movement/destruction transaction.
local exhausted=copy(h); exhausted.world.next_entity_id=9007199254740991
local rejected,why=RW_PlanTurn(exhausted.world,right,services)
assert(not rejected and why.stage == "sink" and why.reason == "entity_id_exhausted")
assert(exhausted.world.entities[1].x == 2 and exhausted.world.entities[2].archetype == "crate" and #exhausted.history == 0)
-- Contact and fresh target resolution failure boundaries do not Commit any state.
for _,failure in ipairs({{"evaluate",3},{"refresh",1},{"refresh",2},{"contact",1},{"contact",2},{"preview",3},{"preview",4},{"preview",5}}) do
    local adapted,calls={},{}
    for name,fn in pairs(services) do adapted[name]=function(...)
        calls[name]=(calls[name] or 0)+1
        if name == failure[1] and calls[name] == failure[2] then return nil,"injected_contact_failure" end
        return fn(...)
    end end
    local no_plan,problem=RW_PlanTurn(h.world,right,adapted)
    assert(not no_plan and problem.reason == "injected_contact_failure")
    assert(h.world.entities[1].x == 2 and h.world.entities[2] and #h.history == 0)
end
-- Freeze syntax, not condition truth: existing rule conditions are re-evaluated.
local conditional=make({{"avatar",2,2},{"skull",3,2},{"rock",6,2},{"water",6,2}},
    {{"SKULL","IS","DEFEAT"},{"WATER","IS","SINK"}})
conditional.world.rule_sources[#conditional.world.rule_sources+1]={when={op="overlap",
    left={kind="archetype",value="rock"},right={kind="archetype",value="water"}},
    effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
local condition_off=step(conditional)
assert(condition_off.world.entities[1] and condition_off.world.entities[1].x == 3)
local activated=make({{"avatar",3,2},{"skull",3,2},{"crate",6,2},{"water",6,2}},
    {{"SKULL","IS","DEFEAT"},{"WATER","IS","SINK"},{"CRATE","HAS","ROCK","AND","ROCK"}})
activated.world.rule_sources[#activated.world.rule_sources+1]={when={op="overlap",
    left={kind="archetype",value="rock"},right={kind="archetype",value="rock"}},
    effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
local condition_on=step(activated)
assert(not condition_on.world.entities[1] and count(condition_on.world,"rock") == 2)
-- Stacked HAS words retain complete-sentence multiplicity, just like IS.
local stacked=make({{"water",3,2},{"crate",3,2}},{{"WATER","IS","SINK"},{"CRATE","HAS","ROCK","AND","ROCK"}})
for _,entry in ipairs({{"HAS",2},{"HAS",2},{"ROCK",3},{"AND",4},{"ROCK",5}}) do
    local id=stacked.world.next_entity_id
    stacked.world.entities[id]={id=id,kind="object",class="text",text={name=entry[1]},x=entry[2],y=7,direction="None"}
    stacked.world.next_entity_id=id+1
end
local stacked_result=step(stacked)
assert(count(stacked_result.world,"rock") == 48)
assert(stacked_result.world.next_entity_id == stacked.world.next_entity_id+48)
-- Breaking HAS before compilation retracts its births normally.
local broken_has=copy(h)
for _,entity in pairs(broken_has.world.entities) do
    if entity.class == "text" and entity.text.name == "HAS" then entity.text.name="UNUSED" end
end
assert(count(step(broken_has).world,"rock") == 0)
-- Win detection uses surviving YOU and the same contact frame as destruction.
local tree_services={}
for name,fn in pairs(services) do tree_services[name]=fn end
for name,fn in pairs({active=RW_GetActiveLevel,update=RW_UpdateActiveLevel,enter=RW_EnterLevel,
    return_level=RW_ReturnLevel,selectors=RW_LevelSelectorIDs,place_selectors=RW_PlaceLevelSelectors,
    bind_entry=RW_BindLevelEntry,commit_session=RW_Commit,outcome=RW_RecordLevelOutcome,
    candidates=RW_LevelSelectionCandidates,win=RW_HasWinContact,level_outcome=RW_ResolveLevelPropertyOutcome}) do tree_services[name]=fn end
local function tree_step(session)
    local definition=assert(RW_CreateLevelDefinition("contact.win",session.world))
    local tree=assert(RW_CreateLevelTree({[definition.id]=definition},definition.id))
    local turn=assert(RW_PlanLevelAction(tree,right,tree_services))
    return RW_CommitLevelTree(tree,turn)
end
local win_and_defeat=make({{"avatar",2,2},{"skull",3,2},{"flag",3,2}},
    {{"AVATAR","IS","YOU"},{"SKULL","IS","DEFEAT"},{"FLAG","IS","WIN"}})
local lost_tree=tree_step(win_and_defeat)
assert(not lost_tree.outcomes[lost_tree.active_id] and not RW_GetActiveLevel(lost_tree).world.entities[1])
assert(not RW_GetActiveLevel(lost_tree).defeated)
assert(RW_GetActiveLevel(RW_UndoLevelTree(lost_tree)).world.entities[1].x == 2)
local frozen_win=make({{"avatar",2,2},{"flag",3,2},{"water",3,8}},
    {{"AVATAR","IS","YOU"},{"WATER","IS","SINK"},{"FLAG","IS","WIN"}})
local won_tree=tree_step(frozen_win)
assert(won_tree.outcomes[won_tree.active_id].kind == "win")
print("PASS: DEFEAT/SINK identity, ordered frozen rules, repeated HAS/Text/Level, new births, allocation rollback and Undo")
