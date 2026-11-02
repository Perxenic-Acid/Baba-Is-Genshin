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
 if name==env.mover_name and verb=='eat' then return mover.eat and true or nil end
 return name=='rock' and target[trait] and true or nil
end
env.issafe=function(id) return (id==200 and target or mover).safe==true end
env.floating=function() return (target.float==true)==(mover.float==true) end
env.checkeffecthistory=function() return 1,'' end;env.MF_particles=function() end;env.setsoundname=function() end
env.mmf={newObject=function(id) return {flags={dead=deleted[id]==true}} end}
env.delete=function(id) if not deleted[id] then deleted[id]=true;order[#order+1]=id end end
local native=assert(load('return function(lockpartner) local x,y,ox,oy=4,4,1,0 local pulling=false '..
 'local unitid,id,name,obsname=mover_id,200,mover_name,"rock" local unit={flags={}} local specials={} local valid=true '..
 'local eat=hasfeature(name,"eat",nil,unitid,x,y) '..
 'if not mover_phantom then '..source:sub(a,b-1)..' end '..
 'local gone=false for _,v in ipairs(specials) do if not gone and not deleted_units[v[1]] then local b,reason=v[1],v[2] local bx,by=5,4 '..source:sub(c,d-1)..
 'end end end return valid,gone end','@installed_real_movement_eat','t',env))()
local count=0
for _,mode in ipairs({'real','virtual','anonymous','pulled'}) do
local virtual=mode~='real';local anonymous=mode=='anonymous';local pulled=mode=='pulled'
env.mover_name=virtual and 'empty' or 'avatar';env.mover_id=virtual and 2 or 100
for mask=0,63 do for mmask=0,63 do
 target={block_entry=true};for i,name in ipairs({'open','shut','safe','float','push','still'}) do target[name]=math.floor(mask/2^(i-1))%2==1 end
 mover={};for i,name in ipairs({'open','shut','safe','float','eat','phantom'}) do mover[name]=math.floor(mmask/2^(i-1))%2==1 end
 deleted,order={},{};env.deleted_units=deleted;env.mover_phantom=mover.phantom
 local valid,gone=native(mover.open and 'shut' or mover.shut and 'open' or '')
 local source_id=virtual and -1 or 1
 local w={width=8,height=8,entities={
  [source_id]={id=source_id,class=virtual and 'empty' or 'object',archetype=virtual and nil or 'avatar',x=4,y=4,direction='Right',behaviors=mover,eat_targets=virtual and {rock=mover.eat} or nil},
  [2]={id=2,class='object',archetype='rock',x=5,y=4,direction='Up',behaviors=target},
  [3]={id=3,class='object',archetype='wall',x=6,y=4,behaviors={block_entry=true}}},movement_eaters={[1]={rock=mover.eat}}}
 if anonymous or pulled then
  w.entities[source_id]=nil;w.entities[1]={id=1,x=pulled and 5 or 3,y=4,behaviors={phantom=pulled}}
  local b={push=anonymous,pull=pulled};for k,value in pairs(mover) do b[k]=value end
  w.empty_cells={['4:4']={x=4,y=4,behaviors=b}}
  w.movement_eaters={empty_cells={['4:4']={rock=mover.eat},['5:4']={rock=mover.eat}}}
 end
 local root_id=(anonymous or pulled) and 1 or source_id
 local p=assert(RW_ResolveMovement(w,{type='move',entity_id=root_id,dx=1,dy=0}))
 local moved=false;for _,op in ipairs(p.changes) do if op.entity_id==root_id and op.kind=='move' then moved=true end end
 assert(moved==(pulled or (not valid or mover.phantom) and (anonymous or not gone)),mode..':'..mask..':'..mmask)
 local deaths=p.destructions or {};assert(#deaths==#order,mask..':'..mmask..' death count')
 for i,id in ipairs(order) do
  local expected=id==env.mover_id and ((anonymous or pulled) and 'empty:4:4' or source_id) or 2
  assert(deaths[i].entity_id==expected,mode..':'..mask..':'..mmask..' death order')
 end
 count=count+1
end end
end
print('PASS: installed real/virtual/anonymous/pulled mover lock-before-EAT, SAFE/FLOAT/PHANTOM, STOP/PUSH/STILL and death order ('..count..' cases)')
env.mover_name='empty';env.mover_id=2
for mask=0,7 do
 local origin_rock=mask%2==1;local destination_rock=math.floor(mask/2)%2==1;local origin_text=mask>=4
 target={block_entry=true};mover={};deleted,order={},{};env.deleted_units=deleted;env.mover_phantom=false
 local queries={}
 env.hasfeature=function(name,verb,trait,id,x,y)
  if name=='empty' and verb=='eat' then
   queries[#queries+1]={trait=trait,x=x,y=y}
   if trait==nil then return (origin_rock or origin_text) and true or nil end
   return destination_rock and true or nil
  end
 end
 local valid=native('');assert(queries[1].x==4 and queries[1].y==4)
 if origin_rock or origin_text then assert(#queries==2 and queries[2].x==5 and queries[2].y==4) else assert(#queries==1) end
 local origin={rock=origin_rock,['@text']=origin_text}
 -- Disabled targets are absent in compiled maps, rather than stored as false.
 if not origin_rock then origin.rock=nil end;if not origin_text then origin['@text']=nil end
 local w={width=8,height=8,entities={
  [-1]={id=-1,class='empty',x=4,y=4,direction='Right',behaviors={},eat_targets=origin},
  [2]={id=2,class='object',archetype='rock',x=5,y=4,direction='Up',behaviors=target}},
  movement_eaters={empty_cells={['4:4']=origin,['5:4']=destination_rock and {rock=true} or nil}}}
 local plan=assert(RW_ResolveMovement(w,{type='move',entity_id=-1,dx=1,dy=0}))
 assert(#(plan.destructions or {})==(valid and 0 or 1),'virtual coordinate gates '..mask)
end
print('PASS: installed EMPTY EAT source-any/destination-specific coordinate gates (8 cases)')
