dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('local emptystop =',1,true));local b=assert(source:find('\n\tend\n\t\n\tif (#results == 0)',a,true))
local c=assert(source:find('if (reason == "lock") then',b,true));local d=assert(source:find('elseif (reason == "weak") then',c,true))
local target,mover,deleted,order
local env=setmetatable({generaldata={values={}},SHAKE='shake',DEAD='dead'},{__index=_G})
env.hasfeature=function(name,verb,trait)
 if verb=='eat' then return mover.eat and true or nil end
 return name=='empty' and target[trait] and true or nil
end
env.cantmove=function() return false end
env.issafe=function(_,x) return (x==6 and target or mover).safe==true end
env.floating=function() return (target.float==true)==(mover.float==true) end
env.checkeffecthistory=function() return 1,'' end;env.MF_particles=function() end;env.setsoundname=function() end
env.delete=function(_,x) if not deleted[x] then deleted[x]=true;order[#order+1]=x end end
local native=assert(load('return function(lockpartner,phantom) local x,y,ox,oy,dir_=5,4,1,0,0 local pulling=false local eat=true '..
 'local unitid=2 local name="empty" local unit={flags={}} local result,results,specials={},{},{} '..
 'if not phantom then '..source:sub(a,b-1)..' end '..
 'local gone=false for _,v in ipairs(specials) do if not gone then local b,reason=v[1],v[2] local bx,by=6,4 '..source:sub(c,d-1)..
 'end end end return result[1] or 0 end','@installed_anonymous_empty_contacts','t',env))()
local count=0
for mask=0,31 do for mmask=0,63 do
 target={stop=true};for i,name in ipairs({'open','shut','safe','float','weak'}) do target[name]=math.floor(mask/2^(i-1))%2==1 end
 mover={};for i,name in ipairs({'open','shut','safe','float','eat','phantom'}) do mover[name]=math.floor(mmask/2^(i-1))%2==1 end
 deleted,order={},{};local classification=native(mover.open and 'shut' or mover.shut and 'open' or '',mover.phantom)
 local source_behaviors={push=true};for k,v in pairs(mover) do source_behaviors[k]=v end
 local target_behaviors={block_entry=true};for k,v in pairs(target) do if k~='stop' then target_behaviors[k]=v end end
 local w={width=8,height=8,entities={[1]={id=1,x=4,y=4,behaviors={}}},
  empty_cells={['5:4']={x=5,y=4,behaviors=source_behaviors},['6:4']={x=6,y=4,behaviors=target_behaviors}},
  movement_eaters={empty_cells={['5:4']={['@empty']=mover.eat},['6:4']={['@empty']=mover.eat}}},empty_eaters={}}
 local plan=assert(RW_ResolveMovement(w,{type='move',entity_id=1,dx=1,dy=0}))
 assert((#plan.changes>0)==(classification==0),mask..':'..mmask..' movement')
 local deaths=plan.destructions or {};assert(#deaths==#order,mask..':'..mmask..' deaths')
 for i,x in ipairs(order) do assert(deaths[i].class=='empty' and deaths[i].x==x and deaths[i].y==4) end
 count=count+1
end end
print('PASS: installed anonymous-to-EMPTY EAT-before-lock, SAFE/FLOAT/PHANTOM, WEAK non-deletion and ordered cell deaths ('..count..' cases)')
