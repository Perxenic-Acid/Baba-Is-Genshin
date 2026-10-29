dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('idle = function',1,true));local b=assert(source:find('often = function',a,true))
local env=setmetatable({},{__index=_G})
local original=assert(load('return {'..source:sub(a,b-1)..'}','@original_idle','t',env))().idle
local count=0
for _,input in ipairs({'none','move','wait'}) do for _,negated in ipairs({false,true}) do
 for _,class in ipairs({'object','text','empty'}) do
  local w=RW_CreateSession().world;w.last_input=input
  env.last_key=input=='wait' and 4 or 0
  local expected=original({},{});if negated then expected=not expected end
  local actual=RW_TestEntityCondition(w,{op='spatial',clauses={{relation='idle',negated=negated,parameters={}}}},
   {id=100,class=class,x=1,y=1})
  assert(actual==expected);count=count+1
 end
end end
print('PASS: installed IDLE input/NOT/Object/Text/EMPTY ('..count..' cases)')
