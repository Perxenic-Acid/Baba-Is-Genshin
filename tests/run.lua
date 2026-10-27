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
    KeyboardCraftspersonKey12Down = "undo"
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
assert(history_depth == 1)
for _, id in ipairs({1, 4, 5}) do
    assert(rendered.entities[id].direction == "Right", "Push direction missing")
    assert(rendered.entities[id].x == initial.entities[id].x + 1)
end
assert(initial.entities[1].direction == "None", "Source snapshot mutated")
listeners.undo()
assert(history_depth == 0 and rendered.entities[1].direction == "None")
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
-- Actual host callback path: independent A/B children, persistent re-entry and Z.
local root_world = rendered
assert(navigation.title:find("MAP"))
listeners.up() -- Root A at (2,1); child starts at (2,2).
assert(navigation.title:find("PUZZLE") and history_depth == 0)
local child_a_title = navigation.title
listeners.right() -- Push both crates, keep the changed child state.
assert(rendered.entities[1].x == 3 and rendered.entities[4].x == 4)
listeners.up(); listeners.left() -- Reach child OUT (2,1).
assert(navigation.title:find("MAP") and rendered.entities[1].y == 1)
listeners.down(); listeners.up() -- Re-enter A; no reset.
assert(navigation.title == child_a_title and rendered.entities[4].x == 4)
assert(history_depth == 3 and rendered.entities[1].y == 1)
listeners.undo() -- Only A: undo its exit move.
assert(navigation.title == child_a_title and rendered.entities[1].x == 3)
listeners.left() -- OUT again.
assert(navigation.title:find("MAP"))
listeners.left(); listeners.down() -- Root B at (1,2).
assert(navigation.title:find("PUZZLE") and navigation.title ~= child_a_title)
assert(history_depth == 0 and rendered.entities[4].x == 3)
listeners.undo() -- Empty child history must not return to map.
assert(navigation.title:find("PUZZLE") and history_depth == 0)
listeners.up() -- B OUT.
assert(navigation.title:find("MAP") and rendered.entities[1].x == 1)
assert(root_world.entities[1].y == 2) -- All earlier snapshots remain unchanged.
print("PASS: host portals A/B, retained child state, local Undo and empty-history boundary")
print("PASS: bootstrap pipelines, directional PUSH, blocked turns, and Undo")
dofile("tests/scheduler.lua")
dofile("tests/lifecycle.lua")
dofile("tests/registration.lua")
dofile("tests/selectors_behaviors.lua")

dofile("tests/levels.lua")

dofile("tests/level_tree.lua")

dofile("tests/navigation_view.lua")
