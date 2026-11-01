-- Each mapped script owns a separate global environment. Do not inherit _G's
-- RW_* exports: all cross-script BACK access must pass through Invoke adapters.
local function isolated(name)
 local env={}
 for _,key in ipairs({"assert","error","ipairs","pairs","next","pcall","select","tonumber","tostring","type","getmetatable","setmetatable","math","string","table","unpack"}) do env[key]=_G[key] end
 env._G=env
 assert(loadfile("external_lua_file/"..name..".lua","t",env))()
 return {env=env,Invoke=function(self,method,...) return assert(self.env[method],method)(...) end}
end
local world,movement,properties=isolated("world"),isolated("movement"),isolated("properties")
assert(not movement.env.RW_PreviewPlan and not movement.env.RW_GetBackFrame and not movement.env.RW_GetBackIdentity)
local calls={}
local api={}
for key,method in pairs({preview="RW_PreviewPlan",frame="RW_GetBackFrame",rows="RW_BackHistoryRows",restore="RW_BackRestoredEntity",identity="RW_GetBackIdentity"}) do
 api[key]=function(...) calls[key]=(calls[key] or 0)+1;return world:Invoke(method,...) end
end
local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function equal(a,b)
 if type(a)~=type(b) then return false end;if type(a)~="table" then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function fixture()
 local s=world:Invoke("RW_CreateSession");local w=s.world;w.width=12;w.height=10;w.next_entity_id=10;w.entities={}
 for id=1,3 do w.entities[id]={id=id,kind="object",class="object",archetype=id==1 and "avatar" or "rock",x=id==3 and 8 or 2,y=2,direction="Right"} end
 return s
end
local function commit(s,p)
 local n,r=world:Invoke("RW_Commit",s,p);assert(r.accepted,r.reason);return n
end
local function motion(s,x)
 local e=s.world.entities[1]
 return {consumes_turn=true,changes={{kind="move",entity_id=1,from={x=e.x,y=e.y,direction=e.direction},to={x=x,y=e.y,direction="Up"}}}}
end

local s=fixture()
local status=assert(movement:Invoke("RW_PlanBackStatus",s.world,{[1]=true},1))
status.back_frame={from=1,retain=true};s=commit(s,status)
local prefix=motion(s,3)
local back=assert(movement:Invoke("RW_PlanBackHistoryMotion",s,prefix,{[1]=true},nil,api))
assert(back.back_retain and back.tele_suppressed[1] and back.changes[1].to.x==2)
assert(equal(back,assert(RW_PlanBackHistoryMotion(s,prefix,{[1]=true}))))
local at=assert(world:Invoke("RW_PreviewPlan",s.world,prefix))
local after=assert(world:Invoke("RW_PreviewPlan",at,back))
local projected=assert(properties:Invoke("RW_ProjectWorld",after,{{op="grant_trait",trait="tele",entity_ids={2,3}}}))
local tele=assert(movement:Invoke("RW_ResolveTele",projected,back.tele_suppressed))
assert(#tele.changes==0 and not tele.random_state)
local phases={{name="movement",plan=prefix},{name="back",plan=back},{name="tele",plan=tele}}
local changes={};for _,phase in ipairs(phases) do for _,op in ipairs(phase.plan.changes) do changes[#changes+1]=op end end
local turn={consumes_turn=true,changes=changes,stages=phases,back_frame={from=2,retain=back.back_retain}}
local next=commit(s,turn)
assert(next.back_frame_count==3 and next.world.entities[1].x==2)
assert(world:Invoke("RW_Undo",next).world==s.world)
-- A historical frame (not the current prefix) also crosses the module boundary.
local history=assert(movement:Invoke("RW_PlanBackHistoryMotion",next,{consumes_turn=true,changes={}},{[1]=true},nil,api))
assert(history.back_retain and #history.changes==0)

-- Primary, duplicate-branch and repeated-conversion playback use world-owned
-- row reconstruction, logical identities, product construction and validation.
for mode=1,3 do
 local old=fixture();old.world.unit_order={3,2,1}
 local ops={{kind="transform",entity_id=1,from="avatar",to="crate"}}
 local plan={consumes_turn=true,changes=ops}
 if mode==2 then
  local product=copy(old.world.entities[1]);product.id=10;product.archetype="flag"
  ops[#ops+1]={kind="create",entity_id=10,to=product};plan.id_allocation={from=10,to=11}
  plan.back_conversions={{source=copy(old.world.entities[1]),product_ids={1,10},removed=true}}
 elseif mode==3 then
  plan={consumes_turn=true,changes={ops[1],{kind="transform",entity_id=1,from="crate",to="flag"}},stages={
   {name="first",plan={consumes_turn=true,changes=ops}},
   {name="second",plan={consumes_turn=true,changes={{kind="transform",entity_id=1,from="crate",to="flag"}}}}}}
 end
 local past=commit(old,plan);local record=world:Invoke("RW_GetTurnRecord",past,1)
 local selections={{entity_id=1,before_world=old.world,record=record}}
 if mode==2 then selections[#selections+1]={entity_id=10,before_world=old.world,record=record} end
 local p=assert(movement:Invoke("RW_PlanBackFramePlayback",past.world,selections,nil,api))
 assert(equal(p,assert(RW_PlanBackFramePlayback(past.world,selections))))
 local restored=commit(past,p)
 assert(restored.world.entities[1].archetype==(mode==3 and "crate" or "avatar") and world:Invoke("RW_Undo",restored).world==past.world)
 if mode==3 then
  assert(restored.world.next_entity_id==13)
  local counts={};for _,e in pairs(restored.world.entities) do counts[e.archetype]=(counts[e.archetype] or 0)+1 end
  assert(counts.avatar==2 and counts.crate==2)
 end
 if mode==1 then
  local legacy={{entity_id=1,before=old.world.entities[1],record=record}}
  assert(equal(assert(movement:Invoke("RW_PlanBackPlayback",past.world,legacy,nil,api)),assert(RW_PlanBackPlayback(past.world,legacy))))
 end
end
for _,key in ipairs({"preview","frame","rows","restore","identity"}) do
 assert((calls[key] or 0)>0,"unused mapped service "..key)
 local missing={};for k,v in pairs(api) do if k~=key then missing[k]=v end end
 local p,why=movement:Invoke("RW_PlanBackHistoryMotion",s,prefix,{[1]=true},nil,missing)
 assert(not p and why=="missing_back_service_"..key)
end
local p,why=movement:Invoke("RW_PlanBackHistoryMotion",s,prefix,{[1]=true})
assert(not p and why=="missing_back_service_preview")
p,why=movement:Invoke("RW_PlanBackHistoryMotion",s,prefix,{[1]=true},nil,false)
assert(not p and why=="invalid_back_services")
local failed=copy(api);failed.rows=function() return nil,"isolated_row_failure" end
p,why=movement:Invoke("RW_PlanBackHistoryMotion",s,prefix,{[1]=true},nil,failed)
assert(not p and why=="isolated_row_failure" and s.world.entities[1].x==2 and s.back_frame_count==2)
print("PASS: isolated mapped BACK clock/history/current-frame/branch/repeated/legacy playback, explicit world services, TELE handoff, failure propagation and Undo")

-- Run the complete session-aware planner with the same script isolation and
-- Invoke boundaries, rather than only composing individual solver calls.
local bootstrap,reader,grammar,rules=isolated("bootstrap"),isolated("reader"),isolated("grammar"),isolated("rules")
local compile={read=function(...) return reader:Invoke("RW_ReadLines",...) end,
 parse=function(...) return grammar:Invoke("RW_ParseRuleAST",...) end,
 lower=function(...) return rules:Invoke("RW_LowerRuleAST",...) end,
 evaluate=function(...) return rules:Invoke("RW_EvaluateRules",...) end,
 project=function(...) return properties:Invoke("RW_ProjectWorld",...) end,
 words=function(...) return rules:Invoke("RW_WordTokenMap",...) end,
 code_status=function(...) return rules:Invoke("RW_PlanCodeStatus",...) end}
local scheduled={project=compile.project,preview=api.preview,
 status=function(...) return rules:Invoke("RW_PlanRuleStatus",...) end,
 resolve=function(...) return movement:Invoke("RW_ResolveTurn",...) end,
 convert=function(...) return rules:Invoke("RW_PlanConversions",...) end,
 tele=function(...) return movement:Invoke("RW_ResolveTele",...) end,
 back_status=function(...) return movement:Invoke("RW_PlanBackStatus",...) end,
 back_history=function(s,p,e,guard) return movement:Invoke("RW_PlanBackHistoryMotion",s,p,e,guard,api) end,
 back_retain=function(...) return world:Invoke("RW_BackRetainDecision",...) end,
 evaluate=function(w)
  local f,e=bootstrap:Invoke("RW_CompileWorld",w,compile);if not f then return nil,e.reason end
  return f.effects,nil,f.relations,f.rules,f.code_status
 end}
s=fixture();s.world.entities[1].back_init=1
s.world.rule_sources[#s.world.rule_sources+1]={when={op="always"},effects={
 {op="grant_trait",target={kind="archetype",value="avatar"},trait="you"},
 {op="grant_trait",target={kind="archetype",value="avatar"},trait="back"},
 {op="grant_trait",target={kind="archetype",value="rock"},trait="tele"}}}
local plan,e=bootstrap:Invoke("RW_PlanTurn",s.world,{type="move",dx=1,dy=0},scheduled,s);assert(plan,e and e.reason)
local n=commit(s,plan)
assert(n.world.entities[1].x==2 and not n.world.random_state and n.back_frame_count==2)
plan,e=bootstrap:Invoke("RW_PlanTurn",n.world,{type="wait"},scheduled,n);assert(plan,e and e.reason)
local transported=commit(n,plan)
assert(transported.world.entities[1].x==8 and transported.world.random_state and transported.back_frame_count==3)
assert(world:Invoke("RW_Undo",transported).world==n.world and world:Invoke("RW_Undo",n).world==s.world)
print("PASS: fully isolated compiler/status/session scheduler, current-frame BACK, transient TELE routing, retained-frame clock, RNG and atomic Undo")
