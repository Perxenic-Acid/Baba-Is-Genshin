local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return (s:gsub('\r\n','\n')) end
local movement,tools=read('movement.lua'),read('tools.lua')
local a=assert(movement:find('local levelshift = findfeature("level","is","shift")',1,true))
local b=assert(movement:find('\n\t\t\tend\n\t\telse',a,true))
local branch=movement:sub(a,b-1)
local function install(env,first,last)
 local x=assert(tools:find('function '..first..'(',1,true));local y=assert(tools:find('function '..last..'(',x+1,true))
 assert(load(tools:sub(x,y-1),'@installed_level_shift_'..first,'t',env))()
end
local names={'Right','Up','Left','Down'};local cases=0
for dir=0,3 do for mask=0,255 do for copies=1,2 do
 local function bit(n)return math.floor(mask/2^n)%2==1 end
 local caps={float=bit(0),sleep=bit(1),still=bit(2),reverse=bit(4)}
 local lock=bit(5) and (dir+2)%4 or dir
 caps[({'lockedright','lockedup','lockedleft','lockeddown'})[lock+1]]=bit(3)
 local mapfloat,hold,enabled=bit(6),bit(7),true
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=12
 w.level_traits={};for i=1,copies do w.level_traits[#w.level_traits+1]='shift' end
 if mapfloat then w.level_traits[#w.level_traits+1]='float' end
 w.level_behaviors={float=mapfloat,hold=hold}
 w.board_offset={x=0,y=0,direction=names[dir+1]}
 w.entities[11]={id=11,kind='object',class='object',archetype='avatar',x=5,y=5,direction='Left',behaviors=caps}
 local unit={fixed=11,values={x=5,y=5,dir=2,float=caps.float and 1 or 0},strings={name='avatar'}}
 local env=setmetatable({XPOS='x',YPOS='y',DIR='dir',FLOAT='float',UNITNAME='name',units={unit},moving_units={},mapdir=dir,featureindex={reverse={}}},{__index=_G})
 env.mmf={newObject=function()return unit end};env.getname=function()return 'avatar' end
 env.findfeature=function(_,_,trait)
  if trait=='float' and mapfloat or trait=='shift' and enabled then local r={};for i=1,copies do r[i]={{},{}} end;return r end
 end
 env.testcond=function()return true end
 env.hasfeature=function(name,_,trait)
  return (name=='level' and trait=='hold' and hold or name~='level' and caps[trait]) and true or nil
 end
 env.hasfeature_count=function(_,_,trait)return caps[trait] and 1 or 0 end
 env.updatedir=function(_,d)unit.values.dir=d end
 env.issleep=function()return caps.sleep end
 install(env,'cantmove','findnoun');install(env,'reversedir','reversecheck');install(env,'reversecheck','simplecheck')
 install(env,'floating_level','emptydir');install(env,'isstill_or_locked','getmat')
 assert(load(branch,'@installed_level_shift_collect','t',env))()
 local plan=assert(RW_ResolveShift(w))
 assert(#plan.shift_tasks==#env.moving_units,'LEVEL SHIFT independent task count')
 for i,task in ipairs(env.moving_units) do local actual=plan.shift_tasks[i]
  assert(actual.entity_id==task.unitid and actual.direction==names[task.dir+1] and actual.count==task.moves,'LEVEL SHIFT collected task')
 end
 local after=assert(RW_PreviewPlan(w,plan))
 if caps.float==mapfloat then assert(after.entities[11].direction==names[unit.values.dir+1],'LEVEL SHIFT turns before SLEEP/locks')
 else assert(after.entities[11].direction=='Left' and after.entities[11].x==5 and after.entities[11].y==5,'LEVEL SHIFT layer isolation') end
 if #env.moving_units==0 then assert(after.entities[11].x==5 and after.entities[11].y==5,'uncollected LEVEL SHIFT must not displace') end
 if #plan.changes>0 then local committed,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(committed).world==w) end
 cases=cases+1
end end end
assert(cases==2048)
do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=3
 w.level_traits={'shift','shift'};w.board_offset={x=0,y=0,direction='Right'}
 w.entities[1]={id=1,kind='object',class='object',archetype='avatar',x=5,y=5,direction='Left',behaviors={}}
 w.entities[2]={id=2,kind='object',class='object',archetype='rock',x=5,y=5,direction='Up',behaviors={shift=true}}
 local plan=assert(RW_ResolveShift(w));assert(#plan.shift_tasks==3,'map impulses must append independently after ordinary belt collection')
 assert(plan.shift_tasks[1].entity_id==1 and plan.shift_tasks[1].direction=='Up')
 assert(plan.shift_tasks[2].entity_id==1 and plan.shift_tasks[2].direction=='Right' and plan.shift_tasks[3].entity_id==2)
 local committed,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 assert(committed.world.entities[1].x==6 and committed.world.entities[1].y==5,'independent map impulse must preserve queued update semantics')
 assert(RW_Undo(committed).world==w)
end
print('PASS: installed LEVEL SHIFT collector, FLOAT, SLEEP/STILL, directional locks/REVERSE, HOLD, duplicate grants, facing and Undo ('..cases..' cases)')

if RW_PlanTurn then
 local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
 local services={shift=RW_ResolveShift,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
  destroy=function(w,ids,c,k,deaths)return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths)end,
  contact=function(w,p,k,c)return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete})end,
  evaluate=function(w)local frame,e=RW_CompileWorld(w,cs);if not frame then return nil,e.reason end;return frame.effects,nil,frame.relations,frame.rules end}
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=20
 w.language.nouns.LEVEL={tag='level',block_type='level_block'}
 w.board_offset={x=0,y=0,direction='Right'}
 w.entities[1]={id=1,kind='object',class='object',archetype='avatar',x=5,y=5,direction='Left'}
 for i,word in ipairs({'LEVEL','IS','SHIFT'}) do local id=i+10
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=i,y=2,direction='Up'}
 end
 local plan,e=RW_PlanTurn(w,{type='wait'},services);assert(plan,e and e.reason)
 local committed,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 assert(committed.world.entities[1].x==6 and committed.world.entities[1].direction=='Right','physical LEVEL IS SHIFT must enter scheduled motion: '..committed.world.entities[1].x..','..committed.world.entities[1].direction..' / '..table.concat(plan.level_traits or {},','))
 for i=1,3 do assert(committed.world.entities[i+10].x==i+1,'map SHIFT must include physical Text') end
 assert(not committed.world.shift_tasks and RW_Undo(committed).world==w,'map SHIFT remains one transient-plan/whole-turn transaction')
 local copy=assert(RW_CreateLevelDefinition('shift.denial',w)).initial_world
 for i,word in ipairs({'LEVEL','IS','NOT','SHIFT'}) do local id=i+13
  copy.entities[id]={id=id,kind='object',class='text',text={name=word},x=i,y=4,direction='Up'}
 end
 local denied,why=RW_PlanTurn(copy,{type='wait'},services);assert(denied,why and why.reason)
 local unchanged=assert(RW_PreviewPlan(copy,denied))
 assert(unchanged.entities[1].x==5 and unchanged.entities[1].direction=='Left','LEVEL IS NOT SHIFT must veto map pulse and facing')
 print('PASS: physical LEVEL IS SHIFT moves Object/Text through scheduled wait and atomic Undo')
end
