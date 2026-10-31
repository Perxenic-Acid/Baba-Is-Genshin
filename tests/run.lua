-- Run from repository root: luatex --luaonly tests/run.lua
-- Core Lua tests plus real bootstrap pipelines with only host UI/input mocked.
local modules = {"world", "reader", "grammar", "rules", "properties", "movement", "renderer"}
local scripts, listeners = {}, {}
local self_test_calls=0
for _, name in ipairs(modules) do
    dofile("external_lua_file/" .. name .. ".lua")
    scripts[#scripts + 1] = {path = name, alive = true,
        Invoke = function(_, method, ...)
            if method:find("SelfTest") then self_test_calls=self_test_calls+1 end
            return assert(_G[method], method)(...)
        end}
end
local rendered, history_depth, navigation
RW_Render = function(world, depth, _, context)
    rendered, history_depth, navigation = world, depth, context
end
printerr = function(...) error(table.concat({...}, " ")) end
local keys = {
    KeyboardMoveForwardKeyDown = "up", KeyboardMoveBackwardKeyDown = "down",
    KeyboardMoveLeftKeyDown = "left", KeyboardMoveRightKeyDown = "right",
    KeyboardCraftspersonKey12Down = "undo", KeyboardInteractKeyDown = "confirm", KeyboardJumpKeyDown="wait"
}
Enum = {KeyEventType = keys}
script = {object = {
    GetScripts = function() return scripts end,
    AddKeyEventListener = function(_, key, callback) listeners[key] = callback end
}}
dofile("external_lua_file/bootstrap.lua")
-- Native Lua has a watchdog; an unboundedly expensive startup can pass semantic
-- tests yet fail before the board appears. Keep instruction work bounded too.
local startup_instructions=0
debug.sethook(function()
    startup_instructions=startup_instructions+1000
    if startup_instructions > 2000000 then error("Production startup exceeded Lua instruction budget") end
end,"",1000)
OnStart()
debug.sethook()
print("Normal startup Lua instructions: " .. startup_instructions)
assert(self_test_calls == 0, "Production startup invoked regression self-tests")
assert(rendered and history_depth == 0 and rendered.entities[12].x == 2)
-- Exercise production closures with diagnostics disabled, including tree navigation.
listeners.right();assert(history_depth == 1 and rendered.entities[1].x == 7)
listeners.undo();assert(history_depth == 0 and rendered.entities[12].x == 2)
listeners.up();listeners.confirm()
assert(navigation.title:find("PUZZLE") and history_depth == 2)
listeners.right();listeners.confirm()
assert(navigation.title:find("MAP"))
while history_depth > 0 do listeners.undo() end
assert(self_test_calls == 0 and rendered.entities[12].x == 2 and rendered.entities[12].y == 2)
print("PASS: production boot/navigation/movement/Undo without diagnostics")
-- The new motion laboratory is exercised through actual production input adapters.
for i=1,10 do listeners.right() end;listeners.confirm()
for i=1,5 do listeners.right() end;listeners.confirm()
assert(rendered.entities[5].archetype=="rock" and rendered.entities[5].x==12)
assert(rendered.width==32 and rendered.height==32)
local loose={}
for _,entity in pairs(rendered.entities) do
    if entity.class=="text" and entity.y>=15 then
        for _,other in ipairs(loose) do
            assert(math.abs(entity.x-other.x)>=3 or math.abs(entity.y-other.y)>=3,"Sparse laboratory words overlap")
        end
        loose[#loose+1]=entity
    end
end
assert(#loose>=40)
local make_frontier=rendered.next_entity_id
listeners.wait();assert(rendered.entities[5].x==13 and rendered.entities[8].direction=="Left")
assert(rendered.entities[make_frontier].archetype=="flag" and rendered.entities[make_frontier].x==13 and rendered.entities[make_frontier].y==10)
listeners.undo();assert(rendered.entities[5].x==12 and rendered.entities[8].direction=="Up" and not rendered.entities[make_frontier])
listeners.right();assert(rendered.entities[4].x==7 and rendered.entities[6].x==8 and rendered.entities[5].x==13)
listeners.undo();assert(rendered.entities[4].x==6 and rendered.entities[6].x==7 and rendered.entities[5].x==12)
listeners.down();listeners.right();listeners.right()
assert(rendered.entities[4].x==8 and rendered.entities[4].y==11 and rendered.entities[9].x==10)
listeners.undo();assert(rendered.entities[4].x==7 and rendered.entities[9].x==9)
while history_depth>0 do listeners.undo() end
assert(self_test_calls==0 and rendered.entities[12].x==2)
print("PASS: production MOTION laboratory wait/MOVE, sleeping PUSH, whole-tree Undo without diagnostics")
-- Diagnostics get a fresh mocked binding surface. Production never calls them.
listeners={}
RW_StartWithSelfTests()
assert(self_test_calls >= 20, "Explicit diagnostics skipped module self-tests")
assert(rendered and listeners.right and listeners.undo, "Bootstrap did not initialize")
local initial = rendered
listeners.right()
assert(history_depth == 1 and rendered.entities[12].x == 3)
assert(rendered.entities[4].x == 3, "SELECT must not push the crate")
assert(rendered.entities[1].x == 7, "YOU movement remains independent")
listeners.undo()
assert(history_depth == 0 and rendered.entities[12].x == 2)
assert(initial.entities[12].direction == "None")
-- Reach the upper edge, then turn left/right while blocked by a STOP fixture
-- through the core API and ensure direction-only Commit/Undo is atomic.
local s = RW_CreateSession()
s.world.entities = {
    [1] = {id = 1, kind = "object", class = "object", x = 1, y = 1,
        direction = "Mid", traits = {you = true}},
    [2] = {id = 2, kind = "object", class = "text", x = 2, y = 1,
        direction = "Down", text = {name = "IS"}, traits = {block_entry = true}}
}
for _, action in ipairs({{type = "move", dx = -1, dy = 0},
    {type = "move", dx = 1, dy = 0}}) do
    local plan = RW_ResolveTurn(s.world, action)
    local preview = assert(RW_PreviewPlan(s.world, plan))
    local next_session, result = RW_Commit(s, plan)
    assert(result.accepted and result.changed and #next_session.history == 1)
    assert(next_session.world.entities[1].x == 1)
    assert(next_session.world.entities[1].direction == preview.entities[1].direction)
    assert(next_session.world.entities[2].direction == "Down")
    local restored = RW_Undo(next_session)
    assert(restored.world == s.world and restored.world.entities[1].direction == "Mid")
end
-- Actual host callbacks: SELECT + explicit confirmation, whole-tree Undo, all exits.
assert(listeners.confirm and type(RW_ConfirmSelectedLevel) == "function" and navigation.title:find("MAP"))
listeners.up()
assert(navigation.title:find("MAP"), "Stepping onto A must not enter")
assert(rendered.entities[12].y == 1)
listeners.confirm()
local child_a_title = navigation.title
assert(child_a_title:find("PUZZLE") and history_depth == 2)
listeners.right()
assert(rendered.entities[4].x == 4 and rendered.entities[12].x == 2)
listeners.confirm() -- SELECT on parent level block, not YOU-only contact.
assert(navigation.title:find("MAP") and rendered.entities[4].x == 3)
listeners.undo()
assert(navigation.title == child_a_title and rendered.entities[4].x == 4)
listeners.undo()
assert(navigation.title == child_a_title and rendered.entities[4].x == 3)
listeners.undo()
assert(navigation.title:find("MAP") and rendered.entities[12].y == 1)
listeners.undo()
assert(history_depth == 0 and rendered.entities[12].y == 2)
listeners.undo()
assert(history_depth == 0)
listeners.left(); listeners.confirm() -- B, same definition, distinct instance.
local child_b_title = navigation.title
assert(child_b_title:find("PUZZLE") and rendered.entities[4].x == 3)
listeners.down() -- YOU overlaps WIN; SELECT has no route down.
assert(navigation.title:find("MAP"), "WIN must return to parent")
listeners.undo()
assert(navigation.title == child_b_title and rendered.entities[1].y == 2)
listeners.right(); listeners.confirm() -- parent block
assert(navigation.title:find("MAP"))
listeners.confirm() -- Re-enter the same retained B instance.
assert(navigation.title == child_b_title and rendered.entities[4].x == 3)
while history_depth > 0 do listeners.undo() end
listeners.up(); listeners.right(); listeners.confirm() -- T
assert(navigation.title:find("PUZZLE") and rendered.entities[1].x == 9)
listeners.up() -- Completes LEVEL IS CRATE.
assert(navigation.title:find("MAP") and rendered.entities[15].archetype == "crate")
listeners.undo()
assert(navigation.title:find("PUZZLE") and rendered.entities[18].y == 9)
listeners.undo()
assert(navigation.title:find("MAP") and rendered.entities[15].archetype == "level_block")
assert(initial.entities[15].archetype == "level_block", "Earlier snapshot mutated")
print("PASS: host SELECT/confirm, parent block, win, level transform and cross-level Undo")
-- Native F callbacks and status for the five ordered LEVEL fixtures.
for column, expected in ipairs({"win","defeat","win","defeat","transform"}) do
    while history_depth > 0 do listeners.undo() end
    if column == 1 then listeners.left() end
    for _=3,column do listeners.right() end
    listeners.down(); listeners.confirm(); listeners.up()
    if expected == "defeat" then
        assert(navigation.title:find("DEFEAT") and navigation.hint:find("SELECT remains active"))
        local before_x = rendered.entities[1].x
        listeners.right()
        assert(rendered.entities[12].x == 2 and rendered.entities[1].x == before_x)
        listeners.undo()
    else
        assert(navigation.title:find("MAP"))
        if expected == "transform" then assert(rendered.entities[41].archetype == "rock") end
    end
    listeners.undo()
    assert(navigation.title:find("PUZZLE") and rendered.entities[16].y == 9)
end
print("PASS: F interaction and native status for ordered LEVEL outcomes and defeat-only Undo")
while history_depth > 0 do listeners.undo() end
for _=1,4 do listeners.right() end
listeners.down(); listeners.confirm(); listeners.up() -- N: CRATE IS LEVEL.
assert(rendered.entities[4].archetype == "level_block" and rendered.entities[5].archetype == "level_block")
local noun_title = navigation.title
listeners.down(); listeners.right(); listeners.right(); listeners.confirm()
assert(navigation.title ~= noun_title and navigation.title:find("PUZZLE"))
listeners.right(); listeners.confirm() -- Nested parent block returns to N.
assert(navigation.title == noun_title)
assert(rendered.entities[4].archetype == "crate" and rendered.entities[5].archetype == "crate")
print("PASS: F enters the configured converted ID; return reloads ordinary conversions")
while history_depth > 0 do listeners.undo() end
for _=1,5 do listeners.right() end
listeners.down()
local choice_depth = history_depth
listeners.confirm()
assert(navigation.choice and #navigation.choice.items == 2 and history_depth == choice_depth)
local cursor_y = rendered.entities[12].y
listeners.down()
assert(navigation.choice.index == 2 and rendered.entities[12].y == cursor_y and history_depth == choice_depth)
listeners.undo()
assert(not navigation.choice and history_depth == choice_depth)
listeners.confirm(); listeners.confirm() -- First overlapping block: LEVEL IS YOU fixture.
assert(rendered.entities[1].x == 4 and not navigation.choice)
listeners.up(); listeners.right()
assert(rendered.board_offset.x == 1 and rendered.board_offset.direction == "Right")
listeners.undo()
assert(not rendered.board_offset or rendered.board_offset.x == 0)
listeners.undo(); listeners.undo()
listeners.confirm()
assert(navigation.choice)
assert(not RW_ChooseSelectedLevel(999) and navigation.choice)
assert(RW_ChooseSelectedLevel(44)) -- Click/API choice of second overlapping block.
assert(not navigation.choice and rendered.entities[1].x == 2)
print("PASS: modal choice open/cycle/cancel/explicit target and LEVEL IS YOU scroll/Undo")
while history_depth > 0 do listeners.undo() end
listeners.right(); listeners.right(); listeners.up(); listeners.confirm() -- DF
local df_depth=history_depth
listeners.right()
assert(not rendered.entities[1] and rendered.entities[15].archetype == "skull")
assert(navigation.title:find("PUZZLE") and not navigation.title:find("DEFEAT"))
listeners.confirm() -- SELECT remains able to return after the last YOU dies.
assert(navigation.title:find("MAP"))
listeners.undo()
assert(navigation.title:find("PUZZLE") and not rendered.entities[1])
listeners.undo()
assert(rendered.entities[1].x == 2 and history_depth == df_depth)
while history_depth > 0 do listeners.undo() end
for _=1,3 do listeners.right() end
listeners.up(); listeners.confirm(); listeners.right() -- SK
assert(rendered.entities[1].x == 3 and not rendered.entities[4] and not rendered.entities[15])
listeners.undo()
assert(rendered.entities[4].x == 3 and rendered.entities[15].archetype == "water")
while history_depth > 0 do listeners.undo() end
listeners.right(); listeners.right(); listeners.confirm() -- HAS
local frontier=rendered.next_entity_id
listeners.right()
assert(not rendered.entities[4] and not rendered.entities[15] and rendered.next_entity_id == frontier+2)
assert(rendered.entities[frontier].archetype == "rock" and rendered.entities[frontier+1].behaviors.control)
listeners.right()
assert(rendered.entities[frontier].x == 5 and rendered.entities[frontier+1].x == 5)
listeners.undo(); listeners.undo()
assert(rendered.entities[4].x == 3 and rendered.entities[15] and rendered.next_entity_id == frontier)
assert(not rendered.entities[frontier])
print("PASS: native F fixtures DEFEAT/SINK/HAS, new YOU control, last-YOU death/SELECT return and whole-tree Undo")
while history_depth > 0 do listeners.undo() end
listeners.left(); listeners.up(); listeners.confirm() -- TXT sandbox.
assert(rendered.entities[1].x == 6 and rendered.entities[1].y == 8)
assert(rendered.entities[2].text.name == "ROCK" and rendered.entities[7].text.name == "NOT")
listeners.up(); listeners.up()
assert(rendered.entities[3].class == "object" and rendered.entities[3].behaviors.word)
for _=1,3 do listeners.right() end
listeners.down(); listeners.left(); listeners.left(); listeners.down(); listeners.left()
listeners.up(); listeners.up()
assert(rendered.entities[3].class == "text" and rendered.entities[3].text.name == "ROCK")
assert(rendered.entities[3].behaviors.push and not rendered.entities[3].archetype)
listeners.undo()
assert(rendered.entities[3].class == "object" and rendered.entities[3].behaviors.word)
print("PASS: native TXT sandbox WORD activation, pushed IS TEXT class conversion and whole-tree Undo")
-- Drive the real host into an Infinite Loop, including a SELECT still present.
while history_depth > 0 do listeners.undo() end
for _=1,3 do listeners.right() end
listeners.confirm()
assert(rendered.entities[1].x == 4 and rendered.entities[7].y == 3)
listeners.up()
assert(rendered.infinite_loop and rendered.entities[7].y == 2 and navigation.title:find("INFINITE LOOP"))
local loop_depth=history_depth
listeners.right();listeners.confirm();listeners.up()
assert(history_depth == loop_depth and rendered.infinite_loop and rendered.entities[1].y == 3)
listeners.undo()
assert(not rendered.infinite_loop and rendered.entities[7].y == 3 and history_depth == loop_depth-1)
listeners.up()
assert(rendered.infinite_loop and history_depth == loop_depth)
listeners.undo()
print("PASS: native Infinite Loop board/status, SELECT/F/movement lock, whole-tree Undo and replay")
while history_depth > 0 do listeners.undo() end
listeners.right();listeners.confirm()
assert(rendered.entities[24].archetype == "cursor" and rendered.entities[1].x == 6 and rendered.entities[1].y == 11)
assert(rendered.entities[1].behaviors.control and rendered.entities[3].behaviors.push)
print("PASS: native NAT entry and independent freely movable actors")
while history_depth > 0 do listeners.undo() end
for _=1,4 do listeners.right() end
listeners.confirm() -- TC: no rule at entry, W completes the stacked sentence.
assert(not rendered.too_complex and rendered.entities[1].y == 8)
listeners.up()
assert(rendered.too_complex and not rendered.infinite_loop and navigation.title:find("TOO COMPLEX"))
local complex_depth=history_depth
listeners.confirm();listeners.right();listeners.up()
assert(history_depth == complex_depth and rendered.entities[1].y == 7)
listeners.undo()
assert(not rendered.too_complex and rendered.entities[1].y == 8 and history_depth == complex_depth-1)
print("PASS: native Too Complex triggering move/status, SELECT/F/movement lock and whole-tree Undo")
while history_depth > 0 do listeners.undo() end
for _=1,5 do listeners.right() end
listeners.up();listeners.right();listeners.confirm() -- COND
assert(not rendered.entities[2].behaviors.word and rendered.entities[5].behaviors.word)
assert(rendered.entities[3].behaviors.safe and rendered.entities[4].behaviors.safe)
listeners.up()
assert(rendered.entities[2].y == 3 and rendered.entities[2].behaviors.word)
listeners.up()
assert(rendered.entities[2].y == 2 and not rendered.entities[2].behaviors.word)
listeners.undo()
assert(rendered.entities[2].y == 3 and rendered.entities[2].behaviors.word)
listeners.undo()
assert(rendered.entities[2].y == 4 and not rendered.entities[2].behaviors.word)
print("PASS: native COND ON WORD activation/retraction, NEAR and subject AND, whole-tree Undo")
while history_depth > 0 do listeners.undo() end
for _=1,5 do listeners.right() end
listeners.up();listeners.right();listeners.right();listeners.confirm() -- MELT
assert(rendered.entities[1].y==5 and rendered.entities[2].behaviors.hot)
local melt_frontier=rendered.next_entity_id
listeners.up()
assert(not rendered.entities[1] and rendered.entities[2].y==4)
assert(rendered.entities[melt_frontier].archetype=="crate" and rendered.entities[melt_frontier].y==4
    and rendered.entities[melt_frontier].direction=="Up")
listeners.undo()
assert(rendered.entities[1].y==5 and not rendered.entities[melt_frontier] and rendered.next_entity_id==melt_frontier)
print("PASS: native MELT contact, retained HOT source, HAS crate, allocator/direction and whole-tree Undo")
while history_depth > 0 do listeners.undo() end
for _=1,5 do listeners.right() end
listeners.up();listeners.right();listeners.right();listeners.right();listeners.confirm()
assert(rendered.entities[1].behaviors.open and rendered.entities[2].behaviors.shut)
local unlock_frontier=rendered.next_entity_id
listeners.up()
assert(not rendered.entities[1] and not rendered.entities[2])
assert(rendered.entities[unlock_frontier].archetype=="flag" and rendered.entities[unlock_frontier].y==4)
assert(rendered.entities[unlock_frontier+1].archetype=="crate" and rendered.entities[unlock_frontier+1].y==5
    and rendered.entities[unlock_frontier+1].direction=="Up")
listeners.undo()
assert(rendered.entities[1].y==5 and rendered.entities[2].y==4 and rendered.next_entity_id==unlock_frontier)
print("PASS: native LOCK entry, movement unlock, source/destination HAS, directions and whole-tree Undo")
while history_depth > 0 do listeners.undo() end
for _=1,5 do listeners.right() end
listeners.up();for _=1,4 do listeners.right() end;listeners.confirm()
assert(rendered.entities[1].behaviors.weak and rendered.entities[6].behaviors.push)
local weak_frontier=rendered.next_entity_id
listeners.up()
assert(not rendered.entities[1] and rendered.entities[weak_frontier].archetype=="crate"
    and rendered.entities[weak_frontier].y==5 and rendered.entities[weak_frontier].direction=="Up")
listeners.undo()
assert(rendered.entities[1].y==5 and rendered.next_entity_id==weak_frontier)
listeners.right();listeners.right()
assert(rendered.entities[1].x==6 and not rendered.entities[6] and rendered.entities[7].x==7)
listeners.undo();listeners.undo()
assert(rendered.entities[1].x==4 and rendered.entities[6].x==6)
print("PASS: native WEAK entry, blocked YOU/HAS, blocked PUSH break and whole-tree Undo")
while history_depth > 0 do listeners.undo() end
for _=1,5 do listeners.right() end
listeners.up();for _=1,5 do listeners.right() end;listeners.confirm()
assert(rendered.entities[1].behaviors.float and rendered.entities[1].behaviors.melt)
listeners.up()
assert(rendered.entities[1].y==4 and rendered.entities[2].y==4)
listeners.undo();listeners.right()
assert(rendered.entities[1].x==4 and rendered.entities[6].x==5)
listeners.undo();listeners.left()
assert(rendered.entities[1].x==3 and rendered.entities[7].x==2)
listeners.undo()
assert(rendered.entities[1].x==4 and rendered.entities[7].x==3)
print("PASS: native FLOAT entry, cross-layer HOT immunity, STOP/PUSH collisions and Undo")
while history_depth > 0 do listeners.undo() end
local function press(sequence)
 local map={D="right",A="left",W="up",S="down",F="confirm",Z="undo"}
 for key in sequence:gmatch(".") do listeners[map[key]]() end
end
press("DDDDDDDDDDFDF")
assert(rendered.width==33 and rendered.height==18)
local function avatar(world)
 for _,e in pairs(world.entities) do if e.archetype=="avatar" then return e end end
end
assert(avatar(rendered).x==13)
for _,e in pairs(rendered.entities) do if e.class=="text" then assert(rendered.active_text_ids[e.id]) end end
press("DDDDDDDD")
assert(rendered.width==12 and rendered.entities[2].level_link.label=="BIY")
press("Z");assert(rendered.width==33 and avatar(rendered).x==20)
press("D");assert(rendered.width==12)
-- Enter WHERE from the restored reference map cursor (3,2).
press("DF");assert(rendered.width==24 and avatar(rendered).x==15)
press("AAA")
for _,e in pairs(rendered.entities) do if e.archetype=="wall" then assert(not e.behaviors.block_entry) end end
local inactive=0
for _,e in pairs(rendered.entities) do if e.class=="text" and not rendered.active_text_ids[e.id] then inactive=inactive+1 end end
assert(inactive>=6)
press("Z")
for _,e in pairs(rendered.entities) do if e.text and e.text.name=="STOP" then assert(rendered.active_text_ids[e.id]) end end
press("A")
press("DWWWWWWWWWWASSDSAAA")
press("SSSAAWWDDDDDDDDWAAAAASSD")
assert(rendered.width==12 and rendered.entities[3].level_link.label=="WHERE")
press("Z");assert(rendered.width==24 and avatar(rendered).x==11)
print("PASS: official BIY and WHERE solutions, boundary WIN/Undo, rule break/rebuild and activation")
while history_depth>0 do listeners.undo() end
press("DDDDDDDDDDFDDDF")
assert(rendered.width==24 and rendered.height==18 and avatar(rendered).x==15 and avatar(rendered).y==15)
assert(avatar(rendered).behaviors.control and avatar(rendered).behaviors.push)
local source
for _,e in pairs(rendered.entities) do if e.archetype=="belt" and e.x==16 and e.y==11 then source=e end end
assert(source and source.behaviors.shift and source.direction=="Up")
press("DWWWW")
assert(avatar(rendered).x==16 and avatar(rendered).y==10 and avatar(rendered).direction=="Up")
press("Z")
assert(avatar(rendered).x==16 and avatar(rendered).y==12)
press("W")
assert(avatar(rendered).y==10)
local before_wait=history_depth
listeners.wait()
assert(avatar(rendered).y==10 and history_depth==before_wait+1)
press("Z")
assert(avatar(rendered).y==10 and history_depth==before_wait)
print("PASS: official Chasm Automated Doors imports WORD/NOT/AND, belt SHIFT, wait binding and atomic Undo")
while history_depth>0 do listeners.undo() end
press("DDDDDDDDDDFDDDDF")
assert(rendered.width==24 and avatar(rendered).x==7 and avatar(rendered).y==7)
assert(rendered.language.properties.MORE=="more")
local traps=assert(RW_CompileWorld(rendered,{read=RW_ReadLines,parse=RW_ParseRuleAST,
 lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}))
assert(#traps.deferred==0)
press("SSSSSSS")
assert(avatar(rendered).x==8 and avatar(rendered).y==14)
press("Z");assert(avatar(rendered).x==7 and avatar(rendered).y==13)
for _=1,6 do listeners.undo() end
assert(avatar(rendered).x==7 and avatar(rendered).y==7)
press("DDSSD")
assert(not avatar(rendered))
press("Z");assert(avatar(rendered).x==9 and avatar(rendered).y==9)
print("PASS: official Meta Booby Trap vocabulary, NEAR EMPTY conversion, belt traversal and whole-tree Undo")
print("PASS: bootstrap pipelines, directional PUSH, blocked turns, and Undo")
dofile("tests/scheduler.lua")
dofile("tests/lifecycle.lua")
dofile("tests/registration.lua")
dofile("tests/selectors_behaviors.lua")

dofile("tests/levels.lua")

dofile("tests/level_tree.lua")

dofile("tests/level_transactions.lua")

dofile("tests/level_semantics.lua")

dofile("tests/navigation_view.lua")

dofile("tests/level_boundaries.lua")

dofile("tests/conversion_split.lua")

dofile("tests/rule_multiplicity.lua")

dofile("tests/stage_transactions.lua")

dofile("tests/contact_words.lua")

dofile("tests/text_word.lua")

dofile("tests/special_nouns.lua")

dofile("tests/terminal_words.lua")
dofile("tests/spatial_words.lua")
dofile("tests/hot_melt.lua")

dofile("tests/open_shut.lua")

dofile("tests/weak.lua")

dofile("tests/float.lua")

dofile("tests/text_activation.lua")

dofile("tests/shift.lua")

dofile("tests/more.lua")

dofile("tests/tele.lua")
dofile("tests/boom.lua")
dofile("tests/hold.lua")
dofile("tests/colours.lua")
dofile("tests/motion_words.lua")
dofile("tests/pull_swap.lua")
dofile("tests/fall_words.lua")
dofile("tests/reverse.lua")
dofile("tests/fear.lua")
dofile("tests/follow.lua")
dofile("tests/make.lua")
dofile("tests/eat.lua")
dofile("tests/become.lua")
dofile("tests/mimic.lua")
dofile("tests/play.lua")
dofile("tests/spatial_extra.lua")
dofile("tests/without.lua")
dofile("tests/facedby.lua")
dofile("tests/seeing.lua")
dofile("tests/feeling.lua")
dofile("tests/powered.lua")
dofile("tests/groups.lua")
dofile("tests/level_text.lua")

dofile("tests/broken_status.lua")
dofile("tests/broken_rules.lua")
dofile("tests/broken_turn.lua")
dofile("tests/broken_code.lua")
dofile("tests/broken_births.lua")
dofile("tests/broken_conversions.lua")
dofile("tests/reference_broken_conversions.lua")
dofile("tests/broken_boundaries.lua")
dofile("tests/broken_contacts.lua")
dofile("tests/broken_empty.lua")
dofile("tests/broken_level.lua")
dofile("tests/broken_creation_limits.lua")
dofile("tests/broken_has_limits.lua")
dofile("tests/broken_conversion_limits.lua")
dofile("tests/broken_integration.lua")
dofile("tests/you2.lua")

dofile("tests/chill.lua")

dofile("tests/presentation_words.lua")

dofile("tests/bonus.lua")

dofile("tests/done.lua")

dofile("tests/end.lua")

dofile("tests/auto.lua")
