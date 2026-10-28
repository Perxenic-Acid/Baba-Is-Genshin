-- Direct parity with the installed original condition functions.
dofile('external_lua_file/rules.lua')
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'))
local source=file:read('*a');file:close()
local env=setmetatable({},{__index=_G})
assert(load(source,'@original_conditions','t',env))()
env.roomsizex=9;env.roomsizey=9;env.UNITNAME=1;env.DIR=1;env.XPOS=2;env.YPOS=3
env.ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}}
env.map={[0]={get_x=function(_,x,y) return x>=1 and x<=7 and y>=1 and y<=7 and 255 or 0 end}}
function env.stringintable(s,t) for _,v in ipairs(t) do if v==s then return true end end;return false end
local objects
env.mmf={newObject=function(id) return objects[id] end}
function env.getname(o) return o.name end
local dirs={'Right','Up','Left','Down'}
local checked=0
for _,relation in ipairs({'nextto','above','below','besideleft','besideright','facing'}) do
for x=1,7 do for y=1,7 do for dir=0,3 do
    objects={[10]={name='avatar',values={dir,4,4}},[11]={name='rock',values={0,x,y}}}
    env.unitmap={}
    local world={width=7,height=7,entities={}}
    for id,o in pairs(objects) do
        local key=o.values[2]+o.values[3]*env.roomsizex
        env.unitmap[key]=env.unitmap[key] or {};table.insert(env.unitmap[key],id)
        world.entities[id]={id=id,class='object',archetype=o.name,x=o.values[2],y=o.values[3],direction=dirs[o.values[1]+1]}
    end
    local params={{'rock'},{'not rock'},{'empty'},{'not empty'},{'level'},{'rock','rock'},{'empty','empty'}}
    if relation=='facing' then params[#params+1]={'right'};params[#params+1]={'not right'};params[#params+1]={'right','right'} end
    for _,list in ipairs(params) do
        local terms={}
        for _,parameter in ipairs(list) do
            local neg=parameter:sub(1,4)=='not ';local name=neg and parameter:sub(5) or parameter
            local term
            if name=='empty' then term={tag='special',name='empty'}
            elseif name=='right' then term={tag='property',name='right'}
            else term={tag='noun',type={tag=name=='level' and 'level' or 'object',name=name}} end
            terms[#terms+1]=neg and {tag='not',operand=term} or term
        end
        local expected=env.condlist[relation](list,{},nil,{unitid=10,x=4,y=4,dir=dir,surrounds={},extras={'right','up','left','down'}})
        local actual,err=RW_TestEntityCondition(world,{op='spatial',clauses={{relation=relation,negated=false,parameters=terms}}},world.entities[10])
        assert(actual==expected,relation..':'..x..','..y..':'..dir..':'..table.concat(list,',')..':'..tostring(err)..':'..tostring(actual)..'/'..tostring(expected))
        checked=checked+1
    end
end end end end
print('PASS: original NEXTTO/ABOVE/BELOW/BESIDELEFT/BESIDERIGHT/FACING parity ('..checked..' cases)')
