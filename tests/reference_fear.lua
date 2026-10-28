-- Exercise the installed findfears() body, including its exact tie/count rule.
dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('function findfears(',1,true))
local b=assert(source:find('function getlettermultiplier(',a,true))
local env=setmetatable({},{__index=_G})
local dirs={'Right','Up','Left','Down'}
local vectors={{1,0},{0,-1},{-1,0},{0,1}}
local units,obstacles
local function bit(mask,i) return math.floor(mask/2^(i-1))%2==1 end
env.XPOS=1;env.YPOS=2;env.DIR=3;env.roomsizex=11
function env.getname() return 'rock' end
env.mmf={newObject=function(id) return units[id] end}
env.ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}}
env.rotate=function(dir) return (dir+2)%4 end
function env.findtype(spec,x,y,id)
    local result={}
    for other,u in pairs(units) do
        if other~=id and u.name==spec[1] and u.values[1]==x and u.values[2]==y then result[#result+1]=other end
    end
    return result
end
function env.check(_,_,_,dir) return {bit(obstacles,dir+1) and 1 or 0} end
function env.trypush() return 0 end
assert(load(source:sub(a,b-1),'@original_findfears','t',env))()
local checked=0
for mask=0,15 do for blocks=0,15 do for dir=0,3 do for count=1,2 do
    obstacles=blocks
    units={[10]={name='rock',values={5,5,dir}}};env.unitmap={}
    local w={width=11,height=11,entities={[10]={id=10,archetype='rock',class='object',x=5,y=5,direction=dirs[dir+1],behaviors={}}}}
    for i,v in ipairs(vectors) do
        if bit(mask,i) then
            units[20+i]={name='avatar',values={5+v[1],5+v[2],0}}
            w.entities[20+i]={id=20+i,archetype='avatar',class='object',x=5+v[1],y=5+v[2],direction='Right',behaviors={}}
        end
        if bit(blocks,i) then
            w.entities[30+i]={id=30+i,archetype='wall',class='object',x=5+v[1],y=5+v[2],direction='None',behaviors={block_entry=true}}
        end
    end
    local targets={};for i=1,count do targets[i]='avatar' end
    local valid,expected,amount=env.findfears(10,targets)
    local ok,facing,n=RW_FindFears(w,10,targets)
    assert(ok==valid and (not valid or facing==(dirs[expected+1] or 'None')) and n==amount,
        table.concat({mask,blocks,dir,count,tostring(ok),facing,tostring(valid),expected},':'))
    checked=checked+1
end end end end
print('PASS: installed findfears cardinal/count/tie/blocker matrix ('..checked..' cases)')
