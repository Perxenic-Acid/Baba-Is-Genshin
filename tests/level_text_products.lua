local root=RW_CreateSession().world;root.entities={};root.next_entity_id=10
root.entities[1]={id=1,kind='object',class='object',archetype='level_block',x=3,y=3,direction='Up',
 level_link={target='child',definition_id='child',source_type='level_block'}}
local child=RW_CreateSession().world
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition('root',root)),
 child=assert(RW_CreateLevelDefinition('child',child))},'root'))
local parent=tree.active_id
local entered=assert(RW_BindLevelEntry(assert(RW_EnterLevel(tree,'1','child')),1))
local changed=assert(RW_RecordLevelOutcome(entered,'transform',{'text_rock','text_is','text_level','text_safe','text_rock'}))
local returned=assert(RW_ReturnLevel(changed))
local w=RW_GetActiveLevel(returned).world
for i,pair in ipairs({{1,'ROCK'},{10,'IS'},{11,'LEVEL'},{12,'SAFE'},{13,'ROCK'}}) do
 local e=w.entities[pair[1]];assert(e.class=='text' and not e.archetype and e.text.name==pair[2])
 assert(e.direction=='Up' and e.x==3 and e.y==3 and e.level_link.definition_id=='child' and e.original_name=='level_block')
end
assert(w.next_entity_id==14 and not root.entities[10])
local reload=assert(RW_ReloadLevel(returned,parent));assert(RW_GetActiveLevel(reload).world.entities[10].text.name=='IS')
local again=assert(RW_BindLevelEntry(assert(RW_EnterLevel(returned,'10','child')),10,w))
local replaced=assert(RW_ReturnLevel(assert(RW_RecordLevelOutcome(again,'transform','text_flag'))))
local replaced_world=RW_GetActiveLevel(replaced).world
assert(replaced_world.entities[1].text.name=='FLAG' and not replaced_world.entities[10] and not replaced_world.entities[11] and not replaced_world.entities[12] and not replaced_world.entities[13])
assert(replaced_world.next_entity_id==14)
local committed,result=RW_CommitLevelTree(tree,{before=tree,after=replaced});assert(result.accepted)
assert(RW_GetActiveLevel(RW_UndoLevelTree(committed)).world==RW_GetActiveLevel(tree).world)
assert(not RW_RecordLevelOutcome(entered,'transform','text_'))
-- Legacy persisted string records must decode all text products too.
local legacy=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition('root',root))},'root'))
legacy.level_transforms[legacy.active_id]={[1]='text_sink'}
local restored=assert(RW_ReloadLevel(legacy,legacy.active_id))
assert(RW_GetActiveLevel(restored).world.entities[1].class=='text' and RW_GetActiveLevel(restored).world.entities[1].text.name=='SINK')
print('PASS: arbitrary scoped Text products retain identity/facing/links, duplicate-copy entry replacement, allocator tombstones, reload/legacy records, validation and tree Undo')

local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]],'rb'))
local source=f:read('*a');f:close()
local start=assert(source:find('function dolevelconversions()',1,true))
local a=assert(source:find('if (op == "write") then',start,true))
local b=assert(source:find('local objectfound',a,true))
local native=assert(load('return function(op,matdata) local mat2=matdata[1] '..source:sub(a,b-1)..' return mat2 end','@original_level_write_prefix'))()
for _,word in ipairs({'rock','level','is','not','safe','empty','all','write'}) do
 local target=native('write',{word})
 local changed=assert(RW_RecordLevelOutcome(entered,'transform',target))
 assert(changed.instances[parent].world.entities[1].text.name==word:upper())
end
print('PASS: installed scoped WRITE text-product prefix oracle (8 noun/syntax/property/special tokens; rule selection is separate)')
