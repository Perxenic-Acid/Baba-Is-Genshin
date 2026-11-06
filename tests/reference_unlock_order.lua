local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local features,blocks=read('features.lua'),read('blocks.lua')
local a=assert(features:find('function getunitswitheffect(',1,true));local b=assert(features:find('function getunitswithverb(',a,true));local selectors=features:sub(a,b-1)
a=assert(blocks:find('local isshut =',1,true));b=assert(blocks:find('delthese,doremovalsound = handledels(delthese,doremovalsound)',a,true));local body=blocks:sub(a,b-1)
local function bit(n,i)return math.floor(n/2^(i-1))%2==1 end
local cases=0
for _,subjects in ipairs({{'rock','flag'},{'flag','rock'},{'rock','flag','rock'},{'flag','rock','flag'}}) do
for _,keygroups in ipairs({{{13,14}},{{14},{13}},{{13},{14}},{{13,14},{13,14}}}) do
for reverse=0,1 do for tile_reverse=0,1 do for positions=0,3 do for floats=0,7 do for safes=0,7 do
 local w=RW_CreateSession().world;w.entities={};w.unit_order=reverse==1 and {14,13,12,11} or {11,12,13,14}
 local byid,stacks={},{};local names={'rock','flag','key','key'}
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,DEAD=1,SHAKE=1,unitlists={},featureindex={shut={}},delthese={},nlist={brief={}},generaldata={values={}}},{__index=_G})
 env.findnoun=function()return false end;env.testcond=function()return true end
 env.checkeffecthistory=function()return 1,'test' end;env.MF_particles=function()end;env.setsoundname=function()end
 assert(load(selectors,'@installed_unlock_sources','t',env))()
 for _,id in ipairs(w.unit_order) do local i=id-10;local name=names[i]
  local x=i<3 and 3 or (bit(positions,i-2) and 7 or 3)
  w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=3,direction='Left'}
  byid[id]={fixed=id,values={x,3},strings={name},flags={false},float=bit(floats,i),safe=bit(safes,i)}
  env.unitlists[name]=env.unitlists[name] or {};table.insert(env.unitlists[name],id)
  local key=x..':3';stacks[key]=stacks[key] or {};table.insert(stacks[key],tile_reverse==1 and 1 or #stacks[key]+1,id)
 end
 w.cell_order=stacks
 env.mmf={newObject=function(id)return byid[id]end}
 env.floating=function(x,y)return byid[x].float==byid[y].float end;env.issafe=function(id)return byid[id].safe end
 -- Normalize each OPEN clause's condition to its matching identities; keep clauses separate.
 env.findfeature=function()local r={};for _,g in ipairs(keygroups) do r[#r+1]={'key',g} end;return r end
 env.findtype=function(rule,x,y)
  local eligible={};for _,id in ipairs(rule[2]) do eligible[id]=true end
  local result={};for _,id in ipairs(stacks[x..':'..y] or {}) do if eligible[id] then result[#result+1]=id end end;return result
 end
 local effects={}
 for _,name in ipairs(subjects) do
  local ids={};for id,e in pairs(w.entities) do if e.archetype==name then ids[#ids+1]=id end end
  effects[#effects+1]={op='grant_trait',trait='shut',entity_ids=ids}
  env.featureindex.shut[#env.featureindex.shut+1]={{name,'is','shut'},{}}
 end
 for _,ids in ipairs(keygroups) do effects[#effects+1]={op='grant_trait',trait='open',entity_ids=ids} end
 for id,u in pairs(byid) do for _,trait in ipairs({'float','safe'}) do
  if u[trait] then effects[#effects+1]={op='grant_trait',trait=trait,entity_ids={id}} end
 end end
 local projected=assert(RW_ProjectWorld(w,effects))
 assert(load(body,'@installed_unlock_order','t',env))()
 local expected,seen={},{};for _,id in ipairs(env.delthese) do if not seen[id] then expected[#expected+1]=id;seen[id]=true end end
 local victims=assert(RW_ResolveContactVictims(projected,'unlock'))
 assert(#victims==#expected,'unlock physical clause victim count')
 for i,id in ipairs(victims) do assert(id==expected[i],'unlock declaration/tile victim order') end
 cases=cases+1
end end end end end end end
assert(cases==16384)
print('PASS: installed OPEN/SHUT declaration/tile order, separate same-name conditional clauses, duplicates, SAFE/FLOAT and deletion sequence ('..cases..' cases)')
