
-- renderer.lua
-- RuleWorld M7: Text-based board renderer

local function cell_label(world, x, y)
    local count = 0
    local first_id = nil
    local text_id = nil
    local text_token = nil

    for id, entity in pairs(world.entities) do
        if entity.x == x and entity.y == y then
            count = count + 1

            if first_id == nil or id < first_id then
                first_id = id
            end

            if entity.symbol
                and (text_id == nil or id < text_id) then
                text_id = id
                text_token = entity.symbol.token
            end
        end
    end

    local label = "."

    if text_token then
        label = text_token
    elseif first_id then
        label = "#" .. tostring(first_id)
    end

    if count > 1 then
        label = label:sub(1, 4) .. "+"
    end

    return string.format("%-5s", label:sub(1, 5))
end

function RW_Render(world, history_depth, active_effects)
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
        "RuleWorld M7",
        "History: " .. tostring(history_depth or 0),
        "Active effects: " .. tostring(active_effects or 0),
        ""
    }

    for y = 1, world.height do
        local row = {}

        for x = 1, world.width do
            row[#row + 1] =
                cell_label(world, x, y)
        end

        lines[#lines + 1] = table.concat(row, " ")
    end

    local player = world.entities[1]

    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format(
        "Entity #1: (%d, %d)",
        player.x, player.y
    )

    lines[#lines + 1] = "WASD: Move | Z: Undo"

    status.text = table.concat(lines, "\n")
    return true
end
