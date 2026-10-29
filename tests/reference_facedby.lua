-- Execute installed FACEDBY with default None-facing virtual Empty.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'));local source=f:read('*a');f:close()
local a=assert(source:find('facedby = function',1,true));local b=assert(source:find('seeing = function',a,true))
local env=setmetatable({},{__index=_G});local original=assert(load('return {'..source:sub(a,b-1)..'}','@original_facedby','t',env))().facedby
local dirs={'Right','Up','Left','Down','Mid','None'}
env.ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}};env.roomsizex=9;env.DIR=1;env.XPOS=2;env.YPOS=3
local units;env.mmf={newObject=function(id) return units[id] end};env.getname=function(u) return u.name end
env.emptydir=function() return 4 end;env.map={[0]={get_x=function() return 255 end}}
local function term(name)
    local neg=name:sub(1,4)=='not ';if neg then name=name:sub(5) end
    local t=(name=='text' or name=='empty') and {tag='special',name=name} or name=='level' and {tag='noun',type={tag='level'}} or {tag='noun',type={tag='object',name=name}}
    return neg and {tag='not',operand=t} or t
end
local paramslist={{'rock'},{'not rock'},{'text'},{'not text'},{'empty'},{'not empty'},{'level'},{'level','level'},{'rock','rock'},{'not rock','rock'},{'rock','flag'},{'not rock','not rock'}}
local positions={{1,0},{0,-1},{-1,0},{0,1},{0,0},{1,1},{2,0}}
local count=0
for _,source_dir in ipairs(dirs) do for index,target_dir in ipairs(dirs) do for _,offset in ipairs(positions) do
for _,name in ipairs({'rock','flag','text'}) do for _,stack in ipairs({false,true}) do
    local w=RW_CreateSession().world;w.width=9;w.height=9;w.entities={}
    local e={id=10,class='object',archetype='avatar',x=4,y=4,direction=source_dir};w.entities[10]=e
    units={};env.unitmap={}
    local function add(id,name,x,y,dir,rawdir)
        w.entities[id]={id=id,class=name=='text' and 'text' or 'object',archetype=name,x=x,y=y,direction=dir}
        units[id]={name=name,values={math.min(rawdir-1,4),x,y}}
        local tile=x+y*9;env.unitmap[tile]=env.unitmap[tile] or {};table.insert(env.unitmap[tile],id)
    end
    add(11,name,4+offset[1],4+offset[2],target_dir,index)
    if stack then add(12,'rock',4+offset[1],4+offset[2],'Left',3) end
    for _,params in ipairs(paramslist) do for _,negative in ipairs({false,true}) do
        local ordered={};local terms={};for _,p in ipairs(params) do terms[#terms+1]=term(p);if p:sub(1,4)=='not ' then ordered[#ordered+1]=p else table.insert(ordered,1,p) end end
        local expected=original(ordered,{},{},{unitid=10,x=4,y=4,dir=0,conds={}})
        if negative then expected=not expected end
        local actual=RW_TestEntityCondition(w,{op='spatial',clauses={{relation='facedby',negated=negative,parameters=terms}}},e)
        assert(actual==expected,source_dir..':'..target_dir..':'..name..':'..table.concat(params,',')..':'..tostring(stack))
        count=count+1
    end end
end end end end end
print('PASS: installed FACEDBY cardinal/stack/negative/Text/LEVEL/default EMPTY/AND matrix ('..count..' cases)')
