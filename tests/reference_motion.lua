-- Run the installed statusblock direction/turn body, not a rewritten oracle.
dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('local ur = hasfeature_count',1,true))
local b=assert(source:find('if (generaldata.values[MODE] == 0)',a,true))
local env=setmetatable({},{__index=_G})
local counts,sleeping,result
local unit={fixed=10,values={}}
env.unit=unit;env.name='rock';env.noturn=false;env.undoing=false
local DIR,XPOS,YPOS=1,2,3;env.DIR=DIR;env.XPOS=XPOS;env.YPOS=YPOS
function env.hasfeature_count(_,_,trait) return counts[trait] or 0 end
function env.issleep() return sleeping end
function env.updatedir(_,dir) unit.values[DIR]=dir;result=dir end
function env.testcond() return true end
local original=assert(load(source:sub(a,b-1),'@original_statusblock_directions','t',env))
local names={'Right','Up','Left','Down'}
local checked=0
for right=0,2 do for up=0,2 do for left=0,2 do for down=0,2 do
for turn=0,2 do for deturn=0,2 do for dir=0,3 do for _,sleep in ipairs({false,true}) do
    counts={right=right,up=up,left=left,down=down,turn=turn,deturn=deturn}
    sleeping=sleep;result=dir;unit.values[DIR]=dir;env.featureindex={turn={},deturn={}}
    for _,trait in ipairs({'turn','deturn'}) do
        for i=1,counts[trait] do table.insert(env.featureindex[trait],{{'rock','is',trait},{}}) end
    end
    original()
    local world={entities={[10]={id=10,x=2,y=2,direction=names[dir+1],behaviors={sleep=sleep}}},trait_counts={[10]=counts}}
    local plan=RW_ResolveOrientation(world)
    local facing=#plan.changes>0 and plan.changes[1].to or names[dir+1]
    assert(facing==names[result+1],table.concat({right,up,left,down,turn,deturn,dir},':'))
    checked=checked+1
end end end end end end end end
print('PASS: original statusblock direction weighting/ties/TURN/DETURN/SLEEP parity ('..checked..' cases)')
