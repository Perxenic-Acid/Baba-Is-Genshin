-- world.lua
-- RuleWorld M1: Pure state transitions and history

local HISTORY_LIMIT = 128

-- Deep copy, supporting nested tables and cycles.
local function clone(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local result = {}
    seen[value] = result

    for k, v in pairs(value) do
        result[clone(k, seen)] = clone(v, seen)
    end

    return result
end

local function create_world()
    return {
        width = 5,
        height = 5,
        entities = {
            [1] = {
                id = 1,
                kind = "object",
                x = 2,
                y = 2
            },
            [2] = {
                id = 2,
                kind = "object",
                x = 3,
                y = 3
            }
        }
    }
end

local function rejected(reason)
    return {
        accepted = false,
        reason = reason,
        changes = {}
    }
end

-- A blocked movement still consumes a turn.
local function blocked(reason)
    return {
        accepted = true,
        changed = false,
        reason = reason,
        changes = {}
    }
end

-- Query the environment at a position.
local function get_environment(world, x, y)
    if x < 1 or x > world.width
        or y < 1 or y > world.height then
        return "edge"
    end

    return "floor"
end

-- Resolve whether an entity can enter a position.
local function can_enter(world, entity, x, y)
    local environment = get_environment(world, x, y)

    if environment == "edge" then
        return false, "blocked_by_edge"
    end

    return true
end

-- Pure transition: (World, Action) -> (World, Result)
local function transition(world, action)
    if type(action) ~= "table"
        or action.type ~= "move" then
        return world, rejected("invalid_action")
    end

    local id = action.entity_id
    local dx, dy = action.dx, action.dy

    -- For this prototype, movement is cardinal only.
    if not (
            (dx == 1 or dx == -1) and dy == 0
            or dx == 0 and (dy == 1 or dy == -1)
        ) then
        return world, rejected("invalid_direction")
    end

    local entity = world.entities[id]
    if not entity then
        return world, rejected("unknown_entity")
    end

    local nx = entity.x + dx
    local ny = entity.y + dy

    local allowed, reason = can_enter(world, entity, nx, ny)

    if not allowed then
        return world, blocked(reason)
    end

    -- The input world remains untouched.
    local next_world = clone(world)
    next_world.entities[id].x = nx
    next_world.entities[id].y = ny

    return next_world, {
        accepted = true,
        changed = true,
        changes = { {
            entity_id = id,
            from = { x = entity.x, y = entity.y },
            to = { x = nx, y = ny }
        } }
    }
end

-- Public API --------------------------------

function RW_CreateSession()
    return {
        world = create_world(),
        history = {}
    }
end

function RW_Step(session, action)
    local next_world, result =
        transition(session.world, action)

    if not result.accepted then
        return session, result
    end

    -- Copy the history array, not the old worlds.
    -- Old world snapshots are never mutated internally.
    local history = {}

    for i = 1, #session.history do
        history[i] = session.history[i]
    end

    if #history >= HISTORY_LIMIT then
        table.remove(history, 1)
    end

    history[#history + 1] = session.world

    return {
        world = next_world,
        history = history
    }, result
end

function RW_Undo(session)
    local n = #session.history

    if n == 0 then
        return session, rejected("empty_history")
    end

    local previous_world = session.history[n]
    local history = {}

    for i = 1, n - 1 do
        history[i] = session.history[i]
    end

    return {
        world = previous_world,
        history = history
    }, {
        accepted = true,
        reason = "undo",
        changes = {}
    }
end

-- In-game invariant tests -------------------

function RW_SelfTest()
    local function move_right(session)
        return RW_Step(session, {
            type = "move",
            entity_id = 1,
            dx = 1,
            dy = 0
        })
    end

    local s0 = RW_CreateSession()
    local s1, r1 = move_right(s0)

    if not r1.accepted then
        return false, "Initial move rejected"
    end

    if s0.world.entities[1].x ~= 2 then
        return false, "Original world mutated"
    end

    if s1.world.entities[1].x ~= 3 then
        return false, "New world incorrect"
    end

    local s2, r2 = RW_Undo(s1)

    if not r2.accepted
        or s2.world.entities[1].x ~= 2
        or #s2.history ~= 0 then
        return false, "Undo incorrect"
    end

    
    -- Test: Reach the right boundary.
    local edge = RW_CreateSession()

    for i = 1, 3 do
        local result
        edge, result = move_right(edge)

        if not result.accepted or not result.changed then
            return false, "Failed to reach boundary"
        end
    end

    if edge.world.entities[1].x ~= 5
        or #edge.history ~= 3 then
        return false, "Boundary setup incorrect"
    end

    -- Test: Blocked movements consume turns.
    local b1, rb1 = move_right(edge)
    local b2, rb2 = move_right(b1)

    if not rb1.accepted or rb1.changed ~= false
        or not rb2.accepted or rb2.changed ~= false then
        return false, "Blocked turn semantics incorrect"
    end

    if rb1.reason ~= "blocked_by_edge"
        or rb2.reason ~= "blocked_by_edge" then
        return false, "Unexpected blocking reason"
    end

    if b1.world.entities[1].x ~= 5
        or b2.world.entities[1].x ~= 5
        or #b1.history ~= 4
        or #b2.history ~= 5 then
        return false, "Blocked turns not recorded"
    end

    -- Test: Undo two blocked turns.
    local u1, ru1 = RW_Undo(b2)
    local u2, ru2 = RW_Undo(u1)

    if not ru1.accepted or not ru2.accepted
        or u1.world.entities[1].x ~= 5
        or u2.world.entities[1].x ~= 5
        or #u1.history ~= 4
        or #u2.history ~= 3 then
        return false, "Blocked turn undo failed"
    end

    -- Test: Undo the preceding movement.
    local u3, ru3 = RW_Undo(u2)

    if not ru3.accepted
        or u3.world.entities[1].x ~= 4
        or #u3.history ~= 2 then
        return false, "Movement undo failed"
    end

    -- Test: Invalid actions do not consume turns.
    local invalid, ri = RW_Step(u3, {
        type = "move",
        entity_id = 1,
        dx = 2,
        dy = 0
    })

    if ri.accepted
        or invalid ~= u3
        or #invalid.history ~= 2 then
        return false, "Invalid action consumed a turn"
    end

    return true, "All M1 invariants passed"

end
