
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
    power={power=true}, power2={power2=true}, power3={power3=true}, hide={hide=true},
    fall={fall=true}, fallright={fallright=true}, fallup={fallup=true}, fallleft={fallleft=true},
    reverse={reverse=true}, pull={pull=true}, swap={swap=true}, phantom={phantom=true},
    sleep={sleep=true}, still={still=true}, lockedright={lockedright=true}, lockedup={lockedup=true}, lockedleft={lockedleft=true}, lockeddown={lockeddown=true}, move={move=true}, right={right=true}, up={up=true}, left={left=true}, down={down=true}, turn={turn=true}, deturn={deturn=true}, nudgeright={nudgeright=true}, nudgeup={nudgeup=true}, nudgeleft={nudgeleft=true}, nudgedown={nudgedown=true},
    you = {control = true}, select = {select = true}, path = {select_path = true},
    boom = {boom = true}, tele = {tele = true}, more = {more = true}, shift = {shift = true}, float = {float = true}, weak = {weak = true}, open = {open = true}, shut = {shut = true}, hot = {hot = true}, melt = {melt = true}, safe = {safe = true}, crash = {crash = true}, win = {win = true}, defeat = {defeat = true}, sink = {sink = true}, word = {word = true}, pushable = {push = true}, block_entry = {block_entry = true}
}
-- Private fixed vocabulary: custom trait aliases may only map implemented capabilities.
local CAPABILITIES={}
for _,spec in pairs(BEHAVIORS) do for capability in pairs(spec) do CAPABILITIES[capability]=true end end
local function valid_behaviors(registry)
    if type(registry) ~= "table" then return false end
    for name, spec in pairs(registry) do
        if type(name) ~= "string" or name == "" or type(spec) ~= "table" then return false end
        local count = 0
        for capability, enabled in pairs(spec) do
            if not CAPABILITIES[capability] or type(enabled) ~= "boolean" then return false end
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
        if type(effect) ~= "table" or (effect.op ~= "grant_trait" and effect.op ~= "deny_trait")
            or type(effect.trait) ~= "string" or effect.trait == "" then
            return nil, "invalid_effect"
        end
        if not dense_list(effect.entity_ids) then return nil, "unresolved_effect" end
        if effect.cells ~= nil then
            if type(world.width) ~= "number" or type(world.height) ~= "number" then return nil,"invalid_empty_grid" end
            if not dense_list(effect.cells) or #effect.entity_ids > 0 then return nil,"invalid_empty_effect" end
            local seen_cells={}
            for _,cell in ipairs(effect.cells) do
                if type(cell) ~= "table" or type(cell.x) ~= "number" or type(cell.y) ~= "number"
                    or cell.x % 1 ~= 0 or cell.y % 1 ~= 0 or cell.x < 1 or cell.y < 1
                    or cell.x > world.width or cell.y > world.height or seen_cells[cell.x .. ":" .. cell.y] then return nil,"invalid_empty_cell" end
                for _,entity in pairs(world.entities) do
                    if entity.x == cell.x and entity.y == cell.y then return nil,"occupied_empty_cell" end
                end
                seen_cells[cell.x .. ":" .. cell.y]=true
            end
        end
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
    projected.empty_cells={}
    projected.trait_counts={}
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
    local denied,empty_denied={},{}
    for _,effect in ipairs(effects) do
        if effect.op == "deny_trait" then
            for _,id in ipairs(effect.entity_ids) do denied[id]=denied[id] or {}; denied[id][effect.trait]=true end
            for _,cell in ipairs(effect.cells or {}) do
                local key=cell.x .. ":" .. cell.y; empty_denied[key]=empty_denied[key] or {}; empty_denied[key][effect.trait]=true
            end
        end
    end
    for _, effect in ipairs(effects) do
        if effect.op == "grant_trait" then
            local behavior = registry[effect.trait] or {}
            for _,cell in ipairs(effect.cells or {}) do
                local key=cell.x .. ":" .. cell.y
                if not (empty_denied[key] and empty_denied[key][effect.trait]) then
                    local empty=projected.empty_cells[key] or {x=cell.x,y=cell.y,traits={},behaviors={}}
                    empty.traits[effect.trait]=true
                    for capability,enabled in pairs(behavior) do if enabled then empty.behaviors[capability]=true end end
                    projected.empty_cells[key]=empty
                end
            end
            for _, id in ipairs(effect.entity_ids) do
                if not (denied[id] and denied[id][effect.trait]) then
                    local entity = projected.entities[id]
                    entity.traits = entity.traits or {}
                    entity.traits[effect.trait] = true
                    projected.trait_counts[id]=projected.trait_counts[id] or {}
                    local counts=projected.trait_counts[id]
                    counts[effect.trait]=(counts[effect.trait] or 0)+1
                    for capability, enabled in pairs(behavior) do
                        if enabled then entity.behaviors[capability] = true end
                    end
                end
            end
        end
    end
    projected.empty_behaviors={}
    local globally_denied={}
    for _,effect in ipairs(effects) do
        if not effect.when and effect.target and effect.target.kind == "empty" and effect.op == "deny_trait" then globally_denied[effect.trait]=true end
    end
    for _,effect in ipairs(effects) do
        if not effect.when and effect.target and effect.target.kind == "empty" and effect.op == "grant_trait" and not globally_denied[effect.trait] then
            for capability,enabled in pairs(registry[effect.trait] or {}) do
                if enabled then projected.empty_behaviors[capability]=true end
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
    for _,cell in pairs(world.empty_cells or {}) do
        if cell.behaviors.control then has_you=true end
    end
    for _, trait in ipairs(traits) do
        local capabilities = registry[trait] or {}
        if capabilities.win and has_you then return "win" end
        if capabilities.defeat and not (world.level_behaviors and world.level_behaviors.safe) then return "defeat" end
    end
    return nil
end

-- Ordered contacts on a rule-projected snapshot. Identity is distinct from type.
function RW_ResolveContactVictims(world, kind)
    if type(world) ~= "table" or type(world.entities) ~= "table" then return nil,"invalid_contact_world" end
    if kind ~= "boom" and kind ~= "sink" and kind ~= "melt" and kind ~= "defeat" and kind ~= "unlock" and kind ~= "weak" then return nil,"invalid_contact_kind" end
    local ids, removed = {}, {}
    for id,entity in pairs(world.entities) do
        if type(id) ~= "number" or id % 1 ~= 0 or id < 1
            or type(entity) ~= "table" or entity.id ~= id or type(entity.behaviors) ~= "table" then
            return nil,"unprojected_contact_entity"
        end
        ids[#ids+1]=id
    end
    table.sort(ids)
    local function overlap(a,b)
        return a.x == b.x and a.y == b.y and (a.behaviors.float == true)==(b.behaviors.float == true)
    end
    if kind == "boom" then
        for _,id in ipairs(ids) do
            local source=world.entities[id]
            if source.behaviors.boom then
                local count=((world.trait_counts or {})[id] or {}).boom or 1
                local radius=math.min(count-1,math.max(world.width,world.height))
                for _,other_id in ipairs(ids) do local other=world.entities[other_id]
                    if not other.behaviors.safe and (other_id==id or
                        ((source.behaviors.float==true)==(other.behaviors.float==true)
                        and math.abs(other.x-source.x)<=radius and math.abs(other.y-source.y)<=radius)) then removed[other_id]=true end
                end
            end
        end
    elseif kind == "sink" then
        for _,id in ipairs(ids) do
            local source=world.entities[id]
            if source.behaviors.sink and not removed[id] then
                local sunk=false
                for _,other_id in ipairs(ids) do
                    if other_id ~= id and not removed[other_id] and overlap(source,world.entities[other_id]) then
                        if not world.entities[other_id].behaviors.safe then removed[other_id]=true end
                        if not source.behaviors.safe then sunk=true end
                    end
                end
                if sunk then removed[id]=true end
            end
        end
    elseif kind == "weak" then
        for _,id in ipairs(ids) do
            local actor=world.entities[id]
            if actor.behaviors.weak and not actor.behaviors.safe
                and not (world.weak_new_ids and world.weak_new_ids[id]) then
                for _,other_id in ipairs(ids) do
                    if other_id ~= id and overlap(actor,world.entities[other_id]) then
                        removed[id]=true;break
                    end
                end
            end
        end
    elseif kind == "unlock" then
        for _,id in ipairs(ids) do
            local door=world.entities[id]
            if door.behaviors.shut then
                local matched_types={}
                for _,other_id in ipairs(ids) do
                    local key=world.entities[other_id]
                    local name=key.class == "text" and "text" or key.archetype
                    if key.behaviors.open and overlap(door,key) and not matched_types[name] then
                        matched_types[name]=true
                        if not door.behaviors.safe then removed[id]=true end
                        if other_id ~= id and not key.behaviors.safe then removed[other_id]=true end
                    end
                end
            end
        end
    elseif kind == "melt" then
        -- Simultaneous victim selection: self-HOT is valid, SAFE guards the victim.
        for _,id in ipairs(ids) do
            local actor=world.entities[id]
            if actor.behaviors.melt and not actor.behaviors.safe then
                for _,other_id in ipairs(ids) do
                    if world.entities[other_id].behaviors.hot and overlap(actor,world.entities[other_id]) then
                        removed[id]=true;break
                    end
                end
            end
        end
    else
        for _,id in ipairs(ids) do
            local actor=world.entities[id]
            if actor.behaviors.control and not actor.behaviors.safe then
                for _,other_id in ipairs(ids) do
                    if world.entities[other_id].behaviors.defeat
                        and overlap(actor,world.entities[other_id]) then removed[id]=true; break end
                end
            end
        end
    end
    local victims={}
    for _,id in ipairs(ids) do if removed[id] then victims[#victims+1]=id end end
    return victims
end

-- MORE copies real units once per phase. Newly created copies block later sources
-- but are not themselves added to this phase's source list.
function RW_ResolveMoreProducts(world)
    local ids,occupancy={},{}
    local function name(e) return e.class=="text" and "text_"..e.text.name or e.archetype end
    local function add(e)
        local key=e.x..":"..e.y;occupancy[key]=occupancy[key] or {};table.insert(occupancy[key],e)
    end
    for id,e in pairs(world.entities) do ids[#ids+1]=id;add(e) end
    table.sort(ids)
    local products={}
    for _,id in ipairs(ids) do
        local source=world.entities[id]
        if source.behaviors.more then
            for _,v in ipairs({{1,0},{0,-1},{-1,0},{0,1}}) do
                local x,y=source.x+v[1],source.y+v[2]
                local valid=x>=1 and x<=world.width and y>=1 and y<=world.height
                local occupants=occupancy[x..":"..y] or {}
                for _,other in ipairs(occupants) do
                    if name(other)==name(source) or other.behaviors.block_entry or other.behaviors.push or other.behaviors.pull then valid=false;break end
                end
                if #occupants==0 then
                    local empty=world.empty_cells and world.empty_cells[x..":"..y]
                    if empty and (empty.behaviors.block_entry or empty.behaviors.push or empty.behaviors.pull) then valid=false end
                end
                if valid then
                    local copy={kind=source.kind,class=source.class,archetype=source.archetype,text=clone(source.text),
                        x=x,y=y,direction=source.direction or "None",level_link=clone(source.level_link)}
                    products[#products+1]=copy
                    local obstacle=clone(copy);obstacle.behaviors=source.behaviors;add(obstacle)
                end
            end
        end
    end
    return products
end

-- EAT chooses all victims from one frozen, post-contact snapshot. A source
-- selected as another eater's victim still participates; HAS runs once per ID.
function RW_ResolveEatVictims(world,targets)
    local removed={}
    for id,parameters in pairs(targets or {}) do
        local source=world.entities[id]
        if source then
            for other_id,other in pairs(world.entities) do
                if other_id~=id and other.x==source.x and other.y==source.y
                    and not other.behaviors.safe
                    and (source.behaviors.float==true)==(other.behaviors.float==true) then
                    local name=other.class=="text" and "@text" or other.archetype
                    for _,target in ipairs(parameters) do
                        if name==target then removed[other_id]=true;break end
                    end
                end
            end
        end
    end
    local victims={};for id in pairs(removed) do victims[#victims+1]=id end;table.sort(victims)
    return victims
end
