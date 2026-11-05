-- Installed motion branches with condition checks between declarations.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local source=read('conditions.lua')
local a=assert(source:find('without = function',1,true));local b=assert(source:find('above = function',a,true))
local env=setmetatable({XPOS=1,YPOS=2,FLOAT=3,ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}},tilesize=1,
 roomsizex=4,roomsizey=4,featureindex={},MF_particles=function() end,setsoundname=function() end,
 checkeffecthistory=function() return 1,0 end,addundo=function() end,MF_levelrotation=function() end},{__index=_G})
local without=assert(load('return {'..source:sub(a,b-1)..'}','@installed_without_order','t',env))().without
source=read('blocks.lua');a=assert(source:find('elseif (action == "tele") and (levelteledone < 3)',1,true))
b=assert(source:find('elseif (action == "empty") then',a,true))
local native=assert(load('return function(rows,lstill,lsleep) local levelteledone=0; for _,row in ipairs(rows) do '
 ..'local action=row.trait; rule={"level","is",action}; if testcond(row.when,1) then if false then '
 ..source:sub(a,b-1)..' end end end end','@installed_ordered_level_motion','t',env))()
source=read('tools.lua');a=assert(source:find('function reversedir(',1,true));b=assert(source:find('function simplecheck(',a,true))
assert(load(source:sub(a,b-1),'@installed_reverse_order','t',env))()
local function condition(quota,negative)
 local terms={};for i=1,quota do terms[i]={tag='special',name='empty'} end
 return {op='spatial',clauses={{relation='without',negated=negative,parameters=terms}}}
end
local services={active=RW_LevelMotionDeclarationActive,reverse=RW_LevelMotionReverse,outcome=RW_ResolveLevelPropertyOutcome,
 resolve=RW_ResolveLevelMotion,layers=RW_LevelTeleLayers}
local cases,changed=0,0
for seed=1,24 do for quota=1,2 do for _,negative in ipairs({false,true}) do for flags=0,4 do for reverses=0,2 do
 local s=RW_CreateSession();local w=s.world;w.width,w.height=2,2;w.entities={};w.next_entity_id=5;w.random_state=seed
 local objects={};env.units={};env.unitlists={}
 for id=1,4 do
  local e={id=id,kind='object',class='object',archetype='rock',x=(id-1)%2+1,y=math.floor((id-1)/2)+1,direction='Left',behaviors={}}
  w.entities[id]=e;objects[id]={fixed=id+100,values={[1]=e.x,[2]=e.y,[3]=0}};env.units[id]=objects[id]
 end
 local when=condition(quota,negative)
 local rows={};local function add(trait,c) rows[#rows+1]={op='level_trait',trait=trait,when=c or {op='always'}} end
 add('move',when);add('tele');add('move',when);add('tele',when);add('chill',when)
 add('tele');add('turn',when);add('tele',when);add('fallright',when);add('move',when)
 for i=1,reverses do add('reverse',when) end
 if flags==1 then add('sleep') elseif flags==2 then add('still') end
 if flags==3 then add('sleep',when) elseif flags==4 then add('still',when) end
 w.rule_sources={{when={op='always'},effects={},scoped_conditions=rows}}
 local selected=assert(RW_LevelMotionDeclarations(w,{}));local traits=assert(RW_QueryLevelTraits(w,{}))
 env.findempty=function() local occupied,empty={},{}
  for _,o in pairs(objects) do occupied[o.values[1]..':'..o.values[2]]=true end
  for y=1,2 do for x=1,2 do if not occupied[x..':'..y] then empty[#empty+1]=x+y*4 end end end
  return empty
 end
 env.testcond=function(c)
  if c.op=='always' then return true end
  local clause=c.clauses[1];local params={};for i=1,#clause.parameters do params[i]='empty' end
  local v=without(params,{},{},{name='level',unitid=1,notcond=clause.negated})
  return clause.negated and not v or not clause.negated and v
 end
 env.floating_level=function() return true end
 env.featureindex=reverses>0 and {reverse={}} or {}
 env.hasfeature_count=function() return env.testcond(when) and reverses or 0 end
 env.mapdir,env.maprotation,env.Xoffset,env.Yoffset=3,0,0,0
 local rng=seed;env.fixedrandom=function(low,high) rng=rng*48271%2147483647;return low+rng%(high-low+1) end
 local history={};env.update=function(id,x,y)
  local o=objects[id-100];if o.values[1]~=x or o.values[2]~=y then history[#history+1]={id=id-100,x=x,y=y} end
  o.values[1],o.values[2]=x,y
 end
 env.MF_scrollroom=function(x,y) env.Xoffset,env.Yoffset=env.Xoffset+x,env.Yoffset+y end
 native(rows,flags==2 or flags==4 and env.testcond(when),flags==1 or flags==3 and env.testcond(when))
 local p=assert(RW_PlanOrderedLevelMotion(w,traits,{},selected,services))
 assert(p.level_motion_outcome==false and not p.tele_attempts)
 assert((p.random_state and p.random_state.to or seed)==rng,'conditional TELE/CHILL draw order')
 local offset=p.board_shift and p.board_shift.to or {x=0,y=0,direction='Down',rotation=0}
 assert(offset.x==env.Xoffset and offset.y==env.Yoffset and (offset.rotation or 0)==env.maprotation,'conditional map motion')
 assert(offset.direction==({'Right','Up','Left','Down'})[env.mapdir+1])
 assert(#(p.motion_history or {})==#history)
 for i,row in ipairs(p.motion_history or {}) do assert(row.entity_id==history[i].id and row.to.x==history[i].x and row.to.y==history[i].y) end
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 for id,o in pairs(objects) do assert(n.world.entities[id].x==o.values[1] and n.world.entities[id].y==o.values[2]) end
 assert(RW_Undo(n).world==w and w.entities[2].x==2)
 local old=RW_ResolveLevelMotion(w,traits)
 if (old.random_state and old.random_state.to or seed)~=rng then changed=changed+1 end
 cases=cases+1
end end end end end
assert(changed>0,'ordered oracle did not distinguish old frozen eligibility')
do
 local s=RW_CreateSession();local w=s.world;w.width,w.height=2,2;w.entities={};w.next_entity_id=2
 w.entities[1]={id=1,kind='object',class='object',archetype='rock',x=1,y=1,direction='Left',behaviors={}}
 local rows={{op='level_trait',trait='tele',when={op='always'}},{op='level_trait',trait='move',when={op='always'}}}
 w.rule_sources={{scoped_conditions=rows}}
 local saved=services.active
 for _,reason in ipairs({'rule_complexity_limit','word_rule_limit','word_rule_cycle','invalid_ordered_condition'}) do
  services.active=function(world,rules,row) if row.trait=='move' then return nil,reason end;return saved(world,rules,row) end
  local p,e=RW_PlanOrderedLevelMotion(w,{'tele','move'},{},rows,services)
  if reason=='invalid_ordered_condition' then assert(not p and e==reason)
  else
   assert(p.random_state.to==182605794 and not p.board_shift)
   assert(reason=='rule_complexity_limit' and p.too_complex or reason~='rule_complexity_limit' and p.infinite_loop)
   local n,r=RW_Commit(s,p);assert(r.accepted and (n.world.too_complex or n.world.infinite_loop),r.reason)
   assert(RW_Undo(n).world==w)
  end
  assert(not w.random_state and w.entities[1].x==1)
 end
 services.active=saved
end
print('PASS: installed ordered LEVEL conditions after TELE, inactive/duplicate declarations, MOVE/CHILL/FALL/turn, captured SLEEP/STILL, RNG/history/Undo ('..cases..' cases)')
