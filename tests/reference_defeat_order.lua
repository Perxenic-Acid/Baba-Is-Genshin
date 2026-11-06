local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local features,blocks=read('features.lua'),read('blocks.lua')
local a=assert(features:find('function getunitswitheffect(',1,true));local b=assert(features:find('function getunitswithverb(',a,true));local selectors=features:sub(a,b-1)
a=assert(blocks:find('local isyou = getunitswitheffect("you",false,delthese)',1,true));b=assert(blocks:find('delthese,doremovalsound = handledels(delthese,doremovalsound)',a,true));local body=blocks:sub(a,b-1)
local function bit(n,i)return math.floor(n/2^(i-1))%2==1 end
local cases=0
for _,subjects in ipairs({{'rock','flag'},{'flag','rock'},{'rock','flag','rock'},{'flag','rock','flag'}}) do
for dual=0,1 do for reverse=0,1 do for positions=0,3 do for floats=0,7 do for safes=0,7 do for weak=0,7 do
 local w=RW_CreateSession().world;w.entities={};w.unit_order=reverse==1 and {13,12,11} or {11,12,13}
 local byid={};local names={'avatar','rock','flag'}
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,DEAD=1,SHAKE=1,unitlists={},featureindex={you={},you2={}},delthese={},nlist={brief={}},generaldata={values={}}},{__index=_G})
 env.findnoun=function()return false end;env.testcond=function()return true end
 env.checkeffecthistory=function()return 1,'test' end;env.MF_particles=function()end
 assert(load(selectors,'@installed_defeat_sources','t',env))()
 for _,id in ipairs(w.unit_order) do local i=id-10;local name=names[i]
  local x=i==1 and 3 or (bit(positions,i-1) and 7 or 3)
  w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=3,direction='Left'}
  byid[id]={fixed=id,values={x,3},strings={name},flags={false},float=bit(floats,i),safe=bit(safes,i),weak=bit(weak,i)}
  env.unitlists[name]=env.unitlists[name] or {};table.insert(env.unitlists[name],id)
 end
 env.mmf={newObject=function(id)return byid[id]end}
 env.floating=function(x,y)return byid[x].float==byid[y].float end;env.issafe=function(id)return byid[id].safe end
 env.hasfeature=function(_,_,_,id)return byid[id].weak and true or nil end
 env.findfeature=function()return {{'avatar','is','defeat'},{'flag','is','defeat'}} end
 env.findtype=function(rule,x,y)
  local result={};for _,id in ipairs(w.unit_order) do local e=w.entities[id]
   if e.archetype==rule[1] and e.x==x and e.y==y then result[#result+1]=id end
  end;return result
 end
 local effects={{op='grant_trait',trait='defeat',entity_ids={11,13}}}
 for index,name in ipairs(subjects) do
  local trait=dual==1 and index%2==1 and 'you2' or 'you'
  local ids={};for id,e in pairs(w.entities) do if e.archetype==name then ids[#ids+1]=id end end
  effects[#effects+1]={op='grant_trait',trait=trait,entity_ids=ids}
  env.featureindex[trait][#env.featureindex[trait]+1]={{name,'is',trait},{}}
 end
 for id,u in pairs(byid) do for _,trait in ipairs({'float','safe','weak'}) do
  if u[trait] then effects[#effects+1]={op='grant_trait',trait=trait,entity_ids={id}} end
 end end
 local projected=assert(RW_ProjectWorld(w,effects))
 assert(load(body,'@installed_defeat_order','t',env))()
 local expected,seen={},{};for _,id in ipairs(env.delthese) do if not seen[id] then expected[#expected+1]=id;seen[id]=true end end
 local victims=assert(RW_ResolveContactVictims(projected,'defeat'))
 assert(#victims==#expected,'DEFEAT victim count')
 for i,id in ipairs(victims) do assert(id==expected[i],'DEFEAT YOU-before-YOU2 declaration order') end
 cases=cases+1
end end end end end end end
assert(cases==32768)
print('PASS: installed DEFEAT YOU/YOU2 declaration/unit order, duplicates, SAFE/FLOAT, unsafe WEAK hazards and self defeat ('..cases..' cases)')
