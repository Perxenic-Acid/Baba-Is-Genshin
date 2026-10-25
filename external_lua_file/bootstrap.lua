
-- bootstrap.lua
-- RuleWorld M1: Input and session coordination

function OnStart()
    local root = script.object

    if not root then
        printerr("[RuleWorld] Missing GameRoot")
        return
    end

    -- Discover scripts once.
    local scripts = {}

    for _, candidate in ipairs(root:GetScripts()) do
        local path = (candidate.path or ""):gsub("\\", "/")
        local name = path:match("([^/]+)$")

        scripts[name] = candidate
        print("[RuleWorld] Found script:", path)
    end

    local world_api = scripts["world"]
    local renderer_api = scripts["renderer"]

    if not world_api or not renderer_api then
        printerr("[RuleWorld] Required script missing")
        return
    end

    if not world_api.alive or not renderer_api.alive then
        printerr("[RuleWorld] Required script not alive")
        return
    end

    -- Run internal tests before starting.
    local passed, message =
        world_api:Invoke("RW_SelfTest")

    if not passed then
        printerr("[RuleWorld] M1 TEST FAILED:", message)
        return
    end

    print("[RuleWorld] M1 TEST PASSED:", message)

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

    -- One input -> one atomic world step.
    local function move(dx, dy)
        local action = {
            type = "move",
            entity_id = 1,
            dx = dx,
            dy = dy
        }

        local next_session, result =
            world_api:Invoke("RW_Step", session, action)

        if not next_session or not result then
            printerr("[RuleWorld] Transition failed")
            return
        end

        if not result.accepted then
            print(
                "[RuleWorld] Move rejected:",
                result.reason
            )
            return
        end

        session = next_session

        local change = result.changes[1]

        print(string.format(
            "[RuleWorld] Entity %d: (%d,%d) -> (%d,%d)",
            change.entity_id,
            change.from.x,
            change.from.y,
            change.to.x,
            change.to.y
        ))

        render()
    end

    local function undo()
        local next_session, result =
            world_api:Invoke("RW_Undo", session)

        if not next_session or not result then
            printerr("[RuleWorld] Undo call failed")
            return
        end

        if not result.accepted then
            print("[RuleWorld] Undo rejected:", result.reason)
            return
        end

        session = next_session

        local e = session.world.entities[1]

        print(string.format(
            "[RuleWorld] Undo -> (%d,%d), history=%d",
            e.x, e.y, #session.history
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

    bind(key.KeyboardMoveForwardKeyDown,   0, -1)
    bind(key.KeyboardMoveBackwardKeyDown,  0,  1)
    bind(key.KeyboardMoveLeftKeyDown,     -1,  0)
    bind(key.KeyboardMoveRightKeyDown,     1,  0)

    -- Craftsperson Key 12: default Z
    if key.KeyboardCraftspersonKey12Down then
        root:AddKeyEventListener(
            key.KeyboardCraftspersonKey12Down,
            function()
                undo()
                return true
            end
        )
        print("[RuleWorld] Undo input registered (Z)")
    else
        printerr("[RuleWorld] Undo key unavailable")
    end

    render()
    print("[RuleWorld] M1 initialized")
end
