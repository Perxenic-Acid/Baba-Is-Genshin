
-- reader.lua
-- RuleWorld M7: Spatial symbol reader

local function is_integer(n)
    return type(n) == "number"
        and n == n
        and n % 1 == 0
end

local function key(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

-- World -> ordered spatial lines
-- No knowledge of vocabulary or grammar.
function RW_ReadLines(world)
    if type(world) ~= "table"
        or type(world.entities) ~= "table"
        or not is_integer(world.width)
        or not is_integer(world.height)
        or world.width < 1
        or world.height < 1 then
        return nil, "invalid_world"
    end

    local positions = {}

    for id, entity in pairs(world.entities) do
        if entity.class == "text" then
            local text_data = entity.text

            if entity.kind ~= "object"
                or type(text_data) ~= "table"
                or type(text_data.name) ~= "string"
                or text_data.name == "" then
                return nil, "invalid_text"
            end

            if not is_integer(entity.x)
                or not is_integer(entity.y) then
                return nil, "invalid_text_position"
            end

            -- Only visible board coordinates are scanned.
            if entity.x >= 1
                and entity.x <= world.width
                and entity.y >= 1
                and entity.y <= world.height then

                local k = key(entity.x, entity.y)

                if not positions[k] then
                    positions[k] = {}
                end

                positions[k][#positions[k] + 1] = {
                    id = id,
                    token = text_data.name
                }
            end
        end
    end

    -- Stable order for stacked symbols.
    for _, slot in pairs(positions) do
        table.sort(slot, function(a, b)
            return a.id < b.id
        end)
    end

    local lines = {}

    -- Horizontal: left to right.
    for y = 1, world.height do
        local line = {
            axis = "horizontal",
            index = y,
            cells = {}
        }

        for x = 1, world.width do
            line.cells[x] = positions[key(x, y)] or {}
        end

        lines[#lines + 1] = line
    end

    -- Vertical: top to bottom.
    for x = 1, world.width do
        local line = {
            axis = "vertical",
            index = x,
            cells = {}
        }

        for y = 1, world.height do
            line.cells[y] = positions[key(x, y)] or {}
        end

        lines[#lines + 1] = line
    end

    return lines
end

function RW_ReaderSelfTest()
    local world = {
        width = 4,
        height = 4,
        entities = {
            [1] = {
                id = 1, x = 1, y = 2,
                kind = "object", class = "text", text = { name = "BOX" }
            },
            [2] = {
                id = 2, x = 2, y = 2,
                kind = "object", class = "text", text = { name = "LINK" }
            },
            [3] = {
                id = 3, x = 3, y = 2,
                kind = "object", class = "text", text = { name = "MOVE" }
            },
            [4] = {
                id = 4, x = 1, y = 2,
                kind = "object", class = "text", text = { name = "ALT" }
            },
            [5] = {
                id = 5, x = 1, y = 3,
                kind = "object", class = "text", text = { name = "LINK" }
            },
            [6] = {
                id = 6, x = 1, y = 4,
                kind = "object", class = "text", text = { name = "STOP" }
            }
        }
    }

    -- A non-Text object must not become a word merely
    -- because it happens to carry a similarly named field.
    world.entities[7] = {
        id = 7, kind = "object", class = "object",
        x = 4, y = 2, text = { name = "DECOY" }
    }

    local lines = RW_ReadLines(world)

    if not lines or #lines ~= 8
        or #lines[2].cells[4] ~= 0 then
        return false, "Line enumeration failed"
    end

    -- Row 2: two symbols stacked at (1,2).
    local horizontal = lines[2]

    if #horizontal.cells[1] ~= 2
        or horizontal.cells[1][1].token ~= "BOX"
        or horizontal.cells[1][2].token ~= "ALT"
        or horizontal.cells[2][1].token ~= "LINK"
        or horizontal.cells[3][1].token ~= "MOVE" then
        return false, "Horizontal reading failed"
    end

    -- Column 1 starts after four horizontal lines.
    local vertical = lines[5]

    if vertical.axis ~= "vertical"
        or vertical.cells[2][1].token ~= "BOX"
        or vertical.cells[3][1].token ~= "LINK"
        or vertical.cells[4][1].token ~= "STOP" then
        return false, "Vertical reading failed"
    end

    if world.entities[1].text.name ~= "BOX" then
        return false, "Reader mutated world"
    end

    -- Reject a Text instance with missing editor-provided name.
    local wrong = {
        width = 2, height = 2,
        entities = {
            [1] = { id = 1, kind = "object", class = "text",
                    x = 1, y = 1 }
        }
    }

    local invalid, err = RW_ReadLines(wrong)

    if invalid ~= nil or err ~= "invalid_text" then
        return false, "Invalid Text accepted"
    end

    return true, "Spatial reader passed"
end
