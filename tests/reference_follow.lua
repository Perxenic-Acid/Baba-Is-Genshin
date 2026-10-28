-- Execute the installed moveblock FOLLOW path with onlystartblock=true.
dofile('external_lua_file/movement.lua')
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local env=setmetatable({},{__index=_G})
local f=assert(io.open(base..'blocks.lua','rb'));local source=f:read('*a');f:close()
assert(load(source,'@original_blocks','t',env))()
env.XPOS=1;env.YPOS=2;env.DIR=3;env.ID=4;env.UNITNAME=1;env.UNITTYPE=2;env.DEAD=1
local units,sleep
local names={'Right','Up','Left','Down','None'}
local vectors={{1,0},{0,-1},{-1,0},{0,1},{0,0}}
env.ndirs=vectors
env.mmf={newObject=function(id) return units[id] end}
env.findfeature=function() return {{'rock',{}}} end
env.issleep=function() return sleep end
env.testcond=function() return true end
env.updatedir=function(id,dir) units[id].values[3]=dir end
env.xthis=function(lookup,name,verb)
    local targets={};for _,r in ipairs(lookup) do if r[1][1]==name and r[1][2]==verb then targets[#targets+1]=r[1][3] end end
    return targets
end
env.findall=function(spec)
    local ids={};for id,u in pairs(units) do if u.strings[1]==spec[1] then ids[#ids+1]=id end end
    table.sort(ids);return ids
end
env.featureindex={rock={{{'rock','follow','avatar'},{}}}}
local checked=0
local function compare(points,dir,memory,sleeping)
    units={[10]={fixed=10,strings={'rock','object'},values={5,5,dir,10},flags={[1]=false},followed=memory}}
    sleep=sleeping
    local w={entities={[10]={id=10,class='object',archetype='rock',x=5,y=5,direction=names[dir+1],followed=memory,behaviors={sleep=sleeping}}}}
    for id,point in pairs(points) do
        units[id]={fixed=id,strings={'avatar','object'},values={point[1],point[2],0,id},flags={[1]=false}}
        w.entities[id]={id=id,class='object',archetype='avatar',x=point[1],y=point[2],direction='Right',behaviors={}}
    end
    env.moveblock(true)
    local plan=RW_ResolveFollow(w,{[10]={'avatar'}})
    local facing,followed=w.entities[10].direction,memory
    for _,c in ipairs(plan.changes) do if c.kind=='direction' then facing=c.to elseif c.kind=='followed' then followed=c.to end end
    assert(facing==names[units[10].values[3]+1] and followed==units[10].followed,
        table.concat({dir,memory,tostring(sleeping),facing,followed,units[10].values[3],units[10].followed},':'))
    checked=checked+1
end
for mask=1,15 do for dir=0,4 do for _,memory in ipairs({-1,1,2,3,4,99}) do for _,sleeping in ipairs({false,true}) do
    local points={}
    for i=1,4 do if math.floor(mask/2^(i-1))%2==1 then points[i]={5+vectors[i][1],5+vectors[i][2]} end end
    compare(points,dir,memory,sleeping)
end end end end
for dx=-3,3 do for dy=-3,3 do for dir=0,3 do
    compare({[1]={5+dx,5+dy},[2]={5-dx,5-dy}},dir,-1,false)
end end end
print('PASS: installed FOLLOW nearest/ties/adjacent memory/SLEEP matrix ('..checked..' cases)')
