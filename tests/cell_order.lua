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
local bad=RW_CreateSession();bad.world.cell_order={['1:1']={1,1}}
local _,r=RW_Commit(bad,{consumes_turn=true,changes={}});assert(not r.accepted,'duplicate tile identities must reject')
print('PASS: installed tile arrival order, independent global order, BONUS dispatch, sparse normalization and Undo')
