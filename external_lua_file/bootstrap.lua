-- bootstrap.lua
-- RuleWorld M7: Runtime coordination

-- M9.3F: host-independent turn planning. Services adapt mapped scripts;
-- no UI calls, logging, session ownership or Commit occur in this function.
-- Services must treat world/context inputs as read-only.
function RW_PlanTurn(world, action, services)
    local trace = {}
    local function fail(stage, reason)
        return nil, {stage = stage, reason = reason or "stage_failed", trace = trace}
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
    local effects, rule_error = services.evaluate(world)
    if not effects then return fail("rules_before", rule_error) end

    trace[#trace + 1] = "project"
    local effective, projection_error = services.project(world, effects)
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

    trace[#trace + 1] = "rules_after"
    local post_effects, post_error, conversions = services.evaluate(preview)
    if not post_effects then return fail("rules_after", post_error) end

    trace[#trace + 1] = "conversions"
    local operations, conversion_error = services.convert(preview, conversions)
    if not operations then return fail("conversions", conversion_error) end

    -- Own the combined list: never append into another planner's result.
    local plan = {consumes_turn = true, reason = movement.reason, changes = {}}
    for _, change in ipairs(movement.changes) do
        plan.changes[#plan.changes + 1] = change
    end
    for _, change in ipairs(operations) do
        plan.changes[#plan.changes + 1] = change
    end

    -- Validate the WHOLE plan before returning it to the host for one Commit.
    trace[#trace + 1] = "preview_complete"
    local complete, complete_error = services.preview(world, plan)
    if not complete then return fail("preview_complete", complete_error) end
    return plan, nil, trace
end

function OnStart()
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
        { "world",      "RW_LevelInstanceSelfTest" },
        { "movement",   "RW_DirectionMovementSelfTest" },
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
        and #base_effects == 3
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
        or #broken_effects ~= 2
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

    local session =
        world_api:Invoke("RW_CreateSession")

    if not session then
        printerr("[RuleWorld] Session creation failed")
        return
    end

    -- World -> spatial lines -> generated IR
    -- -> active effects.
    local function evaluate(world_state)
        world_state = world_state or session.world

        local lines, read_error =
            reader_api:Invoke(
                "RW_ReadLines",
                world_state
            )

        if not lines then
            printerr(
                "[RuleWorld] Reader failed:",
                read_error
            )
            return nil
        end

        local ast, grammar_error =
            grammar_api:Invoke(
                "RW_ParseRuleAST",
                lines,
                world_state.language
            )

        if not ast then
            printerr(
                "[RuleWorld] AST grammar failed:",
                grammar_error
            )
            return nil
        end

        local generated, deferred, conversions =
            rules_api:Invoke("RW_LowerRuleAST", ast, world_state.semantics)

        if not generated then
            printerr(
                "[RuleWorld] AST lowering failed:",
                deferred
            )
            return nil
        end

        local effects, rule_error =
            rules_api:Invoke(
                "RW_EvaluateRules",
                world_state,
                generated
            )

        if not effects then
            printerr(
                "[RuleWorld] Rule evaluation failed:",
                rule_error
            )
            return nil
        end

        return effects, #ast, #deferred, conversions
    end

    -- Mapped script calls stay in the host adapter, outside the scheduler.
    local turn_services = {
        evaluate = function(world_state)
            local effects, rule_count, deferred_count, conversions = evaluate(world_state)
            if not effects then return nil, "evaluation_failed" end
            return effects, nil, conversions
        end,
        project = function(world_state, effects)
            return properties_api:Invoke("RW_ProjectWorld", world_state, effects)
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
            or not plan_a or not plan_b or not same_data(plan_a, plan_b) then
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

    local previous_rule_count = nil
    local previous_deferred_count = nil

    local function render()
        local effects, rule_count, deferred_count = evaluate()
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

        renderer_api:Invoke(
            "RW_Render",
            session.world,
            #session.history,
            #effects
        )
    end

    local function move(dx, dy)
        local action = {
            type = "move",
            dx = dx,
            dy = dy
        }

        local plan, planning_error = RW_PlanTurn(session.world, action, turn_services)
        if not plan then
            printerr("[RuleWorld] Turn planning failed:",
                planning_error.stage, planning_error.reason)
            return
        end

        -- Movement and transformation: one atomic commit.
        local next_session, result =
            world_api:Invoke(
                "RW_Commit",
                session,
                plan
            )

        if not next_session or not result then
            printerr("[RuleWorld] Commit failed")
            return
        end

        if not result.accepted then
            print(
                "[RuleWorld] Invalid action:",
                result.reason
            )
            return
        end

        session = next_session

        if result.changed then
            for _, change in ipairs(result.changes) do
                if change.kind == "create" or change.kind == "delete" then
                    print(string.format(
                        "[RuleWorld] Entity %d: %s", change.entity_id, change.kind
                    ))
                elseif change.kind == "transform" then
                    print(string.format(
                        "[RuleWorld] Entity %d: %s -> %s",
                        change.entity_id,
                        change.from,
                        change.to
                    ))
                elseif change.kind == "direction" then
                    print(string.format(
                        "[RuleWorld] Entity %d direction: %s -> %s",
                        change.entity_id, change.from, change.to
                    ))
                else
                    print(string.format(
                        "[RuleWorld] Entity %d: (%d,%d) -> (%d,%d)",
                        change.entity_id,
                        change.from.x,
                        change.from.y,
                        change.to.x,
                        change.to.y
                    ))
                end
            end
        else
            print(
                "[RuleWorld] Turn consumed:",
                result.reason or "no_change"
            )
        end

        -- This evaluates the NEW world.
        render()
    end

    local function undo()
        local next_session, result =
            world_api:Invoke(
                "RW_Undo",
                session
            )

        if not next_session or not result then
            printerr("[RuleWorld] Undo failed")
            return
        end

        if not result.accepted then
            print(
                "[RuleWorld] Undo rejected:",
                result.reason
            )
            return
        end

        session = next_session

        print(string.format(
            "[RuleWorld] Undo -> history=%d",
            #session.history
        ))

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

    render()

    print("[RuleWorld] M9.3J initialized")
end
