
-- movement.lua
-- RuleWorld M2: Movement intentions and constraints

-- Unit-list consumers keep physical instances separate from native history IDs.
local function unit_ids(world)
    local ids={}
    if world.unit_order then for _,id in ipairs(world.unit_order) do ids[#ids+1]=id end
    else for id in pairs(world.entities) do ids[#ids+1]=id end;table.sort(ids) end
    return ids
end

-- Projected capability sets are authoritative for movement. Raw trait fixtures
-- retain a default-only compatibility path; custom registries require projection.
local function has_capability(world, entity, capability)
    if entity.behaviors ~= nil then
        return type(entity.behaviors) == "table" and entity.behaviors[capability] == true
    end
    if world.behavior_registry ~= nil then return false end
    local legacy = {control = "you", control2="you2", select = "select", select_path = "path",
        win = "win", ["end"]="end", done="done", push = "pushable", block_entry = "block_entry",
        open="open",shut="shut",safe="safe",weak="weak",float="float",tele="tele",shift="shift",fall="fall",fallright="fallright",fallup="fallup",fallleft="fallleft",pull="pull",swap="swap",phantom="phantom",reverse="reverse",sleep="sleep",still="still",lockedright="lockedright",lockedup="lockedup",lockedleft="lockedleft",lockeddown="lockeddown",move="move",auto="auto",chill="chill",right="right",up="up",left="left",down="down",turn="turn",deturn="deturn",nudgeright="nudgeright",nudgeup="nudgeup",nudgeleft="nudgeleft",nudgedown="nudgedown"}
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

-- Native cantmove checks LEVEL HOLD against the map's FLOAT layer first.
local function held_by_level(world,entity)
    local level=world.level_behaviors or {}
    return entity.class~="empty" and level.hold==true
        and has_capability(world,entity,"float")== (level.float==true)
end

-- REVERSE changes active intentions, never recursively pushed/pulled dependencies.
local function reverse_vector(world,entity,dx,dy)
    local counts=world.trait_counts and world.trait_counts[entity.id]
    local count=counts and counts.reverse or (has_capability(world,entity,"reverse") and 1 or 0)
    if count%2==1 then return -dx,-dy end
    return dx,dy
end
local function immobile(world,entity,dx,dy)
    dx,dy=reverse_vector(world,entity,dx,dy)
    local locked=dx==1 and "lockedright" or dx==-1 and "lockedleft" or dy==-1 and "lockedup" or "lockeddown"
    return held_by_level(world,entity) or has_capability(world,entity,"still") or has_capability(world,entity,locked)
end

local function intent_immobile(world,entity,dx,dy)
    dx,dy=reverse_vector(world,entity,dx,dy)
    return immobile(world,entity,dx,dy)
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

    local intent_direction=direction_for(dx,dy)
    if not action.falling and not action.no_reverse then dx,dy=reverse_vector(world,mover,dx,dy) end
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
        return cell and cell.behaviors or world.empty_behaviors,cell
    end
    local function empty_obstacle(x,y)
        local empty,cell=empty_at(x,y)
        if not empty then return nil end
        local qx,qy=dx,dy
        local count=cell and cell.trait_counts and cell.trait_counts.reverse or (empty.reverse and 1 or 0)
        if count%2==1 then qx,qy=-qx,-qy end
        local locked=qx==1 and "lockedright" or qx==-1 and "lockedleft" or qy==-1 and "lockedup" or "lockeddown"
        local still=empty.still or empty[locked]
        -- Native check() disables immobile EMPTY SWAP, and blocks immobile PUSH.
        -- Synthetic EMPTY is exempt from LEVEL HOLD; SLEEP does not stop pushing.
        local swap=empty.swap and not still
        if (empty.push or swap) and still then return "stop" end
        if swap then return nil end
        if empty.push then return "push" end
        if empty.block_entry or empty.pull then return "stop" end
    end
    local try_move,attempt_move
    local function push_empty(x,y)
        local nx,ny=x+dx,y+dy
        if get_environment(world,nx,ny) == "edge" then return false,"blocked_by_edge" end
        local obstacle=empty_obstacle(nx,ny)
        if obstacle=="push" then
            local ok,err=push_empty(nx,ny); if not ok then return false,err end
        elseif obstacle=="stop" then return false,"blocked_by_empty" end
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
        if not (action.fear_probe and id==action.entity_id) and immobile(world,entity,dx,dy) then return false,"blocked_by_still" end
        visiting[id] = true

        local nx = entity.x + dx
        local ny = entity.y + dy

        if get_environment(world, nx, ny) == "edge" then
            visiting[id] = nil
            return false, "blocked_by_edge"
        end

        local phantom=has_capability(world,entity,"phantom")
        local obstacle=not phantom and empty_obstacle(nx,ny)
        if obstacle=="push" then
            local ok,err=push_empty(nx,ny)
            if not ok then visiting[id]=nil; return false,err end
        elseif obstacle=="stop" then
            visiting[id]=nil; return false,"blocked_by_empty"
        end
        -- Gather occupants deterministically.
        local occupants = {}

        for other_id, other in pairs(world.entities) do
            if other_id > 0 and other_id ~= id
                and not removed[other_id]
                and other.x == nx
                and other.y == ny then
                occupants[#occupants + 1] = other_id
            end
        end

        table.sort(occupants)

        local locks,swaps,weak_targets={},{},{}
        local partner=has_capability(world,entity,"open") and "shut"
            or has_capability(world,entity,"shut") and "open" or nil
        for _, other_id in ipairs(occupants) do
            if not planned[other_id] then
                local other = world.entities[other_id]

                local target_swap=has_capability(world,other,"swap") and not immobile(world,other,dx,dy)
                local mover_swap=has_capability(world,entity,"swap")
                if not phantom and partner and id > 0 and other_id > 0 and same_layer(world,entity,other) and has_capability(world,other,partner)
                    and (not has_capability(world,entity,"safe") or not has_capability(world,other,"safe")) then
                    locks[#locks+1]=other_id -- Unlock takes precedence over PUSH/STOP.
                elseif action.falling and not phantom and same_layer(world,entity,other)
                    and has_capability(world,other,"weak") and not has_capability(world,other,"safe")
                    and not has_capability(world,other,"push") then
                    weak_targets[#weak_targets+1]=other_id
                elseif action.falling and target_swap then -- FALL passes over SWAP without swapping it.
                elseif not action.falling and (target_swap or (mover_swap and not phantom)) then
                    if not held_by_level(world,other) and not has_capability(world,other,"still") then swaps[#swaps+1]=other_id end
                elseif phantom then -- PHANTOM bypasses ordinary collisions, not later contacts.
                elseif has_capability(world, other, "push") then
                    -- FALL treats PUSH as support; it never pushes the support away.
                    if action.falling then visiting[id]=nil;return false,"blocked_by_entity" end
                    -- Push takes priority over STOP-like blocking.
                    local ok, reason = try_move(other_id)

                    if not ok then
                        visiting[id] = nil
                        return false, reason
                    end

                elseif (has_capability(world, other, "block_entry") or has_capability(world,other,"pull"))
                    and (not has_capability(world,other,"weak") or not same_layer(world,entity,other)) then
                    visiting[id] = nil
                    return false, "blocked_by_entity"
                end
            end
        end

        for _,other_id in ipairs(weak_targets) do destroy(other_id,nil,"weak") end
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

        for _,other_id in ipairs(swaps) do
            if not removed[other_id] then
                local other=world.entities[other_id];planned[other_id]=true
                changes[#changes+1]={kind="move",entity_id=other_id,
                    from={x=other.x,y=other.y,direction=other.direction or "None"},
                    to={x=entity.x,y=entity.y,direction=other.direction or "None"}}
            end
        end

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

        -- A failed trailing pull never cancels an already successful mover.
        local followers={}
        for other_id,other in pairs(world.entities) do
            if other_id > 0 and not action.falling and not planned[other_id] and not removed[other_id] and other.x==entity.x-dx and other.y==entity.y-dy
                and has_capability(world,other,"pull") then followers[#followers+1]=other_id end
        end
        table.sort(followers)
        for _,other_id in ipairs(followers) do
            local old_planned,old_removed,old_visiting={},{},{}
            for k,v in pairs(planned) do old_planned[k]=v end
            for k,v in pairs(removed) do old_removed[k]=v end
            for k,v in pairs(visiting) do old_visiting[k]=v end
            local change_count,death_count=#changes,#destructions
            local ok=try_move(other_id,true)
            if not ok then
                planned,removed,visiting=old_planned,old_removed,old_visiting
                while #changes>change_count do table.remove(changes) end
                while #destructions>death_count do table.remove(destructions) end
            end
        end
        return true
    end

    try_move=function(id,pulling)
        local entity=world.entities[id]
        if not (action.fear_probe and id==action.entity_id) and immobile(world,entity,dx,dy) then return false,"blocked_by_still" end
        if action.falling or pulling or id < 1 or not has_capability(world,entity,"weak") or has_capability(world,entity,"safe") then
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

    if not action.falling then
        for _,change in ipairs(changes) do
            if change.entity_id==action.entity_id and change.kind=="move" then change.to.direction=intent_direction end
        end
        for _,death in ipairs(destructions) do
            if death.entity_id==action.entity_id then
                death.direction=intent_direction;death.frame[action.entity_id].direction=intent_direction
            end
        end
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

local function resolve_you_turn(world, action, intentions)
    if type(world) ~= "table"
        or type(world.entities) ~= "table" then
        return invalid("invalid_world")
    end

    if type(action) ~= "table"
        or action.type ~= "move" then
        return invalid("invalid_action")
    end

    local dx, dy = action.dx, action.dy

    if not intentions and not (
        ((dx == 1 or dx == -1) and dy == 0)
        or (dx == 0 and (dy == 1 or dy == -1))
    ) then
        return invalid("invalid_direction")
    end

    -- Capture all controllers at the beginning of turn.
    local controllers = {}

    for id, entity in pairs(world.entities) do
        if (intentions and intentions[id] or not intentions and has_capability(world, entity, "control")) and not has_capability(world,entity,"sleep") then
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

        local da = intentions and intentions[a] or {dx,dy}
        local db = intentions and intentions[b] or {dx,dy}
        if intentions and da[3] ~= db[3] then return da[3] < db[3] end
        local pa = ea.x * da[1] + ea.y * da[2]
        local pb = eb.x * db[1] + eb.y * db[2]

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
            local dx,dy=dx,dy
            if intentions then dx,dy=intentions[id][1],intentions[id][2] end
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
    local ids=unit_ids(world)
    for id,e in pairs(world.entities) do
        local copy={};for k,v in pairs(e) do copy[k]=v end
        working.entities[id]=copy
    end
    local vectors={Left={-1,0},Up={0,-1},Right={1,0},Down={0,1}}
    local tasks,order={},{}
    for _,id in ipairs(ids) do
        local belt=world.entities[id]
        if has_capability(world,belt,"shift") and vectors[belt.direction] then
            for _,other_id in ipairs(ids) do
                local rider=world.entities[other_id]
                if other_id ~= id and rider.x==belt.x and rider.y==belt.y and same_layer(world,belt,rider)
                    and not intent_immobile(world,rider,vectors[belt.direction][1],vectors[belt.direction][2]) then
                    if not tasks[other_id] then
                        tasks[other_id]={direction=belt.direction,count=0};order[#order+1]=other_id
                    end
                    tasks[other_id].count=tasks[other_id].count+1
                end
            end
        end
    end
    -- Ordered history is separate from the final atomic displacement summary.
    -- In particular, native alignment emits an update even for identical facing.
    local history,history_state={},{}
    local function remember(id,entity,force)
        local old=history_state[id] or world.entities[id]
        local from={x=old.x,y=old.y,direction=old.direction or "None"}
        local to={x=entity.x,y=entity.y,direction=entity.direction or "None"}
        if force or from.x~=to.x or from.y~=to.y or from.direction~=to.direction then
            history[#history+1]={kind="move",entity_id=id,from=from,to=to,retain=not force}
            history_state[id]=to
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
                remember(id,working.entities[id])
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
                remember(change.entity_id,e)
            end
        end
    end
    -- Original moveblock also aligns surviving occupants at their final position,
    -- without adding another displacement when entering a second belt this turn.
    for _,id in ipairs(ids) do
        local belt=working.entities[id]
        if belt and has_capability(world,belt,"shift") and not has_capability(world,belt,"sleep") and vectors[belt.direction] then
            for _,other_id in ipairs(ids) do
                local rider=working.entities[other_id]
                if rider and other_id~=id and rider.x==belt.x and rider.y==belt.y and same_layer(world,belt,rider) then
                    rider.direction=belt.direction
                    remember(other_id,rider,true)
                end
            end
        end
    end
    local changes={}
    for _,id in ipairs(ids) do
        local before=world.entities[id];local after=working.entities[id] or records[id]
        remember(id,after)
        if before.x~=after.x or before.y~=after.y then
            changes[#changes+1]={kind="move",entity_id=id,
                from={x=before.x,y=before.y,direction=before.direction or "None"},
                to={x=after.x,y=after.y,direction=after.direction or "None"}}
        elseif (before.direction or "None")~=(after.direction or "None") then
            changes[#changes+1]={kind="direction",entity_id=id,from=before.direction or "None",to=after.direction or "None"}
        end
    end
    return {consumes_turn=true,changes=changes,destructions=deaths,reason="shift",motion_history=#history>0 and history or nil}
end

-- Direction grants use physical rule multiplicity (statusblock in blocks.lua).
function RW_ResolveOrientation(world)
    local names={"Right","Up","Left","Down"}
    local indices={Right=0,Up=1,Left=2,Down=3,Mid=4,None=4}
    local traits={"right","up","left","down"}
    local changes={}
    local ids={};for id in pairs(world.entities) do ids[#ids+1]=id end;table.sort(ids)
    for _,id in ipairs(ids) do
        local entity=world.entities[id]
        if not has_capability(world,entity,"sleep") then
            local counts=world.trait_counts and world.trait_counts[id] or entity.traits or {}
            local values,maxcount,winners={},0,0
            for i,trait in ipairs(traits) do
                local value=counts[trait];value=value==true and 1 or value or 0
                values[i]=value
                if value>maxcount then maxcount,winners=value,1
                elseif value==maxcount then winners=winners+1 end
            end
            local current=indices[entity.direction or "None"] or 4
            local facing=current
            if maxcount>0 then
                if winners==1 then
                    for i,value in ipairs(values) do if value==maxcount then facing=i-1 end end
                elseif current<4 then
                    for offset=1,3 do
                        local candidate=(current-offset)%4
                        if values[candidate+1]==maxcount then facing=candidate;break end
                    end
                end
            end
            local function count(trait)
                local value=counts[trait];return value==true and 1 or value or 0
            end
            local turns=count("deturn")-count("turn")
            if turns~=0 then facing=(facing+turns)%4 end
            if names[facing+1] and names[facing+1]~=(entity.direction or "None") then
                changes[#changes+1]={kind="direction",entity_id=id,from=entity.direction or "None",to=names[facing+1]}
            end
        end
    end
    return {consumes_turn=true,changes=changes,reason="orientation"}
end

-- Autonomous impulses reuse the ordinary collision/destruction solver.
function RW_ResolveAutomatic(world,empty_directions)
    local vectors={Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}}
    local opposite={Right="Left",Left="Right",Up="Down",Down="Up"}
    local working={};for k,v in pairs(world) do working[k]=v end
    working.entities={}
    local ids={}
    for id,entity in pairs(world.entities) do
        local copy={};for k,v in pairs(entity) do copy[k]=v end
        working.entities[id]=copy;ids[#ids+1]=id
    end
    table.sort(ids)
    working.trait_counts={};for id,counts in pairs(world.trait_counts or {}) do working.trait_counts[id]=counts end
    local cells={}
    for key,cell in pairs(world.empty_cells or {}) do
        local b=cell.behaviors
        if b.move or b.auto or b.chill or b.nudgeright or b.nudgeup or b.nudgeleft or b.nudgedown then
            cells[#cells+1]={key=key,cell=cell}
        end
    end
    table.sort(cells,function(a,b) if a.cell.y~=b.cell.y then return a.cell.y<b.cell.y end;return a.cell.x<b.cell.x end)
    for index,item in ipairs(cells) do
        local id=-index;local cell=item.cell
        working.entities[id]={id=id,kind="object",class="empty",x=cell.x,y=cell.y,
            direction=empty_directions and empty_directions[item.key] or cell.direction or "None",behaviors=cell.behaviors}
        working.trait_counts[id]=cell.trait_counts or {};ids[#ids+1]=id
    end
    local state=world.random_state or 1;local original_state=state
    local autonomous,reasons,empty_tasks={},{},{}
    -- Real MOVE/AUTO precede CHILL; real CHILL draws occur during collection.
    -- EMPTY draws at dispatch; later properties reuse occupied collection slots.
    for _,id in ipairs(ids) do
        local entity=working.entities[id]
        local counts=working.trait_counts[id] or {}
        local function count(trait) return counts[trait] or (has_capability(world,entity,trait) and 1 or 0) end
        local total=0
        if id<0 then
            empty_tasks[id]={}
        elseif not has_capability(world,entity,"sleep") then
            local v=vectors[entity.direction]
            if v and not intent_immobile(working,entity,v[1],v[2]) then
                local moves,autos=count("move"),count("auto")
                total=moves+autos
                if moves>0 then reasons[id]="move" elseif autos>0 then reasons[id]="auto" end
            end
            for i=1,count("chill") do
                state=(state*48271)%2147483647
                entity.direction=({"Right","Up","Left","Down"})[state%4+1]
                v=vectors[entity.direction]
                if not intent_immobile(working,entity,v[1],v[2]) then
                    total=total+1;reasons[id]=reasons[id] or "chill"
                end
            end
        end
        autonomous[id]=total
    end
    -- EMPTY seen codes belong to the whole property list, not to one vacancy.
    -- An earlier slot with any eligible cell suppresses that slot everywhere in
    -- later properties, while an entirely filtered/empty slot consumes no code.
    local seen_empty={}
    for _,trait in ipairs({"move","auto","chill"}) do
        local collected={}
        for index,item in ipairs(cells) do
            local id=-index;local entity=working.entities[id]
            if not has_capability(world,entity,"sleep") and not has_capability(world,entity,"still") then
                local slots=item.cell.motion_slots and item.cell.motion_slots[trait]
                if not item.cell.motion_slots then
                    slots={}
                    for slot=1,(working.trait_counts[id][trait] or (entity.behaviors[trait] and 1 or 0)) do slots[#slots+1]=slot end
                end
                for _,slot in ipairs(slots or {}) do if not seen_empty[slot] then
                    empty_tasks[id][#empty_tasks[id]+1]={count=1,direction=entity.direction,
                        reason=trait,x=entity.x,y=entity.y}
                    collected[slot]=true
                end end
            end
        end
        for slot in pairs(collected) do seen_empty[slot]=true end
    end
    local deaths,records={},{}
    local function apply(part)
        for _,change in ipairs(part.changes) do
            local entity=working.entities[change.entity_id]
            if entity then
                if change.kind=="move" then entity.x,entity.y,entity.direction=change.to.x,change.to.y,change.to.direction
                elseif change.kind=="direction" then entity.direction=change.to end
            end
        end
        for _,death in ipairs(part.destructions or {}) do
            if death.entity_id>0 then deaths[#deaths+1]=death end
            records[death.entity_id]=death;working.entities[death.entity_id]=nil
        end
    end
    for _,spec in ipairs({{"move"},{"nudgeright","Right"},{"nudgeup","Up"},{"nudgeleft","Left"},{"nudgedown","Down"}}) do
        for _,id in ipairs(ids) do
            local entity=working.entities[id]
            local counts=working.trait_counts[id] or {}
            local count=spec[1]=="move" and autonomous[id] or (counts[spec[1]] or (entity and has_capability(world,entity,spec[1]) and 1 or 0))
            local tasks={{count=count,reason=reasons[id]}}
            if id<0 then
                tasks=spec[1]=="move" and empty_tasks[id] or {}
                if spec[2] then for i=1,count do
                    local initial=cells[-id].cell
                    tasks[#tasks+1]={count=1,direction=spec[2],x=initial.x,y=initial.y,reason=spec[1]}
                end end
            end
            for _,task in ipairs(tasks) do
            if id<0 and entity then entity.x,entity.y,entity.direction=task.x,task.y,task.direction end
            for impulse=1,task.count do
                entity=working.entities[id]
                if not entity or has_capability(world,entity,"sleep") then break end
                if id<0 and has_capability(world,entity,"still") then break end
                if id<0 and ((task.reason=="move" and not vectors[entity.direction]) or task.reason=="chill") then
                    state=(state*48271)%2147483647
                    entity.direction=({"Right","Up","Left","Down"})[state%4+1]
                end
                local direction=spec[2] or entity.direction
                local vector=vectors[direction]
                if vector and not intent_immobile(working,entity,vector[1],vector[2]) then
                    local old_direction=entity.direction or "None"
                    local part=RW_ResolveMovement(working,{type="move",entity_id=id,dx=vector[1],dy=vector[2]})
                    if spec[1]=="move" and task.reason~="auto" and #part.changes==0 and #(part.destructions or {})==0 then
                        direction=opposite[direction];vector=vectors[direction]
                        entity.direction=direction
                        part=RW_ResolveMovement(working,{type="move",entity_id=id,dx=vector[1],dy=vector[2]})
                    end
                    apply(part)
                    if spec[2] and working.entities[id] then working.entities[id].direction=old_direction end
                end
            end
            end
        end
    end
    local changes={}
    for _,id in ipairs(ids) do
        if id>0 then
        local before=world.entities[id];local after=working.entities[id] or records[id]
        if before.x~=after.x or before.y~=after.y then
            changes[#changes+1]={kind="move",entity_id=id,
                from={x=before.x,y=before.y,direction=before.direction or "None"},
                to={x=after.x,y=after.y,direction=after.direction or "None"}}
        elseif (before.direction or "None")~=(after.direction or "None") then
            changes[#changes+1]={kind="direction",entity_id=id,from=before.direction or "None",to=after.direction or "None"}
        end
        end
    end
    return {consumes_turn=true,changes=changes,destructions=deaths,reason="automatic",
        random_state=state~=original_state and {from=original_state,to=state} or nil}
end

-- FALL is a settling phase. Opposite grants cancel by count; surviving
-- axes settle in original down/right/up/left collection order.
function RW_ResolveFall(world)
    local working={};for k,v in pairs(world) do working[k]=v end
    working.entities={}
    local ids,tasks={},{}
    for id,entity in pairs(world.entities) do
        local copy={};for k,v in pairs(entity) do copy[k]=v end
        working.entities[id]=copy;ids[#ids+1]=id
        local counts=world.trait_counts and world.trait_counts[id] or {}
        local function count(trait) return counts[trait] or (has_capability(world,entity,trait) and 1 or 0) end
        local vertical=count("fall")-count("fallup")
        local horizontal=count("fallright")-count("fallleft")
        horizontal,vertical=reverse_vector(world,entity,horizontal,vertical)
        tasks[id]={}
        if vertical>0 then tasks[id][1]={0,1} end
        if horizontal>0 then tasks[id][2]={1,0} end
        if vertical<0 then tasks[id][3]={0,-1} end
        if horizontal<0 then tasks[id][4]={-1,0} end
    end
    table.sort(ids)
    local deaths,records={},{}
    local moved,iterations=true,0
    while moved and iterations<6000 do
        moved=false
        for axis=1,4 do
        for _,id in ipairs(ids) do
            local vector=tasks[id][axis]
            local entity=working.entities[id]
            if vector and entity then
                while working.entities[id] and iterations<6000 do
                    entity=working.entities[id]
                    if immobile(world,entity,vector[1],vector[2]) then break end
                    local facing=entity.direction or "None"
                    local part=RW_ResolveMovement(working,{type="move",entity_id=id,dx=vector[1],dy=vector[2],falling=true})
                    iterations=iterations+1
                    if #part.changes==0 and #(part.destructions or {})==0 then break end
                    for _,change in ipairs(part.changes) do
                        local e=working.entities[change.entity_id]
                        if e and change.kind=="move" then e.x,e.y=change.to.x,change.to.y end
                    end
                    for _,death in ipairs(part.destructions or {}) do
                        if death.entity_id==id then death.direction=facing;death.frame[id].direction=facing end
                        deaths[#deaths+1]=death;records[death.entity_id]=death;working.entities[death.entity_id]=nil
                    end
                    if working.entities[id] then working.entities[id].direction=facing end
                    moved=true
                end
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
        end
    end
    return {consumes_turn=true,changes=changes,destructions=deaths,infinite_loop=iterations>=6000,reason="fall"}
end

-- Project the selected input channel only for displacement. Contact/outcome
-- consumers keep both independent capabilities on the original rule projection.
local function input_control_world(world,player)
    if player~=2 then return world end
    local has_second=world.empty_control2_declared==true
    for _,e in pairs(world.entities) do if has_capability(world,e,"control2") then has_second=true;break end end
    local result={};for k,v in pairs(world) do result[k]=v end
    result.entities={}
    local capability=has_second and "control2" or "control"
    for id,e in pairs(world.entities) do
        local unit={};for k,v in pairs(e) do unit[k]=v end
        if e.behaviors then
            unit.behaviors={};for k,v in pairs(e.behaviors) do unit.behaviors[k]=v end
            unit.behaviors.control=has_capability(world,e,capability)
        else
            unit.traits={};for k,v in pairs(e.traits or {}) do unit.traits[k]=v end
            unit.traits.you=has_capability(world,e,capability)
        end
        result.entities[id]=unit
    end
    if world.empty_cells then
        result.empty_cells={}
        for key,cell in pairs(world.empty_cells) do
            local copy={};for k,v in pairs(cell) do copy[k]=v end
            copy.behaviors={};for k,v in pairs(cell.behaviors) do copy.behaviors[k]=v end
            copy.behaviors.control=cell.behaviors[capability]==true
            result.empty_cells[key]=copy
        end
    end
    if world.level_behaviors then
        result.level_behaviors={};for k,v in pairs(world.level_behaviors) do result.level_behaviors[k]=v end
        -- Original LEVEL fallback is independent of the real-unit list.
        result.level_behaviors.control=world.level_behaviors.control2 or world.level_behaviors.control
    end
    return result
end
-- SELECT is not YOU: it follows traversable map objects without pushing them.
function RW_ResolveTurn(world, action)
    if type(action)=="table" and action.player~=nil and action.player~=1 and action.player~=2 and action.player~=3 then return invalid("invalid_player") end
    if type(action)=="table" and action.type=="wait" then return {consumes_turn=true,changes={},reason="wait"} end
    if type(world)~="table" or type(world.entities)~="table" then return invalid("invalid_world") end
    world=input_control_world(world,type(action)=="table" and action.player or 1)
    local movement_world=world
    if world.empty_cells then
        -- Ephemeral movement agents, never part of a Plan/Commit or allocator.
        movement_world={}; for k,v in pairs(world) do movement_world[k]=v end
        movement_world.entities={}; for id,e in pairs(world.entities) do movement_world.entities[id]=e end
        movement_world.trait_counts={};for id,counts in pairs(world.trait_counts or {}) do movement_world.trait_counts[id]=counts end
        local next_virtual=-1
        local keys={}; for key in pairs(world.empty_cells) do keys[#keys+1]=key end; table.sort(keys)
        for _,key in ipairs(keys) do
            local cell=world.empty_cells[key]
            if (cell.behaviors.control or action.player==3 and cell.behaviors.control2) and not cell.behaviors.sleep then
                movement_world.entities[next_virtual]={id=next_virtual,kind="object",class="empty",
                    x=cell.x,y=cell.y,direction="None",behaviors=cell.behaviors}
                movement_world.trait_counts[next_virtual]=cell.trait_counts or {}
                next_virtual=next_virtual-1
            end
        end
    end
    local intentions
    if action.player==3 then
        local function vector(x,y) return x==0 and y==0 or ((x==1 or x==-1) and y==0) or (x==0 and (y==1 or y==-1)) end
        if not vector(action.dx,action.dy) or not vector(action.dx2,action.dy2) then return invalid("invalid_direction") end
        intentions={}
        for id,e in pairs(movement_world.entities) do
            if has_capability(movement_world,e,"control") and (action.dx~=0 or action.dy~=0) then intentions[id]={action.dx,action.dy,1}
            elseif has_capability(movement_world,e,"control2") and (action.dx2~=0 or action.dy2~=0) then intentions[id]={action.dx2,action.dy2,2} end
        end
    end
    local plan = resolve_you_turn(movement_world, action, intentions)
    local real={}; for _,change in ipairs(plan.changes) do if change.entity_id > 0 then real[#real+1]=change end end
    plan.changes=real
    if not plan.consumes_turn then return plan end
    local writes = {}
    for index, change in ipairs(plan.changes) do writes[change.entity_id] = index end
    local selected = false
    local destroyed={};for _,death in ipairs(plan.destructions or {}) do destroyed[death.entity_id]=true end
    for id, entity in pairs(world.entities) do
        if (action.dx~=0 or action.dy~=0) and not destroyed[id] and has_capability(world, entity, "select") and not has_capability(world,entity,"sleep") then
            selected = true
            local dx,dy=reverse_vector(world,entity,action.dx,action.dy)
            local x, y = entity.x + dx, entity.y + dy
            local traversable = false
            for other_id, other in pairs(world.entities) do
                if other_id ~= id and other.x == x and other.y == y
                    and (has_capability(world, other, "select_path")
                        or level_surface(world,other)) then
                    traversable = true
                end
            end
            if traversable and not immobile(world,entity,dx,dy) and x >= 1 and x <= world.width and y >= 1 and y <= world.height then
                local operation = {kind="move",entity_id=id,
                    from={x=entity.x,y=entity.y,direction=entity.direction or "None"},
                    to={x=x,y=y,direction=direction_for(dx,dy)}}
                -- Both properties: SELECT positioning takes precedence; never double-step.
                if writes[id] then plan.changes[writes[id]] = operation
                else plan.changes[#plan.changes+1] = operation end
            end
        end
    end
    local level_count=0
    for _,trait in ipairs(world.level_traits or {}) do if trait=="reverse" then level_count=level_count+1 end end
    local level_dx,level_dy=action.dx,action.dy
    if level_count%2==1 then level_dx,level_dy=-level_dx,-level_dy end
    if (action.dx~=0 or action.dy~=0) and world.level_behaviors and (world.level_behaviors.control or action.player==3 and world.level_behaviors.control2) and not world.level_behaviors.sleep
        and not world.level_behaviors.still
        and not world.level_behaviors[action.dx==1 and "lockedright" or action.dx==-1 and "lockedleft" or action.dy==-1 and "lockedup" or "lockeddown"] then
        local current = world.board_offset or {x=0,y=0,direction="None"}
        plan.board_shift = {from={x=current.x,y=current.y,direction=current.direction},
            to={x=current.x+level_dx,y=current.y+level_dy,direction=direction_for(level_dx,level_dy)}}
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
    local level=world.level_behaviors or {}
    if level.control or level.control2 then
        if level.win then return true end
        for _,target in pairs(world.entities) do
            if has_capability(world,target,"win") and (has_capability(world,target,"float")== (level.float==true)) then return true end
        end
        local empty_win=world.empty_win_declared
        local empty_float=world.empty_float_declared
        if empty_win==nil then empty_win=world.empty_behaviors and world.empty_behaviors.win end
        if empty_float==nil then empty_float=world.empty_behaviors and world.empty_behaviors.float or false end
        if empty_win and (empty_float==true)==(level.float==true) then return true end
    end
    for _,cell in pairs(world.empty_cells or {}) do
        if (cell.behaviors.control or cell.behaviors.control2) and cell.behaviors.win
            and (not cell.behaviors.defeat or cell.behaviors.safe) then return true end
    end
    for _, actor in pairs(world.entities) do
        if has_capability(world, actor, "control") or has_capability(world,actor,"control2") then
            for _, target in pairs(world.entities) do
                if actor.x == target.x and actor.y == target.y and same_layer(world,actor,target)
                    and has_capability(world, target, "win") and not has_capability(world,target,"end")
                    and not has_capability(world,target,"done") then return true end
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

-- Original tools.lua findfears: cardinal adjacency, parameter counts and tie search.
function RW_FindFears(world,id,targets)
    local entity=world.entities[id]
    if not entity then return false,"None",0 end
    local names={"Right","Up","Left","Down"}
    local dirs={Right=0,Up=1,Left=2,Down=3}
    local vectors={{1,0},{0,-1},{-1,0},{0,1}}
    local dir=dirs[entity.direction] or 4
    local scores,maxfear,resultdir={},0,4
    for j=0,3 do
        local i=((dir+2+j)%4)+1
        local v=vectors[i];local x,y=entity.x+v[1],entity.y+v[2]
        local occupied=false;local found={}
        for other_id,other in pairs(world.entities) do
            if other_id>0 and other.x==x and other.y==y then
                occupied=true
                if other_id~=id then found[other.class=="text" and "@text" or other.archetype]=true end
            end
        end
        local amount=0
        for _,target in ipairs(targets) do
            if (target=="@empty" and not occupied) or found[target] then amount=amount+1 end
        end
        scores[i]=amount
        if amount>0 then resultdir=(i+1)%4;maxfear=math.max(maxfear,amount) end
    end
    if maxfear==0 then return false,"None",0 end
    local tied=0
    for i=1,4 do if scores[i]>=maxfear then tied=tied+1 else scores[i]=0 end end
    if tied>1 then
        resultdir=dir
        -- Native emptydir may be unset: check then probes its empty source cell
        -- with ndirs[5]={0,0}, retaining a non-displacing None intention.
        if dir==4 and entity.class=="empty" then
            local solid=(has_capability(world,entity,"block_entry") or has_capability(world,entity,"pull"))
                and not has_capability(world,entity,"push") and not has_capability(world,entity,"swap")
            if has_capability(world,entity,"phantom")
                or (has_capability(world,entity,"weak") and not has_capability(world,entity,"safe")) then solid=false end
            if not solid then return true,"None",maxfear end
        end
        for tests=0,3 do
            local v=vectors[resultdir+1]
            local problem=scores[resultdir+1]==1 or not v
            if not problem then
                -- The original check probes geometry before REVERSE and STILL.
                local probe=RW_ResolveMovement(world,{type="move",entity_id=id,
                    dx=v[1],dy=v[2],no_reverse=true,fear_probe=true})
                problem=#probe.changes==0 and #(probe.destructions or {})==0
            end
            if not problem then return true,names[resultdir+1],maxfear end
            if tests==0 then resultdir=(resultdir+3)%4
            elseif tests==1 then resultdir=(resultdir+2)%4
            elseif tests==2 then resultdir=(resultdir+1)%4 end
        end
        return false,"None",maxfear
    end
    return true,names[resultdir+1],maxfear
end

function RW_ResolveFear(world,targets)
    local working={};for k,v in pairs(world) do working[k]=v end
    working.entities={}
    local ids,tasks={},{}
    for id,entity in pairs(world.entities) do
        local copy={};for k,v in pairs(entity) do copy[k]=v end
        working.entities[id]=copy;ids[#ids+1]=id
    end
    table.sort(ids)
    working.trait_counts={};for id,counts in pairs(world.trait_counts or {}) do working.trait_counts[id]=counts end
    local intentions={};for id,list in pairs(targets) do if type(id)=="number" then intentions[id]=list end end
    for index,cell in ipairs(targets.empty_cells or {}) do
        local id=-index
        working.entities[id]={id=id,kind="object",class="empty",x=cell.x,y=cell.y,
            direction=cell.direction or "None",behaviors=cell.behaviors or {}}
        working.trait_counts[id]=cell.trait_counts or {};ids[#ids+1]=id;intentions[id]=cell.targets
    end
    -- Collect every intention against the same snapshot, as original take 7 does.
    for _,id in ipairs(ids) do
        local entity=working.entities[id]
        if intentions[id] and not has_capability(working,entity,"sleep") then
            local valid,dir,count=RW_FindFears(working,id,intentions[id])
            if valid and count>0 and dir~="None" then tasks[id]={direction=dir,count=count} end
        end
    end
    local vectors={Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}}
    local deaths,records={},{}
    for _,id in ipairs(ids) do
        local task=tasks[id]
        if task then
            for impulse=1,task.count do
                local entity=working.entities[id];if not entity then break end
                entity.direction=task.direction
                local v=vectors[task.direction]
                -- take 7 checks STILL/locks before queuing the reversed intention.
                if immobile(working,entity,v[1],v[2]) then break end
                local part=RW_ResolveMovement(working,{type="move",entity_id=id,dx=v[1],dy=v[2]})
                for _,change in ipairs(part.changes) do
                    local e=working.entities[change.entity_id]
                    if change.kind=="move" then e.x,e.y,e.direction=change.to.x,change.to.y,change.to.direction
                    elseif change.kind=="direction" then e.direction=change.to end
                end
                for _,death in ipairs(part.destructions or {}) do
                    if death.entity_id>0 then deaths[#deaths+1]=death end
                    records[death.entity_id]=death;working.entities[death.entity_id]=nil
                end
            end
        end
    end
    local changes={}
    for _,id in ipairs(ids) do
        if id>0 then
        local before=world.entities[id];local after=working.entities[id] or records[id]
        if before.x~=after.x or before.y~=after.y then
            changes[#changes+1]={kind="move",entity_id=id,
                from={x=before.x,y=before.y,direction=before.direction or "None"},
                to={x=after.x,y=after.y,direction=after.direction or "None"}}
        elseif (before.direction or "None")~=(after.direction or "None") then
            changes[#changes+1]={kind="direction",entity_id=id,from=before.direction or "None",to=after.direction or "None"}
        end
        end
    end
    return {consumes_turn=true,changes=changes,destructions=deaths,reason="fear"}
end

-- FOLLOW turns toward a nearest target; it never adds displacement itself.
function RW_ResolveFollow(world,targets)
    local ids=unit_ids(world)
    local dirs={Right=0,Up=1,Left=2,Down=3}
    local names={"Right","Up","Left","Down"}
    local changes={}
    for _,id in ipairs(ids) do
        local entity=world.entities[id]
        if targets[id] and #targets[id]>0 and not has_capability(world,entity,"sleep") then
            local dir=dirs[entity.direction] or 4
            local distance,targetdir=9999,-1
            local priority,high,highdir,prioritydir=-1,-1,-1,-1
            local highest,counterclockwise,found=false,false,false
            local followed=entity.followed or -1
            for _,target in ipairs(targets[id]) do
                for _,other_id in ipairs(ids) do
                    local other=world.entities[other_id]
                    local name=other.class=="text" and "@text" or other.archetype
                    if other_id~=id and name==target then
                        local dx,dy=other.x-entity.x,other.y-entity.y
                        local dist=math.abs(dx)+math.abs(dy)
                        local facing
                        if math.abs(dx)<=math.abs(dy) then facing=dy>=0 and 3 or 1
                        else facing=dx>0 and 0 or 2 end
                        if dist<=distance and dist>0 then
                            distance,targetdir=dist,facing
                            if dist==1 then
                                local identity=other.back_identity or other_id
                                if followed==identity then found=true;break end
                                priority,prioritydir=identity,facing
                                if facing==dir then high,highdir=identity,facing;highest=true
                                elseif not highest then
                                    if facing==(dir+1)%4 then high,highdir=identity,facing;counterclockwise=true
                                    elseif not counterclockwise and facing==(dir+3)%4 then high,highdir=identity,facing end
                                end
                            end
                        end
                    end
                end
                if found then break end
            end
            if not found then
                if high>-1 then followed,targetdir=high,highdir
                elseif priority>-1 then followed,targetdir=priority,prioritydir
                elseif followed>-1 then followed=-1 end
            end
            if followed~=(entity.followed or -1) then
                changes[#changes+1]={kind="followed",entity_id=id,from=entity.followed,to=followed}
            end
            if targetdir>=0 and names[targetdir+1]~=entity.direction then
                changes[#changes+1]={kind="direction",entity_id=id,from=entity.direction or "None",to=names[targetdir+1]}
            end
        end
    end
    return {consumes_turn=true,changes=changes,reason="follow"}
end

-- TELE bypasses collision, preserves facing and moves each rider at most once.
function RW_ResolveTele(world,suppressed)
    if suppressed~=nil then
        if type(suppressed)~="table" then return nil,"invalid_tele_suppression" end
        for id,value in pairs(suppressed) do
            if value~=true or not world.entities[id] then return nil,"invalid_tele_suppression" end
        end
    end
    local ids,sources=unit_ids(world),{}
    local positions={}
    for _,id in ipairs(ids) do local e=world.entities[id]
        positions[id]={x=e.x,y=e.y}
        if has_capability(world,e,"tele") then sources[#sources+1]=id end
    end
    local function name(e) return e.class=="text" and "@text" or e.archetype end
    local function same_layer(a,b) return has_capability(world,a,"float")==has_capability(world,b,"float") end
    local state=world.random_state or 1;local original_state=state
    local moved={}
    for _,source_id in ipairs(sources) do
        local source=world.entities[source_id];local at=positions[source_id]
        local targets={}
        for _,id in ipairs(ids) do local p=positions[id]
            if p.x==at.x and p.y==at.y then targets[#targets+1]=id end
        end
        for _,id in ipairs(targets) do local target=world.entities[id]
            if id~=source_id and not moved[id] and not (suppressed and suppressed[id]) and name(target)~=name(source)
                and not has_capability(world,target,"still") and same_layer(source,target) then
                local destinations={}
                for _,other_id in ipairs(sources) do
                    if other_id~=source_id and name(world.entities[other_id])==name(source) then destinations[#destinations+1]=other_id end
                end
                if #destinations>0 then
                    state=(state*48271)%2147483647
                    local destination=positions[destinations[state%#destinations+1]]
                    positions[id]={x=destination.x,y=destination.y};moved[id]=true
                end
            end
        end
    end
    local changes={}
    for _,id in ipairs(ids) do local e,p=world.entities[id],positions[id]
        if e.x~=p.x or e.y~=p.y then changes[#changes+1]={kind="move",entity_id=id,
            from={x=e.x,y=e.y,direction=e.direction or "None"},
            to={x=p.x,y=p.y,direction=e.direction or "None"}} end
    end
    return {consumes_turn=true,changes=changes,reason="tele",
        random_state=state~=original_state and {from=original_state,to=state} or nil}
end

function RW_ResolveHold(world)
    local ids,holders,positions,held,first=unit_ids(world),{},{},{},{}
    for _,id in ipairs(ids) do local e=world.entities[id]
        local identity=e.back_identity or id
        first[identity]=first[identity] or id
        positions[id]={x=e.x,y=e.y};held[id]=e.holder or 0
        if has_capability(world,e,"hold") then holders[identity]=true end
    end
    for _,id in ipairs(ids) do local source=world.entities[id]
        if has_capability(world,source,"hold") then
            local identity=source.back_identity or id
            for _,other in ipairs(ids) do local e=world.entities[other]
                if other~=id and source.x==e.x and source.y==e.y and same_layer(world,source,e) then held[other]=identity end
            end
        end
    end
    for _,id in ipairs(ids) do local holder=held[id]
        if holder~=0 then
            if not holders[holder] then held[id]=0
            else
                local source_id=first[holder]
                local p,target=positions[id],positions[source_id];local e=world.entities[id]
                local dx,dy=target.x-p.x,target.y-p.y
                local locked=held_by_level(world,e) or has_capability(world,e,"still")
                if (dx==0)~=(dy==0) then
                    local rx,ry=reverse_vector(world,e,dx,dy)
                    local key=rx>0 and "lockedright" or rx<0 and "lockedleft" or ry<0 and "lockedup" or "lockeddown"
                    locked=locked or has_capability(world,e,key)
                end
                if locked then held[id]=0
                else positions[id]={x=target.x,y=target.y}
                    if not same_layer(world,e,world.entities[source_id]) then held[id]=0 end
                end
            end
        end
    end
    local changes={}
    for _,id in ipairs(ids) do local e,p=world.entities[id],positions[id]
        if e.x~=p.x or e.y~=p.y then changes[#changes+1]={kind="move",entity_id=id,from={x=e.x,y=e.y,direction=e.direction},to={x=p.x,y=p.y,direction=e.direction}} end
        if (e.holder or 0)~=held[id] then changes[#changes+1]={kind="holder",entity_id=id,from=e.holder,to=held[id]} end
    end
    return {consumes_turn=true,changes=changes,reason="hold"}
end


-- BACK motion primitive for explicitly selected historical frames. Activation,
-- eligibility and age selection belong to the future status/scheduler integration.
-- Conversion rows deliberately fail until their create/remove playback is ready.
local function back_services(services,names)
    if services~=nil and type(services)~="table" then return nil,"invalid_back_services" end
    local resolved=services or {preview=RW_PreviewPlan,frame=RW_GetBackFrame,
        rows=RW_BackHistoryRows,restore=RW_BackRestoredEntity,identity=RW_GetBackIdentity}
    for _,name in ipairs(names) do
        if type(resolved[name])~="function" then return nil,"missing_back_service_"..name end
    end
    return resolved
end

function RW_PlanBackMotion(world,selections,paradox)
    if type(world)~="table" or type(world.entities)~="table" then return nil,"invalid_world" end
    if type(world.width)~="number" or world.width%1~=0 or world.width<1
        or type(world.height)~="number" or world.height%1~=0 or world.height<1 then return nil,"invalid_world" end
    if world.infinite_loop then return nil,"infinite_loop_undo_only" end
    if world.too_complex then return nil,"too_complex_undo_only" end
    local function list(v)
        if type(v)~="table" then return false end
        local n=0;for k in pairs(v) do if type(k)~="number" or k<1 or k%1~=0 then return false end;n=n+1 end
        return n==#v
    end
    if not list(selections) or (paradox~=nil and type(paradox)~="table") then return nil,"invalid_back_selection" end
    paradox=paradox or {}
    local directions={Left=true,Up=true,Right=true,Down=true,Mid=true,None=true}
    local function point(x,y,d)
        return type(x)=="number" and x%1==0 and type(y)=="number" and y%1==0
            and x>=1 and x<=world.width and y>=1 and y<=world.height and directions[d]==true
    end
    local changes,suppressed,seen,history={},{},{},{}
    for _,selection in ipairs(selections) do
        if type(selection)~="table" then return nil,"invalid_back_selection" end
        local id=selection.entity_id;local entity=world.entities[id]
        if type(id)~="number" or id%1~=0 or id<1 or not entity or seen[id] then return nil,"invalid_back_identity" end
        seen[id]=true
        local before,record=selection.before,selection.record
        if type(before)~="table" or before.id~=id or not point(before.x,before.y,before.direction or "None") then return nil,"invalid_back_source" end
        if type(record)~="table" or not list(record.phases) or #record.phases==0 then return nil,"back_history_unavailable" end
        local x,y,d=before.x,before.y,before.direction or "None"
        local rows={}
        for _,phase in ipairs(record.phases) do
            if type(phase)~="table" or not list(phase.changes) then return nil,"invalid_back_history" end
            if phase.motion_history~=nil and not list(phase.motion_history) then return nil,"invalid_back_history" end
            for _,op in ipairs(phase.motion_history or phase.changes) do
                if type(op)~="table" then return nil,"invalid_back_history" end
                if op.entity_id==id then
                    if op.kind=="move" then
                        local from,to=op.from,op.to
                        if type(from)~="table" or type(to)~="table" or from.x~=x or from.y~=y
                            or (from.direction~=nil and from.direction~=d) then return nil,"stale_back_source" end
                        local nd=to.direction or d
                        if not point(to.x,to.y,nd) then return nil,"invalid_back_history" end
                        rows[#rows+1]={x=x,y=y,direction=d,moved=x~=to.x or y~=to.y}
                        x,y,d=to.x,to.y,nd
                    elseif op.kind=="direction" then
                        if op.from~=d then return nil,"stale_back_source" end
                        if not directions[op.to] then return nil,"invalid_back_history" end
                        rows[#rows+1]={x=x,y=y,direction=d,moved=false};d=op.to
                    elseif op.kind=="create" or op.kind=="delete" or op.kind=="retype" or op.kind=="transform" then
                        return nil,"back_conversion_history_pending"
                    elseif op.kind~="back_init" and op.kind~="broken" and op.kind~="holder" and op.kind~="followed" then
                        return nil,"invalid_back_history"
                    end
                end
            end
        end
        x,y,d=entity.x,entity.y,entity.direction or "None"
        if not point(x,y,d) then return nil,"invalid_back_identity" end
        if paradox[id]==nil then
            for index=#rows,1,-1 do
                local row=rows[index]
                local from={x=x,y=y,direction=d}
                if row.moved then x,y=row.x,row.y end
                d=row.direction;suppressed[id]=true
                if from.x~=x or from.y~=y or from.direction~=d then
                    history[#history+1]={kind="move",entity_id=id,from=from,to={x=x,y=y,direction=d}}
                end
            end
        end
        if x~=entity.x or y~=entity.y then
            changes[#changes+1]={kind="move",entity_id=id,
                from={x=entity.x,y=entity.y,direction=entity.direction or "None"},to={x=x,y=y,direction=d}}
        elseif d~=(entity.direction or "None") then
            changes[#changes+1]={kind="direction",entity_id=id,from=entity.direction or "None",to=d}
        end
    end
    table.sort(changes,function(a,b) return a.entity_id<b.entity_id end)
    return {consumes_turn=true,changes=changes,tele_suppressed=suppressed,reason="back",motion_history=#history>0 and history or nil}
end


-- Explicit native buffer counts include the current/open frame. Do not derive
-- this count from the capped local session history until pruning is integrated.
function RW_BackFrameIndex(back_init,frame_count,dead)
    if type(back_init)~="number" or back_init%1~=0 or back_init<0
        or type(frame_count)~="number" or frame_count%1~=0 or frame_count<0
        or (dead~=nil and type(dead)~="boolean") then return nil,"invalid_back_clock" end
    local index=(frame_count-back_init)*2+1
    if back_init==0 or dead or index>frame_count then return nil,"back_inactive" end
    -- A newly set clock may select a nonpositive, absent Lua table index. The
    -- original still marks updateundo=true; preserve that distinction for callers.
    return index
end

-- The caller supplies the complete current-frame set of eligible real identities;
-- rule queries, status timing and lifecycle inheritance remain scheduler concerns.
function RW_PlanBackStatus(world,eligible,frame_count)
    if type(world)~="table" or type(world.entities)~="table" then return nil,"invalid_world" end
    if world.infinite_loop then return nil,"infinite_loop_undo_only" end
    if world.too_complex then return nil,"too_complex_undo_only" end
    if type(eligible)~="table" or type(frame_count)~="number" or frame_count%1~=0 or frame_count<0 then return nil,"invalid_back_clock" end
    for id,value in pairs(eligible) do
        if value~=true or not world.entities[id] then return nil,"invalid_back_identity" end
    end
    local ids={};for id in pairs(world.entities) do ids[#ids+1]=id end;table.sort(ids)
    local changes={}
    for _,id in ipairs(ids) do
        local old=world.entities[id].back_init;local clock=old or 0
        if type(clock)~="number" or clock%1~=0 or clock<0 then return nil,"invalid_back_clock" end
        local next_clock=eligible[id] and (clock==0 and frame_count+1 or clock) or 0
        if next_clock~=clock then changes[#changes+1]={kind="back_init",entity_id=id,from=old,to=next_clock} end
    end
    return {consumes_turn=true,changes=changes,reason="back_status"}
end


-- Select per-unit BACK frames from the native-clock ledger and the current
-- pre-BACK phase prefix. Eligibility and status refresh are supplied by the caller.
function RW_PlanBackHistoryMotion(session,current_plan,eligible,paradox,services,instances)
    if type(session)~="table" or type(eligible)~="table" then return nil,"invalid_back_selection" end
    local count=session.back_frame_count
    if count==nil then return nil,"back_history_unavailable" end
    local api,reason=back_services(services,{"preview","frame","rows","restore","identity"})
    if not api then return nil,reason end
    local world,reason=api.preview(session.world,current_plan)
    if not world then return nil,reason end
    local ids={}
    for id,value in pairs(eligible) do
        if value~=true or not world.entities[id] then return nil,"invalid_back_identity" end
        ids[#ids+1]=id
    end
    local rank={};for index,id in ipairs(unit_ids(world)) do rank[id]=index end
    table.sort(ids,function(a,b) return rank[a]<rank[b] end)
    if instances~=nil then
        if type(instances)~="table" then return nil,"invalid_back_instances" end
        local n,seen=0,{}
        for key,id in pairs(instances) do
            if type(key)~="number" or key%1~=0 or key<1 or eligible[id]~=true then return nil,"invalid_back_instances" end
            n=n+1;seen[id]=true
        end
        if n~=#instances then return nil,"invalid_back_instances" end
        for _,id in ipairs(ids) do if not seen[id] then return nil,"invalid_back_instances" end end
    end
    local selections,retain,selected={},false,{}
    for _,id in ipairs(ids) do
        local index,why=RW_BackFrameIndex(world.entities[id].back_init or 0,count,false)
        if index~=nil then
            retain=true
            local record,before=api.frame(session,index,current_plan)
            if record then
                selections[#selections+1]={entity_id=id,before_world=before,record=record}
                selected[id]=true
            elseif before~="back_frame_absent" then return nil,before end
        elseif why~="back_inactive" then return nil,why end
    end
    local order
    if instances then order={};for _,id in ipairs(instances) do if selected[id] then order[#order+1]=id end end end
    local plan,why=RW_PlanBackFramePlayback(world,selections,paradox,api,order)
    if not plan then return nil,why end
    plan.back_retain=retain
    return plan
end


-- Identity-preserving conversion playback. Branch copies and repeated lifecycle
-- rows need source/handle provenance and remain explicit unsupported history.
function RW_PlanBackPlayback(world,selections,paradox,services)
    -- Reuse the motion primitive's input/terminal checks before examining records.
    local checked,why=RW_PlanBackMotion(world,{},paradox)
    if not checked then return nil,why end
    local api,why=back_services(services,{"preview","restore"})
    if not api then return nil,why end
    if type(selections)~="table" then return nil,"invalid_back_selection" end
    local motion,restores,seen={},{},{}
    local function list(value)
        if type(value)~="table" then return false end
        local count=0;for key in pairs(value) do
            if type(key)~="number" or key%1~=0 or key<1 then return false end
            count=count+1
        end
        return count==#value
    end
    if not list(selections) then return nil,"invalid_back_selection" end
    local function copy(value)
        if type(value)~="table" then return value end
        local result={};for k,v in pairs(value) do result[k]=copy(v) end;return result
    end
    local function equal(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~="table" then return a==b end
        for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    for _,selection in ipairs(selections) do
        if type(selection)~="table" or not world.entities[selection.entity_id] or seen[selection.entity_id] then return nil,"invalid_back_identity" end
        local id=selection.entity_id;seen[id]=true
        if type(selection.before)~="table" or selection.before.id~=id
            or type(selection.record)~="table" or not list(selection.record.phases) or #selection.record.phases==0 then return nil,"invalid_back_history" end
        local cursor,source=copy(selection.before),nil
        for _,phase in ipairs(selection.record.phases) do
            if type(phase)~="table" or not list(phase.changes) then return nil,"invalid_back_history" end
            local recorded=false
            if phase.back_conversions~=nil then
                if not list(phase.back_conversions) then return nil,"invalid_back_history" end
                for _,event in ipairs(phase.back_conversions) do
                    if type(event)~="table" or not list(event.product_ids) or type(event.removed)~="boolean" then return nil,"invalid_back_history" end
                    for _,product in ipairs(event.product_ids) do if product==id then
                        if type(event.source)~="table" or event.source.id~=id then return nil,"back_conversion_history_pending" end
                        if not event.removed then return nil,"invalid_back_history" end
                        if source or recorded then return nil,"back_conversion_history_pending" end
                        if not equal(event.source,cursor) then return nil,"stale_back_source" end
                        source=copy(event.source);recorded=true
                    end end
                end
            end
            for _,op in ipairs(phase.changes) do
                if type(op)~="table" then return nil,"invalid_back_history" end
                if op.entity_id==id then
                    if op.kind=="create" or op.kind=="delete" or op.kind=="back_restore" then return nil,"back_conversion_history_pending" end
                    if (op.kind=="transform" or op.kind=="retype") and not recorded then
                        if source then return nil,"back_conversion_history_pending" end
                        source=copy(cursor)
                    end
                    local temporary={width=world.width,height=world.height,next_entity_id=world.next_entity_id,entities={[id]=cursor}}
                    local after,err=api.preview(temporary,{consumes_turn=true,changes={op}})
                    if not after then return nil,err end
                    cursor=after.entities[id]
                end
            end
        end
        if source then
            if not paradox or paradox[id]==nil then
                local current=world.entities[id]
                restores[#restores+1]={kind="back_restore",entity_id=id,from=copy(current),source=source,to=api.restore(source,current)}
            end
        else motion[#motion+1]=selection end
    end
    local plan,err=RW_PlanBackMotion(world,motion,paradox)
    if not plan then return nil,err end
    for _,restore in ipairs(restores) do plan.changes[#plan.changes+1]=restore end
    table.sort(plan.changes,function(a,b) return a.entity_id<b.entity_id end)
    for _,row in ipairs(plan.motion_history or {}) do row.before_change=#plan.changes+1 end
    return plan
end


-- Replay complete native logical-identity frames against unique current instances.
-- Multiple matching create/remove rows deliberately multiply restored products.
function RW_PlanBackFramePlayback(world,selections,paradox,services,instances)
    local checked,reason=RW_PlanBackMotion(world,{},paradox)
    if not checked then return nil,reason end
    local api,reason=back_services(services,{"preview","rows","restore","identity"})
    if not api then return nil,reason end
    if type(selections)~="table" then return nil,"invalid_back_selection" end
    local count=0;for key in pairs(selections) do
        if type(key)~="number" or key%1~=0 or key<1 then return nil,"invalid_back_selection" end
        count=count+1
    end
    if count~=#selections then return nil,"invalid_back_selection" end
    local function copy(v) if type(v)~="table" then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
    paradox=paradox or {}
    local ordered,seen={},{}
    for _,selection in ipairs(selections) do
        if type(selection)~="table" or not world.entities[selection.entity_id] or seen[selection.entity_id] then return nil,"invalid_back_identity" end
        seen[selection.entity_id]=true;ordered[#ordered+1]=selection
    end
    if world.unit_order then
        local valid,why=api.preview(world,{consumes_turn=true,changes={}})
        if not valid then return nil,why end
    end
    local rank={};for index,id in ipairs(unit_ids(world)) do rank[id]=index end
    table.sort(ordered,function(a,b) return rank[a.entity_id]<rank[b.entity_id] end)
    local unique=ordered
    if instances~=nil then
        if type(instances)~="table" then return nil,"invalid_back_instances" end
        local selected={};for _,selection in ipairs(ordered) do selected[selection.entity_id]=selection end
        local n,present=0,{}
        for key,id in pairs(instances) do
            if type(key)~="number" or key%1~=0 or key<1 or not selected[id] then return nil,"invalid_back_instances" end
            n=n+1;present[id]=true
        end
        if n~=#instances then return nil,"invalid_back_instances" end
        for id in pairs(selected) do if not present[id] then return nil,"invalid_back_instances" end end
        ordered={};for _,id in ipairs(instances) do ordered[#ordered+1]=selected[id] end
    end
    local changes,suppressed,next_id={}, {},world.next_entity_id
    local history,positions,retired_ids={},{},{}
    for _,selection in ipairs(ordered) do
        local id=selection.entity_id;local entity=world.entities[id]
        if not retired_ids[id] then
        local rows,why=api.rows(selection.before_world,selection.record)
        if not rows then return nil,why end
        local identity=api.identity(entity)
        local position=positions[id] or entity
        local x,y,d=position.x,position.y,position.direction
        local products,retired,path={},false,{}
        for _,row in ipairs(rows) do
            if row.identity==identity then
                if row.kind=="update" and paradox[identity]==nil then
                    local from={x=x,y=y,direction=d}
                    if row.moved then x,y=row.x,row.y end
                    d=row.direction;suppressed[id]=true
                    if from.x~=x or from.y~=y or from.direction~=d then
                        path[#path+1]={kind="move",entity_id=id,from=from,to={x=x,y=y,direction=d}}
                    end
                elseif row.kind=="create" and paradox[row.base]==nil then
                    retired=true
                    for _,remove in ipairs(rows) do
                        if remove.kind=="remove" and remove.identity==row.base then products[#products+1]=remove.source end
                    end
                end
            end
        end
        if retired then
            retired_ids[id]=true;positions[id]=nil
            -- Queued actions/TELE marks belong to the retired native handle.
            suppressed[id]=nil
            if #products==0 then
                changes[#changes+1]={kind="delete",entity_id=id,from=copy(entity)}
            else
                local source=products[1]
                changes[#changes+1]={kind="back_restore",entity_id=id,from=copy(entity),source=copy(source),to=api.restore(source,entity)}
                for index=2,#products do
                    if type(next_id)~="number" or next_id%1~=0 or next_id<1 or next_id>=9007199254740991 or world.entities[next_id] then return nil,"invalid_back_frontier" end
                    local source=products[index]
                    local product=api.restore(source,{id=next_id,x=entity.x,y=entity.y})
                    changes[#changes+1]={kind="create",entity_id=next_id,to=product,back_source_identity=api.identity(product)}
                    next_id=next_id+1
                end
            end
        else
            for _,row in ipairs(path) do history[#history+1]=row end
            positions[id]={x=x,y=y,direction=d}
        end
        end
    end
    for _,selection in ipairs(unique) do
        local id=selection.entity_id;local entity=world.entities[id];local position=positions[id]
        if position then
            local x,y,d=position.x,position.y,position.direction
            if x~=entity.x or y~=entity.y then
                changes[#changes+1]={kind="move",entity_id=id,from={x=entity.x,y=entity.y,direction=entity.direction},to={x=x,y=y,direction=d}}
            elseif d~=entity.direction then
                changes[#changes+1]={kind="direction",entity_id=id,from=entity.direction,to=d}
            end
        end
    end
    local retained={};for _,row in ipairs(history) do if not retired_ids[row.entity_id] then retained[#retained+1]=row end end;history=retained
    local sequence={}
    for _,op in ipairs(changes) do if op.kind=="back_restore" or op.kind=="create" or op.kind=="delete" then sequence[#sequence+1]=op.entity_id end end
    -- Native create/remove is immediate, while update/updatedir actions are
    -- dispatched by doupdate only after every BACK selection has been processed.
    for _,row in ipairs(history) do row.before_change=#changes+1 end
    local plan={consumes_turn=true,changes=changes,tele_suppressed=suppressed,reason="back",unit_sequence=#sequence>0 and sequence or nil,motion_history=#history>0 and history or nil}
    if next_id~=world.next_entity_id then plan.id_allocation={from=world.next_entity_id,to=next_id} end
    local after,why=api.preview(world,plan)
    if not after then return nil,why end
    return plan
end
