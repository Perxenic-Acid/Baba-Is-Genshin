dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('\n\tif pulling then\n\t\tlocal swap =',source:find('function dopush(',1,true),true))
local b=assert(source:find('\n\tlocal hm = 0',a,true))
local enabled,updates
local env=setmetatable({}, {__index=_G})
env.hasfeature=function() return enabled and true or nil end
env.findallhere=function() return {100,200} end
env.findupdate=function() return {} end
env.addaction=function(id,action) updates[#updates+1]={id=id,action=action} end
local native=assert(load('return function(x,y,ox,oy) local pulling=true local name,unitid,pusherid="empty",2,100 local pushsound=false '..
 source:sub(a,b-1)..' end','@installed_empty_pull_source_swap','t',env))()
local count=0
for _,axis in ipairs({{1,0},{0,-1},{-1,0},{0,1}}) do for mask=0,7 do
 local dx,dy=axis[1],axis[2];enabled=mask%2==1
 local sleeping=math.floor(mask/2)%2==1;local floating=mask>=4
 updates={};native(6-dx,6-dy,dx,dy)
 local w={width=12,height=12,entities={
  [1]={id=1,x=6,y=6,direction='Mid',behaviors={}},
  [2]={id=2,x=6,y=6,direction='Up',behaviors={float=floating,sleep=sleeping}}},
  empty_cells={[(6-dx)..':'..(6-dy)]={x=6-dx,y=6-dy,behaviors={pull=true,swap=enabled,sleep=sleeping}}}}
 local plan=assert(RW_ResolveMovement(w,{type='move',entity_id=1,dx=dx,dy=dy}))
 local swapped
 for _,op in ipairs(plan.changes) do if op.entity_id==2 then swapped=op end end
 assert((swapped~=nil)==(#updates>0))
 if swapped then
  assert(#updates==1 and updates[1].id==200)
  assert(swapped.to.x==updates[1].action[2] and swapped.to.y==updates[1].action[3] and swapped.to.direction=='Up')
 end
 assert(#(plan.destructions or {})==0 and w.entities[2].x==6)
 count=count+1
end end
print('PASS: installed virtual PULL source SWAP, pusher exclusion, facing, FLOAT/SLEEP and four axes ('..count..' cases)')
