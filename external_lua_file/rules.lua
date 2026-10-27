
-- rules.lua
-- RuleWorld M6: Rule IR evaluation

-- One selector implementation serves condition queries and effect targeting.
local SELECTORS = {
    id = {mode = "field", path = {"id"}, value_type = "integer"},
    archetype = {mode = "field", path = {"archetype"}, value_type = "string"},
    class = {mode = "object_class", value_type = "string"}
}
local function query_clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = query_clone(item) end
    return result
end
local function dense_list(value)
    if type(value) ~= "table" then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then return false end
        count = count + 1
    end
    return count == #value
end
local function valid_selectors(registry)
    if type(registry) ~= "table" then return false end
    for name, spec in pairs(registry) do
        if type(name) ~= "string" or name == "" or type(spec) ~= "table"
            or (spec.value_type ~= "string" and spec.value_type ~= "integer") then return false end
        for key in pairs(spec) do
            if key ~= "mode" and key ~= "path" and key ~= "value_type" then return false end
        end
        if spec.mode == "field" then
            if not dense_list(spec.path) or #spec.path == 0 then return false end
            for _, field in ipairs(spec.path) do
                if type(field) ~= "string" or field == "" then return false end
            end
        elseif spec.mode ~= "object_class" or spec.path ~= nil
            or spec.value_type ~= "string" then return false end
    end
    return true
end
local function selector_registry(world)
    if world and world.selectors ~= nil then return world.selectors end
    return SELECTORS
end
function RW_GetSelectorRegistry() return query_clone(SELECTORS) end
function RW_RegisterSelector(registry, name, specification)
    if registry == nil then registry = SELECTORS end
    if not valid_selectors(registry) or type(name) ~= "string" or name == ""
        or type(specification) ~= "table"
        or not valid_selectors({[name] = specification}) then
        return nil, "invalid_selector_registration"
    end
    if registry[name] ~= nil then return nil, "duplicate_selector" end
    local result = query_clone(registry)
    result[name] = query_clone(specification)
    return result
end

function RW_SelectorSelfTest()
    local spec = {mode = "field", path = {"direction"}, value_type = "string"}
    local registry = RW_RegisterSelector(nil, "facing", spec)
    if not registry then return false, "Selector registration failed" end
    spec.path[1] = "archetype"
    if registry.facing.path[1] ~= "direction" or RW_GetSelectorRegistry().facing ~= nil
        or RW_RegisterSelector(registry, "facing", registry.facing) ~= nil then
        return false, "Selector registration isolation/duplicate failed"
    end
    local world = {selectors = registry, entities = {
        [3] = {id = 3, kind = "object", class = "text", x = 2, y = 2, direction = "Left"},
        [1] = {id = 1, kind = "object", class = "object", x = 2, y = 2, direction = "Left"},
        [2] = {id = 2, kind = "object", class = "object", x = 4, y = 2, direction = "Right"}
    }, rule_sources = {{when = {op = "overlap",
        left = {kind = "facing", value = "Left"}, right = {kind = "class", value = "text"}},
        effects = {{op = "grant_trait", target = {kind = "facing", value = "Left"}, trait = "drive"}}}}}
    local ids = RW_SelectEntities(world, {kind = "facing", value = "Left"})
    local effects = RW_EvaluateRules(world)
    if not ids or #ids ~= 2 or ids[1] ~= 1 or ids[2] ~= 3
        or not effects or #effects ~= 1 or effects[1].entity_ids[1] ~= 1
        or effects[1].entity_ids[2] ~= 3 then
        return false, "Shared conditional/effect selection failed"
    end
    world.entities[1].x = 3
    if #RW_EvaluateRules(world) ~= 0 then return false, "Self-overlap activated rule" end
    local objects = RW_SelectEntities(world, {kind = "class", value = "object"})
    if #objects ~= 3 then return false, "Object superclass selection lost Text" end
    world.selectors = false
    if RW_SelectEntities(world, {kind = "id", value = 1}) ~= nil
        or RW_EvaluateRules(world) ~= nil then return false, "Invalid selector registry accepted" end
    return true, "Shared selector registration, conditions and concrete effect targets passed"
end
local function valid_selector(selector, world)
    if type(selector) ~= "table" or type(selector.kind) ~= "string" then return false end
    local spec = selector_registry(world)[selector.kind]
    if not spec then return false end
    if spec.value_type == "integer" then
        return type(selector.value) == "number" and selector.value == selector.value
            and selector.value % 1 == 0
    end
    return type(selector.value) == "string" and selector.value ~= ""
end
local function matches(entity, selector, world)
    local spec = selector_registry(world)[selector.kind]
    if spec.mode == "object_class" then
        return entity.kind == "object"
            and (selector.value == "object" or entity.class == selector.value)
    end
    local value = entity
    for _, field in ipairs(spec.path) do
        if type(value) ~= "table" then return false end
        value = value[field]
    end
    return value == selector.value
end
function RW_SelectEntities(world, selector)
    if type(world) ~= "table" or type(world.entities) ~= "table" then return nil, "invalid_world" end
    if not valid_selectors(selector_registry(world)) then return nil, "invalid_selector_registry" end
    if not valid_selector(selector, world) then return nil, "invalid_selector" end
    local ids = {}
    for id, entity in pairs(world.entities) do
        if type(id) ~= "number" or id % 1 ~= 0 or id < 1 or type(entity) ~= "table"
            or entity.id ~= id then return nil, "invalid_entity_identity" end
        if matches(entity, selector, world) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

-- Concrete effects are short-lived results for this world, not saved rules.
function RW_ResolveEffects(world, effects)
    if type(world) ~= "table" or type(world.entities) ~= "table" then return nil, "invalid_world" end
    if not valid_selectors(selector_registry(world)) then return nil, "invalid_selector_registry" end
    if not dense_list(effects) then return nil, "invalid_effects" end
    local result = {}
    for _, effect in ipairs(effects) do
        if type(effect) ~= "table" or (effect.op ~= "grant_trait" and effect.op ~= "deny_trait")
            or type(effect.trait) ~= "string" or effect.trait == "" then
            return nil, "invalid_rule_effect"
        end
        local ids, err = RW_SelectEntities(world, effect.target)
        if not ids then return nil, err end
        result[#result + 1] = {op = effect.op, trait = effect.trait,
            target = {kind = effect.target.kind, value = effect.target.value}, entity_ids = ids}
    end
    return result
end

local function overlaps(world, left, right)
    for id_a, a in pairs(world.entities) do
        if matches(a, left, world) then
            for id_b, b in pairs(world.entities) do
                if id_a ~= id_b
                    and matches(b, right, world)
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
        if not valid_selector(node.left, world)
            or not valid_selector(node.right, world) then
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

local function valid_effect(effect, world)
    return type(effect) == "table"
        and (effect.op == "grant_trait" or effect.op == "deny_trait")
        and valid_selector(effect.target, world)
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

    if not valid_selectors(selector_registry(world)) then return nil, "invalid_selector_registry" end

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
                if not valid_effect(effect, world) then
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

    return RW_ResolveEffects(world, active)
end

-- M9.3H: relation semantics are level-selected data, separate from parsing.
local DEFAULT_SEMANTICS = {is = {property = "grant_trait", noun = "transform", negative_property="deny_trait",negative_noun="forbid_transform"}, has = {noun="contain"}}
local function semantic_clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = semantic_clone(item) end
    return result
end
local function valid_semantics(registry)
    if type(registry) ~= "table" then return false end
    for name, spec in pairs(registry) do
        if type(name) ~= "string" or name == "" or type(spec) ~= "table" then return false end
        if spec.property == nil and spec.noun == nil then return false end
        for category, operation in pairs(spec) do
            if not ((category == "property" and operation == "grant_trait")
                or (category == "noun" and (operation == "transform" or operation == "contain"))
                or (category == "negative_property" and operation == "deny_trait")
                or (category == "negative_noun" and operation == "forbid_transform")) then return false end
        end
    end
    return true
end
function RW_GetSemanticRegistry()
    return semantic_clone(DEFAULT_SEMANTICS)
end
function RW_RegisterSemantics(registry, name, specification)
    if registry == nil then registry = DEFAULT_SEMANTICS end
    if not valid_semantics(registry) or type(name) ~= "string" or name == ""
        or type(specification) ~= "table" then return nil, "invalid_semantic_registration" end
    if registry[name] ~= nil then return nil, "duplicate_semantics" end
    if not valid_semantics({[name] = specification}) then
        return nil, "invalid_semantic_registration"
    end
    local result = semantic_clone(registry)
    result[name] = semantic_clone(specification)
    if not valid_semantics(result) then return nil, "invalid_semantic_registration" end
    return result
end

-- M9.3C: typed Rule AST -> property IR + conversion declarations.
-- Default IS executes positive properties/conversions; HAS declares contents.
-- A level registry may assign those capabilities to a different relation ID.
function RW_LowerRuleAST(ast_rules, registry)
    if type(ast_rules) ~= "table" then
        return nil, "invalid_ast_rules"
    end

    if registry == nil then registry = DEFAULT_SEMANTICS end
    if not valid_semantics(registry) then return nil, "invalid_semantic_registry" end

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

        local semantics = registry[ast.verb]
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
            semantics and semantics.property == "grant_trait"
            and simple_subject
            and object.tag == "property"
            and type(object.name) == "string"
            and object.name ~= ""

        local target_type = object.type
        local conversion_rule =
            semantics and semantics.noun == "transform"
            and simple_subject
            and object.tag == "noun"
            and type(target_type) == "table"
            and target_type.tag == "object"
            and type(target_type.name) == "string"
            and target_type.name ~= ""
            and ast.when.op == "always"

        local level_subject = subject.tag == "noun" and type(subject_type) == "table"
            and subject_type.tag == "level" and ast.when.op == "always"
        local has_subject
        if simple_subject then has_subject={kind="archetype",value=subject_type.name}
        elseif level_subject then has_subject={kind="archetype",value=subject_type.block_type or "level_block"}
        elseif subject.tag == "special" and subject.name == "text" then has_subject={kind="class",value="text"} end
        local has_product
        if object.tag == "noun" and type(target_type) == "table" then
            if target_type.tag == "object" and type(target_type.name) == "string" and target_type.name ~= "" then
                has_product={kind="object",archetype=target_type.name}
            elseif target_type.tag == "level" then has_product={kind="object",archetype=target_type.block_type or "level_block"} end
        elseif object.tag == "special" and object.name == "text" then has_product={kind="text"} end
        local negated=object.tag == "not" and object.operand or nil
        if semantics and semantics.negative_property == "deny_trait" and has_subject
            and negated and negated.tag == "property" and type(negated.name) == "string" then
            generated[#generated+1]={when=ast.when,effects={{op="deny_trait",target=has_subject,trait=negated.name}},source=ast.source}
        elseif semantics and semantics.negative_noun == "forbid_transform" and simple_subject and negated
            and ast.when.op == "always" and ((negated.tag == "special" and negated.name == "text")
                or (negated.tag == "noun" and type(negated.type) == "table" and negated.type.tag == "object")) then
            conversions[#conversions+1]={op="forbid_transform",source_type=subject_type.name,
                target_type=negated.tag == "special" and "@text" or negated.type.name,source=ast.source}
        elseif simple_subject and semantics and semantics.noun == "transform"
            and object.tag == "special" and object.name == "text" and ast.when.op == "always" then
            conversions[#conversions+1]={op="transform_text",source_type=subject_type.name,source=ast.source}
        elseif semantics and semantics.noun == "contain" and has_subject and has_product and ast.when.op == "always" then
            conversions[#conversions+1]={op="has",target=has_subject,product=has_product,source=ast.source}
        elseif subject.tag == "special" and subject.name == "text" and semantics and semantics.property == "grant_trait"
            and object.tag == "property" and type(object.name) == "string" and object.name ~= "" then
            generated[#generated+1]={when=ast.when,effects={{op="grant_trait",target={kind="class",value="text"},trait=object.name}},source=ast.source}
        elseif level_subject and semantics and semantics.property == "grant_trait"
            and object.tag == "property" and type(object.name) == "string" and object.name ~= "" then
            conversions[#conversions+1] = {op="level_trait",trait=object.name,source=ast.source}
            generated[#generated+1] = {when=ast.when,effects={{op="grant_trait",
                target={kind="archetype",value=subject_type.block_type or "level_block"},trait=object.name}},source=ast.source}
        elseif simple_subject and semantics and semantics.noun == "transform"
            and object.tag == "noun" and type(target_type) == "table" and target_type.tag == "level"
            and ast.when.op == "always" then
            conversions[#conversions+1] = {op="transform",source_type=subject_type.name,
                target_type=target_type.block_type or "level_block",source=ast.source}
        elseif level_subject and semantics and semantics.noun == "transform"
            and object.tag == "noun" and type(target_type) == "table"
            and target_type.tag == "object" and type(target_type.name) == "string" and target_type.name ~= "" then
            conversions[#conversions+1] = {op="transform_level", target_type=target_type.name,
                source=ast.source}
            conversions[#conversions+1] = {op="transform",source_type=subject_type.block_type or "level_block",
                target_type=target_type.name,source=ast.source}
        elseif level_subject and semantics and semantics.noun == "transform"
            and object.tag == "noun" and type(target_type) == "table" and target_type.tag == "level" then
            conversions[#conversions+1] = {op="protect_level", source=ast.source}
            conversions[#conversions+1] = {op="protect_transform",
                source_type=subject_type.block_type or "level_block",source=ast.source}
        elseif property_rule then
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

function RW_SemanticRegistrationSelfTest()
    local spec = {property = "grant_trait", noun = "transform"}
    local registry = RW_RegisterSemantics(nil, "bind", spec)
    if not registry or RW_GetSemanticRegistry().bind ~= nil then
        return false, "Semantic registration isolation failed"
    end
    spec.property = "bad"
    if registry.bind.property ~= "grant_trait"
        or RW_RegisterSemantics(registry, "bind", registry.bind) ~= nil then
        return false, "Semantic alias/duplicate failed"
    end
    local ast = {{verb = "bind", subject = {tag = "noun", type = {tag = "object", name = "crate"}},
        object = {tag = "property", name = "pushable"}, when = {op = "always"}}}
    local generated, deferred = RW_LowerRuleAST(ast, registry)
    local absent, preserved = RW_LowerRuleAST(ast)
    if not generated or #generated ~= 1 or #deferred ~= 0
        or not absent or #absent ~= 0 or #preserved ~= 1 or preserved[1] ~= ast[1] then
        return false, "Registered/missing semantics execution boundary failed"
    end
    local disabled, retained = RW_LowerRuleAST(ast, {})
    if not disabled or #disabled ~= 0 or #retained ~= 1 then
        return false, "Explicit empty semantic registry ignored"
    end
    if RW_RegisterSemantics(nil, "bad", {property = "unknown"}) ~= nil
        or RW_LowerRuleAST(ast, false) ~= nil then
        return false, "Invalid semantics accepted"
    end
    return true, "Isolated semantic registration and deferred fallback passed"
end

-- Pure conversion planner: never mutates the world.
-- A IS A protects A from all ordinary IS conversions.
-- One rule instance keeps the source ID; every additional instance gets a fresh ID.
-- All products use the same pre-conversion snapshot (no within-turn cascade).
-- Canonical physical noun token, shared by WORD, IS TEXT and HAS TEXT.
function RW_NounTextName(world, entity)
    if entity.class == "text" then return "TEXT" end
    local names={}
    for name,value in pairs((world.language or {}).nouns or {}) do
        if value == entity.archetype or (type(value) == "table" and
            ((value.tag == "object" and value.name == entity.archetype) or
             (value.tag == "level" and (value.block_type or "level_block") == entity.archetype))) then names[#names+1]=name end
    end
    table.sort(names)
    return names[1] or string.upper(entity.archetype or "OBJECT")
end
function RW_WordTokenMap(world, effective)
    local tokens={}
    for id,entity in pairs(effective.entities) do
        if entity.class ~= "text" and entity.behaviors and entity.behaviors.word then
            tokens[id]=RW_NounTextName(world,entity)
        end
    end
    return tokens
end
function RW_PlanConversions(world, conversions)
    if type(world) ~= "table" or type(world.entities) ~= "table"
        or not dense_list(conversions) then return nil,"invalid_conversion_input" end
    local targets, protected, forbidden = {}, {}, {}
    for _, relation in ipairs(conversions) do
        if type(relation) ~= "table" or type(relation.source_type) ~= "string"
            or relation.source_type == "" then return nil,"invalid_conversion_relation" end
        local source = relation.source_type
        if relation.op == "protect_transform" then protected[source] = true
        elseif relation.op == "forbid_transform" and type(relation.target_type) == "string" then
            forbidden[source]=forbidden[source] or {}; forbidden[source][relation.target_type]=true
        elseif relation.op == "transform_text" or (relation.op == "transform" and type(relation.target_type) == "string"
            and relation.target_type ~= "" and relation.target_type ~= source) then
            targets[source] = targets[source] or {}
            targets[source][#targets[source]+1] = relation.op == "transform_text" and "@text" or relation.target_type
        else return nil,"invalid_conversion_relation" end
    end
    local ids = {}
    for id in pairs(world.entities) do ids[#ids+1] = id end
    table.sort(ids)
    local changes, next_id, created = {}, world.next_entity_id,0
    for _, id in ipairs(ids) do
        local entity = world.entities[id]
        local source = entity.archetype
        if entity.kind == "object" and entity.class ~= "text" and targets[source] and not protected[source] then
            local index=0
            for _,target in ipairs(targets[source]) do
                if not (forbidden[source] and forbidden[source][target]) then
                    index=index+1
                    local product=query_clone(entity)
                    product.traits,product.behaviors,product.symbol=nil,nil,nil
                    if target == "@text" then
                        product.class,product.archetype,product.text="text",nil,{name=RW_NounTextName(world,entity)}
                    else product.archetype=target end
                    if index == 1 then
                        if target == "@text" then changes[#changes+1]={kind="retype",entity_id=id,from=query_clone(entity),to=product}
                        else changes[#changes+1]={kind="transform",entity_id=id,from=source,to=target} end
                    else
                        if type(next_id) ~= "number" or next_id % 1 ~= 0 or next_id < 1 or world.entities[next_id] then return nil,"invalid_conversion_frontier" end
                        if next_id >= 9007199254740991 then return nil,"entity_id_exhausted" end
                        product.id=next_id
                        changes[#changes+1]={kind="create",entity_id=next_id,to=product}
                        next_id,created=next_id+1,created+1
                    end
                end
            end
        end
    end
    local allocation
    if created > 0 then allocation={from=world.next_entity_id,to=next_id} end
    return changes,nil,allocation
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
        or #executable ~= 2 or #deferred ~= 1
        or #conversions ~= 3 then
        return false, "Executable/deferred partition failed"
    end

    local effect = executable[1].effects[1]

    if (effect.op ~= "grant_trait" and effect.op ~= "deny_trait")
        or effect.target.kind ~= "archetype"
        or effect.target.value ~= "crate"
        or effect.trait ~= "pushable"
        or executable[1].source ~= property.source then
        return false, "Property lowering failed"
    end

    -- Unsupported syntax is preserved, not executed.
    if deferred[1] ~= special
        or executable[2].effects[1].op ~= "deny_trait"
        or conversions[1].op ~= "transform"
        or conversions[1].source_type ~= "crate"
        or conversions[1].target_type ~= "rock"
        or conversions[2].op ~= "has"
        or conversions[3].op ~= "protect_transform" then
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
        next_entity_id = 6,
        entities = {
            [2] = { id = 2, kind = "object", archetype = "crate" },
            [3] = { id = 3, kind = "object", archetype = "crate" },
            [4] = { id = 4, kind = "object", archetype = "avatar" },
            [5] = { id = 5, kind = "object", class = "text",
                    archetype = "crate", text = { name = "CRATE" } }
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

    local guarded = RW_PlanConversions(test_world, {conversions[1],conversions[3]})

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

    if not conflict or #conflict ~= 4 or conflict_error
        or conflict[2].kind ~= "create" or conflict[2].entity_id ~= 6
        or conflict[4].entity_id ~= 7 then
        return false, "One-to-many conversion planning failed"
    end

    local repeated, repeated_error, allocation = RW_PlanConversions(test_world, {
        conversions[1],conversions[1],conversions[1]})
    if not repeated or repeated_error or #repeated ~= 6
        or not allocation or allocation.to ~= 10 then
        return false,"Repeated conversion instances collapsed"
    end

    local protected_conflict = RW_PlanConversions(
        test_world,
        {
            conversions[1],
            { op = "transform", source_type = "crate", target_type = "avatar" },
            conversions[3]
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

    -- A Text is an Object, but not every Object is Text.
    local class_world = {
        entities = {
            [1] = {
                id = 1, kind = "object", class = "text",
                x = 1, y = 1, text = { name = "BOX" }
            },
            [2] = {
                id = 2, kind = "object", class = "object",
                x = 1, y = 1
            }
        },
        rule_sources = {{
            when = {
                op = "overlap",
                left = { kind = "class", value = "text" },
                right = { kind = "class", value = "object" }
            },
            effects = {{
                op = "grant_trait",
                target = { kind = "class", value = "text" },
                trait = "pushable"
            }}
        }}
    }

    local class_effects = RW_EvaluateRules(class_world)

    if not class_effects
        or #class_effects ~= 1
        or class_effects[1].target.kind ~= "class" then
        return false, "Class selector condition failed"
    end

    return true, "Rule IR evaluation passed"
end

-- HAS products are planned from the destruction snapshot, never from conversion.
-- Repeated relations remain repeated products. Newly born objects are not destroyed
-- recursively by this helper; later contact phases decide what happens to them.
function RW_PlanHasBirths(world, victims, relations)
    if type(world) ~= "table" or type(world.entities) ~= "table" or not dense_list(victims)
        or not dense_list(relations) then return nil,"invalid_has_input" end
    for _,relation in ipairs(relations) do
        if type(relation) ~= "table" or relation.op ~= "has" or not valid_selector(relation.target,world)
            or type(relation.product) ~= "table" or (relation.product.kind ~= "object" and relation.product.kind ~= "text")
            or (relation.product.kind == "object" and (type(relation.product.archetype) ~= "string" or relation.product.archetype == "")) then
            return nil,"invalid_has_relation"
        end
    end
    local specifications, seen = {}, {}
    for _,id in ipairs(victims) do
        local entity=world.entities[id]
        if not entity or seen[id] then return nil,"invalid_has_victim" end
        seen[id]=true
        for _,relation in ipairs(relations) do
            if matches(entity,relation.target,world) then
                local product={kind="object",class=relation.product.kind == "text" and "text" or "object",
                    x=entity.x,y=entity.y,direction=entity.direction}
                if product.class == "text" then product.text={name=RW_NounTextName(world,entity)}
                else
                    product.archetype=relation.product.archetype
                    product.level_link=query_clone(entity.level_link)
                end
                specifications[#specifications+1]=product
            end
        end
    end
    return specifications
end
