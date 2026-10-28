-- Native renderer adapter exercised with fake controls, including same-size switches.
local old_game, old_script, old_color, old_render = game, script, Color, RW_Render
local controls = {}
local calls={position=0,size=0,font=0,visible=0}
local board, status = {alive=true}, {alive=true}
local methods = setmetatable({}, {__index=function() return function() end end})
methods.SetAnchoredPosition = function(control,x,y) calls.position=calls.position+1;control.px,control.py=x,y end
methods.SetSizeDelta = function(control,w,h) calls.size=calls.size+1;control.width,control.height=w,h end
methods.SetVisible=function() calls.visible=calls.visible+1 end
methods.AddCursorEventListener = function(control,event,callback) control.click=callback end
local old_cursor_events = Enum.CursorEventType
Enum.CursorEventType = {CursorClick="click"}
local chosen
Color = function(r,g,b,a) return {r,g,b,a} end
script = {object={GetScripts=function() return {{path="bootstrap",Invoke=function(_,name,id) chosen=id; return true end}} end,GetChild=function(_,name)
    if name == "BoardRoot" then return board end
    if name == "StatusText" then return status end
end}}
game = {
    InstantiateClientUIControl=function()
        local control = setmetatable({alive=true,properties={}}, {
            __index=function(c,key)
                if key=="fontSize" then return c.properties.fontSize end
                return methods[key]
            end,
            __newindex=function(c,key,value)
                if key=="fontSize" then
                    calls.font=calls.font+1
                    assert(math.type(value)=="integer","native fontSize requires a Lua integer")
                    c.properties.fontSize=value
                else rawset(c,key,value) end
            end})
        controls[#controls+1] = control
        return control
    end,
    DestroyClientUIControl=function(control) control.alive=false end
}
dofile("external_lua_file/renderer.lua")
local world = {width=2,height=2,entities={}}
assert(RW_Render(world,0,0,{title="MAP",portals={{x=2,y=1,label="A"}}}))
assert(controls[2].text == "A" and status.text:find("MAP"))
assert(RW_Render(world,3,0,{title="PUZZLE",portals={{x=1,y=2,label="OUT"}}}))
assert(#controls == 4 and controls[2].text == "" and controls[3].text == "OUT")
assert(controls[2].bgColor[1] == 43 and status.text:find("PUZZLE"))
assert(RW_Render(world,0,0))
assert(controls[3].text == "" and status.text:find("RuleWorld"))
local typed = {width=2,height=2,entities={
    [1]={id=1,kind="object",class="object",archetype="flag",x=1,y=1,behaviors={}},
    [2]={id=2,kind="object",class="object",archetype="rock",x=2,y=1,behaviors={win=true}},
    [3]={id=3,kind="object",class="object",archetype="level_block",x=1,y=2,behaviors={}},
    [4]={id=4,kind="object",class="object",archetype="crate",x=2,y=2,behaviors={},
        level_link={source_type="level_block",target="parent",label="A"}}
}}
assert(RW_Render(typed,0,1))
local views = {}
for _, control in ipairs(controls) do if control.name then views[control.name] = control end end
assert(views.RW_Entity_1.text == "FLAG" and views.RW_Entity_1.bgColor[1] ~= 238)
assert(views.RW_Entity_2.bgColor[1] == 238)
assert(views.RW_Entity_3.text == "LEVEL?" and views.RW_Entity_4.text == "A:crate")
typed.entities[5]={id=5,kind="object",class="object",archetype="skull",x=1,y=1,behaviors={defeat=true}}
typed.entities[6]={id=6,kind="object",class="object",archetype="water",x=2,y=2,behaviors={sink=true}}
assert(RW_Render(typed,0,1))
for _, control in ipairs(controls) do if control.name then views[control.name] = control end end
assert(views.RW_Entity_5.text == "S" and views.RW_Entity_5.bgColor[1] == 170)
assert(views.RW_Entity_6.text == "W" and views.RW_Entity_6.bgColor[3] == 185)
local before_x,before_y = views.RW_Entity_1.px,views.RW_Entity_1.py
local cell_x,cell_y = controls[1].px,controls[1].py
typed.board_offset = {x=1,y=2,direction="Right"}
assert(RW_Render(typed,0,1,{choice={index=1,items={
    {entity_id=43,label="YOU",available=true},{entity_id=44,label="P",available=true}}}}))
assert(views.RW_Entity_1.px == before_x+68 and views.RW_Entity_1.py == before_y-136)
assert(controls[1].px == cell_x+68 and controls[1].py == cell_y-136)
local rows = {}
for _, control in ipairs(controls) do if control.name then rows[control.name]=control end end
assert(rows.RW_Choice_44 and rows.RW_Choice_44.click)
rows.RW_Choice_44.click()
assert(chosen == 44)
rows.RW_ChoiceCancel.click()
assert(chosen == 0)
-- The native control may have no cursor-listener method: W/S/F remains usable.
local mouse_listener=methods.AddCursorEventListener
methods.AddCursorEventListener=false
assert(RW_Render(typed,0,1,{choice={index=1,items={{entity_id=44,label="P",available=true}}}}))
local keyboard_row
for _,control in ipairs(controls) do
    if control.alive and control.name == "RW_Choice_44" then keyboard_row=control end
end
assert(keyboard_row and rawget(keyboard_row,"click") == nil)
methods.AddCursorEventListener=mouse_listener
assert(RW_RendererSelfTest())
assert(RW_Render(typed,0,1))
assert(not rows.RW_Choice_44.alive)
local conveyor={width=2,height=2,entities={
 [1]={id=1,kind="object",class="object",archetype="belt",x=1,y=1,direction="Up",behaviors={shift=true}}
}}
assert(RW_Render(conveyor,0,0))
local belt_view
for _,c in ipairs(controls) do if c.alive and c.name=="RW_Entity_1" then belt_view=c end end
assert(belt_view.text=="^" and belt_view.bgColor[1]==65)
conveyor.entities[1].direction="Right";assert(RW_Render(conveyor,0,0));assert(belt_view.text==">")
local words={width=5,height=2,active_text_ids={[1]=true},entities={
 [1]={id=1,kind="object",class="text",text={name="IS"},x=2,y=1,behaviors={}},
 [2]={id=2,kind="object",class="text",text={name="WIN"},x=4,y=1,behaviors={win=true,defeat=true}}
}}
assert(RW_Render(words,0,0))
local tiles={};for _,c in ipairs(controls) do if c.alive and c.name then tiles[c.name]=c end end
local first,second=tiles.RW_Entity_1,tiles.RW_Entity_2
assert(first.bgColor[1]==205 and second.bgColor[1]==82)
assert(second.fontColor[1]==156) -- Text palette overrides object WIN/DEFEAT palettes.
words.active_text_ids={[2]=true};assert(RW_Render(words,0,0))
assert(first.bgColor[1]==82 and second.bgColor[1]==205)
words.width=33;words.height=18;assert(RW_Render(words,0,0))
local scaled
for _,c in ipairs(controls) do if c.alive and c.name=="RW_Entity_1" then scaled=c end end
assert(scaled.width<24 and scaled.height<24 and scaled.fontSize>=7)
assert(math.type(scaled.fontSize)=="integer")
assert(not pcall(function() scaled.fontSize=7.5 end),"mock must reject native-invalid fractional font sizes")
-- Check the 24-wide AUTO/WHERE scale as well as the 33-wide BIY scale.
words.width=24;assert(RW_Render(words,0,0))
for _,c in ipairs(controls) do if c.alive and c.name=="RW_Entity_1" then
 assert(c.fontSize==9 and math.type(c.fontSize)=="integer")
end end
words.width=33;assert(RW_Render(words,0,0))
for _,c in ipairs(controls) do if c.alive and c.name and c.name:find("RW_Cell_") then
 assert(math.abs(c.px)+c.width/2<=408 and math.abs(c.py)+c.height/2<=408)
end end
words.width=5;words.height=2;assert(RW_Render(words,0,0))
local restored
for _,c in ipairs(controls) do if c.alive and c.name=="RW_Entity_1" then restored=c end end
assert(restored.height==58 and restored.bgColor[1]==82)
local before={};for k,v in pairs(calls) do before[k]=v end
assert(RW_Render(words,0,0))
for k,v in pairs(calls) do assert(v==before[k],"unchanged frame repeated native "..k) end
words.entities[1].x=3;assert(RW_Render(words,0,0))
assert(calls.position==before.position+1 and calls.size==before.size and calls.font==before.font)
print("PASS: unchanged render makes zero repeated position/size/font/visibility calls; one moved entity updates one position")
print("PASS: native inactive/active Text colours, same-view refresh and large-board scaling/reset")
Enum.CursorEventType = old_cursor_events
game, script, Color, RW_Render = old_game, old_script, old_color, old_render
print("PASS: native renderer portal labels, status and same-size instance refresh")
