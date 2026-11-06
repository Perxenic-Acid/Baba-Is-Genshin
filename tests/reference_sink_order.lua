local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local features,blocks,tools=read('features.lua'),read('blocks.lua'),read('tools.lua')
local a=assert(features:find('function getunitswitheffect(',1,true));local b=assert(features:find('function getunitswithverb(',a,true));local selectors=features:sub(a,b-1)
a=assert(blocks:find('local issink =',1,true));b=assert(blocks:find('delthese,doremovalsound = handledels(delthese,doremovalsound)',a,true));local sink=blocks:sub(a,b-1)
a=assert(tools:find('function findallhere(',1,true));b=assert(tools:find('function findempty(',a,true));local maps=tools:sub(a,b-1)
a=assert(tools:find('function addunitmap(',1,true));b=assert(tools:find('function inside(',a,true));maps=maps..tools:sub(a,b-1)
local function bit(n,i)return math.floor(n/2^(i-1))%2==1 end
local cases=0
for _,subjects in ipairs({{'rock','flag'},{'flag','rock'},{'rock','flag','rock'},{'flag','rock','flag'}}) do
for reverse=0,1 do for tile_reverse=0,1 do for positions=0,3 do for floats=0,7 do for safes=0,7 do
 local w=RW_CreateSession().world;w.entities={};w.width=20;w.height=12
 w.unit_order=reverse==1 and {13,12,11} or {11,12,13}
 local byid,stacks={},{};local names={'avatar','rock','flag'}
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,DEAD=1,SHAKE=1,roomsizex=20,unitmap={},unittypeshere={},unitlists={},featureindex={sink={}},delthese={},nlist={brief={}},generaldata={values={}}},{__index=_G})
 env.findnoun=function()return false end;env.testcond=function()return true end
 env.checkeffecthistory=function()return 1,'test' end;env.getcolour=function()return 0,3 end;env.MF_particles=function()end
 assert(load(selectors..maps,'@installed_sink_selectors','t',env))()
 for _,id in ipairs(w.unit_order) do local i=id-10;local name=names[i]
  local x=i==1 and 3 or (bit(positions,i-1) and 7 or 3)
  w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=3,direction='Left'}
  byid[id]={fixed=id,values={x,3},strings={name},flags={false},float=bit(floats,i),safe=bit(safes,i)}
  env.unitlists[name]=env.unitlists[name] or {};table.insert(env.unitlists[name],id)
  local k=x..':3';stacks[k]=stacks[k] or {};table.insert(stacks[k],tile_reverse==1 and 1 or #stacks[k]+1,id)
 end
 w.cell_order={}
 for k,stack in pairs(stacks) do
  if tile_reverse==1 and #stack>1 then w.cell_order[k]=stack end
  for _,id in ipairs(stack) do local e=w.entities[id];env.addunitmap(id,e.x,e.y,e.archetype)end
 end
 env.mmf={newObject=function(id)return byid[id]end};env.getunitid=function(id)return id end
 env.floating=function(x,y)return byid[x].float==byid[y].float end;env.issafe=function(id)return byid[id].safe end
 local effects={}
 for _,name in ipairs(subjects) do
  local ids={};for id,e in pairs(w.entities) do if e.archetype==name then ids[#ids+1]=id end end
  effects[#effects+1]={op='grant_trait',trait='sink',entity_ids=ids}
  env.featureindex.sink[#env.featureindex.sink+1]={{name,'is','sink'},{}}
 end
 for id,u in pairs(byid) do
  if u.float then effects[#effects+1]={op='grant_trait',trait='float',entity_ids={id}} end
  if u.safe then effects[#effects+1]={op='grant_trait',trait='safe',entity_ids={id}} end
 end
 local projected=assert(RW_ProjectWorld(w,effects))
 assert(load(sink,'@installed_sink_order','t',env))()
 local victims=assert(RW_ResolveContactVictims(projected,'sink'))
 assert(#victims==#env.delthese,'SINK ordered count')
 for i,id in ipairs(victims) do assert(id==env.delthese[i],'SINK ordered deletion') end
 assert(not w.sink_source_groups,'SINK groups must stay transient')
 cases=cases+1
end end end end end end
assert(cases==4096)
print('PASS: installed SINK declaration/duplicate order, source/tile lists, SAFE/FLOAT and deletion sequence ('..cases..' cases)')
