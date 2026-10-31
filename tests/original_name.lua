-- REVERT prerequisite: origin is intrinsic, independent of current concrete name.
local s=RW_CreateSession();s.world.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=3,y=3,direction="Left"}}
s.world.next_entity_id=10
local initial=s
local function convert(session,relations)
 local changes,e,allocation=RW_PlanConversions(session.world,relations);assert(changes,e)
 local p={consumes_turn=true,changes=changes,id_allocation=allocation}
 local preview=assert(RW_PreviewPlan(session.world,p));local n,r=RW_Commit(session,p);assert(r.accepted,r.reason)
 assert(RW_GetOriginalName(preview.entities[1])==RW_GetOriginalName(n.world.entities[1]))
 assert(RW_Undo(n).world==session.world);return n
end
s=convert(s,{{op="transform",source_type="avatar",target_type="rock"},{op="transform",source_type="avatar",target_type="flag"}})
assert(s.world.entities[1].archetype=="rock" and s.world.entities[10].archetype=="flag")
assert(s.world.entities[1].original_name=="avatar" and s.world.entities[10].original_name=="avatar")
s=convert(s,{{op="transform_text",source_type="rock"}})
assert(s.world.entities[1].class=="text" and s.world.entities[1].original_name=="avatar")
s=convert(s,{{op="write_text",source_type="@text",target_text="IS"},{op="write_text",source_type="@text",target_text="IS"}})
assert(s.world.entities[1].text.name=="IS" and s.world.entities[11].text.name=="IS")
assert(s.world.entities[11].original_name=="avatar")
s=convert(s,{{op="become",when={op="always"},source_type="@text",target_type="rock"}})
assert(s.world.entities[1].archetype=="rock" and s.world.entities[1].original_name=="avatar")
assert(initial.world.entities[1].original_name==nil and RW_GetOriginalName(initial.world.entities[1])=="avatar")
local text=RW_CreateSession();text.world.entities={[1]={id=1,kind="object",class="text",text={name="ROCK"},x=3,y=3,direction="Up"}};text.world.next_entity_id=10
text=convert(text,{{op="transform",source_type="@text",target_type="flag"}})
assert(text.world.entities[1].original_name=="text_ROCK")
-- Births start their own origin; MORE uses original copy()->create(), not conversion.
local projected=assert(RW_ProjectWorld(s.world,{{op="grant_trait",entity_ids={1},trait="more"}}))
local products=RW_ResolveMoreProducts(projected);assert(#products>0)
for _,product in ipairs(products) do assert(RW_GetOriginalName(product)=="rock" and product.original_name==nil) end
local births=assert(RW_PlanHasBirths(s.world,{1},{{op="has",target={kind="archetype",value="rock"},product={kind="object",archetype="flag"}}}))
assert(#births==1 and RW_GetOriginalName(births[1])=="flag")
local created=assert(RW_PlanCreate(s.world,births));local n,r=RW_Commit(s,created);assert(r.accepted)
assert(RW_GetOriginalName(n.world.entities[created.changes[1].entity_id])=="flag")
-- Origin cannot be changed by retyping, and malformed origins reject creation.
local old=s.world.entities[1];local to={};for k,v in pairs(old) do to[k]=v end;to.class="text";to.archetype=nil;to.text={name="ROCK"};to.original_name="flag"
local _,r=RW_Commit(s,{consumes_turn=true,changes={{kind="retype",entity_id=1,from=old,to=to}}});assert(not r.accepted)
local bad={kind="object",class="object",archetype="flag",x=1,y=1,direction="None",original_name={}}
assert(not RW_PlanCreate(s.world,{bad}))
-- Execute the installed conversion provenance assignment unchanged.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]],"rb"));local source=f:read("*a");f:close()
local assignment=assert(source:match("newunit%.originalname = unit%.originalname"))
local original=assert(load("return function(unit) local newunit={} "..assignment.." return newunit.originalname end","@installed_original_name"))()
for _,name in ipairs({"avatar","text_ROCK","level_block","@empty"}) do assert(original({originalname=name})==RW_GetOriginalName({class="object",archetype="flag",original_name=name})) end
print("PASS: conversion origin through duplicate IS/TEXT/WRITE/BECOME, physical Text, newborn reset, immutable retype, Preview/Commit/Undo and installed provenance assignment")

-- Virtual EMPTY conversions carry the empty lineage, not the newborn noun.
local empty=RW_CreateSession();empty.world.width=4;empty.world.height=4;empty.world.entities={};empty.world.next_entity_id=1
local ops,e,allocation=RW_PlanConversions(empty.world,{{op="transform",source_type="@empty",target_type="rock"}});assert(ops,e)
local born,r=RW_Commit(empty,{consumes_turn=true,changes=ops,id_allocation=allocation});assert(r.accepted and #ops==16)
for _,unit in pairs(born.world.entities) do assert(unit.original_name=="@empty") end
-- Scoped LEVEL copies and runtime reload retain the entrance's origin.
local root=RW_CreateSession().world;root.entities={[1]={id=1,kind="object",class="object",archetype="level_block",x=3,y=3,direction="Down",level_link={target="child",definition_id="child",source_type="level_block"}}};root.next_entity_id=10
local child=RW_CreateSession().world;child.entities={};child.next_entity_id=1
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",root)),child=assert(RW_CreateLevelDefinition("child",child))},"root"))
local parent_id=tree.active_id;tree=assert(RW_EnterLevel(tree,"1","child"));tree=assert(RW_BindLevelEntry(tree,1))
tree=assert(RW_RecordLevelOutcome(tree,"transform",{"rock","text_level"}))
local parent=tree.instances[parent_id].world
assert(parent.entities[1].original_name=="level_block" and parent.entities[10].original_name=="level_block")
tree=assert(RW_ReloadLevel(tree,parent_id));parent=tree.instances[parent_id].world
assert(parent.entities[1].original_name=="level_block" and parent.entities[10].original_name=="level_block")
print("PASS: virtual EMPTY origin and scoped LEVEL duplicate/persistent reload provenance")
