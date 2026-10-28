-- Execute installed reversecheck(), including duplicate-grant parity.
dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('function reversecheck(',1,true))
local b=assert(source:find('function simplecheck(',a,true))
local count=0
local env=setmetatable({},{__index=_G})
env.mmf={newObject=function() return {} end}
env.getname=function() return 'rock' end
env.hasfeature_count=function() return count end
env.reversedir=function(dir) return (dir+2)%4 end
assert(load(source:sub(a,b-1),'@original_reversecheck','t',env))()
local vectors={{1,0},{0,-1},{-1,0},{0,1}}
local names={'Right','Up','Left','Down'}
local checked=0
for n=0,6 do for dir=0,3 do
    count=n
    local v=vectors[dir+1]
    local _,dx,dy=env.reversecheck(10,dir,4,4,v[1],v[2])
    local w={width=9,height=9,entities={[10]={id=10,x=4,y=4,direction='Mid',behaviors={reverse=n>0}}},trait_counts={[10]={reverse=n}}}
    local p=RW_ResolveMovement(w,{type='move',entity_id=10,dx=v[1],dy=v[2]})
    assert(#p.changes==1)
    local to=p.changes[1].to
    assert(to.x==4+dx and to.y==4+dy and to.direction==names[dir+1])
    checked=checked+1
end end
print('PASS: installed reversecheck parity/direction vectors ('..checked..' cases)')

local ca=assert(source:find('function cantmove(',1,true))
local cb=assert(source:find('function findnoun(',ca,true))
assert(load(source:sub(ca,cb-1),'@original_cantmove','t',env))()
local lock
local opts={'lockedright','lockedup','lockedleft','lockeddown'}
env.featureindex={reverse={}}
env.hasfeature=function(_,_,trait) if trait==lock then return true end end
for n=0,4 do for dir=0,3 do for _,locked in ipairs(opts) do
    count=n;lock=locked
    local v=vectors[dir+1]
    local physical=env.reversecheck(10,dir,4,4)
    local blocked=env.cantmove('rock',10,physical,4,4)==true
    local w={width=9,height=9,entities={[10]={id=10,x=4,y=4,direction='Mid',behaviors={reverse=n>0,[locked]=true}}},trait_counts={[10]={reverse=n}}}
    local p=RW_ResolveMovement(w,{type='move',entity_id=10,dx=v[1],dy=v[2]})
    assert((#p.changes==0)==blocked)
end end end
print('PASS: original cantmove/REVERSE directional-lock matrix (80 cases)')
