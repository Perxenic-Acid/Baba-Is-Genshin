
-- bootstrap.lua
-- RuleWorld M2: Input and module coordination

function OnStart()
    local root = script.object

    if not root then
        printerr("[RuleWorld] Missing GameRoot")
        return
    end

    local scripts = {}

    for _, candidate in ipairs(root:GetScripts()) do
        local path =
            (candidate.path or ""):gsub("\\", "/")

        local name = path:match("([^/]+)$")

        scripts[name] = candidate
        print("[RuleWorld] Found script:", path)
    end

    local world_api = scripts["world"]
    local movement_api = scripts["movement"]
    local renderer_api = scripts["renderer"]

    if not world_api or not movement_api
        or not renderer_api then
        printerr("[RuleWorld] Required script missing")
        return
    end

    for _, api in ipairs({
        world_api, movement_api, renderer_api
    }) do
        if not api.alive then
            printerr("[RuleWorld] Script not alive")
            return
        end
    end

    local wp, wm =
        world_api:Invoke("RW_SelfTest")

    local mp, mm =
        movement_api:Invoke("RW_MovementSelfTest")

    if not wp or not mp then
        printerr("[RuleWorld] M2 TEST FAILED:",
            not wp and wm or mm)
        return
    end

    print("[RuleWorld] M2 TEST PASSED:",
        wm, mm)

    local session =
        world_api:Invoke("RW_CreateSession")

    if not session then
        printerr("[RuleWorld] Session creation failed")
        return
    end

    local function render()
        renderer_api:Invoke(
            "RW_Render",
            session.world,
            #session.history
        )
    end

    local function move(dx, dy)
        local action = {
            type = "move",
            entity_id = 1,
            dx = dx,
            dy = dy
        }

        -- Phase 1: Resolve intention and constraints.
        local plan = movement_api:Invoke(
            "RW_ResolveMovement",
            session.world,
            action
        )

        if not plan then
            printerr("[RuleWorld] Resolver failed")
            return
        end

        -- Phase 2: Atomically commit the plan.
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
            print("[RuleWorld] Invalid action:",
                result.reason)
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
            print("[RuleWorld] Turn consumed:",
                result.reason or "no_change")
        end

        render()
    end

    local function undo()
        local next_session, result =
            world_api:Invoke("RW_Undo", session)

        if not next_session or not result then
            printerr("[RuleWorld] Undo failed")
            return
        end

        if not result.accepted then
            print("[RuleWorld] Undo rejected:",
                result.reason)
            return
        end

        session = next_session

        local entity = session.world.entities[1]

        print(string.format(
            "[RuleWorld] Undo -> (%d,%d), history=%d",
            entity.x,
            entity.y,
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

    bind(key.KeyboardMoveForwardKeyDown,  0, -1)
    bind(key.KeyboardMoveBackwardKeyDown, 0,  1)
    bind(key.KeyboardMoveLeftKeyDown,    -1,  0)
    bind(key.KeyboardMoveRightKeyDown,    1,  0)

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

    print("[RuleWorld] M2 initialized")
end
