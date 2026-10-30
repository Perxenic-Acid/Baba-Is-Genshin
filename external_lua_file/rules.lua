
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

local evaluate_condition
local function contains_rule_query(node)
    if type(node)~="table" then return false end
    for _,clause in ipairs(node.clauses or {}) do
        for _,term in ipairs(clause.parameters or {}) do
            local raw=term;while type(raw)=="table" and raw.tag=="not" do raw=raw.operand end
            if type(raw)=="table" and raw.tag=="noun" and raw.type and raw.type.tag=="group" then return true end
        end
    end
    for _,clause in ipairs(node.clauses or {}) do if clause.relation=="seeing" or clause.relation=="feeling" or clause.relation=="powered" or clause.relation=="powered2" or clause.relation=="powered3" then return true end end
    if contains_rule_query(node.condition) then return true end
    for _,term in ipairs(node.terms or {}) do if contains_rule_query(term) then return true end end
    for _,term in ipairs(node.requirements or {}) do if contains_rule_query(term) then return true end end
    return false
end
local function condition_context(world,rules)
    local context={};for k,v in pairs(world) do context[k]=v end
    context._condition_rules=rules;context._condition_guard={};context._condition_depth=0
    return context
end
-- Query this rule frame, never stale entity.behaviors from a previous turn.
local function query_trait(world,entity,trait)
    local guard=world._condition_guard or {}
    local key=tostring(entity.id or (entity.x..":"..entity.y))..":"..trait
    if guard[key] then return false end
    if (world._condition_depth or 0)>=80 then return nil,"word_rule_limit" end
    guard[key]=true
    local context={};for k,v in pairs(world) do context[k]=v end
    context._condition_guard=guard;context._condition_depth=(world._condition_depth or 0)+1
    local granted,denied=false,false
    for _,rules in ipairs({world.rule_sources or {},world._condition_rules or {}}) do
        for _,rule in ipairs(rules) do for _,effect in ipairs(rule.effects or {}) do
            if effect.trait==trait and effect.target and valid_selector(effect.target,world) and ((entity.class=="empty" and effect.target.kind=="empty") or (entity.class~="empty" and matches(entity,effect.target,world))) then
                local enabled,err
                if rule.when and rule.when.op=="spatial" then enabled,err=RW_TestEntityCondition(context,rule.when,entity)
                else enabled,err=evaluate_condition(context,rule.when) end
                if enabled==nil then guard[key]=nil;return nil,err end
                if enabled then
                    if effect.op=="deny_trait" then denied=true else granted=true end
                end
            end
        end end
    end
    guard[key]=nil;return granted and not denied
end
local function condition_matches(world,entity,target)
    if entity.class=="empty" then return target.kind=="empty" end
    return valid_selector(target,world) and matches(entity,target,world)
end
local function query_when(world,condition,entity)
    if condition and condition.op=="spatial" then return RW_TestEntityCondition(world,condition,entity) end
    return evaluate_condition(world,condition)
end
-- FEELING uses declarations, not the previous projected trait set. Its NOT
-- argument seeks another property and consumes condition instances just like positives.
local function feeling_condition(world,parameters,entity,negated,node)
    if (world._condition_depth or 0)>=80 then return nil,"word_rule_limit" end
    local checked={};for condition,value in pairs(world._feeling_checked or {}) do checked[condition]=value end
    checked[node]=true
    local context={};for k,v in pairs(world) do context[k]=v end
    context._feeling_checked=checked;context._condition_depth=(world._condition_depth or 0)+1
    local properties={}
    for _,trait in pairs((world.language or {}).properties or {}) do properties[trait]=true end
    local frames={world.rule_sources or {},world._condition_rules or {}}
    local found=0
    for _,parameter in ipairs(parameters) do
        local wanted=parameter.name:match("^@trait:(.+)$") or parameter.name:match("^@direction:(.+)$")
        if not wanted then return nil,"invalid_feeling_parameter" end
        local matched=false
        for _,rules in ipairs(frames) do
            for _,rule in ipairs(rules) do
                if not matched and not checked[rule.when] then
                    for _,effect in ipairs(rule.effects or {}) do
                        if effect.op=="grant_trait" and condition_matches(world,entity,effect.target)
                            and (not parameter.negative and effect.trait==wanted or parameter.negative and effect.trait~=wanted and properties[effect.trait]) then
                            checked[rule.when]=true
                            local enabled,err=query_when(context,rule.when,entity)
                            if enabled==nil then return nil,err end
                            local denied=false
                            if enabled then
                                for _,deny_rules in ipairs(frames) do for _,deny_rule in ipairs(deny_rules) do
                                    for _,deny in ipairs(deny_rule.effects or {}) do
                                        if deny.op=="deny_trait" and deny.trait==effect.trait and condition_matches(world,entity,deny.target) then
                                            local active,err=query_when(context,deny_rule.when,entity)
                                            if active==nil then return nil,err end
                                            denied=denied or active
                                        end
                                    end
                                end end
                            end
                            if enabled and not denied then matched=true end
                            break -- A condition instance is consumed even when it fails.
                        end
                    end
                end
            end
        end
        if matched then found=found+1 end
    end
    local result=found==#parameters
    return negated and not result or not negated and result
end
local function powered_condition(world,trait,negated)
    local guard=world._condition_guard or {};local key="global:"..trait
    if guard[key] then return negated end
    if (world._condition_depth or 0)>=80 then return nil,"word_rule_limit" end
    guard[key]=true
    local context={};for k,v in pairs(world) do context[k]=v end
    context._condition_guard=guard;context._condition_depth=(world._condition_depth or 0)+1
    local found,empty_source=false,false
    for _,rules in ipairs({world.rule_sources or {},world._condition_rules or {}}) do
        for _,rule in ipairs(rules) do
            if rule.scoped_power and rule.scoped_power[trait] then found=true end
            for _,effect in ipairs(rule.effects or {}) do
                if effect.op=="grant_trait" and effect.trait==trait and effect.target.kind=="empty" then empty_source=true end
            end
        end
    end
    if not found then
        local ids={};for id in pairs(world.entities) do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids) do
            local active,err=query_trait(context,world.entities[id],trait)
            if active==nil then guard[key]=nil;return nil,err end
            if active then found=true;break end
        end
    end
    if not found and empty_source then
        local occupied={};for _,e in pairs(world.entities) do occupied[e.x..":"..e.y]=true end
        for y=1,world.height do for x=1,world.width do if not found and not occupied[x..":"..y] then
            local active,err=query_trait(context,{class="empty",x=x,y=y},trait)
            if active==nil then guard[key]=nil;return nil,err end
            found=active
        end end end
    end
    guard[key]=nil
    return negated and not found or not negated and found
end
-- findgroup() promotes a conditional member's noun when ANY real unit qualifies.
local function group_parameters(world,name,invert)
    local function finish(result)
        if not invert then return result end
        local found={};for _,noun in ipairs(result) do found[noun]=true end
        local complement={}
        for _,noun in ipairs(RW_NounPalette(world)) do if not found[noun] then complement[#complement+1]=noun end end
        for _,noun in pairs((world.language or {}).nouns or {}) do
            if type(noun)=="table" and noun.tag=="level" and not found["@level"] then complement[#complement+1]="@level";break end
        end
        return complement
    end
    -- Original subgroup_ substitutes the previous iteration for every group name.
    if world._group_override then return finish(world._group_override) end
    local guard=world._condition_guard or {};local key="members:"..name
    if guard[key] then return {} end
    if (world._condition_depth or 0)>=80 then return nil,"word_rule_limit" end
    guard[key]=true
    local context={};for k,v in pairs(world) do context[k]=v end
    context._condition_guard=guard;context._condition_depth=(world._condition_depth or 0)+1
    local members,units={},{}
    local ids={};for id in pairs(world.entities) do ids[#ids+1]=id end;table.sort(ids)
    for _,rule in ipairs(world._condition_rules or {}) do
        for _,member in ipairs((rule.group_members or {})[name] or {}) do
            members[#members+1]=member
            if not units[member.name] then
                units[member.name]={}
                for _,id in ipairs(ids) do local e=world.entities[id]
                    if (member.name=="@text" and e.class=="text") or (e.class~="text" and e.archetype==member.name) then
                        units[member.name][#units[member.name]+1]=e
                    end
                end
            end
        end
    end
    local function qualifies(member)
        if member.when.op=="always" then return true end
        for _,e in ipairs(units[member.name]) do
            local active,err=RW_TestEntityCondition(context,member.when,e)
            if active==nil then return nil,err end
            if active then return true end
        end
        return false
    end
    local base,recursive={},false
    for _,member in ipairs(members) do
        if member.recursive and #units[member.name]>0 and member.when.op~="always" then recursive=true
        elseif not member.recursive or member.when.op=="always" then
            local active,err=qualifies(member)
            if active==nil then guard[key]=nil;return nil,err end
            if active then base[#base+1]=member.name end
        end
    end
    if recursive then
        local current={};for _,noun in ipairs(base) do current[#current+1]=noun end
        local signature=table.concat(current,"")
        for iteration=1,10 do
            local next_members={};for _,noun in ipairs(base) do next_members[#next_members+1]=noun end
            context._group_override=current
            for _,member in ipairs(members) do if member.recursive then
                local active,err=qualifies(member)
                if active==nil then guard[key]=nil;return nil,err end
                if active then next_members[#next_members+1]=member.name end
            end end
            local next_signature=table.concat(next_members,"")
            if next_signature==signature then
                -- findgroup appends the converged list to the original base list.
                for _,noun in ipairs(current) do base[#base+1]=noun end
                guard[key]=nil;return finish(base)
            end
            current=next_members;signature=next_signature
        end
        guard[key]=nil;return nil,"word_rule_limit"
    end
    guard[key]=nil;return finish(base)
end
local function seeing_condition(world,parameters,entity,negated)
    local vectors={Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}}
    local v=vectors[entity.direction];local targets={}
    if not v then return negated end
    local x,y=entity.x+v[1],entity.y+v[2]
    while x>=1 and x<=world.width and y>=1 and y<=world.height do
        local ids={};for id,e in pairs(world.entities) do if e.x==x and e.y==y then ids[#ids+1]=id end end;table.sort(ids)
        local visible,solid=false,false
        for _,id in ipairs(ids) do
            local e=world.entities[id];local hidden,err=query_trait(world,e,"hide")
            if hidden==nil then return nil,err end
            if not hidden then
                targets[#targets+1]={id=id,name=e.class=="text" and "@text" or e.archetype};visible=true
                local phantom,err=query_trait(world,e,"phantom");if phantom==nil then return nil,err end
                if not phantom then for _,trait in ipairs({"block_entry","pushable","pull"}) do
                    local blocking,err=query_trait(world,e,trait);if blocking==nil then return nil,err end
                    if blocking then solid=true;break end
                end end
            end
        end
        if not visible then targets[#targets+1]={name="@empty"} end
        if solid then break end
        x,y=x+v[1],y+v[2]
    end
    local used,found={},0
    for _,p in ipairs(parameters) do
        local matched=false
        if p.name=="@level" and not p.negative and not used.level then used.level=true;matched=true
        elseif p.name=="@empty" then
            -- The original positive AND negative EMPTY branches both seek a placeholder;
            -- repeated EMPTY arguments may reuse it.
            for _,target in ipairs(targets) do if target.name=="@empty" then matched=true;break end end
        else
            local expected=p.name=="@level" and "level_block" or p.name
            for _,target in ipairs(targets) do
                if target.id and target.id~=entity.id and not used[target.id] and
                    (not p.negative and target.name==expected or p.negative and target.name~=expected and target.name~="@text") then
                    used[target.id]=true;matched=true;break
                end
            end
        end
        if matched then found=found+1 end
    end
    local result=found==#parameters
    return negated and not result or not negated and result
end
-- Concrete effects are short-lived results for this world, not saved rules.
-- Original WITHOUT counts shortages per parameter, with shared complement witnesses.
local function without_condition(world,parameters,entity,negated)
    local counts,used={},{}
    local function key(p) return (p.negative and "not " or "")..p.name end
    for _,p in ipairs(parameters) do local k=key(p);counts[k]=(counts[k] or 0)+1 end
    if counts["@level"] then counts["@level"]=counts["@level"]-1 end
    local allfound=0
    for _,p in ipairs(parameters) do
        local k=key(p);local threshold=counts[k]
        if p.name=="@level" and not p.negative and threshold==0 then allfound=-99;break end
        local count=0
        if p.name=="@empty" and not p.negative then
            local occupied={};for _,e in pairs(world.entities) do occupied[e.x..":"..e.y]=true end
            for y=1,world.height do for x=1,world.width do if not occupied[x..":"..y] then count=count+1 end end end
            if entity.class=="empty" then threshold=threshold+1 end
        else
            local ids={};for id in pairs(world.entities) do ids[#ids+1]=id end;table.sort(ids)
            for _,id in ipairs(ids) do local e=world.entities[id]
                local name=e.class=="text" and "@text" or e.archetype
                if p.negative then
                    if name~=p.name and e.class~="text" and id~=entity.id and not used[id] then
                        used[id]=true;count=count+1
                        if count>=threshold then break end
                    end
                elseif name==p.name then count=count+1 end
            end
            local own=entity.class=="text" and "@text" or entity.class=="empty" and "@empty" or entity.archetype
            if not p.negative and own==p.name then threshold=threshold+1 end
        end
        if count<threshold then allfound=allfound+1 end
    end
    if negated then return not (allfound>0) end
    return allfound==#parameters
end
-- FACEDBY visits neighbors first, then parameters (unlike forward FACING).
local function facedby_condition(world,parameters,entity,negated)
    local vectors={{1,0},{0,-1},{-1,0},{0,1}}
    local dirs={Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}}
    local used,matched,allfound={},{},0
    for _,offset in ipairs(vectors) do
        local x,y=entity.x+offset[1],entity.y+offset[2]
        local ids={}
        for id,e in pairs(world.entities) do if e.x==x and e.y==y then ids[#ids+1]=id end end
        table.sort(ids)
        for index,p in ipairs(parameters) do
            if not matched[index] then
                if p.name=="@level" and not p.negative and not used.level then
                    used.level=true;matched[index]=true;allfound=allfound+1
                elseif p.name=="@empty" then
                    -- Empty has no derived facing in the current virtual-cell model.
                    -- Its default direction is None, so it cannot watch this source.
                    if p.negative then matched[index]=true;allfound=allfound+1 end
                else
                    for _,id in ipairs(ids) do if id~=entity.id and not used[id] then
                        local e=world.entities[id];local name=e.class=="text" and "@text" or e.archetype
                        local expected=p.name=="@level" and "level_block" or p.name
                        local vector=dirs[e.direction]
                        local watching=vector and e.x+vector[1]==entity.x and e.y+vector[2]==entity.y or false
                        local found=not p.negative and name==expected and watching
                            or p.negative and name~="@text" and (name~=expected or not watching)
                        if found then used[id]=true;matched[index]=true;allfound=allfound+1;break end
                    end end
                end
            end
        end
    end
    local found=allfound==#parameters
    return negated and not found or not negated and found
end
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
    if node.requirements~=nil and not dense_list(node.requirements) then return nil,"invalid_condition_terms" end
    if node.op ~= "spatial" or not dense_list(node.clauses) or (#node.clauses == 0 and (not node.requirements or #node.requirements==0))
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
                    return term.type.tag=="group" and ("@group:"..term.type.name) or term.type.tag == "level" and "@level" or term.type.name,negative
                elseif term.tag == "special" then return "@" .. term.name,negative
                elseif term.tag == "property" and (term.name=="right" or term.name=="up" or term.name=="left" or term.name=="down") then
                    return "@direction:"..term.name,negative
                elseif term.tag=="property" then return "@trait:"..term.name,negative end
                return nil
            end
            negative=not negative;term=term.operand
        end
    end
    local result=true
    for _,condition in ipairs(node.requirements or {}) do
        local enabled,err=RW_TestEntityCondition(world,condition,entity)
        if enabled==nil then return nil,err end
        result=result and enabled
    end
    for _,clause in ipairs(node.clauses) do
        if type(clause) ~= "table" or (clause.relation ~= "on" and clause.relation ~= "near" and clause.relation ~= "nextto"
                and clause.relation ~= "above" and clause.relation ~= "below" and clause.relation ~= "besideleft"
                and clause.relation ~= "besideright" and clause.relation ~= "facing" and clause.relation ~= "without" and clause.relation ~= "facedby" and clause.relation ~= "seeing" and clause.relation ~= "feeling" and clause.relation ~= "powered" and clause.relation ~= "powered2" and clause.relation ~= "powered3" and clause.relation ~= "lonely" and clause.relation ~= "idle" and clause.relation ~= "often" and clause.relation ~= "seldom")
            or type(clause.negated) ~= "boolean" or not dense_list(clause.parameters) or (#clause.parameters == 0 and clause.relation~="powered" and clause.relation~="powered2" and clause.relation~="powered3" and clause.relation~="lonely" and clause.relation~="idle" and clause.relation~="often" and clause.relation~="seldom") then
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
        -- Follow testcond's insertion/removal order, including multiple group tokens.
        local remove,offset={},0
        local count=#parameters
        local hasgroup=false
        for _,parameter in ipairs(parameters) do if parameter.name:sub(1,7)=="@group:" then hasgroup=true;break end end
        for index=1,hasgroup and count or 0 do
            local parameter=parameters[index]
            if parameter.name:sub(1,7)=="@group:" then
                local members,err=group_parameters(world,parameter.name:sub(8),parameter.negative)
                if not members then return nil,err end
                remove[#remove+1]=index
                for _,name in ipairs(members) do
                    if parameter.negative then parameters[#parameters+1]={name=name}
                    else table.insert(parameters,1,{name=name});offset=offset-1 end
                end
                if #members==0 then parameters[#parameters+1]={name="_NONE_"};break end
            else
                -- Original group preprocessing aborts even on an ordinary token.
                parameters[#parameters+1]={name="_NONE_"};break
            end
        end
        for _,index in ipairs(remove) do table.remove(parameters,index-offset);offset=offset+1 end
        if clause.relation=="often" or clause.relation=="seldom" then
            if #parameters~=0 or (clause.chance_key~=nil and type(clause.chance_key)~="string") then return nil,"invalid_chance_clause" end
            local identity=entity.class=="empty" and ("empty:"..entity.x..":"..entity.y) or tostring(entity.id)
            local key=(clause.chance_key or clause.relation)..":"..identity
            local sample=world.chance_seed or 1
            for index=1,#key do sample=(sample*(131+key:byte(index))+key:byte(index))%2147483647 end
            sample=(sample*48271)%2147483647
            local found=clause.relation=="often" and sample%4~=0 or clause.relation=="seldom" and sample%6==0
            result=result and (clause.negated and not found or not clause.negated and found)
        elseif clause.relation=="idle" then
            if #parameters~=0 then return nil,"invalid_prefix_parameters" end
            local found=world.last_input=="wait"
            result=result and (clause.negated and not found or not clause.negated and found)
        elseif clause.relation=="lonely" then
            if #parameters~=0 then return nil,"invalid_prefix_parameters" end
            local found=true
            for id,other in pairs(world.entities) do
                if id~=entity.id and other.x==entity.x and other.y==entity.y then found=false;break end
            end
            result=result and (clause.negated and not found or not clause.negated and found)
        elseif clause.relation=="powered" or clause.relation=="powered2" or clause.relation=="powered3" then
            if #parameters~=0 then return nil,"invalid_prefix_parameters" end
            local found,err=powered_condition(world,clause.relation:gsub("powered","power"),clause.negated)
            if found==nil then return nil,err end
            result=result and found
        elseif clause.relation=="feeling" then
            local found,err=feeling_condition(world,parameters,entity,clause.negated,node)
            if found==nil then return nil,err end
            result=result and found
        elseif clause.relation=="seeing" then
            local found,err=seeing_condition(world,parameters,entity,clause.negated)
            if found==nil then return nil,err end
            result=result and found
        elseif clause.relation=="facedby" then
            result=result and facedby_condition(world,parameters,entity,clause.negated)
        elseif clause.relation=="without" then
            result=result and without_condition(world,parameters,entity,clause.negated)
        else
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
evaluate_condition = function(world, node, stack)
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

    local needs_context=false
    for _,effect in ipairs(active) do if contains_rule_query(effect.when) then needs_context=true;break end end
    return RW_ResolveEffects(needs_context and condition_context(world,generated_rules or {}) or world, active)
end

-- M9.3H: relation semantics are level-selected data, separate from parsing.
local DEFAULT_SEMANTICS = {play={noun="play",negative_noun="forbid_play"},mimic={noun="mimic"},become={noun="become",negative_noun="forbid_become"},eat={noun="eat",negative_noun="forbid_eat"},make={noun="make",negative_noun="forbid_make"},follow={noun="follow",negative_noun="forbid_follow"},fear={noun="fear",negative_noun="forbid_fear"},is = {property = "grant_trait", noun = "transform", negative_property="deny_trait",negative_noun="forbid_transform"}, has = {noun="contain",negative_noun="forbid_contain"}, write={noun="write_text",negative_noun="forbid_write"}}
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
                or (category == "noun" and (operation == "transform" or operation == "contain" or operation == "write_text" or operation == "fear" or operation == "follow" or operation == "make" or operation == "eat" or operation == "become" or operation == "mimic" or operation == "play"))
                or (category == "negative_property" and operation == "deny_trait")
                or (category == "negative_noun" and (operation == "forbid_transform" or operation == "forbid_contain" or operation == "forbid_write" or operation == "forbid_fear" or operation == "forbid_follow" or operation == "forbid_make" or operation == "forbid_eat" or operation == "forbid_become" or operation == "forbid_play"))) then return false end
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
    if relation.condition_rules then world=condition_context(world,relation.condition_rules) end
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
-- Original invertconds toggles each named condition before OR grouping.
-- WITHOUT's NOT form is intentionally not a Boolean complement for AND quotas.
local function invert_mimic_condition(condition)
    if type(condition)=="table" and condition.op=="spatial" and not condition.requirements then
        local terms={}
        for _,clause in ipairs(condition.clauses) do
            local inverse=query_clone(clause);inverse.negated=not inverse.negated
            terms[#terms+1]={op="not",condition={op="spatial",clauses={inverse}}}
        end
        return {op="not",condition={op="all",terms=terms}}
    end
    return {op="not",condition=condition}
end
-- Original subrules copies only untagged, non-MIMIC declarations: one generation.
local function expand_mimic(ast_rules)
    local present=false
    for _,rule in ipairs(ast_rules) do if type(rule)=="table" and rule.verb=="mimic" then present=true;break end end
    if not present then return ast_rules end
    local function key(term)
        if type(term)~="table" then return nil end
        return subject_key(term)
    end
    local result,bans={},{}
    for _,rule in ipairs(ast_rules) do
        if type(rule)~="table" then return nil,"invalid_ast_rule" end
        if rule.verb=="mimic" then
            local target,negative=unwrap(rule.object)
            local source,destination=key(rule.subject),key(target)
            if source and destination and source~="@empty" and destination~="@empty" and negative then
                bans[source]=bans[source] or {};bans[source][destination]=bans[source][destination] or {}
                table.insert(bans[source][destination],rule.when)
            end
        else result[#result+1]=rule end
    end
    local count=0
    for _,rule in ipairs(ast_rules) do if rule.verb=="mimic" then
        local target,negative=unwrap(rule.object)
        local source,destination=key(rule.subject),key(target)
        if not source or not destination or source=="@empty" or destination=="@empty" then
            result[#result+1]=rule -- unsupported forms remain visible as deferred.
        elseif not negative then
            for _,copied in ipairs(ast_rules) do
                if copied.verb~="mimic" and key(copied.subject)==destination then
                    local conditions={copied.when,rule.when}
                    for _,condition in ipairs((bans[source] or {})[destination] or {}) do
                        conditions[#conditions+1]=invert_mimic_condition(condition)
                    end
                    local combined={op="spatial",clauses={},requirements={}}
                    local blocked=false
                    for _,condition in ipairs(conditions) do
                        if type(condition)~="table" then return nil,"invalid_condition" end
                        if condition.op=="not" and condition.condition and condition.condition.op=="always" then blocked=true end
                        if condition.op~="always" then combined.requirements[#combined.requirements+1]=query_clone(condition) end
                    end
                    if not blocked then
                        local copy=query_clone(copied);copy.subject=query_clone(rule.subject)
                        copy.when=#combined.requirements>0 and combined or {op="always"}
                        result[#result+1]=copy;count=count+1
                        if count>250 then return nil,"rule_complexity_limit" end
                    end
                end
            end
        end
    end end
    return result
end
-- Direct GROUP membership expands declarations, never creates Group entities.
local function expand_groups(ast_rules,registry,world)
    local function group(term)
        local raw,negative=unwrap(term)
        if raw and raw.tag=="noun" and raw.type and raw.type.tag=="group" then return raw.type.name,negative end
    end
    local function condition_group(node)
        if type(node)~="table" then return false end
        for _,clause in ipairs(node.clauses or {}) do
            for _,term in ipairs(clause.parameters or {}) do if group(term) then return true end end
        end
        if condition_group(node.condition) then return true end
        for _,term in ipairs(node.terms or {}) do if condition_group(term) then return true end end
        for _,term in ipairs(node.requirements or {}) do if condition_group(term) then return true end end
        return false
    end
    local present=false
    for _,rule in ipairs(ast_rules) do
        if type(rule)~="table" or type(rule.when)~="table" then return nil,"invalid_ast_rule" end
        if group(rule.subject) or group(rule.object) or condition_group(rule.when) then present=true;break end
    end
    if not present then return ast_rules,{} end
    if not registry.is or registry.is.noun~="transform" then
        local ordinary,deferred={},{}
        for _,rule in ipairs(ast_rules) do
            local list=(group(rule.subject) or group(rule.object) or condition_group(rule.when)) and deferred or ordinary
            list[#list+1]=rule
        end
        return ordinary,deferred
    end
    local bans,positive,transfers,negative_transfers={},{},{},{}
    local function member_key(term) return subject_key(term) end
    local function combine(...)
        local requirements={}
        for _,condition in ipairs({...}) do
            if condition and condition.op~="always" then
                if condition.op=="spatial" and #(condition.clauses or {})==0 and condition.requirements then
                    for _,requirement in ipairs(condition.requirements) do requirements[#requirements+1]=query_clone(requirement) end
                else requirements[#requirements+1]=query_clone(condition) end
            end
        end
        return #requirements==0 and {op="always"} or {op="spatial",clauses={},requirements=requirements}
    end
    local function membership(rule)
        local name,negative=group(rule.object)
        local key=member_key(rule.subject)
        return name and rule.verb=="is" and key,name,negative,key
    end
    local membership_count=0
    local function add_member(name,key,term,condition,negative)
        membership_count=membership_count+1
        local entry={name=name,key=key,term=query_clone(term),when=condition}
        if negative then
            bans[name]=bans[name] or {};bans[name][key]=bans[name][key] or {}
            bans[name][key][#bans[name][key]+1]=entry
        else positive[#positive+1]=entry end
    end
    local transfer_rules={}
    for _,rule in ipairs(ast_rules) do
        local is_member,name,negative,key=membership(rule)
        if is_member then add_member(name,key,rule.subject,rule.when,negative)
        else
            local source,source_not=group(rule.subject);local target,target_not=group(rule.object)
            if rule.verb=="is" and source and target and source~=target then
                local list=source_not and negative_transfers or transfers
                list[#list+1]={rule=rule,source=source,target=target,negative=target_not}
                transfer_rules[rule]=true
            end
        end
    end
    -- The negative solver's base is direct positive declarations only: positive
    -- transfer products and exclusions are deliberately absent from this snapshot.
    local negative_base={}
    if #negative_transfers>0 then
        for _,member in ipairs(positive) do
            negative_base[member.name]=negative_base[member.name] or {}
            negative_base[member.name][member.key]=true
        end
    end
    -- Original diffname_used consumes an edge after its first matching pass.
    -- It scans the growing positive list, accumulating earlier member conditions.
    local progress=true
    while progress do
        progress=false
        for _,edge in ipairs(transfers) do if not edge.used then
            local condition=edge.rule.when
            for _,member in ipairs(positive) do if member.name==edge.source then
                edge.used=true;progress=true
                condition=combine(condition,member.when)
                add_member(edge.target,member.key,member.term,condition,edge.negative)
                if membership_count>5000 then return nil,"rule_complexity_limit" end
            end end
        end end
    end
    if #negative_transfers>0 then
        local function keys(map)
            local list={};for key in pairs(map) do list[#list+1]=key end;table.sort(list);return list
        end
        local function signature(map)
            local parts={}
            for _,group in ipairs(keys(map)) do
                parts[#parts+1]=group
                for _,noun in ipairs(keys(map[group])) do parts[#parts+1]=noun end
            end
            return table.concat(parts,"")
        end
        local function copy_base()
            local result={}
            for group,nouns in pairs(negative_base) do
                result[group]={};for noun in pairs(nouns) do result[group][noun]=true end
            end
            return result
        end
        local base_id=signature(negative_base)
        local previous,previous_id=copy_base(),base_id
        local vocabulary=RW_NounPalette(world)
        local converged=false
        for iteration=1,10 do
            local found,derived={},0
            for _,edge in ipairs(negative_transfers) do
                found[edge.target]=found[edge.target] or {}
                for _,noun in ipairs(vocabulary) do if not (previous[edge.source] or {})[noun] then
                    local entries=found[edge.target]
                    entries[noun]=entries[noun] or {};entries[noun][#entries[noun]+1]=edge
                    derived=derived+1
                    if derived+membership_count>5000 then return nil,"rule_complexity_limit" end
                end end
            end
            -- Original repeats base_id and counts even empty destination tables.
            local current_id=base_id..base_id..signature(found)
            if current_id==previous_id then
                for _,group in ipairs(keys(found)) do for _,noun in ipairs(keys(found[group])) do
                    for _,edge in ipairs(found[group][noun]) do
                        add_member(group,noun,noun_term(noun),edge.rule.when,edge.negative)
                    end
                end end
                converged=true;break
            end
            previous=copy_base()
            -- Found destination tables replace their entire base entry, not union.
            for group,nouns in pairs(found) do
                previous[group]={};for noun in pairs(nouns) do previous[group][noun]=true end
            end
            previous_id=current_id
        end
        if not converged then return nil,"word_rule_limit" end
    end
    if membership_count>5000 then return nil,"rule_complexity_limit" end
    local function constant(node)
        if node.op=="always" then return true end
        if node.op=="not" then local v=constant(node.condition);if v~=nil then return not v end;return nil end
        local terms=node.op=="all" and node.terms or (node.op=="spatial" and #(node.clauses or {})==0 and node.requirements)
        if not terms then return nil end
        local known=true
        for _,term in ipairs(terms) do local v=constant(term);if v==false then return false elseif v==nil then known=false end end
        if known then return true end
    end
    local teams={}
    for _,member in ipairs(positive) do
        local name,key=member.name,member.key
        teams[name]=teams[name] or {}
        local condition=member.when
        for _,ban in ipairs((bans[name] or {})[key] or {}) do
            condition=combine(condition,invert_mimic_condition(ban.when))
        end
        if constant(condition)~=false then teams[name][#teams[name]+1]={term=member.term,when=condition,name=key,recursive=condition_group(condition)} end
    end
    local function complement(name,branch)
        local result,seen={},{}
        if branch then
            for _,member in ipairs(teams[name] or {}) do
                seen[member_key(member.term)]=true
                local inverse=invert_mimic_condition(member.when)
                if constant(inverse)~=false then result[#result+1]={term=member.term,when=inverse} end
            end
        end
        for _,noun in ipairs(RW_NounPalette(world)) do
            local condition={op="always"}
            if not branch then
                for _,member in ipairs(teams[name] or {}) do if member_key(member.term)==noun then
                    condition=combine(condition,invert_mimic_condition(member.when))
                end end
            end
            if not seen[noun] and constant(condition)~=false then result[#result+1]={term=noun_term(noun),when=condition} end
        end
        return result
    end
    local expanded,deferred={},{}
    local function emit(rule,subject,object,condition)
        local copy=query_clone(rule);copy.subject=query_clone(subject);copy.object=query_clone(object)
        copy.when=combine(rule.when,condition);expanded[#expanded+1]=copy
        if #expanded>5000 then return nil,"rule_complexity_limit" end
        return true
    end
    for _,rule in ipairs(ast_rules) do
        local is_member=membership(rule)
        local source,source_not=group(rule.subject);local target,target_not=group(rule.object)
        if transfer_rules[rule] then -- Closure already consumed this declaration.
        elseif (condition_group(rule.when) and target and rule.verb=="is" and source~=target and not is_member) or ((source or target) and rule.verb=="mimic")
            or (target and rule.verb=="is" and not source and not is_member)
            or (source and source_not and target and source~=target and rule.verb=="is") then
            deferred[#deferred+1]=rule
        elseif is_member then -- Membership is a declaration, not an IS conversion.
        elseif source and target then
            if source==target and rule.verb=="is" and source_not~=target_not then
                local team=source_not and complement(source,true) or (teams[source] or {})
                for _,member in ipairs(team) do
                    local crash=query_clone(rule);crash.verb="is"
                    local ok,err=emit(crash,member.term,{tag="property",name="crash"},member.when)
                    if not ok then return nil,err end
                end
            elseif not target_not then
                local first=source_not and complement(source,true) or (teams[source] or {})
                local prevents={op="always"}
                if not source_not and rule.verb~="is" then for _,ban in ipairs(ast_rules) do
                    local bs,bn=group(ban.subject);local bt,btn=group(ban.object)
                    if bs==source and not bn and bt==target and btn and ban.verb==rule.verb and not condition_group(ban.when) then
                        prevents=combine(prevents,invert_mimic_condition(ban.when))
                    end
                end end
                for _,a in ipairs(first) do for _,b in ipairs(teams[target] or {}) do
                    local ok,err=emit(rule,a.term,b.term,combine(a.when,b.when,prevents))
                    if not ok then return nil,err end
                end end
            end -- Other group-to-negative-group declarations are bans only.
        elseif source or target then
            local team=source and source_not and complement(source,false) or (teams[source or target] or {})
            for _,member in ipairs(team) do
                local object=target and (target_not and {tag="not",operand=member.term} or member.term) or rule.object
                local ok,err=emit(rule,source and member.term or rule.subject,object,member.when)
                if not ok then return nil,err end
            end
        else
            expanded[#expanded+1]=rule
        end
    end
    return expanded,deferred,teams
end

function RW_LowerRuleAST(ast_rules, registry, world)
    if not world then return lower_simple(ast_rules,registry) end
    registry=registry or DEFAULT_SEMANTICS
    if not valid_semantics(registry) or not dense_list(ast_rules) then return nil,"invalid_ast_rules" end
    if registry.mimic and registry.mimic.noun=="mimic" then
        local expanded,err=expand_mimic(ast_rules);if not expanded then return nil,err end;ast_rules=expanded
    end
    local expanded,group_deferred,group_members=expand_groups(ast_rules,registry,world)
    if not expanded then return nil,group_deferred end
    ast_rules=expanded
    local generated,deferred,relations={},group_deferred,{}
    if group_members then generated[1]={when={op="always"},effects={},group_members=group_members} end
    local contain_bans,contain_origins,contain_verbs={},{},{}
    local write_bans,write_origins,write_verbs={},{},{}
    local predicate_bans={}
    local play_bans={}
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
            if sem and key and sem.noun=="play" and obj.tag=="note" and type(obj.name)=="string"
                and (ast.when.op=="always" or ast.when.op=="spatial") then
                if objnot then add_ban(play_bans,ast.verb,key,obj.name,ast.when)
                else relations[#relations+1]={op="play",source_type=key,note=obj.name,when=query_clone(ast.when),verb=ast.verb} end
                supported=true
            elseif sem and key and key~="@empty" and (ast.when.op=="always" or ast.when.op=="spatial") and (sem.noun=="fear" or sem.noun=="follow" or sem.noun=="make" or sem.noun=="eat")
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
        if relation.op=="play" then
            relation.exclusions={}
            for _,condition in ipairs(((play_bans[relation.verb] or {})[relation.source_type] or {})[relation.note] or {}) do
                relation.exclusions[#relation.exclusions+1]=condition
            end
        end
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
    local scoped_power,denied_power={},{}
    for _,relation in ipairs(filtered) do
        if relation.trait=="power" or relation.trait=="power2" or relation.trait=="power3" then
            if relation.op=="level_trait" then scoped_power[relation.trait]=true
            elseif relation.op=="deny_level_trait" then denied_power[relation.trait]=true end
        end
    end
    for trait in pairs(denied_power) do scoped_power[trait]=nil end
    if next(scoped_power) then generated[#generated+1]={when={op="always"},effects={},scoped_power=scoped_power} end
    for _,relation in ipairs(filtered) do
        local needed=contains_rule_query(relation.when)
        for _,condition in ipairs(relation.exclusions or {}) do needed=needed or contains_rule_query(condition) end
        if needed then relation.condition_rules=generated end
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


-- PLAY emits presentation requests; no host audio is called during planning.
local play_cache
local function play_data_table()
    if play_cache then return play_cache end
    local play_data={freqs={},tunes={baba="beep5",box="drum_kick",rock="drum_snare",key="drum_hat",keke="tune_blop",skull="tune_short2",piano="piano2",guitar="guitar2",sax="sax2",drum="drum_snare",hihat="drum_hat",trumpet="trumpet",frog="frog",fire="burn6",lava="burn5",crystal="clink",gem="clink",shell="clink",vase="clink",mirror="clink",car="honk",water="splash",fish="splash",bubble="splash",crab="splash",bottle="splash",bunny="boing",arm="drum_kick"}}

	local notes = {"c","csharp","d","dsharp","e","f","fsharp","g","gsharp","a","asharp","b"}
	local octaves = 3
	local base = 4
	local step = 2 ^ (1/12)
	local basefreq = 24000 * (step ^ 3)
	local freq = basefreq
	local prev = "b"

	for i,v in ipairs(notes) do
		play_data.freqs[v] = math.floor(freq)

		freq = freq * step
	end

	freq = basefreq

	play_data.freqs["aflat"] = freq / step

	for i,v in ipairs(notes) do
		if (string.sub(v, -5) ~= "sharp") then
			local name = v .. "flat"
			local pair = prev .. "sharp"

			if (string.sub(name, 1, 1) == "c") or (string.sub(name, 1, 1) == "f") then
				pair = prev
			end


			if (play_data.freqs[pair] ~= nil) then
				play_data.freqs[name] = play_data.freqs[pair]
			end

			--MF_alert(name .. " = " .. pair)

			prev = v
		end
	end

	play_data.freqs["bsharp"] = play_data.freqs["c"]
	play_data.freqs["esharp"] = play_data.freqs["f"]

	freq = basefreq

	for j_=1,octaves do
		local j = base + (j_-1)
		freq = (basefreq * 0.5) * 2 ^ j_
		prev = "b"

		for i,v in ipairs(notes) do
			local name = v .. tostring(j)
			play_data.freqs[name] = math.floor(freq * 0.5)

			freq = freq * step
		end

		freq = (basefreq * 0.5) * 2 ^ j_

		local aflat = "aflat" .. tostring(j)
		play_data.freqs[aflat] = freq / step

		for i,v in ipairs(notes) do
			if (string.sub(v, -5) ~= "sharp") then
				local name = v .. "flat" .. tostring(j)
				local pair = prev .. "sharp" .. tostring(j)

				if (string.sub(name, 1, 1) == "c") or (string.sub(name, 1, 1) == "f") then
					pair = prev .. tostring(j)
				end

				if (play_data.freqs[pair] ~= nil) and (play_data.freqs[pair] < 100000) then
					play_data.freqs[name] = play_data.freqs[pair]
				end

				--MF_alert(name .. " = " .. pair)

				prev = v
			end
		end
	end

	play_data.freqs["bsharp4"] = play_data.freqs["c4"]
	play_data.freqs["esharp4"] = play_data.freqs["f4"]
	play_data.freqs["bsharp5"] = play_data.freqs["c5"]
	play_data.freqs["esharp5"] = play_data.freqs["f5"]
	play_data.freqs["esharp6"] = play_data.freqs["f6"]

    play_cache=play_data;return play_data
end
function RW_ResolvePlayEvents(world,relations)
    local events={}
    for _,relation in ipairs(relations or {}) do if relation.op=="play" then
        local ids,positions={},{}
        if relation.source_type=="@empty" then
            local occupied={};for _,e in pairs(world.entities) do occupied[e.x..":"..e.y]=true end
            for y=1,world.height do for x=1,world.width do if not occupied[x..":"..y] then
                local enabled,err=RW_RelationApplies(world,relation,{class="empty",x=x,y=y})
                if enabled==nil then return nil,err end
                if enabled then positions[#positions+1]={x=x,y=y} end
            end end end
        else
            for id,e in pairs(world.entities) do
                if (relation.source_type=="@text" and e.class=="text") or (e.class~="text" and e.archetype==relation.source_type) then
                    local enabled,err=RW_RelationApplies(world,relation,e)
                    if enabled==nil then return nil,err end
                    if enabled then ids[#ids+1]=id end
                end
            end
            table.sort(ids);for _,id in ipairs(ids) do local e=world.entities[id];positions[#positions+1]={x=e.x,y=e.y} end
        end
        if #positions>0 then
            local data=play_data_table();local name=relation.source_type=="@text" and "text" or relation.source_type=="@empty" and "empty" or relation.source_type
            events[#events+1]={kind="play",source_type=relation.source_type,note=relation.note,tune=data.tunes[name] or "beep",
                frequency=data.freqs[relation.note] or 24000,entity_ids=ids,positions=positions,particles=name~="empty"}
        end
    end end
    return events
end
