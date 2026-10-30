-- Establish installed HOLD behavior before implementing transactional holder state.
dofile("external_lua_file/movement.lua")
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
 local w={entities={
  [1]={id=1,class="object",archetype="avatar",x=rider.values[1],y=2,direction="Down",holder=rider.holder,behaviors={still=bit(1),float=bit(2)}},
  [2]={id=2,class="object",archetype="rock",x=7,y=2,direction="Right",behaviors={hold=not bit(0),float=false}}}}
 local plan=assert(RW_ResolveHold(w));local actual_x=w.entities[1].x;local actual_holder=w.entities[1].holder
 for _,change in ipairs(plan.changes) do if change.entity_id==1 then
  if change.kind=="move" then actual_x=change.to.x elseif change.kind=="holder" then actual_holder=change.to end
 end end
 assert(load(source:sub(a,b-1),'@original_hold','t',env))()
 local acquired=not bit(0) and (not bit(3) or not bit(2))
 local should_move=acquired and not bit(1)
 assert(rider.values[1]==(bit(3) and 7 or should_move and 7 or 2))
 assert(rider.holder==(should_move and not bit(2) and 2 or 0))
 assert(actual_x==rider.values[1] and actual_holder==rider.holder,'production HOLD differs')
 assert(rider.values[3]==3,'HOLD must preserve rider facing')
 checked=checked+1
end

for mask=0,255 do
 local function bit(n) return math.floor(mask/2^n)%2==1 end
 local w={entities={}}
 for id=1,4 do
  w.entities[id]={id=id,class='object',archetype='rock',x=id<=2 and 3 or 8,y=id==4 and 5 or 3,direction='Left',holder=id==1 and 3 or id==3 and (bit(7) and 1 or 0) or 0,
   behaviors={hold=id==2 or id==3,still=id==1 and bit(0),lockedright=id==1 and bit(1),lockedleft=id==1 and bit(2),reverse=id==1 and bit(3),float=id==1 and bit(4) or id==2 and bit(5) or id==3 and bit(6)}}
 end
 local units,holders={},{}
 for id=1,4 do local e=w.entities[id];units[id]={fixed=id,values={e.x,e.y,2,id},strings={'rock'},holder=e.holder};if e.behaviors.hold then holders[#holders+1]=units[id] end end
 local env=setmetatable({XPOS=1,YPOS=2,DIR=3,ID=4,roomsizex=12,unitmap={},units=units},{__index=_G})
 for _,e in pairs(w.entities) do env.unitmap[e.x+e.y*12]=true end
 env.getunitswitheffect=function() return holders end
 env.findallhere=function(x,y) local r={};for id,u in ipairs(units) do if u.values[1]==x and u.values[2]==y then r[#r+1]=id end end;return r end
 env.mmf={newObject=function(id) return units[id] end};env.getunitid=function(id) return id end;env.getname=function() return 'rock' end
 env.floating=function(x,y) return w.entities[x].behaviors.float==w.entities[y].behaviors.float end
 env.cantmove=function(_,id,dir)
  local traits=w.entities[id].behaviors
  if traits.still then return true end
  if dir~=4 then
   if traits.reverse then dir=(dir+2)%4 end
   return traits[({'lockedright','lockedup','lockedleft','lockeddown'})[dir+1]] or false
  end
  return false
 end
 env.addundo=function() end;env.update=function(id,x,y) units[id].values[1],units[id].values[2]=x,y end
 assert(load(source:sub(a,b-1),'@original_hold_order','t',env))()
 local result={};for id,e in pairs(w.entities) do result[id]={x=e.x,y=e.y,holder=e.holder} end
 for _,change in ipairs(assert(RW_ResolveHold(w)).changes) do local r=result[change.entity_id]
  if change.kind=='move' then r.x,r.y=change.to.x,change.to.y elseif change.kind=='holder' then r.holder=change.to end
 end
 for id,u in ipairs(units) do local r=result[id];assert(r.x==u.values[1] and r.y==u.values[2] and r.holder==u.holder,'HOLD order mismatch '..mask..':'..id) end
 checked=checked+1
end
assert(checked==272)
print('PASS: installed HOLD acquisition, mobile holders/cycles, layers, STILL/directional locks/REVERSE, release and facing ('..checked..' cases)')
