dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local anchor=assert(source:find('local obsunit = mmf.newObject(id)',1,true))
local a=assert(source:find('if (lockpartner ~= "") and (pulling == false) then',anchor,true))
local b=assert(source:find('local weak =',a,true))
local c=assert(source:find('if (reason == "lock") then',b,true))
local d=assert(source:find('elseif (reason == "weak") then',c,true))
local target,mover,deleted,order
local env=setmetatable({generaldata={values={}},SHAKE='shake',DEAD='dead'},{__index=_G})
env.hasfeature=function(name,verb,trait)
 if name=='avatar' and verb=='eat' then return mover.eat and true or nil end
 return name=='rock' and target[trait] and true or nil
end
env.issafe=function(id) return (id==200 and target or mover).safe==true end
env.floating=function() return (target.float==true)==(mover.float==true) end
env.checkeffecthistory=function() return 1,'' end;env.MF_particles=function() end;env.setsoundname=function() end
env.mmf={newObject=function(id) return {flags={dead=deleted[id]==true}} end}
env.delete=function(id) if not deleted[id] then deleted[id]=true;order[#order+1]=id end end
local native=assert(load('return function(lockpartner) local x,y,ox,oy=4,4,1,0 local pulling=false local eat=true '..
 'local unitid,id,name,obsname=100,200,"avatar","rock" local unit={flags={}} local specials={} local valid=true '..
 'if not mover_phantom then '..source:sub(a,b-1)..' end '..
 'local gone=false for _,v in ipairs(specials) do if not gone and not deleted_units[v[1]] then local b,reason=v[1],v[2] local bx,by=5,4 '..source:sub(c,d-1)..
 'end end end return valid,gone end','@installed_real_movement_eat','t',env))()
local count=0
for mask=0,63 do for mmask=0,63 do
 target={block_entry=true};for i,name in ipairs({'open','shut','safe','float','push','still'}) do target[name]=math.floor(mask/2^(i-1))%2==1 end
 mover={};for i,name in ipairs({'open','shut','safe','float','eat','phantom'}) do mover[name]=math.floor(mmask/2^(i-1))%2==1 end
 deleted,order={},{};env.deleted_units=deleted;env.mover_phantom=mover.phantom
 local valid,gone=native(mover.open and 'shut' or mover.shut and 'open' or '')
 local w={width=8,height=8,entities={
  [1]={id=1,class='object',archetype='avatar',x=4,y=4,direction='Right',behaviors=mover},
  [2]={id=2,class='object',archetype='rock',x=5,y=4,direction='Up',behaviors=target},
  [3]={id=3,class='object',archetype='wall',x=6,y=4,behaviors={block_entry=true}}},movement_eaters={[1]={rock=mover.eat}}}
 local p=assert(RW_ResolveMovement(w,{type='move',entity_id=1,dx=1,dy=0}))
 local moved=false;for _,op in ipairs(p.changes) do if op.entity_id==1 and op.kind=='move' then moved=true end end
 assert(moved==((not valid or mover.phantom) and not gone),mask..':'..mmask)
 local deaths=p.destructions or {};assert(#deaths==#order,mask..':'..mmask..' death count')
 for i,id in ipairs(order) do assert(deaths[i].entity_id==(id==100 and 1 or 2),mask..':'..mmask..' death order') end
 count=count+1
end end
print('PASS: installed real movement lock-before-EAT, SAFE/FLOAT/PHANTOM, STOP/PUSH/STILL and death order ('..count..' cases)')
