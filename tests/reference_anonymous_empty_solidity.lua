dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('local weak = hasfeature(obsname,"is","weak"',1,true))
local b=assert(source:find('\n\t\t\tend\n\t\tend\n\telseif (phantom == nil)',a,true))
local target,mover
local env=setmetatable({}, {__index=_G})
env.hasfeature=function(_,_,trait) return target[trait] and true or nil end
env.issafe=function() return target.safe==true end
env.floating=function() return (target.float==true)==(mover.float==true) end
env.cantmove=function() return target.still==true end
local native=assert(load('return function() local obsname,id,unitid="rock",200,2 local x,y,ox,oy,dir=5,4,1,0,0 '..
 'local pulling=false local specials,result,results={},{},{} local valid=true local localresult=0 local obsunit={visible=true} '..
 source:sub(a,b-1)..' return result[1] or 0 end','@installed_anonymous_solidity','t',env))()
local count=0
for mask=0,127 do for layer=0,1 do
 target={};for i,name in ipairs({'stop','pull','push','weak','safe','float','still'}) do target[name]=math.floor(mask/2^(i-1))%2==1 end
 mover={float=layer==1}
 local classification=native()
 local behavior={};for k,v in pairs(target) do behavior[k=='stop' and 'block_entry' or k]=v end
 local w={width=9,height=8,entities={
  [1]={id=1,x=4,y=4,behaviors={}},
  [2]={id=2,x=6,y=4,direction='Up',behaviors=behavior},
  [3]={id=3,x=7,y=4,behaviors={block_entry=true}}},
  empty_cells={['5:4']={x=5,y=4,behaviors={push=true,float=mover.float}}}}
 local plan=assert(RW_ResolveMovement(w,{type='move',entity_id=1,dx=1,dy=0}))
 -- A mobile PUSH is supported by a wall, except unsafe WEAK which shatters.
 local succeeds=classification==0 or classification==200 and target.weak and not target.safe
 assert((#plan.changes>0)==succeeds,mask..':'..layer..' solidity')
 local deaths=plan.destructions or {}
 assert(#deaths==((classification==200 and target.weak and not target.safe) and 1 or 0),mask..':'..layer..' deaths')
 if #deaths>0 then assert(deaths[1].entity_id==2 and deaths[1].cause=='weak') end
 count=count+1
end end
print('PASS: installed anonymous EMPTY versus real STOP/PULL/PUSH/WEAK/SAFE/FLOAT/STILL solidity ('..count..' cases)')
