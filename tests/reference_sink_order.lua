local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local features,blocks,tools=read('features.lua'),read('blocks.lua'),read('tools.lua')
local a=assert(features:find('function getunitswitheffect(',1,true));local b=assert(features:find('function getunitswithverb(',a,true));local selectors=features:sub(a,b-1)
a=assert(tools:find('function findallhere(',1,true));b=assert(tools:find('function findempty(',a,true));local maps=tools:sub(a,b-1)
a=assert(tools:find('function addunitmap(',1,true));b=assert(tools:find('function inside(',a,true));maps=maps..tools:sub(a,b-1)
local function bit(n,i)return math.floor(n/2^(i-1))%2==1 end
local cases=0
for _,kind in ipairs({'sink','weak','melt'}) do
local start=assert(blocks:find('local is'..kind..' =',1,true))
local finish=assert(blocks:find('delthese,doremovalsound = handledels(delthese,doremovalsound'..(kind=='sink' and ')' or ',true)'),start,true))
local body=blocks:sub(start,finish-1)
for newborn=0,(kind=='weak' and 1 or 0) do
for _,subjects in ipairs({{'rock','flag'},{'flag','rock'},{'rock','flag','rock'},{'flag','rock','flag'}}) do
for reverse=0,1 do for tile_reverse=0,1 do for positions=0,3 do for floats=0,7 do for safes=0,7 do
 local w=RW_CreateSession().world;w.entities={};w.width=20;w.height=12
 w.unit_order=reverse==1 and {13,12,11} or {11,12,13}
 local byid,stacks={},{};local names={'avatar','rock','flag'}
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,UNITTYPE=2,DEAD=1,SHAKE=1,roomsizex=20,unitmap={},unittypeshere={},unitlists={},featureindex={[kind]={}},delthese={},nlist={brief={}},generaldata={values={}}},{__index=_G})
 env.findnoun=function()return false end;env.testcond=function()return true end
 env.checkeffecthistory=function()return 1,'test' end;env.getcolour=function()return 0,3 end;env.MF_particles=function()end
 assert(load(selectors..maps,'@installed_sink_selectors','t',env))()
 for _,id in ipairs(w.unit_order) do local i=id-10;local name=names[i]
  local x=i==1 and 3 or (bit(positions,i-1) and 7 or 3)
  w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=3,direction='Left'}
  byid[id]={fixed=id,values={x,3},strings={name,'object'},flags={false},float=bit(floats,i),safe=bit(safes,i),new=newborn==1 and i==2}
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
 env.findfeature=function()return {{'avatar','is','hot'}} end
 env.findtype=function(rule,x,y)
  local result={};for _,id in ipairs(w.unit_order) do local e=w.entities[id]
   if e.archetype==rule[1] and e.x==x and e.y==y then result[#result+1]=id end
  end;return result
 end
 local effects={}
 for _,name in ipairs(subjects) do
  local ids={};for id,e in pairs(w.entities) do if e.archetype==name then ids[#ids+1]=id end end
  effects[#effects+1]={op='grant_trait',trait=kind,entity_ids=ids}
  env.featureindex[kind][#env.featureindex[kind]+1]={{name,'is',kind},{}}
 end
 for id,u in pairs(byid) do
  if u.float then effects[#effects+1]={op='grant_trait',trait='float',entity_ids={id}} end
  if u.safe then effects[#effects+1]={op='grant_trait',trait='safe',entity_ids={id}} end
 end
 if kind=='melt' then effects[#effects+1]={op='grant_trait',trait='hot',entity_ids={11}} end
 local projected=assert(RW_ProjectWorld(w,effects))
 if newborn==1 then projected.weak_new_ids={[12]=true} end
 assert(load(body,'@installed_'..kind..'_order','t',env))()
 -- Compare selected identities in first-encounter order; our HAS contract runs once per victim.
 local expected,seen={},{};for _,id in ipairs(env.delthese) do if not seen[id] then expected[#expected+1]=id;seen[id]=true end end
 local victims=assert(RW_ResolveContactVictims(projected,kind))
 assert(#victims==#expected,kind..' ordered count')
 for i,id in ipairs(victims) do assert(id==expected[i],kind..' ordered deletion') end
 assert(not w[kind..'_source_groups'],kind..' groups must stay transient')
 cases=cases+1
end end end end end end
end end
assert(cases==16384)
print('PASS: installed SINK/WEAK/MELT declaration/duplicate order, source/tile lists, SAFE/FLOAT/newborn grace and deletion sequence ('..cases..' cases)')
