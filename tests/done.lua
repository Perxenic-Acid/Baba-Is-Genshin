local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local lifecycle={victims=RW_ResolveContactVictims,birth_products=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete,
 births=function(w,ids,c,rules) local p,e=RW_PlanHasBirths(w,ids,c);if not p then return nil,e end;return RW_InitializeBirthSpecifications(w,p,rules) end}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,lifecycle,rules) end,
 done=function(w,p,r) local ids,events,win=RW_ResolveDone(p,r);local plan,e=RW_PlanDelete(w,ids);if plan then plan.events,plan.done_win=events,win end;return plan,e end,
 more=function(w,p,rules) return RW_PlanInitializedCreation(w,RW_ResolveMoreProducts(p),rules,{initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate}) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width=32;w.height=32;w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag";w.language.nouns.LEVEL={tag="level",block_type="level_block"}
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=12,y=18,direction="Right"},
 [2]={id=2,kind="object",class="object",archetype="rock",x=12,y=18,direction="Left"}}
 w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
 w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"} end end
 assert(w.language.properties.DONE=="done");return s
end
local function step(s,svc)
 local p,e=RW_PlanTurn(s.world,{type="wait"},svc or services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n,p
end
local function count(w,name) local n=0;for _,e in pairs(w.entities) do if e.archetype==name then n=n+1 end end;return n end
local s=fixture({{"ROCK","IS","DONE"},{"ROCK","IS","SAFE"},{"ROCK","HAS","FLAG"}})
local n,p=step(s);assert(not n.world.entities[2] and count(n.world,"flag")==0 and n.world.next_entity_id==s.world.next_entity_id)
assert(#p.events==1 and p.events[1].kind=="done" and p.events[1].direction=="Left")
s=fixture({{"ROCK","IS","DONE","AND","MORE","AND","CRASH"}});n=step(s)
assert(count(n.world,"rock")==0 and not n.world.infinite_loop,"DONE must precede MORE and CRASH")
s=fixture({{"ROCK","IS","DONE"},{"ROCK","IS","NOT","DONE"}});n=step(s);assert(n.world.entities[2])
s=fixture({{"ROCK","IS","DONE"},{"ROCK","IS","BROKEN"}});n=step(s);assert(n.world.entities[2])
s=fixture({{"ROCK","ON","AVATAR","IS","DONE"}});n=step(s);assert(not n.world.entities[2])
s.world.entities[1].x=15;n=step(s);assert(n.world.entities[2])
s=fixture({{"AVATAR","IS","DONE"},{"ROCK","ON","AVATAR","IS","MORE"}});n=step(s)
assert(count(n.world,"rock")==1,"MORE condition must see DONE removal")
s=fixture({{"AVATAR","IS","DONE"},{"AVATAR","IS","SINK"}});n=step(s)
assert(not n.world.entities[1] and n.world.entities[2],"removed DONE must not SINK its former co-occupant")
s=fixture({{"AVATAR","IS","ROCK"},{"ROCK","IS","DONE"}});n=step(s)
assert(not n.world.entities[1] and not n.world.entities[2],"DONE must include converted sources")
s=fixture({{"TEXT","IS","DONE"},{"ROCK","IS","MORE"},{"TEXT","HAS","FLAG"}});n=step(s)
assert(count(n.world,"rock")==5 and count(n.world,"flag")==0,"DONE Text must not erase frozen MORE declarations")
for _,e in pairs(n.world.entities) do assert(e.class~="text") end
local later=step(n);assert(count(later.world,"rock")==5,"deleted Text leaked into next turn")
-- Post-DONE contact/HAS births are not immediately DONE this turn.
s=fixture({{"AVATAR","IS","SINK"},{"AVATAR","HAS","FLAG"},{"FLAG","IS","DONE"}});n=step(s)
assert(count(n.world,"flag")==1);later=step(n);assert(count(later.world,"flag")==0)
-- Scoped LEVEL DONE retires all real identities, including protected/broken Text.
s=fixture({{"LEVEL","IS","DONE"},{"ROCK","IS","SAFE"},{"ROCK","HAS","FLAG"}});n,p=step(s)
assert(not next(n.world.entities) and n.world.next_entity_id==s.world.next_entity_id and not n.world.infinite_loop)
s=fixture({{"LEVEL","IS","DONE"},{"LEVEL","IS","NOT","DONE"}});n=step(s);assert(n.world.entities[1])
s=fixture({{"LEVEL","IS","DONE"},{"LEVEL","IS","BROKEN"}});n=step(s);assert(n.world.entities[1],"scoped BROKEN must disable DONE")
local audible={};for k,v in pairs(services) do audible[k]=v end;audible.play=RW_ResolvePlayEvents
s=fixture({{"ROCK","IS","DONE"},{"AVATAR","PLAY","C4"}});n,p=step(s,audible)
local played,retired=0,0;for _,event in ipairs(p.events) do if event.kind=="play" then played=played+1 elseif event.kind=="done" then retired=retired+1 end end
assert(played==1 and retired==1,"PLAY replaced earlier DONE events")
-- A later malformed phase rejects all prior deletion/input metadata.
local invalid={};for k,v in pairs(services) do invalid[k]=v end
invalid.done=function(w,p,r) local plan=services.done(w,p,r);plan.changes[1].from.direction="Down";return plan end
s=fixture({{"ROCK","IS","DONE"},{"AVATAR","IS","YOU"}})
local failed=RW_PlanTurn(s.world,{type="move",dx=1,dy=0},invalid)
assert(not failed and s.world.entities[1].x==12 and s.world.entities[2] and not s.world.last_input and not s.world.chance_seed)
-- Literal ALL directive is distinct from all ordinary units happening to be DONE.
s=fixture({{"ALL","IS","DONE"}});n,p=step(s);assert(p.done_win and not n.world.entities[1] and not n.world.entities[2])
s=fixture({{"AVATAR","IS","DONE"},{"ROCK","IS","DONE"}});n,p=step(s);assert(not p.done_win)
s=fixture({{"ALL","ON","FLAG","IS","DONE"},{"AVATAR","IS","DONE"}});n,p=step(s);assert(not p.done_win and n.world.entities[2])
-- Original threshold uses the repeated target list rather than unique coverage.
s=fixture({{"ALL","ON","FLAG","IS","DONE"},{"AVATAR","IS","DONE"},{"AVATAR","IS","DONE"}});n,p=step(s)
assert(p.done_win and n.world.entities[2],"original ALL DONE duplicate-target threshold lost")
s=fixture({{"ALL","IS","DONE"},{"ALL","IS","NOT","DONE"}});n,p=step(s);assert(not p.done_win and n.world.entities[1])
local nav={};for k,v in pairs(services) do nav[k]=v end
nav.active=RW_GetActiveLevel;nav.update=RW_UpdateActiveLevel;nav.update_instance=RW_UpdateLevelInstance;nav.enter=RW_EnterLevel;nav.return_level=RW_ReturnLevel
nav.selectors=RW_LevelSelectorIDs;nav.place_selectors=RW_PlaceLevelSelectors;nav.bind_entry=RW_BindLevelEntry
nav.commit_session=RW_Commit;nav.outcome=RW_RecordLevelOutcome;nav.candidates=RW_LevelSelectionCandidates
nav.win=RW_HasWinContact;nav.level_outcome=RW_ResolveLevelPropertyOutcome
s=fixture({{"ALL","IS","DONE"}});local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",s.world))},"root"))
local plan,e=RW_PlanLevelAction(tree,{type="wait"},nav);assert(plan,e and e.reason)
local t,r=RW_CommitLevelTree(tree,plan);assert(r.accepted,r.reason);assert(t.outcomes[t.active_id].kind=="win")
assert(RW_GetActiveLevel(RW_UndoLevelTree(t)).world.entities[1],"whole-tree DONE Undo lost objects")
-- Installed DONE block selection/removal: animation RNG is host-only, not simulation.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],"rb"));local source=f:read("*a");f:close()
local first=assert(source:find("\t\tif (generaldata2.values[ENDINGGOING] == 0) then",1,true))
local last=assert(source:find("\t\tlocal ismore =",first,true));local code=source:sub(first,last-1)
local checked=0
for mask=0,15 do for safe=0,3 do
 local world=fixture({}).world;world.entities={};world.trait_counts={};local originals,chosen={},{}
 for id=1,4 do
  local done=math.floor(mask/2^(id-1))%2==1;local protected=math.floor(safe/2^((id-1)%2))%2==1
  world.entities[id]={id=id,kind="object",class=id==4 and "text" or "object",archetype=id~=4 and "rock" or nil,text=id==4 and {name="ROCK"} or nil,
   x=id,y=3,direction="Up",behaviors={done=done,safe=protected,float=id%2==0}}
  originals[id]={fixed=id+1000,originalname="rock",strings={name="rock"},flags={dead=false},values={x=id,y=3,dir=1,id=id,float=id%2}}
  if done then chosen[#chosen+1]=originals[id];chosen[#chosen+1]=originals[id] end
 end
 local removed={};local env={ipairs=ipairs,table=table,doned={},delthese={},generaldata2={values={ending=0}},ENDINGGOING="ending",FLOAT="float",DEAD="dead",EFFECTCOUNT="effect",POSITIONING="position",
 XPOS="x",YPOS="y",DIR="dir",ID="id",UNITNAME="name",VISION="vision",CAMTARGET="camera",spritedata={values={vision=0}},math={random=function() return 0 end},
 getunitswitheffect=function() return chosen end,setsoundname=function() end,addundo=function() end,dynamicat=function() end,delunit=function(id) removed[id-1000]=true end}
 assert(load(code,"installed DONE block","t",env))()
 local ids=RW_ResolveDone(world,{})
 local seen={};for _,id in ipairs(ids) do seen[id]=true end
 for id=1,4 do assert((seen[id]==true)==(removed[id]==true),"original DONE removal mismatch") end
 checked=checked+1
end end
-- Original custom/editor ALL DONE decision, including Text and duplicate counts.
first=assert(source:find("\t\tif (featureindex[\"done\"] ~= nil) then",last,true))
last=assert(source:find("\t\tif (generaldata.strings[WORLD] == generaldata.strings[BASEWORLD]) and (generaldata.strings[CURRLEVEL] == \"305level\") then",first,true))
code=source:sub(first,last-1)
for mask=0,15 do for repeats=1,3 do
 local world={entities={},trait_counts={}};local units,targets,texts={}, {},{};local byid={}
 for id=1,4 do
  local level=id==3;local text=id==4;local done=math.floor(mask/2^(id-1))%2==1
  world.entities[id]={id=id,class=text and "text" or "object",archetype=level and "level_block" or "rock",behaviors={done=done}}
  world.trait_counts[id]={done=repeats};local unit={fixed=id+1000,className=level and "level" or "rock"};units[#units+1]=unit;byid[id+1000]=unit
  if text then texts[#texts+1]=unit end
  if done then for i=1,repeats do targets[#targets+1]=id+1000 end end
 end
 local won=false;local env={ipairs=ipairs,table=table,featureindex={done={{{"all","is","done"},{}}}},donethings={},units=units,codeunits=texts,objectlist={level=true},
 generaldata={values={wintimer=0},strings={world="custom",base="baba"}},WINTIMER="wintimer",WORLD="world",BASEWORLD="base",editor={values={ineditor=1}},INEDITOR="ineditor",
 findallfeature=function() return targets end,mmf={newObject=function(id) return byid[id] end},checkeffecthistory=function() return 1 end,
 MF_playsound=function() end,MF_done_single=function() end,MF_win=function() won=true end}
 assert(load(code,"installed ALL DONE threshold","t",env))()
 local _,_,actual=RW_ResolveDone(world,{{op="all_done"}});assert(actual==won,"original ALL DONE threshold mismatch")
 checked=checked+1
end end
print("PASS: DONE no-HAS/SAFE/status/conditions/conversion/MORE/frozen Text/newborns/LEVEL/ALL/Undo and "..checked.." installed oracle cases")
