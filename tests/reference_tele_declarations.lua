local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local features,tools,blocks=read('features.lua'),read('tools.lua'),read('blocks.lua')
local function section(s,first,last)local a=assert(s:find('function '..first..'(',1,true));local b=assert(s:find('function '..last..'(',a+1,true));return s:sub(a,b-1)end
local selectors=section(features,'findallfeature','getunitswitheffect')..section(tools,'findall','delunit')..section(tools,'findallhere','findempty')..section(tools,'addunitmap','inside')
local a=assert(blocks:find('for i,unitid in ipairs(istele) do',1,true));local b=assert(blocks:find('for a,unitid in ipairs(isshift) do',a,true));local tele=blocks:sub(a,b-1)
local patterns={{'rock','rock13'},{'rock13','rock'},{'rock','flag','rock13'},{'flag','rock','rock13'},{'rock13','rock13','rock'}}
local cases=0
for _,pattern in ipairs(patterns) do for reverse=0,1 do for tile_reverse=0,1 do for seed=1,16 do for floats=0,3 do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=20;w.width=20;w.height=12;w.random_state=seed
 w.unit_order=reverse==1 and {17,16,15,14,13,12,11} or {11,12,13,14,15,16,17}
 local specs={{'avatar',3},{'rock',3},{'rock',7},{'rock',11},{'flag',3},{'flag',15},{'avatar',3}}
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,UNITTYPE=2,DEAD=1,roomsizex=20,unitmap={},unittypeshere={},unitlists={},objectdata={}}, {__index=_G})
 assert(load(selectors,'@installed_tele_declaration_selectors','t',env))()
 local byid,stacks={},{ }
 for _,id in ipairs(w.unit_order) do local spec=specs[id-10];local name,x=spec[1],spec[2]
  w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=3,direction='Left'}
  byid[id]={fixed=id,values={x,3},strings={name,'object'},flags={false},float=id==11 and floats%2==1 or id==13 and floats>=2}
  env.unitlists[name]=env.unitlists[name] or {};table.insert(env.unitlists[name],id)
  local k=x..':3';stacks[k]=stacks[k] or {};table.insert(stacks[k],tile_reverse==1 and 1 or #stacks[k]+1,id)
 end
 w.cell_order={}
 for k,stack in pairs(stacks) do
  if tile_reverse==1 and #stack>1 then w.cell_order[k]=stack end
  for _,id in ipairs(stack) do local e=w.entities[id];env.addunitmap(id,e.x,e.y,e.archetype) end
 end
 env.mmf={newObject=function(id)return byid[id]end};env.getname=function(u)return u.strings[1]end
 env.testcond=function(conds,id)return not conds.allowed or conds.allowed[id]==true end
 local rows,effects={},{}
 for _,entry in ipairs(pattern) do
  local name=entry=='rock13' and 'rock' or entry;local conds=entry=='rock13' and {allowed={[13]=true}} or {}
  rows[#rows+1]={name,conds};local ids={}
  for _,id in ipairs(w.unit_order) do if w.entities[id].archetype==name and env.testcond(conds,id) then ids[#ids+1]=id end end
  effects[#effects+1]={op='grant_trait',trait='tele',entity_ids=ids}
 end
 env.findfeature=function()return rows end
 for id,u in pairs(byid) do if u.float then effects[#effects+1]={op='grant_trait',trait='float',entity_ids={id}} end end
 local projected=assert(RW_ProjectWorld(w,effects));local sources=env.findallfeature(nil,'is','tele',true)
 local actual_sources={};for _,group in ipairs(projected.tele_source_groups) do for _,id in ipairs(group) do actual_sources[#actual_sources+1]=id end end
 assert(#sources==#actual_sources);for i,id in ipairs(sources) do assert(actual_sources[i]==id,'TELE declaration source order/multiplicity') end
 local state=seed;local arrivals={}
 env.isgone=function()return false end;env.hasfeature=function()return nil end
 env.floating=function(x,y)return byid[x].float==byid[y].float end
 env.fixedrandom=function(lo,hi)state=(state*48271)%2147483647;return lo+state%(hi-lo+1)end
 env.update=function(id,x,y)local u=byid[id]
  if u.values[1]~=x or u.values[2]~=y then env.updateunitmap(id,u.values[1],u.values[2],x,y,u.strings[1]);arrivals[#arrivals+1]=id end
  u.values={x,y}
 end
 env.checkeffecthistory=function()return 1,0 end;env.MF_particles=function()end;env.setsoundname=function()end
 assert(load('return function(istele) '..tele..' end','@installed_weighted_tele','t',env))()(sources)
 local plan=assert(RW_ResolveTele(projected));local result=assert(RW_PreviewPlan(w,plan))
 for id,u in pairs(byid) do assert(result.entities[id].x==u.values[1] and result.entities[id].y==u.values[2],'TELE weighted destination mismatch') end
 assert((plan.random_state and plan.random_state.to or seed)==state,'TELE weighted RNG mismatch')
 assert(#arrivals==#(plan.motion_history or {}));for i,id in ipairs(arrivals) do assert(plan.motion_history[i].entity_id==id,'TELE weighted arrival dispatch') end
 assert(not result.tele_source_groups,'TELE groups must remain transient')
 local committed,r=RW_Commit(s,plan);if #plan.changes>0 or plan.random_state then assert(r.accepted,r.reason);assert(RW_Undo(committed).world==w) end
 cases=cases+1
end end end end end
assert(cases==1280)
print('PASS: installed TELE declaration order, conditional duplicate destination weights, moving networks, tile/global order, FLOAT, RNG and Undo ('..cases..' cases)')
if RW_CompileWorld then
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=20;w.random_state=3
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 for id,x in pairs({[11]=3,[12]=3,[13]=7,[14]=11,[15]=7}) do
  w.entities[id]={id=id,kind='object',class='object',archetype=id==11 and 'avatar' or id==15 and 'flag' or 'rock',x=x,y=3,direction='Left'}
 end
 for row,words in ipairs({{'ROCK','IS','TELE'},{'ROCK','ON','FLAG','IS','TELE'}}) do for x,word in ipairs(words) do
  local id=w.next_entity_id;w.next_entity_id=id+1;w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=4+row*2,direction='None'}
 end end
 local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
 local frame,e=RW_CompileWorld(w,cs);assert(frame,e and e.reason)
 local projected=assert(RW_ProjectWorld(w,frame.effects));assert(#projected.tele_source_groups==2 and #projected.tele_source_groups[1]==3 and projected.tele_source_groups[2][1]==13)
 local plan=assert(RW_ResolveTele(projected));local committed,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 assert(committed.world.entities[11].x==7,'physical conditional TELE must retain the extra destination occurrence')
 assert(not committed.world.tele_source_groups and RW_Undo(committed).world==w)
 print('PASS: physical ROCK ON FLAG IS TELE preserves conditional destination multiplicity and atomic Undo')
end
