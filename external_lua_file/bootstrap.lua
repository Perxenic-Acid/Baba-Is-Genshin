-- bootstrap.lua
-- RuleWorld M7: Runtime coordination

local function level_traits_from(conversions)
    local traits,denied={},{}
    for _,command in ipairs(conversions or {}) do
        if command.op == "deny_level_trait" then denied[command.trait]=true end
    end
    for _,command in ipairs(conversions or {}) do
        if command.op == "level_trait" and not denied[command.trait] then traits[#traits+1]=command.trait end
    end
    return traits
end

-- WORD is a grounded least expansion from physical Text on EVERY compilation.
-- No previous frame can keep an object readable after its independent seed breaks.
function RW_CompileWorld(world, services)
    for _,name in ipairs({"read","parse","lower","evaluate","project","words"}) do
        if type(services[name]) ~= "function" then return nil,{stage="compile",reason="missing_" .. name} end
    end
    local tokens={}
    local function signature(map)
        if type(map) ~= "table" then return nil end
        local ids={}
        for id,token in pairs(map) do
            if type(id) ~= "number" or id % 1 ~= 0 or type(token) ~= "string" or token == "" then return nil end
            ids[#ids+1]=id
        end
        table.sort(ids)
        local items={}; for _,id in ipairs(ids) do items[#items+1]=tostring(id) .. ":" .. #map[id] .. ":" .. map[id] end
        return table.concat(items,"|")
    end
    for iteration=1,200 do
        local lines,err=services.read(world,tokens)
        if not lines then return nil,{stage="reader",reason=err} end
        local ast,why=services.parse(lines,world.language)
        if not ast then return nil,{stage="grammar",reason=why} end
        local generated,deferred,relations=services.lower(ast,world.semantics,world)
        if not generated then return nil,{stage="lower",reason=deferred} end
        local effects,rule_error=services.evaluate(world,generated)
        if not effects then return nil,{stage="evaluate",reason=rule_error} end
        local effective,projection_error=services.project(world,effects,level_traits_from(relations))
        if not effective then return nil,{stage="project",reason=projection_error} end
        local next_tokens,word_error=services.words(world,effective)
        if not next_tokens then return nil,{stage="word",reason=word_error} end
        local previous,next_key=signature(tokens),signature(next_tokens)
        if not next_key then return nil,{stage="word",reason="invalid_word_tokens"} end
        if previous == next_key then
            -- Activation describes sentence membership, not whether a rule finds a target.
            local active_text_ids={}
            for _,rule in ipairs(ast) do
                local source=rule.source or {}
                for _,id in ipairs(source.sentence_entity_ids or source.entity_ids or {}) do
                    if world.entities[id] and world.entities[id].class == "text" then active_text_ids[id]=true end
                end
            end
            return {effects=effects,ast=ast,rules=generated,deferred=deferred,relations=relations,
                active_text_ids=active_text_ids,word_tokens=tokens,iterations=iteration}
        end
        -- Stay bounded without recursively calling the parser, even on oscillation.
        tokens=next_tokens
    end
    return nil,{stage="word",reason="word_rule_limit"}
end

-- Contact destruction and HAS share one flat phase: births use the pre-delete
-- snapshot, and IDs are allocated only in the returned plan.
function RW_PlanDestructionPhase(world, ids, contents, kind, services, deaths)
    local specifications,err
    if deaths then
        specifications={}
        for _,death in ipairs(deaths) do
            if type(death.frame) ~= "table" or not death.frame[death.entity_id] then return nil,"invalid_death_frame" end
            local context={};for key,value in pairs(world) do context[key]=value end
            context.entities={};for id,entity in pairs(death.frame) do context.entities[id]=entity end
            -- Earlier deaths' HAS products already exist for later conditional HAS queries.
            for index,spec in ipairs(specifications) do
                local entity={};for key,value in pairs(spec) do entity[key]=value end
                entity.id=world.next_entity_id+index-1;context.entities[entity.id]=entity
            end
            local born,why=services.births(context,{death.entity_id},contents)
            if not born then return nil,why end
            for _,spec in ipairs(born) do specifications[#specifications+1]=spec end
        end
    else
        specifications,err=services.births(world,ids,contents)
        if not specifications then return nil,err end
    end
    local removal,remove_error=services.delete(world,ids)
    if not removal then return nil,remove_error end
    local creation,create_error=services.create(world,specifications)
    if not creation then return nil,create_error end
    local plan={consumes_turn=true,changes={},id_allocation=creation.id_allocation,events={}}
    for _,change in ipairs(removal.changes) do plan.changes[#plan.changes+1]=change end
    for _,change in ipairs(creation.changes) do plan.changes[#plan.changes+1]=change end
    for index,id in ipairs(ids) do plan.events[#plan.events+1]={kind="destroy",cause=(deaths and deaths[index] and deaths[index].cause) or kind,entity_id=id} end
    return plan
end

function RW_PlanContactPhase(world, effective, kind, contents, services)
    local ids,why=services.victims(effective,kind)
    if not ids then return nil,why end
    return RW_PlanDestructionPhase(world,ids,contents,kind,services)
end

-- M9.3F: host-independent turn planning. Services adapt mapped scripts;
-- no UI calls, logging, session ownership or Commit occur in this function.
-- Services must treat world/context inputs as read-only.
local function lock_compile_failure(plan, reason)
    if reason == "rule_complexity_limit" then plan.too_complex=true;plan.reason="too_complex"
    else plan.infinite_loop=true;plan.reason="infinite_loop" end
end
function RW_PlanTurn(world, action, services)
    local trace = {}
    if type(world) == "table" and world.infinite_loop then return nil,{stage="input",reason="infinite_loop_undo_only"} end
    if type(world) == "table" and world.too_complex then return nil,{stage="input",reason="too_complex_undo_only"} end
    local function fail(stage, reason, phase)
        return nil, {stage = stage, reason = reason or "stage_failed", phase=phase,trace = trace}
    end
    if type(world) ~= "table" or type(world.entities) ~= "table" then
        return fail("input", "invalid_world")
    end
    if type(services) ~= "table" then
        return fail("input", "invalid_services")
    end
    for _, name in ipairs({"evaluate", "project", "resolve", "preview", "convert"}) do
        if type(services[name]) ~= "function" then
            return fail("input", "missing_service_" .. name)
        end
    end

    trace[#trace + 1] = "rules_before"
    local effects, rule_error, before_conversions, before_rules = services.evaluate(world)
    if not effects then return fail("rules_before", rule_error) end

    trace[#trace + 1] = "project"
    local effective, projection_error = services.project(world, effects, level_traits_from(before_conversions))
    if not effective then return fail("project", projection_error) end

    trace[#trace + 1] = "movement"
    local movement, movement_error = services.resolve(effective, action)
    if not movement then return fail("movement", movement_error) end
    if not movement.consumes_turn then
        return movement, nil, trace
    end

    trace[#trace + 1] = "preview_movement"
    local preview, preview_error = services.preview(world, movement)
    if not preview then return fail("preview_movement", preview_error) end

    local movement_prefix=movement
    if #(movement.destructions or {}) > 0 then
        if type(services.destroy) ~= "function" then return fail("movement_destruction","missing_destruction_service") end
        local victims,contents={},{}
        for _,death in ipairs(movement.destructions) do victims[#victims+1]=death.entity_id end
        for _,relation in ipairs(before_conversions or {}) do if relation.op == "has" then contents[#contents+1]=relation end end
        trace[#trace+1]="movement_destruction"
        local destruction,why=services.destroy(preview,victims,contents,"movement",movement.destructions)
        if not destruction then return fail("movement_destruction",why) end
        local after,err=services.preview(preview,destruction)
        if not after then return fail("movement_destruction",err) end
        local move_stage={consumes_turn=true,changes=movement.changes,board_shift=movement.board_shift}
        movement_prefix={consumes_turn=true,reason=movement.reason,changes={},stages={
            {name="movement",plan=move_stage},{name="movement_destruction",plan=destruction}}}
        for _,stage in ipairs(movement_prefix.stages) do
            for _,change in ipairs(stage.plan.changes) do movement_prefix.changes[#movement_prefix.changes+1]=change end
        end
        preview=after
    end
    local automatic_active=false
    for _,effect in ipairs(effects) do
        local trait=effect.trait
        if effect.op=="grant_trait" and (trait=="move" or trait=="nudgeright" or trait=="nudgeup" or trait=="nudgeleft" or trait=="nudgedown") then
            automatic_active=true;break
        end
    end
    local fear_active=false
    for _,relation in ipairs(before_conversions or {}) do if relation.op=="fear" then fear_active=true;break end end
    for _,motion_phase in ipairs({"automatic","fear","shift"}) do
    if services[motion_phase] and (motion_phase~="automatic" or automatic_active) and (motion_phase~="fear" or fear_active) then
        local refreshed,why=services.refresh(preview,before_rules)
        if not refreshed then return fail(motion_phase.."_rules",why) end
        local shifted_world,err=services.project(preview,refreshed,level_traits_from(before_conversions))
        if not shifted_world then return fail(motion_phase.."_project",err) end
        local shift,shift_error=services[motion_phase](shifted_world,before_conversions)
        if not shift then return fail(motion_phase,shift_error) end
        local stages=movement_prefix.stages or {{name="movement",plan={consumes_turn=true,
            changes=movement.changes,board_shift=movement.board_shift}}}
        stages[#stages+1]={name=motion_phase,plan={consumes_turn=true,changes=shift.changes}}
        local after,problem=services.preview(preview,stages[#stages].plan)
        if not after then return fail("preview_"..motion_phase,problem) end
        if #(shift.destructions or {})>0 then
            local ids,contents={},{}
            for _,death in ipairs(shift.destructions) do ids[#ids+1]=death.entity_id end
            for _,relation in ipairs(before_conversions or {}) do if relation.op=="has" then contents[#contents+1]=relation end end
            if not services.destroy then return fail(motion_phase.."_destruction","missing_destruction_service") end
            local destruction,why=services.destroy(after,ids,contents,motion_phase,shift.destructions)
            if not destruction then return fail(motion_phase.."_destruction",why) end
            local next_world,err=services.preview(after,destruction)
            if not next_world then return fail(motion_phase.."_destruction",err) end
            stages[#stages+1]={name=motion_phase.."_destruction",plan=destruction};after=next_world
        end
        movement_prefix={consumes_turn=true,reason=movement.reason,changes={},stages=stages}
        for _,stage in ipairs(stages) do for _,change in ipairs(stage.plan.changes) do
            movement_prefix.changes[#movement_prefix.changes+1]=change
        end end
        preview=after
        trace[#trace+1]=motion_phase
    end
    end
    trace[#trace + 1] = "rules_after"
    local post_effects, post_error, conversions = services.evaluate(preview)
    if not post_effects then
        if post_error == "word_rule_limit" or post_error == "word_rule_cycle" or post_error == "rule_complexity_limit" then
            lock_compile_failure(movement_prefix,post_error)
            return movement_prefix,nil,trace
        end
        return fail("rules_after", post_error)
    end

    trace[#trace + 1] = "conversions"
    local entity_conversions, level_targets, protected, level_traits = {}, {}, false, {}
    for _, conversion in ipairs(conversions or {}) do
        if conversion.op == "transform_level" then level_targets[#level_targets+1] = conversion.target_type
        elseif conversion.op == "protect_level" then protected = true
        elseif conversion.op == "level_trait" or conversion.op == "deny_level_trait" then -- Resolved together below.
        elseif conversion.op == "has" or conversion.op=="fear" or conversion.op=="follow" or conversion.op=="make" or conversion.op=="eat" or conversion.op=="play" then -- Consumed by their scheduled phases, not conversion.
        else entity_conversions[#entity_conversions+1] = conversion end
    end
    level_traits=level_traits_from(conversions)
    local target_type
    if not protected then
        if #level_targets == 1 then target_type=level_targets[1]
        elseif #level_targets > 1 then target_type=level_targets end
    end
    local operations, conversion_error, allocation, converted_ids = services.convert(preview, entity_conversions)
    if not operations then return fail("conversions", conversion_error) end

    -- Keep phase-local preconditions: conversion reads the movement snapshot,
    -- while the transaction still has a single Commit/Undo boundary.
    local movement_stage = {consumes_turn=true,changes={},board_shift=movement.board_shift}
    local conversion_stage = {consumes_turn=true,changes={},id_allocation=allocation}
    for _, change in ipairs(movement.changes) do movement_stage.changes[#movement_stage.changes+1]=change end
    for _, change in ipairs(operations) do conversion_stage.changes[#conversion_stage.changes+1]=change end
    local stages=movement_prefix.stages or {{name="movement",plan=movement_stage}}
    stages[#stages+1]={name="conversion",plan=conversion_stage}
    local plan = {consumes_turn=true,reason=movement.reason,changes={},
        level_transform=target_type,level_traits=level_traits,stages=stages}

    for _, stage in ipairs(plan.stages) do
        for _, change in ipairs(stage.plan.changes) do plan.changes[#plan.changes+1]=change end
    end

    -- Validate the WHOLE plan before returning it to the host for one Commit.
    trace[#trace + 1] = "preview_complete"
    local complete, complete_error, phase = services.preview(world, plan)
    if not complete then return fail("preview_complete", complete_error,phase) end
    local more_frame
    if services.more or services.fall or services.follow then
        local effects,why,relations,rules=services.evaluate(complete)
        if not effects then
            if why=="word_rule_limit" or why=="word_rule_cycle" or why=="rule_complexity_limit" then
                lock_compile_failure(plan,why);return plan,nil,trace
            end
            return fail("more_rules",why)
        end
        -- Reuse the post-conversion compile when FOLLOW is absent or unchanged.
        if services.follow then
        local active=false
        for _,relation in ipairs(relations or {}) do if relation.op=="follow" then active=true;break end end
        if active then
            local projected,why=services.project(complete,effects,level_traits_from(relations))
            if not projected then return fail("follow_project",why) end
            local follow,why=services.follow(projected,relations)
            if not follow then return fail("follow",why) end
            local next_world,why=services.preview(complete,follow)
            if not next_world then return fail("follow_preview",why) end
            plan.stages[#plan.stages+1]={name="follow",plan=follow}
            for _,change in ipairs(follow.changes) do plan.changes[#plan.changes+1]=change end
            complete=next_world;trace[#trace+1]="follow"
            if #follow.changes>0 then
                effects,why,relations,rules=services.evaluate(complete)
                if not effects then
                    if why=="word_rule_limit" or why=="word_rule_cycle" or why=="rule_complexity_limit" then
                        lock_compile_failure(plan,why);return plan,nil,trace
                    end
                    return fail("follow_rules",why)
                end
            end
        end
        end
        local has_fall=false
        if services.fall then for _,effect in ipairs(effects) do
            if effect.op=="grant_trait" and #effect.entity_ids>0 and
                (effect.trait=="fall" or effect.trait=="fallright" or effect.trait=="fallup" or effect.trait=="fallleft") then has_fall=true;break end
        end end
        if has_fall then
            local projected,why=services.project(complete,effects,level_traits_from(relations))
            if not projected then return fail("fall_project",why) end
            local fall,why=services.fall(projected)
            if not fall then return fail("fall",why) end
            local fall_stage={consumes_turn=true,changes=fall.changes}
            local after,why=services.preview(complete,fall_stage)
            if not after then return fail("fall",why) end
            plan.stages[#plan.stages+1]={name="fall",plan=fall_stage}
            for _,change in ipairs(fall.changes) do plan.changes[#plan.changes+1]=change end
            if #(fall.destructions or {})>0 then
                local ids,contents={},{}
                for _,death in ipairs(fall.destructions) do ids[#ids+1]=death.entity_id end
                for _,relation in ipairs(relations or {}) do if relation.op=="has" then contents[#contents+1]=relation end end
                if not services.destroy then return fail("fall_destruction","missing_destruction_service") end
                local destruction,why=services.destroy(after,ids,contents,"fall",fall.destructions)
                if not destruction then return fail("fall_destruction",why) end
                local next_world,why=services.preview(after,destruction)
                if not next_world then return fail("fall_destruction",why) end
                plan.stages[#plan.stages+1]={name="fall_destruction",plan=destruction}
                for _,change in ipairs(destruction.changes) do plan.changes[#plan.changes+1]=change end
                after=next_world
            end
            complete=after;trace[#trace+1]="fall"
            if fall.infinite_loop then plan.infinite_loop=true;plan.reason="infinite_loop";return plan,nil,trace end
            effects,why,relations,rules=services.evaluate(complete)
            if not effects then
                if why=="word_rule_limit" or why=="word_rule_cycle" or why=="rule_complexity_limit" then lock_compile_failure(plan,why);return plan,nil,trace end
                return fail("fall_rules",why)
            end
        end
        local has_more=false
        for _,effect in ipairs(effects) do
            if effect.op=="grant_trait" and effect.trait=="more" and #effect.entity_ids>0 then has_more=true;break end
        end
        local more={consumes_turn=true,changes={}}
        if has_more and services.more then
            local projected,err=services.project(complete,effects,level_traits_from(relations))
            if not projected then return fail("more_project",err) end
            local why;more,why=services.more(complete,projected)
            if not more then return fail("more",why) end
        end
        if #more.changes==0 then more_frame={effects=effects,relations=relations,rules=rules} end
        local after,err=services.preview(complete,more)
        if not after then return fail("more",err) end
        plan.stages[#plan.stages+1]={name="more",plan=more}
        for _,change in ipairs(more.changes) do plan.changes[#plan.changes+1]=change end
        complete=after;trace[#trace+1]="more"
    end
    local final_world,final_effects,final_relations
    if services.contact ~= nil or services.refresh ~= nil then
        if type(services.contact) ~= "function" or type(services.refresh) ~= "function" then
            return fail("contacts","invalid_contact_services")
        end
        trace[#trace+1]="contact_rules"
        local frozen_effects,why,frozen_relations,frozen_rules
        if more_frame then frozen_effects=more_frame.effects;frozen_relations=more_frame.relations;frozen_rules=more_frame.rules
        else frozen_effects,why,frozen_relations,frozen_rules=services.evaluate(complete) end
        if not frozen_effects then
            if why == "word_rule_limit" or why == "word_rule_cycle" or why == "rule_complexity_limit" then
                lock_compile_failure(plan,why); return plan,nil,trace
            end
            return fail("contact_rules",why)
        end
        if type(frozen_rules) ~= "table" then return fail("contact_rules","missing_contact_rule_frame") end
        local contents={}
        for _,relation in ipairs(frozen_relations or {}) do
            if relation.op == "has" then contents[#contents+1]=relation end
        end
        plan.level_traits=level_traits_from(frozen_relations)
        plan.contact_frame=frozen_rules -- Freeze declarations, re-evaluate conditions/targets.
        if services.play then
            local active=false
            for _,relation in ipairs(frozen_relations or {}) do if relation.op=="play" then active=true;break end end
            if active then
                local events,why=services.play(complete,frozen_relations)
                if not events then return fail("play",why) end
                plan.events=events;trace[#trace+1]="play"
            end
        end
        local weak_new={}
        for _,stage in ipairs(plan.stages) do
            for _,change in ipairs(stage.plan.changes) do
                if (stage.name == "movement_destruction" or stage.name == "shift_destruction" or stage.name == "automatic_destruction" or stage.name == "fear_destruction" or stage.name == "fall_destruction" or stage.name == "more") and change.kind == "create" then weak_new[change.entity_id]=true
                elseif stage.name == "conversion" then weak_new[change.entity_id]=nil end
            end
        end
        for _,kind in ipairs({"sink","weak","melt","defeat","unlock"}) do
            trace[#trace+1]=kind
            local refreshed,refresh_error=services.refresh(complete,frozen_rules)
            if not refreshed then return fail(kind,refresh_error) end
            local projected,projection_error=services.project(complete,refreshed,plan.level_traits)
            if not projected then return fail(kind,projection_error) end
            if kind == "weak" then projected.weak_new_ids=weak_new end
            local contact,contact_error=services.contact(complete,projected,kind,contents)
            if not contact then return fail(kind,contact_error) end
            local next_world,validation_error=services.preview(complete,contact)
            if not next_world then return fail(kind,validation_error) end
            plan.stages[#plan.stages+1]={name=kind,plan=contact}
            for _,change in ipairs(contact.changes) do plan.changes[#plan.changes+1]=change end
            for _,change in ipairs(contact.changes) do
                if change.kind == "create" then weak_new[change.entity_id]=true end
            end
            complete=next_world
        end
        if services.eat then
            local active=false
            for _,relation in ipairs(frozen_relations or {}) do if relation.op=="eat" then active=true;break end end
            if active then
                local refreshed,why=services.refresh(complete,frozen_rules)
                if not refreshed then return fail("eat_rules",why) end
                local projected,why=services.project(complete,refreshed,plan.level_traits)
                if not projected then return fail("eat_project",why) end
                local eat,why=services.eat(complete,projected,frozen_relations,contents)
                if not eat then return fail("eat",why) end
                local next_world,why=services.preview(complete,eat)
                if not next_world then return fail("eat_preview",why) end
                plan.stages[#plan.stages+1]={name="eat",plan=eat}
                for _,change in ipairs(eat.changes) do plan.changes[#plan.changes+1]=change end
                complete=next_world;trace[#trace+1]="eat"
            end
        end
        -- Late creation reads surviving sources with the frozen contact declarations.
        if services.make then
            local active=false
            for _,relation in ipairs(frozen_relations or {}) do if relation.op=="make" then active=true;break end end
            if active then
                local converted={}
                for id in pairs(converted_ids or {}) do converted[id]=true end
                for _,stage in ipairs(plan.stages) do for _,change in ipairs(stage.plan.changes) do
                    if change.kind=="create" or change.kind=="transform" or change.kind=="retype" then converted[change.entity_id]=true end
                end end
                local creation,why=services.make(complete,frozen_relations,converted)
                if not creation then return fail("make",why) end
                local next_world,why=services.preview(complete,creation)
                if not next_world then return fail("make_preview",why) end
                plan.stages[#plan.stages+1]={name="make",plan=creation}
                for _,change in ipairs(creation.changes) do plan.changes[#plan.changes+1]=change end
                complete=next_world;trace[#trace+1]="make"
            end
        end
        -- CRASH is checked on surviving units after destruction, against the frozen rules.
        local crash_effects,crash_error=services.refresh(complete,frozen_rules)
        if not crash_effects then return fail("crash",crash_error) end
        local crash_world,crash_projection_error=services.project(complete,crash_effects,plan.level_traits)
        if not crash_world then return fail("crash",crash_projection_error) end
        for _,entity in pairs(crash_world.entities) do
            if entity.behaviors.crash then plan.infinite_loop=true;plan.reason="infinite_loop";return plan,nil,trace end
        end
        trace[#trace+1]="preview_contacts"
        local final,why,phase=services.preview(world,plan)
        if not final then return fail("preview_contacts",why,phase) end
        -- Contacts can remove the grounding Text of a WORD rule. Detect a loop
        -- in the final board before Commit/render, without changing frozen contacts.
        local checked,check_error,checked_relations=services.evaluate(final)
        final_world,final_effects,final_relations=final,checked,checked_relations
        if not checked then
            if check_error == "word_rule_limit" or check_error == "word_rule_cycle" or check_error == "rule_complexity_limit" then
                lock_compile_failure(plan,check_error)
            else return fail("rules_final",check_error) end
        end
    else
        for _,relation in ipairs(conversions or {}) do
            if relation.op == "has" then return fail("contacts","missing_contact_services") end
        end
    end
    if services.orient and not plan.infinite_loop and not plan.too_complex then
        local final,why,phase=final_world
        if not final then final,why,phase=services.preview(world,plan) end
        if not final then return fail("orientation_preview",why,phase) end
        local effects,relations=final_effects,final_relations
        if not effects then effects,why,relations=services.evaluate(final) end
        if not effects then
            if why=="word_rule_limit" or why=="word_rule_cycle" or why=="rule_complexity_limit" then
                lock_compile_failure(plan,why);return plan,nil,trace
            end
            return fail("orientation_rules",why)
        end
        local orientation_active=false
        for _,effect in ipairs(effects) do
            local t=effect.trait
            if effect.op=="grant_trait" and #(effect.entity_ids or {})>0 and
                (t=="right" or t=="up" or t=="left" or t=="down" or t=="turn" or t=="deturn") then orientation_active=true;break end
        end
        if orientation_active then
        local projected,why=services.project(final,effects,level_traits_from(relations))
        if not projected then return fail("orientation_project",why) end
        local orientation,why=services.orient(projected)
        if not orientation then return fail("orientation",why) end
        if #orientation.changes>0 then
            plan.stages[#plan.stages+1]={name="orientation",plan=orientation}
            for _,change in ipairs(orientation.changes) do plan.changes[#plan.changes+1]=change end
            local checked,why,phase=services.preview(world,plan)
            if not checked then return fail("orientation_complete",why,phase) end
            local verified,why=services.evaluate(checked)
            if not verified then
                if why=="word_rule_limit" or why=="word_rule_cycle" or why=="rule_complexity_limit" then lock_compile_failure(plan,why)
                else return fail("orientation_final_rules",why) end
            end
        end
        end
    end
    return plan, nil, trace
end

-- Whole-tree transaction planner: navigation, outcomes and movement share one Undo.
function RW_PlanLevelAction(tree, action, services)
    local function fail(reason) return nil, {stage="level_action",reason=reason} end
    if type(action) ~= "table" then return fail("invalid_action") end
    local session = services.active(tree)
    if session.world.infinite_loop then return fail("infinite_loop_undo_only") end
    if session.world.too_complex then return fail("too_complex_undo_only") end
    local effects, err, initial_conversions = services.evaluate(session.world)
    if not effects then return fail(err) end
    local effective, project_error = services.project(session.world,effects,level_traits_from(initial_conversions))
    if not effective then return fail(project_error) end
    local select_after_defeat = session.defeated == true
    if select_after_defeat then
        if #services.selectors(effective) == 0 then return fail("level_defeated_undo_only") end
        local adapted, original_project = {}, services.project
        for key, value in pairs(services) do adapted[key] = value end
        adapted.project = function(world,active_effects,traits)
            local projected, why = original_project(world,active_effects,traits)
            if not projected then return nil,why end
            for _, entity in pairs(projected.entities) do entity.behaviors.control = nil end
            projected.level_behaviors.control = nil
            return projected
        end
        services = adapted
    end
    local function return_to_parent(current)
        local entry = current.entry_links[current.active_id]
        local returned, reason = services.return_level(current)
        if not returned or not entry then return returned,reason end
        local parent = services.active(returned)
        local e, why, commands = services.evaluate(parent.world)
        if not e then return nil,why end
        local projected, projection_error = services.project(parent.world,e,level_traits_from(commands))
        if not projected then return nil,projection_error end
        return services.place_selectors(returned,services.selectors(projected),entry.entity_id)
    end
    if action.type == "confirm" then
        local candidates = services.candidates(effective)
        if #candidates == 0 then return fail("no_selected_level") end
        local entity_id = action.entity_id
        if entity_id ~= nil then
            local found = false
            for _, id in ipairs(candidates) do if id == entity_id then found = true end end
            if not found then return fail("selected_level_changed") end
        elseif #candidates > 1 then
            return nil,{stage="level_action",reason="choose_level",candidates=candidates}
        else entity_id = candidates[1] end
        local link = session.world.entities[entity_id].level_link
        if not link then return fail("unavailable_level") end
        local next_tree, reason
        if link.target == "parent" then next_tree, reason = return_to_parent(tree)
        else
            next_tree, reason = services.enter(tree,tostring(entity_id),link.definition_id)
            if next_tree then next_tree, reason = services.bind_entry(next_tree,entity_id) end
        end
        if not next_tree then return fail(reason) end
        return {before=tree,after=next_tree,reason="confirm_level",changes={},select_after_defeat=select_after_defeat}
    end
    local turn, planning_error = RW_PlanTurn(session.world,action,services)
    if not turn then return nil, planning_error end
    if not turn.consumes_turn then return fail(turn.reason) end
    local completed, accepted = services.commit_session(session,turn)
    if not accepted.accepted then return fail(accepted.reason) end
    local next_tree, update_error = services.update(tree,completed)
    if not next_tree then return fail(update_error) end
    if turn.infinite_loop or turn.too_complex then
        return {before=tree,after=next_tree,reason=turn.too_complex and "too_complex" or "infinite_loop",changes=turn.changes,events=turn.events}
    end
    local post_effects, post_error, post_traits
    if turn.contact_frame then
        post_effects,post_error=services.refresh(completed.world,turn.contact_frame)
        post_traits=turn.level_traits
    else
        local commands
        post_effects,post_error,commands=services.evaluate(completed.world)
        post_traits=level_traits_from(commands)
    end
    if not post_effects then return fail(post_error) end
    local post, projection_error = services.project(completed.world,post_effects,post_traits)
    if not post then return fail(projection_error) end
    local level_outcome, outcome_error = services.level_outcome(post,turn.level_traits)
    if outcome_error then return fail(outcome_error) end
    local outcome = turn.level_transform and "transform" or level_outcome
        or (services.win(post) and "win" or nil)
    if select_after_defeat and outcome == "defeat" then outcome = nil end
    local outcome_diagnostic
    if outcome == "win" then
        local entries={"LEVEL traits=" .. table.concat(turn.level_traits or {},",")}
        local ids={};for id in pairs(post.entities) do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids) do
            local e=post.entities[id];local b=e.behaviors or {}
            if e.class == "text" or b.control or b.win then
                entries[#entries+1]=string.format("%d:%s@%s,%s YOU=%s WIN=%s",id,
                    e.text and e.text.name or e.archetype or "?",tostring(e.x),tostring(e.y),
                    tostring(b.control == true),tostring(b.win == true))
            end
        end
        for key,cell in pairs(post.empty_cells or {}) do
            if cell.behaviors.control and cell.behaviors.win then entries[#entries+1]="EMPTY YOU+WIN@" .. key end
        end
        outcome_diagnostic=table.concat(entries,"; ")
    end
    if outcome then
        next_tree, update_error = services.outcome(next_tree,outcome,turn.level_transform)
        if not next_tree then return fail(update_error) end
        if outcome ~= "defeat" and #next_tree.stack > 0 then
            next_tree,update_error = return_to_parent(next_tree)
            if not next_tree then return fail(update_error) end
        end
    end
    return {before=tree,after=next_tree,reason=outcome or turn.reason,changes=turn.changes,select_after_defeat=select_after_defeat,
        outcome_diagnostic=outcome_diagnostic,events=turn.events}
end

-- Host confirmation entry point, shared with the F interaction binding.
local confirm_selected_level, choose_selected_level = nil, nil
function RW_ConfirmSelectedLevel()
    if not confirm_selected_level then return false, "not_initialized" end
    return confirm_selected_level()
end

function RW_ChooseSelectedLevel(entity_id)
    if not choose_selected_level then return false,"not_initialized" end
    return choose_selected_level(entity_id)
end

local function start(run_self_tests)
    local root = script.object

    if not root then
        printerr("[RuleWorld] Missing GameRoot")
        return
    end

    -- Discover mapped scripts.
    local scripts = {}

    for _, candidate in ipairs(root:GetScripts()) do
        local path =
            (candidate.path or ""):gsub("\\", "/")
        local name = path:match("([^/]+)$")

        scripts[name] = candidate

        print("[RuleWorld] Found script:", path)
    end

    -- All modules required by M7.
    local required = {
        "world",
        "reader",
        "grammar",
        "rules",
        "properties",
        "movement",
        "renderer"
    }

    for _, name in ipairs(required) do
        local api = scripts[name]

        if not api then
            printerr(
                "[RuleWorld] Missing module:", name
            )
            return
        end

        if not api.alive then
            printerr(
                "[RuleWorld] Module not alive:", name
            )
            return
        end
    end

    local world_api = scripts.world
    local reader_api = scripts.reader
    local grammar_api = scripts.grammar
    local rules_api = scripts.rules
    local properties_api = scripts.properties
    local movement_api = scripts.movement
    local renderer_api = scripts.renderer

    if run_self_tests then
    -- Explicit diagnostics only; never execute regression fixtures on normal startup.
    -- Module self-tests.
    local tests = {
        { "world",      "RW_SelfTest" },
        { "reader",     "RW_ReaderSelfTest" },
        { "grammar",    "RW_GrammarSelfTest" },
        { "rules",      "RW_RulesSelfTest" },
        { "properties", "RW_PropertiesSelfTest" },
        { "movement",   "RW_MovementSelfTest" },
        { "renderer",   "RW_RendererSelfTest" },
        { "movement",   "RW_ControlSelfTest" },
        { "grammar",    "RW_GrammarASTSelfTest" },
        { "grammar",    "RW_GrammarRegistrationSelfTest" },
        { "rules",      "RW_SemanticRegistrationSelfTest" },
        { "rules",      "RW_SelectorSelfTest" },
        { "rules",      "RW_ASTLoweringSelfTest" },
        { "world",      "RW_DirectionStateSelfTest" },
        { "world",      "RW_LifecycleSelfTest" },
        { "world",      "RW_StageTransactionSelfTest" },
        { "world",      "RW_LevelInstanceSelfTest" },
        { "world",      "RW_LevelTreeSelfTest" },
        { "movement",   "RW_DirectionMovementSelfTest" },
        { "movement",   "RW_LevelSelectionSelfTest" },
    }

    for _, test in ipairs(tests) do
        local name = test[1]
        local method = test[2]

        local passed, message =
            scripts[name]:Invoke(method)

        if not passed then
            printerr(
                "[RuleWorld] TEST FAILED:",
                name, message
            )
            return
        end

        print(
            "[RuleWorld] TEST PASSED:",
            name, message
        )
    end

    -- M9.3B migration gate: compare old and typed-AST pipelines
    -- on the real fixture, both intact and with a broken word rule.
    local function verify_ast_parity(test_world)
        local lines, read_err =
            reader_api:Invoke("RW_ReadLines", test_world)
        if not lines then return false, read_err end

        local legacy, old_err = grammar_api:Invoke(
            "RW_CompileRules", lines, test_world.language
        )
        if not legacy then return false, old_err end

        local ast, parse_err = grammar_api:Invoke(
            "RW_ParseRuleAST", lines, test_world.language
        )
        if not ast then return false, parse_err end

        local generated, deferred = rules_api:Invoke(
            "RW_LowerRuleAST", ast
        )
        if not generated then return false, deferred end

        if #deferred ~= 0 or #generated ~= #legacy then
            return false, "rule count/deferred mismatch"
        end

        local old_effects, old_eval_err = rules_api:Invoke(
            "RW_EvaluateRules", test_world, legacy
        )
        if not old_effects then return false, old_eval_err end

        local new_effects, new_eval_err = rules_api:Invoke(
            "RW_EvaluateRules", test_world, generated
        )
        if not new_effects then return false, new_eval_err end

        local function signatures(effects)
            local result = {}
            for _, effect in ipairs(effects) do
                local target = effect.target or {}
                result[#result + 1] = table.concat({
                    tostring(effect.op),
                    tostring(target.kind),
                    tostring(target.value),
                    tostring(effect.trait)
                }, ":")
            end
            table.sort(result)
            return result
        end

        local left = signatures(old_effects)
        local right = signatures(new_effects)

        if #left ~= #right then
            return false, "active effect count mismatch"
        end
        for i = 1, #left do
            if left[i] ~= right[i] then
                return false, "active effect mismatch"
            end
        end

        return true
    end

    local parity_session =
        world_api:Invoke("RW_CreateSession")

    if not parity_session then
        printerr("[RuleWorld] AST parity: no test world")
        return
    end

    local parity_ok, parity_err =
        verify_ast_parity(parity_session.world)

    if not parity_ok then
        printerr("[RuleWorld] AST parity failed:", parity_err)
        return
    end

    -- Break CRATE IS PUSH without changing the live session.
    local test_word = parity_session.world.entities[8]
    test_word.x = parity_session.world.width
    test_word.y = parity_session.world.height

    parity_ok, parity_err =
        verify_ast_parity(parity_session.world)

    if not parity_ok then
        printerr("[RuleWorld] AST broken-rule parity failed:", parity_err)
        return
    end

    -- The authoritative level contains NO intrinsic PUSH
    -- traits. TEXT IS PUSH is applied only in effective_world,
    -- independently of any spatial CRATE IS PUSH rule.
    local base_world = world_api:Invoke("RW_CreateSession")
    local base_lines = reader_api:Invoke(
        "RW_ReadLines", base_world.world
    )
    local base_ast = grammar_api:Invoke(
        "RW_ParseRuleAST", base_lines, base_world.world.language
    )
    local base_generated = rules_api:Invoke(
        "RW_LowerRuleAST", base_ast
    )
    local base_effects = rules_api:Invoke(
        "RW_EvaluateRules", base_world.world, base_generated
    )
    local effective = properties_api:Invoke(
        "RW_ProjectWorld", base_world.world, base_effects
    )

    local function has_trait(world_state, id, trait)
        local entity = world_state.entities[id]

        return entity ~= nil
            and entity.traits ~= nil
            and entity.traits[trait] == true
    end

    local base_valid =
        effective ~= nil
        and #base_effects == 6
        -- No rule-derived traits may leak into authored state.
        and base_world.world.entities[6].traits == nil
        and base_world.world.entities[1].traits == nil
        -- Each Text receives PUSH from the class-based base rule.
        and has_trait(effective, 6, "pushable")
        and has_trait(effective, 7, "pushable")
        and has_trait(effective, 8, "pushable")
        and has_trait(effective, 9, "pushable")
        and has_trait(effective, 10, "pushable")
        and has_trait(effective, 11, "pushable")
        -- CRATE IS PUSH and AVATAR IS YOU still work normally.
        and has_trait(effective, 4, "pushable")
        and has_trait(effective, 5, "pushable")
        and has_trait(effective, 1, "you")
        -- Being YOU does not imply being PUSH.
        and not has_trait(effective, 1, "pushable")

    if not base_valid then
        printerr("[RuleWorld] TEST FAILED: TEXT IS PUSH base rule")
        return
    end

    -- Breaking CRATE IS PUSH must retract PUSH from crates
    -- without affecting the rule-derived PUSH of any Text.
    base_world.world.entities[8].x = 12
    base_world.world.entities[8].y = 12

    local broken_lines = reader_api:Invoke(
        "RW_ReadLines", base_world.world
    )
    local broken_ast = grammar_api:Invoke(
        "RW_ParseRuleAST", broken_lines, base_world.world.language
    )
    local broken_generated = rules_api:Invoke(
        "RW_LowerRuleAST", broken_ast
    )
    local broken_effects = rules_api:Invoke(
        "RW_EvaluateRules", base_world.world, broken_generated
    )
    local broken_effective = properties_api:Invoke(
        "RW_ProjectWorld", base_world.world, broken_effects
    )

    if not broken_effective
        or #broken_effects ~= 5
        or has_trait(broken_effective, 4, "pushable")
        or has_trait(broken_effective, 5, "pushable")
        or not has_trait(broken_effective, 6, "pushable")
        or not has_trait(broken_effective, 8, "pushable")
        or not has_trait(broken_effective, 1, "you") then
        printerr("[RuleWorld] TEST FAILED: TEXT PUSH retraction isolation")
        return
    end

    print("[RuleWorld] TEST PASSED: pipeline TEXT IS PUSH base rule")

    print("[RuleWorld] TEST PASSED: pipeline AST/legacy parity")

    -- End-to-end M9.3C fixture: spell CRATE IS AVATAR,
    -- move once, then transform both crates in the same
    -- atomic history entry. No changes to the live level.
    local conversion_session =
        world_api:Invoke("RW_CreateSession")

    local conversion_world = conversion_session.world

    conversion_world.entities[9].x = 4
    conversion_world.entities[9].y = 4
    conversion_world.entities[8].x = 12
    conversion_world.entities[8].y = 12

    local conversion_turn = {
        consumes_turn = true,
        changes = {{
            kind = "move",
            entity_id = 1,
            from = { x = 2, y = 2 },
            to = { x = 2, y = 3 }
        }}
    }

    local preview, preview_error =
        world_api:Invoke(
            "RW_PreviewPlan",
            conversion_world,
            conversion_turn
        )

    if not preview then
        printerr(
            "[RuleWorld] TEST FAILED: conversion preview",
            preview_error
        )
        return
    end

    local parsed_lines = reader_api:Invoke(
        "RW_ReadLines", preview
    )

    local parsed_ast = grammar_api:Invoke(
        "RW_ParseRuleAST",
        parsed_lines,
        preview.language
    )

    if not parsed_ast then
        printerr("[RuleWorld] TEST FAILED: conversion grammar")
        return
    end

    local _, deferred, conversion_relations =
        rules_api:Invoke("RW_LowerRuleAST", parsed_ast)

    local conversion_ops, conversion_error =
        rules_api:Invoke(
            "RW_PlanConversions",
            preview,
            conversion_relations
        )

    if not conversion_ops or #conversion_ops ~= 2
        or #deferred ~= 0 then
        printerr(
            "[RuleWorld] TEST FAILED: conversion planner",
            conversion_error or "unexpected output"
        )
        return
    end

    for _, change in ipairs(conversion_ops) do
        conversion_turn.changes[#conversion_turn.changes + 1] = change
    end

    local completed, completion_result =
        world_api:Invoke(
            "RW_Commit",
            conversion_session,
            conversion_turn
        )

    if not completion_result.accepted
        or completed.world.entities[4].archetype ~= "avatar"
        or completed.world.entities[5].archetype ~= "avatar"
        or completed.world.entities[1].y ~= 3
        or #completed.history ~= 1 then
        printerr("[RuleWorld] TEST FAILED: conversion commit")
        return
    end

    local restored, undo_result =
        world_api:Invoke("RW_Undo", completed)

    if not undo_result.accepted
        or #restored.history ~= 0
        or restored.world.entities[4].archetype ~= "crate"
        or restored.world.entities[5].archetype ~= "crate"
        or restored.world.entities[1].y ~= 2
        or conversion_world.entities[4].archetype ~= "crate" then
        printerr("[RuleWorld] TEST FAILED: conversion undo")
        return
    end

    print("[RuleWorld] TEST PASSED: pipeline CRATE IS AVATAR / Undo")

    end -- module and legacy pipeline diagnostics

    local session =
        world_api:Invoke("RW_CreateSession")

    if not session then
        printerr("[RuleWorld] Session creation failed")
        return
    end

    local compile_services = {
        read=function(world,tokens) return reader_api:Invoke("RW_ReadLines",world,tokens) end,
        parse=function(lines,language) return grammar_api:Invoke("RW_ParseRuleAST",lines,language) end,
        lower=function(ast,semantics,world) return rules_api:Invoke("RW_LowerRuleAST",ast,semantics,world) end,
        evaluate=function(world,rules) return rules_api:Invoke("RW_EvaluateRules",world,rules) end,
        project=function(world,effects,traits) return properties_api:Invoke("RW_ProjectWorld",world,effects,traits) end,
        words=function(world,effective) return rules_api:Invoke("RW_WordTokenMap",world,effective) end
    }
    local function evaluate(world_state)
        local frame,problem=RW_CompileWorld(world_state or session.world,compile_services)
        if not frame then
            print("[RuleWorld] Rule compilation rejected:",problem.stage,problem.reason)
            return nil,nil,nil,nil,nil,problem.reason
        end
        return frame.effects,#frame.ast,#frame.deferred,frame.relations,frame.rules,nil,frame.active_text_ids
    end

    -- Mapped script calls stay in the host adapter, outside the scheduler.
    local turn_services = {
        evaluate = function(world_state)
            local effects, rule_count, deferred_count, conversions, generated, why = evaluate(world_state)
            if not effects then return nil, why or "evaluation_failed" end
            return effects, nil, conversions, generated
        end,
        project = function(world_state, effects, traits)
            return properties_api:Invoke("RW_ProjectWorld", world_state, effects, traits)
        end,
        resolve = function(world_state, action)
            return movement_api:Invoke("RW_ResolveTurn", world_state, action)
        end,
        preview = function(world_state, plan)
            return world_api:Invoke("RW_PreviewPlan", world_state, plan)
        end,
        convert = function(world_state, conversions)
            return rules_api:Invoke("RW_PlanConversions", world_state, conversions)
        end
    }

    local contact_services = {
        victims=function(world,kind) return properties_api:Invoke("RW_ResolveContactVictims",world,kind) end,
        births=function(world,ids,contents) return rules_api:Invoke("RW_PlanHasBirths",world,ids,contents) end,
        delete=function(world,ids) return world_api:Invoke("RW_PlanDelete",world,ids) end,
        create=function(world,specifications) return world_api:Invoke("RW_PlanCreate",world,specifications) end
    }
    turn_services.contact=function(world,effective,kind,contents)
        return RW_PlanContactPhase(world,effective,kind,contents,contact_services)
    end
    turn_services.more=function(world,projected)
        local products,why=properties_api:Invoke("RW_ResolveMoreProducts",projected)
        if not products then return nil,why end
        return world_api:Invoke("RW_PlanCreate",world,products)
    end
    turn_services.play=function(world,relations) return rules_api:Invoke("RW_ResolvePlayEvents",world,relations) end
    turn_services.fall=function(world) return movement_api:Invoke("RW_ResolveFall",world) end
    turn_services.orient=function(world) return movement_api:Invoke("RW_ResolveOrientation",world) end
    turn_services.automatic=function(world) return movement_api:Invoke("RW_ResolveAutomatic",world) end
    turn_services.eat=function(world,projected,relations,contents)
        local targets=rules_api:Invoke("RW_ResolveVerbTargets",world,relations,"eat")
        local ids=properties_api:Invoke("RW_ResolveEatVictims",projected,targets)
        return RW_PlanDestructionPhase(world,ids,contents,"eat",contact_services)
    end
    turn_services.make=function(world,relations,converted)
        local products,rng=rules_api:Invoke("RW_PlanMakeProducts",world,relations,converted)
        local creation,why=world_api:Invoke("RW_PlanCreate",world,products)
        if not creation then return nil,why end
        creation.random_state=rng
        return creation
    end
    turn_services.follow=function(world,relations)
        local targets=rules_api:Invoke("RW_ResolveVerbTargets",world,relations,"follow")
        return movement_api:Invoke("RW_ResolveFollow",world,targets)
    end
    turn_services.fear=function(world,relations)
        local targets=rules_api:Invoke("RW_ResolveFearTargets",world,relations)
        return movement_api:Invoke("RW_ResolveFear",world,targets)
    end
    turn_services.shift=function(world) return movement_api:Invoke("RW_ResolveShift",world) end
    turn_services.destroy=function(world,ids,contents,cause,deaths)
        return RW_PlanDestructionPhase(world,ids,contents,cause,contact_services,deaths)
    end
    turn_services.refresh=function(world,rules) return rules_api:Invoke("RW_EvaluateRules",world,rules) end

    if run_self_tests then

    do
        local definitions=world_api:Invoke("RW_GetNavigationDefinitions")
        local probe=world_api:Invoke("RW_InstantiateLevel",definitions["navigation.text_word"],"probe:specials")
        probe.world.entities[2].text.name="ALL"
        probe.world.entities[6].y=5
        local frame,why=RW_CompileWorld(probe.world,compile_services)
        if not frame or not frame.word_tokens[1] or not frame.word_tokens[3] or frame.word_tokens[2] then
            printerr("[RuleWorld] TEST FAILED: ALL WORD palette",why and why.reason); return
        end
        probe.world.entities[2].text.name="EMPTY"
        probe.world.entities[6].text.name="TEXT"
        local e,_,_,relations=evaluate(probe.world)
        local changes,err,allocation=rules_api:Invoke("RW_PlanConversions",probe.world,relations)
        if not e or not changes then printerr("[RuleWorld] TEST FAILED: EMPTY TEXT plan",err); return end
        local completed,status=world_api:Invoke("RW_Commit",probe,{consumes_turn=true,changes=changes,id_allocation=allocation})
        if not status.accepted or not completed.world.entities[probe.world.next_entity_id]
            or completed.world.entities[probe.world.next_entity_id].text.name ~= "EMPTY" then
            printerr("[RuleWorld] TEST FAILED: EMPTY TEXT births"); return
        end
        local restored=world_api:Invoke("RW_Undo",completed)
        if restored.world.next_entity_id ~= probe.world.next_entity_id or restored.world.entities[probe.world.next_entity_id] then
            printerr("[RuleWorld] TEST FAILED: EMPTY TEXT Undo"); return
        end
        print("[RuleWorld] TEST PASSED: pipeline ALL WORD / EMPTY TEXT / Undo")
    end

    do
        local definitions=world_api:Invoke("RW_GetNavigationDefinitions")
        for _,kind in ipairs({"defeat","sink","has"}) do
            local initial=world_api:Invoke("RW_InstantiateLevel",definitions["navigation.contact_" .. kind],"probe:" .. kind)
            local turn,why=RW_PlanTurn(initial.world,{type="move",dx=1,dy=0},turn_services)
            if not turn then printerr("[RuleWorld] TEST FAILED: contact planning",kind,why and why.reason); return end
            local completed,result=world_api:Invoke("RW_Commit",initial,turn)
            local rocks=0
            for _,entity in pairs(completed.world.entities) do if entity.archetype == "rock" then rocks=rocks+1 end end
            if not result.accepted or #completed.history ~= 1
                or (kind == "defeat" and (completed.world.entities[1] or not completed.world.entities[15]))
                or (kind ~= "defeat" and (completed.world.entities[4] or completed.world.entities[15]))
                or (kind == "has" and rocks ~= 2) then
                printerr("[RuleWorld] TEST FAILED: contact outcome",kind); return
            end
            local restored=world_api:Invoke("RW_Undo",completed)
            if restored.world.next_entity_id ~= initial.world.next_entity_id or not restored.world.entities[1] then
                printerr("[RuleWorld] TEST FAILED: contact Undo",kind); return
            end
        end
        print("[RuleWorld] TEST PASSED: pipeline DEFEAT / SINK / repeated HAS / atomic Undo")
    end

    do
        local definitions=world_api:Invoke("RW_GetNavigationDefinitions")
        local definition=definitions["navigation.text_word"]
        local initial=world_api:Invoke("RW_InstantiateLevel",definition,"probe:text_word")
        local current=initial
        for _=1,2 do
            local plan,why=RW_PlanTurn(current.world,{type="move",dx=0,dy=-1},turn_services)
            if not plan then printerr("[RuleWorld] TEST FAILED: WORD plan",why and why.reason); return end
            current=world_api:Invoke("RW_Commit",current,plan)
        end
        local effects=evaluate(current.world)
        local projected=properties_api:Invoke("RW_ProjectWorld",current.world,effects)
        if not projected.entities[3].behaviors.word or projected.entities[3].class ~= "object" then
            printerr("[RuleWorld] TEST FAILED: WORD object reading"); return
        end
        local text=world_api:Invoke("RW_InstantiateLevel",definition,"probe:is_text")
        text.world.entities[8].x,text.world.entities[8].y=6,5
        local plan,why=RW_PlanTurn(text.world,{type="move",dx=0,dy=1},turn_services)
        if not plan then printerr("[RuleWorld] TEST FAILED: IS TEXT plan",why and why.reason); return end
        local converted,result=world_api:Invoke("RW_Commit",text,plan)
        if not result.accepted or converted.world.entities[3].class ~= "text"
            or converted.world.entities[3].text.name ~= "ROCK" then
            printerr("[RuleWorld] TEST FAILED: IS TEXT class conversion"); return
        end
        local restored=world_api:Invoke("RW_Undo",converted)
        if restored.world.entities[3].class ~= "object" then printerr("[RuleWorld] TEST FAILED: IS TEXT Undo"); return end
        print("[RuleWorld] TEST PASSED: pipeline IS TEXT / WORD object reading / Undo")
    end

    -- Two physical languages, one semantic IR and one atomic turn behavior.
    local function same_data(left, right)
        if type(left) ~= type(right) then return false end
        if type(left) ~= "table" then return left == right end
        for key, value in pairs(left) do
            if not same_data(value, right[key]) then return false end
        end
        for key in pairs(right) do if left[key] == nil then return false end end
        return true
    end
    local default_verbs = grammar_api:Invoke("RW_GetVerbRegistry")
    local registered_verbs = grammar_api:Invoke("RW_RegisterVerb", default_verbs,
        "bind", {phase = "relation", rhs = {property = true, noun = true}})
    local default_semantics = rules_api:Invoke("RW_GetSemanticRegistry")
    local registered_semantics = rules_api:Invoke("RW_RegisterSemantics", default_semantics,
        "bind", {property = "grant_trait", noun = "transform"})
    if not registered_verbs or not registered_semantics then
        printerr("[RuleWorld] TEST FAILED: language/semantics registration")
        return
    end
    for _, case in ipairs({{"PUSH", "SHOVE"}, {"YOU", "DRIVE"}, {"AVATAR", "HERO"}}) do
        local standard = world_api:Invoke("RW_CreateSession")
        local alternate = world_api:Invoke("RW_CreateSession")
        standard.world.entities[8].text.name = case[1]
        alternate.world.language = {
            nouns = {BOX = "crate", HERO = "avatar"},
            verbs = {LINK = "bind"}, properties = {SHOVE = "pushable", DRIVE = "you"},
            order = {"object", "verb", "subject"}, verb_registry = registered_verbs
        }
        alternate.world.semantics = registered_semantics
        local tokens = {[6] = case[2], [7] = "LINK", [8] = "BOX",
            [9] = "DRIVE", [10] = "LINK", [11] = "HERO"}
        for id, token in pairs(tokens) do alternate.world.entities[id].text.name = token end
        local effects_a = evaluate(standard.world)
        local effects_b = evaluate(alternate.world)
        local action = {type = "move", dx = 1, dy = 0}
        local plan_a = RW_PlanTurn(standard.world, action, turn_services)
        local plan_b = RW_PlanTurn(alternate.world, action, turn_services)
        if not effects_a or not effects_b or not same_data(effects_a, effects_b)
            or not plan_a or not plan_b or not same_data(plan_a.stages, plan_b.stages)
            or plan_a.reason ~= plan_b.reason or plan_a.level_transform ~= plan_b.level_transform
            or not same_data(plan_a.level_traits,plan_b.level_traits) then
            printerr("[RuleWorld] TEST FAILED: alternate language behavior", case[1])
            return
        end
        local completed, committed = world_api:Invoke("RW_Commit", alternate, plan_b)
        local restored, undone = world_api:Invoke("RW_Undo", completed)
        if not committed.accepted or not undone.accepted or #restored.history ~= 0
            or not same_data(restored.world, alternate.world) then
            printerr("[RuleWorld] TEST FAILED: alternate language Undo")
            return
        end
    end
    print("[RuleWorld] TEST PASSED: pipeline alternate grammar/semantics behavior / Undo")

    -- Custom selectors and trait names feed the SAME solver and atomic world API.
    local selectors = rules_api:Invoke("RW_RegisterSelector",
        rules_api:Invoke("RW_GetSelectorRegistry"), "type_name",
        {mode = "field", path = {"archetype"}, value_type = "string"})
    selectors = rules_api:Invoke("RW_RegisterSelector", selectors, "named",
        {mode = "field", path = {"text", "name"}, value_type = "string"})
    local behaviors = {}
    for _, item in ipairs({{"drive", {control = true}}, {"shove", {push = true}},
        {"solid", {block_entry = true}}}) do
        behaviors = properties_api:Invoke("RW_RegisterBehavior", behaviors, item[1], item[2])
        if not behaviors then
            printerr("[RuleWorld] TEST FAILED: behavior registration")
            return
        end
    end
    if not selectors then
        printerr("[RuleWorld] TEST FAILED: selector registration")
        return
    end
    local custom = world_api:Invoke("RW_CreateSession")
    custom.world.width, custom.world.height = 6, 4
    custom.world.selectors, custom.world.behavior_registry = selectors, behaviors
    custom.world.entities = {
        [1] = {id = 1, kind = "object", class = "object", archetype = "avatar",
            x = 2, y = 2, direction = "Mid"},
        [2] = {id = 2, kind = "object", class = "object", archetype = "crate",
            x = 3, y = 2, direction = "None"},
        [3] = {id = 3, kind = "object", class = "text", text = {name = "BOX"},
            x = 4, y = 2, direction = "Left"},
        [4] = {id = 4, kind = "object", class = "object", archetype = "wall",
            x = 5, y = 2, direction = "None"},
        [5] = {id = 5, kind = "object", class = "text", text = {name = "SIGN"},
            x = 2, y = 2, direction = "None"}
    }
    local function grant(target, trait, when)
        return {when = when or {op = "always"}, effects = {
            {op = "grant_trait", target = target, trait = trait}}}
    end
    custom.world.rule_sources = {
        grant({kind = "type_name", value = "avatar"}, "drive", {op = "overlap",
            left = {kind = "type_name", value = "avatar"}, right = {kind = "named", value = "SIGN"}}),
        grant({kind = "type_name", value = "crate"}, "shove"),
        grant({kind = "class", value = "text"}, "shove"),
        grant({kind = "type_name", value = "wall"}, "solid")
    }
    local right = {type = "move", dx = 1, dy = 0}
    local blocked = RW_PlanTurn(custom.world, right, turn_services)
    if not blocked or #blocked.changes ~= 1 or blocked.changes[1].kind ~= "direction"
        or blocked.changes[1].to ~= "Right" then
        printerr("[RuleWorld] TEST FAILED: custom behavior blocking")
        return
    end
    local deletion = world_api:Invoke("RW_PlanDelete", custom.world, {4})
    local opened, opened_result = world_api:Invoke("RW_Commit", custom, deletion)
    local push = RW_PlanTurn(opened.world, right, turn_services)
    if not opened_result.accepted or not push or #push.changes ~= 3 then
        printerr("[RuleWorld] TEST FAILED: custom selector PUSH chain")
        return
    end
    local moved, move_result = world_api:Invoke("RW_Commit", opened, push)
    local inactive = RW_PlanTurn(moved.world, right, turn_services)
    local restored, undo_result = world_api:Invoke("RW_Undo", moved)
    if not move_result.accepted or moved.world.entities[1].x ~= 3
        or moved.world.entities[3].x ~= 5 or moved.world.entities[3].direction ~= "Right"
        or moved.world.entities[1].traits or moved.world.entities[1].behaviors
        or not inactive or inactive.reason ~= "no_you" or #inactive.changes ~= 0
        or not undo_result.accepted or not same_data(restored.world, opened.world) then
        printerr("[RuleWorld] TEST FAILED: custom behavior retraction / Undo")
        return
    end
    print("[RuleWorld] TEST PASSED: pipeline custom selectors/behaviors / atomic Undo")

    -- Exercise the same scheduler the input adapter will use, without a Commit.
    local probe, probe_error = RW_PlanTurn(session.world,
        {type = "move", dx = 1, dy = 0}, turn_services)
    if not probe or not probe.consumes_turn or #probe.changes ~= 3
        or session.world.entities[1].x ~= 2
        or session.world.entities[1].direction ~= "None" then
        printerr("[RuleWorld] TEST FAILED: turn scheduler",
            probe_error and probe_error.reason or "unexpected_plan")
        return
    end
    print("[RuleWorld] TEST PASSED: pipeline atomic turn scheduler")

    -- Created/deleted symbols flow through the real Reader/AST/Rule pipeline.
    local lifecycle = world_api:Invoke("RW_CreateSession")
    local specifications = {}
    for index, name in ipairs({"CRATE", "IS", "YOU"}) do
        specifications[index] = {kind = "object", class = "text",
            x = 6 + index, y = 8, direction = "None", text = {name = name}}
    end
    local creation = world_api:Invoke("RW_PlanCreate", lifecycle.world, specifications)
    if not creation then
        printerr("[RuleWorld] TEST FAILED: lifecycle creation planning")
        return
    end
    local populated, created_result = world_api:Invoke("RW_Commit", lifecycle, creation)
    if not created_result.accepted then
        printerr("[RuleWorld] TEST FAILED: lifecycle creation commit")
        return
    end
    local controlled = RW_PlanTurn(populated.world,
        {type = "move", dx = 0, dy = 1}, turn_services)
    if not controlled or #controlled.changes ~= 3 then
        printerr("[RuleWorld] TEST FAILED: created Text rule evaluation")
        return
    end
    local deletion = world_api:Invoke("RW_PlanDelete", populated.world, {12})
    local removed, deleted_result = world_api:Invoke("RW_Commit", populated, deletion)
    local uncontrolled = RW_PlanTurn(removed.world,
        {type = "move", dx = 0, dy = 1}, turn_services)
    local returned, restored_result = world_api:Invoke("RW_Undo", removed)
    if not deleted_result.accepted or not uncontrolled or #uncontrolled.changes ~= 1
        or not restored_result.accepted or not returned.world.entities[12]
        or returned.world.next_entity_id ~= 15 then
        printerr("[RuleWorld] TEST FAILED: deleted Text rule/Undo")
        return
    end
    print("[RuleWorld] TEST PASSED: pipeline created/deleted Text rules / Undo")

    end -- turn pipeline diagnostics

    local demo_definitions, root_definition_id = world_api:Invoke("RW_GetNavigationDefinitions")
    local level_tree = world_api:Invoke("RW_CreateLevelTree",demo_definitions,root_definition_id)
    session = world_api:Invoke("RW_GetActiveLevel",level_tree)
    local level_services = {}
    for name, service in pairs(turn_services) do level_services[name] = service end
    level_services.active = function(tree) return world_api:Invoke("RW_GetActiveLevel",tree) end
    level_services.update = function(tree,value) return world_api:Invoke("RW_UpdateActiveLevel",tree,value) end
    level_services.enter = function(tree,slot,id) return world_api:Invoke("RW_EnterLevel",tree,slot,id) end
    level_services.return_level = function(tree) return world_api:Invoke("RW_ReturnLevel",tree) end
    level_services.bind_entry = function(tree,id) return world_api:Invoke("RW_BindLevelEntry",tree,id) end
    level_services.commit_session = function(value,plan) return world_api:Invoke("RW_Commit",value,plan) end
    level_services.outcome = function(tree,kind,target) return world_api:Invoke("RW_RecordLevelOutcome",tree,kind,target) end
    level_services.selectors = function(world) return movement_api:Invoke("RW_LevelSelectorIDs",world) end
    level_services.place_selectors = function(tree,ids,block)
        return world_api:Invoke("RW_PlaceLevelSelectors",tree,ids,block)
    end
    level_services.candidates = function(world) return movement_api:Invoke("RW_LevelSelectionCandidates",world) end
    level_services.win = function(world) return movement_api:Invoke("RW_HasWinContact",world) end
    level_services.level_outcome = function(world,traits)
        return properties_api:Invoke("RW_ResolveLevelPropertyOutcome",world,traits)
    end

    if run_self_tests then
    -- Real mapped pipeline probe; never change the live tree during self-tests.
    do
        local probe = level_tree
        local function step(action)
            local plan, err = RW_PlanLevelAction(probe,action,level_services)
            if not plan then return false, err and err.reason end
            local result
            probe, result = world_api:Invoke("RW_CommitLevelTree",probe,plan)
            return result.accepted
        end
        local function up() return step({type="move",dx=0,dy=-1}) end
        local function confirm() return step({type="confirm"}) end
        if not up() or probe.active_id ~= level_tree.active_id or not confirm()
            or #probe.stack ~= 1 then
            printerr("[RuleWorld] TEST FAILED: explicit SELECT confirmation"); return
        end
        local entered = probe
        if not step({type="move",dx=1,dy=0}) or not confirm() or #probe.stack ~= 0 then
            printerr("[RuleWorld] TEST FAILED: parent block exit"); return
        end
        probe = world_api:Invoke("RW_UndoLevelTree",probe)
        if probe.active_id ~= entered.active_id
            or world_api:Invoke("RW_GetActiveLevel",probe).world.entities[4].x ~= 4 then
            printerr("[RuleWorld] TEST FAILED: navigation Undo"); return
        end
        probe = entered
        if not step({type="move",dx=0,dy=1}) or #probe.stack ~= 0 then
            printerr("[RuleWorld] TEST FAILED: win exit"); return
        end
        probe = level_tree
        if not up() or not step({type="move",dx=1,dy=0}) or not confirm() or not up()
            or #probe.stack ~= 0
            or world_api:Invoke("RW_GetActiveLevel",probe).world.entities[15].archetype ~= "crate" then
            printerr("[RuleWorld] TEST FAILED: level transform exit"); return
        end
        probe = world_api:Invoke("RW_UndoLevelTree",probe)
        if #probe.stack ~= 1 or world_api:Invoke("RW_GetActiveLevel",probe).world.entities[18].y ~= 9 then
            printerr("[RuleWorld] TEST FAILED: level transform Undo"); return
        end
        print("[RuleWorld] TEST PASSED: pipeline SELECT confirm / parent / win / level transform / tree Undo")
    end

    do
        local function apply(probe,action)
            local plan = RW_PlanLevelAction(probe,action,level_services)
            if not plan then return nil end
            local next_tree, accepted = world_api:Invoke("RW_CommitLevelTree",probe,plan)
            return accepted.accepted and next_tree or nil
        end
        local cases = {{"win","win"},{"defeat","defeat"},{"win_defeat","win"},
            {"defeat_win","defeat"},{"rock_win","transform"}}
        for index, test in ipairs(cases) do
            local probe = level_services.enter(level_tree,tostring(36+index),"navigation." .. test[1])
            probe = level_services.bind_entry(probe,36+index)
            local child_id = probe.active_id
            local completed = apply(probe,{type="move",dx=0,dy=-1})
            if not completed or not completed.outcomes[child_id]
                or completed.outcomes[child_id].kind ~= test[2]
                or (test[2] == "defeat" and completed.active_id ~= child_id)
                or (test[2] ~= "defeat" and completed.active_id ~= level_tree.active_id) then
                printerr("[RuleWorld] TEST FAILED: ordered LEVEL outcome",test[1]); return
            end
            if test[2] == "defeat" then
                local selected = apply(completed,{type="move",dx=1,dy=0})
                if not selected or level_services.active(selected).world.entities[12].x ~= 2 then
                    printerr("[RuleWorld] TEST FAILED: defeat disabled SELECT"); return
                end
            end
            local undone = world_api:Invoke("RW_UndoLevelTree",completed)
            if undone.active_id ~= child_id or undone.outcomes[child_id]
                or level_services.active(undone).world.entities[16].y ~= 9 then
                printerr("[RuleWorld] TEST FAILED: ordered LEVEL outcome Undo",test[1]); return
            end
        end
        local probe = level_services.enter(level_tree,"42","navigation.noun_level")
        probe = level_services.bind_entry(probe,42)
        local completed = apply(probe,{type="move",dx=0,dy=-1})
        local world = completed and level_services.active(completed).world
        if not world or world.entities[4].archetype ~= "level_block"
            or world.entities[5].archetype ~= "level_block" or not world.entities[4].level_link
            or world.entities[5].level_link then
            printerr("[RuleWorld] TEST FAILED: Noun IS LEVEL identity-bound destinations"); return
        end
        local selector_only = apply(level_tree,{type="move",dx=1,dy=0})
        for _=1,4 do selector_only = apply(selector_only,{type="move",dx=1,dy=0}) end
        selector_only = apply(selector_only,{type="move",dx=0,dy=-1})
        selector_only = apply(selector_only,{type="confirm"})
        local selector_id = selector_only.active_id
        selector_only = apply(selector_only,{type="move",dx=1,dy=0})
        if not selector_only or selector_only.active_id ~= selector_id or selector_only.outcomes[selector_id] then
            printerr("[RuleWorld] TEST FAILED: SELECT-only WIN exited level"); return
        end
        print("[RuleWorld] TEST PASSED: SELECT-only WIN keeps level active")
        print("[RuleWorld] TEST PASSED: pipeline ordered LEVEL WIN/DEFEAT/transform and Noun IS LEVEL / Undo")
    end

    end -- navigation diagnostics

    local pending_selection = nil
    local function navigation_view()
        local outcome = level_tree.outcomes[level_tree.active_id]
        local defeated = session.defeated == true
        if session.world.infinite_loop then return {title="INFINITE LOOP / " .. session.instance_id,
            hint="INFINITE LOOP: Z Undo",portals={}} end
        if session.world.too_complex then return {title="TOO COMPLEX / " .. session.instance_id,
            hint="TOO COMPLEX: Z Undo",portals={}} end
        local choice
        if pending_selection then
            choice = {items={},index=pending_selection.index,error=pending_selection.error}
            for _, id in ipairs(pending_selection.ids) do
                local entity = session.world.entities[id]
                choice.items[#choice.items+1] = {entity_id=id,
                    label=entity.level_link and entity.level_link.label or "LEVEL",
                    available=entity.level_link ~= nil}
            end
        end
        return {choice=choice,title=(defeated and "DEFEAT / " or (#level_tree.stack == 0 and "MAP / " or "PUZZLE / ")) .. session.instance_id,
            hint=defeated and "DEFEAT: SELECT remains active; Z Undo" or "WASD: YOU + SELECT   F: Confirm   Z: Whole-tree Undo",portals={}}
    end

    local previous_rule_count = nil
    local previous_deferred_count = nil

    local function render()
        if session.world.infinite_loop or session.world.too_complex then
            renderer_api:Invoke("RW_Render",session.world,#level_tree.history,0,navigation_view())
            return
        end
        local effects, rule_count, deferred_count, scope_commands, _, _, active_text_ids = evaluate()
        if not effects then return end

        if previous_rule_count ~= rule_count
            or previous_deferred_count ~= deferred_count then
            print(string.format(
                "[RuleWorld] Spatial rules: %d, effects: %d, deferred: %d",
                rule_count,
                #effects,
                deferred_count
            ))

            previous_rule_count = rule_count
            previous_deferred_count = deferred_count
        end

        local display_world, projection_error = properties_api:Invoke("RW_ProjectWorld",session.world,effects,level_traits_from(scope_commands))
        if not display_world then printerr("[RuleWorld] View projection failed:",projection_error); return end
        display_world.active_text_ids=active_text_ids
        renderer_api:Invoke(
            "RW_Render",
            display_world,
            #level_tree.history,
            #effects,
            navigation_view()
        )
    end

    local function act(action)
        local plan, planning_error = RW_PlanLevelAction(level_tree,action,level_services)
        if not plan then
            if planning_error.reason == "choose_level" then
                pending_selection = {tree=level_tree,ids=planning_error.candidates,index=1}
                render()
                return true,"choice_opened"
            end
            if pending_selection then pending_selection.error = planning_error.reason; render() end
            print("[RuleWorld] Action rejected:",planning_error.stage,planning_error.reason)
            return false, planning_error.reason
        end
        local next_tree, result = world_api:Invoke("RW_CommitLevelTree",level_tree,plan)
        if not result.accepted then printerr("[RuleWorld] Tree commit rejected:",result.reason); return false, result.reason end
        for _,event in ipairs(plan.events or {}) do if event.kind=="play" then
            print(string.format("[RuleWorld] PLAY %s %s frequency=%s sources=%d",event.source_type,event.note,tostring(event.frequency),#event.positions))
        end end
        if plan.outcome_diagnostic then print("[RuleWorld] WIN evidence: " .. plan.outcome_diagnostic) end
        level_tree = next_tree
        pending_selection = nil
        session = world_api:Invoke("RW_GetActiveLevel",level_tree)
        print(string.format("[RuleWorld] Tree action %s -> %s depth=%d history=%d",
            result.reason or action.type,session.instance_id,#level_tree.stack,#level_tree.history))
        render()
        return true
    end

    local function move(dx,dy)
        if pending_selection then
            if dy ~= 0 then
                pending_selection.index = (pending_selection.index-1+dy)%#pending_selection.ids+1
                render()
            end
            return
        end
        act({type="move",dx=dx,dy=dy})
    end

    local function undo()
        if pending_selection then pending_selection = nil; render(); return end
        local next_tree, result = world_api:Invoke("RW_UndoLevelTree",level_tree)
        if not result.accepted then print("[RuleWorld] Undo rejected:",result.reason); return end
        level_tree = next_tree
        session = world_api:Invoke("RW_GetActiveLevel",level_tree)
        print(string.format("[RuleWorld] Tree Undo -> %s depth=%d history=%d",
            session.instance_id,#level_tree.stack,#level_tree.history))
        render()
    end

    local function bind(key, dx, dy)
        root:AddKeyEventListener(key, function()
            move(dx, dy)
            return true
        end)
    end

    local key = Enum.KeyEventType

    bind(key.KeyboardMoveForwardKeyDown, 0, -1)
    bind(key.KeyboardMoveBackwardKeyDown, 0, 1)
    bind(key.KeyboardMoveLeftKeyDown, -1, 0)
    bind(key.KeyboardMoveRightKeyDown, 1, 0)

    if key.KeyboardJumpKeyDown then
        root:AddKeyEventListener(key.KeyboardJumpKeyDown,function()
            if not pending_selection then act({type="wait"}) end
            return true
        end)
        print("[RuleWorld] Wait registered (Space)")
    end

    if key.KeyboardCraftspersonKey12Down then
        root:AddKeyEventListener(
            key.KeyboardCraftspersonKey12Down,
            function()
                undo()
                return true
            end
        )
        print("[RuleWorld] Undo registered (Z)")
    end

    choose_selected_level = function(entity_id)
        if not pending_selection then return false,"no_level_choice" end
        if entity_id == 0 then pending_selection = nil; render(); return true end
        if pending_selection.tree ~= level_tree then
            pending_selection = nil; render(); return false,"stale_level_choice"
        end
        local listed = false
        for _, id in ipairs(pending_selection.ids) do if id == entity_id then listed = true end end
        if not listed then return false,"invalid_level_choice" end
        return act({type="confirm",entity_id=entity_id})
    end
    confirm_selected_level = function()
        if pending_selection then return choose_selected_level(pending_selection.ids[pending_selection.index]) end
        return act({type="confirm"})
    end
    if key.KeyboardInteractKeyDown then
        root:AddKeyEventListener(key.KeyboardInteractKeyDown,function()
            RW_ConfirmSelectedLevel()
            return true
        end)
        print("[RuleWorld] Confirm registered (F)")
    else
        printerr("[RuleWorld] Missing KeyboardInteractKeyDown for F confirmation")
    end
    render()

    print("[RuleWorld] M9.4R initialized")
end

-- Production entry point: build the authored world, bind controls and render only.
-- Engine-provided callback arguments cannot enable diagnostics accidentally.
function OnStart()
    return start(false)
end

-- Explicit offline/fresh-host diagnostic entry point. Not bound to gameplay keys.
-- The test harness invokes this in isolation, never on top of a running game.
function RW_StartWithSelfTests()
    return start(true)
end
