-- Establish installed HOLD behavior before implementing transactional holder state.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('local ishold =',1,true));local b=assert(source:find('local issink =',a,true))
local checked=0
for mask=0,15 do
 local function bit(n) return math.floor(mask/2^n)%2==1 end
 local rider={fixed=1,values={2,2,3,1},strings={'avatar'},holder=2}
 local holder={fixed=2,values={7,2,0,2},strings={'rock'},holder=0}
 local env=setmetatable({XPOS=1,YPOS=2,DIR=3,ID=4,roomsizex=12,unitmap={},units={rider,holder}}, {__index=_G})
 env.getunitswitheffect=function() return bit(0) and {} or {holder} end
 env.findallhere=function() return {2} end
 env.mmf={newObject=function(id) return id==1 and rider or holder end}
 env.getunitid=function(id) return id end;env.getname=function(unit) return unit.strings[1] end
 env.floating=function() return not bit(2) end
 env.cantmove=function() return bit(1) end
 env.addundo=function() end
 env.update=function(id,x,y,dir) local u=id==1 and rider or holder;u.values[1],u.values[2],u.values[3]=x,y,dir end
 if bit(3) then rider.values[1]=7;env.unitmap[7+2*12]=true;env.findallhere=function() return {1,2} end;rider.holder=0 end
 assert(load(source:sub(a,b-1),'@original_hold','t',env))()
 local acquired=not bit(0) and (not bit(3) or not bit(2))
 local should_move=acquired and not bit(1)
 assert(rider.values[1]==(bit(3) and 7 or should_move and 7 or 2))
 assert(rider.holder==(should_move and not bit(2) and 2 or 0))
 assert(rider.values[3]==3,'HOLD must preserve rider facing')
 checked=checked+1
end
print('PASS: installed HOLD acquisition, lost holders, lock release, post-move FLOAT release and facing ('..checked..' cases)')
