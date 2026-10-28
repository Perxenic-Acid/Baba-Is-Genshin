-- Execute original check()/fallblock() against stubbed engine state.
dofile('external_lua_file/movement.lua')
local env=setmetatable({},{__index=_G})
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
for _,name in ipairs({'movement.lua','blocks.lua'}) do
    local f=assert(io.open(base..name,'rb'));local source=f:read('*a');f:close()
    assert(load(source,'@original_'..name,'t',env))()
end
local tf=assert(io.open(base..'tools.lua','rb'));local ts=tf:read('*a');tf:close()
local ta=assert(ts:find('function reversecheck(',1,true));local tb=assert(ts:find('function simplecheck(',ta,true))
assert(load(ts:sub(ta,tb-1),'@original_reversecheck','t',env))()
env.reversedir=function(dir) return (dir+2)%4 end
env.XPOS=1;env.YPOS=2;env.DIR=3;env.UNITNAME=1;env.DEAD=1
local names={'Right','Up','Left','Down'}
env.ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}}
env.roomsizex=9;env.roomsizey=9
local units
function env.inbounds(x,y) return x>=1 and x<=7 and y>=1 and y<=7 end
function env.getname(unit) return unit.strings[1] end
env.mmf={newObject=function(id) return units[id] end}
function env.hasfeature(_,verb,trait,id)
    if verb=='is' and units[id] and units[id].traits[trait] then return true end
end
function env.hasfeature_count(_,verb,trait,id) return verb=='is' and units[id] and units[id].traits[trait] or 0 end
function env.findallfeature(_,_,trait)
    local ids={};for id,unit in pairs(units) do for i=1,unit.traits[trait] or 0 do ids[#ids+1]=id end end
    table.sort(ids);return ids
end
function env.cantmove(_,id,dir)
    local t=units[id] and units[id].traits or {};dir=env.reversecheck(id,dir);return t.still or t[({'lockedright','lockedup','lockedleft','lockeddown'})[dir+1]] or false
end
function env.floating(a,b) return (units[a].traits.float~=nil)==(units[b].traits.float~=nil) end
function env.issafe(id) return units[id].traits.safe~=nil end
function env.findobstacle(x,y)
    if not env.inbounds(x,y) then return {-1} end
    local ids={};for id,u in pairs(units) do if u.values[1]==x and u.values[2]==y then ids[#ids+1]=id end end
    table.sort(ids);return ids
end
function env.findupdate() return {} end
function env.update(id,x,y) units[id].values[1],units[id].values[2]=x,y end
function env.destroylevel() error('unexpected original fall limit') end
local checked=0
for right=0,1 do for left=0,1 do for reverse=0,2 do for down=0,2 do for up=0,2 do for _,support in ipairs({'stop','push','pull','swap','none'}) do
    units={[10]={fixed=10,strings={'rock'},values={4,2,0},flags={[1]=false},traits={fall=down,fallup=up,fallright=right,fallleft=left,reverse=reverse}},
        [11]={fixed=11,strings={'flag'},values={4,5,1},flags={[1]=false},traits={}}}
    if support~='none' then units[11].traits[support]=1 end
    env.objectdata={};env.featureindex={reverse={}}
    local world={width=7,height=7,entities={},trait_counts={}}
    for id,u in pairs(units) do
        local behaviors={};for k,v in pairs(u.traits) do if v>0 then behaviors[k=="stop" and "block_entry" or k]=true end end
        world.entities[id]={id=id,class='object',archetype=u.strings[1],x=u.values[1],y=u.values[2],direction=names[u.values[3]+1],behaviors=behaviors}
        world.trait_counts[id]=u.traits
    end
    env.fallblock()
    local plan=RW_ResolveFall(world)
    local positions={};for id,u in pairs(world.entities) do positions[id]={u.x,u.y,u.direction} end
    for _,change in ipairs(plan.changes) do positions[change.entity_id]={change.to.x,change.to.y,change.to.direction} end
    for id,position in pairs(positions) do
        assert(position[1]==units[id].values[1] and position[2]==units[id].values[2],down..':'..up..':'..support..':'..position[2]..'/'..units[id].values[2])
        assert(position[3]==names[units[id].values[3]+1])
    end
    checked=checked+1
end end end end end end
print('PASS: original check/fallblock support, SWAP, cancellation, counts and facing parity ('..checked..' cases)')
