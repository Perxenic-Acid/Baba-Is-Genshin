
-- properties.lua
-- RuleWorld M6: Effect application

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

-- Registry entries map rule-derived trait names to implemented capabilities.
local BEHAVIORS = {
    you = {control = true}, select = {select = true}, path = {select_path = true},
    win = {win = true}, defeat = {defeat = true}, pushable = {push = true}, block_entry = {block_entry = true}
}
local function valid_behaviors(registry)
    if type(registry) ~= "table" then return false end
    for name, spec in pairs(registry) do
        if type(name) ~= "string" or name == "" or type(spec) ~= "table" then return false end
        local count = 0
        for capability, enabled in pairs(spec) do
            if (capability ~= "control" and capability ~= "push" and capability ~= "block_entry"
                    and capability ~= "select" and capability ~= "select_path" and capability ~= "win"
                    and capability ~= "defeat")
                or type(enabled) ~= "boolean" then return false end
            if enabled then count = count + 1 end
        end
        if count == 0 then return false end
    end
    return true
end
function RW_GetBehaviorRegistry() return clone(BEHAVIORS) end
function RW_RegisterBehavior(registry, name, specification)
    if registry == nil then registry = BEHAVIORS end
    if not valid_behaviors(registry) or type(name) ~= "string" or name == ""
        or type(specification) ~= "table"
        or not valid_behaviors({[name] = specification}) then
        return nil, "invalid_behavior_registration"
    end
    if registry[name] ~= nil then return nil, "duplicate_behavior" end
    local result = clone(registry)
    result[name] = clone(specification)
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

-- Consume concrete effects resolved by rules.RW_ResolveEffects/EvaluateRules.
-- Selection semantics belong to the query module, never to the projector.
function RW_ProjectWorld(world, effects, level_traits)
    if type(world) ~= "table" or type(world.entities) ~= "table" then return nil, "invalid_world" end
    if effects == nil then effects = {} end
    if not dense_list(effects) then return nil, "invalid_effects" end
    local registry = world.behavior_registry
    if registry == nil then registry = BEHAVIORS end
    if not valid_behaviors(registry) then return nil, "invalid_behavior_registry" end
    for id, entity in pairs(world.entities) do
        if type(entity) ~= "table" or entity.id ~= id then return nil, "invalid_entity_identity" end
    end
    for _, effect in ipairs(effects) do
        if type(effect) ~= "table" or effect.op ~= "grant_trait"
            or type(effect.trait) ~= "string" or effect.trait == "" then
            return nil, "invalid_effect"
        end
        if not dense_list(effect.entity_ids) then return nil, "unresolved_effect" end
        local seen = {}
        for _, id in ipairs(effect.entity_ids) do
            if type(id) ~= "number" or id % 1 ~= 0 or id < 1
                or not world.entities[id] or seen[id] then return nil, "invalid_effect_target" end
            seen[id] = true
        end
    end
    level_traits = level_traits or {}
    if not dense_list(level_traits) then return nil,"invalid_level_properties" end
    for _, trait in ipairs(level_traits) do
        if type(trait) ~= "string" or trait == "" then return nil,"invalid_level_property" end
    end
    local projected = clone(world)
    projected.level_traits, projected.level_behaviors = {}, {}
    for _, trait in ipairs(level_traits) do
        projected.level_traits[#projected.level_traits+1] = trait
        for capability, enabled in pairs(registry[trait] or {}) do
            if enabled then projected.level_behaviors[capability] = true end
        end
    end
    for _, entity in pairs(projected.entities) do
        entity.traits = nil
        entity.behaviors = {} -- Explicit empty capabilities disable legacy fallback.
    end
    for _, effect in ipairs(effects) do
        local behavior = registry[effect.trait] or {}
        for _, id in ipairs(effect.entity_ids) do
            local entity = projected.entities[id]
            entity.traits = entity.traits or {}
            entity.traits[effect.trait] = true
            for capability, enabled in pairs(behavior) do
                if enabled then entity.behaviors[capability] = true end
            end
        end
    end
    return projected
end

function RW_PropertiesSelfTest()
    local original = {entities = {
        [1] = {id = 1, kind = "object", class = "object", direction = "Mid"},
        [2] = {id = 2, kind = "object", class = "text", text = {name = "BOX"}}
    }}
    local effects = {{op = "grant_trait", entity_ids = {1, 2}, trait = "pushable"}}
    local projected = RW_ProjectWorld(original, effects)
    if not projected or not projected.entities[1].behaviors.push
        or not projected.entities[2].traits.pushable or original.entities[1].traits
        or original.entities[1].behaviors or projected.entities[1].direction ~= "Mid" then
        return false, "Concrete effect projection/isolation failed"
    end
    local inactive = RW_ProjectWorld(projected, {})
    if inactive.entities[1].traits or inactive.entities[1].behaviors.push then
        return false, "Derived behavior retraction failed"
    end
    local spec = {control = true, push = true}
    local registry = RW_RegisterBehavior({}, "drive", spec)
    spec.control = false
    if not registry or not registry.drive.control or RW_GetBehaviorRegistry().drive ~= nil
        or RW_RegisterBehavior(registry, "drive", registry.drive) ~= nil then
        return false, "Behavior registration isolation/duplicate failed"
    end
    original.behavior_registry = registry
    local custom = RW_ProjectWorld(original, {{op = "grant_trait", entity_ids = {2}, trait = "drive"}})
    if not custom or not custom.entities[2].behaviors.control or not custom.entities[2].behaviors.push then
        return false, "Custom behavior capability mapping failed"
    end
    local bad, err = RW_ProjectWorld(original, {{op = "unknown"}})
    if bad ~= nil or err ~= "invalid_effect" then return false, "Effect validation failed" end
    if RW_ProjectWorld(original, {{op = "grant_trait", trait = "you", target = {kind = "id", value = 1}}}) ~= nil
        or RW_ProjectWorld(original, {{op = "grant_trait", trait = "you", entity_ids = {1, 1}}}) ~= nil then
        return false, "Unresolved/duplicate target accepted"
    end
    return true, "Concrete effects and isolated behavior registration passed"
end

-- Current-level properties are ordered rule-derived properties, not flags on a
-- specially named entity. The first terminal capability settles the outcome.
function RW_ResolveLevelPropertyOutcome(world, traits)
    local registry = world.behavior_registry or BEHAVIORS
    if not valid_behaviors(registry) or not dense_list(traits) then
        return nil, "invalid_level_properties"
    end
    for _, trait in ipairs(traits) do
        if type(trait) ~= "string" or trait == "" then return nil,"invalid_level_property" end
    end
    local has_you = world.level_behaviors and world.level_behaviors.control == true
    for _, entity in pairs(world.entities or {}) do
        if entity.behaviors and entity.behaviors.control then has_you = true end
    end
    for _, trait in ipairs(traits) do
        local capabilities = registry[trait] or {}
        if capabilities.win and has_you then return "win" end
        if capabilities.defeat then return "defeat" end
    end
    return nil
end
