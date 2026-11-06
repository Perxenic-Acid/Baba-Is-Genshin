local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local features,blocks=read('features.lua'),read('blocks.lua')
local a=assert(features:find('function getunitswitheffect(',1,true));local b=assert(features:find('function getunitswithverb(',a,true));local selectors=features:sub(a,b-1)
a=assert(blocks:find('local ismore =',1,true));b=assert(blocks:find('local isplay =',a,true))
local body=blocks:sub(a,b-1):gsub(string.char(10)..string.char(9)..'end%s*$','')
local function bit(n,i)return math.floor(n/2^(i-1))%2==1 end
local cases=0
for _,sources in ipairs({{11,12},{12,11},{11,12,11},{12,11,12}}) do
for reverse=0,1 do for layout=1,3 do for blockers=0,63 do for text=0,1 do
 local w=RW_CreateSession().world;w.entities={};w.width=9;w.height=9;w.unit_order=reverse==1 and {12,11} or {11,12}
 local units,births={},{};local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,DEAD=1,roomsizex=9,unitlists={},featureindex={more={}},delthese={},nlist={brief={}},ndirs={{1,0},{0,-1},{-1,0},{0,1}}},{__index=_G})
 env.findnoun=function()return false end;env.testcond=function(c,id)return c.only==nil or c.only==id end
 assert(load(selectors,'@installed_more_sources','t',env))()
 for _,id in ipairs(w.unit_order) do
  local name=id==11 and 'rock' or 'flag';local x,y=3,3
  if id==12 then if layout==2 then x=5 elseif layout==3 then y=5 end end
  w.entities[id]={id=id,kind='object',class=text==1 and 'text' or 'object',archetype=text==0 and name or nil,text=text==1 and {name=name:upper()} or nil,x=x,y=y,direction=id==11 and 'Right' or 'Up'}
  units[id]={fixed=id,values={x,y},strings={text==1 and 'text_'..name or name},flags={false},direction=w.entities[id].direction}
  local source_name=text==1 and 'text' or name;env.unitlists[source_name]=env.unitlists[source_name] or {};table.insert(env.unitlists[source_name],id)
  for i,trait in ipairs({'stop','push','pull'}) do units[id][trait]=bit(blockers,(id-11)*3+i) end
 end
 env.mmf={newObject=function(id)return units[id]end}
 env.findobstacle=function(x,y)
  if x<1 or x>9 or y<1 or y>9 then return {-1} end
  local r={};for id,u in pairs(units) do if u.values[1]==x and u.values[2]==y then r[#r+1]=id end end;return r
 end
 env.hasfeature=function(_,_,trait,id)return units[id] and units[id][trait] and true or nil end
 env.copy=function(id,x,y)
  local source=units[id];local copy={fixed=20+#births,values={x,y},strings={source.strings[1]},direction=source.direction}
  for _,trait in ipairs({'stop','push','pull'}) do copy[trait]=source[trait] end
  units[copy.fixed]=copy;births[#births+1]=copy;return copy
 end
 local effects={}
 for _,id in ipairs(sources) do
  effects[#effects+1]={op='grant_trait',trait='more',entity_ids={id}}
  local name=text==1 and 'text' or w.entities[id].archetype
  env.featureindex.more[#env.featureindex.more+1]={{name,'is','more'},{only=id}}
 end
 for _,id in ipairs(w.unit_order) do for _,trait in ipairs({'stop','push','pull'}) do
  if units[id][trait] then effects[#effects+1]={op='grant_trait',trait=trait=='stop' and 'block_entry' or trait=='push' and 'pushable' or trait,entity_ids={id}} end
 end end
 local projected=assert(RW_ProjectWorld(w,effects));assert(load(body,'@installed_more_order','t',env))()
 local products=RW_ResolveMoreProducts(projected)
 assert(#products==#births,'MORE ordered count '..cases..' '..#products..'/'..#births)
 for i,p in ipairs(products) do
  local name=p.class=='text' and 'text_'..p.text.name:lower() or p.archetype;local expected=births[i]
  assert(name==expected.strings[1] and p.x==expected.values[1] and p.y==expected.values[2] and p.direction==expected.direction,'MORE ordered product')
 end
 assert(not w.more_source_groups,'MORE groups must stay transient');cases=cases+1
end end end end end
assert(cases==3072)
print('PASS: installed MORE source declaration order, duplicates, competing Object/Text growth, STOP/PUSH/PULL and product sequence ('..cases..' cases)')
