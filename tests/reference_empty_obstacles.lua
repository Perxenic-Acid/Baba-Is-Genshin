-- Installed check() EMPTY solidity and cantmove(), with lifecycle specials absent.
dofile('external_lua_file/movement.lua')
local function read(name)
 local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]..name..'.lua','rb'))
 local s=f:read('*a'):gsub('\r\n','\n');f:close();return s
end
local source=read('movement');local a=assert(source:find('local emptystop =',1,true))
local b=assert(source:find('\n\tend\n\t\n\tif (#results == 0)',a,true))
local tools=read('tools');local c=assert(tools:find('function cantmove(',1,true));local d=assert(tools:find('function findnoun(',c,true))
local current,count
local env=setmetatable({featureindex={}},{__index=_G})
env.hasfeature=function(name,_,trait) return name=='empty' and current[trait] and true or nil end
env.floating_level=function() return false end
env.reversecheck=function(_,dir) return (dir+2*(count%2))%4 end
assert(load(tools:sub(c,d-1),'@installed_cantmove','t',env))()
local native=assert(load('return function(dir_) local x,y,ox,oy=4,4,1,0 local pulling=false local eat=nil local lockpartner="" '..
 'local unitid=100 local name="rock" local result,results,specials={},{},{} '..source:sub(a,b-1)..' return result[1] end','@installed_empty_obstacles','t',env))()
local names={'push','stop','pull','swap','still','lockedright','lockedup','lockedleft','lockeddown','sleep'}
local vectors={{1,0},{0,-1},{-1,0},{0,1}}
local checked=0
for mask=0,1023 do for reverse=0,2 do for dir=0,3 do
 current={};for i,name in ipairs(names) do current[name]=math.floor(mask/2^(i-1))%2==1 end
 count=reverse;current.reverse=reverse>0;env.featureindex.reverse=reverse>0 and {} or nil
 local classification=native(dir)
 for _,obstructed in ipairs({false,true}) do
  local dx,dy=table.unpack(vectors[dir+1]);local nx,ny=4+dx,4+dy
  local behaviors={};for k,v in pairs(current) do behaviors[k=='stop' and 'block_entry' or k]=v end
  local w={width=8,height=8,entities={[1]={id=1,x=4,y=4,direction='None',behaviors={}}},
   empty_cells={[nx..':'..ny]={x=nx,y=ny,behaviors=behaviors,trait_counts={reverse=reverse}}}}
  if obstructed then w.entities[2]={id=2,x=nx+dx,y=ny+dy,behaviors={block_entry=true}} end
  local p=RW_ResolveMovement(w,{type='move',entity_id=1,dx=dx,dy=dy})
  local moved=false;for _,op in ipairs(p.changes) do if op.entity_id==1 and op.kind=='move' then moved=true end;assert(op.entity_id>0) end
  assert(moved==(classification==0 or classification==2 and not obstructed),table.concat({mask,reverse,dir,tostring(obstructed)},':'))
  assert(w.entities[1].x==4 and w.entities[1].y==4)
  checked=checked+1
 end
end end end
print('PASS: installed EMPTY STOP/PUSH/PULL/SWAP, STILL/directional locks, REVERSE parity, SLEEP and downstream blockers ('..checked..' cases)')
