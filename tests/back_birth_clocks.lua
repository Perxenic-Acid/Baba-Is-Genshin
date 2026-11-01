local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,
 project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local lifecycle={victims=RW_ResolveContactVictims,create=RW_PlanCreate,delete=RW_PlanDelete,birth_products=RW_PlanHasBirths,
 births=function(w,ids,c,rules,count)
  local specs,e=RW_PlanHasBirths(w,ids,c);if not specs then return nil,e end
  return RW_InitializeBirthSpecifications(w,specs,rules,count)
 end}
local services={status_required=RW_StatusInitializationNeeded,status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,
 preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,back_status=RW_PlanBackStatus,
 back_history=RW_PlanBackHistoryMotion,back_retain=RW_BackRetainDecision,
 more=function(w,p,r,c) return RW_PlanInitializedCreation(w,RW_ResolveMoreProducts(p),r,{initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate},c) end,
 make=function(w,relations,converted,r,c)
  local specs,rng=RW_PlanMakeProducts(w,relations,converted);if not specs then return nil,rng end
  local p,e=RW_PlanInitializedCreation(w,specs,r,{initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate},c)
  if p then p.random_state=rng end;return p,e
 end,
 destroy=function(w,ids,c,k,d,r,count) return RW_PlanDestructionPhase(w,ids,c,k,lifecycle,d,r,count) end,
 contact=function(w,p,k,c,r,count) return RW_PlanContactPhase(w,p,k,c,lifecycle,r,count) end,
 eat=function(w,p,relations,c,r,count)
  return RW_PlanDestructionPhase(w,RW_ResolveEatVictims(p,RW_ResolveVerbTargets(w,relations,"eat")),c,"eat",lifecycle,nil,r,count)
 end,
 bonus=function(w,p,c,r,count)
  local adapted=copy(lifecycle);adapted.contacts=RW_ResolveBonusContacts
  return RW_PlanBonusPhase(w,p,c,r,adapted,count)
 end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
  return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width=24;w.height=28;w.next_entity_id=10
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=3,y=3,direction="Right"}}
 w.language.properties.BACK="back";w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag";w.language.nouns.WALL="wall"
 w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}
 for row,words in ipairs(rows or {}) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=6+row*2,direction="Right"}
 end end
 s.back_frame_count=5 -- A capped empty native ledger retains its absolute clock.
 return s
end
local function step(s,action)
 local p,e=RW_PlanTurn(s.world,action or {type="wait"},services,s);assert(p,e and e.stage..":"..e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world and RW_Undo(n).back_frame_count==5)
 return n,p
end
local function objects(w,name) local r={};for _,e in pairs(w.entities) do if e.archetype==name then r[#r+1]=e end end;return r end

-- Execute installed addunit's reset lines, brokenblock, hasfeature and BACK
-- status clause; only testcond's spatial host query is normalized to a Boolean.
local root=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(root..name,"rb"));local s=f:read("*a"):gsub("\r\n","\n");f:close();return s end
local blocks,syntax,features=read("blocks.lua"),read("syntax.lua"),read("features.lua")
local env=setmetatable({ID="id",UNITNAME="name",addundo=function() end},{__index=_G})
local hasfeature=assert(features:match('(function hasfeature%(.-)\nfunction hasfeature_count'))
assert(load(hasfeature,"@installed_hasfeature_birth_clock","t",env))()
local broken=assert(blocks:match('(function brokenblock%(.-)\nfunction statusblock'))
assert(load(broken,"@installed_brokenblock_birth_clock","t",env))()
local clock=assert(blocks:match('(if %(featureindex%["back"%] ~= nil%) then.-)\n\t\t\tend\n\t\tend'))
local resets=assert(syntax:match('(unit.back_init = 0\n\tunit.broken = 0)'))
local native=assert(load('return function(unit,name) '..resets..' brokenblock({unit}) '..clock..' end',"@installed_addunit_clock_reset","t",env))()
local cases=0
for count=0,8 do for _,old in ipairs({0,2,99}) do for active=0,2 do for damaged=0,1 do for class=0,1 do
 local s=fixture();s.back_frame_count=nil;local w=s.world;w.entities={};w.next_entity_id=20;w.rule_sources={}
 local target=class==0 and {kind="archetype",value="rock"} or {kind="class",value="text"}
 local name=class==0 and "rock" or "text_rock";local generic=class==0 and "rock" or "text"
 env.undobuffer={};for i=1,count do env.undobuffer[i]={} end
 env.featureindex={};env.featureindex[generic]={}
 if active>0 then
  local r={{generic,"is","back"},{{active==2}}};env.featureindex[generic][#env.featureindex[generic]+1]=r;env.featureindex.back={r}
  w.rule_sources[#w.rule_sources+1]={when=active==2 and {op="always"} or {op="spatial",clauses={{relation="on",negated=false,parameters={{tag="noun",type={tag="object",name="flag"}}}}}},
   effects={{op="grant_trait",target=target,trait="back"}}}
 end
 if damaged==1 then
  env.featureindex[generic][#env.featureindex[generic]+1]={{generic,"is","broken"},{{true}}}
  w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target=target,trait="broken"}}}
 end
 local unit={fixed=20,back_init=old,broken=1,values={id=20},strings={name=name}}
 env.units={unit};env.testcond=function(conds) return unit.broken==0 and conds[1][1] end
 native(unit,generic)
 local spec={kind="object",class=class==0 and "object" or "text",archetype=class==0 and "rock" or nil,
  text=class==1 and {name="ROCK"} or nil,x=3,y=3,direction="Up",broken=1,back_init=old}
 local result=assert(RW_InitializeBirthSpecifications(w,{spec},{},count))[1]
 assert((result.back_init or 0)==unit.back_init and (result.broken or 0)==unit.broken,"native birth clock mismatch")
 assert(spec.back_init==old and spec.broken==1 and not w.entities[20])
 -- The primary conversion reuses a persistent ID, but still resets like addunit.
 local src={id=1,kind="object",class="object",archetype="avatar",x=3,y=3,direction="Up",back_init=old}
 w.entities[1]=src
 local relation={op=class==0 and "transform" or "write_text",source_type="avatar",target_type=class==0 and "rock" or nil,target_text=class==1 and "ROCK" or nil}
 local ops,e,allocation=RW_PlanConversions(w,{relation},{},count);assert(ops,e)
 local out,r=RW_Commit(s,{consumes_turn=true,changes=ops,id_allocation=allocation});assert(r.accepted,r.reason)
 assert((out.world.entities[1].back_init or 0)==unit.back_init and (out.world.entities[1].broken or 0)==unit.broken)
 cases=cases+2
end end end end end
assert(cases==648)
print("PASS: installed addunit/reset/brokenblock/hasfeature/BACK birth and primary-conversion clock oracle (648 cases), Object/Text, failed conditions, inherited clocks and BROKEN gating")

local s=fixture({{"AVATAR","IS","ROCK","AND","ROCK"},{"AVATAR","IS","BACK"},{"ROCK","ON","AVATAR","IS","BACK"}})
s.world.entities[1].back_init=2
local n,p=step(s);local rocks=objects(n.world,"rock");assert(#rocks==2)
for _,e in ipairs(rocks) do assert(e.back_init==6) end
-- Same-name BECOME must reset status even without a persistent shape operation.
s=fixture({{"AVATAR","BECOME","AVATAR"},{"AVATAR","IS","BACK"}});s.world.entities[1].back_init=2
n=step(s);assert(n.world.entities[1].back_init==6)
s=fixture({{"AVATAR","WRITE","ROCK"},{"TEXT","IS","BACK"}});s.world.entities[1].back_init=2
n=step(s);assert(n.world.entities[1].class=="text" and n.world.entities[1].back_init==6)
s=fixture({{"AVATAR","IS","ROCK"},{"ROCK","IS","BACK"},{"ROCK","IS","BROKEN"}});s.world.entities[1].back_init=2
n=step(s);assert(n.world.entities[1].broken==1 and (n.world.entities[1].back_init or 0)==0)

-- MORE's copies and MAKE's late births get the current absolute native count.
s=fixture({{"AVATAR","IS","MORE","AND","BACK"}});s.world.entities[1].back_init=2
n=step(s);local avatars=objects(n.world,"avatar");assert(#avatars==5 and n.world.entities[1].back_init==2)
for _,e in ipairs(avatars) do if e.id~=1 then assert(e.back_init==6) end end
s=fixture({{"AVATAR","MAKE","ROCK","AND","ROCK"},{"ROCK","IS","BACK"}})
n=step(s);rocks=objects(n.world,"rock");assert(#rocks==2 and rocks[1].back_init==6 and rocks[2].back_init==6)

-- Contacts and movement death frames still expose the dying HAS parent to ON.
s=fixture({{"AVATAR","IS","DEFEAT"},{"AVATAR","HAS","ROCK"},{"ROCK","ON","AVATAR","IS","BACK"}})
n=step(s);rocks=objects(n.world,"rock");assert(#rocks==1 and rocks[1].back_init==6 and not n.world.entities[1])
s=fixture({{"AVATAR","IS","WEAK"},{"AVATAR","HAS","ROCK"},{"ROCK","ON","AVATAR","IS","BACK"}})
s.world.entities[1].x=1
n=step(s,{type="move",dx=-1,dy=0});rocks=objects(n.world,"rock");assert(#rocks==1 and rocks[1].back_init==6 and rocks[1].x==1)

for _,cause in ipairs({"eat","bonus"}) do
 s=fixture({{"AVATAR",cause=="eat" and "EAT" or "HAS","FLAG"},{"FLAG","HAS","ROCK"},{"ROCK","IS","BACK"}})
 s.world.entities[2]={id=2,kind="object",class="object",archetype="flag",x=3,y=3,direction="Left"}
 if cause=="bonus" then s.world.rule_sources[#s.world.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="flag"},trait="bonus"}}} end
 n=step(s);rocks=objects(n.world,"rock");assert(#rocks==1 and rocks[1].back_init==6)
 if cause=="bonus" then assert(n.world.bonus_count==1) end
end

-- Saved runtime clocks are not authored facts across boot/boundaries. Do not
-- activate a new BACK clock just because authored Text contains that word.
s=fixture({{"AVATAR","IS","BACK"}});s.world.entities[1].back_init=99;s.world.entities[1].broken=1
local initialized=assert(RW_InitializeLevelWorld(s.world,services))
assert((initialized.entities[1].back_init or 0)==0 and (initialized.entities[1].broken or 0)==0 and not initialized.chance_seed)
assert(s.world.entities[1].back_init==99 and not s.turn_records)
local clean=fixture({{"AVATAR","IS","BACK"}}).world
assert(RW_InitializeLevelWorld(clean,services)==clean and not clean.entities[1].back_init)
for _,bad in ipairs({-1,0.5,"5",false}) do
 local out,why=RW_InitializeBirthSpecifications(clean,{}, {},bad);assert(not out and why=="invalid_back_clock")
 local out,why=RW_PlanConversions(clean,{}, {},bad);assert(not out and why=="invalid_back_clock")
end
print("PASS: scheduled HAS/contact/movement/EAT/BONUS/MORE/MAKE and IS/WRITE/BECOME clocks, source witnesses, duplicates, atomic Undo, saved-clock reset and non-activating startup")

local function recursive_back()
 local rules={}
 for i=0,82 do rules[#rules+1]={when={op="spatial",clauses={{relation="feeling",negated=false,parameters={{tag="property",name="clock_limit_"..(i+1)}}}}},
  effects={{op="grant_trait",target={kind="archetype",value="rock"},trait=i==0 and "back" or "clock_limit_"..i}}} end
 rules[#rules+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="rock"},trait="clock_limit_83"}}}
 rules[#rules+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="flag"},trait="back"}}}
 return rules
end
local raw=recursive_back();s=fixture();s.world.next_entity_id=20;s.world.entities[1].back_init=2
local specs={}
for _,name in ipairs({"flag","rock","flag"}) do specs[#specs+1]={kind="object",class="object",archetype=name,x=3,y=3,direction="Up",back_init=99} end
local out,why,prefix=RW_InitializeBirthSpecifications(s.world,specs,raw,5)
assert(not out and why=="word_rule_limit" and #prefix==2 and prefix[1].back_init==6 and not prefix[2].back_init)
assert(specs[1].back_init==99 and specs[2].back_init==99)
local born=assert(RW_PlanInitializedCreation(s.world,specs,raw,{initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate},5))
born.back_frame={from=5,retain=true};local limited,r=RW_Commit(s,born);assert(r.accepted,r.reason)
assert(limited.world.infinite_loop and limited.world.entities[20].back_init==6 and not limited.world.entities[21].back_init and limited.world.next_entity_id==22)
assert(RW_Undo(limited).world==s.world)
local relations={{op="transform",source_type="avatar",target_type="flag"},{op="transform",source_type="avatar",target_type="rock"},
 {op="transform",source_type="avatar",target_type="flag"}}
local ops,e,allocation,_,terminal,events=RW_PlanConversions(s.world,relations,raw,5);assert(ops,e)
assert(terminal=="word_rule_limit" and #events==1 and events[1].retained_conversion and not events[1].removed)
local partial={consumes_turn=true,changes=ops,id_allocation=allocation,back_conversions=events,infinite_loop=true,back_frame={from=5,retain=true}}
limited,r=RW_Commit(s,partial);assert(r.accepted,r.reason)
assert(limited.world.entities[1].archetype=="avatar" and limited.world.entities[1].back_init==2)
assert(limited.world.entities[20].archetype=="flag" and limited.world.entities[20].back_init==6 and limited.world.entities[21].archetype=="rock" and not limited.world.entities[21].back_init)
assert(limited.world.next_entity_id==22 and RW_Undo(limited).world==s.world)

-- Each movement death frame receives earlier initialized births and a shifted
-- temporary allocator; status failure keeps only earlier parents' destruction.
s=fixture();s.world.next_entity_id=20
s.world.entities[2]={id=2,kind="object",class="object",archetype="crate",x=6,y=3,direction="Left",back_init=2}
local has={{op="has",target={kind="archetype",value="avatar"},product={kind="object",archetype="flag"}},
 {op="has",target={kind="archetype",value="crate"},product={kind="object",archetype="rock"}}}
local deaths={{entity_id=1,frame=s.world.entities},{entity_id=2,frame=s.world.entities}}
local destruction=assert(RW_PlanDestructionPhase(s.world,{1,2},has,"movement",lifecycle,deaths,raw,5))
destruction.back_frame={from=5,retain=true};limited,r=RW_Commit(s,destruction);assert(r.accepted,r.reason)
assert(limited.world.infinite_loop and not limited.world.entities[1] and limited.world.entities[2].back_init==2)
assert(limited.world.entities[20].back_init==6 and not limited.world.entities[21].back_init and limited.world.entities[21].x==6)
assert(RW_Undo(limited).world==s.world)

-- Boundary initialization is part of the outer whole-tree transaction only.
s=fixture();s.world.entities[1].back_init=99
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",s.world))},"root"))
local active=RW_GetActiveLevel(tree)
local adapted={initialize=function(w) return RW_InitializeLevelWorld(w,services) end,update_instance=RW_UpdateLevelInstance}
local boundary=assert(RW_InitializeLevelBoundary(tree,{tree.active_id},adapted))
local committed,r=RW_CommitLevelTree(tree,{before=tree,after=boundary});assert(r.accepted,r.reason)
assert(RW_GetActiveLevel(committed).world.entities[1].back_init==0 and #RW_GetActiveLevel(committed).history==0)
assert(RW_UndoLevelTree(committed).instances[tree.active_id]==active and active.world.entities[1].back_init==99)
print("PASS: BACK newborn/conversion query-limit prefixes retain earlier clocks and triggering zero clocks, death-frame allocators, no speculative source reset, terminal/tree/local Undo")
