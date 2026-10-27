-- world.lua
-- RuleWorld M2: World state, atomic commit, history

local HISTORY_LIMIT = 128

-- Intrinsic Object/Text state, independent of rule-derived traits.
local DIRECTIONS = {
    Left = true, Up = true, Right = true,
    Down = true, Mid = true, None = true
}

local function valid_direction(value)
    return type(value) == "string" and DIRECTIONS[value] == true
end

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

local function rejected(reason)
    return {
        accepted = false,
        changed = false,
        reason = reason,
        changes = {}
    }
end

local function is_integer(n)
    return type(n) == "number"
        and n == n
        and n % 1 == 0
end

-- Plans and creation specifications use dense ordered operation lists.
local function is_list(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if not is_integer(key) or key < 1 then return false end
        count = count + 1
    end
    return count == #value
end

local MAX_ID = 9007199254740991
local function valid_id(id)
    return is_integer(id) and id > 0 and id <= MAX_ID
end

local function same_state(a, b, seen)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    seen = seen or {}
    if seen[a] then return seen[a] == b end
    seen[a] = b
    for key, value in pairs(a) do
        if not same_state(value, b[key], seen) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function valid_new_entity(world, entity, id)
    if not is_integer(world.width) or not is_integer(world.height)
        or world.width < 1 or world.height < 1
        or type(entity) ~= "table" or entity.id ~= id
        or entity.kind ~= "object"
        or (entity.class ~= "object" and entity.class ~= "text")
        or not valid_direction(entity.direction)
        or not is_integer(entity.x) or not is_integer(entity.y)
        or entity.x < 1 or entity.x > world.width
        or entity.y < 1 or entity.y > world.height
        or entity.traits ~= nil or entity.behaviors ~= nil or entity.symbol ~= nil then
        return false
    end
    if entity.level_link ~= nil then
        local link = entity.level_link
        if type(link) ~= "table"
            or (link.source_type ~= nil and (type(link.source_type) ~= "string" or link.source_type == ""))
            or (link.target ~= "child" and link.target ~= "parent")
            or (link.target == "child" and (type(link.definition_id) ~= "string"
                or link.definition_id == "")) then return false end
    end
    if entity.class == "text" then
        return type(entity.text) == "table"
            and type(entity.text.name) == "string" and entity.text.name ~= ""
            and entity.archetype == nil
    end
    return entity.text == nil and (entity.archetype == nil
        or (type(entity.archetype) == "string" and entity.archetype ~= ""))
end

-- A frontier is part of the authoritative world. Never reconstruct it after
-- deletion: IDs cannot be recycled within a timeline. Undo restores it.
local function valid_frontier(world)
    if not valid_id(world.next_entity_id) then return false end
    for id, entity in pairs(world.entities) do
        if not valid_id(id) or type(entity) ~= "table"
            or entity.id ~= id or id >= world.next_entity_id then
            return false
        end
    end
    return true
end

local function valid_board_offset(value)
    return type(value) == "table" and is_integer(value.x) and is_integer(value.y)
        and math.abs(value.x) <= MAX_ID and math.abs(value.y) <= MAX_ID
        and valid_direction(value.direction)
end

-- Validate against the ORIGINAL world, independently of operation order.
-- Existing move/direction/transform writes may coexist with one terminal delete.
local function validate_plan(world, plan)
    if type(plan) ~= "table"
        or type(plan.consumes_turn) ~= "boolean"
        or not is_list(plan.changes) then
        return false, "invalid_plan"
    end
    if plan.board_shift ~= nil then
        local shift = plan.board_shift
        local current = world.board_offset or {x=0,y=0,direction="None"}
        if type(shift) ~= "table" or not valid_board_offset(shift.from)
            or not valid_board_offset(shift.to) then return false,"invalid_board_shift" end
        if not same_state(current,shift.from) then return false,"stale_board_shift" end
    end
    if not plan.consumes_turn then
        if #plan.changes ~= 0 or plan.id_allocation ~= nil or plan.board_shift ~= nil then
            return false, "invalid_no_turn_plan"
        end
        return true
    end

    local seen, created = {}, {}
    local create_count = 0
    for _, change in ipairs(plan.changes) do
        if type(change) ~= "table"
            or (change.kind ~= "move" and change.kind ~= "transform"
                and change.kind ~= "direction" and change.kind ~= "create"
                and change.kind ~= "delete" and change.kind ~= "retype") then
            return false, "invalid_operation"
        end
        local id = change.entity_id
        if not valid_id(id) then return false, "invalid_entity_id" end
        local entity = world.entities[id]
        seen[id] = seen[id] or {}
        if seen[id][change.kind] then return false, "duplicate_operation" end
        seen[id][change.kind] = true

        if change.kind == "create" then
            if entity then return false, "entity_already_exists" end
            if change.from ~= nil or not valid_new_entity(world, change.to, id) then
                return false, "invalid_creation"
            end
            created[id] = true
            create_count = create_count + 1
        else
            -- New entities are fully specified by create.to; they cannot be
            -- moved, transformed or deleted in the same original-world plan.
            if not entity then return false, "unknown_entity" end
            if change.kind == "direction"
                or (change.kind == "move" and type(change.to) == "table"
                    and change.to.direction ~= nil) then
                if seen[id].direction_write then return false, "duplicate_direction" end
                seen[id].direction_write = true
            end

            if change.kind == "retype" then
                if not same_state(entity,change.from) or not valid_new_entity(world,change.to,id)
                    or same_state(change.from,change.to) or change.to.x ~= entity.x or change.to.y ~= entity.y
                    or change.to.direction ~= entity.direction or not same_state(change.to.level_link,entity.level_link) then
                    return false,"invalid_or_stale_retype"
                end
            elseif change.kind == "delete" then
                if type(change.from) ~= "table" or change.to ~= nil then
                    return false, "invalid_deletion"
                end
                if not same_state(entity, change.from) then
                    return false, "stale_deletion"
                end
            elseif change.kind == "direction" then
                if not valid_direction(change.from) or not valid_direction(change.to) then
                    return false, "invalid_direction"
                end
                if (entity.direction or "None") ~= change.from then
                    return false, "stale_direction"
                end
                if change.from == change.to then return false, "redundant_direction" end
            elseif change.kind == "move" then
                if type(change.from) ~= "table" or type(change.to) ~= "table" then
                    return false, "invalid_operation"
                end
                if entity.x ~= change.from.x or entity.y ~= change.from.y then
                    return false, "stale_operation"
                end
                if not is_integer(change.to.x) or not is_integer(change.to.y) then
                    return false, "invalid_position"
                end
                if change.from.direction ~= nil or change.to.direction ~= nil then
                    if not valid_direction(change.from.direction)
                        or not valid_direction(change.to.direction) then
                        return false, "invalid_direction"
                    end
                    if (entity.direction or "None") ~= change.from.direction then
                        return false, "stale_direction"
                    end
                end
            else
                if entity.kind ~= "object" or entity.class == "text"
                    or type(change.from) ~= "string" or type(change.to) ~= "string"
                    or change.to == "" then
                    return false, "invalid_transformation"
                end
                if entity.archetype ~= change.from then return false, "stale_transformation" end
                if change.to == change.from then return false, "redundant_transformation" end
            end
        end
    end

    for _,operations in pairs(seen) do
        if operations.retype then
            for kind in pairs(operations) do if kind ~= "retype" then return false,"conflicting_retype" end end
        end
    end
    if create_count == 0 then
        if plan.id_allocation ~= nil then return false, "invalid_id_allocation" end
    else
        if not valid_frontier(world) then return false, "invalid_id_frontier" end
        local allocation = plan.id_allocation
        if type(allocation) ~= "table" or allocation.from ~= world.next_entity_id then
            return false, "stale_id_allocation"
        end
        local next_id = world.next_entity_id + create_count
        if not valid_id(next_id) or allocation.to ~= next_id then
            return false, "invalid_id_allocation"
        end
        for id = allocation.from, allocation.to - 1 do
            if not created[id] then return false, "noncontiguous_entity_ids" end
        end
    end
    return true
end

-- Single application path for Preview and Commit; deletion is terminal even
-- if it precedes a movement/transform in the operation list.
local function apply_plan(world, plan)
    local projected = clone(world)
    for _, change in ipairs(plan.changes) do
        local entity = projected.entities[change.entity_id]
        if change.kind == "create" then
            projected.entities[change.entity_id] = clone(change.to)
        elseif change.kind == "retype" then
            projected.entities[change.entity_id] = clone(change.to)
        elseif change.kind == "move" then
            entity.x, entity.y = change.to.x, change.to.y
            entity.direction = change.to.direction or entity.direction
        elseif change.kind == "direction" then
            entity.direction = change.to
        elseif change.kind == "transform" then
            entity.archetype = change.to
        end
    end
    for _, change in ipairs(plan.changes) do
        if change.kind == "delete" then projected.entities[change.entity_id] = nil end
    end
    if plan.id_allocation then projected.next_entity_id = plan.id_allocation.to end
    if plan.board_shift then projected.board_offset = clone(plan.board_shift.to) end
    return projected
end

-- Plan constructors allocate only in the returned plan, never in the world.
-- Combine an allocation batch with other operations via plan.changes.
function RW_PlanCreate(world, specifications)
    if type(world) ~= "table" or type(world.entities) ~= "table"
        or not is_integer(world.width) or not is_integer(world.height)
        or world.width < 1 or world.height < 1 or not valid_frontier(world) then
        return nil, "invalid_creation_world"
    end
    if not is_list(specifications) then return nil, "invalid_creation_list" end
    local plan = {consumes_turn = true, changes = {}}
    if #specifications == 0 then return plan end
    if not valid_id(world.next_entity_id + #specifications) then
        return nil, "entity_id_exhausted"
    end
    for index, specification in ipairs(specifications) do
        if type(specification) ~= "table" or specification.id ~= nil then
            return nil, "invalid_creation_specification"
        end
        local entity = clone(specification)
        entity.id = world.next_entity_id + index - 1
        if not valid_new_entity(world, entity, entity.id) then return nil, "invalid_creation" end
        plan.changes[#plan.changes + 1] = {
            kind = "create", entity_id = entity.id, to = entity
        }
    end
    plan.id_allocation = {from = world.next_entity_id,
        to = world.next_entity_id + #specifications}
    return plan
end

function RW_PlanDelete(world, ids)
    if type(world) ~= "table" or type(world.entities) ~= "table" then
        return nil, "invalid_world"
    end
    if not is_list(ids) then return nil, "invalid_deletion_list" end
    local ordered, seen = {}, {}
    for _, id in ipairs(ids) do
        if not valid_id(id) or not world.entities[id] then return nil, "unknown_entity" end
        if seen[id] then return nil, "duplicate_operation" end
        seen[id] = true
        ordered[#ordered + 1] = id
    end
    table.sort(ordered)
    local plan = {consumes_turn = true, changes = {}}
    for _, id in ipairs(ordered) do
        plan.changes[#plan.changes + 1] = {
            kind = "delete", entity_id = id, from = clone(world.entities[id])
        }
    end
    return plan
end

-- Six intrinsic values, stale-plan rejection and atomic Undo.
function RW_DirectionStateSelfTest()
    local s = RW_CreateSession()
    for _, direction in ipairs({"Left", "Up", "Right", "Down", "Mid", "None"}) do
        local original = s
        -- Choose a distinct valid source even for None.
        s.world.entities[1].direction = direction == "None" and "Mid" or "None"
        local before = s.world.entities[1].direction
        local plan = { consumes_turn = true, changes = {
            { kind = "move", entity_id = 1,
                from = {x = 2, y = 2, direction = before},
                to = {x = 2, y = 3, direction = direction} },
            { kind = "transform", entity_id = 1, from = "avatar", to = "crate" }
        } }
        local preview = RW_PreviewPlan(s.world, plan)
        local next_session, result = RW_Commit(s, plan)
        if not preview or not result.accepted
            or preview.entities[1].direction ~= direction
            or next_session.world.entities[1].direction ~= direction
            or s.world.entities[1].direction ~= before then
            return false, "Direction preview/commit mutated source"
        end
        local undone = RW_Undo(next_session)
        if undone.world ~= original.world or #undone.history ~= 0
            or undone.world.entities[1].archetype ~= "avatar"
            or undone.world.entities[1].y ~= 2
            or undone.world.entities[1].direction ~= before then
            return false, "Direction/move/transform Undo failed"
        end
        -- Direction-only turn, including Text.
        local face = { consumes_turn = true, changes = {
            {kind = "direction", entity_id = 6, from = "None", to = "Up"}
        } }
        local faced, facing = RW_Commit(s, face)
        local restored = RW_Undo(faced)
        if not facing.changed or faced.world.entities[6].direction ~= "Up"
            or restored.world.entities[6].direction ~= "None" then
            return false, "Text direction-only Undo failed"
        end
        -- A bad direction must reject an otherwise valid move + transform.
        for _, bad_value in ipairs({"north", "", 1}) do
            local bad = clone(plan)
            bad.changes[1].to.direction = bad_value
            local rejected_session, rejection = RW_Commit(s, bad)
            if rejection.accepted or rejected_session ~= s
                or RW_PreviewPlan(s.world, bad) ~= nil then
                return false, "Invalid direction partially committed"
            end
        end
        local stale = clone(plan)
        stale.changes[1].from.direction = before == "Mid" and "None" or "Mid"
        local unchanged, rejection = RW_Commit(s, stale)
        if rejection.accepted or unchanged ~= s then
            return false, "Stale direction accepted"
        end
        local duplicate = clone(plan)
        duplicate.changes[#duplicate.changes + 1] = {
            kind = "direction", entity_id = 1, from = before, to = "Down"
        }
        local unchanged2, rejection2 = RW_Commit(s, duplicate)
        if rejection2.accepted or unchanged2 ~= s then
            return false, "Competing direction writes accepted"
        end
    end
    return true, "Six-value direction state and atomic Undo passed"
end

-- Public API --------------------------------


local function default_world()
    return {
            width = 12,
            height = 12,
            next_entity_id = 12,

            -- Every entity is an Object. Text is an Object
            -- subclass distinguished by class="text".
            -- Neither class has intrinsic rule-derived traits.
            entities = {
                [1] = {
                    id = 1, kind = "object", direction = "None", class = "object",
                    archetype = "avatar", x = 2, y = 2
                },
                [2] = {
                    id = 2, kind = "object", direction = "None", class = "object",
                    x = 6, y = 3
                },
                [3] = {
                    id = 3, kind = "object", direction = "None", class = "object",
                    x = 6, y = 5
                },
                [4] = {
                    id = 4, kind = "object", direction = "None", class = "object",
                    archetype = "crate", x = 3, y = 2
                },
                [5] = {
                    id = 5, kind = "object", direction = "None", class = "object",
                    archetype = "crate", x = 4, y = 2
                },

                -- Editor-facing Text.name is independent
                -- of derived PUSH/STOP/YOU/WORD properties.
                [6] = {
                    id = 6, kind = "object", direction = "None", class = "text",
                    x = 2, y = 4, text = { name = "CRATE" }
                },
                [7] = {
                    id = 7, kind = "object", direction = "None", class = "text",
                    x = 3, y = 4, text = { name = "IS" }
                },
                [8] = {
                    id = 8, kind = "object", direction = "None", class = "text",
                    x = 4, y = 4, text = { name = "PUSH" }
                },
                [9] = {
                    id = 9, kind = "object", direction = "None", class = "text",
                    x = 1, y = 5, text = { name = "AVATAR" }
                },
                [10] = {
                    id = 10, kind = "object", direction = "None", class = "text",
                    x = 2, y = 5, text = { name = "IS" }
                },
                [11] = {
                    id = 11, kind = "object", direction = "None", class = "text",
                    x = 3, y = 5, text = { name = "YOU" }
                }
            },

            -- Base rules are ordinary Rule IR sources,
            -- not intrinsic traits of Text instances.
            rule_sources = {{
                when = { op = "always" },
                effects = {{
                    op = "grant_trait",
                    target = { kind = "class", value = "text" },
                    trait = "pushable"
                }}
            }, {
                when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="cursor"},trait="select"}}
            }, {
                when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="line"},trait="path"}}
            }, {
                when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="level_block"},trait="block_entry"}}
            }},

            -- Level-selected vocabulary.
            language = {
                nouns = {
                    CRATE = "crate",
                    AVATAR = "avatar"
                },

                -- New typed AST vocabulary. The legacy copula
                -- remains until its compiler is retired.
                verbs = {
                    IS = "is", HAS = "has"
                },

                copulas = {
                    IS = "grant_trait"
                },

                properties = {
                    PUSH = "pushable",
                    YOU = "you", DEFEAT = "defeat", SINK = "sink", WORD = "word",
                    STOP="block_entry", WIN="win"
                },
                specials = {TEXT="text",ALL="all",EMPTY="empty"},
                operators = {AND="and",NOT="not"}
            }
    }
end

-- Level definitions are reusable data; sessions own independent runtime snapshots.
-- No implicit instance allocator: the future parent/campaign owns instance IDs.
local WORLD_FIELDS = {width=true, height=true, next_entity_id=true, entities=true, infinite_loop=true,
    rule_sources=true, language=true, semantics=true, selectors=true,
    behavior_registry=true,board_offset=true}

local function plain_data(value, visiting)
    local kind = type(value)
    if kind == "number" then return value == value and value ~= math.huge and value ~= -math.huge end
    if kind ~= "table" then return kind == "string" or kind == "boolean" or kind == "nil" end
    if getmetatable(value) ~= nil then return false end
    visiting = visiting or {}
    if visiting[value] then return false end
    visiting[value] = true
    for key, item in pairs(value) do
        if (type(key) ~= "string" and type(key) ~= "number")
            or not plain_data(key, visiting) or not plain_data(item, visiting) then return false end
    end
    visiting[value] = nil
    return true
end

local function validate_definition(definition)
    if type(definition) ~= "table" or not plain_data(definition)
        or type(definition.id) ~= "string" or definition.id == ""
        or type(definition.initial_world) ~= "table" then return false end
    for key in pairs(definition) do
        if key ~= "id" and key ~= "initial_world" then return false end
    end
    local world = definition.initial_world
    for key in pairs(world) do if not WORLD_FIELDS[key] then return false end end
    if not is_integer(world.width) or world.width < 1
        or not is_integer(world.height) or world.height < 1
        or type(world.entities) ~= "table" or not valid_frontier(world) then return false end
    if world.infinite_loop ~= nil and world.infinite_loop ~= true then return false end
    if world.board_offset ~= nil and not valid_board_offset(world.board_offset) then return false end
    for id, entity in pairs(world.entities) do
        if not valid_new_entity(world, entity, id) then return false end
    end
    for _, key in ipairs({"rule_sources", "language", "semantics", "selectors", "behavior_registry"}) do
        if world[key] ~= nil and type(world[key]) ~= "table" then return false end
    end
    return true
end

function RW_GetDefaultLevelDefinition()
    return {id = "ruleworld.demo", initial_world = default_world()}
end

function RW_CreateLevelDefinition(id, initial_world)
    local definition = {id = id, initial_world = initial_world}
    if not validate_definition(definition) then return nil, "invalid_level_definition" end
    return clone(definition)
end

function RW_InstantiateLevel(definition, instance_id)
    if not validate_definition(definition) then return nil, "invalid_level_definition" end
    if type(instance_id) ~= "string" or instance_id == "" then return nil, "invalid_instance_id" end
    return {definition_id = definition.id, instance_id = instance_id,
        world = clone(definition.initial_world), history = {}}
end

-- Existing callers retain the default demo. IDs are local to the owning parent;
-- entity IDs are local to an instance, never globally unique across instances.
function RW_CreateSession()
    return RW_InstantiateLevel(RW_GetDefaultLevelDefinition(), "root")
end

function RW_LevelInstanceSelfTest()
    local definition = RW_GetDefaultLevelDefinition()
    local a = RW_InstantiateLevel(definition, "a")
    local b = RW_InstantiateLevel(definition, "b")
    local plan = {consumes_turn=true, changes={{kind="direction", entity_id=1,
        from="None", to="Left"}}}
    local moved, result = RW_Commit(a, plan)
    local restored = RW_Undo(moved)
    if not result.accepted or moved.instance_id ~= "a"
        or moved.definition_id ~= definition.id or restored.instance_id ~= "a"
        or restored.world ~= a.world or #restored.history ~= 0
        or moved.world.entities[1].direction ~= "Left"
        or b.world.entities[1].direction ~= "None"
        or definition.initial_world.entities[1].direction ~= "None" then
        return false, "Level instance identity/isolation/Undo failed"
    end
    definition.initial_world.language.nouns.CRATE = "changed"
    if a.world.language.nouns.CRATE ~= "crate" or b.world.language.nouns.CRATE ~= "crate" then
        return false, "Level configuration alias leaked"
    end
    local invalid = RW_GetDefaultLevelDefinition()
    invalid.initial_world.entities[1].behaviors = {control=true}
    if RW_InstantiateLevel(invalid, "bad") ~= nil then
        return false, "Derived runtime state accepted as level definition"
    end
    return true, "Level definition/runtime instance isolation passed"
end

-- A phase sequence is validated against successive private snapshots. Flat plans
-- keep their original simultaneous-operation contract; nested sequences are rejected.
local function preview_transaction(world, plan)
    if world.infinite_loop then return nil,"infinite_loop_undo_only" end
    if type(plan) ~= "table" then return nil,"invalid_plan" end
    if plan.infinite_loop ~= nil and plan.infinite_loop ~= true then return nil,"invalid_infinite_loop" end
    if plan.stages == nil then
        local valid, reason = validate_plan(world,plan)
        if not valid then return nil,reason end
        if not plan.consumes_turn then return nil,plan.reason or "no_turn" end
        local result=apply_plan(world,plan)
        if plan.infinite_loop then result.infinite_loop=true end
        return result,nil,#plan.changes > 0 or plan.board_shift ~= nil or plan.infinite_loop == true
    end
    if plan.consumes_turn ~= true or not is_list(plan.changes)
        or plan.id_allocation ~= nil or plan.board_shift ~= nil
        or not is_list(plan.stages) or #plan.stages == 0 or #plan.stages > 32 then
        return nil,"invalid_stage_sequence"
    end
    local current, changed, names, summary = world,false,{},{}
    for _, stage in ipairs(plan.stages) do
        if type(stage) ~= "table" or type(stage.name) ~= "string" or stage.name == ""
            or names[stage.name] or type(stage.plan) ~= "table" or stage.plan.stages ~= nil then
            return nil,"invalid_stage"
        end
        names[stage.name] = true
        local valid, reason = validate_plan(current,stage.plan)
        if not valid then return nil,reason,nil,stage.name end
        if not stage.plan.consumes_turn then return nil,"non_consuming_stage",nil,stage.name end
        for _, change in ipairs(stage.plan.changes) do summary[#summary+1]=change end
        current = apply_plan(current,stage.plan)
        changed = changed or #stage.plan.changes > 0 or stage.plan.board_shift ~= nil
    end
    if not same_state(plan.changes,summary) then return nil,"stage_summary_mismatch" end
    if plan.infinite_loop then current.infinite_loop=true; changed=true end
    return current,nil,changed
end

-- Owned sequential plan; creation is still pure and does not record history.
function RW_PlanStages(world, stages)
    local plan = {consumes_turn=true,changes={},stages=clone(stages)}
    if is_list(plan.stages) then
        for _, stage in ipairs(plan.stages) do
            if type(stage) == "table" and type(stage.plan) == "table" and is_list(stage.plan.changes) then
                for _, change in ipairs(stage.plan.changes) do plan.changes[#plan.changes+1]=clone(change) end
            end
        end
    end
    local preview, reason, _, phase = preview_transaction(world,plan)
    if not preview then return nil,reason,nil,phase end
    return plan,nil,preview
end

function RW_PreviewPlan(world, plan)
    local preview, reason, _, phase = preview_transaction(world,plan)
    return preview,reason,phase
end

-- One final world, one history frame, even across multiple sequential phases.
function RW_Commit(session, plan)
    local preview, reason, changed, phase = preview_transaction(session.world,plan)
    if not preview then
        local result = rejected(reason)
        result.phase = phase
        return session,result
    end
    local next_world = changed and preview or session.world

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
        definition_id = session.definition_id,
        instance_id = session.instance_id,
        defeated = session.defeated,
        history = history
    }, {
        accepted = true,
        changed = changed,
        reason = plan.reason,
        changes = plan.changes,
        stages = plan.stages
    }
end

function RW_StageTransactionSelfTest()
    local session = RW_CreateSession()
    local frontier = session.world.next_entity_id
    local creation = RW_PlanCreate(session.world,{{kind="object",class="object",
        archetype="rock",x=4,y=4,direction="Mid"}})
    local created = RW_PreviewPlan(session.world,creation)
    local removal = RW_PlanDelete(created,{frontier})
    local plan = RW_PlanStages(session.world,{{name="create",plan=creation},{name="remove",plan=removal}})
    local committed,result = RW_Commit(session,plan)
    if not result.accepted or not result.changed or #committed.history ~= 1
        or committed.world.entities[frontier] or committed.world.next_entity_id ~= frontier+1 then
        return false,"Sequential lifecycle transaction failed"
    end
    local restored = RW_Undo(committed)
    if restored.world ~= session.world then return false,"Stage transaction Undo failed" end
    return true,"Sequential phases, transient creation/deletion and single Undo passed"
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
        definition_id = session.definition_id,
        instance_id = session.instance_id,
        defeated = session.defeated,
        history = history
    }, {
        accepted = true,
        changed = previous_world ~= session.world,
        reason = "undo",
        changes = {}
    }
end

-- M9.3G: lifecycle operations share the existing atomic state boundary.
function RW_LifecycleSelfTest()
    local s = RW_CreateSession()
    local specifications = {
        {kind = "object", class = "object", archetype = "crate",
            x = 2, y = 2, direction = "Mid"},
        {kind = "object", class = "text", x = 2, y = 2,
            direction = "None", text = {name = "AVATAR"}}
    }
    local plan = RW_PlanCreate(s.world, specifications)
    local deletion = RW_PlanDelete(s.world, {6, 4})
    if not plan or not deletion or #plan.changes ~= 2
        or plan.changes[1].entity_id ~= 12 or plan.changes[2].entity_id ~= 13
        or deletion.changes[1].entity_id ~= 4 or s.world.next_entity_id ~= 12 then
        return false, "Lifecycle planning/ID order failed"
    end
    -- Creation owns a copy of nested Text state.
    specifications[2].text.name = "CHANGED"
    if plan.changes[2].to.text.name ~= "AVATAR" then
        return false, "Creation specification alias leaked"
    end
    for _, change in ipairs(deletion.changes) do plan.changes[#plan.changes + 1] = change end
    local additions = {
        {kind = "move", entity_id = 1,
            from = {x = 2, y = 2, direction = "None"},
            to = {x = 2, y = 3, direction = "Down"}},
        {kind = "transform", entity_id = 1, from = "avatar", to = "crate"},
        -- Deletion precedes these writes in the list but is terminal.
        {kind = "move", entity_id = 4, from = {x = 3, y = 2}, to = {x = 3, y = 3}},
        {kind = "transform", entity_id = 4, from = "crate", to = "avatar"}
    }
    for _, change in ipairs(additions) do plan.changes[#plan.changes + 1] = change end
    local preview = RW_PreviewPlan(s.world, plan)
    local committed, result = RW_Commit(s, plan)
    if not preview or not result.accepted or not result.changed
        or not same_state(preview, committed.world) or #committed.history ~= 1
        or committed.world.next_entity_id ~= 14
        or committed.world.entities[4] or committed.world.entities[6]
        or committed.world.entities[1].archetype ~= "crate"
        or committed.world.entities[1].direction ~= "Down"
        or committed.world.entities[12].direction ~= "Mid"
        or committed.world.entities[13].text.name ~= "AVATAR"
        or s.world.entities[1].y ~= 2 or not s.world.entities[6] then
        return false, "Mixed lifecycle Preview/Commit failed"
    end
    local restored = RW_Undo(committed)
    if restored.world ~= s.world or #restored.history ~= 0
        or restored.world.next_entity_id ~= 12 or restored.world.entities[12] then
        return false, "Lifecycle Undo failed"
    end
    local replayed, replay_result = RW_Commit(restored, plan)
    if not replay_result.accepted or not same_state(replayed.world, committed.world) then
        return false, "Lifecycle deterministic replay failed"
    end
    local reversed = clone(plan)
    for index = 1, math.floor(#reversed.changes / 2) do
        local other = #reversed.changes - index + 1
        reversed.changes[index], reversed.changes[other] =
            reversed.changes[other], reversed.changes[index]
    end
    if not same_state(RW_PreviewPlan(s.world, reversed), preview) then
        return false, "Lifecycle operation order changed result"
    end
    local remove_new = RW_PlanDelete(committed.world, {12, 13})
    local removed = RW_Commit(committed, remove_new)
    local fresh = RW_PlanCreate(removed.world, {specifications[1]})
    if removed.world.next_entity_id ~= 14 or fresh.changes[1].entity_id ~= 14 then
        return false, "Deleted ID was recycled"
    end
    local stale_session, stale_result = RW_Commit(removed, plan)
    if stale_result.accepted or stale_session ~= removed then
        return false, "Old allocation was reused"
    end
    -- A stale nested delete must reject movement, creation and ID advance too.
    local bad = clone(plan)
    bad.changes[4].from.text.name = "IS"
    local unchanged, rejection = RW_Commit(s, bad)
    if rejection.accepted or unchanged ~= s or s.world.next_entity_id ~= 12
        or RW_PreviewPlan(s.world, bad) ~= nil then
        return false, "Stale deletion partially committed"
    end
    local duplicate = clone(plan)
    duplicate.changes[#duplicate.changes + 1] = clone(duplicate.changes[1])
    local unchanged2, rejected2 = RW_Commit(s, duplicate)
    if rejected2.accepted or unchanged2 ~= s then
        return false, "Duplicate creation accepted"
    end
    -- Neither committed nor preview state aliases create.to payloads.
    plan.changes[2].to.text.name = "MUTATED"
    if committed.world.entities[13].text.name ~= "AVATAR"
        or preview.entities[13].text.name ~= "AVATAR" then
        return false, "Lifecycle payload alias leaked"
    end
    return true, "Atomic create/delete, ID allocation and Undo passed"
end

-- Internal invariant tests.
function RW_SelfTest()
    local s0 = RW_CreateSession()
    if not valid_frontier(s0.world) then
        return false, "Invalid authored entity ID frontier"
    end

    for _, entity in pairs(s0.world.entities) do
        if entity.kind ~= "object"
            or (entity.class ~= "object"
                and entity.class ~= "text")
            or entity.traits ~= nil
            or entity.behaviors ~= nil
            or not valid_direction(entity.direction) then
            return false, "Invalid authored Object state"
        end

        if entity.class == "text" then
            if type(entity.text) ~= "table"
                or type(entity.text.name) ~= "string"
                or entity.text.name == ""
                or entity.symbol ~= nil then
                return false, "Invalid authored Text subclass"
            end
        end
    end

    local base = s0.world.rule_sources[1]

    if #s0.world.rule_sources ~= 4
        or not base
        or base.effects[1].target.kind ~= "class"
        or base.effects[1].target.value ~= "text"
        or base.effects[1].trait ~= "pushable" then
        return false, "TEXT IS PUSH base rule absent"
    end

    local move = {
        consumes_turn = true,
        changes = { {
            kind = "move",
            entity_id = 1,
            from = { x = 2, y = 2 },
            to = { x = 3, y = 2 }
        } }
    }

    local s1, r1 = RW_Commit(s0, move)

    if not r1.accepted or not r1.changed
        or s0.world.entities[1].x ~= 2
        or s1.world.entities[1].x ~= 3 then
        return false, "Immutable commit failed"
    end

    local blocked = {
        consumes_turn = true,
        reason = "test_block",
        changes = {}
    }

    local s2, r2 = RW_Commit(s1, blocked)

    if not r2.accepted or r2.changed
        or #s2.history ~= 2 then
        return false, "Empty turn commit failed"
    end

    local u1 = RW_Undo(s2)
    local u2 = RW_Undo(u1)

    if u1.world.entities[1].x ~= 3
        or u2.world.entities[1].x ~= 2
        or #u2.history ~= 0 then
        return false, "Undo failed"
    end

    -- Invalid plans must never partially commit.
    local invalid_plan = {
        consumes_turn = true,
        changes = {
            {
                kind = "move",
                entity_id = 1,
                from = { x = 2, y = 2 },
                to = { x = 3, y = 2 }
            },
            {
                kind = "move",
                entity_id = 999,
                from = { x = 1, y = 1 },
                to = { x = 2, y = 1 }
            }
        }
    }

    local bad, rb = RW_Commit(s0, invalid_plan)

    if rb.accepted or bad ~= s0
        or s0.world.entities[1].x ~= 2 then
        return false, "Atomic validation failed"
    end

    -- Move and transform the same entity atomically.
    local transform_plan = {
        consumes_turn = true,
        changes = {
            {
                kind = "move",
                entity_id = 4,
                from = { x = 3, y = 2 },
                to = { x = 4, y = 3 }
            },
            {
                kind = "transform",
                entity_id = 4,
                from = "crate",
                to = "avatar"
            }
        }
    }

    local preview = RW_PreviewPlan(s0.world, transform_plan)

    if not preview
        or preview.entities[4].x ~= 4
        or preview.entities[4].y ~= 3
        or preview.entities[4].archetype ~= "avatar"
        or s0.world.entities[4].archetype ~= "crate" then
        return false, "Transformation preview failed"
    end

    local converted, conversion_result =
        RW_Commit(s0, transform_plan)

    if not conversion_result.accepted
        or #converted.history ~= 1
        or converted.world.entities[4].archetype ~= "avatar"
        or converted.world.entities[4].x ~= 4 then
        return false, "Atomic transformation failed"
    end

    local restored, undone = RW_Undo(converted)

    if not undone.accepted
        or #restored.history ~= 0
        or restored.world.entities[4].archetype ~= "crate"
        or restored.world.entities[4].x ~= 3
        or restored.world.entities[4].y ~= 2 then
        return false, "Transformation undo failed"
    end

    -- A stale transform must reject the complete turn.
    local stale = clone(transform_plan)
    stale.changes[2].from = "rock"
    local rejected_session, rejection = RW_Commit(s0, stale)

    if rejection.accepted
        or rejected_session ~= s0
        or s0.world.entities[4].x ~= 3 then
        return false, "Transformation validation failed"
    end

    return true, "World invariants passed"
end

-- M9.3K: persistent nested instances, independent of movement or presentation.
-- Tree snapshots are immutable by convention, as are world/session snapshots.
local function copy_map(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

function RW_CreateLevelTree(definitions, root_definition_id)
    if type(definitions) ~= "table" or not plain_data(definitions) then
        return nil, "invalid_definitions"
    end
    for id, definition in pairs(definitions) do
        if type(id) ~= "string" or not validate_definition(definition)
            or definition.id ~= id then return nil, "invalid_definitions" end
    end
    local definition = definitions[root_definition_id]
    if not definition then return nil, "unknown_definition" end
    local root = RW_InstantiateLevel(definition, "instance:1")
    return {definitions=clone(definitions), instances={[root.instance_id]=root},
        children={}, active_id=root.instance_id, stack={}, entry_links={}, outcomes={}, level_transforms={},
        history={}, next_instance_id=2}
end

function RW_GetActiveLevel(tree)
    return tree.instances[tree.active_id]
end

-- Only replace the active session; sibling and suspended parent states survive.
function RW_UpdateActiveLevel(tree, session)
    local current = RW_GetActiveLevel(tree)
    if type(session) ~= "table" or session.instance_id ~= tree.active_id
        or session.definition_id ~= current.definition_id then
        return nil, "instance_identity_mismatch"
    end
    local next_tree = copy_map(tree)
    next_tree.instances = copy_map(tree.instances)
    next_tree.instances[tree.active_id] = session
    return next_tree
end

-- Boundaries reload authored data plus persistent LEVEL transformations.
function RW_ReloadLevel(tree,id)
    local old = tree.instances[id]
    if not old then return nil,"unknown_instance" end
    local session = RW_InstantiateLevel(tree.definitions[old.definition_id],id)
    for entity_id, archetype in pairs(tree.level_transforms[id] or {}) do
        if not session.world.entities[entity_id] then return nil,"persistent_level_block_missing" end
        session.world.entities[entity_id].archetype = archetype
    end
    local result = copy_map(tree)
    result.instances = copy_map(tree.instances)
    result.instances[id] = session
    return result
end

function RW_PlaceLevelSelectors(tree,ids,block_id)
    local session = RW_GetActiveLevel(tree)
    local block = session.world.entities[block_id]
    if not block or not is_list(ids) then return nil,"invalid_selector_spawn" end
    local world = clone(session.world)
    for _, id in ipairs(ids) do
        if not world.entities[id] then return nil,"invalid_selector_spawn" end
        world.entities[id].x,world.entities[id].y = block.x,block.y
    end
    return RW_UpdateActiveLevel(tree,{definition_id=session.definition_id,instance_id=session.instance_id,
        world=world,history={}})
end

-- Slot identity belongs to a parent INSTANCE. Same slot under two parents differs.
-- Definition is checked again on re-entry; a slot cannot silently change meaning.
function RW_EnterLevel(tree, slot, definition_id)
    if type(slot) ~= "string" or slot == "" then return nil, "invalid_slot" end
    if type(definition_id) ~= "string" or not tree.definitions[definition_id] then
        return nil, "unknown_definition"
    end
    local existing = (tree.children[tree.active_id] or {})[slot]
    if existing and tree.instances[existing].definition_id ~= definition_id then
        return nil, "slot_definition_mismatch"
    end
    if not existing and (not valid_id(tree.next_instance_id)
        or tree.next_instance_id >= MAX_ID) then return nil, "instance_id_exhausted" end
    local result = copy_map(tree)
    result.stack = copy_map(tree.stack)
    result.stack[#result.stack+1] = tree.active_id
    if existing then
        result.active_id = existing
    else
        local id = "instance:" .. string.format("%.0f",tree.next_instance_id)
        result.instances = copy_map(tree.instances)
        result.instances[id] = RW_InstantiateLevel(tree.definitions[definition_id], id)
        result.children = copy_map(tree.children)
        result.children[tree.active_id] = copy_map(tree.children[tree.active_id] or {})
        result.children[tree.active_id][slot] = id
        result.active_id = id
        result.next_instance_id = tree.next_instance_id + 1
    end
    local reloaded, err = RW_ReloadLevel(result,tree.active_id)
    if not reloaded then return nil,err end
    return RW_ReloadLevel(reloaded,result.active_id)
end

function RW_ReturnLevel(tree)
    if #tree.stack == 0 then return nil, "at_root" end
    local result = copy_map(tree)
    result.stack = copy_map(tree.stack)
    result.active_id = result.stack[#result.stack]
    result.stack[#result.stack] = nil
    local reloaded, err = RW_ReloadLevel(result,tree.active_id)
    if not reloaded then return nil,err end
    return RW_ReloadLevel(reloaded,result.active_id)
end

function RW_LevelTreeSelfTest()
    local d = RW_GetDefaultLevelDefinition()
    local root = RW_CreateLevelTree({[d.id]=d},d.id)
    local child = RW_EnterLevel(root,"A",d.id)
    local moved = RW_Commit(RW_GetActiveLevel(child),{consumes_turn=true,changes={
        {kind="direction",entity_id=1,from="None",to="Left"}}})
    child = RW_UpdateActiveLevel(child,moved)
    local again = RW_EnterLevel(RW_ReturnLevel(child),"A",d.id)
    if RW_GetActiveLevel(again).world.entities[1].direction ~= "None"
        or #RW_GetActiveLevel(again).history ~= 0 or again.active_id ~= child.active_id
        or RW_GetActiveLevel(child).world.entities[1].direction ~= "Left"
        or RW_ReturnLevel(root) ~= nil then return false,"Level boundary reset failed" end
    return true,"Level boundary reload, stable identity and snapshot isolation passed"
end

function RW_BindLevelEntry(tree, entity_id)
    if #tree.stack == 0 then return nil, "at_root" end
    local result = copy_map(tree)
    result.entry_links = copy_map(tree.entry_links)
    result.entry_links[tree.active_id] = {parent_id=tree.stack[#tree.stack], entity_id=entity_id}
    return result
end

function RW_RecordLevelOutcome(tree, kind, target_type)
    if kind ~= "win" and kind ~= "transform" and kind ~= "defeat" then return nil, "invalid_level_outcome" end
    if kind == "transform" and (type(target_type) ~= "string" or target_type == "") then
        return nil, "invalid_level_transform"
    end
    local result = copy_map(tree)
    result.outcomes = copy_map(tree.outcomes)
    result.outcomes[tree.active_id] = {kind=kind,target_type=target_type}
    if kind == "defeat" then
        result.instances = copy_map(tree.instances)
        result.instances[tree.active_id] = copy_map(tree.instances[tree.active_id])
        result.instances[tree.active_id].defeated = true
    end
    if kind == "transform" then
        local entry = tree.entry_links[tree.active_id]
        if not entry then return nil, "no_parent_level_block" end
        local parent = tree.instances[entry.parent_id]
        local block = parent.world.entities[entry.entity_id]
        if not block then return nil, "missing_parent_level_block" end
        local changed, accepted = RW_Commit(parent, {consumes_turn=true, changes={
            {kind="transform",entity_id=block.id,from=block.archetype,to=target_type}}})
        if not accepted.accepted then return nil, accepted.reason end
        result.instances = copy_map(tree.instances)
        result.instances[entry.parent_id] = changed
        result.level_transforms = copy_map(tree.level_transforms)
        result.level_transforms[entry.parent_id] = copy_map(tree.level_transforms[entry.parent_id] or {})
        result.level_transforms[entry.parent_id][block.id] = target_type
    end
    return result
end

local function valid_tree_candidate(tree)
    if type(tree) ~= "table" or type(tree.instances) ~= "table"
        or type(tree.definitions) ~= "table" or type(tree.children) ~= "table"
        or type(tree.entry_links) ~= "table" or type(tree.outcomes) ~= "table"
        or type(tree.level_transforms) ~= "table"
        or not is_list(tree.stack) or not valid_id(tree.next_instance_id)
        or not tree.instances[tree.active_id] then return false end
    for id, session in pairs(tree.instances) do
        local sequence = type(id) == "string" and tonumber(id:match("^instance:(%d+)$"))
        if not sequence or not valid_id(sequence) or sequence >= tree.next_instance_id
            or type(session) ~= "table" or session.instance_id ~= id
            or not tree.definitions[session.definition_id] or not is_list(session.history)
            or not validate_definition({id=session.definition_id,initial_world=session.world}) then return false end
    end
    local seen = {[tree.active_id]=true}
    for _, id in ipairs(tree.stack) do
        if not tree.instances[id] or seen[id] then return false end
        seen[id] = true
    end
    for parent, slots in pairs(tree.children) do
        if not tree.instances[parent] or type(slots) ~= "table" then return false end
        for slot, id in pairs(slots) do
            if type(slot) ~= "string" or slot == "" or not tree.instances[id] or id == parent then return false end
        end
    end
    return true
end

-- The planner produces a complete candidate. Commit owns the only history write.
function RW_CommitLevelTree(tree, plan)
    if RW_GetActiveLevel(tree).world.infinite_loop then return tree,rejected("infinite_loop_undo_only") end
    if RW_GetActiveLevel(tree).defeated and not (type(plan) == "table" and plan.select_after_defeat) then
        return tree,rejected("level_defeated_undo_only")
    end
    if type(plan) ~= "table" or plan.before ~= tree or type(plan.after) ~= "table"
        or not valid_tree_candidate(plan.after) or plan.after.history ~= tree.history then
        return tree, rejected("invalid_or_stale_tree_plan")
    end
    local result = copy_map(plan.after)
    local snapshot = copy_map(tree)
    snapshot.history = nil -- Avoid nested history chains; frames share immutable state.
    result.history = copy_map(tree.history)
    if #result.history >= HISTORY_LIMIT then table.remove(result.history,1) end
    result.history[#result.history+1] = snapshot
    return result, {accepted=true,changed=true,reason=plan.reason,changes=plan.changes or {}}
end

function RW_UndoLevelTree(tree)
    if #tree.history == 0 then return tree, rejected("empty_history") end
    local result = copy_map(tree.history[#tree.history])
    result.history = copy_map(tree.history)
    result.history[#result.history] = nil
    return result, {accepted=true,changed=true,reason="undo",changes={}}
end

-- Native-playtest definitions: actual level blocks, an independent SELECT cursor,
-- a YOU actor, a win contact, and an assemblable scoped LEVEL conversion.
function RW_GetNavigationDefinitions()
    local function object(world,id,archetype,x,y,link)
        world.entities[id] = {id=id,kind="object",class="object",direction="None",
            archetype=archetype,x=x,y=y,level_link=link}
        world.next_entity_id = math.max(world.next_entity_id,id+1)
    end
    local function grant(world,archetype,trait)
        world.rule_sources[#world.rule_sources+1] = {when={op="always"},effects={
            {op="grant_trait",target={kind="archetype",value=archetype},trait=trait}}}
    end
    local function portal(world,id,x,y,name,definition_id)
        object(world,id,"level_block",x,y,{source_type="level_block",target=definition_id and "child" or "parent",
            definition_id=definition_id,label=name})
    end
    local function configure(world)
        world.language.nouns.CURSOR = "cursor"
        world.language.nouns.LINE = "line"
        world.language.properties.PATH = "path"
        world.language.properties.STOP = "block_entry"
        world.language.nouns.FLAG = "flag"
        world.language.nouns.LEVEL = {tag="level",block_type="level_block"}
        world.language.operators = {AND="and"}
        world.language.properties.SELECT = "select"
        world.language.properties.WIN = "win"
        world.language.properties.DEFEAT = "defeat"
        world.language.nouns.ROCK = "rock"
    end
    local root = default_world()
    configure(root)
    root.entities[1].x = 6
    object(root,12,"cursor",2,2)
    portal(root,13,2,1,"A","navigation.puzzle")
    portal(root,14,1,2,"B","navigation.puzzle")
    portal(root,15,3,1,"T","navigation.transform")
    local id = 16
    for y=1,3 do for x=1,7 do
        object(root,id,"line",x,y)
        id = id+1
    end end
    local puzzle = default_world()
    configure(puzzle)
    object(puzzle,12,"cursor",1,1)
    portal(puzzle,13,2,1,"PARENT")
    object(puzzle,14,"line",1,1)
    object(puzzle,15,"flag",2,3)
    local transform = clone(puzzle)
    transform.entities[1].x, transform.entities[1].y = 9,10
    transform.entities[15].x, transform.entities[15].y = 2,10
    for index, token in ipairs({"LEVEL","IS","CRATE"}) do
        local token_id = 15+index
        transform.entities[token_id] = {id=token_id,kind="object",class="text",direction="None",
            x=6+index,y=index == 3 and 9 or 8,text={name=token}}
    end
    transform.next_entity_id = 19
    local definitions = {
        ["navigation.root"] = {id="navigation.root",initial_world=root},
        ["navigation.puzzle"] = {id="navigation.puzzle",initial_world=puzzle},
        ["navigation.transform"] = {id="navigation.transform",initial_world=transform}
    }
    -- Push the SUBJECT into place: no terminal prefix is active before the test.
    local cases = {
        {id="win",label="W",words={"LEVEL","IS","WIN"}},
        {id="defeat",label="D",words={"LEVEL","IS","DEFEAT"}},
        {id="win_defeat",label="WD",words={"LEVEL","IS","WIN","AND","DEFEAT"}},
        {id="defeat_win",label="DW",words={"LEVEL","IS","DEFEAT","AND","WIN"}},
        {id="rock_win",label="RW",words={"LEVEL","IS","ROCK","AND","WIN"}},
        {id="noun_level",label="N",words={"CRATE","IS","LEVEL"}}
    }
    for column, test in ipairs(cases) do
        local world = clone(puzzle)
        world.entities[15] = nil -- No incidental contact WIN in these test worlds.
        world.entities[1].x,world.entities[1].y = 4,10
        for offset, token in ipairs(test.words) do
            local token_id = 15+offset
            world.entities[token_id] = {id=token_id,kind="object",class="text",direction="None",
                x=3+offset,y=offset == 1 and 9 or 8,text={name=token}}
        end
        world.next_entity_id = 16+#test.words
        if test.id == "noun_level" then
            world.entities[4].level_link = {source_type="crate",target="child",definition_id="navigation.puzzle",label="C"}
            object(world,world.next_entity_id,"line",1,2)
            object(world,world.next_entity_id,"line",2,2)
        end
        local definition_id = "navigation." .. test.id
        definitions[definition_id] = {id=definition_id,initial_world=world}
        portal(root,36+column,column,3,test.label,definition_id)
    end
    local map_you = clone(definitions["navigation.win"].initial_world)
    map_you.entities[18].text.name = "YOU"
    definitions["navigation.level_you"] = {id="navigation.level_you",initial_world=map_you}
    portal(root,43,7,3,"YOU","navigation.level_you")
    portal(root,44,7,3,"P","navigation.puzzle")
    local selector_win = clone(definitions["navigation.win"].initial_world)
    selector_win.entities[16].y = 8
    selector_win.entities[11].text.name = "PUSH" -- No YOU: WIN must leave SELECT usable.
    definitions["navigation.selector_win"] = {id="navigation.selector_win",initial_world=selector_win}
    portal(root,45,7,1,"SW","navigation.selector_win")
    local split = clone(definitions["navigation.noun_level"].initial_world)
    for offset, token in ipairs({"AND","ROCK"}) do
        local token_id = split.next_entity_id
        split.entities[token_id] = {id=token_id,kind="object",class="text",direction="None",
            x=6+offset,y=8,text={name=token}}
        split.next_entity_id = token_id+1
    end
    definitions["navigation.split"] = {id="navigation.split",initial_world=split}
    portal(root,46,6,1,"SPL","navigation.split")
    local function contact_fixture(kind)
        local world=clone(puzzle)
        world.entities[1].x,world.entities[1].y=2,3
        world.entities[2],world.entities[3],world.entities[4],world.entities[5],world.entities[15]=nil,nil,nil,nil,nil
        world.language.nouns.ROCK="rock"
        world.language.nouns.SKULL="skull"
        world.language.nouns.WATER="water"
        local function sentence(words,y)
            for offset,word in ipairs(words) do
                local id=world.next_entity_id
                world.entities[id]={id=id,kind="object",class="text",direction="None",x=offset,y=y,text={name=word}}
                world.next_entity_id=id+1
            end
        end
        if kind == "defeat" then
            object(world,15,"skull",3,3)
            sentence({"SKULL","IS","DEFEAT"},7)
        else
            object(world,4,"crate",3,3)
            object(world,15,"water",4,3)
            sentence({"WATER","IS","SINK"},7)
            if kind == "has" then
                sentence({"CRATE","HAS","ROCK","AND","ROCK"},8)
                sentence({"ROCK","IS","YOU"},9)
            end
        end
        return world
    end
    for _,case in ipairs({{47,4,1,"DF","defeat"},{48,5,1,"SK","sink"},{49,4,2,"HAS","has"}}) do
        local id="navigation.contact_" .. case[5]
        definitions[id]={id=id,initial_world=contact_fixture(case[5])}
        portal(root,case[1],case[2],case[3],case[4],id)
    end
    local lab=default_world()
    lab.entities={
        [1]={id=1,kind="object",class="object",archetype="avatar",x=6,y=8,direction="None"},
        [2]={id=2,kind="object",class="text",text={name="ROCK"},x=4,y=5,direction="None"},
        [3]={id=3,kind="object",class="object",archetype="rock",x=4,y=3,direction="None"},
        [4]={id=4,kind="object",class="text",text={name="IS"},x=5,y=5,direction="None"},
        [5]={id=5,kind="object",class="text",text={name="IS"},x=5,y=3,direction="None"},
        [6]={id=6,kind="object",class="text",text={name="WORD"},x=6,y=6,direction="None"},
        [7]={id=7,kind="object",class="text",text={name="NOT"},x=8,y=4,direction="None"},
        [8]={id=8,kind="object",class="text",text={name="TEXT"},x=8,y=7,direction="None"},
        [9]={id=9,kind="object",class="text",text={name="WORD"},x=9,y=9,direction="None"}
    }
    lab.next_entity_id=10
    lab.language.nouns.ROCK="rock"
    -- Authored helper objects are real noun types too: NOT/ALL and WORD must
    -- see Cursor/Line even without a movable noun tile in the sandbox.
    lab.language.nouns.CURSOR="cursor"
    lab.language.nouns.LINE="line"
    lab.language.nouns.LEVEL={tag="level",block_type="level_block"}
    grant(lab,"avatar","you")
    grant(lab,"rock","pushable") -- Makes the requested object freely movable.
    object(lab,12,"cursor",1,1)
    portal(lab,13,2,1,"PARENT")
    object(lab,14,"line",1,1)
    definitions["navigation.text_word"]={id="navigation.text_word",initial_world=lab}
    portal(root,50,1,1,"TXT","navigation.text_word")
    local combos=clone(lab)
    combos.entities={}
    combos.next_entity_id=1
    object(combos,1,"avatar",6,11)
    object(combos,2,"rock",4,2)
    object(combos,3,"crate",8,2)
    local tokens={"ROCK","CRATE","AVATAR","ALL","EMPTY","TEXT","IS","IS","IS",
        "IS","NOT","NOT","NOT","NOT","WORD","WORD","PUSH","YOU","AND","WIN"}
    for index,token in ipairs(tokens) do
        local id=3+index
        combos.entities[id]={id=id,kind="object",class="text",text={name=token},
            x=2+((index-1)%5)*2,y=4+2*math.floor((index-1)/5),direction="None"}
        combos.next_entity_id=id+1
    end
    grant(combos,"crate","pushable")
    object(combos,24,"cursor",1,1)
    portal(combos,25,2,1,"PARENT")
    object(combos,26,"line",1,1)
    definitions["navigation.specials"]={id="navigation.specials",initial_world=combos}
    portal(root,51,3,2,"NAT","navigation.specials")
    local loop=clone(lab)
    loop.entities={};loop.next_entity_id=1
    object(loop,1,"avatar",4,4)
    object(loop,2,"rock",2,2)
    for index,spec in ipairs({{"ROCK",1,6},{"IS",2,6},{"WORD",3,6},
        {"IS",3,2},{"NOT",4,3},{"WORD",5,2}}) do
        local id=index+2
        loop.entities[id]={id=id,kind="object",class="text",text={name=spec[1]},x=spec[2],y=spec[3],direction="None"}
        loop.next_entity_id=id+1
    end
    object(loop,9,"cursor",1,1)
    portal(loop,10,2,1,"PARENT")
    object(loop,11,"line",1,1)
    definitions["navigation.infinite"]={id="navigation.infinite",initial_world=loop}
    portal(root,52,5,2,"LOOP","navigation.infinite")
    -- WIN is authored visibly in these two victory fixtures, never a Flag default.
    for _,world in ipairs({puzzle,transform}) do
        for offset,token in ipairs({"FLAG","IS","WIN"}) do
            local id=world.next_entity_id
            world.entities[id]={id=id,kind="object",class="text",text={name=token},
                x=7+offset,y=11,direction="None"}
            world.next_entity_id=id+1
        end
    end
    return definitions, "navigation.root"
end
