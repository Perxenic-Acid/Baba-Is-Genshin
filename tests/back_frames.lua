local source=assert(io.open("C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/undo.lua","rb")):read("*a")
local body=assert(source:match("^(.-)function addundo"))
local env=setmetatable({undobuffer={{}},updateundo=false,doundo=true,last_key=4,Fixedseed=100,
 generaldata2={values={}},UNDOTOOLTIPTIMER="timer",wordunits={},wordrelatedunits={},visiontargets={}},{__index=_G})
assert(load(body,"@installed_newundo","t",env))()
local function fixture() local s=RW_CreateSession();s.world.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Right"}};return s end
local s=fixture();local checks=0
for turn=1,180 do
 local retain=turn%3~=0
 local p={consumes_turn=true,changes={},reason="frame:"..turn,back_frame={from=s.back_frame_count or 1,retain=retain}}
 if turn%3==1 then local e=s.world.entities[1];p.changes={{kind="move",entity_id=1,from={x=e.x,y=e.y,direction=e.direction},to={x=e.x==2 and 3 or 2,y=2,direction="Right"}}} end
 local old=s;local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);s=n
 env.undobuffer[1].tag=p.reason;env.updateundo=retain;env.newundo();env.undobuffer[1].tag="current"
 assert(s.back_frame_count==#env.undobuffer)
 local prefix={consumes_turn=true,changes={},reason="current"}
 for _,index in ipairs({-1,0,1,2,3,#env.undobuffer,#env.undobuffer+1}) do
  local record,before=RW_GetBackFrame(s,index,prefix)
  local native=env.undobuffer[index]
  if not native then assert(not record and before=="back_frame_absent")
  elseif index==1 then assert(record.reason==native.tag and before.entities[1].x==s.world.entities[1].x)
  else
   assert(record and record.reason==native.tag,"native frame tag mismatch");assert(before.entities[1])
  end
  checks=checks+1
 end
 -- Ordinary Undo restores the immediately preceding command's native clock,
 -- including commands pruned only from BACK's operation history.
 local restored,ur=RW_Undo(s);assert(ur.accepted and restored.world==old.world and restored.back_frame_count==old.back_frame_count)
end
assert(checks==1260 and #s.history==180 and s.back_frame_count==121)
local record,before=RW_GetBackFrame(s,2);assert(record and before)
record.reason="mutated";before.entities[1].x=99
assert(RW_GetBackFrame(s,2).reason~="mutated")
local _,again=RW_GetBackFrame(s,2);assert(again.entities[1].x~=99)
local missing,why=RW_GetBackFrame(s,1);assert(not missing and why=="back_current_frame_unavailable")
local original=s
-- Select the first retained frame after 180 commands. Its snapshot was lost
-- under the old cap; playback must now undo its actual update, not silently skip.
original.world.entities[1].back_init=61
local long_prefix={consumes_turn=true,changes={{kind="move",entity_id=1,
 from={x=original.world.entities[1].x,y=2,direction="Right"},to={x=4,y=2,direction="Right"}}}}
local replay=assert(RW_PlanBackHistoryMotion(original,long_prefix,{[1]=true}))
local combined=assert(RW_PlanStages(original.world,{{name="move",plan=long_prefix},{name="back",plan=replay}}))
combined.back_frame={from=121,retain=true}
local replayed,res=RW_Commit(original,combined);assert(res.accepted,res.reason)
assert(replayed.world.entities[1].x==2 and replay.tele_suppressed[1] and RW_Undo(replayed).world==original.world)
for i=1,180 do local n,r=RW_Undo(s);assert(r.accepted,r.reason);s=n end
assert(#s.history==0 and s.back_frame_count==nil)
assert(not RW_GetBackFrame(s,2))
local next_session,r=RW_Commit(s,{consumes_turn=true,changes={},back_frame={from=1,retain=true}});assert(r.accepted,r.reason)
assert(RW_Undo(next_session).back_frame_count==s.back_frame_count)
-- Empty retained frames still occupy a native slot; pruned frames never do.
local a=fixture();local b,r=RW_Commit(a,{consumes_turn=true,changes={},back_frame={from=1,retain=false}});assert(r.accepted and b.back_frame_count==1)
local c,r=RW_Commit(b,{consumes_turn=true,changes={},reason="empty retained",back_frame={from=1,retain=true}});assert(r.accepted and c.back_frame_count==2)
assert(RW_GetBackFrame(c,2).reason=="empty retained")
assert(RW_Undo(b).back_frame_count==nil)
-- Stale/missing metadata and late phase failures cannot advance the clock.
for _,p in ipairs({{consumes_turn=true,changes={}}, {consumes_turn=true,changes={},back_frame={from=99,retain=true}}, {consumes_turn=true,changes={},back_frame={from=2,retain=1}}}) do
 local same,r=RW_Commit(c,p);assert(same==c and not r.accepted)
end
local late={consumes_turn=true,changes={{kind="direction",entity_id=1,from="Up",to="Left"}},back_frame={from=2,retain=true}}
local same,r=RW_Commit(c,late);assert(same==c and not r.accepted and c.back_frame_count==2)
local legacy=fixture();legacy=RW_Commit(legacy,{consumes_turn=true,changes={}})
local same,r=RW_Commit(legacy,{consumes_turn=true,changes={},back_frame={from=1,retain=true}});assert(same==legacy and not r.accepted)
local bad=fixture();bad.back_frame_count=0;local same,r=RW_Commit(bad,{consumes_turn=true,changes={}});assert(same==bad and not r.accepted)
print("PASS: installed newundo frame mapping/pruning oracle (1260 queries), open/retained frames beyond 128 commands, ownership, rejection and complete Undo")

-- Current open-frame playback and past-frame playback share the same mapping.
local selected=fixture();selected.world.entities[1].back_init=1
selected=RW_Commit(selected,{consumes_turn=true,changes={{kind="move",entity_id=1,from={x=2,y=2},to={x=3,y=2}}},back_frame={from=1,retain=true}})
selected=RW_Commit(selected,{consumes_turn=true,changes={},back_frame={from=2,retain=true}})
local prefix={consumes_turn=true,changes={{kind="move",entity_id=1,from={x=3,y=2},to={x=4,y=2}}}}
-- count=3, init=2 -> index=3, the first retained frame.
selected.world.entities[1].back_init=2
local playback,e=RW_PlanBackHistoryMotion(selected,prefix,{[1]=true});assert(playback,e)
assert(playback.back_retain and playback.tele_suppressed[1] and playback.changes[1].to.x==2)
local combined=assert(RW_PlanStages(selected.world,{{name="prefix",plan=prefix},{name="back",plan=playback}}));combined.back_frame={from=3,retain=true}
local played,r=RW_Commit(selected,combined);assert(r.accepted and played.world.entities[1].x==2)
assert(RW_Undo(played).world==selected.world)
-- init=count selects index 1 and reverses this turn's current prefix.
selected.world.entities[1].back_init=3
local current=assert(RW_PlanBackHistoryMotion(selected,prefix,{[1]=true}));assert(current.changes[1].to.x==3)
selected.world.entities[1].back_init=4
local absent=assert(RW_PlanBackHistoryMotion(selected,prefix,{[1]=true}));assert(absent.back_retain and #absent.changes==0 and next(absent.tele_suppressed)==nil)
selected.world.entities[1].back_init=0
local inactive=assert(RW_PlanBackHistoryMotion(selected,prefix,{[1]=true}));assert(not inactive.back_retain and #inactive.changes==0)
selected.world.entities[1].back_init=2
local blocked=assert(RW_PlanBackHistoryMotion(selected,prefix,{[1]=true},{[1]=false}));assert(blocked.back_retain and #blocked.changes==0)
local legacy=fixture();assert(not RW_PlanBackHistoryMotion(legacy,{consumes_turn=true,changes={}},{[1]=true}))
print("PASS: per-identity BACK history selection, staged current/past playback, absent-frame retention, paradox suppression and whole-turn Undo")

local root=fixture().world;root.entities[1].level_link={target="child",definition_id="child",source_type="avatar"}
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",root)),child=assert(RW_CreateLevelDefinition("child",fixture().world))},"root"))
local parent_id=tree.active_id;tree=assert(RW_EnterLevel(tree,"1","child"));tree=assert(RW_BindLevelEntry(tree,1))
local child_id=tree.active_id;local session=RW_GetActiveLevel(tree)
local moved,r=RW_Commit(session,{consumes_turn=true,changes={},back_frame={from=1,retain=true}});assert(r.accepted)
local updated=assert(RW_UpdateActiveLevel(tree,moved));local completed,r=RW_CommitLevelTree(tree,{before=tree,after=updated});assert(r.accepted)
assert(RW_GetActiveLevel(completed).back_frame_count==2 and completed.instances[parent_id].back_frame_count==nil)
assert(RW_UndoLevelTree(completed).instances[child_id]==session)
local reload=assert(RW_ReloadLevel(completed,child_id));assert(RW_GetActiveLevel(reload).back_frame_count==nil)
local boundary,r=RW_CommitLevelTree(completed,{before=completed,after=reload});assert(r.accepted)
assert(RW_UndoLevelTree(boundary).instances[child_id]==moved)
-- Corrupted counters are rejected at the tree gate, not just local commits.
local corrupt={};for k,v in pairs(moved) do corrupt[k]=v end;corrupt.back_frame_count=3
local candidate=assert(RW_UpdateActiveLevel(completed,corrupt));local same,r=RW_CommitLevelTree(completed,{before=completed,after=candidate});assert(same==completed and not r.accepted)
print("PASS: BACK clock tree/sibling isolation, boundary reset/restoration and corrupted-ledger rejection")

-- Whole-tree history must retain the same long lifetime, including a boundary
-- that resets the active session's local journal and allocators.
local initial=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",fixture().world))},"root"))
local long_tree=initial
for i=1,165 do
 local active=RW_GetActiveLevel(long_tree);local e=active.world.entities[1]
 local next_session,result=RW_Commit(active,{consumes_turn=true,changes={{kind="direction",entity_id=1,
  from=e.direction,to=e.direction=="Right" and "Left" or "Right"}}});assert(result.accepted)
 local candidate=assert(RW_UpdateActiveLevel(long_tree,next_session))
 long_tree,result=RW_CommitLevelTree(long_tree,{before=long_tree,after=candidate});assert(result.accepted)
end
assert(#long_tree.history==165 and #RW_GetActiveLevel(long_tree).history==165)
local candidate=assert(RW_ReloadLevel(long_tree,long_tree.active_id))
local reloaded,result=RW_CommitLevelTree(long_tree,{before=long_tree,after=candidate});assert(result.accepted)
assert(#RW_GetActiveLevel(reloaded).history==0 and #reloaded.history==166)
local restored=RW_UndoLevelTree(reloaded)
assert(RW_GetActiveLevel(restored)==RW_GetActiveLevel(long_tree))
for i=1,165 do restored,result=RW_UndoLevelTree(restored);assert(result.accepted) end
assert(#restored.history==0 and RW_GetActiveLevel(restored)==RW_GetActiveLevel(initial))
print("PASS: BACK replay beyond 128 commands and complete long local/tree/boundary Undo")
