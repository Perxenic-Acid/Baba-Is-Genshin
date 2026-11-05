local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local features,blocks,tools=read('features.lua'),read('blocks.lua'),read('tools.lua')
local a=assert(features:find('function getunitswitheffect(',1,true));local b=assert(features:find('function getunitswithverb(',a,true));local select_sources=features:sub(a,b-1)
a=assert(blocks:find('local ishold =',1,true));b=assert(blocks:find('local issink =',a,true));local hold=blocks:sub(a,b-1)
a=assert(tools:find('function findallhere(',1,true));b=assert(tools:find('function findempty(',a,true));local maps=tools:sub(a,b-1)
a=assert(tools:find('function addunitmap(',1,true));b=assert(tools:find('function inside(',a,true));maps=maps..tools:sub(a,b-1)
local function noun(n)return {tag='noun',type={tag='object',name=n}}end
local cases=0
for _,subjects in ipairs({{'rock','flag'},{'flag','rock'},{'rock','flag','rock'},{'flag','rock','flag'}}) do
for reverse=0,1 do for tile_reverse=0,1 do for positions=0,15 do for floats=0,15 do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=20;w.width=20;w.height=12
 w.unit_order=reverse==1 and {14,13,12,11} or {11,12,13,14}
 local units,byid,stacks={},{},{};local names={'avatar','rock','flag','rock'}
 local env=setmetatable({XPOS=1,YPOS=2,DIR=3,ID=4,UNITNAME=1,DEAD=1,roomsizex=20,unitmap={},unittypeshere={},unitlists={},featureindex={hold={}},delthese={},nlist={brief={}}},{__index=_G})
 env.findnoun=function()return false end;env.testcond=function()return true end;env.addundo=function()end
 assert(load(select_sources..maps,'@installed_hold_selectors','t',env))()
 for _,id in ipairs(w.unit_order) do local i=id-10;local name=names[i]
  local x=math.floor(positions/2^(i-1))%2==1 and 7 or 3
  local float=math.floor(floats/2^(i-1))%2==1
  w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=3,direction='Left',holder=id==11 and 14 or 0}
  local u={fixed=id,values={x,3,2,id},strings={name},flags={false},holder=w.entities[id].holder,float=float}
  units[#units+1]=u;byid[id]=u
  env.unitlists[name]=env.unitlists[name] or {};table.insert(env.unitlists[name],id)
  local k=x..':3';stacks[k]=stacks[k] or {};table.insert(stacks[k],tile_reverse==1 and 1 or #stacks[k]+1,id)
 end
 w.cell_order={}
 for k,stack in pairs(stacks) do
  if tile_reverse==1 and #stack>1 then w.cell_order[k]=stack end
  for _,id in ipairs(stack) do local e=w.entities[id];env.addunitmap(id,e.x,e.y,e.archetype)end
 end
 env.units=units;env.mmf={newObject=function(id)return byid[id]end};env.getunitid=function(id)return id end
 env.getname=function(u)return u.strings[1]end;env.floating=function(x,y)return byid[x].float==byid[y].float end
 env.cantmove=function()return false end
 env.update=function(id,x,y,d)local u=byid[id]
  if u.values[1]~=x or u.values[2]~=y then env.updateunitmap(id,u.values[1],u.values[2],x,y,u.strings[1])end
  u.values[1],u.values[2],u.values[3]=x,y,d
 end
 local ast={}
 for _,name in ipairs(subjects) do
  ast[#ast+1]={subject=noun(name),verb='is',object={tag='property',name='hold'},when={op='always'}}
  env.featureindex.hold[#env.featureindex.hold+1]={{name,'is','hold'},{}}
 end
 -- Exact per-identity FLOAT fixture uses evaluated effects, independent of noun grants.
 local rules=assert(RW_LowerRuleAST(ast,nil,w));local effects=assert(RW_EvaluateRules(w,rules))
 for id,u in pairs(byid) do if u.float then effects[#effects+1]={op='grant_trait',trait='float',entity_ids={id}} end end
 local projected=assert(RW_ProjectWorld(w,effects));local plan=assert(RW_ResolveHold(projected))
 assert(load(hold,'@installed_hold_declaration_order','t',env))()
 local result=assert(RW_PreviewPlan(w,plan))
 for id,u in pairs(byid) do local e=result.entities[id]
  assert(e.x==u.values[1] and e.y==u.values[2] and (e.holder or 0)==u.holder,'HOLD declaration dispatch mismatch')
 end
 if #plan.changes>0 then local committed,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(committed).world==w) end
 assert(not result.hold_source_groups,'HOLD declaration projection must stay transient')
 cases=cases+1
end end end end end
assert(cases==4096)
print('PASS: installed HOLD physical declaration/duplicate order, global/tile traversal, FLOAT, cycles, holder memory and Undo ('..cases..' cases)')
