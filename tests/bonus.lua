local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local destruction={victims=RW_ResolveContactVictims,births=function(w,ids,c,rules) local specs,e=RW_PlanHasBirths(w,ids,c);if not specs then return nil,e end;return RW_InitializeBirthSpecifications(w,specs,rules) end,birth_products=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete,contacts=RW_ResolveBonusContacts}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,destruction,rules) end,
 bonus=function(w,p,c,rules) local plan,err=RW_PlanBonusPhase(w,p,c,rules,destruction);if plan then plan.win_contact=RW_HasWinContact(p) end;return plan,err end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width=32;w.height=32;w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag"
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=8,y=8,direction="Right"},
 [2]={id=2,kind="object",class="object",archetype="rock",x=8,y=8,direction="Up"}}
 w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
 w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"} end end
 return s
end
local function step(s)
 local p,e=RW_PlanTurn(s.world,{type="wait"},services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n,p
end
local base={{"AVATAR","IS","YOU"},{"ROCK","IS","BONUS"}}
local s=fixture(base);local n,p=step(s);assert(n.world.bonus_count==1 and not n.world.entities[2]);assert(not s.world.bonus_count and s.world.entities[2])
assert(#p.events==1 and p.events[1].kind=="bonus" and p.events[1].collector_id==1)
local again=step(n);assert(again.world.bonus_count==1,"removed bonus collected again")
s=fixture({base[1],base[2],{"ROCK","IS","SAFE"}});n,p=step(s)
assert(n.world.bonus_count==1 and n.world.entities[2]);again=step(n);assert(again.world.bonus_count==2)
s=fixture({base[1],base[2],{"ROCK","HAS","FLAG"},{"ROCK","HAS","FLAG"}});n=step(s)
local flags=0;for _,e in pairs(n.world.entities) do if e.archetype=="flag" then flags=flags+1;assert(e.x==8 and e.y==8 and e.direction=="Up") end end
assert(flags==2 and n.world.bonus_count==1)
s=fixture({base[1],base[1],{"AVATAR","IS","YOU2"},base[2],base[2]});n=step(s);assert(n.world.bonus_count==6,"rule multiplicity lost")
s=fixture({base[1],base[2],{"ROCK","IS","FLOAT"}});n=step(s);assert(not n.world.bonus_count and n.world.entities[2])
s=fixture({base[1],base[2],{"ROCK","IS","NOT","BONUS"}});n=step(s);assert(not n.world.bonus_count and n.world.entities[2])
s=fixture({{"AVATAR","IS","SELECT"},base[2]});n=step(s);assert(not n.world.bonus_count and n.world.entities[2],"SELECT collected bonus")
s=fixture({base[1],{"AVATAR","IS","BONUS"}});n=step(s);assert(n.world.bonus_count==1 and not n.world.entities[1],"self BONUS+YOU must collect")
s=fixture({base[1],base[2],{"ROCK","IS","BROKEN"}});s.world.entities[2].broken=1;n=step(s);assert(not n.world.bonus_count and n.world.entities[2])
s=fixture({base[1],{"ROCK","ON","AVATAR","IS","BONUS"}});n=step(s);assert(n.world.bonus_count==1)
s=fixture({base[1],base[2],{"ROCK","IS","CRASH"}});n=step(s);assert(not n.world.infinite_loop and n.world.bonus_count==1,"deleted CRASH survived")
s=fixture({base[1],base[2],{"ROCK","HAS","ROCK"}});n=step(s);assert(n.world.bonus_count==1 and n.world.entities[s.world.next_entity_id],"newborn recursively collected")
-- Counter-only stages, stale validation, invalid/no-turn and late failure purity.
local raw=fixture({}).world
assert(not RW_PreviewPlan(raw,{consumes_turn=true,changes={},bonus_state={from=1,to=2}}))
assert(not RW_PreviewPlan(raw,{consumes_turn=false,changes={},bonus_state={from=0,to=1}}))
for _,bad in ipairs({-1,0.5,math.huge}) do assert(not RW_PreviewPlan(raw,{consumes_turn=true,changes={},bonus_state={from=0,to=bad}})) end
local sequence={consumes_turn=true,changes={},stages={{name="award",plan={consumes_turn=true,changes={},bonus_state={from=0,to=1}}},
 {name="late",plan={consumes_turn=true,changes={},bonus_state={from=0,to=2}}}}}
assert(not RW_PreviewPlan(raw,sequence) and not raw.bonus_count)
-- Pure plans carry local earned count; the tree owns persistent campaign total.
local nav={};for k,v in pairs(services) do nav[k]=v end
nav.active=RW_GetActiveLevel;nav.update=RW_UpdateActiveLevel;nav.update_instance=RW_UpdateLevelInstance;nav.enter=RW_EnterLevel;nav.return_level=RW_ReturnLevel
nav.selectors=RW_LevelSelectorIDs;nav.place_selectors=RW_PlaceLevelSelectors;nav.bind_entry=RW_BindLevelEntry
nav.commit_session=RW_Commit;nav.outcome=RW_RecordLevelOutcome;nav.candidates=RW_LevelSelectionCandidates
nav.win=RW_HasWinContact;nav.level_outcome=RW_ResolveLevelPropertyOutcome
s=fixture({base[1],base[2],{"ROCK","IS","WIN"}})
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",s.world))},"root"))
local plan,e=RW_PlanLevelAction(tree,{type="wait"},nav);assert(plan,e and e.reason)
local t,r=RW_CommitLevelTree(tree,plan);assert(r.accepted,r.reason)
assert(t.bonus_count==1 and t.outcomes[t.active_id].kind=="win","BONUS removal erased pre-delete WIN")
assert(RW_UndoLevelTree(t).bonus_count==0 and tree.bonus_count==0)
local reloaded=assert(RW_ReloadLevel(t,t.active_id));assert(reloaded.bonus_count==1 and not RW_GetActiveLevel(reloaded).world.bonus_count)
plan=assert(RW_PlanLevelAction(reloaded,{type="wait"},nav));local t2; t2,r=RW_CommitLevelTree(reloaded,plan);assert(r.accepted,r.reason);assert(t2.bonus_count==2)
assert(RW_UndoLevelTree(t2).bonus_count==1)
-- Actual enter/return reloads runtime while retaining campaign bonus total.
local function linked(rows,target)
 local w=fixture(rows).world
 w.entities[3]={id=3,kind="object",class="object",archetype="cursor",x=8,y=8,direction="None"}
 w.entities[4]={id=4,kind="object",class="object",archetype="level_block",x=8,y=8,direction="None",
  level_link=target and {source_type="level_block",target="child",definition_id=target} or {source_type="level_block",target="parent"}}
 return w
end
local defs={root=assert(RW_CreateLevelDefinition("root",linked(base,"child"))),child=assert(RW_CreateLevelDefinition("child",linked(base)))}
tree=assert(RW_CreateLevelTree(defs,"root"))
local function act(t,action)
 local p,e=RW_PlanLevelAction(t,action,nav);assert(p,e and e.reason);local n,r=RW_CommitLevelTree(t,p);assert(r.accepted,r.reason);return n
end
local collected=act(tree,{type="wait"});local entered=act(collected,{type="confirm"});assert(#entered.stack==1 and entered.bonus_count==1)
local child_collected=act(entered,{type="wait"});assert(child_collected.bonus_count==2)
local returned=act(child_collected,{type="confirm"});assert(#returned.stack==0 and returned.bonus_count==2)
assert(RW_GetActiveLevel(returned).world.entities[2] and not RW_GetActiveLevel(returned).world.bonus_count)
local undone=RW_UndoLevelTree(returned);assert(undone.active_id==child_collected.active_id and undone.bonus_count==2)
undone=RW_UndoLevelTree(undone);assert(undone.bonus_count==1 and RW_GetActiveLevel(undone).world.entities[2])
-- A status recursion limit commits the previously awarded bonus and triggering
-- birth prefix, retains the triggering parent, and skips late CRASH/outcomes.
local limited={};for k,v in pairs(services) do limited[k]=v end
limited.bonus=function(w,p,c,rules)
 local raw={};for _,r in ipairs(rules) do raw[#raw+1]=r end
 local function effect(t) return {op="grant_trait",target={kind="archetype",value="flag"},trait=t} end
 for i=0,82 do raw[#raw+1]={when={op="spatial",clauses={{relation="feeling",negated=false,parameters={{tag="property",name="limit_"..(i+1)}}}}},effects={effect(i==0 and "broken" or "limit_"..i)}} end
 raw[#raw+1]={when={op="always"},effects={effect("limit_83")}}
 return RW_PlanBonusPhase(w,p,c,raw,destruction)
end
s=fixture({base[1],base[2],{"ROCK","HAS","FLAG"},{"ROCK","IS","CRASH"}})
local limited_plan,err=RW_PlanTurn(s.world,{type="wait"},limited);assert(limited_plan,err and err.reason)
local locked,result=RW_Commit(s,limited_plan);assert(result.accepted,result.reason)
assert(locked.world.infinite_loop and locked.world.bonus_count==1 and locked.world.entities[2])
assert(locked.world.entities[s.world.next_entity_id].archetype=="flag")
assert(RW_Undo(locked).world==s.world)
-- Execute the installed post-HOLD YOU/BONUS/WIN loops unchanged (host callbacks only).
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],"rb"));local code=f:read("*a");f:close()
local first=assert(code:find("\tisyou = getunitswitheffect(\"you\",false,delthese)",1,true))
local last=assert(code:find("\tdelthese,doremovalsound = handledels",first,true));code=code:sub(first,last-1)
local cases=0
for you=1,3 do for bonus=1,3 do for safe=0,1 do for float=0,1 do for self=0,1 do
 local w=fixture({}).world;w.entities[1].behaviors={control=true};w.entities[2].behaviors={bonus=true,safe=safe==1,float=float==1}
 local target=self==1 and 1 or 2;w.entities[target].behaviors.bonus=true;w.entities[target].behaviors.safe=safe==1
 w.trait_counts={[1]={you=you},[target]={bonus=bonus}}
 if self==1 then w.trait_counts[1]={you=you,bonus=bonus} end
 if self==1 then w.entities[2].behaviors.bonus=false end
 local victims,events=RW_ResolveBonusContacts(w);local awarded=0;local units={}
 for id=1,2 do local e=w.entities[id];units[id]={fixed=id+1000,flags={dead=false},values={x=e.x,y=e.y}} end
 local env={ipairs=ipairs,table=table,DEAD="dead",XPOS="x",YPOS="y",small=false,delthese={},generaldata={values={}},SHAKE="shake",
 getunitswitheffect=function(trait) local a={};if trait=="you" then for i=1,you do a[#a+1]=units[1] end end;return a end,
 findfeature=function(_,_,trait) if trait~="bonus" then return nil end;local a={};for i=1,bonus do a[#a+1]={"rock"} end;return a end,
 findtype=function() return {target+1000} end,floating=function() return self==1 or float==0 end,
 checkeffecthistory=function() return 1,false end,MF_particles=function() end,MF_playsound=function() end,
 MF_bonus=function(v) awarded=awarded+v end,addundo=function() end,issafe=function() return safe==1 end}
 assert(load(code,"installed BONUS/WIN loops","t",env))()
 assert(#events==awarded,"original bonus multiplicity mismatch")
 local expected={};for _,id in ipairs(env.delthese) do expected[id]=true end
 assert(#victims==(expected[target+1000] and 1 or 0),"original removal mismatch")
 cases=cases+1
end end end end end
print("PASS: BONUS pickup/SAFE/multiplicity/FLOAT/self/HAS/conditions/CRASH, counters/tree reload/Undo/WIN and "..cases.." installed oracle cases")
