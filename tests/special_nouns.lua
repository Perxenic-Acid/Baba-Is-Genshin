-- Semantic combinations use the same grounded compiler and transaction services as play.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local function compile(w) local f,e=RW_CompileWorld(w,cs); assert(f,e and e.reason); return f end
local function copy(v) if type(v) ~= "table" then return v end local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t end
local function fixture(sentences)
    local s=RW_CreateSession();local w=s.world
    w.entities={
        [1]={id=1,kind="object",class="object",archetype="rock",x=3,y=3,direction="Mid"},
        [2]={id=2,kind="object",class="object",archetype="avatar",x=3,y=2,direction="None"},
        [3]={id=3,kind="object",class="object",archetype="crate",x=6,y=3,direction="Down"}}
    w.language.nouns={ROCK="rock",AVATAR="avatar",CRATE="crate",LEVEL={tag="level",block_type="level_block"}}
    w.next_entity_id=4
    for row,words in ipairs(sentences) do
        for x,word in ipairs(words) do
            local id=w.next_entity_id;w.next_entity_id=id+1
            w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="None"}
        end
    end
    return s
end
local function projected(s) local f=compile(s.world);return RW_ProjectWorld(s.world,f.effects),f end
local function convert(s)
    local f=compile(s.world);local rel={}
    for _,r in ipairs(f.relations) do if r.op ~= "has" then rel[#rel+1]=r end end
    local changes,err,allocation=RW_PlanConversions(s.world,rel);assert(changes,err)
    local result,status=RW_Commit(s,{consumes_turn=true,changes=changes,id_allocation=allocation})
    assert(status.accepted,status.reason);return result,f
end
-- Ordinary NOT and ALL exclude special types, including Text and LEVEL.
local s=fixture({{"NOT","ROCK","IS","WORD"}})
local p,f=projected(s);assert(not p.entities[1].behaviors.word and p.entities[2].behaviors.word and p.entities[3].behaviors.word)
assert(not p.entities[4].behaviors.word and #f.deferred == 0)
s=fixture({{"ALL","IS","PUSH"}});p=projected(s)
assert(p.entities[1].behaviors.push and p.entities[2].behaviors.push and p.entities[3].behaviors.push)
-- NOT ALL is Text plus Empty; ordinary objects are unaffected.
s=fixture({{"NOT","ALL","IS","WORD"}});p=projected(s)
assert(p.entities[4].behaviors.word and not p.entities[1].behaviors.word and p.empty_cells["1:1"].behaviors.word)
-- Repeated prefixes cancel by parity, including prefixes after AND.
s=fixture({{"NOT","NOT","ROCK","IS","NOT","NOT","WORD"}});p,f=projected(s)
assert(#f.ast == 1 and p.entities[1].behaviors.word and not p.entities[2].behaviors.word)
s=fixture({{"NOT","NOT","NOT","ROCK","IS","WORD"}});p,f=projected(s)
assert(#f.ast == 1 and not p.entities[1].behaviors.word and p.entities[2].behaviors.word)
s=fixture({{"ROCK","IS","PUSH","AND","NOT","NOT","WORD"}});p,f=projected(s)
assert(#f.ast == 2 and p.entities[1].behaviors.word and p.entities[1].behaviors.push)
-- Negative self conversion deletes without a HAS destruction event.
s=fixture({{"ROCK","IS","NOT","ROCK"},{"ROCK","HAS","CRATE"}})
local converted=convert(s);assert(not converted.world.entities[1] and converted.world.next_entity_id == s.world.next_entity_id)
assert(RW_Undo(converted).world == s.world)
s=fixture({{"TEXT","IS","ROCK"}});converted=convert(s)
assert(converted.world.entities[4].archetype == "rock" and converted.world.entities[4].class == "object")
assert(converted.world.entities[4].id == 4 and converted.world.entities[4].direction == "None" and not converted.world.entities[4].text)
s=fixture({{"TEXT","IS","TEXT"},{"TEXT","IS","ROCK"}});converted=convert(s)
assert(converted.world.entities[4].class == "text")
s=fixture({{"TEXT","IS","NOT","TEXT"}});converted=convert(s)
assert(converted.world.entities[1] and not converted.world.entities[4])
-- NOUN IS ALL retains the original and adds missing palette types; no within-cell duplicate.
s=fixture({{"ROCK","IS","ALL"}});local frontier=s.world.next_entity_id;converted=convert(s)
assert(converted.world.entities[1].archetype == "rock" and converted.world.next_entity_id == frontier+2)
for id=frontier,frontier+1 do assert(converted.world.entities[id].x == 3 and converted.world.entities[id].y == 3) end
s=fixture({{"ROCK","IS","ALL"},{"ROCK","IS","NOT","ALL"}});converted=convert(s)
assert(converted.world.entities[1].archetype == "rock" and converted.world.next_entity_id == s.world.next_entity_id)
-- EMPTY is determined from one frozen grid snapshot and includes neither Text nor any object.
s=fixture({{"EMPTY","IS","ROCK"}});frontier=s.world.next_entity_id
local expected=s.world.width*s.world.height;for _ in pairs(s.world.entities) do expected=expected-1 end
converted=convert(s);assert(converted.world.next_entity_id == frontier+expected)
for id=frontier,converted.world.next_entity_id-1 do
    local e=converted.world.entities[id];assert(e.archetype == "rock")
    for _,old in pairs(s.world.entities) do assert(e.x ~= old.x or e.y ~= old.y) end
end
assert(RW_Undo(converted).world == s.world)
s=fixture({{"EMPTY","IS","TEXT"}});converted=convert(s)
assert(converted.world.entities[s.world.next_entity_id].text.name == "EMPTY")
s=fixture({{"EMPTY","IS","EMPTY"},{"EMPTY","IS","ROCK"}});converted=convert(s)
assert(converted.world.next_entity_id == s.world.next_entity_id)
s=fixture({{"ROCK","IS","EMPTY"}});converted=convert(s);assert(not converted.world.entities[1])
-- Negative Empty property overrides a positive one, and STOP blocks entering vacancy.
s=fixture({{"EMPTY","IS","STOP"}});p=projected(s)
p.entities[2].behaviors.control=true
local blocked=RW_ResolveTurn(p,{type="move",dx=1,dy=0})
for _,c in ipairs(blocked.changes) do assert(c.kind ~= "move") end
s=fixture({{"EMPTY","IS","STOP"},{"EMPTY","IS","NOT","STOP"}});p=projected(s)
assert(not p.empty_cells["1:1"] or not p.empty_cells["1:1"].behaviors.block_entry)
-- EMPTY YOU uses ephemeral movement agents; only real PUSH objects reach the plan.
s=fixture({{"EMPTY","IS","YOU"},{"ROCK","IS","PUSH"}});p=projected(s)
local moved=RW_ResolveTurn(p,{type="move",dx=1,dy=0});local rock_move=false
for _,c in ipairs(moved.changes) do assert(c.entity_id > 0);if c.entity_id == 1 and c.kind == "move" then rock_move=true end end
assert(rock_move)
s=fixture({{"EMPTY","IS","YOU"},{"EMPTY","IS","WIN"}});p=projected(s);assert(RW_HasWinContact(p))
-- EMPTY PUSH propagates through vacancies and respects PUSH-before-STOP.
s=fixture({{"EMPTY","IS","PUSH"},{"EMPTY","IS","STOP"}});p=projected(s)
p.entities[2].behaviors.control=true
local stopped=RW_ResolveTurn(p,{type="move",dx=1,dy=0})
for _,c in ipairs(stopped.changes) do assert(c.kind ~= "move") end
s.world.entities[1].x,s.world.entities[1].y=7,2
p=projected(s);p.entities[2].behaviors.control=true
local filled=RW_ResolveTurn(p,{type="move",dx=1,dy=0});local advanced=false
for _,c in ipairs(filled.changes) do if c.entity_id == 2 and c.kind == "move" then advanced=c.to.x == 4 end end
assert(advanced)
-- Physical NOT alternatives retain multiplicity after prefix suppression.
s=fixture({{"NOT","NOT","ROCK","IS","WORD"}})
local id=s.world.next_entity_id;s.world.next_entity_id=id+1
s.world.entities[id]=copy(s.world.entities[4]);s.world.entities[id].id=id
f=compile(s.world);assert(#f.ast == 2)
-- ALL HAS ALL expands one relation per palette member, and Empty HAS stays deferred.
s=fixture({{"ALL","HAS","ALL"}});f=compile(s.world);assert(#f.relations == 18)
s=fixture({{"EMPTY","HAS","TEXT"}});f=compile(s.world);assert(#f.deferred == 1)
-- Negative self-conversion applies to members expanded from ALL.
s=fixture({{"ALL","IS","NOT","ROCK"}});converted=convert(s)
assert(not converted.world.entities[1] and converted.world.entities[2] and converted.world.entities[3])
-- Scoped LEVEL denial also suppresses the board property, not only level-block objects.
s=fixture({{"LEVEL","IS","WIN"},{"LEVEL","IS","NOT","WIN"}})
local ts={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,
    evaluate=function(w) local f=compile(w);return f.effects,nil,f.relations,f.rules end}
local turn,why=RW_PlanTurn(s.world,{type="move",dx=1,dy=0},ts)
assert(turn,why and why.reason);assert(#turn.level_traits == 0)
-- The freely movable NAT fixture starts with no accidental spatial rules.
local definitions=RW_GetNavigationDefinitions()
local nat=RW_InstantiateLevel(definitions["navigation.specials"],"test:specials")
f=compile(nat.world);assert(#f.ast == 0 and #f.deferred == 0)
p=RW_ProjectWorld(nat.world,f.effects);assert(p.entities[1].behaviors.control)
-- Screenshot regression: NOT ROCK IS WORD under Cursor+Level / IS / TEXT.
local screenshot=RW_InstantiateLevel(definitions["navigation.text_word"],"test:cursor-text")
local w=screenshot.world
w.entities[12].x=2 -- Cursor shares the parent Level block at (2,1).
w.entities[5].x,w.entities[5].y=3,1
w.entities[8].x,w.entities[8].y=4,1
w.entities[7].x,w.entities[7].y=3,5
w.entities[6].x,w.entities[6].y=6,5
w.entities[1].x,w.entities[1].y=4,2
w.entities[3].x,w.entities[3].y=5,4
w.entities[9].x,w.entities[9].y=7,8
f=compile(w)
assert(f.word_tokens[12] == "CURSOR" and f.word_tokens[14] == "LINE")
assert(not f.word_tokens[13], "Ordinary NOT must exclude special LEVEL")
local seen_cursor_conversion=false
for _,relation in ipairs(f.relations) do
    if relation.op == "transform_text" and relation.source_type == "cursor" then seen_cursor_conversion=true end
end
assert(seen_cursor_conversion)
local turn_services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(world,effective,kind,contents)
        return RW_PlanContactPhase(world,effective,kind,contents,{victims=RW_ResolveContactVictims,
            births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete})
    end,
    evaluate=function(world) local frame=compile(world);return frame.effects,nil,frame.relations,frame.rules end}
local plan,problem=RW_PlanTurn(w,{type="move",dx=1,dy=0},turn_services)
assert(plan,problem and problem.reason)
local changed,status=RW_Commit(screenshot,plan);assert(status.accepted,status.reason)
assert(changed.world.entities[12].class == "text" and changed.world.entities[12].text.name == "CURSOR")
assert(changed.world.entities[13].archetype == "level_block" and changed.world.entities[13].level_link.target == "parent")
local restored=RW_Undo(changed);assert(restored.world == w)
p=projected(restored);assert(p.entities[12].behaviors.select and p.entities[12].behaviors.word)
print("PASS: screenshot Cursor WORD/IS TEXT conversion on overlapping parent Level and Undo; LEVEL exclusion")
print("PASS: NOT parity/complements, ALL palette/products, TEXT retype, virtual EMPTY conversion/STOP/YOU/WIN, sandbox")

-- Right NOT filters HAS after subject expansion, without erasing independent products.
s=fixture({{"ROCK","HAS","ALL"},{"ROCK","HAS","NOT","ROCK"}})
f=compile(s.world);assert(#f.relations == 2 and #f.deferred == 0)
for _,r in ipairs(f.relations) do assert(r.product.archetype ~= "rock") end
s=fixture({{"ROCK","HAS","ALL"},{"ROCK","HAS","NOT","ALL"},{"ROCK","HAS","CRATE"}})
f=compile(s.world);assert(#f.relations == 1 and f.relations[1].product.archetype == "crate")
s=fixture({{"NOT","ROCK","HAS","TEXT"},{"ALL","HAS","NOT","TEXT"}})
f=compile(s.world);assert(#f.relations == 0 and #f.deferred == 0)
s=fixture({{"TEXT","HAS","ROCK"},{"NOT","ALL","HAS","NOT","ROCK"}})
f=compile(s.world);assert(#f.relations == 0)
s=fixture({{"ALL","IS","PUSH"},{"NOT","ALL","IS","NOT","PUSH"}})
p=projected(s);assert(p.entities[1].behaviors.push and p.entities[2].behaviors.push)
assert(not p.entities[4].behaviors.push)
print("PASS: ALL HAS ALL original multiplicity; left/right NOT HAS, TEXT and ALL expansion provenance")

-- Cross-family conversion vetoes: negative ALL does not mean every individual noun.
s=fixture({{"ROCK","IS","ALL"},{"ROCK","IS","NOT","TEXT"}})
converted=convert(s);assert(converted.world.entities[1].archetype == "rock")
assert(converted.world.next_entity_id == s.world.next_entity_id+2)
s=fixture({{"ROCK","IS","TEXT"},{"NOT","TEXT","IS","NOT","TEXT"}})
converted=convert(s);assert(converted.world.entities[1].archetype == "rock")
s=fixture({{"EMPTY","IS","TEXT"},{"NOT","ALL","IS","NOT","TEXT"}})
converted=convert(s);assert(converted.world.next_entity_id == s.world.next_entity_id)
s=fixture({{"TEXT","IS","ROCK"},{"NOT","ALL","IS","NOT","ROCK"}})
converted=convert(s);assert(converted.world.entities[4].class == "text")
assert(RW_Undo(converted).world == s.world)
print("PASS: ALL/EMPTY/TEXT cross-family left/right NOT conversions and Undo")

-- User regression: AVATAR IS NOT ALL alone must never create victory or conversions.
s=fixture({{"AVATAR","IS","NOT","ALL"}})
p,f=projected(s);assert(not RW_HasWinContact(p))
assert(#f.relations == 1 and f.relations[1].op == "forbid_transform"
    and f.relations[1].source_type == "avatar" and f.relations[1].target_type == "@all")
converted=convert(s);assert(converted.world.entities[2].archetype == "avatar")
assert(converted.world.next_entity_id == s.world.next_entity_id)
assert(not RW_HasWinContact(projected(converted)))
print("PASS: AVATAR IS NOT ALL preserves Avatar and cannot trigger WIN by itself")
