local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
services.active=RW_GetActiveLevel;services.update=RW_UpdateActiveLevel;services.enter=RW_EnterLevel;services.return_level=RW_ReturnLevel
services.selectors=RW_LevelSelectorIDs;services.place_selectors=RW_PlaceLevelSelectors;services.bind_entry=RW_BindLevelEntry
services.commit_session=RW_Commit;services.outcome=RW_RecordLevelOutcome;services.candidates=RW_LevelSelectionCandidates
services.win=RW_HasWinContact;services.level_outcome=RW_ResolveLevelPropertyOutcome
local function fixture(extra,converted,copy_entry,base)
 local root=RW_CreateSession().world;root.language.nouns.ROCK="rock";root.language.nouns.FLAG="flag"
 root.entities={[1]={id=1,kind="object",class="object",archetype="rock",x=3,y=3,direction="Left",level_link={target="child",definition_id="child",source_type="rock"}},
 [2]={id=2,kind="object",class="object",archetype="flag",x=6,y=6,direction="Right"}};root.next_entity_id=10
 local child=RW_CreateSession().world;child.width=24;child.height=24;child.entities={};child.next_entity_id=10
 child.language.nouns.LEVEL={tag="level",block_type="level_block"};child.language.nouns.ROCK="rock";child.language.nouns.FLAG="flag"
 local rows=base or {{"LEVEL","IS","REVERT"}};for _,r in ipairs(extra or {}) do rows[#rows+1]=r end
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=child.next_entity_id;child.next_entity_id=id+1;child.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"} end end
 local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",root)),child=assert(RW_CreateLevelDefinition("child",child))},"root"))
 local parent_id=tree.active_id;tree=assert(RW_EnterLevel(tree,"1","child"));tree=assert(RW_BindLevelEntry(tree,1))
 if converted then tree=assert(RW_RecordLevelOutcome(tree,"transform",{"text_level","flag"})) end
 if copy_entry then tree=assert(RW_BindLevelEntry(tree,10)) end
 return tree,parent_id
end
for _,copy in ipairs({false,true}) do
 local t,parent_id=fixture({{"LEVEL","IS","FLAG"},{"LEVEL","IS","WIN"},{"LEVEL","IS","DEFEAT"}},true,copy)
 local child_id=t.active_id;local p,e=RW_PlanLevelAction(t,{type="wait"},services);assert(p,e and e.reason);assert(p.reason=="revert")
 local n,r=RW_CommitLevelTree(t,p);assert(r.accepted,r.reason);assert(n.active_id==parent_id)
 local w=RW_GetActiveLevel(n).world
 assert(w.entities[1].archetype=="rock" and w.entities[1].x==3 and w.entities[1].direction=="Left" and w.entities[1].level_link.target=="child")
 assert(not w.entities[10] and w.next_entity_id>10 and n.level_transforms[parent_id][1]==nil and n.level_transforms[parent_id][10].deleted)
 assert(n.entry_links[child_id].entity_id==1 and n.outcomes[child_id].kind=="revert")
 local u=RW_UndoLevelTree(n);assert(u.active_id==t.active_id and u.level_transforms==t.level_transforms and u.entry_links==t.entry_links)
 assert(u.instances[parent_id].world==t.instances[parent_id].world)
 n=assert(RW_ReloadLevel(n,parent_id));assert(not RW_GetActiveLevel(n).world.entities[10] and RW_GetActiveLevel(n).world.next_entity_id>10)
end
-- Reverting an unconverted authored entrance still returns to the parent.
local t,parent_id=fixture({},false,false)
local p,e=RW_PlanLevelAction(t,{type="wait"},services);assert(p,e and e.reason)
local n,r=RW_CommitLevelTree(t,p);assert(r.accepted and n.active_id==parent_id and RW_GetActiveLevel(n).world.entities[1].archetype=="rock")
for _,extra in ipairs({{{"LEVEL","IS","NOT","REVERT"}},{{"LEVEL","IS","LEVEL"}},{{"LEVEL","IS","BROKEN"}}}) do
 t,parent_id=fixture(extra,true,false);p,e=RW_PlanLevelAction(t,{type="wait"},services);assert(p,e and e.reason)
 n,r=RW_CommitLevelTree(t,p);assert(r.accepted and n.active_id==t.active_id and n.instances[parent_id].world.entities[1].class=="text")
end
-- Missing authored provenance rejects without changing the conversion group.
t,parent_id=fixture({},true,true);t.definitions.root.initial_world.entities[1]=nil
p,e=RW_PlanLevelAction(t,{type="wait"},services);assert(not p and e.reason=="missing_authored_level_origin")
assert(t.instances[parent_id].world.entities[1].class=="text" and t.instances[parent_id].world.entities[10])
print("PASS: scoped LEVEL REVERT priority, authored shape/links, duplicate copy entry, tombstones/reload, NOT/identity/BROKEN, missing provenance and whole-tree Undo")

-- Execute the installed scoped product-selection loop, before native save I/O.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]],"rb"));local source=f:read("*a");f:close()
local scoped=assert(source:match("function dolevelconversions%(%)%s*if.-then%s*(local mats = levelconversions.-)\n\t\tif %(#levelmats > 0%)"))
local env=setmetatable({unitreference={flag="flag"},tileslist={flag={name="flag"}},changes={},MF_alert=function() end,
 testcond=function(c) return c.enabled~=false end,destroylevel=function() error("unexpected level destruction") end},{__index=_G})
local oracle=assert(load("return function() "..scoped.." return levelmats,revert end","@installed_scoped_REVERT_selection","t",env))()
local cases=0
for _,count in ipairs({0,1,2,49,50,51}) do for present=0,1 do for enabled=0,1 do for ordering=0,1 do
 local mats,relations={},{}
 for i=1,count do mats[#mats+1]={"flag",{}};relations[#relations+1]={op="transform_level",target_type="flag"} end
 if present==1 then
  local m={"revert",{enabled=enabled==1}}
  if ordering==0 then table.insert(mats,1,m) else mats[#mats+1]=m end
  if enabled==1 then relations[#relations+1]={op="level_trait",trait="revert"} end
 end
 env.levelconversions=mats;local products,reverting=oracle()
 local s=RW_CreateSession();s.world.entities={};s.world.next_entity_id=1
 local pure={};for k,v in pairs(services) do pure[k]=v end
 pure.evaluate=function() return {},nil,relations,{} end
 local plan,e=RW_PlanTurn(s.world,{type="wait"},pure);assert(plan,e and e.reason)
 assert((plan.level_transform=="@revert")==reverting)
 if not reverting then
  local n=type(plan.level_transform)=="table" and #plan.level_transform or plan.level_transform and 1 or 0
  assert(n==#products)
 end
 cases=cases+1
end end end end
assert(cases==48);print("PASS: installed scoped REVERT priority/product-selection oracle (48 cases; native save I/O and 50-product terminal limit excluded)")

-- Remove only this entrance's products; keep sibling persistent transforms.
t,parent_id=fixture({},true,false)
local sibling={id=2,kind="object",class="object",archetype="crate",original_name="flag",x=6,y=6,direction="Right"}
t.level_transforms[parent_id][2]={entity=sibling,source_id=2}
t.instances[parent_id].world.entities[2].x=9
p,e=RW_PlanLevelAction(t,{type="wait"},services);assert(p,e and e.reason)
n,r=RW_CommitLevelTree(t,p);assert(r.accepted)
assert(n.instances[parent_id].world.entities[2].archetype=="crate" and n.instances[parent_id].world.entities[2].x==6)
assert(n.level_transforms[parent_id][2].source_id==2)
print("PASS: scoped REVERT isolates sibling persistence and resets parent runtime")

-- Scoped BECOME bypasses IS identity protection and keeps verb-specific bans.
for _,case in ipairs({
 {rows={{'LEVEL','BECOME','FLAG'},{'LEVEL','IS','LEVEL'}},kind='transform',count=1},
 {rows={{'LEVEL','BECOME','FLAG'},{'LEVEL','BECOME','FLAG'}},kind='transform',count=2},
 {rows={{'LEVEL','IS','FLAG'},{'LEVEL','BECOME','FLAG'}},kind='transform',count=2},
 {rows={{'LEVEL','BECOME','TEXT'}},kind='transform',text=true,count=1},
 {rows={{'LEVEL','BECOME','LEVEL'}},kind='revert'},
 {rows={{'LEVEL','BECOME','LEVEL'},{'LEVEL','IS','NOT','REVERT'}},kind='revert'},
 {rows={{'LEVEL','BECOME','FLAG'},{'LEVEL','BECOME','NOT','FLAG'}}},
 {rows={{'LEVEL','BECOME','FLAG'},{'LEVEL','IS','BROKEN'}}},
 {rows={{'LEVEL','IS','REVERT'},{'LEVEL','IS','LEVEL'},{'LEVEL','BECOME','FLAG'}},kind='transform',count=1}
}) do
 local tree,parent=fixture({},true,false,case.rows)
 local plan,err=RW_PlanLevelAction(tree,{type='wait'},services);assert(plan,err and err.reason)
 local next,result=RW_CommitLevelTree(tree,plan);assert(result.accepted,result.reason)
 if case.kind then
  assert(next.active_id==parent and next.outcomes[tree.active_id].kind==case.kind)
  local w=RW_GetActiveLevel(next).world
  if case.kind=='revert' then assert(w.entities[1].archetype=='rock' and not w.entities[10])
  else
   local count=0
   for _,e in pairs(w.entities) do if e.level_link then
    count=count+1
    if case.text then assert(e.class=='text' and e.text.name=='LEVEL') else assert(e.archetype=='flag') end
   end end
   assert(count==case.count)
  end
 else assert(next.active_id==tree.active_id and next.instances[parent].world==tree.instances[parent].world) end
 local restored=RW_UndoLevelTree(next);assert(restored.active_id==tree.active_id and restored.level_transforms==tree.level_transforms)
 assert(restored.instances[parent].world==tree.instances[parent].world)
end
print('PASS: scoped LEVEL BECOME noun/Text/LEVEL, IS protection bypass, duplicates, own NOT, BROKEN, persistence and whole-tree Undo')

-- Execute installed dolevelconversions product selection for ordered mixed verbs.
env.unitreference.rock='rock';env.tileslist.rock={name='rock'}
env.unitreference.text_level='text_level';env.tileslist.text_level={name='text_level'}
local become_cases=0
for protected=0,1 do for copies=0,3 do for self=0,1 do for denied=0,1 do
 local mats={{'flag',{enabled=protected==0},'is'}}
 local relations={{op='transform_level',target_type='flag'}}
 if protected==1 then relations[#relations+1]={op='protect_level'} end
 for i=1,copies do
  local name=i%2==1 and 'rock' or 'text_level'
  mats[#mats+1]={name,{enabled=denied==0},'become'}
  relations[#relations+1]={op='become_level',target_type=name}
  if denied==1 then relations[#relations+1]={op='forbid_become_level',target_type=name} end
 end
 if self==1 then
  mats[#mats+1]={'level',{},'become'}
  relations[#relations+1]={op='become_level',target_type='@revert'}
 end
 env.levelconversions=mats;local expected,reverting=oracle()
 local s=RW_CreateSession();s.world.entities={};s.world.next_entity_id=1
 local pure={};for k,v in pairs(services) do pure[k]=v end
 pure.evaluate=function() return {},nil,relations,{} end
 local p,e=RW_PlanTurn(s.world,{type='wait'},pure);assert(p,e and e.reason)
 if reverting then assert(p.level_transform=='@revert')
 else
  local got=type(p.level_transform)=='table' and p.level_transform or p.level_transform and {p.level_transform} or {}
  assert(#got==#expected);for i,name in ipairs(expected) do assert(got[i]==name) end
 end
 become_cases=become_cases+1
end end end end
assert(become_cases==32)
print('PASS: installed scoped BECOME ordered product/self-revert selection oracle (32 cases; IS protection/own bans normalized)')

for _,target in ipairs({'FLAG','TEXT','LEVEL'}) do
 local tree=fixture({},false,false,{{'LEVEL','BECOME',target}})
 local session=RW_GetActiveLevel(tree)
 session.world.entities[1]={id=1,kind='object',class='object',archetype='level_block',original_name='rock',x=18,y=18,direction='Down',level_link={target='child',definition_id='root',source_type='rock'}}
 local p,e=RW_PlanTurn(session.world,{type='wait'},services);assert(p,e and e.reason)
 local n,r=RW_Commit(session,p);assert(r.accepted,r.reason)
 local unit=n.world.entities[1]
 assert(unit.direction=='Down' and unit.original_name=='rock' and unit.level_link.target=='child')
 if target=='TEXT' then assert(unit.class=='text' and unit.text.name=='LEVEL')
 else assert(unit.archetype==(target=='LEVEL' and 'level_block' or 'flag')) end
 assert(RW_Undo(n).world==session.world)
end
-- Unsupported synthetic self-negation must remain explicitly deferred rather
-- than silently becoming a REVERT ban (native selects error/destroylevel).
local tree=fixture({},false,false,{{'LEVEL','BECOME','NOT','LEVEL'}})
local frame=assert(RW_CompileWorld(RW_GetActiveLevel(tree).world,cs))
assert(#frame.deferred>0)
for _,relation in ipairs(frame.relations) do assert(relation.op~='forbid_become_level') end
print('PASS: real LEVEL BECOME preserves facing/origin/links and Undo; synthetic self-negative destruction stays explicitly deferred')
