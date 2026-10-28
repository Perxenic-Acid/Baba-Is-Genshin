
-- movement.lua
-- RuleWorld M2: Movement intentions and constraints

-- Projected capability sets are authoritative for movement. Raw trait fixtures
-- retain a default-only compatibility path; custom registries require projection.
local function has_capability(world, entity, capability)
    if entity.behaviors ~= nil then
        return type(entity.behaviors) == "table" and entity.behaviors[capability] == true
    end
    if world.behavior_registry ~= nil then return false end
    local legacy = {control = "you", select = "select", select_path = "path",
        win = "win", push = "pushable", block_entry = "block_entry",
        open="open",shut="shut",safe="safe",weak="weak",float="float",shift="shift"}
    return entity.traits and entity.traits[legacy[capability]] == true
end

local function same_layer(world,a,b)
    return has_capability(world,a,"float")==has_capability(world,b,"float")
end

local function level_surface(world,entity)
    local level = world.language and world.language.nouns and world.language.nouns.LEVEL
    local block_type = type(level) == "table" and level.block_type or "level_block"
    return entity.level_link ~= nil or entity.archetype == block_type
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

    local planned,removed,destructions = {},{},{}
    local visiting = {}
    local changes = {}
    local function destroy(id,direction,cause)
        if removed[id] then return end
        local entity=world.entities[id]
        local frame={}
        for other_id,other in pairs(world.entities) do
            if other_id > 0 and not removed[other_id] then
                local snapshot={};for key,value in pairs(other) do snapshot[key]=value end
                frame[other_id]=snapshot
            end
        end
        local dying={};for key,value in pairs(entity) do dying[key]=value end
        dying.direction=direction or entity.direction or "None";frame[id]=dying
        removed[id]=true;planned[id]=true
        destructions[#destructions+1]={entity_id=id,x=entity.x,y=entity.y,
            direction=dying.direction,cause=cause or "unlock",frame=frame}
    end

    local function empty_at(x,y)
        for id,entity in pairs(world.entities) do
            if id > 0 and not removed[id] and entity.x == x and entity.y == y then return nil end
        end
        local cell=world.empty_cells and world.empty_cells[x .. ":" .. y]
        return cell and cell.behaviors or world.empty_behaviors
    end
    local try_move,attempt_move
    local function push_empty(x,y)
        local nx,ny=x+dx,y+dy
        if get_environment(world,nx,ny) == "edge" then return false,"blocked_by_edge" end
        local empty=empty_at(nx,ny)
        if empty and empty.push then
            local ok,err=push_empty(nx,ny); if not ok then return false,err end
        elseif empty and empty.block_entry then return false,"blocked_by_empty" end
        local occupants={}
        for id,entity in pairs(world.entities) do
            if id > 0 and not removed[id] and entity.x == nx and entity.y == ny then occupants[#occupants+1]=id end
        end
        table.sort(occupants)
        for _,id in ipairs(occupants) do
            if not planned[id] then
                if has_capability(world,world.entities[id],"push") then
                    local ok,err=try_move(id); if not ok then return false,err end
                elseif has_capability(world,world.entities[id],"block_entry") then return false,"blocked_by_entity" end
            end
        end
        return true
    end
    attempt_move=function(id)
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

        local empty=empty_at(nx,ny)
        if empty and empty.push then
            local ok,err=push_empty(nx,ny)
            if not ok then visiting[id]=nil; return false,err end
        elseif empty and empty.block_entry then
            visiting[id]=nil; return false,"blocked_by_empty"
        end
        -- Gather occupants deterministically.
        local occupants = {}

        for other_id, other in pairs(world.entities) do
            if other_id ~= id
                and not removed[other_id]
                and other.x == nx
                and other.y == ny then
                occupants[#occupants + 1] = other_id
            end
        end

        table.sort(occupants)

        local locks={}
        local partner=has_capability(world,entity,"open") and "shut"
            or has_capability(world,entity,"shut") and "open" or nil
        for _, other_id in ipairs(occupants) do
            if not planned[other_id] then
                local other = world.entities[other_id]

                if partner and id > 0 and other_id > 0 and same_layer(world,entity,other) and has_capability(world,other,partner)
                    and (not has_capability(world,entity,"safe") or not has_capability(world,other,"safe")) then
                    locks[#locks+1]=other_id -- Unlock takes precedence over PUSH/STOP.
                elseif has_capability(world, other, "push") then
                    -- Push takes priority over STOP-like blocking.
                    local ok, reason = try_move(other_id)

                    if not ok then
                        visiting[id] = nil
                        return false, reason
                    end

                elseif has_capability(world, other, "block_entry")
                    and (not has_capability(world,other,"weak") or not same_layer(world,entity,other)) then
                    visiting[id] = nil
                    return false, "blocked_by_entity"
                end
            end
        end

        for _,other_id in ipairs(locks) do
            if removed[id] then break end
            if not removed[other_id] then
                if not has_capability(world,world.entities[other_id],"safe") then destroy(other_id) end
                if not has_capability(world,entity,"safe") then destroy(id,direction_for(dx,dy)) end
            end
        end
        visiting[id] = nil
        planned[id] = true
        if removed[id] then return true end

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

    try_move=function(id)
        local entity=world.entities[id]
        if id < 1 or not has_capability(world,entity,"weak") or has_capability(world,entity,"safe") then
            return attempt_move(id)
        end
        -- A failed weak subtree shatters only its root, not speculative pushes.
        local old_planned,old_removed={},{}
        for k,v in pairs(planned) do old_planned[k]=v end
        for k,v in pairs(removed) do old_removed[k]=v end
        local change_count,death_count=#changes,#destructions
        local ok,reason=attempt_move(id)
        if ok then return true end
        planned,removed=old_planned,old_removed;visiting[id]=nil
        while #changes>change_count do table.remove(changes) end
        while #destructions>death_count do table.remove(destructions) end
        destroy(id,direction_for(dx,dy),"weak")
        return true
    end

    local ok, reason = try_move(mover.id)

    if not ok then
        return blocked(reason)
    end

    return {
        consumes_turn = true,
        changes = changes,
        destructions=destructions
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

local function resolve_you_turn(world, action)
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
    local displaced,death_records,death_order = {},{},{}
    local blocked_count = 0
    local last_block_reason = nil

    for _, id in ipairs(controllers) do
        if not displaced[id] and working.entities[id] then
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

            if #part.changes == 0 and #(part.destructions or {}) == 0 then
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
                for _,death in ipairs(part.destructions or {}) do
                    death_records[death.entity_id]=death;death_order[#death_order+1]=death
                    working.entities[death.entity_id]=nil;displaced[death.entity_id]=true
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
        if not after then
            local death=death_records[id]
            after={x=death.x,y=death.y,direction=death.direction}
        end

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
        changes = changes,
        destructions=death_order
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

-- SHIFT snapshots its riders after YOU, then applies each collected impulse.
-- Movement and deaths still use the ordinary collision solver and death frames.
function RW_ResolveShift(world)
    local working={};for k,v in pairs(world) do working[k]=v end
    working.entities={}
    local ids={}
    for id,e in pairs(world.entities) do
        local copy={};for k,v in pairs(e) do copy[k]=v end
        working.entities[id]=copy;ids[#ids+1]=id
    end
    table.sort(ids)
    local vectors={Left={-1,0},Up={0,-1},Right={1,0},Down={0,1}}
    local tasks,order={},{}
    for _,id in ipairs(ids) do
        local belt=world.entities[id]
        if has_capability(world,belt,"shift") and vectors[belt.direction] then
            for _,other_id in ipairs(ids) do
                local rider=world.entities[other_id]
                if other_id ~= id and rider.x==belt.x and rider.y==belt.y and same_layer(world,belt,rider) then
                    if not tasks[other_id] then
                        tasks[other_id]={direction=belt.direction,count=0};order[#order+1]=other_id
                    end
                    tasks[other_id].count=tasks[other_id].count+1
                end
            end
        end
    end
    local deaths,records={},{}
    local rounds=0;for _,task in pairs(tasks) do rounds=math.max(rounds,task.count) end
    for impulse=1,rounds do
        -- Resolve one impulse for every rider before applying queued updates.
        -- Converging Text must be allowed to land on the same formerly empty cell.
        local queued={}
        for _,id in ipairs(order) do
            local task=tasks[id];local vector=vectors[task.direction]
            if impulse<=task.count and working.entities[id] then
                local part=RW_ResolveMovement(working,{type="move",entity_id=id,dx=vector[1],dy=vector[2]})
                if not part.consumes_turn then return nil,part.reason end
                working.entities[id].direction=task.direction
                for _,change in ipairs(part.changes) do queued[#queued+1]=change end
                for _,death in ipairs(part.destructions or {}) do
                    deaths[#deaths+1]=death;records[death.entity_id]=death;working.entities[death.entity_id]=nil
                end
            end
        end
        for _,change in ipairs(queued) do
            local e=working.entities[change.entity_id]
            if e then
                if change.kind=="move" then e.x=change.to.x;e.y=change.to.y;e.direction=change.to.direction
                elseif change.kind=="direction" then e.direction=change.to end
            end
        end
    end
    -- Original moveblock also aligns surviving occupants at their final position,
    -- without adding another displacement when entering a second belt this turn.
    for _,id in ipairs(ids) do
        local belt=working.entities[id]
        if belt and has_capability(world,belt,"shift") and vectors[belt.direction] then
            for _,other_id in ipairs(ids) do
                local rider=working.entities[other_id]
                if rider and other_id~=id and rider.x==belt.x and rider.y==belt.y and same_layer(world,belt,rider) then
                    rider.direction=belt.direction
                end
            end
        end
    end
    local changes={}
    for _,id in ipairs(ids) do
        local before=world.entities[id];local after=working.entities[id] or records[id]
        if before.x~=after.x or before.y~=after.y then
            changes[#changes+1]={kind="move",entity_id=id,
                from={x=before.x,y=before.y,direction=before.direction or "None"},
                to={x=after.x,y=after.y,direction=after.direction or "None"}}
        elseif (before.direction or "None")~=(after.direction or "None") then
            changes[#changes+1]={kind="direction",entity_id=id,from=before.direction or "None",to=after.direction or "None"}
        end
    end
    return {consumes_turn=true,changes=changes,destructions=deaths,reason="shift"}
end

-- SELECT is not YOU: it follows traversable map objects without pushing them.
function RW_ResolveTurn(world, action)
    if type(action)=="table" and action.type=="wait" then return {consumes_turn=true,changes={},reason="wait"} end
    local movement_world=world
    if world.empty_cells then
        -- Ephemeral movement agents, never part of a Plan/Commit or allocator.
        movement_world={}; for k,v in pairs(world) do movement_world[k]=v end
        movement_world.entities={}; for id,e in pairs(world.entities) do movement_world.entities[id]=e end
        local next_virtual=-1
        local keys={}; for key in pairs(world.empty_cells) do keys[#keys+1]=key end; table.sort(keys)
        for _,key in ipairs(keys) do
            local cell=world.empty_cells[key]
            if cell.behaviors.control then
                movement_world.entities[next_virtual]={id=next_virtual,kind="object",class="object",
                    x=cell.x,y=cell.y,direction="None",behaviors={control=true}}
                next_virtual=next_virtual-1
            end
        end
    end
    local plan = resolve_you_turn(movement_world, action)
    local real={}; for _,change in ipairs(plan.changes) do if change.entity_id > 0 then real[#real+1]=change end end
    plan.changes=real
    if not plan.consumes_turn then return plan end
    local writes = {}
    for index, change in ipairs(plan.changes) do writes[change.entity_id] = index end
    local selected = false
    local destroyed={};for _,death in ipairs(plan.destructions or {}) do destroyed[death.entity_id]=true end
    for id, entity in pairs(world.entities) do
        if not destroyed[id] and has_capability(world, entity, "select") then
            selected = true
            local x, y = entity.x + action.dx, entity.y + action.dy
            local traversable = false
            for other_id, other in pairs(world.entities) do
                if other_id ~= id and other.x == x and other.y == y
                    and (has_capability(world, other, "select_path")
                        or level_surface(world,other)) then
                    traversable = true
                end
            end
            if traversable and x >= 1 and x <= world.width and y >= 1 and y <= world.height then
                local operation = {kind="move",entity_id=id,
                    from={x=entity.x,y=entity.y,direction=entity.direction or "None"},
                    to={x=x,y=y,direction=direction_for(action.dx,action.dy)}}
                -- Both properties: SELECT positioning takes precedence; never double-step.
                if writes[id] then plan.changes[writes[id]] = operation
                else plan.changes[#plan.changes+1] = operation end
            end
        end
    end
    if world.level_behaviors and world.level_behaviors.control then
        local current = world.board_offset or {x=0,y=0,direction="None"}
        plan.board_shift = {from={x=current.x,y=current.y,direction=current.direction},
            to={x=current.x+action.dx,y=current.y+action.dy,direction=direction_for(action.dx,action.dy)}}
        plan.reason = nil
    end
    if selected then
        table.sort(plan.changes, function(a,b) return a.entity_id < b.entity_id end)
        if #plan.changes > 0 then plan.reason = nil
        elseif plan.reason == "no_you" then plan.reason = "select_blocked" end
    end
    return plan
end

function RW_LevelSelectionCandidates(world)
    local candidates, seen = {}, {}
    for id, cursor in pairs(world.entities) do
        if has_capability(world, cursor, "select") then
            for target_id, target in pairs(world.entities) do
                if id ~= target_id and not has_capability(world,target,"select")
                    and cursor.x == target.x and cursor.y == target.y
                    and level_surface(world,target) and not seen[target_id] then
                    seen[target_id] = true
                    candidates[#candidates+1] = target_id
                end
            end
        end
    end
    table.sort(candidates)
    return candidates
end

function RW_HasWinContact(world)
    for _,cell in pairs(world.empty_cells or {}) do
        if cell.behaviors.control and cell.behaviors.win and not cell.behaviors.defeat then return true end
    end
    for _, actor in pairs(world.entities) do
        if has_capability(world, actor, "control") then
            for _, target in pairs(world.entities) do
                if actor.x == target.x and actor.y == target.y and same_layer(world,actor,target)
                    and has_capability(world, target, "win") then return true end
            end
        end
    end
    return false
end

function RW_LevelSelectionSelfTest()
    local world = {width=4,height=3,entities={
        [7]={id=7,x=1,y=1,direction="None",traits={select=true}},
        [8]={id=8,x=2,y=1,direction="None",archetype="portal",level_link={source_type="portal",target="parent"}},
        [9]={id=9,x=2,y=1,direction="None",traits={pushable=true}},
        [10]={id=10,x=4,y=3,direction="None",traits={you=true}}
    }}
    local before = RW_LevelSelectionCandidates(world)
    local plan = RW_ResolveTurn(world,{type="move",dx=1,dy=0})
    local cursor_move
    for _, change in ipairs(plan.changes) do
        if change.entity_id == 9 then return false, "SELECT pushed an ordinary object" end
        if change.entity_id == 7 then cursor_move = change end
    end
    if #before ~= 0 or not cursor_move or cursor_move.to.x ~= 2 then
        return false, "SELECT path movement failed"
    end
    world.entities[7].x = 2
    if RW_LevelSelectionCandidates(world)[1] ~= 8 then return false, "Non-Avatar SELECT failed" end
    world.entities[7].traits = {you=true}
    if #RW_LevelSelectionCandidates(world) ~= 0 then return false, "YOU gained SELECT authority" end
    world.entities[7].traits = {select=true}
    world.entities[7].behaviors = {} -- Rule retraction disables raw legacy traits.
    if #RW_LevelSelectionCandidates(world) ~= 0 then return false, "Retracted SELECT still active" end
    return true, "SELECT independent of YOU, path movement and entry authority passed"
end

function RW_LevelSelectorIDs(world)
    local ids = {}
    for id, entity in pairs(world.entities) do
        if has_capability(world,entity,"select") then ids[#ids+1] = id end
    end
    table.sort(ids)
    return ids
end
