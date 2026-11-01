local function read(path) local f=assert(io.open(path,"rb"));local s=f:read("*a"):gsub("\r\n","\n");f:close();return s end
local root="C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/"
-- Execute the installed selector/findall functions unchanged. Native handles
-- differ from logical IDs; synthetic LEVEL/EMPTY must never reach newObject.
local features=read(root.."features.lua");local tools=read(root.."tools.lua")
local env=setmetatable({},{__index=_G})
assert(load(assert(features:match("^(.-)function findfeatureat")),"@installed_findfeature_BACK","t",env))()
assert(load(assert(features:match("(function findallfeature%(.-)\nfunction getunitswitheffect")),"@installed_findallfeature_BACK","t",env))()
assert(load(assert(tools:match("(function findall%(.-)\nfunction delunit")),"@installed_findall_BACK","t",env))()
local cases=0
for _,name in ipairs({"avatar","level","text","empty"}) do for passing=0,1 do for broken=0,1 do for copies=1,2 do
 env.featureindex={back={}};env.unitlists={avatar={101},level={102}};env.codeunits={103}
 for i=1,copies do env.featureindex.back[i]={{name,"is","back"},{{passing==1 and "pass" or "fail"}}} end
 local units={[101]={name="avatar",broken=broken},[102]={name="level",broken=broken},[103]={name="text",broken=broken}}
 env.mmf={newObject=function(handle) assert(handle~=1 and handle~=2,"synthetic observer entered BACK");return assert(units[handle]) end}
 env.getname=function(unit) return unit.name end
 env.testcond=function(conds,handle) return conds[1][1]=="pass" and units[handle].broken==0 end
 local ids,empty=env.findallfeature(nil,"is","back",true)
 local count=name~="empty" and passing==1 and broken==0 and copies or 0
 assert(#ids==count and #empty==count)
 for i,id in ipairs(ids) do assert(id==({avatar=101,level=102,text=103})[name] and #empty[i]==0) end
 cases=cases+1
end end end end
assert(cases==32)
print("PASS: installed BACK findfeature/findallfeature/findall oracle (32 cases), real LEVEL/Text, ignored EMPTY, conditions/BROKEN and duplicate declarations")

local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 status=RW_PlanRuleStatus,back_status=RW_PlanBackStatus,back_history=RW_PlanBackHistoryMotion,back_retain=RW_BackRetainDecision,
 contact=function(w,p,k,c,r,count) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
  births=function(w,ids,c,r,count) local specs,e=RW_PlanHasBirths(w,ids,c);if not specs then return nil,e end;return RW_InitializeBirthSpecifications(w,specs,r,count) end,
  create=RW_PlanCreate,delete=RW_PlanDelete},r,count) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width=16;w.height=18;w.next_entity_id=10
 assert(w.language.properties.BACK=="back" and RW_GetBehaviorRegistry().back.back)
 w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag"
 w.language.nouns.LEVEL={tag="level",block_type="level_block"}
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Right"}}
 w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
 for row,words in ipairs(rows or {}) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="Right"}
 end end
 return s
end
local right={type="move",dx=1,dy=0};local wait={type="wait"}
local function step(s,action)
 local p,e=RW_PlanTurn(s.world,action or wait,services,s);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n,p
end
local s=fixture({{"AVATAR","IS","BACK"}})
local frame=assert(RW_CompileWorld(s.world,cs));local projected=assert(RW_ProjectWorld(s.world,frame.effects))
assert(projected.entities[1].behaviors.back and projected.entities[1].traits.back)
for id,e in pairs(s.world.entities) do if e.class=="text" then assert(frame.active_text_ids[id]) end end
for _,deferred in ipairs(projected.deferred_effects or {}) do assert(deferred.effect.trait~="back") end
local one=step(s,right);local two=step(one,right)
assert(one.world.entities[1].x==3 and two.world.entities[1].x==3 and two.world.entities[1].back_init==2)
s=fixture({{"AVATAR","IS","BACK"},{"AVATAR","FEELING","BACK","IS","FLOAT"}})
frame=assert(RW_CompileWorld(s.world,cs));projected=assert(RW_ProjectWorld(s.world,frame.effects));assert(projected.entities[1].behaviors.back and projected.entities[1].behaviors.float)
s=fixture({{"AVATAR","IS","BACK"},{"AVATAR","IS","NOT","BACK"}})
one=step(s,right);assert(one.world.entities[1].x==3 and not one.world.entities[1].back_init)
s=fixture({{"AVATAR","IS","BACK"},{"AVATAR","IS","BROKEN"}})
one=step(s,right);assert(one.world.entities[1].x==2 and one.world.entities[1].broken==1 and not one.world.entities[1].back_init)
s=fixture({{"ROCK","IS","WORD"}})
s.world.entities[2]={id=2,kind="object",class="object",archetype="rock",x=1,y=10,direction="Down"}
for x,word in ipairs({"IS","BACK"}) do local id=s.world.next_entity_id;s.world.next_entity_id=id+1
 s.world.entities[id]={id=id,kind="object",class="text",text={name=word},x=x+1,y=10,direction="Right"}
end
frame=assert(RW_CompileWorld(s.world,cs));projected=assert(RW_ProjectWorld(s.world,frame.effects))
assert(projected.entities[2].behaviors.back and projected.entities[2].behaviors.word)
one=step(s,right);assert(one.world.entities[2].back_init==2 and one.world.entities[2].direction=="Down")

-- Actual level blocks receive BACK and preserve identity-bound destinations;
-- the scoped declaration and virtual EMPTY do not invent synthetic clocks.
s=fixture({{"LEVEL","IS","BACK"},{"LEVEL","IS","PUSH"}})
s.world.entities[2]={id=2,kind="object",class="object",archetype="level_block",x=3,y=2,direction="Down",level_link={target="child",definition_id="child",source_type="level_block"}}
one=step(s,right);two=step(one,right)
assert(one.world.entities[2].x==4 and two.world.entities[2].x==4 and two.world.entities[2].back_init==2)
assert(two.world.entities[2].level_link.definition_id=="child" and not two.world.back_init and not two.world.board_offset)
for _,rows in ipairs({{{"LEVEL","IS","BACK"}},{{"EMPTY","IS","BACK"}}}) do
 s=fixture(rows);local next,p=step(s)
 assert(not next.world.back_init and not next.world.entities[1].back_init and next.world.next_entity_id==s.world.next_entity_id)
 for id in pairs(next.world.entities) do assert(id>0) end
end

-- Production tree actions pass the session, so public BACK is not confined to
-- the explicit planner helper. Whole-tree Undo and reload own its clock/history.
for k,v in pairs({active=RW_GetActiveLevel,update=RW_UpdateActiveLevel,enter=RW_EnterLevel,return_level=RW_ReturnLevel,
 selectors=RW_LevelSelectorIDs,place_selectors=RW_PlaceLevelSelectors,bind_entry=RW_BindLevelEntry,commit_session=RW_Commit,
 outcome=RW_RecordLevelOutcome,candidates=RW_LevelSelectionCandidates,win=RW_HasWinContact,level_outcome=RW_ResolveLevelPropertyOutcome}) do services[k]=v end
s=fixture({{"AVATAR","IS","BACK"}})
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",s.world))},"root"))
local function tree_step(t)
 local p,e=RW_PlanLevelAction(t,right,services);assert(p,e and e.reason)
 local n,r=RW_CommitLevelTree(t,p);assert(r.accepted,r.reason);return n
end
local first=tree_step(tree);local second=tree_step(first)
assert(RW_GetActiveLevel(second).world.entities[1].x==3 and RW_GetActiveLevel(second).back_frame_count==3)
assert(RW_UndoLevelTree(second).instances[first.active_id]==RW_GetActiveLevel(first))
local reset=assert(RW_ReloadLevel(second,second.active_id));assert(not RW_GetActiveLevel(reset).back_frame_count and not RW_GetActiveLevel(reset).world.entities[1].back_init)
print("PASS: public BACK capability/compiler/activation/FEELING/NOT/BROKEN/WORD, linked level-block replay, inert scoped LEVEL/EMPTY, production tree actions, reload and Undo")
