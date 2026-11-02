dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('local emptystop =',1,true));local b=assert(source:find('\n\tend\n\t\n\tif (#results == 0)',a,true))
local c=assert(source:find('if (b == 2) and (unitid ~= 2) then',b,true));local d=assert(source:find('\n\t\t\t\t\tend',c,true))
local current,moverfloat,deletes
local env=setmetatable({generaldata={values={}},SHAKE='shake'},{__index=_G})
env.hasfeature=function(name,_,trait) return name=='empty' and current[trait] and true or nil end
env.cantmove=function() return current.still==true end
env.issafe=function() return current.safe==true end
env.floating=function() return (current.float==true)==moverfloat end
env.checkeffecthistory=function() return 1,'' end;env.MF_particles=function() end;env.setsoundname=function() end
env.delete=function() deletes=deletes+1 end
local native=assert(load('return function(unitid) local x,y,ox,oy,dir_=4,4,1,0,0 local pulling=false local eat=nil local lockpartner="" '..
 'local name="rock" local result,results,specials={},{},{} '..source:sub(a,b-1)..
 ' for _,v in ipairs(specials) do local b=v[1] local bx,by=5,4 '..source:sub(c,d-1)..' end end return result[1] end','@installed_empty_weak','t',env))()
local names={'push','stop','pull','swap','still','weak','safe','float'}
local checked=0
for mask=0,255 do for _,layer in ipairs({false,true}) do for _,virtual in ipairs({false,true}) do
 current={};for i,name in ipairs(names) do current[name]=math.floor(mask/2^(i-1))%2==1 end
 moverfloat=layer;deletes=0;local classification=native(virtual and 2 or 100)
 for _,obstructed in ipairs({false,true}) do
  local id=virtual and -1 or 1;local behaviors={};for k,v in pairs(current) do behaviors[k=='stop' and 'block_entry' or k]=v end
  local w={width=8,height=8,entities={[id]={id=id,class=virtual and 'empty' or 'object',x=4,y=4,behaviors={float=layer}}},
   empty_cells={['5:4']={x=5,y=4,behaviors=behaviors}}}
  if obstructed then w.entities[2]={id=2,x=6,y=4,behaviors={block_entry=true}} end
  local p=RW_ResolveMovement(w,{type='move',entity_id=id,dx=1,dy=0})
  local moved=false;for _,op in ipairs(p.changes) do if op.entity_id==id and op.kind=='move' then moved=true end end
  assert(moved==(classification==0 or classification==2 and not obstructed))
  assert(#(p.destructions or {})==(moved and deletes or 0),table.concat({mask,tostring(layer),tostring(virtual)},':'))
  if deletes>0 and moved then assert(p.destructions[1].class=='empty' and p.destructions[1].x==5 and p.destructions[1].y==4) end
  checked=checked+1
 end
end end end
print('PASS: installed EMPTY WEAK collision and real-vs-virtual move deletion, solidity/SAFE/FLOAT/STILL ('..checked..' cases)')
