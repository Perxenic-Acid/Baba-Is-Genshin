-- Compare dynamic map FLOAT with installed WITHOUT and floating_level.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local source=read('conditions.lua')
local a=assert(source:find('without = function',1,true));local b=assert(source:find('above = function',a,true))
local env=setmetatable({FLOAT=3,unitlists={}},{__index=_G})
local without=assert(load('return {'..source:sub(a,b-1)..'}','@installed_without_tele','t',env))().without
source=read('tools.lua');a=assert(source:find('function floating_level(',1,true));b=assert(source:find('function emptydir(',a,true))
assert(load(source:sub(a,b-1),'@installed_floating_level_dynamic','t',env))()
local count,changed=0,0
for seed=1,20 do for pattern=0,15 do for quota=1,2 do for _,negative in ipairs({false,true}) do
 local s=RW_CreateSession();local w=s.world;w.width,w.height=2,2;w.entities={};w.next_entity_id=5;w.random_state=seed
 local objects={}
 for id=1,4 do local f=math.floor(pattern/2^(id-1))%2==1
  w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=(id-1)%2+1,y=math.floor((id-1)/2)+1,direction='Right',behaviors={float=f}}
  objects[id]={values={[1]=w.entities[id].x,[2]=w.entities[id].y,[3]=f and 1 or 0}}
 end
 local params,terms={},{};for i=1,quota do params[i]='empty';terms[i]={tag='special',name='empty'} end
 local when={op='spatial',clauses={{relation='without',negated=negative,parameters=terms}}}
 w.rule_sources={{when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='float',when=when}}}}
 env.findempty=function() local occupied,empty={},{}
  for _,o in pairs(objects) do occupied[o.values[1]..':'..o.values[2]]=true end
  for y=1,2 do for x=1,2 do if not occupied[x..':'..y] then empty[#empty+1]=x+y*4 end end end
  return empty
 end
 env.findfeature=function() return {{{'level','is','float'},params}} end
 env.testcond=function() local v=without(params,{},{},{name='level',unitid=1,notcond=negative});return negative and not v or not negative and v end
 env.mmf={newObject=function(id) return objects[id-100] end}
 local p=assert(RW_ResolveLevelMotion(w,{'tele','tele','tele'}))
 local layers=assert(RW_LevelTeleLayers(w,{},p.tele_attempts))
 local initial=env.testcond()
 for i,t in ipairs(p.tele_attempts) do
  local expected=env.floating_level(t.entity_id+100)
  assert(layers[i]==expected,'dynamic map layer differs from installed condition')
  if expected~=(w.entities[t.entity_id].behaviors.float==initial) then changed=changed+1 end
  if expected then objects[t.entity_id].values[1],objects[t.entity_id].values[2]=t.x,t.y end
 end
 local resolved=assert(RW_ResolveLevelMotion(w,{'tele','tele','tele'},nil,layers))
 local n,r=RW_Commit(s,resolved);assert(r.accepted,r.reason)
 for id,o in pairs(objects) do assert(n.world.entities[id].x==o.values[1] and n.world.entities[id].y==o.values[2]) end
 assert(RW_Undo(n).world==w and w.entities[1].x==1 and w.entities[2].x==2)
 count=count+1
end end end end
assert(changed>0,'oracle never exercised a changed map layer')
-- A failing map-layer query retains only earlier decisions and its two draws.
do
 local s=RW_CreateSession();local w=s.world;w.width,w.height=2,2;w.entities={};w.next_entity_id=3
 for id=1,2 do w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=id,y=1,direction='Right'} end
 w.rule_sources={{scoped_conditions={{op='level_trait',trait='float',when={op='always'}}}}}
 local saved=RW_TestEntityCondition;local calls=0
 RW_TestEntityCondition=function(...) calls=calls+1;if calls==2 then return nil,'rule_complexity_limit' end;return false end
 local p=RW_ResolveLevelMotion(w,{'tele','chill','tele'})
 local layers,why,through=RW_LevelTeleLayers(w,{},p.tele_attempts)
 RW_TestEntityCondition=saved
 assert(why=='rule_complexity_limit' and through==2 and layers[1] and layers[2]==false)
 local prefix=assert(RW_ResolveLevelMotion(w,{'tele','chill','tele'},nil,layers,through))
 local rng=1;for i=1,4 do rng=rng*48271%2147483647 end
 assert(prefix.random_state.to==rng and not prefix.board_shift and #prefix.tele_attempts==2)
 prefix.too_complex=true;local n,r=RW_Commit(s,prefix);assert(r.accepted,r.reason)
 assert(n.world.too_complex and RW_Undo(n).world==w)
end
print('PASS: dynamic LEVEL TELE map FLOAT, installed WITHOUT quotas/negation, sequential occupancy, fixed unit layers, terminal RNG prefix and Undo ('..count..' cases)')
