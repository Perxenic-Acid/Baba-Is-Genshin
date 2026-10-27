
-- movement.lua
-- RuleWorld M2: Movement intentions and constraints

-- Projected capability sets are authoritative for movement. Raw trait fixtures
-- retain a default-only compatibility path; custom registries require projection.
local function has_capability(world, entity, capability)
    if entity.behaviors ~= nil then
        return type(entity.behaviors) == "table" and entity.behaviors[capability] == true
    end
    if world.behavior_registry ~= nil then return false end
    local legacy = {control = "you", push = "pushable", block_entry = "block_entry"}
    return entity.traits and entity.traits[legacy[capability]] == true
end

local function direction_for(dx, dy)
    if dx == -1 then return "Left" end
    if dx == 1 then return "Right" end
    if dy == -1 then return "Up" end
    return "Down"
end

function RW_DirectionMovementSelfTest()
    for _, vector in ipairs({{-1, 0, "Left"}, {0, -1, "Up"},
        {1, 0, "Right"}, {0, 1, "Down"}}) do
        local dx, dy, direction = vector[1], vector[2], vector[3]
        local world = {width = 7, height = 7, entities = {
            [1] = {id = 1, x = 4, y = 4, direction = "Mid", traits = {you = true}},
            [2] = {id = 2, x = 4 + dx, y = 4 + dy, direction = "None",
                class = "text", traits = {pushable = true}},
            [3] = {id = 3, x = 4 + 2*dx, y = 4 + 2*dy, direction = "Left",
                traits = {pushable = true, you = true}},
            [4] = {id = 4, x = 1, y = 1, direction = "Up", traits = {}}
        }}
        local action = {type = "move", dx = dx, dy = dy}
        local plan = RW_ResolveTurn(world, action)
        if #plan.changes ~= 3 then return false, "Directional push count failed" end
        for _, change in ipairs(plan.changes) do
            local source = world.entities[change.entity_id]
            if change.kind ~= "move" or change.to.direction ~= direction
                or change.from.direction ~= source.direction
                or change.to.x ~= source.x + dx or change.to.y ~= source.y + dy then
                return false, "Push participants did not face movement direction"
            end
        end
        if world.entities[1].direction ~= "Mid" or world.entities[2].direction ~= "None" then
            return false, "Direction planning mutated source"
        end
        -- STOP behind the chain: both YOU turn, passive PUSH retains direction.
        world.entities[5] = {id = 5, x = 4 + 3*dx, y = 4 + 3*dy,
            direction = "None", traits = {block_entry = true}}
        local stopped = RW_ResolveTurn(world, action)
        local count = 0
        for _, change in ipairs(stopped.changes) do
            if change.kind ~= "direction" or change.to ~= direction
                or (change.entity_id ~= 1 and change.entity_id ~= 3) then
                return false, "Blocked push leaked movement or passive direction"
            end
            count = count + 1
        end
        if count ~= (direction == "Left" and 1 or 2)
            or stopped.reason ~= "all_blocked" then
            return false, "Blocked YOU direction failed"
        end
        -- EDGE blocks a lone YOU, which still faces the requested direction.
        world.entities = {[1] = {id = 1,
            x = dx == -1 and 1 or (dx == 1 and 7 or 4),
            y = dy == -1 and 1 or (dy == 1 and 7 or 4),
            direction = "Mid", traits = {you = true}}}
        local edge = RW_ResolveTurn(world, action)
        if edge.reason ~= "blocked_by_edge" or #edge.changes ~= 1
            or edge.changes[1].kind ~= "direction" or edge.changes[1].to ~= direction then
            return false, "EDGE direction failed"
        end
        world.entities[1].direction = direction
        if #RW_ResolveTurn(world, action).changes ~= 0 then
            return false, "Repeated blocked direction generated redundant write"
        end
    end
    return true, "Direction movement, blocking and PUSH passed"
end

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

                if has_capability(world, other, "push") then
                    -- Push takes priority over STOP-like blocking.
                    local ok, reason = try_move(other_id)

                    if not ok then
                        visiting[id] = nil
                        return false, reason
                    end

                elseif has_capability(world, other, "block_entry") then
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
                y = entity.y,
                direction = entity.direction or "None"
            },
            to = {
                x = nx,
                y = ny,
                direction = direction_for(dx, dy)
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



-- M9.2: Resolve all YOU entities within a single turn.
-- Order: front-to-back along the movement direction.
-- Produce one atomic plan relative to the input world.

function RW_ResolveTurn(world, action)
    if type(world) ~= "table"
        or type(world.entities) ~= "table" then
        return invalid("invalid_world")
    end

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

    -- Capture all controllers at the beginning of turn.
    local controllers = {}

    for id, entity in pairs(world.entities) do
        if has_capability(world, entity, "control") then
            controllers[#controllers + 1] = id
        end
    end

    if #controllers == 0 then
        return blocked("no_you")
    end

    -- Front-to-back. Tie-break by entity ID.
    table.sort(controllers, function(a, b)
        local ea = world.entities[a]
        local eb = world.entities[b]

        local pa = ea.x * dx + ea.y * dy
        local pb = eb.x * dx + eb.y * dy

        if pa == pb then
            return a < b
        end

        return pa > pb
    end)

    -- Copy top-level world fields and entity records.
    -- Nested trait tables remain shared but read-only.
    local working = {}

    for k, v in pairs(world) do
        working[k] = v
    end

    working.entities = {}

    for id, entity in pairs(world.entities) do
        local copy = {}

        for k, v in pairs(entity) do
            copy[k] = v
        end

        working.entities[id] = copy
    end

    -- Track entities moved by any previous sub-plan.
    -- A pushed YOU must not receive a second step.
    local displaced = {}
    local blocked_count = 0
    local last_block_reason = nil

    for _, id in ipairs(controllers) do
        if not displaced[id] then
            local part = RW_ResolveMovement(
                working,
                {
                    type = "move",
                    entity_id = id,
                    dx = dx,
                    dy = dy
                }
            )

            if not part or not part.consumes_turn then
                return invalid(
                    part and part.reason
                    or "subplan_failed"
                )
            end

            if #part.changes == 0 then
                blocked_count = blocked_count + 1
                last_block_reason = part.reason
                working.entities[id].direction = direction_for(dx, dy)
            else
                -- Update only the temporary world.
                for _, change in ipairs(part.changes) do
                    local entity =
                        working.entities[change.entity_id]

                    entity.x = change.to.x
                    entity.y = change.to.y
                    entity.direction = change.to.direction

                    displaced[change.entity_id] = true
                end
            end
        end
    end

    -- Build one plan against ORIGINAL positions.
    -- Each entity occurs at most once.
    local ids = {}

    for id in pairs(world.entities) do
        ids[#ids + 1] = id
    end

    table.sort(ids)

    local changes = {}

    for _, id in ipairs(ids) do
        local before = world.entities[id]
        local after = working.entities[id]

        if before.x ~= after.x
            or before.y ~= after.y then

            changes[#changes + 1] = {
                kind = "move",
                entity_id = id,

                from = {
                    x = before.x,
                    y = before.y,
                    direction = before.direction or "None"
                },

                to = {
                    x = after.x,
                    y = after.y,
                    direction = after.direction
                }
            }
        elseif (before.direction or "None") ~= (after.direction or "None") then
            changes[#changes + 1] = {
                kind = "direction", entity_id = id,
                from = before.direction or "None", to = after.direction
            }
        end
    end

    local reason = nil

    if blocked_count == #controllers then
        if #controllers == 1 then
            reason = last_block_reason or "blocked"
        else
            reason = "all_blocked"
        end
    end

    return {
        consumes_turn = true,
        reason = reason,
        changes = changes
    }
end




function RW_ControlSelfTest()
    local function move_right(world)
        return RW_ResolveTurn(world, {
            type = "move",
            dx = 1,
            dy = 0
        })
    end

    local function moved_to(plan, id, x, y)
        for _, change in ipairs(plan.changes) do
            if change.kind == "move" and change.entity_id == id then
                return change.to.x == x
                    and change.to.y == y
            end
        end

        return false
    end

    local world = {
        width = 5,
        height = 4,
        entities = {
            [1] = {
                id = 1, x = 2, y = 2,
                traits = { you = true }
            },
            [2] = {
                id = 2, x = 4, y = 2,
                traits = { you = true }
            }
        }
    }

    -- Two YOU entities, one turn, two operations.
    local both = move_right(world)

    if not both.consumes_turn
        or #both.changes ~= 2
        or not moved_to(both, 1, 3, 2)
        or not moved_to(both, 2, 5, 2) then
        return false, "Multiple YOU movement failed"
    end

    -- No mutation of the original state.
    if world.entities[1].x ~= 2
        or world.entities[2].x ~= 4 then
        return false, "Resolver mutated original world"
    end

    -- One YOU blocked by EDGE, another moves.
    world.entities[2].x = 5

    local partial = move_right(world)

    if not partial.consumes_turn
        or #partial.changes ~= 2
        or not moved_to(partial, 1, 3, 2) then
        return false, "Partial movement failed"
    end

    -- Two adjacent YOU entities.
    -- The front object has STOP-like blocking.
    world.entities[1].x = 2
    world.entities[2].x = 3
    world.entities[2].traits = {
        you = true,
        block_entry = true
    }

    local adjacent = move_right(world)

    if #adjacent.changes ~= 2
        or not moved_to(adjacent, 1, 3, 2)
        or not moved_to(adjacent, 2, 4, 2) then
        return false, "Front-to-back ordering failed"
    end

    -- Transfer control exclusively to #2.
    world.entities[1].traits = {}
    world.entities[2].x = 4

    local transferred = move_right(world)

    if #transferred.changes ~= 1
        or not moved_to(transferred, 2, 5, 2) then
        return false, "Control transfer failed"
    end

    -- No YOU remains: empty turn is recorded.
    world.entities[2].traits = {}

    local nobody = move_right(world)

    if not nobody.consumes_turn
        or #nobody.changes ~= 0
        or nobody.reason ~= "no_you" then
        return false, "No YOU semantics failed"
    end

    -- Invalid directions are not valid turns.
    local invalid_plan = RW_ResolveTurn(world, {
        type = "move",
        dx = 2,
        dy = 0
    })

    if invalid_plan.consumes_turn then
        return false, "Invalid direction consumed turn"
    end

    return true, "Multiple YOU control passed"
end
