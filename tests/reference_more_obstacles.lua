local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local tools,blocks=read('tools.lua'),read('blocks.lua')
local function section(s,a,b)local first=assert(s:find('function '..a..'(',1,true));local last=assert(s:find('function '..b..'(',first,true));return s:sub(first,last-1)end
local maps=section(tools,'findobstacle','update')..section(tools,'addunitmap','inside')
local a=assert(blocks:find('local ismore =',1,true));local b=assert(blocks:find('local isplay =',a,true))
local body=blocks:sub(a,b-1):gsub(string.char(10)..string.char(9)..'end%s*$','')
local permutations={{14,15,16},{14,16,15},{15,14,16},{15,16,14},{16,14,15},{16,15,14}}
local cases=0
for _,stack in ipairs(permutations) do for reverse=0,1 do for explicit=0,1 do for mask=0,7 do for copyblock=0,1 do
 local w=RW_CreateSession().world;w.width=9;w.height=9;w.next_entity_id=20;w.entities={}
 w.unit_order=reverse==0 and {11,12,14,15,16} or {16,15,14,12,11}
 for _,spec in ipairs({{11,'rock',3},{12,'flag',5},{14,'water',4},{15,'skull',4},{16,'crate',4}}) do
  local id=spec[1];w.entities[id]={id=id,kind='object',class='object',archetype=spec[2],x=spec[3],y=3,direction='Up'}
 end
 if explicit==1 then w.cell_order={['4:3']=stack}end
 local units,births,expected,actual={},{},{},{}
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,DEAD=1,roomsizex=9,unitmap={},unittypeshere={},map={[0]={get_x=function()return 255 end}},ndirs={{1,0},{0,-1},{-1,0},{0,1}},delthese={}},{__index=_G})
 env.inbounds=function(x,y)return x>=1 and y>=1 and x<=9 and y<=9 end
 env.mmf={newObject=function(id)return units[id]end}
 assert(load(maps,'@installed_MORE_obstacle_maps','t',env))()
 for id,e in pairs(w.entities) do units[id]={fixed=id,values={e.x,e.y},strings={e.archetype},flags={false},direction=e.direction}end
 for _,id in ipairs(w.unit_order) do if explicit==0 or id<14 then local e=w.entities[id];env.addunitmap(id,e.x,e.y,e.archetype)end end
 if explicit==1 then for _,id in ipairs(stack) do local e=w.entities[id];env.addunitmap(id,e.x,e.y,e.archetype)end end
 local function block(id,name,trait)
  if name=='rock' and trait=='push' then return copyblock==1 end
  local selected=id and id>=14 and id<=16 and math.floor(mask/2^(id-14))%2==1
  return selected and trait==({'stop','push','pull'})[id-13] or false
 end
 env.getunitswitheffect=function()return {units[11],units[12]}end
 env.hasfeature=function(name,_,trait,id,x,y)
  if trait=='stop' then expected[#expected+1]=id==2 and ('empty:'..x..':'..y) or id end
  return block(id,name,trait) and true or nil
 end
 env.copy=function(id,x,y)
  local source=units[id];local p={fixed=20+#births,values={x,y},strings={source.strings[1]},flags={false},direction=source.direction}
  births[#births+1]=p;units[p.fixed]=p;env.addunitmap(p.fixed,x,y,p.strings[1]);return p
 end
 local effects={{op='grant_trait',trait='more',entity_ids={11}},{op='grant_trait',trait='more',entity_ids={12}}}
 local projected=assert(RW_ProjectWorld(w,effects))
 local products=assert(RW_ResolveMoreProducts(projected,{
  initialize=function(context,p)return RW_InitializeBirthSpecifications(context,p,{})end,
  obstacle=function(context,e)
   actual[#actual+1]=e.id or ('empty:'..e.x..':'..e.y)
   return block(e.id,e.archetype,'stop') or block(e.id,e.archetype,'push') or block(e.id,e.archetype,'pull')
  end}))
 assert(load(body,'@installed_MORE_obstacle_order','t',env))()
 assert(#actual==#expected,'MORE obstacle query count '..cases)
 for i,id in ipairs(expected)do assert(actual[i]==id,'MORE obstacle query order '..cases..' at '..i)end
 assert(#products==#births);for i,p in ipairs(products)do local e=births[i];assert(p.archetype==e.strings[1] and p.x==e.values[1] and p.y==e.values[2])end
 assert(w.next_entity_id==20 and (not w.cell_order or w.cell_order['4:3']==stack))
 cases=cases+1
end end end end end
assert(cases==384)
print('PASS: installed MORE/findobstacle/addunitmap query order, global/explicit stacks, blocker short circuit, newborn arrivals and products ('..cases..' cases)')
