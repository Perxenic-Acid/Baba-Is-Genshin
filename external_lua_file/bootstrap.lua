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

    local session =
        world_api:Invoke("RW_CreateSession")

    if not session then
        printerr("[RuleWorld] Session creation failed")
        return
    end

    -- World -> spatial lines -> generated IR
    -- -> active effects.
    local function evaluate()
        local lines, read_error =
            reader_api:Invoke(
                "RW_ReadLines",
                session.world
            )

        if not lines then
            printerr(
                "[RuleWorld] Reader failed:",
                read_error
            )
            return nil
        end

        local generated, grammar_error =
            grammar_api:Invoke(
                "RW_CompileRules",
                lines,
                session.world.language
            )

        if not generated then
            printerr(
                "[RuleWorld] Grammar failed:",
                grammar_error
            )
            return nil
        end

        local effects, rule_error =
            rules_api:Invoke(
                "RW_EvaluateRules",
                session.world,
                generated
            )

        if not effects then
            printerr(
                "[RuleWorld] Rule evaluation failed:",
                rule_error
            )
            return nil
        end

        return effects, #generated
    end

    local previous_rule_count = nil

    local function render()
        local effects, rule_count = evaluate()
        if not effects then return end

        if previous_rule_count ~= rule_count then
            print(string.format(
                "[RuleWorld] Spatial rules: %d, effects: %d",
                rule_count,
                #effects
            ))

            previous_rule_count = rule_count
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

        -- Commit against the authoritative state.
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
                print(string.format(
                    "[RuleWorld] Entity %d: (%d,%d) -> (%d,%d)",
                    change.entity_id,
                    change.from.x,
                    change.from.y,
                    change.to.x,
                    change.to.y
                ))
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

    print("[RuleWorld] M9.2 initialized")
end
