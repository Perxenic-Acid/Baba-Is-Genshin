
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

-- M9.3C: typed Rule AST -> property IR + conversion declarations.
-- Only positive NOUN IS PROPERTY and simple NOUN IS NOUN
-- are executable. All other relations remain deferred.
function RW_LowerRuleAST(ast_rules)
    if type(ast_rules) ~= "table" then
        return nil, "invalid_ast_rules"
    end

    local generated = {}
    local deferred = {}
    local conversions = {}

    for i, ast in ipairs(ast_rules) do
        if type(ast) ~= "table"
            or type(ast.verb) ~= "string"
            or type(ast.subject) ~= "table"
            or type(ast.object) ~= "table"
            or type(ast.when) ~= "table" then
            return nil, "invalid_ast_rule_" .. tostring(i)
        end

        local subject = ast.subject
        local object = ast.object
        local subject_type = subject.type

        local simple_subject =
            subject.tag == "noun"
            and type(subject_type) == "table"
            and subject_type.tag == "object"
            and type(subject_type.name) == "string"
            and subject_type.name ~= ""

        local property_rule =
            ast.verb == "is"
            and simple_subject
            and object.tag == "property"
            and type(object.name) == "string"
            and object.name ~= ""

        local target_type = object.type
        local conversion_rule =
            ast.verb == "is"
            and simple_subject
            and object.tag == "noun"
            and type(target_type) == "table"
            and target_type.tag == "object"
            and type(target_type.name) == "string"
            and target_type.name ~= ""
            and ast.when.op == "always"

        if property_rule then
            generated[#generated + 1] = {
                when = ast.when,
                effects = {{
                    op = "grant_trait",
                    target = {
                        kind = "archetype",
                        value = subject_type.name
                    },
                    trait = object.name
                }},
                source = ast.source
            }
        elseif conversion_rule then
            if subject_type.name == target_type.name then
                conversions[#conversions + 1] = {
                    op = "protect_transform",
                    source_type = subject_type.name,
                    source = ast.source
                }
            else
                conversions[#conversions + 1] = {
                    op = "transform",
                    source_type = subject_type.name,
                    target_type = target_type.name,
                    source = ast.source
                }
            end
        else
            -- Preserve unsupported syntax verbatim.
            deferred[#deferred + 1] = ast
        end
    end

    return generated, deferred, conversions
end

-- Pure conversion planner: never mutates the world.
-- A IS A protects A from all ordinary IS conversions.
-- Multiple distinct targets currently require a later,
-- explicit one-to-many conversion implementation.
function RW_PlanConversions(world, conversions)
    if type(world) ~= "table"
        or type(world.entities) ~= "table"
        or type(conversions) ~= "table" then
        return nil, "invalid_conversion_input"
    end

    local targets = {}
    local protected = {}
    local conflicts = {}

    for _, relation in ipairs(conversions) do
        if type(relation) ~= "table"
            or type(relation.source_type) ~= "string"
            or relation.source_type == "" then
            return nil, "invalid_conversion_relation"
        end

        local source_type = relation.source_type

        if relation.op == "protect_transform" then
            protected[source_type] = true
        elseif relation.op == "transform"
            and type(relation.target_type) == "string"
            and relation.target_type ~= ""
            and relation.target_type ~= source_type then
            local previous = targets[source_type]

            if previous ~= nil
                and previous ~= relation.target_type then
                conflicts[source_type] = true
            else
                targets[source_type] = relation.target_type
            end
        else
            return nil, "invalid_conversion_relation"
        end
    end

    -- A IS A shields its source from conflicting conversions
    -- independently of the textual rule enumeration order.
    for source_type in pairs(conflicts) do
        if not protected[source_type] then
            return nil, "multiple_conversion_targets"
        end
    end

    local ids = {}

    for id in pairs(world.entities) do
        ids[#ids + 1] = id
    end

    table.sort(ids)

    local changes = {}

    for _, id in ipairs(ids) do
        local entity = world.entities[id]
        local source_type = entity.archetype

        if entity.kind == "object"
            and type(source_type) == "string"
            and targets[source_type] ~= nil
            and not protected[source_type] then
            changes[#changes + 1] = {
                kind = "transform",
                entity_id = id,
                from = source_type,
                to = targets[source_type]
            }
        end
    end

    return changes
end

function RW_ASTLoweringSelfTest()
    local function noun(name)
        return {
            tag = "noun",
            type = { tag = "object", name = name }
        }
    end

    local function rule(verb, subject, object)
        return {
            subject = subject,
            verb = verb,
            object = object,
            when = { op = "always" },
            source = { axis = "horizontal", line = 1 }
        }
    end

    local property = rule(
        "is", noun("crate"),
        { tag = "property", name = "pushable" }
    )
    local transformation = rule("is", noun("crate"), noun("rock"))
    local has = rule("has", noun("crate"), noun("rock"))
    local negation = rule(
        "is", noun("crate"),
        { tag = "not", operand = { tag = "property", name = "pushable" } }
    )
    local special = rule(
        "is", { tag = "special", name = "all" },
        { tag = "property", name = "you" }
    )

    local identity = rule("is", noun("crate"), noun("crate"))

    local executable, deferred, conversions = RW_LowerRuleAST({
        property, transformation, has, negation, special, identity
    })

    if not executable or not deferred or not conversions
        or #executable ~= 1 or #deferred ~= 3
        or #conversions ~= 2 then
        return false, "Executable/deferred partition failed"
    end

    local effect = executable[1].effects[1]

    if effect.op ~= "grant_trait"
        or effect.target.kind ~= "archetype"
        or effect.target.value ~= "crate"
        or effect.trait ~= "pushable"
        or executable[1].source ~= property.source then
        return false, "Property lowering failed"
    end

    -- Unsupported syntax is preserved, not executed.
    if deferred[1] ~= has
        or deferred[2] ~= negation
        or deferred[3] ~= special
        or conversions[1].op ~= "transform"
        or conversions[1].source_type ~= "crate"
        or conversions[1].target_type ~= "rock"
        or conversions[2].op ~= "protect_transform" then
        return false, "Deferred AST provenance lost"
    end

    -- Source AST is not mutated.
    if property.effects ~= nil
        or property.subject.type.name ~= "crate" then
        return false, "AST mutated by lowering"
    end

    local invalid, err = RW_LowerRuleAST({{
        subject = noun("crate"),
        verb = "is",
        object = { tag = "property", name = "you" }
    }})

    if invalid ~= nil or err ~= "invalid_ast_rule_1" then
        return false, "Malformed AST accepted"
    end

    local test_world = {
        entities = {
            [2] = { id = 2, kind = "object", archetype = "crate" },
            [3] = { id = 3, kind = "object", archetype = "crate" },
            [4] = { id = 4, kind = "object", archetype = "avatar" },
            [5] = { id = 5, kind = "text", archetype = "crate" }
        }
    }

    local planned = RW_PlanConversions(test_world, { conversions[1] })

    if not planned or #planned ~= 2
        or planned[1].entity_id ~= 2
        or planned[2].entity_id ~= 3
        or planned[1].to ~= "rock"
        or test_world.entities[2].archetype ~= "crate" then
        return false, "IS NOUN conversion planning failed"
    end

    local guarded = RW_PlanConversions(test_world, conversions)

    if not guarded or #guarded ~= 0 then
        return false, "IS identity protection failed"
    end

    local conflict, conflict_error = RW_PlanConversions(
        test_world,
        {
            conversions[1],
            { op = "transform", source_type = "crate", target_type = "avatar" }
        }
    )

    if conflict ~= nil
        or conflict_error ~= "multiple_conversion_targets" then
        return false, "Conflicting conversions not rejected"
    end

    local protected_conflict = RW_PlanConversions(
        test_world,
        {
            conversions[1],
            { op = "transform", source_type = "crate", target_type = "avatar" },
            conversions[2]
        }
    )

    if not protected_conflict
        or #protected_conflict ~= 0 then
        return false, "Identity guard priority failed"
    end

    return true, "AST property and conversion lowering passed"
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
