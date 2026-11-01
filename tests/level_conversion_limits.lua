local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
services.active=RW_GetActiveLevel;services.update=RW_UpdateActiveLevel;services.enter=RW_EnterLevel;services.return_level=RW_ReturnLevel
services.selectors=RW_LevelSelectorIDs;services.place_selectors=RW_PlaceLevelSelectors;services.bind_entry=RW_BindLevelEntry
services.commit_session=RW_Commit;services.outcome=RW_RecordLevelOutcome;services.candidates=RW_LevelSelectionCandidates
services.win=RW_HasWinContact;services.level_outcome=RW_ResolveLevelPropertyOutcome
local function fixture(count,extra)
 local root=RW_CreateSession().world;root.entities={[1]={id=1,kind="object",class="object",archetype="level_block",x=3,y=3,direction="Down",level_link={target="child",definition_id="child",source_type="level_block"}}};root.next_entity_id=10
 local w=RW_CreateSession().world;w.width=32;w.height=2*(count+#(extra or {})+6)+10
 w.language.nouns.LEVEL={tag="level",block_type="level_block"};w.language.nouns.FLAG="flag";w.language.nouns.CURSOR="cursor";w.language.nouns.LINE="line";w.language.properties.PATH="path"
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=24,y=4,direction="Up"},
 [2]={id=2,kind="object",class="object",archetype="cursor",x=24,y=8,direction="Up"},[3]={id=3,kind="object",class="object",archetype="line",x=25,y=8,direction="None"}}
 w.next_entity_id=10
 local rows={{"AVATAR","IS","YOU"},{"CURSOR","IS","SELECT"},{"LINE","IS","PATH"}}
 for i=1,count do rows[#rows+1]={"LEVEL","IS","FLAG"} end
 for _,row in ipairs(extra or {}) do rows[#rows+1]=row end
 for y,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1;w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=y*2,direction="None"} end end
 local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",root)),child=assert(RW_CreateLevelDefinition("child",w))},"root"))
 local parent_id=tree.active_id;tree=assert(RW_EnterLevel(tree,"1","child"));tree=assert(RW_BindLevelEntry(tree,1));return tree,parent_id
end
local function act(t)
 local p,e=RW_PlanLevelAction(t,{type="move",dx=1,dy=0},services);assert(p,e and e.reason)
 local n,r=RW_CommitLevelTree(t,p);assert(r.accepted,r.reason);return n,p
end
for _,count in ipairs({49,50,51}) do
 local t,parent_id=fixture(count);local before=RW_GetActiveLevel(t).world
 local n,p=act(t);assert(not before.too_complex and #t.history==0)
 if count==49 then
  assert(n.active_id==parent_id and p.reason=="transform");local total=0;for _,u in pairs(RW_GetActiveLevel(n).world.entities) do if u.archetype=="flag" then total=total+1 end end;assert(total==49)
 else
  local w=RW_GetActiveLevel(n).world
  assert(n.active_id==t.active_id and w.too_complex and not w.infinite_loop and p.reason=="too_complex")
  assert(w.entities[1].x==25 and w.entities[1].direction=="Right" and w.entities[2].x==25)
  assert(w.last_input=="move" and w.chance_seed==48271 and w.next_entity_id==before.next_entity_id)
  assert(n.instances[parent_id].world==t.instances[parent_id].world and not n.outcomes[t.active_id])
  for _,a in ipairs({{type="move",dx=-1,dy=0},{type="wait"},{type="confirm"}}) do local p,e=RW_PlanLevelAction(n,a,services);assert(not p and e.reason=="too_complex_undo_only") end
  local _,r=RW_CommitLevelTree(n,{before=n,after=n});assert(not r.accepted and r.reason=="too_complex_undo_only")
 end
 local u=RW_UndoLevelTree(n);assert(u.active_id==t.active_id and RW_GetActiveLevel(u).world==before and u.level_transforms==t.level_transforms)
end
local t,parent_id=fixture(51,{{"LEVEL","IS","REVERT"}});local n,p=act(t)
assert(n.active_id==parent_id and p.reason=="revert" and not RW_GetActiveLevel(n).world.too_complex)
t=fixture(50,{{"LEVEL","IS","LEVEL"}});n,p=act(t);assert(n.active_id==t.active_id and not RW_GetActiveLevel(n).world.too_complex)
t=fixture(50,{{"AVATAR","IS","CRASH"}});n,p=act(t);assert(RW_GetActiveLevel(n).world.infinite_loop and not RW_GetActiveLevel(n).world.too_complex)
print("PASS: scoped 49/50/51 conversion boundary, retained move/SELECT/input/RNG/allocator, no parent mutation, Undo-only, REVERT/identity and prior CRASH")

-- Execute the installed dispatch including its editor branch and >=50 branch.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]],"rb"));local source=f:read("*a");f:close()
local branch=assert(source:match("(\t\tif %(#levelmats > 0%).-)\n\t\tlevelconversions = {}"))
local env=setmetatable({editor={values={editing=1}},INEDITOR="editing"},{__index=_G})
local original=assert(load("return function(levelmats) local revert=false "..branch.." end","@installed_LEVEL_conversion_limit","t",env))()
for _,count in ipairs({0,1,49,50,51,99}) do
 local convert,terminal=0,nil;env.MF_levelconversion=function() convert=convert+1 end;env.destroylevel=function(reason) terminal=reason end
 local mats={};for i=1,count do mats[i]="flag" end;original(mats)
 assert((terminal=="toocomplex")== (count>=50));assert(convert==((count>0 and count<50) and 1 or 0))
end
print("PASS: installed scoped conversion dispatch/50-product limit oracle (6 cases)")

-- The project's conversion-before-terminal policy also applies at this boundary.
t=fixture(50,{{"AVATAR","IS","WIN"}});n,p=act(t)
assert(RW_GetActiveLevel(n).world.too_complex and not n.outcomes[t.active_id])
-- AUTO commits only the triggering pulse prefix and clears queued input.
services.auto_count=RW_GetAutoTurnCount
t=fixture(50,{{"LEVEL","IS","AUTO"},{"LEVEL","IS","AUTO"}})
local command,e=RW_PlanAutoCommand(t,{type="move",dx=1,dy=0},services);assert(command,e and e.reason)
local q,r=RW_CommitAutoInput(t,command);assert(r.accepted)
local pulse,e=RW_PlanAutoPulse(q,services);assert(pulse,e and e.reason);assert(#pulse.pulse_turns==1)
n,r=RW_CommitLevelTree(q,pulse);assert(r.accepted and RW_GetActiveLevel(n).world.too_complex and next(n.auto_input)==nil)
local restored=RW_UndoLevelTree(n);assert(not RW_GetActiveLevel(restored).world.too_complex and restored.auto_input[1]==0 and RW_GetActiveLevel(restored).world==RW_GetActiveLevel(q).world)
print("PASS: scoped complexity keeps conversion-before-WIN and AUTO triggering prefix/queue Undo")
