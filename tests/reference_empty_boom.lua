-- Installed levelblock EMPTY BOOM body plus the real floating() helper.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a'):gsub('\r\n','\n');f:close();return s end
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local source=read(base..'blocks.lua');local a=assert(source:find('if emptyboom then',1,true));local b=assert(source:find('local alive = true',a,true))
local tools=read(base..'tools.lua');local c=assert(tools:find('function floating(',1,true));local d=assert(tools:find('function floating_level(',c,true))
local units,n,emptyfloat
local env=setmetatable({roomsizex=14,roomsizey=14,FLOAT='float'},{__index=_G})
env.mmf={newObject=function(id) return {values={float=units[id].behaviors.float and 1 or 0}} end}
env.hasfeature=function(name,_,trait,_,x,y) if name=='empty' and trait=='float' and emptyfloat and units[1].x==x and units[1].y==y then return true end end
env.hasfeature_count=function() return n end
env.inbounds=function(x,y) return x>=1 and x<=12 and y>=1 and y<=12 end
env.findallhere=function(x,y) local ids={};for id,e in pairs(units) do if e.x==x and e.y==y then ids[#ids+1]=id end end;return ids end
env.issafe=function(id) return units[id].behaviors.safe end
env.checkeffecthistory=function() return 1,false end;env.MF_particles=function() end;env.setsoundname=function() end
assert(load(tools:sub(c,d-1),'@installed_floating','t',env))()
local boom=assert(load('return function(i,j,esafe,delthese,edelthese) local emptyboom=true '..source:sub(a,b-1)..' end','@installed_empty_boom','t',env))()
local cases=0
for count=1,4 do for _,offset in ipairs({{1,0},{1,1},{2,0},{3,2},{4,0}}) do
for mask=0,31 do for sources=1,2 do
 local safe=mask%2==1;local victim_safe=math.floor(mask/2)%2==1
 local layer=math.floor(mask/4)%2==1;emptyfloat=math.floor(mask/8)%2==1
 local sourcefloat=math.floor(mask/16)%2==1;n=count
 units={[1]={id=1,kind='object',class='object',archetype='rock',x=5+offset[1],y=5+offset[2],direction='Left',behaviors={safe=victim_safe,float=layer}}}
 env.unitmap={[units[1].x+units[1].y*14]={1}}
 local real,virtual={},{};local projected={entities=units,empty_cells={}}
 for i=1,sources do
  local cell={x=5,y=4+i,behaviors={boom=true,safe=safe,float=sourcefloat},trait_counts={boom=count}}
  projected.empty_cells[cell.x..':'..cell.y]=cell;boom(cell.x,cell.y,safe,real,virtual)
 end
 local w=RW_CreateSession().world;w.width,w.height=12,12;w.entities=units;w.rule_sources={}
 local rules={}
 if emptyfloat then rules[1]={when={op='spatial',clauses={{relation='on',negated=false,parameters={{tag='noun',type={tag='object',name='rock'}}}}}},effects={{op='grant_trait',trait='float',target={kind='empty',value='empty'}}}} end
 local actual,why=RW_ResolveEmptyBoom(w,projected,rules);assert(actual,why)
 assert(#actual.ids==#real and #actual.cells==#virtual,table.concat({count,offset[1],offset[2],mask,sources},':'))
 if #real>0 then assert(actual.ids[1]==1) end
 assert(not w._condition_rules and not w._condition_guard and w.next_entity_id)
 cases=cases+1
end end end end
print('PASS: installed EMPTY BOOM radius/diagonals/SAFE/duplicates and victim-coordinate FLOAT ('..cases..' cases)')