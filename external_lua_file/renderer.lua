-- renderer.lua
-- Miliastra UI renderer.

function RW_Render(world, history_depth)
    local root = script.object
    if not root then
        printerr("[RuleWorld] Renderer has no host")
        return false
    end

    local status = root:GetChild("StatusText")
    if not status then
        printerr("[RuleWorld] Missing StatusText")
        return false
    end

    local lines = {
        "RuleWorld M1",
        "History: " .. tostring(history_depth or 0)
    }

    for y = 1, world.height do
        local row = {}

        for x = 1, world.width do
            local count = 0

            for _, entity in pairs(world.entities) do
                if entity.x == x and entity.y == y then
                    count = count + 1
                end
            end

            row[#row + 1] =
                count == 0 and "." or tostring(count)
        end

        lines[#lines + 1] = table.concat(row, "  ")
    end

    local e = world.entities[1]

    lines[#lines + 1] = string.format(
        "Entity #1: (%d, %d)", e.x, e.y
    )

    lines[#lines + 1] = "WASD: Move | Z: Undo"

    status.text = table.concat(lines, "\n")
    return true
end
