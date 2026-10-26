-- world.lua
-- RuleWorld M2: World state, atomic commit, history

local HISTORY_LIMIT = 128

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

-- Validate every operation before modifying anything.
local function validate_plan(world, plan)
    if type(plan) ~= "table"
        or type(plan.consumes_turn) ~= "boolean"
        or type(plan.changes) ~= "table" then
        return false, "invalid_plan"
    end

    if not plan.consumes_turn then
        if #plan.changes ~= 0 then
            return false, "invalid_no_turn_plan"
        end
        return true
    end

    local seen = {}

    for _, change in ipairs(plan.changes) do
        if type(change) ~= "table"
            or change.kind ~= "move"
            or type(change.from) ~= "table"
            or type(change.to) ~= "table" then
            return false, "invalid_operation"
        end

        local id = change.entity_id
        local entity = world.entities[id]

        if not entity then
            return false, "unknown_entity"
        end

        if seen[id] then
            return false, "duplicate_operation"
        end

        seen[id] = true

        if entity.x ~= change.from.x
            or entity.y ~= change.from.y then
            return false, "stale_operation"
        end

        if not is_integer(change.to.x)
            or not is_integer(change.to.y) then
            return false, "invalid_position"
        end
    end

    return true
end

-- Public API --------------------------------


function RW_CreateSession()
    return {
        world = {
            width = 7,
            height = 6,

            entities = {
                -- Controlled test entity
                [1] = {
                    id = 1,
                    kind = "object",
                    x = 2, y = 2
                },

                -- Fixed blocking entity
                [2] = {
                    id = 2,
                    kind = "object",
                    x = 6, y = 3,
                    traits = {
                        block_entry = true
                    }
                },

                -- Ordinary nonblocking entity
                [3] = {
                    id = 3,
                    kind = "object",
                    x = 6, y = 5
                },

                -- Two crates
                [4] = {
                    id = 4,
                    kind = "object",
                    archetype = "crate",
                    x = 3, y = 2,
                    traits = {
                        block_entry = true
                    }
                },

                [5] = {
                    id = 5,
                    kind = "object",
                    archetype = "crate",
                    x = 4, y = 2
                },

                -- Movable text blocks
                [6] = {
                    id = 6,
                    kind = "text",
                    x = 2, y = 4,
                    symbol = {
                        token = "CRATE"
                    },
                    traits = {
                        pushable = true
                    }
                },

                [7] = {
                    id = 7,
                    kind = "text",
                    x = 3, y = 4,
                    symbol = {
                        token = "IS"
                    },
                    traits = {
                        pushable = true
                    }
                },

                [8] = {
                    id = 8,
                    kind = "text",
                    x = 4, y = 4,
                    symbol = {
                        token = "PUSH"
                    },
                    traits = {
                        pushable = true
                    }
                }
            },

            -- No permanent rule sources in this level.
            rule_sources = {},

            -- Level-selected vocabulary.
            language = {
                nouns = {
                    CRATE = "crate"
                },

                copulas = {
                    IS = "grant_trait"
                },

                properties = {
                    PUSH = "pushable"
                }
            }
        },

        history = {}
    }
end

-- Commit a prepared plan atomically.
function RW_Commit(session, plan)
    local valid, reason =
        validate_plan(session.world, plan)

    if not valid then
        return session, rejected(reason)
    end

    if not plan.consumes_turn then
        return session, rejected(
            plan.reason or "no_turn"
        )
    end

    local changed = #plan.changes > 0

    local next_world = session.world

    if changed then
        next_world = clone(session.world)

        for _, change in ipairs(plan.changes) do
            local entity =
                next_world.entities[change.entity_id]

            entity.x = change.to.x
            entity.y = change.to.y
        end
    end

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
    }, {
        accepted = true,
        changed = changed,
        reason = plan.reason,
        changes = plan.changes
    }
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
        changed = previous_world ~= session.world,
        reason = "undo",
        changes = {}
    }
end

-- Internal invariant tests.
function RW_SelfTest()
    local s0 = RW_CreateSession()

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

    return true, "World invariants passed"
end
