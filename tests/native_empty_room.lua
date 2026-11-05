-- Run from repository root: luatex --luaonly tests/native_empty_room.lua
-- Core Lua tests plus real bootstrap pipelines with only host UI/input mocked.
local modules = {"world", "reader", "grammar", "rules", "properties", "movement", "renderer"}
local scripts, listeners = {}, {}
local self_test_calls=0
for _, name in ipairs(modules) do
    dofile("external_lua_file/" .. name .. ".lua")
    scripts[#scripts + 1] = {path = name, alive = true,
        Invoke = function(_, method, ...)
            if method:find("SelfTest") then self_test_calls=self_test_calls+1 end
            return assert(_G[method], method)(...)
        end}
end
local rendered, history_depth, navigation
RW_Render = function(world, depth, _, context)
    rendered, history_depth, navigation = world, depth, context
end
printerr = function(...) error(table.concat({...}, " ")) end
local keys = {
    KeyboardMoveForwardKeyDown = "up", KeyboardMoveBackwardKeyDown = "down",
    KeyboardMoveLeftKeyDown = "left", KeyboardMoveRightKeyDown = "right",
    KeyboardCraftspersonKey12Down = "undo", KeyboardInteractKeyDown = "confirm", KeyboardJumpKeyDown="wait"
}
Enum = {KeyEventType = keys}
script = {object = {
    GetScripts = function() return scripts end,
    AddKeyEventListener = function(_, key, callback) listeners[key] = callback end
}}
dofile("external_lua_file/bootstrap.lua")
-- Native Lua has a watchdog; an unboundedly expensive startup can pass semantic
-- tests yet fail before the board appears. Keep instruction work bounded too.
local startup_instructions=0
debug.sethook(function()
    startup_instructions=startup_instructions+1000
    if startup_instructions > 2000000 then error("Production startup exceeded Lua instruction budget") end
end,"",1000)
OnStart()
debug.sethook()
print("Normal startup Lua instructions: " .. startup_instructions)
assert(self_test_calls == 0, "Production startup invoked regression self-tests")
assert(rendered and history_depth == 0 and rendered.entities[12].x == 2)
for _,key in ipairs({'right','right','right','right','right','right','right','right','right','right','confirm','right','right','right','right','right','right','right','right','confirm'}) do listeners[key]() end
-- Native renderer adapter exercised with fake controls, including same-size switches.
local old_game, old_script, old_color, old_render = game, script, Color, RW_Render
local controls = {}
local calls={position=0,size=0,font=0,visible=0}
local minimum_font=12
local board, status = {alive=true}, {alive=true}
local methods = setmetatable({}, {__index=function() return function() end end})
methods.SetAnchoredPosition = function(control,x,y) calls.position=calls.position+1;control.px,control.py=x,y end
methods.SetSizeDelta = function(control,w,h) calls.size=calls.size+1;control.width,control.height=w,h end
methods.SetVisible=function(control,value) calls.visible=calls.visible+1;control.visible=value end
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
                    assert(value>=minimum_font and value<=72,"native fontSize outside supported test range")
                    c.properties.fontSize=value
                else rawset(c,key,value) end
            end})
        controls[#controls+1] = control
        return control
    end,
    DestroyClientUIControl=function(control) control.alive=false end
}
dofile("external_lua_file/renderer.lua")
local capture=old_render;local native_render=RW_Render;RW_Render=function(...) capture(...);assert(native_render(...)) end

local count=0
debug.sethook(function() count=count+1000 end,'',1000)
listeners.right()
debug.sethook()
assert(count<5000000,'EMPTY input plus native renderer budget: '..count)
local function avatar_view()
 for _,c in ipairs(controls) do if c.alive and c.name then
  local id=tonumber(c.name:match('^RW_Entity_(%d+)$'))
  if id and rendered.entities[id] and rendered.entities[id].archetype=='avatar' then return c end
 end end
end
local v=assert(avatar_view());local x=v.px
listeners.right();assert(avatar_view().px~=x,'movement did not update the native avatar control')
listeners.undo();assert(avatar_view().px==x,'Undo did not restore the native avatar control')
for i=1,4 do listeners.right();assert(avatar_view().px~=x);listeners.undo();assert(avatar_view().px==x) end
print('PASS: EMPTY production input plus actual renderer, repeated movement/Undo; instructions='..count)

