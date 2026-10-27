-- Native renderer adapter exercised with fake controls, including same-size switches.
local old_game, old_script, old_color, old_render = game, script, Color, RW_Render
local controls = {}
local board, status = {alive=true}, {alive=true}
local methods = setmetatable({}, {__index=function() return function() end end})
Color = function(r,g,b,a) return {r,g,b,a} end
script = {object={GetChild=function(_,name)
    if name == "BoardRoot" then return board end
    if name == "StatusText" then return status end
end}}
game = {
    InstantiateClientUIControl=function()
        local control = setmetatable({alive=true}, {__index=methods})
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
game, script, Color, RW_Render = old_game, old_script, old_color, old_render
print("PASS: native renderer portal labels, status and same-size instance refresh")
