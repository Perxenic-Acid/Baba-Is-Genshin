
-- movement.lua
-- RuleWorld M2: Movement intentions and constraints

local function invalid(reason)
    return {
        consumes_turn = false,
        reason = reason,
        changes = {}
    }
end

local function blocked(reason)
    return {
        consumes_turn = true,
        reason = reason,
        changes = {}
    }
end

-- Environment query.
-- EDGE is a special environment, not a normal entity.
local function get_environment(world, x, y)
    if x < 1 or x > world.width
        or y < 1 or y > world.height then
        return "edge"
    end

    return "floor"
end

-- A simple constraint resolver.
local function resolve_entry(world, mover, x, y)
    local environment =
        get_environment(world, x, y)

    if environment == "edge" then
        return false, "blocked_by_edge"
    end

    for id, entity in pairs(world.entities) do
        if id ~= mover.id
            and entity.x == x
            and entity.y == y
            and entity.traits
            and entity.traits.block_entry then
            return false, "blocked_by_entity"
        end
    end

    return true
end

-- Public resolver.
function RW_ResolveMovement(world, action)
    if type(action) ~= "table"
        or action.type ~= "move" then
        return invalid("invalid_action")
    end

    local dx, dy = action.dx, action.dy

    if not (
        ((dx == 1 or dx == -1) and dy == 0)
        or (dx == 0 and (dy == 1 or dy == -1))
    ) then
        return invalid("invalid_direction")
    end

    local entity = world.entities[action.entity_id]

    if not entity then
        return invalid("unknown_entity")
    end

    local nx = entity.x + dx
    local ny = entity.y + dy

    local allowed, reason =
        resolve_entry(world, entity, nx, ny)

    if not allowed then
        return blocked(reason)
    end

    return {
        consumes_turn = true,
        changes = {{
            kind = "move",
            entity_id = entity.id,
            from = {
                x = entity.x,
                y = entity.y
            },
            to = {
                x = nx,
                y = ny
            }
        }}
    }
end

function RW_MovementSelfTest()
    local world = {
        width = 5,
        height = 5,
        entities = {
            [1] = { id = 1, x = 2, y = 3 },
            [2] = {
                id = 2, x = 3, y = 3,
                traits = { block_entry = true }
            },
            [3] = { id = 3, x = 2, y = 2 }
        }
    }

    local function resolve(dx, dy)
        return RW_ResolveMovement(world, {
            type = "move",
            entity_id = 1,
            dx = dx,
            dy = dy
        })
    end

    -- Entity #2 blocks entry.
    local blocked_entity = resolve(1, 0)

    if not blocked_entity.consumes_turn
        or #blocked_entity.changes ~= 0
        or blocked_entity.reason ~= "blocked_by_entity" then
        return false, "Entity constraint failed"
    end

    -- Entity #3 does not block entry.
    local overlap = resolve(0, -1)

    if not overlap.consumes_turn
        or #overlap.changes ~= 1 then
        return false, "Overlap behavior failed"
    end

    -- EDGE also blocks, without being an entity.
    world.entities[1].x = 1

    local edge = resolve(-1, 0)

    if not edge.consumes_turn
        or edge.reason ~= "blocked_by_edge"
        or #edge.changes ~= 0 then
        return false, "EDGE constraint failed"
    end

    return true, "Movement constraints passed"
end
