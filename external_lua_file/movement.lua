
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


-- Resolve one movement intention and its dependencies.
-- No world state is mutated during planning.

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

    local mover = world.entities[action.entity_id]

    if not mover then
        return invalid("unknown_entity")
    end

    local planned = {}
    local visiting = {}
    local changes = {}

    local function try_move(id)
        -- An entity can participate only once in this plan.
        if planned[id] then
            return true
        end

        if visiting[id] then
            return false, "cyclic_dependency"
        end

        local entity = world.entities[id]
        visiting[id] = true

        local nx = entity.x + dx
        local ny = entity.y + dy

        if get_environment(world, nx, ny) == "edge" then
            visiting[id] = nil
            return false, "blocked_by_edge"
        end

        -- Gather occupants deterministically.
        local occupants = {}

        for other_id, other in pairs(world.entities) do
            if other_id ~= id
                and other.x == nx
                and other.y == ny then
                occupants[#occupants + 1] = other_id
            end
        end

        table.sort(occupants)

        for _, other_id in ipairs(occupants) do
            if not planned[other_id] then
                local other = world.entities[other_id]
                local traits = other.traits or {}

                if traits.pushable then
                    -- Push takes priority over STOP-like blocking.
                    local ok, reason = try_move(other_id)

                    if not ok then
                        visiting[id] = nil
                        return false, reason
                    end

                elseif traits.block_entry then
                    visiting[id] = nil
                    return false, "blocked_by_entity"
                end
            end
        end

        visiting[id] = nil
        planned[id] = true

        -- Append dependencies before their mover.
        changes[#changes + 1] = {
            kind = "move",
            entity_id = id,
            from = {
                x = entity.x,
                y = entity.y
            },
            to = {
                x = nx,
                y = ny
            }
        }

        return true
    end

    local ok, reason = try_move(mover.id)

    if not ok then
        return blocked(reason)
    end

    return {
        consumes_turn = true,
        changes = changes
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


    -- Test: Two-object push chain.
    local puzzle = {
        width = 5,
        height = 5,
        entities = {
            [1] = { id = 1, x = 2, y = 2 },
            [2] = {
                id = 2, x = 3, y = 2,
                traits = {
                    pushable = true,
                    block_entry = true
                }
            },
            [3] = {
                id = 3, x = 4, y = 2,
                traits = { pushable = true }
            }
        }
    }

    local function push_right()
        return RW_ResolveMovement(puzzle, {
            type = "move",
            entity_id = 1,
            dx = 1,
            dy = 0
        })
    end

    local plan = push_right()

    if not plan.consumes_turn
        or #plan.changes ~= 3 then
        return false, "Push chain planning failed"
    end

    -- The farthest object is planned first.
    if plan.changes[1].entity_id ~= 3
        or plan.changes[2].entity_id ~= 2
        or plan.changes[3].entity_id ~= 1 then
        return false, "Push dependency order incorrect"
    end

    -- Planning must not mutate the input world.
    if puzzle.entities[1].x ~= 2
        or puzzle.entities[2].x ~= 3
        or puzzle.entities[3].x ~= 4 then
        return false, "Movement resolver mutated world"
    end

    -- Simulate the post-commit positions.
    puzzle.entities[1].x = 3
    puzzle.entities[2].x = 4
    puzzle.entities[3].x = 5

    local edge_plan = push_right()

    if not edge_plan.consumes_turn
        or #edge_plan.changes ~= 0
        or edge_plan.reason ~= "blocked_by_edge" then
        return false, "Blocked push chain failed"
    end

    -- Reset positions, then add an immovable object.
    puzzle.entities[1].x = 2
    puzzle.entities[2].x = 3
    puzzle.entities[3].x = 4

    puzzle.entities[4] = {
        id = 4, x = 5, y = 2,
        traits = { block_entry = true }
    }

    local stop_plan = push_right()

    if not stop_plan.consumes_turn
        or #stop_plan.changes ~= 0
        or stop_plan.reason ~= "blocked_by_entity" then
        return false, "STOP behind PUSH chain failed"
    end


    return true, "Movement constraints passed"
end
