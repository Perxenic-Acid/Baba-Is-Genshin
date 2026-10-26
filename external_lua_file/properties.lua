
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

-- Apply effects to a separate world view.
-- Never modify the authoritative world.
function RW_ProjectWorld(world, effects)
    if type(world) ~= "table"
        or type(world.entities) ~= "table" then
        return nil, "invalid_world"
    end

    effects = effects or {}

    if type(effects) ~= "table" then
        return nil, "invalid_effects"
    end

    -- Validate all effects before applying any.
    for _, effect in ipairs(effects) do
        if type(effect) ~= "table"
            or effect.op ~= "grant_trait"
            or not valid_selector(effect.target)
            or type(effect.trait) ~= "string"
            or effect.trait == "" then
            return nil, "invalid_effect"
        end
    end

    local projected = clone(world)

    for _, effect in ipairs(effects) do
        for id, entity in pairs(projected.entities) do
            if matches(world.entities[id], effect.target) then
                entity.traits = entity.traits or {}
                entity.traits[effect.trait] = true
            end
        end
    end

    return projected
end

function RW_PropertiesSelfTest()
    local original = {
        entities = {
            [1] = {
                id = 1,
                archetype = "crate",
                traits = { block_entry = true }
            },
            [2] = {
                id = 2,
                archetype = "crate"
            },
            [3] = {
                id = 3,
                archetype = "other"
            }
        }
    }

    local effects = {{
        op = "grant_trait",
        target = {
            kind = "archetype",
            value = "crate"
        },
        trait = "pushable"
    }}

    local active = RW_ProjectWorld(
        original, effects
    )

    if not active
        or not active.entities[1].traits.pushable
        or not active.entities[2].traits.pushable
        or active.entities[3].traits then
        return false, "Trait grant failed"
    end

    if not active.entities[1].traits.block_entry then
        return false, "Intrinsic trait lost"
    end

    -- Source world must remain unchanged.
    if original.entities[1].traits.pushable
        or original.entities[2].traits then
        return false, "Projection mutated world"
    end

    -- Empty effect list retracts derived traits.
    local inactive = RW_ProjectWorld(original, {})

    if inactive.entities[1].traits.pushable
        or inactive.entities[2].traits then
        return false, "Effect retraction failed"
    end

    -- Select an individual entity.
    local individual = RW_ProjectWorld(
        original,
        {{
            op = "grant_trait",
            target = { kind = "id", value = 3 },
            trait = "pushable"
        }}
    )

    if not individual.entities[3].traits.pushable
        or individual.entities[2].traits then
        return false, "ID targeting failed"
    end

    -- Invalid effects must not be applied.
    local bad, err = RW_ProjectWorld(
        original,
        {{ op = "unknown" }}
    )

    if bad ~= nil or err ~= "invalid_effect" then
        return false, "Effect validation failed"
    end

    return true, "Effect projection passed"
end
