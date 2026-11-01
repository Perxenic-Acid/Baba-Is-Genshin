local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,
 project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
 convert=RW_PlanConversions,refresh=RW_EvaluateRules,tele=RW_ResolveTele,
 back_status=RW_PlanBackStatus,back_history=RW_PlanBackHistoryMotion,back_retain=RW_BackRetainDecision,
 follow=function(w,relations) return RW_ResolveFollow(w,RW_ResolveVerbTargets(w,relations,"follow")) end,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
  births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
  return f.effects,nil,f.relations,f.rules,f.code_status end}
local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width=20;w.height=24;w.next_entity_id=10
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Right"},
 [2]={id=2,kind="object",class="object",archetype="rock",x=5,y=2,direction="Right"},
 [3]={id=3,kind="object",class="object",archetype="rock",x=12,y=2,direction="Right"}}
 assert(w.language.properties.BACK=="back");w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag"
 w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
 for row,words in ipairs(rows or {}) do for x,word in ipairs(words) do
  local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=6+row*2,direction="Right"}
 end end
 return s
end
local wait={type="wait"};local right={type="move",dx=1,dy=0};local left={type="move",dx=-1,dy=0}
local function step(s,action,svc)
 svc=svc or services
 local plan,e=RW_PlanTurn(s.world,action or wait,svc,s);assert(plan,e and (e.stage..":"..e.reason))
 local next,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 assert(RW_Undo(next).world==s.world and RW_Undo(next).back_frame_count==s.back_frame_count)
 assert(not next.world.tele_suppressed)
 return next,plan
end
local function stages(plan) local r={};for i,stage in ipairs(plan.stages) do r[stage.name]=i end;return r end

-- Accepted input/RNG-only waits remain user-undoable but do not occupy BACK slots.
local s=fixture()
for i=1,5 do local old=s;s=step(s);assert(s.back_frame_count==1 and #s.history==i and s.world.chance_seed~=old.world.chance_seed) end
s.world.entities[1].x=1
local next,plan=step(s,left);assert(plan.back_frame.retain and next.back_frame_count==2 and next.world.entities[1].direction=="Left")
local still,p=step(next,left);assert(not p.back_frame.retain and still.back_frame_count==2)

-- Activation, current-prefix playback, an older retained frame and expiry.
s=fixture({{"AVATAR","IS","BACK"}})
local one,p1=step(s,right);assert(one.world.entities[1].x==3 and one.world.entities[1].back_init==2 and one.back_frame_count==2)
local two,p2=step(one,right);assert(two.world.entities[1].x==3 and two.back_frame_count==3)
local three,p3=step(two);assert(three.world.entities[1].x==2 and three.back_frame_count==4)
local four,p4=step(three);assert(four.world.entities[1].x==2 and four.back_frame_count==4 and not p4.back_frame.retain)
assert(p1.stages[1].name=="back_status_before" and stages(p2).conversion<stages(p2).back)
assert(p2.stages[stages(p2).back].plan.tele_suppressed[1])
local undone=RW_Undo(three);local replay=step(undone)
assert(replay.world.entities[1].x==three.world.entities[1].x and replay.back_frame_count==three.back_frame_count)
-- Lost eligibility retracts only in the next input status pass, not mid-move.
s=fixture({{"AVATAR","ON","ROCK","IS","BACK"}});s.world.entities[2].x=2
one=step(s,right);assert(one.world.entities[1].back_init==2 and one.world.entities[1].x==3)
two=step(one);assert(two.world.entities[1].back_init==0)
s=fixture({{"AVATAR","IS","BACK"},{"AVATAR","IS","NOT","BACK"}})
one=step(s);assert(not one.world.entities[1].back_init and one.back_frame_count==1)
-- BROKEN refresh precedes BACK status, including unconditional declarations.
s=fixture({{"AVATAR","IS","BACK"},{"AVATAR","IS","BROKEN"}});s.world.entities[1].back_init=1
one,plan=step(s,right);assert(one.world.entities[1].broken==1 and one.world.entities[1].back_init==0 and one.world.entities[1].x==2)
assert(stages(plan).status_before<stages(plan).back_status_before and not plan.back_frame.retain)
s=fixture({{"IDLE","AVATAR","IS","BACK"}})
one=step(s);assert(one.world.entities[1].back_init==2)
two=step(one,right);assert(two.world.entities[1].back_init==0)

-- FOLLOW's direction/memory update is part of the current BACK frame.
s=fixture({{"AVATAR","IS","BACK"},{"AVATAR","FOLLOW","ROCK"}})
s.world.entities[1].back_init=1;s.world.entities[1].direction="Left";s.world.entities[2].x=3
one,plan=step(s);assert(one.world.entities[1].direction=="Left" and one.world.entities[1].followed==2)
assert(stages(plan).follow<stages(plan).back and plan.back_frame.retain)
-- Forward only the current turn's physical marks to TELE; no persistence or RNG.
s=fixture({{"AVATAR","IS","BACK"},{"ROCK","IS","TELE"}})
s.world.entities[1].back_init=1;s.world.entities[2].x=2
one,plan=step(s,right);assert(one.world.entities[1].x==2 and not one.world.random_state and stages(plan).back<stages(plan).tele)
two=step(one);assert(two.world.entities[1].x==12 and two.world.random_state)
-- A marked rider retired by DONE before TELE must not invalidate its old tag.
local done_services=copy(services)
done_services.done=function(w,p,relations)
 local ids=RW_ResolveDone(p,relations);return RW_PlanDelete(w,ids)
end
s=fixture({{"AVATAR","IS","BACK"},{"ROCK","IS","TELE"},{"AVATAR","IS","DONE"}})
s.world.entities[1].back_init=1;s.world.entities[2].x=2
one,plan=step(s,right,done_services)
assert(not one.world.entities[1] and stages(plan).back<stages(plan).done and stages(plan).done<stages(plan).tele)

-- A compile limit after historical motion commits that triggering board and
-- clocks, then permits only Undo; it must not reject the command or rerun BACK.
s=fixture({{"AVATAR","IS","BACK"}});one=step(s,right);two=step(one,right)
local limited=copy(services)
limited.evaluate=function(w)
 if w.entities[1].x==2 then return nil,"word_rule_limit" end
 return services.evaluate(w)
end
local terminal,locked_plan=step(two,wait,limited)
assert(terminal.world.infinite_loop and terminal.world.entities[1].x==2 and terminal.back_frame_count==4)
assert(stages(locked_plan).back and RW_Undo(terminal).world==two.world)

-- Text restored by BACK forms TEXT IS BROKEN. Apply code status once at that
-- reading barrier before contacts, without recompiling the frozen contact frame.
s=fixture();s.world.entities[10]={id=10,kind="object",class="text",text={name="TEXT"},x=1,y=6,direction="Right",back_init=2}
s.world.entities[11]={id=11,kind="object",class="text",text={name="IS"},x=2,y=6,direction="Right"}
s.world.entities[12]={id=12,kind="object",class="text",text={name="BROKEN"},x=3,y=6,direction="Right"};s.world.next_entity_id=13
s.world.rule_sources[#s.world.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="class",value="text"},trait="back"}}}
local historical={consumes_turn=true,changes={{kind="move",entity_id=10,from={x=1,y=6,direction="Right"},to={x=2,y=6,direction="Right"}}},back_frame={from=1,retain=true}}
local r;s,r=RW_Commit(s,historical);assert(r.accepted)
s,r=RW_Commit(s,{consumes_turn=true,changes={},back_frame={from=2,retain=true}});assert(r.accepted)
one,plan=step(s);assert(one.world.entities[10].x==1 and one.world.entities[10].broken==1)
assert(stages(plan).back<stages(plan).code_status_after_back and stages(plan).code_status_after_back<stages(plan).sink)

-- Previews cannot leave clocks/input/RNG/history changes behind after any late
-- failure; legacy sessions cannot silently reinterpret their capped Undo frames.
local failing=copy(services);failing.tele=function() return nil,"tele_injected_failure" end
s=fixture({{"AVATAR","IS","BACK"},{"ROCK","IS","TELE"}})
local rejected,e=RW_PlanTurn(s.world,right,failing,s)
assert(not rejected and e.stage=="tele" and not s.back_frame_count and not s.world.entities[1].back_init and not s.world.last_input and not s.world.chance_seed and #s.history==0)
local legacy=fixture();legacy=select(1,RW_Commit(legacy,{consumes_turn=true,changes={}}))
rejected,e=RW_PlanTurn(legacy.world,wait,services,legacy);assert(not rejected and e.reason=="back_history_unavailable")
local mismatch=fixture();rejected,e=RW_PlanTurn(s.world,wait,services,mismatch);assert(not rejected and e.reason=="invalid_back_session")
local invalid=fixture();invalid.back_frame_count=0
rejected,e=RW_PlanTurn(invalid.world,wait,services,invalid);assert(not rejected and e.reason=="invalid_back_clock")
for _,terminal in ipairs({"infinite_loop","too_complex"}) do
 local locked=fixture();locked.world[terminal]=true;rejected,e=RW_PlanTurn(locked.world,right,services,locked)
 assert(not rejected and e.reason==terminal.."_undo_only")
end
-- The production-generated session transaction remains one whole-tree Undo.
s=fixture({{"AVATAR","IS","BACK"}})
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",s.world))},"root"))
local active=RW_GetActiveLevel(tree);one,plan=step(active,right)
local updated=assert(RW_UpdateActiveLevel(tree,one))
local completed,result=RW_CommitLevelTree(tree,{before=tree,after=updated});assert(result.accepted)
assert(RW_UndoLevelTree(completed).instances[tree.active_id]==active)
local reload=assert(RW_ReloadLevel(completed,completed.active_id))
assert(RW_GetActiveLevel(reload).back_frame_count==nil and not RW_GetActiveLevel(reload).world.entities[1].back_init)
local boundary,result=RW_CommitLevelTree(completed,{before=completed,after=reload});assert(result.accepted)
assert(RW_UndoLevelTree(boundary).instances[tree.active_id]==one)
print("PASS: session BACK scheduler activation/retraction/conditions/NOT/BROKEN/IDLE, current/past frames, FOLLOW, TELE/RNG, Text code-status barrier, retention, replay/Undo and atomic failures")

-- Native BACK restoration calls addunit(...,true), retaining unit.new=true.
-- Conversion products instead explicitly clear that flag. Only the former
-- receive current-turn WEAK contact grace, including allocated duplicate slots.
for _,scenario in ipairs({{copies=1},{copies=2},{copies=1,repeated=true}}) do
 local copies=scenario.copies
 s=fixture();s.world.entities[1].back_init=2
 s.world.entities[2].archetype="flag";s.world.entities[2].x=2
 s.world.entities[3]=nil
 for _,pair in ipairs({{"rock","back"},{"flag","back"},{"avatar","weak"}}) do
  s.world.rule_sources[#s.world.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value=pair[1]},trait=pair[2]}}}
 end
 local relations={};for i=1,copies do relations[i]={op="transform",source_type="avatar",target_type="rock"} end
 local ops,e,a,_,_,events=RW_PlanConversions(s.world,relations);assert(ops,e)
 local history={consumes_turn=true,changes=ops,id_allocation=a,back_conversions=events}
 if scenario.repeated then
  local mid=assert(RW_PreviewPlan(s.world,history))
  local changes,why,allocation,_,_,conversions=RW_PlanConversions(mid,{{op="transform",source_type="rock",target_type="flag"}});assert(changes,why)
  history=assert(RW_PlanStages(s.world,{{name="first",plan=history},{name="second",plan={consumes_turn=true,changes=changes,id_allocation=allocation,back_conversions=conversions}}}))
 end
 history.back_frame={from=1,retain=true}
 s,r=RW_Commit(s,history);assert(r.accepted,r.reason)
 s,r=RW_Commit(s,{consumes_turn=true,changes={},back_frame={from=2,retain=true}});assert(r.accepted,r.reason)
 local restored,p=step(s);local count=0
 for _,u in pairs(restored.world.entities) do if u.archetype=="avatar" then count=count+1;assert(u.x==2 and u.y==2 and not u.weak_new) end end
 assert(count==(scenario.repeated and 2 or copies) and stages(p).back<stages(p).weak,"restored WEAK must survive its birth turn")
 if scenario.repeated then local allocated=false
  for _,op in ipairs(p.stages[stages(p).back].plan.changes) do if op.kind=="create" and op.to.archetype=="avatar" then allocated=true end end
  assert(allocated,"repeated restoration must exercise allocated birth grace")
 end
 local expired=step(restored)
 for _,u in pairs(expired.world.entities) do assert(u.archetype~="avatar","WEAK birth grace must expire on next input") end
 assert(RW_Undo(expired).world==restored.world and RW_Undo(restored).world==s.world)
end
print("PASS: BACK primary/duplicate restored WEAK contact grace, transient expiry and atomic Undo")

-- The real scheduler must preserve SHIFT history metadata through its phase
-- adapter. A locked rider stays put but still gets native final alignment.
s=fixture({{"AVATAR","IS","BACK"},{"ROCK","IS","SHIFT"},{"ROCK","IS","TELE"}})
s.world.entities[1].back_init=1;s.world.entities[2].x=2
s.world.rule_sources[#s.world.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="lockedright"}}}
local shifted=copy(services);shifted.shift=RW_ResolveShift
one,plan=step(s,wait,shifted)
local order=stages(plan)
assert(#plan.stages[order.shift].plan.motion_history==1 and #plan.stages[order.shift].plan.changes==0)
assert(plan.stages[order.back].plan.tele_suppressed[1] and one.world.entities[1].x==2 and not one.world.random_state)
assert(order.shift<order.back and order.back<order.tele and one.back_frame_count==2)
print("PASS: scheduled SHIFT no-op current-frame BACK playback and transient TELE suppression without RNG")

-- Native-ledger playback must retain effective intermediate BACK updates even
-- when its summary is empty, so another selected retained frame can replay them.
s=fixture({{"AVATAR","IS","BACK"}});s.world.entities[1].back_init=2
local cycle=assert(RW_PlanStages(s.world,{
 {name="out",plan={consumes_turn=true,changes={{kind="move",entity_id=1,from={x=2,y=2,direction="Right"},to={x=3,y=2,direction="Right"}}}}},
 {name="home",plan={consumes_turn=true,changes={{kind="move",entity_id=1,from={x=3,y=2,direction="Right"},to={x=2,y=2,direction="Right"}}}}}}))
cycle.back_frame={from=1,retain=true};s,r=RW_Commit(s,cycle);assert(r.accepted,r.reason)
s,r=RW_Commit(s,{consumes_turn=true,changes={},back_frame={from=2,retain=true}});assert(r.accepted,r.reason)
one,plan=step(s);local back=plan.stages[stages(plan).back].plan
assert(#back.changes==0 and #back.motion_history==2 and back.tele_suppressed[1] and one.back_frame_count==4)
local rearmed,r=RW_Commit(one,{consumes_turn=true,changes={{kind="back_init",entity_id=1,from=2,to=4}},back_frame={from=4,retain=true}});assert(r.accepted,r.reason)
two,plan=step(rearmed);back=plan.stages[stages(plan).back].plan
assert(#back.changes==0 and #back.motion_history==2 and back.tele_suppressed[1] and two.back_frame_count==6)
assert(RW_Undo(two).world==rearmed.world and RW_Undo(rearmed).world==one.world)
print("PASS: scheduled retained zero-net BACK journal selected again through native frame ledger, clocks and Undo")

for copies=2,3 do
 local rows={};for i=1,copies do rows[i]={"AVATAR","IS","BACK"} end
 s=fixture(rows);s.world.entities[1].back_init=2
 s,r=RW_Commit(s,cycle);assert(r.accepted,r.reason)
 s,r=RW_Commit(s,{consumes_turn=true,changes={},back_frame={from=2,retain=true}});assert(r.accepted,r.reason)
 one,plan=step(s);local back=plan.stages[stages(plan).back].plan
 assert(#back.changes==0 and #back.motion_history==2*copies,"physical BACK declarations must each enqueue playback")
 rows[#rows+1]={"AVATAR","IS","NOT","BACK"}
 s=fixture(rows);s.world.entities[1].back_init=2
 s,r=RW_Commit(s,cycle);assert(r.accepted,r.reason)
 s,r=RW_Commit(s,{consumes_turn=true,changes={},back_frame={from=2,retain=true}});assert(r.accepted,r.reason)
 one,plan=step(s);assert(not stages(plan).back and one.world.entities[1].back_init==0 and one.back_frame_count==3)
end

-- Declaration order comes before unit-list order within each declaration.
s=fixture({{"ROCK","IS","BACK"},{"AVATAR","IS","BACK"},{"ROCK","IS","BACK"}})
s.world.unit_order={3,2,1};for id=10,s.world.next_entity_id-1 do s.world.unit_order[#s.world.unit_order+1]=id end
local out,home={},{}
for id=1,3 do local u=s.world.entities[id];u.back_init=2
 out[#out+1]={kind="move",entity_id=id,from={x=u.x,y=u.y,direction=u.direction},to={x=u.x+1,y=u.y,direction=u.direction}}
 home[#home+1]={kind="move",entity_id=id,from={x=u.x+1,y=u.y,direction=u.direction},to={x=u.x,y=u.y,direction=u.direction}}
end
local history=assert(RW_PlanStages(s.world,{{name="out",plan={consumes_turn=true,changes=out}},{name="home",plan={consumes_turn=true,changes=home}}}))
history.back_frame={from=1,retain=true};s,r=RW_Commit(s,history);assert(r.accepted,r.reason)
s,r=RW_Commit(s,{consumes_turn=true,changes={},back_frame={from=2,retain=true}});assert(r.accepted,r.reason)
one,plan=step(s);local back=plan.stages[stages(plan).back].plan
local expected={3,3,2,2,1,1,3,3,2,2};assert(#back.motion_history==#expected)
for i,id in ipairs(expected) do assert(back.motion_history[i].entity_id==id,"BACK declaration/unit-list queue order mismatch") end
for _,invalid in ipairs({false,{1},{1,2,3,999},{[2]=1,[3]=2}}) do
 local p,e=RW_PlanBackHistoryMotion(s,{consumes_turn=true,changes={}},{[1]=true,[2]=true,[3]=true},nil,nil,invalid)
 assert(not p and e=="invalid_back_instances")
end
print("PASS: scheduled repeated BACK declarations, declaration-before-unit-list queue order, instance validation and Undo")

-- Native update/updatedir sets updatecode for effective Text writes, even when
-- the queued path returns to its starting geometry/facing before code() runs.
s=fixture({{"TEXT","ON","AVATAR","IS","BROKEN"}})
local id=s.world.next_entity_id;s.world.next_entity_id=id+1
s.world.entities[id]={id=id,kind="object",class="text",text={name="FLAG"},x=3,y=2,direction="Right",back_init=2}
s.world.rule_sources[#s.world.rule_sources+1]={when={op="always"},effects={
 {op="grant_trait",target={kind="class",value="text"},trait="back"},
 {op="deny_trait",target={kind="class",value="text"},trait="pushable"}}}
local function text_cycle(unit)
 local e=s.world.entities[unit]
 local plan=assert(RW_PlanStages(s.world,{
  {name="out",plan={consumes_turn=true,changes={{kind="move",entity_id=unit,from={x=e.x,y=e.y,direction="Right"},to={x=e.x+1,y=e.y,direction="Right"}}}}},
  {name="home",plan={consumes_turn=true,changes={{kind="move",entity_id=unit,from={x=e.x+1,y=e.y,direction="Right"},to={x=e.x,y=e.y,direction="Right"}}}}}}))
 plan.back_frame={from=1,retain=true};return plan
end
s,r=RW_Commit(s,text_cycle(id));assert(r.accepted,r.reason)
s,r=RW_Commit(s,{consumes_turn=true,changes={},back_frame={from=2,retain=true}});assert(r.accepted,r.reason)
one,plan=step(s,right);local order=stages(plan);local back=plan.stages[order.back].plan
assert(#back.changes==0 and #back.motion_history==2)
assert(not order.code_status_after_move and order.back<order.code_status_after_back and order.code_status_after_back<order.sink)
assert(one.world.entities[id].broken==1 and one.world.entities[id].x==3 and one.world.entities[1].x==3)
assert(RW_Undo(one).world==s.world and not s.world.entities[id].broken)
for _,reason in ipairs({"word_rule_limit","rule_complexity_limit"}) do
 local limited=copy(services)
 limited.evaluate=function(w) if w.entities[id].broken==1 then return nil,reason end;return services.evaluate(w) end
 local terminal,p=step(s,right,limited);local terminal_order=stages(p)
 assert(terminal.world[reason=="rule_complexity_limit" and "too_complex" or "infinite_loop"] and terminal.world.entities[id].broken==1 and not terminal_order.sink)
 assert(terminal_order.back<terminal_order.code_status_after_back and RW_Undo(terminal).world==s.world)
end
local failing=copy(services)
failing.preview=function(w,p)
 if p.reason=="broken_status" then for _,op in ipairs(p.changes) do if op.entity_id==id and op.to==1 then return nil,"injected_reading_barrier_failure" end end end
 return RW_PreviewPlan(w,p)
end
local rejected,e=RW_PlanTurn(s.world,right,failing,s)
assert(not rejected and e.stage=="code_status_after_back" and e.reason=="injected_reading_barrier_failure")
assert(s.world.entities[1].x==2 and not s.world.entities[id].broken and s.back_frame_count==3 and #s.history==2)
assert(not s.world.chance_seed and not s.world.last_input)

local turning=RW_Undo(RW_Undo(s))
local direction_cycle=assert(RW_PlanStages(turning.world,{
 {name="turn",plan={consumes_turn=true,changes={{kind="direction",entity_id=id,from="Right",to="Up"}}}},
 {name="home",plan={consumes_turn=true,changes={{kind="direction",entity_id=id,from="Up",to="Right"}}}}}))
direction_cycle.back_frame={from=1,retain=true};turning,r=RW_Commit(turning,direction_cycle);assert(r.accepted,r.reason)
turning,r=RW_Commit(turning,{consumes_turn=true,changes={},back_frame={from=2,retain=true}});assert(r.accepted,r.reason)
local turned,p=step(turning,right);local turn_order=stages(p)
assert(#p.stages[turn_order.back].plan.changes==0 and turned.world.entities[id].broken==1 and turned.world.entities[id].direction=="Right")
assert(turn_order.back<turn_order.code_status_after_back and RW_Undo(turned).world==turning.world)

-- A matched historical update whose dispatch is already a no-op suppresses
-- TELE, but must not invent updatecode/BROKEN refresh at this barrier.
local noop=RW_Undo(RW_Undo(s))
noop,r=RW_Commit(noop,{consumes_turn=true,changes={{kind="move",entity_id=id,from={x=3,y=2,direction="Right"},to={x=4,y=2,direction="Right"}}},back_frame={from=1,retain=true}});assert(r.accepted,r.reason)
noop,r=RW_Commit(noop,{consumes_turn=true,changes={{kind="move",entity_id=id,from={x=4,y=2,direction="Right"},to={x=3,y=2,direction="Right"}}},back_frame={from=2,retain=true}});assert(r.accepted,r.reason)
local unchanged,p=step(noop,right);local no_order=stages(p);local back=p.stages[no_order.back].plan
assert(#back.changes==0 and not back.motion_history and back.tele_suppressed[id])
assert(not no_order.code_status_after_back and not unchanged.world.entities[id].broken)
print("PASS: zero-net BACK Text dispatch triggers one code-status barrier before frozen contacts and Undo")

-- SHIFT's blocked facing update invalidates Text reading even if final belt
-- alignment restores the initial facing, leaving no final Text change.
local shifted=RW_Undo(RW_Undo(s))
shifted.world.entities[id].back_init=nil
for _,belt_id in ipairs({2,3}) do
 local belt=shifted.world.entities[belt_id];belt.x=3;belt.y=2;belt.direction=belt_id==2 and "Left" or "Right"
end
local wall=shifted.world.next_entity_id;shifted.world.next_entity_id=wall+1
shifted.world.entities[wall]={id=wall,kind="object",class="object",archetype="rock",x=2,y=2,direction="Right"}
shifted.world.rule_sources[#shifted.world.rule_sources+1]={when={op="always"},effects={
 {op="deny_trait",target={kind="class",value="text"},trait="back"},
 {op="grant_trait",target={kind="id",value=2},trait="shift"},
 {op="grant_trait",target={kind="id",value=3},trait="shift"},
 {op="grant_trait",target={kind="id",value=2},trait="still"},
 {op="grant_trait",target={kind="id",value=2},trait="sleep"},
 {op="grant_trait",target={kind="id",value=3},trait="still"},
 {op="grant_trait",target={kind="id",value=wall},trait="block_entry"}}}
local shift_services=copy(services);shift_services.shift=RW_ResolveShift
local after,p=step(shifted,right,shift_services);local indices=stages(p)
local shift=p.stages[indices.shift].plan
for _,change in ipairs(shift.changes) do assert(change.entity_id~=id) end
assert(after.world.entities[id].x==3 and after.world.entities[id].direction=="Right" and after.world.entities[id].broken==1)
assert(indices.shift<indices.code_status_after_move and indices.code_status_after_move<indices.sink)
assert(RW_Undo(after).world==shifted.world and not shifted.world.entities[id].broken)
for _,reason in ipairs({"word_rule_limit","rule_complexity_limit"}) do
 local limited=copy(shift_services)
 limited.evaluate=function(w) if w.entities[id].broken==1 then return nil,reason end;return services.evaluate(w) end
 local terminal,p=step(shifted,right,limited)
 assert(terminal.world[reason=="word_rule_limit" and "infinite_loop" or "too_complex"] and terminal.world.entities[id].broken==1)
 assert(not stages(p).sink and RW_Undo(terminal).world==shifted.world)
end
local failing=copy(shift_services)
failing.preview=function(w,p)
 if p.reason=="broken_status" then for _,op in ipairs(p.changes) do if op.entity_id==id and op.to==1 then return nil,"injected_shift_status_failure" end end end
 return RW_PreviewPlan(w,p)
end
local rejected,e=RW_PlanTurn(shifted.world,right,failing,shifted)
assert(not rejected and e.stage=="code_status_after_move" and e.reason=="injected_shift_status_failure")
assert(not shifted.world.entities[id].broken and shifted.world.entities[1].x==2 and not shifted.world.chance_seed)
local malformed=copy(shift_services)
malformed.shift=function() return {consumes_turn=true,changes={},motion_history={{}}} end
local rejected,e=RW_PlanTurn(shifted.world,right,malformed,shifted)
assert(not rejected and e.stage=="preview_shift")
local alignment=copy(shifted)
alignment.world.rule_sources[#alignment.world.rule_sources+1]={when={op="always"},effects={
 {op="grant_trait",target={kind="id",value=id},trait="still"}}}
local unchanged,p=step(alignment,right,shift_services)
assert(not stages(p).code_status_after_move and not unchanged.world.entities[id].broken)
for _,row in ipairs(p.stages[stages(p).shift].plan.motion_history or {}) do
 if row.entity_id==id then assert(row.retain==false and row.from.direction==row.to.direction) end
end
print("PASS: zero-net blocked SHIFT Text facing refreshes code status before conversion and Undo")
