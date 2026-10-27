-- Run from repository root: luatex --luaonly tests/run.lua
-- Core Lua tests plus real bootstrap pipelines with only host UI/input mocked.
local modules = {"world", "reader", "grammar", "rules", "properties", "movement", "renderer"}
local scripts, listeners = {}, {}
for _, name in ipairs(modules) do
    dofile("external_lua_file/" .. name .. ".lua")
    scripts[#scripts + 1] = {path = name, alive = true,
        Invoke = function(_, method, ...) return assert(_G[method], method)(...) end}
end
local rendered, history_depth, navigation
RW_Render = function(world, depth, _, context)
    rendered, history_depth, navigation = world, depth, context
end
printerr = function(...) error(table.concat({...}, " ")) end
local keys = {
    KeyboardMoveForwardKeyDown = "up", KeyboardMoveBackwardKeyDown = "down",
    KeyboardMoveLeftKeyDown = "left", KeyboardMoveRightKeyDown = "right",
    KeyboardCraftspersonKey12Down = "undo", KeyboardInteractKeyDown = "confirm"
}
Enum = {KeyEventType = keys}
script = {object = {
    GetScripts = function() return scripts end,
    AddKeyEventListener = function(_, key, callback) listeners[key] = callback end
}}
dofile("external_lua_file/bootstrap.lua")
OnStart()
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
