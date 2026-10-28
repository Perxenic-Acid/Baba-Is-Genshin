
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
    if selector.kind == "empty" then return selector.value == "empty" end
    local spec = selector_registry(world)[selector.kind]
    if not spec then return false end
    if spec.value_type == "integer" then
        return type(selector.value) == "number" and selector.value == selector.value
            and selector.value % 1 == 0
    end
    return type(selector.value) == "string" and selector.value ~= ""
end
local function matches(entity, selector, world)
    if selector.kind == "empty" then return false end
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
-- Contextual conditions are tested against one identity (or one virtual Empty cell).
function RW_TestEntityCondition(world,node,entity)
    if type(node) ~= "table" then return nil,"invalid_condition" end
    if node.op == "always" then return true end
    if node.op == "not" then
        local value,err=RW_TestEntityCondition(world,node.condition,entity)
        if value == nil then return nil,err end;return not value
    end
    if node.op == "all" then
        if not dense_list(node.terms) then return nil,"invalid_condition_terms" end
        local result=true
        for _,term in ipairs(node.terms) do local v,e=RW_TestEntityCondition(world,term,entity)
            if v == nil then return nil,e end;result=result and v end
        return result
    end
    if node.op ~= "spatial" or not dense_list(node.clauses) or #node.clauses == 0
        or type(entity) ~= "table" or type(entity.x) ~= "number" or type(entity.y) ~= "number" then
        return nil,"invalid_spatial_condition"
    end
    if type(world.width) ~= "number" or type(world.height) ~= "number" then return nil,"invalid_spatial_grid" end
    local function term_value(term)
        local negative=false
        for depth=1,256 do
            if type(term) ~= "table" then return nil end
            if term.tag ~= "not" then
                if term.tag == "noun" and type(term.type) == "table" then
                    return term.type.tag == "level" and "@level" or term.type.name,negative
                elseif term.tag == "special" then return "@" .. term.name,negative
                elseif term.tag == "property" and (term.name=="right" or term.name=="up" or term.name=="left" or term.name=="down") then
                    return "@direction:"..term.name,negative end
                return nil
            end
            negative=not negative;term=term.operand
        end
    end
    local result=true
    for _,clause in ipairs(node.clauses) do
        if type(clause) ~= "table" or (clause.relation ~= "on" and clause.relation ~= "near" and clause.relation ~= "nextto"
                and clause.relation ~= "above" and clause.relation ~= "below" and clause.relation ~= "besideleft"
                and clause.relation ~= "besideright" and clause.relation ~= "facing")
            or type(clause.negated) ~= "boolean" or not dense_list(clause.parameters) or #clause.parameters == 0 then
            return nil,"invalid_spatial_clause"
        end
        local parameters={}
        for _,term in ipairs(clause.parameters) do
            local name,negative=term_value(term)
            if not name then return nil,"invalid_spatial_parameter" end
            if name == "@all" then
                if negative then
                    parameters[#parameters+1]={name="@empty"};parameters[#parameters+1]={name="@text"}
                else for _,ordinary in ipairs(RW_NounPalette(world)) do parameters[#parameters+1]={name=ordinary} end end
            else parameters[#parameters+1]={name=name,negative=negative} end
        end
        -- testcond evaluates concrete parameters before complements; positives reverse
        -- physical order, negatives retain it. This matters when witnesses overlap.
        local ordered={}
        for _,parameter in ipairs(parameters) do
            if parameter.negative then ordered[#ordered+1]=parameter else table.insert(ordered,1,parameter) end
        end
        parameters=ordered
        local vectors={Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}}
        local vector=vectors[entity.direction]
        local function in_region(x,y)
            local dx,dy=x-entity.x,y-entity.y
            local relation=clause.relation
            if relation=="on" then return dx==0 and dy==0 end
            if relation=="near" then return math.abs(dx)<=1 and math.abs(dy)<=1 end
            if relation=="nextto" then return math.abs(dx)+math.abs(dy)==1 end
            if relation=="above" then return dx==0 and dy>0 end
            if relation=="below" then return dx==0 and dy<0 end
            if relation=="besideleft" then return dy==0 and dx>0 end
            if relation=="besideright" then return dy==0 and dx<0 end
            if relation=="facing" then return vector and dx==vector[1] and dy==vector[2] end
        end
        local candidates={}
        for id,target in pairs(world.entities) do
            if id ~= entity.id and in_region(target.x,target.y) then candidates[#candidates+1]=target end
        end
        table.sort(candidates,function(a,b)
            if a.x ~= b.x then return a.x < b.x end
            if a.y ~= b.y then return a.y < b.y end
            return a.id < b.id
        end)
        local used,allfound={},0
        for _,parameter in ipairs(parameters) do
            local matched,contribution=false,nil
            if parameter.name:sub(1,11)=="@direction:" then
                if clause.relation~="facing" then return nil,"invalid_spatial_parameter" end
                local expected=parameter.name:sub(12)
                local same=entity.direction and entity.direction:lower()==expected
                if vector and ((not parameter.negative and same) or (parameter.negative and not same)) then matched=true end
            elseif parameter.name == "@level" and not parameter.negative and not used["@level"] then
                used["@level"]=true;matched=true
            elseif parameter.name == "@empty" and parameter.negative and clause.relation == "on" then
                -- Original ON NOT EMPTY consumes/counts every remaining co-occupant.
                contribution=0
                if entity.class ~= "empty" then
                    for _,target in ipairs(candidates) do
                        if not used[target.id] then used[target.id]=true;contribution=contribution+1 end
                    end
                end
            elseif parameter.name == "@empty" then
                local xmin,xmax,ymin,ymax=1,world.width,1,world.height
                local relation=clause.relation
                if relation=="on" then xmin,xmax,ymin,ymax=entity.x,entity.x,entity.y,entity.y
                elseif relation=="near" or relation=="nextto" then
                    xmin,xmax=math.max(1,entity.x-1),math.min(world.width,entity.x+1)
                    ymin,ymax=math.max(1,entity.y-1),math.min(world.height,entity.y+1)
                elseif relation=="facing" then
                    if vector then
                        xmin,xmax=math.max(1,entity.x+vector[1]),math.min(world.width,entity.x+vector[1])
                        ymin,ymax=math.max(1,entity.y+vector[2]),math.min(world.height,entity.y+vector[2])
                    else xmax=0 end
                elseif relation=="above" then xmin,xmax,ymin=entity.x,entity.x,entity.y+1
                elseif relation=="below" then xmin,xmax,ymax=entity.x,entity.x,entity.y-1
                elseif relation=="besideleft" then xmin,ymin,ymax=entity.x+1,entity.y,entity.y
                elseif relation=="besideright" then xmax,ymin,ymax=entity.x-1,entity.y,entity.y end
                for x=xmin,xmax do for y=ymin,ymax do
                    local dx,dy=x-entity.x,y-entity.y
                    local key="empty:" .. x .. ":" .. y
                    if in_region(x,y) and (clause.relation=="facing" or not used[key]) then
                        local occupied=false
                        for _,target in pairs(world.entities) do if target.x == x and target.y == y then occupied=true;break end end
                        local empty=not occupied
                        if dx == 0 and dy == 0 then
                            if entity.class == "empty" then empty=false
                            elseif parameter.negative then
                                local others=0;for _,target in pairs(world.entities) do if target.x == x and target.y == y then others=others+1 end end
                                if others <= 1 then empty=true end
                            end
                        end
                        if not (clause.relation == "on" and entity.class == "empty") and
                            ((not parameter.negative and empty) or (parameter.negative and not empty)) then
                            if not matched then used[key]=true;matched=true end
                        end
                    end
                end end
            else
                for _,target in ipairs(candidates) do
                    local name=target.class == "text" and "@text" or target.archetype
                    local expected=parameter.name == "@level" and "level_block" or parameter.name
                    local eligible=parameter.negative and name ~= expected and name ~= "@text"
                        or not parameter.negative and name == expected
                    if eligible and not used[target.id] then used[target.id]=true;matched=true;break end
                end
            end
            allfound=allfound+(contribution or (matched and 1 or 0))
        end
        local found=allfound == #parameters
        if clause.relation=="facing" and not vector then found=false end
        if clause.negated then found=not found end
        result=result and found
    end
    return result
end

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
        if effect.when then
            local _,why=RW_TestEntityCondition(world,effect.when,{class="empty",x=1,y=1})
            if why then return nil,why end
            local selected={}
            for _,id in ipairs(ids) do
                local enabled,why=RW_TestEntityCondition(world,effect.when,world.entities[id])
                if enabled == nil then return nil,why end
                if enabled then selected[#selected+1]=id end
            end
            ids=selected
        end
        local resolved={op=effect.op,trait=effect.trait,when=effect.when,
            target={kind=effect.target.kind,value=effect.target.value},entity_ids=ids}
        if effect.target.kind == "empty" then
            if type(world.width) ~= "number" or type(world.height) ~= "number"
                or world.width % 1 ~= 0 or world.height % 1 ~= 0 or world.width < 1 or world.height < 1 then
                return nil,"invalid_empty_grid"
            end
            resolved.cells={}
            local occupied={}
            for _,entity in pairs(world.entities) do occupied[entity.x .. ":" .. entity.y]=true end
            for y=1,world.height do for x=1,world.width do
                if not occupied[x .. ":" .. y] then
                    local enabled,why=true,nil
                    if effect.when then enabled,why=RW_TestEntityCondition(world,effect.when,{class="empty",x=x,y=y}) end
                    if enabled == nil then return nil,why end
                    if enabled then resolved.cells[#resolved.cells+1]={x=x,y=y} end
                end
            end end
        end
        result[#result+1]=resolved
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

            local enabled,err
            if rule.when and rule.when.op == "spatial" then enabled=true
            else enabled,err=evaluate_condition(world,rule.when) end

            if enabled == nil then
                return false, err
            end

            if enabled then
                for _, effect in ipairs(rule.effects) do
                    active[#active + 1] = {
                        op = effect.op,
                        when = rule.when.op == "spatial" and query_clone(rule.when) or nil,
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
local DEFAULT_SEMANTICS = {become={noun="become",negative_noun="forbid_become"},eat={noun="eat",negative_noun="forbid_eat"},make={noun="make",negative_noun="forbid_make"},follow={noun="follow",negative_noun="forbid_follow"},fear={noun="fear",negative_noun="forbid_fear"},is = {property = "grant_trait", noun = "transform", negative_property="deny_trait",negative_noun="forbid_transform"}, has = {noun="contain",negative_noun="forbid_contain"}, write={noun="write_text",negative_noun="forbid_write"}}
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
                or (category == "noun" and (operation == "transform" or operation == "contain" or operation == "write_text" or operation == "fear" or operation == "follow" or operation == "make" or operation == "eat" or operation == "become"))
                or (category == "negative_property" and operation == "deny_trait")
                or (category == "negative_noun" and (operation == "forbid_transform" or operation == "forbid_contain" or operation == "forbid_write" or operation == "forbid_fear" or operation == "forbid_follow" or operation == "forbid_make" or operation == "forbid_eat" or operation == "forbid_become"))) then return false end
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
local function lower_simple(ast_rules, registry)
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
            if level_subject then conversions[#conversions+1]={op="deny_level_trait",trait=negated.name,source=ast.source} end
        elseif semantics and semantics.negative_noun == "forbid_transform" and simple_subject and negated
            and ast.when.op == "always" and ((negated.tag == "special" and negated.name == "text")
                or (negated.tag == "noun" and type(negated.type) == "table" and negated.type.tag == "object")) then
            conversions[#conversions+1]={op="forbid_transform",source_type=subject_type.name,
                target_type=negated.tag == "special" and "@text" or negated.type.name,source=ast.source}
        elseif level_subject and semantics and semantics.noun == "transform"
            and object.tag == "special" and object.name == "text" then
            conversions[#conversions+1]={op="transform_level",target_type="text_level",source=ast.source}
            conversions[#conversions+1]={op="transform_text",source_type=subject_type.block_type or "level_block",source=ast.source}
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
function RW_RelationApplies(world,relation,entity)
    if relation.exclusions ~= nil and not dense_list(relation.exclusions) then return nil,"invalid_relation_exclusions" end
    if relation.when then
        local enabled,err=RW_TestEntityCondition(world,relation.when,entity)
        if enabled == nil then return nil,err end
        if not enabled then return false end
    end
    for _,condition in ipairs(relation.exclusions or {}) do
        local disabled,err=RW_TestEntityCondition(world,condition,entity)
        if disabled == nil then return nil,err end
        if disabled then return false end
    end
    return true
end
function RW_PlanConversions(world, conversions)
    if type(world) ~= "table" or type(world.entities) ~= "table"
        or not dense_list(conversions) then return nil,"invalid_conversion_input" end
    local targets,protected,forbidden,conditional={},{},{},{}
    for _,relation in ipairs(conversions) do
        if type(relation) ~= "table" or type(relation.source_type) ~= "string" or relation.source_type == "" then
            return nil,"invalid_conversion_relation"
        end
        local source=relation.source_type
        if relation.when or relation.exclusions then
            if relation.op ~= "protect_transform" and relation.op ~= "forbid_transform" and relation.op ~= "write_text"
                and relation.op ~= "transform_text" and relation.op ~= "transform_all" and relation.op ~= "transform"
                and relation.op ~= "become" and relation.op ~= "forbid_become" then
                return nil,"invalid_conversion_relation"
            end
            if (relation.op == "write_text" and (type(relation.target_text) ~= "string" or relation.target_text == ""))
                or ((relation.op == "transform" or relation.op == "forbid_transform" or relation.op=="become" or relation.op=="forbid_become")
                    and (type(relation.target_type) ~= "string" or relation.target_type == "")) then
                return nil,"invalid_conversion_relation"
            end
            local _,why=RW_RelationApplies(world,relation,{class="empty",x=1,y=1})
            if why then return nil,why end
            conditional[source]=conditional[source] or {};conditional[source][#conditional[source]+1]=relation
        elseif relation.op == "protect_transform" then protected[source]=true
        elseif relation.op == "forbid_transform" and type(relation.target_type) == "string" then
            forbidden[source]=forbidden[source] or {}; forbidden[source][relation.target_type]=true
        elseif relation.op == "write_text" and type(relation.target_text) == "string" and relation.target_text ~= "" then
            targets[source]=targets[source] or {}
            targets[source][#targets[source]+1]={text_name=relation.target_text}
        elseif relation.op == "transform_text" or relation.op == "transform_all" or
            (relation.op == "transform" and type(relation.target_type) == "string" and relation.target_type ~= "" and relation.target_type ~= source) then
            targets[source]=targets[source] or {}
            targets[source][#targets[source]+1]=relation.op == "transform_text" and "@text"
                or (relation.op == "transform_all" and "@all" or relation.target_type)
        else return nil,"invalid_conversion_relation" end
    end
    local ids,occupied={},{}
    for id,entity in pairs(world.entities) do
        ids[#ids+1]=id; if entity.x and entity.y then occupied[entity.x .. ":" .. entity.y]=true end
    end
    table.sort(ids)
    local changes,next_id,created={},world.next_entity_id,0
    local converted_ids={}
    local function create(product)
        if type(next_id) ~= "number" or next_id % 1 ~= 0 or next_id < 1 or world.entities[next_id] then return nil,"invalid_conversion_frontier" end
        if next_id >= 9007199254740991 then return nil,"entity_id_exhausted" end
        product.id=next_id
        changes[#changes+1]={kind="create",entity_id=next_id,to=product}
        next_id,created=next_id+1,created+1; return true
    end
    local function convert(entity,source,virtual)
        local bans=query_clone(forbidden[source] or {})
        local choices=query_clone(targets[source] or {})
        local protect=protected[source]
        local become_bans={}
        for _,relation in ipairs(conditional[source] or {}) do
            local enabled,err=RW_RelationApplies(world,relation,virtual and {class="empty",x=entity.x,y=entity.y} or entity)
            if enabled == nil then return nil,err end
            if enabled then
                if relation.op == "protect_transform" then protect=true
                elseif relation.op == "forbid_transform" then bans[relation.target_type]=true
                elseif relation.op=="forbid_become" then become_bans[relation.target_type]=true
                elseif relation.op=="become" then choices[#choices+1]={become_target=relation.target_type}
                elseif relation.op == "write_text" then choices[#choices+1]={text_name=relation.target_text}
                else choices[#choices+1]=relation.op == "transform_text" and "@text"
                    or relation.op == "transform_all" and "@all" or relation.target_type end
            end
        end
        local has_become=false
        for _,choice in ipairs(choices) do if type(choice)=="table" and choice.become_target then has_become=true;break end end
        -- Preserve established IS self-negation, while BECOME is independently selected.
        if bans[source] and not has_become then
            if not virtual then changes[#changes+1]={kind="delete",entity_id=entity.id,from=query_clone(entity)} end
            return true
        end
        local products,retain,remove={},false,bans[source] or become_bans[source] or false
        for _,choice in ipairs(choices) do
            local becoming=type(choice)=="table" and choice.become_target~=nil
            local target=becoming and choice.become_target or choice
            local denied=becoming and become_bans or bans
            if (becoming or (not protect and not bans[source])) and not denied[target]
                and not (type(target)=="table" and denied["@text"])
                and not (becoming and target=="@all" and become_bans["@all"]) then
                if target=="@all" then
                    if not virtual and entity.class~="text" then retain=true end
                    for _,name in ipairs(RW_NounPalette(world)) do
                        if name~=source and not denied[name] then
                            local exists=false
                            for _,other in pairs(world.entities) do
                                if other.x==entity.x and other.y==entity.y and other.class~="text" and other.archetype==name then exists=true end
                            end
                            if not exists then products[#products+1]=name end
                        end
                    end
                    if becoming and not virtual then converted_ids[entity.id]=true end
                elseif target=="@empty" then remove=true
                else
                    products[#products+1]=target
                    if becoming and not virtual then converted_ids[entity.id]=true end
                end
            end
        end
        local used=false
        for _,target in ipairs(products) do
            local product=query_clone(entity)
            product.traits,product.behaviors,product.symbol=nil,nil,nil
            if target == "@text" or type(target) == "table" then
                product.class,product.archetype,product.text="text",nil,
                    {name=type(target) == "table" and target.text_name or (virtual and "EMPTY" or RW_NounTextName(world,entity))}
            else product.class,product.archetype,product.text="object",target,nil end
            if not virtual and not retain and not used then
                if entity.class == "text" and product.class == "text" and entity.text.name == product.text.name then
                    -- WRITE may target this very Text; retain its first identity product.
                elseif entity.class == "text" or target == "@text" or type(target) == "table" then
                    changes[#changes+1]={kind="retype",entity_id=entity.id,from=query_clone(entity),to=product}
                elseif entity.archetype~=target then
                    changes[#changes+1]={kind="transform",entity_id=entity.id,from=entity.archetype,to=target}
                end
                used=true
            else local ok,err=create(product); if not ok then return nil,err end end
        end
        if not virtual and not retain and not used and remove then
            changes[#changes+1]={kind="delete",entity_id=entity.id,from=query_clone(entity)}
        end
        return true
    end
    for _,id in ipairs(ids) do
        local entity=world.entities[id]
        local source=entity.class == "text" and "@text" or entity.archetype
        if source then local ok,err=convert(entity,source,false); if not ok then return nil,err end end
    end
    -- All EMPTY products read one frozen occupancy snapshot: no within-phase cascade.
    if targets["@empty"] or conditional["@empty"] then
        for y=1,world.height do for x=1,world.width do
            if not occupied[x .. ":" .. y] then
                local ok,err=convert({kind="object",class="object",x=x,y=y,direction="None"},"@empty",true)
                if not ok then return nil,err end
            end
        end end
    end
    return changes,nil,created > 0 and {from=world.next_entity_id,to=next_id} or nil,converted_ids
end

-- The authored vocabulary is the palette, not the objects remaining this frame.
-- ALL and ordinary NOT exclude the special nouns TEXT, EMPTY and LEVEL.
function RW_NounPalette(world)
    local set={}
    for _,value in pairs((world.language or {}).nouns or {}) do
        if type(value) == "string" then set[value]=true
        elseif type(value) == "table" and value.tag == "object" then set[value.name]=true end
    end
    local result={}; for name in pairs(set) do result[#result+1]=name end
    table.sort(result); return result
end
local function unwrap(term)
    local negative=false
    for _=1,256 do
        if type(term) ~= "table" then return nil end
        if term.tag ~= "not" then return term,negative end
        negative=not negative; term=term.operand
    end
    return nil
end
local function noun_term(name) return {tag="noun",type={tag="object",name=name}} end
local function written_token(world,term)
    if term.tag == "literal" then return term.token end
    local vocabulary=term.tag == "property" and world.language.properties
        or term.tag == "special" and world.language.specials or world.language.nouns
    local matches={}
    for token,value in pairs(vocabulary or {}) do
        if (type(value) == "string" and value == (term.name or (term.type and term.type.name)))
            or (type(value) == "table" and term.type and value.tag == term.type.tag and value.block_type == term.type.block_type and value.name == term.type.name) then
            matches[#matches+1]=token
        end
    end
    table.sort(matches)
    return matches[1]
end
local function subject_key(term)
    if term.tag == "noun" and term.type and term.type.tag == "object" then return term.type.name end
    if term.tag == "special" and (term.name == "text" or term.name == "empty") then return "@" .. term.name end
end
function RW_LowerRuleAST(ast_rules, registry, world)
    if not world then return lower_simple(ast_rules,registry) end
    registry=registry or DEFAULT_SEMANTICS
    if not valid_semantics(registry) or not dense_list(ast_rules) then return nil,"invalid_ast_rules" end
    local generated,deferred,relations={},{},{}
    local contain_bans,contain_origins,contain_verbs={},{},{}
    local write_bans,write_origins,write_verbs={},{},{}
    local predicate_bans={}
    local function add_ban(store,verb,key,target,condition)
        store[verb]=store[verb] or {};local bans=store[verb]
        bans[key]=bans[key] or {};bans[key][target]=bans[key][target] or {}
        bans[key][target][#bans[key][target]+1]=query_clone(condition)
    end
    local function append(list,items) for _,item in ipairs(items) do list[#list+1]=item end end
    for _,ast in ipairs(ast_rules) do
        if type(ast) ~= "table" or type(ast.when) ~= "table" then return nil,"invalid_ast_rule" end
        local subj,subnot=unwrap(ast.subject)
        local obj,objnot=unwrap(ast.object)
        if not subj or not obj then return nil,"invalid_ast_term" end
        local subjects={}
        if (subj.tag == "special" and subj.name == "all") or subnot then
            if subj.tag == "special" and subj.name == "all" and subnot then
                subjects={{tag="special",name="text"},{tag="special",name="empty"}}
            elseif subj.tag == "noun" or (subj.tag == "special" and
                (subj.name == "all" or subj.name == "text" or subj.name == "empty")) then
                for _,name in ipairs(RW_NounPalette(world)) do
                    if not (subnot and subj.tag == "noun" and subj.type and subj.type.name == name) then
                        subjects[#subjects+1]=noun_term(name)
                    end
                end
            end
        else subjects={subj} end
        local sem=registry[ast.verb]
        local supported=false
        local generated_start,relations_start=#generated+1,#relations+1
        local contextual=ast.when.op == "spatial"
        for _,subject in ipairs(subjects) do
            local rule=query_clone(ast); rule.subject=subject; rule.object=objnot and {tag="not",operand=obj} or obj
            local key=subject_key(subject)
            local special=key == "@text" or key == "@empty"
            local has_start=#relations+1
            if sem and key and key~="@empty" and (ast.when.op=="always" or ast.when.op=="spatial") and (sem.noun=="fear" or sem.noun=="follow" or sem.noun=="make" or sem.noun=="eat")
                and (not objnot or sem.negative_noun=="forbid_"..sem.noun) then
                local target=subject_key(obj)
                if obj.tag=="noun" and obj.type and obj.type.tag=="level" then target=obj.type.block_type or "level_block" end
                if obj.tag=="special" and obj.name=="all" then target="@all" end
                if target then
                    supported=true
                    if objnot then add_ban(predicate_bans,ast.verb,key,target,ast.when)
                    else
                        local targets=target=="@all" and RW_NounPalette(world) or {target}
                        for _,name in ipairs(targets) do
                            relations[#relations+1]={op=sem.noun,source_type=key,target_type=name,
                                origin=target,verb=ast.verb,source=ast.source,when=query_clone(ast.when)}
                            if sem.noun=="make" and subj.tag=="special" and subj.name=="all" and not subnot
                                and obj.tag=="special" and obj.name=="all" then
                                relations[#relations+1]=query_clone(relations[#relations])
                            end
                        end
                    end
                end
            elseif sem and key and (ast.when.op == "always" or ast.when.op == "spatial") and sem.noun == "write_text"
                and (not objnot or sem.negative_noun == "forbid_write") then
                local token=written_token(world,obj)
                if token then
                    if objnot then
                        add_ban(write_bans,ast.verb,key,token,ast.when)
                    else
                        local products={token}
                        if obj.tag == "special" and obj.name == "all" then
                            products={}
                            for _,name in ipairs(RW_NounPalette(world)) do products[#products+1]=written_token(world,noun_term(name)) end
                        end
                        for _,name in ipairs(products) do
                            relations[#relations+1]={op="write_text",source_type=key,target_text=name,source=ast.source}
                            write_origins[#relations]=token;write_verbs[#relations]=ast.verb
                            if subj.tag == "special" and subj.name == "all" and not subnot
                                and obj.tag == "special" and obj.name == "all" then
                                relations[#relations+1]=query_clone(relations[#relations])
                                write_origins[#relations]=token;write_verbs[#relations]=ast.verb
                            end
                        end
                    end
                    supported=true
                end
            elseif sem and key and (ast.when.op == "always" or ast.when.op == "spatial") and sem.noun == "contain"
                and objnot and sem.negative_noun == "forbid_contain" then
                local target=subject_key(obj)
                if obj.tag == "special" and obj.name == "all" then target="@all" end
                if obj.tag == "noun" and obj.type and obj.type.tag == "level" then target=obj.type.block_type or "level_block" end
                if target and key ~= "@empty" then
                    add_ban(contain_bans,ast.verb,key,target,ast.when)
                    supported=true
                end
            elseif sem and key and obj.tag == "property" and sem.property == "grant_trait"
                and (not objnot or sem.negative_property == "deny_trait") then
                generated[#generated+1]={when=ast.when,source=ast.source,effects={{
                    op=objnot and "deny_trait" or "grant_trait",trait=obj.name,
                    target=special and (key == "@text" and {kind="class",value="text"} or {kind="empty",value="empty"})
                        or {kind="archetype",value=key}}}}
                supported=true
            elseif sem and key and (ast.when.op == "always" or ast.when.op == "spatial") and sem.noun == "contain" and not objnot
                and obj.tag == "special" and (obj.name == "all" or obj.name == "empty") then
                if obj.name == "all" and key ~= "@empty" then
                    for _,name in ipairs(RW_NounPalette(world)) do
                        relations[#relations+1]={op="has",source=ast.source,
                            target=key == "@text" and {kind="class",value="text"} or {kind="archetype",value=key},
                            product={kind="object",archetype=name}}
                    end
                end
                supported=key ~= "@empty"
            elseif sem and key and (ast.when.op=="always" or ast.when.op=="spatial") and sem.noun=="become" then
                local target=subject_key(obj)
                if obj.tag=="noun" and obj.type and obj.type.tag=="level" then target=obj.type.block_type or "level_block" end
                if obj.tag=="special" and obj.name=="all" then target="@all" end
                if target and (not objnot or sem.negative_noun=="forbid_become") then
                    relations[#relations+1]={op=objnot and "forbid_become" or "become",source_type=key,
                        target_type=target,source=ast.source,when=query_clone(ast.when)}
                    supported=true
                end
            elseif sem and key and (ast.when.op == "always" or ast.when.op == "spatial") and sem.noun == "transform" then
                local target=subject_key(obj)
                if obj.tag == "noun" and obj.type and obj.type.tag == "level" then target=obj.type.block_type or "level_block" end
                if obj.tag == "special" and obj.name == "all" then target="@all" end
                if target and (not objnot or sem.negative_noun == "forbid_transform") then
                    local op
                    if objnot then op="forbid_transform"
                    elseif target == key then op="protect_transform"
                    elseif target == "@text" then op="transform_text"
                    elseif target == "@all" then op="transform_all"
                    else op="transform" end
                    relations[#relations+1]={op=op,source_type=key,target_type=target,source=ast.source}
                    supported=true
                else
                    if contextual then rule.when={op="always"} end
                    local g,d,r=lower_simple({rule},registry)
                    if not g then return nil,d end
                    append(generated,g);append(relations,r);supported=supported or #d == 0
                end
            elseif sem and key == "@empty" and sem.noun == "contain" then
                -- Empty destruction/HAS needs cell-local lifecycle state, not IDs.
                supported=false
            elseif contextual and subject.tag == "noun" and subject.type and subject.type.tag == "level" then
                supported=false -- Scoped LEVEL surroundings require the campaign context.
            else
                if contextual then rule.when={op="always"} end
                local g,d,r=lower_simple({rule},registry)
                if not g then return nil,d end
                append(generated,g);append(relations,r);supported=supported or #d == 0
            end
            -- Original subrules reaches ALL HAS ALL through both expansion axes.
            local has_end=#relations
            for index=has_start,has_end do
                if relations[index].op == "has" then
                    contain_verbs[index]=ast.verb
                    contain_origins[index]=obj.tag == "special" and obj.name == "all" and "@all" or false
                    if subj.tag == "special" and subj.name == "all" and not subnot
                        and obj.tag == "special" and obj.name == "all" and not objnot then
                        relations[#relations+1]=query_clone(relations[index]);contain_origins[#relations]="@all";contain_verbs[#relations]=ast.verb
                    end
                end
            end
        end
        if contextual then
            for index=generated_start,#generated do generated[index].when=query_clone(ast.when) end
            for index=relations_start,#relations do relations[index].when=query_clone(ast.when) end
        end
        if not supported and #subjects > 0 then deferred[#deferred+1]=ast end
    end
    local filtered={}
    for index,relation in ipairs(relations) do
        local blocked=false
        if relation.op == "has" then
            local key=relation.target.kind == "class" and "@text" or relation.target.value
            local bans=(contain_bans[contain_verbs[index]] or {})[key] or {}
            local product=relation.product.kind == "text" and "@text" or relation.product.archetype
            relation.exclusions={}
            for _,condition in ipairs(bans[product] or {}) do relation.exclusions[#relation.exclusions+1]=condition end
            if contain_origins[index] == "@all" then
                for _,condition in ipairs(bans["@all"] or {}) do relation.exclusions[#relation.exclusions+1]=condition end
            end
        end
        if relation.op == "write_text" then
            local bans=(write_bans[write_verbs[index]] or {})[relation.source_type] or {}
            relation.exclusions={}
            for _,condition in ipairs(bans[relation.target_text] or {}) do relation.exclusions[#relation.exclusions+1]=condition end
            if write_origins[index] ~= relation.target_text then
                for _,condition in ipairs(bans[write_origins[index]] or {}) do relation.exclusions[#relation.exclusions+1]=condition end
            end
        end
        if relation.op=="fear" or relation.op=="follow" or relation.op=="make" or relation.op=="eat" then
            local bans=(predicate_bans[relation.verb] or {})[relation.source_type] or {}
            relation.exclusions={}
            for _,condition in ipairs(bans[relation.target_type] or {}) do relation.exclusions[#relation.exclusions+1]=condition end
            if relation.origin=="@all" then
                for _,condition in ipairs(bans["@all"] or {}) do relation.exclusions[#relation.exclusions+1]=condition end
            end
        end
        if relation.exclusions then
            for _,condition in ipairs(relation.exclusions) do if condition.op == "always" then blocked=true end end
            if #relation.exclusions == 0 then relation.exclusions=nil end
        end
        if not blocked then filtered[#filtered+1]=relation end
    end
    return generated,deferred,filtered
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
            local enabled,err=RW_RelationApplies(world,relation,entity)
            if enabled == nil then return nil,err end
            if matches(entity,relation.target,world) and enabled then
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

-- Resolve predicates per source identity using the current phase positions.
-- Keep duplicate physical declarations; FEAR strength counts target parameters.
function RW_ResolveVerbTargets(world,relations,verb)
    local groups={}
    for _,relation in ipairs(relations or {}) do
        if relation.op==verb then
            local selector=relation.source_type=="@text" and {kind="class",value="text"}
                or {kind="archetype",value=relation.source_type}
            for _,id in ipairs(RW_SelectEntities(world,selector)) do
                if RW_RelationApplies(world,relation,world.entities[id]) then
                    groups[id]=groups[id] or {};groups[id][#groups[id]+1]=relation.target_type
                end
            end
        end
    end
    return groups
end

function RW_ResolveFearTargets(world,relations) return RW_ResolveVerbTargets(world,relations,"fear") end

-- Original block() MAKE: inspect existing non-converted occupants only. Products
-- of this same MAKE phase do not inhibit later duplicate declarations.
function RW_PlanMakeProducts(world,relations,converted)
    local products={}
    local state=world.random_state or 1
    local original_state=state
    local directions={"Right","Up","Left","Down"}
    local function random_direction()
        state=(state*48271)%2147483647
        return directions[state%4+1]
    end
    for _,relation in ipairs(relations or {}) do
        if relation.op=="make" then
            local selector=relation.source_type=="@text" and {kind="class",value="text"}
                or {kind="archetype",value=relation.source_type}
            for _,id in ipairs(RW_SelectEntities(world,selector)) do
                local source=world.entities[id]
                if RW_RelationApplies(world,relation,source) then
                    local direction=source.direction
                    if direction=="None" or direction=="Mid" then direction=random_direction() end
                    local target=relation.target_type
                    local blocked=false
                    for other_id,other in pairs(world.entities) do
                        if not (converted and converted[other_id]) and other.x==source.x and other.y==source.y then
                            if (target=="@text" and other.class=="text")
                                or (target~="@text" and other.class~="text" and other.archetype==target) then blocked=true;break end
                        end
                    end
                    if not blocked and target~="@empty" and not (target=="@text" and source.class=="text") then
                        local product={kind="object",class=target=="@text" and "text" or "object",
                            x=source.x,y=source.y,direction=direction,level_link=query_clone(source.level_link)}
                        if target=="@text" then product.text={name=RW_NounTextName(world,source)}
                        else product.archetype=target end
                        products[#products+1]=product
                    end
                end
            end
        end
    end
    return products,state~=original_state and {from=original_state,to=state} or nil
end
