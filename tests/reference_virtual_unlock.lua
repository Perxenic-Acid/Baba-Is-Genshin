dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('local emptystop =',1,true));local b=assert(source:find('\n\tend\n\t\n\tif (#results == 0)',a,true))
local c=assert(source:find('if (reason == "lock") then',b,true));local d=assert(source:find('elseif (reason == "eat") then',c,true))
local e=assert(source:find('if (b == 2) and (unitid ~= 2) then',d,true));local g=assert(source:find('\n\t\t\t\t\tend',e,true))
local target,mover,deleted,order
local env=setmetatable({generaldata={values={}},SHAKE='shake',DEAD='dead'},{__index=_G})
env.hasfeature=function(name,_,trait) return name=='empty' and target[trait] and true or nil end
env.cantmove=function() return target.still end
env.issafe=function(id,x) return (x==5 and target or mover).safe==true end
env.floating=function() return (target.float==true)==(mover.float==true) end
env.checkeffecthistory=function() return 1,'' end;env.MF_particles=function() end;env.setsoundname=function() end
env.delete=function(id,x) if not deleted[x] then deleted[x]=true;order[#order+1]=x end end
local native=assert(load('return function(lockpartner) local x,y,ox,oy,dir_=4,4,1,0,0 local pulling=false local eat=nil '..
 'local unitid=2 local name="rock" local unit={flags={}} local result,results,specials={},{},{} '..source:sub(a,b-1)..
 ' local gone=false for _,v in ipairs(specials) do if not gone then local b,reason=v[1],v[2] local bx,by=5,4 '..source:sub(c,d-1)..
 ' elseif reason=="weak" then '..source:sub(e,g-1)..' end end end end return result[1],gone end','@installed_virtual_unlock','t',env))()
local names={'open','shut','push','stop','pull','swap','still','weak','safe','float'}
local checked=0
for mask=0,1023 do for movermask=0,15 do for _,prior in ipairs({false,true}) do
 target={};for i,name in ipairs(names) do target[name]=math.floor(mask/2^(i-1))%2==1 end
 mover={open=movermask%2==1,shut=math.floor(movermask/2)%2==1,safe=math.floor(movermask/4)%2==1,float=movermask>=8}
 deleted,order={},{};if prior then deleted[4]=true end;local classification,gone=native(mover.open and 'shut' or mover.shut and 'open' or '')
 local behaviors={};for k,v in pairs(target) do behaviors[k=='stop' and 'block_entry' or k]=v end
 local w={width=8,height=8,entities={[-1]={id=-1,class='empty',x=4,y=4,behaviors=mover},[3]={id=3,x=6,y=4,behaviors={block_entry=true}}},
  empty_cells={['5:4']={x=5,y=4,behaviors=behaviors}},empty_deleted=prior and {['4:4']=true} or nil}
 local p=RW_ResolveMovement(w,{type='move',entity_id=-1,dx=1,dy=0})
 local moved=false;for _,op in ipairs(p.changes) do if op.entity_id==-1 and op.kind=='move' then moved=true end end
 assert(moved==(classification==0 and not gone),mask..':'..movermask)
 local deaths={};for _,death in ipairs(p.destructions or {}) do if not death.skip_inside then deaths[#deaths+1]=death end end;assert(#deaths==#order)
 for index,id in ipairs(order) do
  local death=deaths[index]
  assert(death.class=='empty')
  assert(death.x==id and death.y==4)
 end
 checked=checked+1
end end end
print('PASS: installed virtual EMPTY unlock, SAFE/FLOAT, WEAK non-deletion, source/target order and prior cell delete cache ('..checked..' cases)')
