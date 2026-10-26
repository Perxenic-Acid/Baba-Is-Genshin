
-- rules.lua
-- RuleWorld M6: Rule IR evaluation

local function valid_selector(s)
    if type(s) ~= "table" then
        return false
    end

    if s.kind == "id" then
        return type(s.value) == "number"
            and s.value % 1 == 0
    end

    if s.kind == "archetype" then
        return type(s.value) == "string"
            and s.value ~= ""
    end

    return false
end

local function matches(entity, selector)
    if selector.kind == "id" then
        return entity.id == selector.value
    end

    if selector.kind == "archetype" then
        return entity.archetype == selector.value
    end

    return false
end

local function overlaps(world, left, right)
    for id_a, a in pairs(world.entities) do
        if matches(a, left) then
            for id_b, b in pairs(world.entities) do
                if id_a ~= id_b
                    and matches(b, right)
                    and a.x == b.x
                    and a.y == b.y then
                    return true
                end
            end
        end
    end

    return false
end

-- Evaluate a Boolean condition tree.
-- Returns boolean on success, nil + error on failure.
local function evaluate_condition(world, node, stack)
    if type(node) ~= "table" then
        return nil, "invalid_condition"
    end

    stack = stack or {}

    if stack[node] then
        return nil, "cyclic_condition"
    end

    stack[node] = true

    local result
    local err

    if node.op == "always" then
        result = true

    elseif node.op == "overlap" then
        if not valid_selector(node.left)
            or not valid_selector(node.right) then
            err = "invalid_selector"
        else
            result = overlaps(
                world, node.left, node.right
            )
        end

    elseif node.op == "not" then
        local inner, inner_err =
            evaluate_condition(
                world, node.condition, stack
            )

        if inner == nil then
            err = inner_err
        else
            result = not inner
        end

    elseif node.op == "all" or node.op == "any" then
        if type(node.terms) ~= "table" then
            err = "invalid_condition_terms"
        else
            -- Logical identities:
            -- all({}) = true; any({}) = false
            result = (node.op == "all")

            -- Evaluate every child, even if the result
            -- is already known, to detect invalid nodes.
            for _, term in ipairs(node.terms) do
                local value, child_err =
                    evaluate_condition(world, term, stack)

                if value == nil then
                    result = nil
                    err = child_err
                    break
                end

                if node.op == "all" then
                    result = result and value
                else
                    result = result or value
                end
            end
        end

    else
        err = "unknown_condition_operator"
    end

    stack[node] = nil
    return result, err
end

local function valid_effect(effect)
    return type(effect) == "table"
        and effect.op == "grant_trait"
        and valid_selector(effect.target)
        and type(effect.trait) == "string"
        and effect.trait ~= ""
end

-- World + optional generated rules -> active effects.
-- Does not modify either input.
function RW_EvaluateRules(world, generated_rules)
    if type(world) ~= "table"
        or type(world.entities) ~= "table" then
        return nil, "invalid_world"
    end

    local active = {}

    local function collect(sources)
        if type(sources) ~= "table" then
            return false, "invalid_rule_sources"
        end

        for _, rule in ipairs(sources) do
            if type(rule) ~= "table"
                or type(rule.effects) ~= "table" then
                return false, "invalid_rule"
            end

            -- Validate effects regardless of whether
            -- the rule's condition currently holds.
            for _, effect in ipairs(rule.effects) do
                if not valid_effect(effect) then
                    return false, "invalid_rule_effect"
                end
            end

            local enabled, err =
                evaluate_condition(world, rule.when)

            if enabled == nil then
                return false, err
            end

            if enabled then
                for _, effect in ipairs(rule.effects) do
                    active[#active + 1] = {
                        op = effect.op,
                        target = {
                            kind = effect.target.kind,
                            value = effect.target.value
                        },
                        trait = effect.trait
                    }
                end
            end
        end

        return true
    end

    local ok, err = collect(world.rule_sources or {})
    if not ok then
        return nil, err
    end

    if generated_rules ~= nil then
        ok, err = collect(generated_rules)
        if not ok then
            return nil, err
        end
    end

    return active
end

function RW_RulesSelfTest()
    local player = { kind = "id", value = 1 }
    local plate = { kind = "id", value = 6 }
    local other = { kind = "id", value = 2 }

    local world = {
        entities = {
            [1] = { id = 1, x = 2, y = 2 },
            [2] = { id = 2, x = 3, y = 2 },
            [6] = { id = 6, x = 2, y = 2 }
        },

        rule_sources = {{
            when = {
                op = "all",
                terms = {
                    {
                        op = "overlap",
                        left = player,
                        right = plate
                    },
                    {
                        op = "not",
                        condition = {
                            op = "overlap",
                            left = player,
                            right = other
                        }
                    }
                }
            },

            effects = {{
                op = "grant_trait",
                target = {
                    kind = "archetype",
                    value = "crate"
                },
                trait = "pushable"
            }}
        }}
    }

    -- True AND NOT(false) -> true.
    local active = RW_EvaluateRules(world)

    if not active
        or #active ~= 1
        or active[1].trait ~= "pushable" then
        return false, "Composite activation failed"
    end

    -- True AND NOT(true) -> false.
    world.entities[2].x = 2

    local inactive = RW_EvaluateRules(world)

    if not inactive or #inactive ~= 0 then
        return false, "NOT condition failed"
    end

    -- Restore initial arrangement.
    world.entities[2].x = 3

    local restored = RW_EvaluateRules(world)

    if not restored or #restored ~= 1 then
        return false, "Rule restoration failed"
    end

    -- External producer can supply its own Rule IR.
    -- Move player away from plate, onto entity #2.
    world.entities[1].x = 3

    local generated = {{
        when = {
            op = "any",
            terms = {
                {
                    op = "overlap",
                    left = player,
                    right = plate
                },
                {
                    op = "overlap",
                    left = player,
                    right = other
                }
            }
        },

        effects = {{
            op = "grant_trait",
            target = { kind = "id", value = 2 },
            trait = "highlighted"
        }}
    }}

    local external = RW_EvaluateRules(
        world, generated
    )

    if not external
        or #external ~= 1
        or external[1].trait ~= "highlighted" then
        return false, "External Rule IR failed"
    end

    -- Invalid operators must be rejected.
    local bad = {{
        when = { op = "unknown" },
        effects = {}
    }}

    local result, err =
        RW_EvaluateRules(world, bad)

    if result ~= nil
        or err ~= "unknown_condition_operator" then
        return false, "Invalid IR validation failed"
    end

    return true, "Rule IR evaluation passed"
end
