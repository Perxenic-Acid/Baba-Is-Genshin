-- bootstrap.lua
-- RuleWorld M7: Runtime coordination

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
        { "rules",      "RW_ASTLoweringSelfTest" },
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
            rules_api:Invoke("RW_LowerRuleAST", ast)

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

        -- Evaluate rules against the OLD world.
        local effects = evaluate()
        if not effects then return end

        local effective_world, projection_error =
            properties_api:Invoke(
                "RW_ProjectWorld",
                session.world,
                effects
            )

        if not effective_world then
            printerr(
                "[RuleWorld] Projection failed:",
                projection_error
            )
            return
        end

        -- Resolve the full movement plan.
        local plan = movement_api:Invoke(
            "RW_ResolveTurn",
            effective_world,
            action
        )

        if not plan then
            printerr("[RuleWorld] Movement failed")
            return
        end

        if plan.consumes_turn then
            -- Work on the post-movement state, but DO NOT
            -- commit yet. A newly assembled conversion
            -- applies in this same turn.
            local preview, preview_error =
                world_api:Invoke(
                    "RW_PreviewPlan",
                    session.world,
                    plan
                )

            if not preview then
                printerr(
                    "[RuleWorld] Movement preview failed:",
                    preview_error
                )
                return
            end

            local post_effects, _, _, conversions =
                evaluate(preview)

            if not post_effects then
                return
            end

            local conversion_changes, conversion_error =
                rules_api:Invoke(
                    "RW_PlanConversions",
                    preview,
                    conversions
                )

            if not conversion_changes then
                printerr(
                    "[RuleWorld] Conversion planning failed:",
                    conversion_error
                )
                return
            end

            for _, change in ipairs(conversion_changes) do
                plan.changes[#plan.changes + 1] = change
            end
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
                if change.kind == "transform" then
                    print(string.format(
                        "[RuleWorld] Entity %d: %s -> %s",
                        change.entity_id,
                        change.from,
                        change.to
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

    print("[RuleWorld] M9.3C initialized")
end
