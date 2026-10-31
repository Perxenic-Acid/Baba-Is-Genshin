local directions={"Right","Up","Left","Down"}
local vectors={Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}}
local opposite={Right="Left",Up="Down",Left="Right",Down="Up"}
local function projected(moves,autos,chills,seed,sleep,still)
 local w=RW_CreateSession().world;w.width=30;w.height=30;w.random_state=seed
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=12,y=12,direction="Right",
  behaviors={move=moves>0,auto=autos>0,chill=chills>0,sleep=sleep,still=still}}}
 w.next_entity_id=10;w.trait_counts={[1]={move=moves,auto=autos,chill=chills}};return w
end
local function raw(w)
 local r={};for k,v in pairs(w) do if k~="trait_counts" then r[k]=v end end;r.entities={}
 for id,e in pairs(w.entities) do local c={};for k,v in pairs(e) do if k~="behaviors" then c[k]=v end end;r.entities[id]=c end
 return r
end
-- Original collection and the original state-3 reversal guard, not copied logic.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],"rb"));local source=f:read("*a");f:close()
local first=assert(source:find("function add_moving_units(",1,true));local last=source:find("\nfunction ",first+1,true)
local collection=source:sub(first,last and last-1 or #source)
local guard=assert(source:match('elseif %(state == 3%) then%s*if (.-) then'))
local reverses=assert(load('return function(data) return '..guard..' end',"installed reversal guard"))()
local cases=0
for moves=0,2 do for autos=0,2 do for chills=0,1 do for seed=1,8 do for sleep=0,1 do for still=0,1 do
 local state=seed;local unit={values={dir=0,x=12,y=12}}
 local env={ipairs=ipairs,pairs=pairs,table=table,DIR="dir",XPOS="x",YPOS="y",mmf={newObject=function() return unit end},getname=function() return "avatar" end,
  hasfeature=function() return sleep==1 and true or nil end,cantmove=function() return still==1 end,updatedir=function(_,d) unit.values.dir=d end,
  fixedrandom=function() state=state*48271%2147483647;return state%4 end}
 assert(load(collection,"installed MOVE/AUTO/CHILL collection","t",env))()
 local list,seen={},{}
 for _,spec in ipairs({{"move",moves},{"auto",autos},{"chill",chills}}) do local ids={};for i=1,spec[2] do ids[i]=1 end
  list,seen=env.add_moving_units(spec[1],ids,list,seen,{})
 end
 local w=projected(moves,autos,chills,seed,sleep==1,still==1)
 local d=directions[unit.values.dir+1];local v=vectors[d]
 -- Stop immediately in the collected final facing; a bounced move has ample room.
 w.entities[2]={id=2,kind="object",class="object",archetype="rock",x=12+v[1],y=12+v[2],direction="None",behaviors={block_entry=true}}
 local p=RW_ResolveAutomatic(w);local after=assert(RW_PreviewPlan(raw(w),p))
 local expected_dir=d;local distance=0
 if #list>0 and reverses(list[1]) then expected_dir=opposite[d];distance=list[1].moves end
 local displacement=vectors[expected_dir]
 assert(after.entities[1].x==12+displacement[1]*distance and after.entities[1].y==12+displacement[2]*distance,"original AUTO movement/reversal mismatch")
 assert(after.entities[1].direction==expected_dir,"original AUTO collected facing mismatch")
 assert((p.random_state and p.random_state.to or seed)==state and w.random_state==seed)
 cases=cases+1
end end end end end end
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local lifecycle={victims=RW_ResolveContactVictims,birth_products=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete,
 births=function(w,ids,c,rules) local p,e=RW_PlanHasBirths(w,ids,c);if not p then return nil,e end;return RW_InitializeBirthSpecifications(w,p,rules) end}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,automatic=RW_ResolveAutomatic,
 destroy=function(w,ids,c,k,deaths,rules) return RW_PlanDestructionPhase(w,ids,c,k,lifecycle,deaths,rules) end,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,lifecycle,rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width=24;w.height=24;w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag";w.language.nouns.LEVEL={tag="level",block_type="level_block"}
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=12,y=18,direction="Right"},[2]={id=2,kind="object",class="object",archetype="rock",x=13,y=18,direction="Left"}};w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
 w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"} end end
 assert(w.language.properties.AUTO=="auto");return s
end
local function step(s)
 local p,e=RW_PlanTurn(s.world,{type="wait"},services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n,p
end
local s=fixture({{"AVATAR","IS","AUTO"},{"ROCK","IS","STOP"}});local n,p=step(s);assert(n.world.entities[1].x==12 and n.world.entities[1].direction=="Right")
s=fixture({{"AVATAR","IS","AUTO","AND","MOVE"},{"ROCK","IS","STOP"}});n=step(s);assert(n.world.entities[1].x==10 and n.world.entities[1].direction=="Left")
s=fixture({{"AVATAR","IS","AUTO"},{"AVATAR","IS","AUTO"},{"ROCK","IS","PUSH"}});n=step(s);assert(n.world.entities[1].x==14 and n.world.entities[2].x==15 and n.world.entities[2].direction=="Right")
s=fixture({{"AVATAR","IS","AUTO","AND","WEAK"},{"AVATAR","HAS","FLAG"},{"ROCK","IS","STOP"}});n=step(s)
assert(not n.world.entities[1] and n.world.entities[s.world.next_entity_id].archetype=="flag" and n.world.entities[s.world.next_entity_id].x==12)
s=fixture({{"AVATAR","IS","AUTO","AND","BROKEN"}});n=step(s);assert(n.world.entities[1].x==12)
s=fixture({{"AVATAR","IS","AUTO"},{"AVATAR","IS","NOT","AUTO"}});n=step(s);assert(n.world.entities[1].x==12)
s=fixture({{"AVATAR","ON","ROCK","IS","AUTO"}});s.world.entities[2].x=12;n=step(s);assert(n.world.entities[1].x==13)
s=fixture({{"AVATAR","IS","AUTO","AND","REVERSE"}});n=step(s);assert(n.world.entities[1].x==11 and n.world.entities[1].direction=="Right")
s=fixture({{"AVATAR","IS","AUTO","AND","SLEEP"}});n=step(s);assert(n.world.entities[1].x==12)
s=fixture({{"AVATAR","IS","AUTO","AND","LOCKEDRIGHT"}});n=step(s);assert(n.world.entities[1].x==12)
s=fixture({{"AVATAR","IS","AUTO","AND","CHILL"},{"ROCK","IS","STOP"}});s.world.entities[2].x=12;s.world.entities[2].y=19;n=step(s)
assert(n.world.entities[1].y==18 and n.world.entities[1].direction=="Down","AUTO-first CHILL must not bounce")
s=fixture({{"AVATAR","IS","AUTO","AND","CHILL","AND","LOCKEDRIGHT"},{"ROCK","IS","STOP"}});s.world.entities[2].x=12;s.world.entities[2].y=19;n=step(s)
assert(n.world.entities[1].y==17 and n.world.entities[1].direction=="Up","uncollected locked AUTO must not suppress CHILL bounce")
for _,dir in ipairs({"Mid","None"}) do s=fixture({{"AVATAR","IS","AUTO"}});s.world.entities[1].direction=dir;n=step(s);assert(n.world.entities[1].x==12 and n.world.entities[1].direction==dir) end
local function scoped(rows)
 local w=fixture(rows).world;local frame=assert(RW_CompileWorld(w,cs));local denied,traits={},{}
 for _,r in ipairs(frame.relations) do if r.op=="deny_level_trait" then denied[r.trait]=true end end
 for _,r in ipairs(frame.relations) do if r.op=="level_trait" and not denied[r.trait] then traits[#traits+1]=r.trait end end
 return assert(RW_ProjectWorld(w,frame.effects,traits))
end
local world=scoped({{"LEVEL","IS","AUTO","AND","AUTO","AND","SLEEP","AND","STILL"}});assert(RW_GetAutoTurnCount(world)==2)
world=scoped({{"LEVEL","IS","AUTO"},{"LEVEL","IS","NOT","AUTO"}});assert(RW_GetAutoTurnCount(world)==0)
world=scoped({{"LEVEL","IS","AUTO"},{"LEVEL","IS","BROKEN"}});assert(RW_GetAutoTurnCount(world)==0)
-- Query the same original AUTO_ON assignment used by statusblock/startblock.
f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],"rb"));source=f:read("*a");f:close()
first=assert(source:find('generaldata5.values[AUTO_ON] = 0',1,true));last=assert(source:find('if (ids == nil) then',first,true));local assignment=source:sub(first,last-1)
for count=0,6 do local env={generaldata5={values={}},AUTO_ON="auto",featureindex={level=true},hasfeature_count=function() return count>0 and count or nil end}
 assert(load(assignment,"installed scoped AUTO count","t",env))();assert(RW_GetAutoTurnCount({},(function() local t={};for i=1,count do t[i]="auto" end;return t end)())==env.generaldata5.values.auto)
end
print("PASS: AUTO nonbouncing weighted motion, MOVE/CHILL precedence, PUSH/WEAK/HAS/status/conditions/Undo, scoped count and "..cases.." installed collection/guard oracle cases")

-- Pure clock input collection and whole-tree pulse transactions.
local nav={};for k,v in pairs(services) do nav[k]=v end
nav.active=RW_GetActiveLevel;nav.update=RW_UpdateActiveLevel;nav.enter=RW_EnterLevel;nav.return_level=RW_ReturnLevel
nav.selectors=RW_LevelSelectorIDs;nav.place_selectors=RW_PlaceLevelSelectors;nav.bind_entry=RW_BindLevelEntry
nav.commit_session=RW_Commit;nav.outcome=RW_RecordLevelOutcome;nav.candidates=RW_LevelSelectionCandidates
nav.win=RW_HasWinContact;nav.level_outcome=RW_ResolveLevelPropertyOutcome;nav.auto_count=RW_GetAutoTurnCount
local function tree_for(rows)
 local s=fixture(rows);return assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",s.world))},"root"))
end
local function command(t,a)
 local p,e=RW_PlanAutoCommand(t,a,nav);assert(p,e and e.reason)
 local n,r;if p.kind=="auto_input" then n,r=RW_CommitAutoInput(t,p) else n,r=RW_CommitLevelTree(t,p) end
 assert(r.accepted,r.reason);return n,p
end
local function pulse(t)
 local p,e=RW_PlanAutoPulse(t,nav);assert(p,e and e.reason)
 local n,r;if p.kind=="auto_input" then n,r=RW_CommitAutoInput(t,p) else n,r=RW_CommitLevelTree(t,p) end
 assert(r.accepted,r.reason);return n,p
end
local t=tree_for({{"LEVEL","IS","AUTO"},{"LEVEL","IS","AUTO"},{"AVATAR","IS","YOU"},{"ROCK","IS","YOU2"}})
local original=t;local base=RW_GetActiveLevel(t).world
local queued,qp=command(t,{type="move",dx=1,dy=0})
assert(queued.auto_input[1]==0 and not queued.auto_input[2]);assert(RW_GetActiveLevel(queued).world==base and #queued.history==0)
queued=command(queued,{type="move",dx=0,dy=-1,player=2});assert(queued.auto_input[2]==1)
local finished,pp=pulse(queued);local w=RW_GetActiveLevel(finished).world
assert(#pp.pulse_turns==2 and w.entities[1].x==14 and w.entities[2].y==16)
assert(w.chance_seed==48271*48271%2147483647 and #finished.history==1 and next(finished.auto_input)==nil)
local restored=RW_UndoLevelTree(finished);assert(RW_GetActiveLevel(restored).world==base and restored.auto_input[1]==0 and restored.auto_input[2]==1)
assert(original.auto_input==nil and base.last_input==nil)
-- Last direction replaces its own channel; waiting is an explicit stored input.
queued=command(queued,{type="wait",player=1});assert(queued.auto_input[1]==4 and queued.auto_input[2]==1)
finished=pulse(queued);assert(RW_GetActiveLevel(finished).world.entities[1].x==12)
t=tree_for({{"LEVEL","IS","AUTO"},{"AVATAR","IS","YOU"}})
queued=command(t,{type="move",dx=0,dy=1,player=2});assert(queued.auto_input[1]==3 and queued.auto_input[2]==3)
finished=pulse(queued);assert(RW_GetActiveLevel(finished).world.entities[1].y==19)
-- Conditional/negative YOU2 declaration presence prevents primary copying.
for _,row in ipairs({{"ROCK","ON","FLAG","IS","YOU2"},{"ROCK","IS","NOT","YOU2"}}) do
 t=tree_for({{"LEVEL","IS","AUTO"},{"AVATAR","IS","YOU"},row})
 queued=command(t,{type="move",dx=0,dy=1,player=2});assert(queued.auto_input[1]==nil and queued.auto_input[2]==3)
 finished=pulse(queued);assert(RW_GetActiveLevel(finished).world.entities[1].y==18)
end
-- Empty pulse waits but advances automatic motion; no queued state leaks to the next pulse.
t=tree_for({{"LEVEL","IS","AUTO"},{"AVATAR","IS","AUTO"}})
finished=pulse(t);assert(RW_GetActiveLevel(finished).world.entities[1].x==13 and RW_GetActiveLevel(finished).world.last_input=="wait")
local second=pulse(finished);assert(RW_GetActiveLevel(second).world.entities[1].x==14)
-- Without clock input is immediate, still remembered until command_auto clears it.
t=tree_for({{"AVATAR","IS","YOU"}});queued=command(t,{type="move",dx=1,dy=0})
assert(RW_GetActiveLevel(queued).world.entities[1].x==13 and #queued.history==1 and queued.auto_input[1]==0)
finished,pp=pulse(queued);assert(#pp.pulse_turns==0 and #finished.history==1 and next(finished.auto_input)==nil)
-- Queue commits cannot alter any other tree fact or bypass terminal locks.
t=tree_for({{"LEVEL","IS","AUTO"}});local plan=assert(RW_PlanAutoCommand(t,{type="wait"},nav))
local bad={};for k,v in pairs(plan) do bad[k]=v end;bad.after={};for k,v in pairs(plan.after) do bad.after[k]=v end;bad.after.bonus_count=100
local _,r=RW_CommitAutoInput(t,bad);assert(not r.accepted)
local other=command(t,{type="wait"});_,r=RW_CommitAutoInput(other,plan);assert(not r.accepted)
plan.after.auto_input={[3]=0};_,r=RW_CommitAutoInput(t,plan);assert(not r.accepted)
t.instances[t.active_id].world.infinite_loop=true
local no,e=RW_PlanAutoPulse(t,nav);assert(not no and e.reason=="infinite_loop_undo_only")
_,r=RW_CommitAutoInput(t,plan);assert(not r.accepted and r.reason=="infinite_loop_undo_only")
print("PASS: AUTO queue isolation/replacement/fallback, weighted dual pulses, RNG/input/history/Undo, no-clock clearing and guarded queue Commit")

-- Run installed command()/command_auto() unchanged with native calls captured.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/syntax.lua]],"rb"));local syntax=file:read("*a");file:close()
local original_commands=assert(syntax:match("(function command%(key,player_%).-)\nfunction dolog"))
local cases=0
for count=0,2 do for second_channel=0,1 do for dir=0,4 do for player=1,2 do
 local rows={{"AVATAR","IS","YOU"}};for i=1,count do rows[#rows+1]={"LEVEL","IS","AUTO"} end
 if second_channel==1 then rows[#rows+1]={"ROCK","IS","YOU2"} end
 local t=tree_for(rows);local calls={};local env=setmetatable({keys={test=dir},auto_dir={},AUTO_ON="auto",VISION="vision",
  generaldata5={values={auto=count}},spritedata={values={vision=0}},featureindex=second_channel==1 and {you2={}} or {},
  ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}},do_mod_hook=function() end,dolog=function() end,MF_update=function() end,
  movecommand=function(x,y,d,p,d2) calls[#calls+1]={x,y,d,p,d2} end},{__index=_G})
 assert(load(original_commands,"@installed_AUTO_commands","t",env))()
 local v=env.ndirs[dir+1];local action=dir==4 and {type="wait",player=player} or {type="move",dx=v[1],dy=v[2],player=player}
 env.command("test",player);local queued=command(t,action)
 for p=1,2 do assert(queued.auto_input[p]==env.auto_dir[p],"installed AUTO queue mismatch") end
 local immediate=calls;calls={};env.command_auto();local finished,plan=pulse(queued)
 assert(#plan.pulse_turns==#calls and next(finished.auto_input)==nil)
 local expected={{12,18},{13,18}}
 for _,list in ipairs({immediate,calls}) do for _,call in ipairs(list) do
  local function move(id,d) local v=env.ndirs[d+1];expected[id][1]=expected[id][1]+v[1];expected[id][2]=expected[id][2]+v[2] end
  if call[4]==1 then move(1,call[3])
  elseif call[4]==2 then move(second_channel==1 and 2 or 1,call[3])
  else assert(call[4]==3);move(1,call[3]);if second_channel==1 then move(2,call[5]) end end
 end end
 local actual=RW_GetActiveLevel(finished).world
 for id=1,2 do assert(actual.entities[id].x==expected[id][1] and actual.entities[id].y==expected[id][2],"installed AUTO command direction mismatch") end
 cases=cases+1
end end end end
assert(cases==60)
print("PASS: installed command/command_auto queue and pulse-count oracle (60 cases)")

t=tree_for({{"LEVEL","IS","AUTO"},{"LEVEL","IS","AUTO"},{"AVATAR","IS","CRASH"}})
queued=command(t,{type="move",dx=1,dy=0})
finished,pp=pulse(queued);assert(#pp.pulse_turns==1 and RW_GetActiveLevel(finished).world.infinite_loop)
restored=RW_UndoLevelTree(finished);assert(not RW_GetActiveLevel(restored).world.infinite_loop and restored.auto_input[1]==0)
-- A late nonterminal planning failure rejects the entire pulse, including prior turns.
t=tree_for({{"LEVEL","IS","AUTO"},{"LEVEL","IS","AUTO"},{"AVATAR","IS","YOU"}})
queued=command(t,{type="move",dx=1,dy=0});base=RW_GetActiveLevel(queued).world
local failing={};for k,v in pairs(nav) do failing[k]=v end;local calls=0
failing.resolve=function(w,a) calls=calls+1;if calls==2 then return {consumes_turn=false,changes={},reason="test_late_failure"} end;return nav.resolve(w,a) end
local rejected,why=RW_PlanAutoPulse(queued,failing);assert(not rejected and why.reason=="test_late_failure")
assert(RW_GetActiveLevel(queued).world==base and base.entities[1].x==12 and #queued.history==0 and queued.auto_input[1]==0)
print("PASS: AUTO triggering CRASH pulse prefix/Undo and atomic late failure")
