-- Execute the installed tile-map mutators rather than reimplementing the oracle.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('function addunitmap(',1,true))
local b=assert(source:find('function inside(',a,true))
local env=setmetatable({unitmap={},unittypeshere={},roomsizex=20},{__index=_G})
assert(load(source:sub(a,b-1),'@installed_cell_order','t',env))()
local s=RW_CreateSession();local w=s.world;w.entities={};w.unit_order=nil;w.next_entity_id=10
for id=1,3 do
 w.entities[id]={id=id,kind='object',class='object',archetype=id==1 and 'avatar' or 'flag',x=id==2 and 2 or 1,y=1,direction='Right'}
 local e=w.entities[id];env.addunitmap(id,e.x,e.y,e.archetype)
end
local function move(session,id,x)
 local e=session.world.entities[id]
 local p={consumes_turn=true,changes={{kind='move',entity_id=id,from={x=e.x,y=e.y,direction=e.direction},to={x=x,y=e.y,direction=e.direction}}}}
 local n,r=RW_Commit(session,p);assert(r.accepted,r.reason);return n
end
local n=move(s,2,1);env.updateunitmap(2,2,1,1,1,'flag')
local native=env.unitmap[21];local actual=assert(n.world.cell_order)['1:1']
for i,id in ipairs(native) do assert(actual[i]==id,'arrival order differs from installed unitmap') end
assert(n.world.unit_order==nil,'movement must preserve global order')
local groups={control={{1}},control2={},bonus={{2,3}}}
local p={entities={},cell_order=n.world.cell_order,bonus_contact_groups=groups}
for id,e in pairs(n.world.entities) do p.entities[id]={x=e.x,y=e.y,behaviors={}} end
local victims,events=RW_ResolveBonusContacts(p)
assert(victims[1]==3 and victims[2]==2 and events[1].entity_id==3,'BONUS must use tile arrival order')
assert(RW_Undo(n).world==w,'Undo must restore original tile order')
local back=move(n,2,2);assert(back.world.cell_order==nil,'canonical occupancy should stay sparse')
local dir={consumes_turn=true,changes={{kind='direction',entity_id=1,from='Right',to='Left'}}}
local turned,r=RW_Commit(n,dir);assert(r.accepted and turned.world.cell_order['1:1'][1]==1,'updatedir must not reorder a tile')
local roundtrip={consumes_turn=true,changes={},motion_history={
 {kind='move',entity_id=1,from={x=1,y=1,direction='Right'},to={x=2,y=1,direction='Right'},before_change=1},
 {kind='move',entity_id=1,from={x=2,y=1,direction='Right'},to={x=1,y=1,direction='Right'},before_change=1}}}
-- History validation also requires the final diagnostic move summary.
roundtrip.changes={{kind='move',entity_id=1,from={x=1,y=1,direction='Right'},to={x=1,y=1,direction='Right'}}}
local loop,lr=RW_Commit(n,roundtrip);assert(lr.accepted,lr.reason)
assert(loop.world.cell_order['1:1'][3]==1,'zero-net movement must retain intermediate arrival order')
assert(RW_Undo(loop).world==n.world,'zero-net arrival order must Undo')
local creation=assert(RW_PlanCreate(n.world,{{kind='object',class='object',archetype='flag',x=1,y=1,direction='Left'}}))
local born,br=RW_Commit(n,creation);assert(br.accepted,br.reason)
assert(born.world.cell_order['1:1'][4]==10,'birth must append after existing arrivals')
local deleted,dr=RW_Commit(born,assert(RW_PlanDelete(born.world,{3})));assert(dr.accepted,dr.reason)
assert(deleted.world.cell_order==nil,'deleting the displaced ordering witness must normalize')
assert(RW_Undo(deleted).world==born.world,'deletion must restore prior tile order')
local def=assert(RW_CreateLevelDefinition('cell.order',n.world))
local tree=assert(RW_CreateLevelTree({[def.id]=def},def.id))
local placed=assert(RW_PlaceLevelSelectors(tree,{1},2))
-- Returning to the same tile is not an arrival when coordinates/facing agree.
assert(RW_GetActiveLevel(placed).world.cell_order['1:1'][1]==1)
local initial=RW_GetActiveLevel(tree).world
tree.level_transforms[tree.active_id]={[3]={deleted=true}}
local reloaded=assert(RW_ReloadLevel(tree,tree.active_id))
assert(RW_GetActiveLevel(reloaded).world.cell_order==nil,'persistent retirement must remove obsolete stack IDs')
local session=RW_GetActiveLevel(reloaded)
assert(RW_CreateLevelDefinition('cell.reloaded',session.world),'boundary must leave valid tile metadata')
assert(initial.entities[3] and initial.cell_order['1:1'][2]==3,'reload must preserve source snapshot')
tree.level_transforms[tree.active_id]={[10]={entity={id=10,kind='object',class='object',archetype='rock',x=1,y=1,direction='Left'}}}
local restored=RW_GetActiveLevel(assert(RW_ReloadLevel(tree,tree.active_id))).world
assert(restored.cell_order['1:1'][4]==10 and restored.cell_order['1:1'][2]==3,'persistent new products append after surviving authored stack')
assert(restored.next_entity_id==11 and RW_CreateLevelDefinition('cell.restored',restored),'restored tile IDs must match allocator and validated contents')
local separated=assert(RW_CreateLevelDefinition('cell.separate',w))
local other=assert(RW_CreateLevelTree({[separated.id]=separated},separated.id))
local arrived=assert(RW_PlaceLevelSelectors(other,{2},1))
assert(RW_GetActiveLevel(arrived).world.cell_order['1:1'][3]==2,'boundary selector arrival must append to tile')
local committed,cr=RW_CommitLevelTree(other,{before=other,after=arrived});assert(cr.accepted)
assert(RW_GetActiveLevel(RW_UndoLevelTree(committed)).world==RW_GetActiveLevel(other).world,'selector placement tile order must join whole-tree Undo')
local floats=move(s,2,1.0)
assert(floats.world.cell_order['1:1'][3]==2 and not floats.world.cell_order['1.0:1'],'equal numeric coordinates must share one tile')
assert(RW_CreateLevelDefinition('cell.float',floats.world),'integral float coordinates must validate against canonical tile keys')
p.cell_order=floats.world.cell_order;p.entities[1].x=1.0
local float_victims=RW_ResolveBonusContacts(p)
assert(float_victims[1]==3 and float_victims[2]==2,'float collector coordinates must preserve tile order')
local bad=RW_CreateSession();bad.world.cell_order={['1:1']={1,1}}
local _,r=RW_Commit(bad,{consumes_turn=true,changes={}});assert(not r.accepted,'duplicate tile identities must reject')
print('PASS: installed tile arrival order, independent global order, BONUS dispatch, sparse normalization, boundary reload/selector arrivals and Undo')
