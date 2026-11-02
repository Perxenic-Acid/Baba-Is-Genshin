dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('function trypush(',1,true));local b=assert(source:find('function move(',a,true))
local env=setmetatable({roomsizex=12,TURNSOUND='turn',generaldata2={strings={turn=''}},XPOS='x',YPOS='y'}, {__index=_G})
local unit,eligible
env.mmf={newObject=function() return unit end};env.getname=function() return 'rock' end
env.hasfeature=function() end;env.findfeatureat=function() end;env.setsoundname=function() end
env.check=function(id,_,_,_,pulling)
 if id==2 and pulling and eligible then return {200},{200},{} end
 return {0},{0},{}
end
assert(load(source:sub(a,b-1),'@installed_empty_pull_dispatch','t',env))()
local count=0
for _,axis in ipairs({{1,0},{0,-1},{-1,0},{0,1}}) do for mask=0,31 do
 local dx,dy=axis[1],axis[2]
 local traits={};for i,name in ipairs({'still','sleep','float','weak','safe'}) do traits[name]=math.floor(mask/2^(i-1))%2==1 end
 -- check() eligibility is isolated here; its cantmove classification has its
 -- own installed-fragment oracle. This executes actual recursive dopush.
 eligible=not traits.still;unit={values={x=6-dx,y=6-dy}}
 env.movemap={};env.pushedunits={};env.movelist={};env.HACK_MOVES=0
 assert(env.dopush(2,dx,dy,0,false,6,6,'you',100)==0)
 assert(env.HACK_MOVES<10000,'native recursive chain exhausted move guard')
 local native_pulled=false;for _,move in ipairs(env.movelist) do if move[1]==200 then native_pulled=true end end
 local behavior={pull=true};for k,v in pairs(traits) do behavior[k]=v end
 local w={width=12,height=12,entities={
  [1]={id=1,x=6-dx,y=6-dy,direction='Mid',behaviors={}},
  [2]={id=2,x=6-dx,y=6-dy,direction='None',behaviors=behavior}},
  empty_cells={['6:6']={x=6,y=6,behaviors={push=true}}}}
 local plan=assert(RW_ResolveMovement(w,{type='move',entity_id=1,dx=dx,dy=dy}))
 local leader,pulled
 for _,op in ipairs(plan.changes) do if op.entity_id==1 then leader=op elseif op.entity_id==2 then pulled=op end end
 assert(leader and leader.to.x==6 and leader.to.y==6)
 assert((pulled~=nil)==native_pulled,mask..' pulling')
 if pulled then assert(pulled.to.x==6 and pulled.to.y==6) end
 assert(#(plan.destructions or {})==0)
 assert(w.entities[2].x==6-dx and not w.empty_departures)
 count=count+1
end end
print('PASS: installed anonymous EMPTY trailing real PULL dispatch, four axes, STILL/SLEEP/FLOAT/WEAK/SAFE ('..count..' cases)')
local chains=0
for _,axis in ipairs({{1,0},{0,-1},{-1,0},{0,1}}) do for length=1,4 do for locked=0,length do for pushing=0,1 do
 local dx,dy=axis[1],axis[2]
 local cells={};for distance=1,length do
  local x,y=6-distance*dx,6-distance*dy
  cells[x..':'..y]={x=x,y=y,behaviors={pull=true,push=pushing==1,still=distance==locked}}
 end
 unit={values={x=6-(length+1)*dx,y=6-(length+1)*dy}}
 env.check=function(id,x,y,_,pulling)
  if not pulling then
   local cell=cells[(x+dx)..':'..(y+dy)]
   if cell and cell.behaviors.push then return {cell.behaviors.still and 1 or 2},{2},{} end
   return {0},{0},{}
  end
  if id==200 then return {0},{0},{} end
  local key=(x-dx)..':'..(y-dy);local cell=cells[key]
  if cell then return {cell.behaviors.still and 1 or 2},{2},{} end
  return {200},{200},{}
 end
 env.movemap={};env.pushedunits={};env.movelist={};env.HACK_MOVES=0
 assert(env.dopush(2,dx,dy,0,false,6,6,'you',100)==0)
 assert(env.HACK_MOVES<10000,'native recursive chain exhausted move guard')
 local expected=false;for _,move in ipairs(env.movelist) do if move[1]==200 then expected=true end end
 local w={width=12,height=12,entities={
  [1]={id=1,x=6,y=6,direction='Mid',behaviors={}},
  [2]={id=2,x=unit.values.x,y=unit.values.y,direction='Up',behaviors={pull=true}}},empty_cells=cells}
 local plan=assert(RW_ResolveMovement(w,{type='move',entity_id=1,dx=dx,dy=dy}))
 local pulled;for _,op in ipairs(plan.changes) do if op.entity_id==2 then pulled=op end;assert(op.entity_id>0) end
 assert((pulled~=nil)==expected,length..':'..locked..' virtual chain')
 if pulled then assert(pulled.to.x==unit.values.x+dx and pulled.to.y==unit.values.y+dy) end
 assert(#(plan.destructions or {})==0 and not w.empty_departures)
 local seen={};for _,op in ipairs(plan.changes) do assert(not seen[op.entity_id],'duplicate real movement');seen[op.entity_id]=true end
 chains=chains+1
end end end end
print('PASS: installed EMPTY PULL/PUSH recursive chain dispatch to real tails, four axes, lengths and interior STILL ('..chains..' cases)')
