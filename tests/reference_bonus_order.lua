-- Original actor/declaration/tile loops, with actual feature and tile selectors.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name)local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({DEAD='dead',XPOS='x',YPOS='y',UNITNAME='name',UNITTYPE='type',SHAKE='shake',
 small=false,generaldata={values={}},findnoun=function()return false end,nlist={brief={}},testcond=function()return true end,
 checkeffecthistory=function()return 1,false end,MF_particles=function()end,MF_playsound=function()end,addundo=function()end},{__index=_G})
local source=read('features.lua');local a=assert(source:find('function getunitswitheffect(',1,true));local b=assert(source:find('function getunitswithverb(',a,true))
assert(load(source:sub(a,b-1),'@installed_bonus_getunits','t',env))()
source=read('tools.lua');a=assert(source:find('function findtype(',1,true));b=assert(source:find('function findobstacle(',a,true))
assert(load(source:sub(a,b-1),'@installed_bonus_findtype','t',env))()
source=read('blocks.lua')
a=assert(source:find('function handledels(',1,true));b=assert(source:find('function startblock(',a,true))
assert(load(source:sub(a,b-1),'@installed_bonus_handledels','t',env))()
a=assert(source:find('\tisyou = getunitswitheffect("you",false,delthese)',1,true));b=assert(source:find('\tdelthese,doremovalsound = handledels',a,true))
local native=assert(load(source:sub(a,b-1),'@installed_bonus_order','t',env))
local function noun(n)return {tag='noun',type={tag='object',name=n}} end
local cases=0
for actor_order=1,2 do for target_order=1,2 do for order=1,2 do for controls=1,2 do for grants=1,2 do for safes=0,3 do for floats=0,3 do
for _,same_actor in ipairs({false,true}) do for _,same_target in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.entities={};w.rule_sources={};w.next_entity_id=20
 w.unit_order=order==1 and {4,3,2,1} or {1,2,3,4}
 local names={'avatar',same_actor and 'avatar' or 'rock','flag',same_target and 'flag' or 'wall'};local units={};env.unitlists={};env.unitmap={[0]={}};env.roomsizex=10
 for id,name in ipairs(names) do
  w.entities[id]={id=id,kind='object',class='object',archetype=name,x=1,y=1,direction='Right'}
  units[1000+id]={fixed=1000+id,values={x=1,y=1},strings={name=name,type='object'},flags={dead=false}}
 end
 for _,id in ipairs(w.unit_order) do local name=names[id];env.unitlists[name]=env.unitlists[name] or {};table.insert(env.unitlists[name],1000+id);env.unitmap[11]=env.unitmap[11] or {};table.insert(env.unitmap[11],1000+id) end
 env.mmf={newObject=function(id)return units[id] end}
 local ast={};env.featureindex={you={},you2={},bonus={}}
 local function grant(name,trait)
  ast[#ast+1]={subject=noun(name),verb='is',object={tag='property',name=trait},when={op='always'}}
  if env.featureindex[trait] then table.insert(env.featureindex[trait],{{name,'is',trait},{}}) end
 end
 local actors=actor_order==1 and {names[1],names[2]} or {names[2],names[1]}
 local targets=target_order==1 and {names[3],names[4]} or {names[4],names[3]}
 -- Interleave YOU2 earlier physically: native still processes it after all YOU.
 grant(names[2],'you2')
 for i=1,controls do for _,name in ipairs(actors) do grant(name,'you') end end
 for i=1,grants do for _,name in ipairs(targets) do grant(name,'bonus') end end
 for i,id in ipairs({3,4}) do
  if math.floor(safes/2^(i-1))%2==1 then grant(names[id],'safe') end
  if math.floor(floats/2^(i-1))%2==1 then grant(names[id],'float') end
 end
 local rules=assert(RW_LowerRuleAST(ast,nil,w));local effects=assert(RW_EvaluateRules(w,rules));local projected=assert(RW_ProjectWorld(w,effects))
 local victims,events=RW_ResolveBonusContacts(projected);local expected={};env.delthese={}
 env.findfeature=function(_,_,trait)
  if trait~='bonus' then return nil end
  local rows={};for _,row in ipairs(env.featureindex.bonus) do rows[#rows+1]={row[1][1],{}} end;return rows
 end
 local current_target,current_actor
 env.floating=function(target,actor)current_target,current_actor=target-1000,actor-1000;return projected.entities[current_target].behaviors.float~=true end
 env.issafe=function(id)return projected.entities[id-1000].behaviors.safe==true end
 env.MF_bonus=function()expected[#expected+1]={entity_id=current_target,collector_id=current_actor} end
 native()
 assert(#events==#expected)
 for i,event in ipairs(expected) do assert(events[i].entity_id==event.entity_id and events[i].collector_id==event.collector_id,'BONUS actor/declaration event order') end
 local removed={};env.deleted={};env.delete=function(id)removed[#removed+1]=id-1000 end
 env.handledels(env.delthese)
 assert(#victims==#removed);for i,id in ipairs(removed) do assert(victims[i]==id,'BONUS first-encounter victim order') end
 cases=cases+1
end end end end end end end end end
print('PASS: installed BONUS feature/YOU/YOU2/tile dispatch, duplicate events and first-encounter destruction order ('..cases..' cases)')

do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=10;w.unit_order={3,2,1}
 for id,name in ipairs({'avatar','flag','wall'}) do w.entities[id]={id=id,kind='object',class='object',archetype=name,x=1,y=1,direction='Right'} end
 local ast={};for _,row in ipairs({{'avatar','is','you'},{'wall','is','bonus'},{'flag','is','bonus'},{'wall','has','avatar'},{'flag','has','rock'}}) do
  ast[#ast+1]={subject=noun(row[1]),verb=row[2],object=row[2]=='is' and {tag='property',name=row[3]} or noun(row[3]),when={op='always'}}
 end
 local rules,_,contents=RW_LowerRuleAST(ast,nil,w)
 local projected=assert(RW_ProjectWorld(w,assert(RW_EvaluateRules(w,rules))))
 local plan=assert(RW_PlanBonusPhase(w,projected,contents,rules,{
  contacts=RW_ResolveBonusContacts,initialized_births=function(a,b,c,d,n)return RW_InitializeHasBirths(a,b,c,d,n,false) end,
  create=RW_PlanCreate,delete=RW_PlanDelete}))
 local n,r=RW_Commit(s,plan);assert(r.accepted and n.world.bonus_count==2)
 assert(n.world.entities[10].archetype=='avatar' and n.world.entities[11].archetype=='rock','BONUS declaration order must determine HAS allocation order')
 assert(not n.world.bonus_contact_groups and RW_Undo(n).world==w,'projection dispatch groups must never enter persisted world/Undo')
 print('PASS: ordered BONUS destruction/HAS allocation, atomic rewards, transient metadata and Undo')
end
