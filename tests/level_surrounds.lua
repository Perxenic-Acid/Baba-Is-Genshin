-- Entry context must be captured before the parent runtime is reloaded.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('function getlevelsurrounds(',1,true))
local b=assert(source:find('function parsesurrounds(',a,true))
local offsets={{1,0},{0,-1},{-1,0},{0,1},{1,1},{1,-1},{-1,-1},{-1,1},{0,0}}
local keys={'r','u','l','d','dr','ur','ul','dl','o'}
local checked=0
for _,direction in ipairs({'Right','Up','Left','Down','Mid','None'}) do
 for _,stacked in ipairs({false,true}) do
  local w=RW_CreateSession().world;w.width=12;w.height=12;w.entities={};w.next_entity_id=30
  w.entities[1]={id=1,kind='object',class='object',archetype='level_block',x=2,y=2,direction=direction,
   level_link={target='child',definition_id='child',source_type='level_block'}}
  local id=2
  for index,offset in ipairs(offsets) do if index%2==0 or stacked then
   local e={id=id,kind='object',class=index%3==0 and 'text' or 'object',archetype=index%3~=0 and 'rock' or nil,
    text=index%3==0 and {name='FLAG'} or nil,x=6+offset[1],y=6+offset[2],direction='None'}
   w.entities[id]=e;id=id+1
  end end
  if stacked then
   w.unit_order={};for eid=id-1,1,-1 do w.unit_order[#w.unit_order+1]=eid end
  end
  if direction=='Mid' then w.entities[1].class='text';w.entities[1].text={name='LEVEL'};w.entities[1].archetype=nil end
  local child=RW_CreateSession().world
  local root=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition('root',w)),
   child=assert(RW_CreateLevelDefinition('child',child))},'root'))
  local active=RW_GetActiveLevel(root)
  local moved,result=RW_Commit(active,{consumes_turn=true,changes={{kind='move',entity_id=1,from={x=2,y=2},to={x=6,y=6}}}})
  assert(result.accepted);local dirty=assert(RW_UpdateActiveLevel(root,moved))
  local entered=assert(RW_EnterLevel(dirty,'1','child'))
  assert(entered.instances[root.active_id].world.entities[1].x==2)
  local bound=assert(RW_BindLevelEntry(entered,1,moved.world))
  local actual=RW_GetActiveLevel(bound).world.level_surrounds
  local env=setmetatable({XPOS=1,YPOS=2,DIR=3,LEVELSURROUNDS=1,roomsizex=12,
   dirs_diagonals=offsets,generaldata2={strings={}},unitmap={}},{__index=_G})
  local objects={};local order={};for eid in pairs(moved.world.entities) do order[#order+1]=eid end;table.sort(order)
  order=moved.world.unit_order or order
  for _,eid in ipairs(order) do local e=moved.world.entities[eid]
   objects[eid]={values={e.x,e.y,({Right=0,Up=1,Left=2,Down=3})[e.direction] or 4},name=e.class=='text' and 'text' or e.archetype=='level_block' and 'level' or e.archetype}
   local cell=e.x+e.y*12;env.unitmap[cell]=env.unitmap[cell] or {};table.insert(env.unitmap[cell],eid)
  end
  env.mmf={newObject=function(eid) return objects[eid] end};env.getname=function(e) return e.name end
  assert(load(source:sub(a,b-1),'@original_getlevelsurrounds','t',env))();env.getlevelsurrounds(1)
  local values={};for value in env.generaldata2.strings[1]:gmatch('([^,]+),') do values[#values+1]=value end
  assert(actual.dir==tonumber(values[1]));local index=2
  for _,key in ipairs(keys) do
   assert(values[index]==key);index=index+1
   for _,name in ipairs(actual[key]) do assert(values[index]==name);index=index+1 end
  end
  assert(index==#values+1)
  local reloaded=assert(RW_ReloadLevel(bound,bound.active_id));local saved=RW_GetActiveLevel(reloaded).world.level_surrounds
  assert(saved~=actual and saved.dir==actual.dir and table.concat(saved.r,',')==table.concat(actual.r,','))
  local committed,ok=RW_CommitLevelTree(dirty,{before=dirty,after=bound});assert(ok.accepted)
  assert(RW_GetActiveLevel(RW_UndoLevelTree(committed)).world==moved.world)
  assert(not RW_GetActiveLevel(entered).world.level_surrounds)
  local invalid=RW_GetActiveLevel(bound).world;local copy={};for k,v in pairs(invalid) do copy[k]=v end
  copy.level_surrounds={dir=5};assert(not RW_CreateLevelDefinition('bad',copy))
  checked=checked+1
 end
end
print('PASS: installed getlevelsurrounds entry-time nine-cell names/directions/empty sentinel ('..checked..' cases), pre-reset runtime, reload isolation, validation and whole-tree Undo')
