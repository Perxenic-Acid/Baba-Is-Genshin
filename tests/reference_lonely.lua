dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('lonely = function',1,true));local b=assert(source:find('powered = function',a,true))
local env=setmetatable({roomsizex=8},{__index=_G})
local original=assert(load('return {'..source:sub(a,b-1)..'}','@original_lonely','t',env))().lonely
local count=0
for _,empty in ipairs({false,true}) do for overlap=0,4 do for _,negated in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.entities={}
 local e={id=empty and -1 or 10,class=empty and 'empty' or 'object',archetype='avatar',x=3,y=3}
 local uid=empty and 2 or 10;env.unitmap={[27]={}}
 if not empty then w.entities[10]=e;table.insert(env.unitmap[27],10) end
 for i=1,overlap do
  w.entities[10+i]={id=10+i,class=i%2==0 and 'text' or 'object',x=3,y=3,behaviors={hide=true,float=true}}
  table.insert(env.unitmap[27],10+i)
 end
 local expected=original({}, {}, {}, {unitid=uid,x=3,y=3})
 if negated then expected=not expected end
 local actual=assert(type(RW_TestEntityCondition)=='function') and RW_TestEntityCondition(w,{op='spatial',clauses={{relation='lonely',negated=negated,parameters={}}}},e)
 assert(actual==expected,'lonely oracle mismatch');count=count+1
end end end
print('PASS: installed LONELY identity/virtual EMPTY/stacked Text/NOT ('..count..' cases)')
