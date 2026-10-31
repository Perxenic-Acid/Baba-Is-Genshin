local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local destruction={victims=RW_ResolveContactVictims,births=function(w,ids,c,rules) local p,e=RW_PlanHasBirths(w,ids,c);if not p then return nil,e end;return RW_InitializeBirthSpecifications(w,p,rules) end,
 birth_products=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete,contacts=RW_ResolveBonusContacts}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,ending=RW_ResolveEndContact,
 done=function(w,p,r) local ids,events,win=RW_ResolveDone(p,r);local plan,e=RW_PlanDelete(w,ids);if plan then plan.events,plan.done_win=events,win end;return plan,e end,
 bonus=function(w,p,c,rules) local plan,e=RW_PlanBonusPhase(w,p,c,rules,destruction);if plan then plan.win_contact=RW_HasWinContact(p) end;return plan,e end,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,destruction,rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width=16;w.height=16;w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag";w.language.nouns.LEVEL={tag="level",block_type="level_block"}
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=12,y=12,direction="Right"},[2]={id=2,kind="object",class="object",archetype="rock",x=12,y=12,direction="Left"}};w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
 w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"} end end
 assert(w.language.properties.END=="end");return s
end
local you={"AVATAR","IS","YOU"};local ending={"ROCK","IS","END"}
local function step(s,svc)
 local p,e=RW_PlanTurn(s.world,{type="wait"},svc or services);assert(p,e and e.reason);local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 assert(RW_Undo(n).world==s.world);return n,p
end
local s=fixture({you,ending});local n,p=step(s);assert(p.end_contact and n.world.entities[2] and not n.world.infinite_loop)
assert(p.end_contact.source.entity_id==1 and p.end_contact.target.entity_id==2)
s=fixture({{"AVATAR","IS","YOU2"},ending});n,p=step(s);assert(p.end_contact)
s=fixture({{"AVATAR","IS","SELECT"},ending});n,p=step(s);assert(not p.end_contact)
s=fixture({you,ending,{"ROCK","IS","FLOAT"}});n,p=step(s);assert(not p.end_contact)
s=fixture({you,ending,{"ROCK","IS","FLOAT"},{"AVATAR","IS","FLOAT"}});n,p=step(s);assert(p.end_contact)
s=fixture({you,{"AVATAR","IS","END"}});n,p=step(s);assert(p.end_contact.source.entity_id==p.end_contact.target.entity_id)
s=fixture({you,ending,{"ROCK","IS","NOT","END"}});n,p=step(s);assert(not p.end_contact)
s=fixture({you,ending,{"ROCK","IS","BROKEN"}});n,p=step(s);assert(not p.end_contact)
s=fixture({you,{"ROCK","ON","AVATAR","IS","END"}});n,p=step(s);assert(p.end_contact)
s.world.entities[1].x=15;n,p=step(s);assert(not p.end_contact)
s=fixture({you,ending,{"ROCK","IS","DONE"}});n,p=step(s);assert(not p.end_contact and not n.world.entities[2])
s=fixture({you,ending,{"AVATAR","IS","DEFEAT"}});n,p=step(s);assert(not p.end_contact and not n.world.entities[1])
local nav={};for k,v in pairs(services) do nav[k]=v end
nav.active=RW_GetActiveLevel;nav.update=RW_UpdateActiveLevel;nav.update_instance=RW_UpdateLevelInstance;nav.enter=RW_EnterLevel;nav.return_level=RW_ReturnLevel
nav.selectors=RW_LevelSelectorIDs;nav.place_selectors=RW_PlaceLevelSelectors;nav.bind_entry=RW_BindLevelEntry
nav.commit_session=RW_Commit;nav.outcome=RW_RecordLevelOutcome;nav.candidates=RW_LevelSelectionCandidates
nav.win=RW_HasWinContact;nav.level_outcome=RW_ResolveLevelPropertyOutcome
local function tree_for(s) return assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",s.world))},"root")) end
local function act(t,a)
 local p,e=RW_PlanLevelAction(t,a or {type="wait"},nav);assert(p,e and e.reason);local n,r=RW_CommitLevelTree(t,p);assert(r.accepted,r.reason);return n,p
end
s=fixture({you,ending,{"ROCK","IS","BONUS"},{"ROCK","IS","WIN"}});local tree=tree_for(s);local t,plan=act(tree)
assert(t.ending and t.ending.kind=="end" and t.bonus_count==1 and not RW_GetActiveLevel(t).world.entities[2])
assert(t.outcomes[t.active_id].kind=="win" and t.ending.target.entity_id==2)
local events=0;for _,e in ipairs(plan.events) do if e.kind=="end" then events=events+1 end end;assert(events==1)
local u=RW_UndoLevelTree(t);assert(not u.ending and u.bonus_count==0 and RW_GetActiveLevel(u).world.entities[2])
local stale_result;_,stale_result=RW_CommitLevelTree(t,plan);assert(not stale_result.accepted)
for _,badsource in ipairs({{kind="wrong"},{kind="unit",entity_id=-1,x=1,y=1},{kind="level",x=1,y=1}}) do
 local bad={};for k,v in pairs(plan) do bad[k]=v end;bad.after={};for k,v in pairs(plan.after) do bad.after[k]=v end
 bad.after.ending={kind="end",instance_id=tree.active_id,source=badsource,target={kind="level"}}
 local rejected;_,rejected=RW_CommitLevelTree(tree,bad);assert(not rejected.accepted and not tree.ending)
end
-- Surviving CRASH and WORD terminal results take priority over ending dispatch.
s=fixture({you,ending,{"ROCK","IS","CRASH"}});t,plan=act(tree_for(s));assert(RW_GetActiveLevel(t).world.infinite_loop and not t.ending)
for _,e in ipairs(plan.events or {}) do assert(e.kind~="end") end
-- Scoped END order and conversion preserve existing scoped terminal precedence.
s=fixture({you,{"LEVEL","IS","END"},{"LEVEL","IS","DEFEAT"}});t=act(tree_for(s));assert(t.ending and t.outcomes[t.active_id].kind=="win")
s=fixture({you,{"LEVEL","IS","DEFEAT"},{"LEVEL","IS","END"}});t=act(tree_for(s));assert(not t.ending and t.outcomes[t.active_id].kind=="defeat")
s=fixture({you,{"LEVEL","IS","WIN"},{"LEVEL","IS","END"}});t=act(tree_for(s));assert(not t.ending and t.outcomes[t.active_id].kind=="win")
s=fixture({you,{"LEVEL","IS","END"},{"AVATAR","IS","FLOAT"}});n,p=step(s);assert(not p.end_contact)
s=fixture({you,{"LEVEL","IS","END"},{"LEVEL","IS","FLOAT"},{"AVATAR","IS","FLOAT"}});n,p=step(s);assert(p.end_contact)
s=fixture({{"LEVEL","IS","YOU"},ending});t=act(tree_for(s));assert(t.ending)
s=fixture({{"LEVEL","IS","YOU"},ending,{"ROCK","IS","WIN"}});t=act(tree_for(s));assert(not t.ending and t.outcomes[t.active_id].kind=="win")
s=fixture({{"LEVEL","IS","END"},{"LEVEL","IS","BROKEN"},you});n,p=step(s);assert(not p.end_contact)
-- EMPTY's original END order quirk: END before YOU succeeds, reverse does not.
s=fixture({{"EMPTY","IS","END"},{"EMPTY","IS","YOU"}});t=act(tree_for(s));assert(t.ending and t.ending.source.kind=="empty")
s=fixture({{"EMPTY","IS","YOU"},{"EMPTY","IS","END"}});n,p=step(s);assert(not p.end_contact)
s=fixture({{"EMPTY","IS","END"},{"EMPTY","IS","YOU"},{"EMPTY","IS","DONE"}});n,p=step(s);assert(p.end_contact,"EMPTY DONE is only a sound flag")
s=fixture({{"EMPTY","IS","END"},{"EMPTY","IS","YOU"},{"EMPTY","IS","WIN"}});t=act(tree_for(s));assert(not t.ending and t.outcomes[t.active_id].kind=="win")
-- Empty placeholder declarations count for scoped queries even without eligible cells.
s=fixture({{"EMPTY","ON","ROCK","IS","YOU"},{"LEVEL","IS","END"}});n,p=step(s);assert(p.end_contact and p.end_contact.source.kind=="empty")
s=fixture({{"EMPTY","ON","ROCK","IS","END"},{"LEVEL","IS","YOU"}});n,p=step(s);assert(p.end_contact and p.end_contact.target.kind=="empty")
-- A child END commits progress before normal return/reload; Undo restores child.
local root=fixture({}).world;root.entities[3]={id=3,kind="object",class="object",archetype="cursor",x=12,y=12,direction="None"}
root.entities[4]={id=4,kind="object",class="object",archetype="level_block",x=12,y=12,direction="None",level_link={source_type="level_block",target="child",definition_id="child"}}
local child=fixture({you,ending}).world
local definitions={root=assert(RW_CreateLevelDefinition("root",root)),child=assert(RW_CreateLevelDefinition("child",child))}
tree=assert(RW_CreateLevelTree(definitions,"root"));local entered=act(tree,{type="confirm"});t=act(entered)
assert(#t.stack==0 and t.active_id==tree.active_id and t.ending.instance_id==entered.active_id)
u=RW_UndoLevelTree(t);assert(u.active_id==entered.active_id and not u.ending and #u.stack==1)
local transformed=fixture({you,{"LEVEL","IS","END"},{"LEVEL","IS","ROCK"}}).world
local defs={root=definitions.root,child=assert(RW_CreateLevelDefinition("child",transformed))}
local converting=assert(RW_CreateLevelTree(defs,"root"));local selected=act(converting,{type="confirm"});t=act(selected)
assert(not t.ending and t.outcomes[selected.active_id].kind=="transform" and #t.stack==0)
-- Installed real-unit post-HOLD END/WIN loop, unchanged, with host callbacks.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],"rb"));local source=f:read("*a");f:close()
local first=assert(source:find("\tisyou = getunitswitheffect(\"you\",false,delthese)",1,true))
local last=assert(source:find("\tdelthese,doremovalsound = handledels",first,true));local code=source:sub(first,last-1)
local checked=0
for control=0,3 do for af=0,1 do for bf=0,1 do for self=0,1 do for hasend=0,1 do for haswin=0,1 do
 local target=self==1 and 1 or 2
 local world={entities={[1]={id=1,x=5,y=5,behaviors={control=control%2==1,control2=control>=2,float=af==1}},[2]={id=2,x=5,y=5,behaviors={float=bf==1}}}}
 world.entities[target].behaviors["end"]=hasend==1;world.entities[target].behaviors.win=haswin==1
 local units={};for id,e in pairs(world.entities) do units[id]={fixed=id+1000,values={x=e.x,y=e.y},flags={dead=false}} end
 local ended,won=false,false
 local env={ipairs=ipairs,table=table,DEAD="dead",XPOS="x",YPOS="y",WORLD="world",BASEWORLD="base",MODE="mode",INEDITOR="editor",small=false,delthese={},
 generaldata={values={mode=0},strings={world="custom",base="baba"}},editor={values={editor=1}},
 getunitswitheffect=function(trait) if (trait=="you" and control%2==1) or (trait=="you2" and control>=2) then return {units[1]} end;return {} end,
 findfeature=function(_,_,trait) if (trait=="end" and hasend==1) or (trait=="win" and haswin==1) then return {{"rock"}} end end,
 findtype=function() return {target+1000} end,floating=function() return self==1 or af==bf end,
 checkeffecthistory=function() return 1,false end,MF_particles=function() end,MF_end_single=function() ended=true end,MF_win=function() won=true end,
 hasfeature=function(_,_,trait) if trait=="end" and hasend==1 then return true end end}
 assert(load(code,"installed END/WIN contacts","t",env))()
 assert((RW_ResolveEndContact(world)~=nil)==ended,"original real END mismatch")
 assert((RW_ResolveEndContact(world)~=nil or RW_HasWinContact(world))==won,"original real END/WIN result mismatch")
 checked=checked+1
end end end end end end
-- Installed scoped LEVEL END branch and its global Empty placeholder/FLOAT query.
first=assert(source:find('elseif (action == "end") then',1,true));first=assert(source:find('local yous =',first,true))
last=assert(source:find('elseif (action == "tele")',first,true));code=source:sub(first,last-1)
for control=0,3 do for uf=0,1 do for lf=0,1 do for ly=0,1 do for ey=0,1 do for ef=0,1 do
 local world={entities={[1]={id=1,x=5,y=5,behaviors={control=control%2==1,control2=control>=2,float=uf==1}}},level_behaviors={["end"]=true,control=ly==1,float=lf==1},empty_control_declared=ey==1,empty_control2_declared=false,empty_float_declared=ef==1}
 local ended=false;local env={ipairs=ipairs,table=table,WORLD="world",BASEWORLD="base",INEDITOR="editor",XPOS="x",YPOS="y",generaldata={strings={world="custom",base="baba"}},editor={values={editor=1}},
 findfeature=function(_,_,trait) local list={};if (trait=="you" and control%2==1) or (trait=="you2" and control>=2) then list[#list+1]={"avatar"} end;return list end,
 findall=function() return {1001} end,floating_level=function(id) return (id==2 and ef or uf)==lf end,
 findallfeature=function(_,_,trait) return ey==1 and trait=="you" and {2} or {} end,
 hasfeature=function(_,_,trait) return ly==1 and trait=="you" and true or nil end,
 mmf={newObject=function() return {values={x=5,y=5}} end},checkeffecthistory=function() return 1 end,MF_particles=function() end,
 MF_end_single=function() ended=true end,MF_win=function() end,MF_credits=function() end}
 assert(load("for _=1,1 do "..code.." end","installed LEVEL END","t",env))()
 assert((RW_ResolveEndContact(world,"level_end")~=nil)==ended,"original LEVEL END mismatch")
 checked=checked+1
end end end end end end
-- Execute original EMPTY END pair-update clause to retain its asymmetric typo.
first=assert(source:find('if (rule[3] == "end") and testcond(conds,2,i,j) then',1,true))
last=assert(source:find('if (rule[3] == "done")',first,true));code=source:sub(first,last-1)
for value=0,80 do
 local v=value;local words={};local effects={};for i=1,4 do local trait=({"end","you","you2"})[v%3+1];v=math.floor(v/3);words[i]={"empty","is",trait}
 effects[#effects+1]={op="grant_trait",trait=trait,target={kind="empty"},entity_ids={},cells={{x=1,y=1}}} end
 local env={ipairs=ipairs,string=string,rules=words,conds={},endpair="",bonuspair="",ending=false,testcond=function() return true end}
 assert(load("for _,rule in ipairs(rules) do "..code.." end","installed EMPTY END pair","t",env))()
 local projected=assert(RW_ProjectWorld({width=1,height=1,entities={}},effects))
 assert((RW_ResolveEndContact(projected)~=nil)==env.ending,"original EMPTY END order mismatch")
 checked=checked+1
end
print("PASS: END real/scoped/Empty conditions, ordered results, BONUS/DONE/CRASH, persistent tree ending/navigation/Undo and "..checked.." installed oracle cases")
