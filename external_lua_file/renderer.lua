-- renderer.lua
-- RuleWorld M8: Native grid UI renderer

-- Replace 0 with the actual client control template index.
local TILE_TEMPLATE_INDEX = 1073741851

local CELL_STEP = 68
local CELL_SIZE = 64
local board_scale = 1

local board_root = nil
local status_text = nil

local cells = {}
local views = {}
local board_width = 0
local board_height = 0
local last_error = nil
local board_dx, board_dy = 0, 0
local choice_controls = {}

-- Stable colours and cached writes avoid native calls for unchanged controls.
local palette={}
local function cached_color(r,g,b,a)
    local key=r..":"..g..":"..b..":"..a
    if not palette[key] then palette[key]=Color(r,g,b,a) end
    return palette[key]
end
local control_state=setmetatable({},{__mode="k"})
local function state(control)
    if not control_state[control] then control_state[control]={} end
    return control_state[control]
end
local function paint(control,key,value)
    local previous=state(control)
    if previous[key]~=value then control[key]=value;previous[key]=value end
end
local function set_position(control,x,y)
    local previous=state(control)
    if previous.x~=x or previous.y~=y then control:SetAnchoredPosition(x,y);previous.x=x;previous.y=y end
end
local function set_size(control,w,h)
    local previous=state(control)
    if previous.w~=w or previous.h~=h then control:SetSizeDelta(w,h);previous.w=w;previous.h=h end
end
local function set_visible(control,visible)
    local previous=state(control)
    if previous.visible~=visible then control:SetVisible(visible);previous.visible=visible end
end

local function report_error(message)
    if last_error ~= message then
        printerr("[RuleWorld M8] " .. message)
        last_error = message
    end
end

-- Convert world grid coordinates into local UI positions.
local function grid_position(x, y, width, height)
    return
        (x - (width + 1) / 2) * CELL_STEP,
        ((height + 1) / 2 - y) * CELL_STEP
end

local function display_position(x,y,width,height)
    local px,py = grid_position(x,y,width,height)
    return px+board_dx*CELL_STEP,py-board_dy*CELL_STEP
end

local function configure_control(control)
    control:SetAnchorMin(0.5, 0.5)
    control:SetAnchorMax(0.5, 0.5)
    control:SetPivot(0.5, 0.5)

    -- These enum names are supported by the 7.x client API.
    if Enum.TextHorizontalAlignment
        and Enum.TextHorizontalAlignment.Middle then
        control.horizontalAlignment =
            Enum.TextHorizontalAlignment.Middle
    end

    if Enum.TextVerticalAlignment
        and Enum.TextVerticalAlignment.Middle then
        control.verticalAlignment =
            Enum.TextVerticalAlignment.Middle
    end

    control.adaptiveFontSize = false
    control:SetActive(true)
    set_visible(control,true)
end

local function instantiate(parent)
    local control = game.InstantiateClientUIControl(
        TILE_TEMPLATE_INDEX,
        parent
    )

    if not control then
        return nil
    end

    configure_control(control)
    return control
end

local function ensure_host()
    if board_root and board_root.alive then
        return true
    end

    local root = script.object

    if not root then
        report_error("Missing script host")
        return false
    end

    status_text = root:GetChild("StatusText")
    board_root = root:GetChild("BoardRoot")

    if not board_root then
        report_error("Missing BoardRoot")
        if status_text then
            status_text.text = "M8: Missing BoardRoot"
        end
        return false
    end

    if TILE_TEMPLATE_INDEX == 0 then
        report_error("Set TILE_TEMPLATE_INDEX first")
        if status_text then
            status_text.text = "M8: Configure tile template index"
        end
        return false
    end

    return true
end

local function destroy_cells()
    for _, control in ipairs(cells) do
        if control and control.alive then
            game.DestroyClientUIControl(control)
        end
    end

    cells = {}
end

local function ensure_grid(world)
    if board_width == world.width
        and board_height == world.height
        and #cells == world.width * world.height then
        return true
    end

    for id, control in pairs(views) do
        if control and control.alive then
            game.DestroyClientUIControl(control)
        end
    end
    views = {}


    destroy_cells()

    local created = {}

    for y = 1, world.height do
        for x = 1, world.width do
            local control = instantiate(board_root)

            if not control then
                for _, item in ipairs(created) do
                    if item.alive then
                        game.DestroyClientUIControl(item)
                    end
                end

                report_error(
                    "Cannot instantiate tile template "
                    .. tostring(TILE_TEMPLATE_INDEX)
                )
                return false
            end

            local px, py = display_position(
                x, y, world.width, world.height
            )

            control.name =
                string.format("RW_Cell_%d_%d", x, y)

            set_position(control,px, py)
            set_size(control,CELL_SIZE, CELL_SIZE)

            control.text = ""
            control.bgColor = cached_color(43, 55, 75, 255)

            created[#created + 1] = control
        end
    end

    cells = created
    board_width = world.width
    board_height = world.height

    print(string.format(
        "[RuleWorld M8] Grid created: %dx%d, cells=%d",
        board_width, board_height, #cells
    ))

    return true
end

local function get_label(entity)
    if entity.class == "text" then return entity.text and entity.text.name or "?" end
    if entity.level_link then
        local label = entity.level_link.label or "LEVEL"
        if entity.level_link.source_type and entity.archetype ~= entity.level_link.source_type then
            return label .. ":" .. tostring(entity.archetype)
        end
        return label
    end
    if entity.archetype == "level_block" then return "LEVEL?" end
    if entity.archetype == "cursor" then return "SEL" end
    if entity.archetype == "line" then return "." end
    if entity.archetype == "flag" then return "FLAG" end
    if entity.archetype == "skull" then return "SKULL" end
    if entity.archetype == "water" then return "WATER" end
    if entity.archetype == "belt" then
        return ({Left="<",Up="^",Right=">",Down="v"})[entity.direction] or "BELT"
    end
    if entity.archetype == "rock" then return "ROCK" end
    if entity.archetype == "wall" then return "WALL" end
    if entity.archetype == "crate" then return "CRATE" end
    if entity.class == "text" then
        return entity.text and entity.text.name or "?"
    end

    if entity.archetype == "avatar" then
        return "★"
    end

    return tostring(entity.id)
end

local function get_colors(entity,active)
    if entity.class == "text" then
        if active then return cached_color(205,159,89,255),cached_color(36,26,15,255) end
        return cached_color(82,68,49,255),cached_color(156,133,99,255)
    end
    local capabilities = entity.behaviors or {}
    if capabilities.defeat then return cached_color(170,65,80,255),cached_color(255,255,255,255) end
    if capabilities.sink then return cached_color(45,130,185,255),cached_color(255,255,255,255) end
    if capabilities.win then return cached_color(238,206,88,255), cached_color(30,24,10,255) end
    if capabilities.select then return cached_color(220,220,230,255), cached_color(20,20,30,255) end
    if capabilities.word then return cached_color(112,90,170,255), cached_color(255,255,255,255) end
    if capabilities.shift then return cached_color(65,125,125,255),cached_color(255,255,255,255) end
    if entity.level_link then
        return cached_color(112,70,145,255), cached_color(255,255,255,255)
    end
    if entity.archetype == "cursor" then return cached_color(220,220,230,255), cached_color(20,20,30,255) end
    if entity.archetype == "line" then return cached_color(43,55,75,255), cached_color(90,110,140,255) end

    if entity.archetype == "avatar" then
        return
            cached_color(77, 107, 195, 255),
            cached_color(255, 255, 255, 255)
    end

    if entity.archetype == "crate" then
        return
            cached_color(71, 119, 108, 255),
            cached_color(255, 255, 255, 255)
    end

    if entity.traits and entity.traits.block_entry then
        return
            cached_color(139, 81, 85, 255),
            cached_color(255, 255, 255, 255)
    end

    return
        cached_color(90, 104, 130, 255),
        cached_color(255, 255, 255, 255)
end

local function ensure_view(id)
    local control = views[id]

    if control and control.alive then
        return control
    end

    control = instantiate(board_root)

    if not control then
        report_error(
            "Cannot instantiate view for entity "
            .. tostring(id)
        )
        return nil
    end

    control.name = "RW_Entity_" .. tostring(id)

    views[id] = control
    return control
end

-- Native implicit wrapping clips long words on scaled boards. Supply explicit
-- line breaks and an integer font that fits the available width AND height.
function RW_FitTileLabel(label,width,height,font)
    if not label:match("^[%w_?:%-]+$") then return label,font end
    local columns=1
    for size=font,4,-1 do
        columns=math.max(1,math.floor((width-1)/(size*0.65)))
        local lines=math.ceil(#label/columns)
        if lines*size*1.35<=height then
            local pieces={}
            for i=1,#label,columns do pieces[#pieces+1]=label:sub(i,i+columns-1) end
            return table.concat(pieces,"\n"),math.floor(size)
        end
    end
    return label,4
end

local function draw_entities(world)
    local occupancy = {}
    local visible_ids = {}

    -- Group the actual world entities by their positions.
    for id, entity in pairs(world.entities) do
        if not (entity.behaviors and entity.behaviors.hide) and entity.x >= 1 and entity.x <= world.width
            and entity.y >= 1 and entity.y <= world.height then
            local slot_index =
                (entity.y - 1) * world.width + entity.x

            local slot = occupancy[slot_index]

            if not slot then
                slot = {}
                occupancy[slot_index] = slot
            end

            if entity.archetype ~= "path" then slot[#slot + 1] = {
                id = id,
                entity = entity
            } end
        end
    end

    -- Stable order for overlapping entities.
    for _, slot in pairs(occupancy) do
        table.sort(slot, function(a, b)
            return a.id < b.id
        end)
    end

    for y = 1, world.height do
        for x = 1, world.width do
            local slot_index =
                (y - 1) * world.width + x

            local slot = occupancy[slot_index] or {}
            local count = #slot

            if count > 0 then
                local cx, cy = display_position(
                    x, y, world.width, world.height
                )

                local span = (CELL_SIZE - 4*board_scale) / count
                local tile_width = math.max(5, span - 2*board_scale)

                for i, item in ipairs(slot) do
                    local control = ensure_view(item.id)

                    if control then
                        local entity = item.entity
                        local label = get_label(entity)
                        local bg, fg = get_colors(entity,world.active_text_ids and world.active_text_ids[item.id])

                        if count > 1 and #label > 2 then
                            label = label:sub(1, 1)
                            if entity.level_link and entity.level_link.source_type
                                and entity.archetype ~= entity.level_link.source_type then label = label .. "*" end
                        end

                        local font_size = 18

                        if count >= 3 then
                            font_size = 12
                        elseif count == 2 then
                            font_size = 14
                        elseif #label >= 5 then
                            font_size = 14
                        end

                        local offset_x =
                            (i - (count + 1) / 2) * span

                        set_position(control,
                            cx + offset_x, cy
                        )

                        set_size(control,
                            tile_width,
                            CELL_SIZE - 6*board_scale
                        )

                        local fitted_font=math.max(7,math.floor(font_size*board_scale+0.5))
                        if entity.class=="text" then label,fitted_font=RW_FitTileLabel(label,tile_width,CELL_SIZE-6*board_scale,fitted_font) end
                        paint(control,"text",label)
                        paint(control,"fontSize",fitted_font)
                        paint(control,"fontColor",fg)
                        paint(control,"bgColor",bg)
                        set_visible(control,true)

                        visible_ids[item.id] = true
                    end
                end
            end
        end
    end

    -- Reuse views; hide those not present in the world.
    for id, control in pairs(views) do
        if control.alive and not visible_ids[id] then
            set_visible(control,false)
        end
    end
end

local function choose_level(entity_id)
    for _, candidate in ipairs(script.object:GetScripts()) do
        local name = (candidate.path or ""):gsub("\\","/"):match("([^/]+)$")
        if name == "bootstrap" then candidate:Invoke("RW_ChooseSelectedLevel",entity_id); return end
    end
end

local function draw_level_choice(choice)
    for _, control in ipairs(choice_controls) do
        if control.alive then game.DestroyClientUIControl(control) end
    end
    choice_controls = {}
    if not choice then return end
    local first = math.floor((choice.index-1)/8)*8+1
    local last = math.min(#choice.items,first+7)
    local height = (last-first+3)*48
    local function panel(name,text,y,width,h,selected,id)
        local control = instantiate(board_root)
        if not control then report_error("Cannot instantiate level choice"); return end
        choice_controls[#choice_controls+1] = control
        control.name = name
        set_position(control,0,y)
        set_size(control,width,h)
        control.text = text
        control.fontSize = 18
        control.fontColor = cached_color(255,255,255,255)
        control.bgColor = selected and cached_color(90,80,155,255) or cached_color(24,30,48,255)
        if id and type(control.AddCursorEventListener) == "function"
            and Enum.CursorEventType and Enum.CursorEventType.CursorClick then
            control:AddCursorEventListener(Enum.CursorEventType.CursorClick,function() choose_level(id); return true end)
        end
    end
    panel("RW_ChoiceBackground","",0,640,height,false)
    panel("RW_ChoiceTitle","Choose level: W/S + F",height/2-24,620,44,false)
    for index=first,last do
        local item = choice.items[index]
        panel("RW_Choice_" .. tostring(item.entity_id),
            (index == choice.index and "> " or "  ") .. item.label .. (item.available and "" or " (unavailable)"),
            height/2-24-(index-first+1)*48,620,44,index == choice.index,item.entity_id)
    end
    panel("RW_ChoiceCancel",choice.error or "Z: Cancel",-height/2+24,620,44,false,0)
end

function RW_Render(world, history_depth, active_effects, navigation)
    if not ensure_host() then
        return false
    end

    board_scale=math.min(1,12/world.width,12/world.height)
    CELL_STEP=68*board_scale;CELL_SIZE=64*board_scale
    board_dx = world.board_offset and world.board_offset.x or 0
    board_dy = world.board_offset and world.board_offset.y or 0
    if not ensure_grid(world) then
        return false
    end

    local annotations={}
    for _,entity in pairs(world.entities) do
        if entity.archetype=="line" and not (entity.behaviors and entity.behaviors.hide) then annotations[(entity.y-1)*world.width+entity.x]={text="."} end
    end
    for _,portal in ipairs(navigation and navigation.portals or {}) do
        annotations[(portal.y-1)*world.width+portal.x]={text=portal.label,portal=true}
    end
    for index,cell in ipairs(cells) do
        local x,y=(index-1)%world.width+1,math.floor((index-1)/world.width)+1
        set_position(cell,display_position(x,y,world.width,world.height))
        local text,font,bg,fg="",18,cached_color(43,55,75,255),cached_color(90,110,140,255)
        local empty=world.empty_cells and world.empty_cells[x..":"..y]
        if empty and not empty.behaviors.hide then
            text="E";font=12;fg=cached_color(130,150,175,255)
            if empty.behaviors.control then bg=cached_color(75,100,125,255) end
            if empty.behaviors.block_entry then bg=cached_color(65,65,85,255) end
        end
        local annotation=annotations[index]
        if annotation then
            text=annotation.text;font=18;fg=cached_color(90,110,140,255)
            if annotation.portal then bg=cached_color(112,70,145,255);fg=cached_color(255,255,255,255) end
        end
        paint(cell,"text",text);paint(cell,"fontSize",font);paint(cell,"fontColor",fg);paint(cell,"bgColor",bg)
    end
    draw_entities(world)
    draw_level_choice(navigation and navigation.choice)

    if status_text then
        status_text.text = string.format(
            (navigation and navigation.title or "RuleWorld") .. "\n" ..
            (navigation and "Undo steps: %d    Active effects: %d\n" or "Turns: %d    Active effects: %d\n") ..
            "%s",
            history_depth or 0,
            active_effects or 0,
            navigation and navigation.hint or "WASD: Move    Z: Undo"
        )
    end

    return true
end

function RW_RendererSelfTest()
    local x, y = grid_position(1, 1, 7, 6)

    if x ~= -204 or y ~= 170 then
        return false, "Grid coordinate conversion failed"
    end

    return true, "Grid geometry passed"
end
