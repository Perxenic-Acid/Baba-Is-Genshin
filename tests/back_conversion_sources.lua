local function copy(x) if type(x)~="table" then return x end;local r={};for k,v in pairs(x) do r[k]=copy(v) end;return r end
local function fixture(text)
 local s=RW_CreateSession();s.world.width=8;s.world.height=6;s.world.next_entity_id=10;s.world.language={nouns={AVATAR="avatar",ROCK="rock",FLAG="flag"}}
 s.world.entities={[1]={id=1,kind="object",class=text and "text" or "object",archetype=not text and "avatar" or nil,text=text and {name="FLAG"} or nil,x=2,y=2,direction="Up",original_name="flag",followed=7,back_init=3,level_link={target="parent",source_type="avatar"}}};return s
end
local function convert(s,relations)
 local ops,e,allocation,converted,terminal,events=RW_PlanConversions(s.world,relations);assert(ops,e)
 local p={consumes_turn=true,changes=ops,id_allocation=allocation,back_conversions=events}
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);return n,p,events,converted,terminal
end
local s=fixture();local before=copy(s.world.entities[1])
local n,p,events=convert(s,{{op="transform",source_type="avatar",target_type="rock"},{op="transform",source_type="avatar",target_type="flag"},{op="transform",source_type="avatar",target_type="rock"}})
assert(#events==1 and events[1].source.id==1 and events[1].source.archetype=="avatar" and events[1].removed)
assert(#events[1].product_ids==3 and events[1].product_ids[1]==1 and events[1].product_ids[2]==10 and events[1].product_ids[3]==11)
assert(n.world.entities[10].archetype=="flag" and n.world.entities[11].archetype=="rock")
local record=assert(RW_GetTurnRecord(n,1));assert(record.phases[1].back_conversions[1].product_ids[3]==11)
events[1].source.archetype="tampered";record.phases[1].back_conversions[1].product_ids[3]=99
assert(RW_GetTurnRecord(n,1).phases[1].back_conversions[1].source.archetype=="avatar")
assert(RW_GetTurnRecord(n,1).phases[1].back_conversions[1].product_ids[3]==11)
assert(n.world.back_conversions==nil and n.world.entities[10].back_conversions==nil and RW_Undo(n).world==s.world)
-- Same-name BECOME emits no shape op but remains an actual conversion event.
s=fixture();before=copy(s.world.entities[1])
n,p,events=convert(s,{{op="become",source_type="avatar",target_type="avatar",when={op="always"}}})
assert(#p.changes==0 and #events==1 and events[1].removed and events[1].product_ids[1]==1)
local restore,e=RW_PlanBackPlayback(n.world,{{entity_id=1,before=before,record=assert(RW_GetTurnRecord(n,1))}});assert(restore,e)
assert(restore.changes[1].kind=="back_restore" and restore.changes[1].to.original_name==nil)
s=fixture(true);before=copy(s.world.entities[1])
n,p,events=convert(s,{{op="write_text",source_type="@text",target_text="FLAG"}})
assert(#p.changes==0 and events[1].source.text.name=="FLAG")
assert(RW_PlanBackPlayback(n.world,{{entity_id=1,before=before,record=assert(RW_GetTurnRecord(n,1))}}).changes[1].kind=="back_restore")
-- ALL retains its source; its extra products have no remove partner.
s=fixture();n,p,events=convert(s,{{op="transform_all",source_type="avatar"}})
assert(not events[1].removed and events[1].source.id==1 and #events[1].product_ids==2)
assert(events[1].product_ids[1]==10 and n.world.entities[1].archetype=="avatar")
-- Conversion deletion is recorded without pretending it had a product.
s=fixture();n,p,events=convert(s,{{op="forbid_transform",source_type="avatar",target_type="avatar"}})
assert(events[1].removed and #events[1].product_ids==0 and not n.world.entities[1])
-- EMPTY births have cell origins, not a fake physical source identity.
s=fixture();s.world.width=3;s.world.height=1;s.world.entities[1].x=1;s.world.entities[1].y=1
n,p,events=convert(s,{{op="transform",source_type="@empty",target_type="rock"}})
assert(#events==2 and not events[1].source and events[1].empty.x==2 and not events[1].removed)
assert(events[2].empty.x==3 and events[1].product_ids[1]==10 and events[2].product_ids[1]==11)
-- Journal metadata preconditions are atomic even for a no-op shape conversion.
s=fixture();local ops,e,allocation,_,_,source_events=RW_PlanConversions(s.world,{{op="become",source_type="avatar",target_type="avatar",when={op="always"}}});assert(ops,e)
for _,mutate in ipairs({
 function(v) v[1].source.x=3 end,
 function(v) v[1].product_ids={9} end,
 function(v) v[1].product_ids={1,1} end,
 function(v) v[1].source=false end,
 function(v) v[1].removed=false end,
 function(v) v[1].source=nil;v[1].empty={x=2,y=2} end
}) do
 local bad=copy(source_events);mutate(bad)
 local same,r=RW_Commit(s,{consumes_turn=true,changes=ops,id_allocation=allocation,back_conversions=bad});assert(same==s and not r.accepted)
end
print("PASS: conversion source journals preserve ordered duplicate/primary/branch IDs, same-name BECOME/WRITE, ALL retention, deletion/EMPTY origins, ownership, stale atomic rejection and Undo")

local f=assert(io.open("C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua","rb"));local source=f:read("*a");f:close()
local code=assert(source:match("(function convert%(stuff,mats,dolevels_%).-)\nfunction doconvert"))
local cases=0
for _,text in ipairs({false,true}) do for enabled=0,1 do for count=1,4 do for offset=0,2 do
 local captured={};local next_id=10;local name=text and "text" or "avatar"
 local unit={fixed=11,values={x=2,y=2,dir=1,id=1},strings={name=text and "text_FLAG" or "avatar"},originalname="flag",flags={converted=false}}
 local env=setmetatable({map={[0]={}},unitlists={[name]={11}},editor2={values={cursor=0}},CURSORSEXIST="cursor",XPOS="x",YPOS="y",DIR="dir",ID="id",UNITNAME="name",CONVERTED="converted",
  mmf={newObject=function() return unit end},getname=function() return name end,unitreference={},
  testcond=function(c) return c.enabled end,newid=function() local id=next_id;next_id=id+1;return id end,
  addaction=function(_,a) captured=a[2] end},{__index=_G})
 assert(load(code,"@installed_conversion_provenance","t",env))()
 local mats,relations={},{}
 for i=1,count do local target=({"rock","flag","rock"})[((i+offset-1)%3)+1]
  mats[#mats+1]={target,{enabled=enabled==1}}
  relations[#relations+1]={op="transform",source_type=text and "@text" or "avatar",target_type=target,when={op="always"},exclusions=enabled==0 and {{op="always"}} or nil}
 end
 env.convert(name,mats)
 local s=fixture(text);local _,_,events=convert(s,relations)
 if #captured==0 then assert(events==nil)
 else
  assert(#events==1 and events[1].removed and events[1].source.id==1 and #events[1].product_ids==#captured)
  for i,row in ipairs(captured) do assert(events[1].product_ids[i]==row[2] and row[3]==events[1].source.id,"native source/product ID mismatch") end
 end
 cases=cases+1
end end end end
assert(cases==48);print("PASS: installed conversion source/product ID collection oracle (48 cases)")

local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
s=fixture();s.world.width=20;s.world.height=12;s.world.entities[1].x=12;s.world.entities[1].y=10;s.world.language=RW_CreateSession().world.language;s.world.language.nouns.ROCK="rock";s.world.language.nouns.FLAG="flag"
for row,words in ipairs({{"AVATAR","IS","ROCK"},{"AVATAR","IS","FLAG"}}) do for x,word in ipairs(words) do
 local id=s.world.next_entity_id;s.world.next_entity_id=id+1;s.world.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"}
end end
local turn,e=RW_PlanTurn(s.world,{type="wait"},services);assert(turn,e and e.reason)
local phase;for _,v in ipairs(turn.stages) do if v.name=="conversion" then phase=v.plan end end
assert(phase and phase.back_conversions and #phase.back_conversions[1].product_ids==2)
local committed,r=RW_Commit(s,turn);assert(r.accepted,r.reason)
local journal=assert(RW_GetTurnRecord(committed,1));local found
for _,v in ipairs(journal.phases) do if v.name=="conversion" then found=v.back_conversions end end
assert(found and found[1].source.archetype=="avatar" and found[1].source.x==12 and found[1].removed)
assert(RW_Undo(committed).world==s.world)
print("PASS: real compiler/turn scheduler preserves conversion provenance through phase validation, Commit journals and Undo")

local raw={}
for i=0,82 do raw[#raw+1]={when={op="spatial",clauses={{relation="feeling",negated=false,parameters={{tag="property",name="limit_"..(i+1)}}}}},effects={{op="grant_trait",target={kind="archetype",value="rock"},trait=i==0 and "broken" or "limit_"..i}}} end
raw[#raw+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="rock"},trait="limit_83"}}}
s=fixture();local ops,e,allocation,_,terminal,events=RW_PlanConversions(s.world,{{op="transform",source_type="avatar",target_type="flag"},{op="transform",source_type="avatar",target_type="rock"}},raw)
assert(ops,e);assert(terminal=="word_rule_limit" and #events==1 and not events[1].removed)
assert(events[1].product_ids[1]==10 and events[1].product_ids[2]==11)
local after,r=RW_Commit(s,{consumes_turn=true,changes=ops,id_allocation=allocation,back_conversions=events,infinite_loop=true});assert(r.accepted,r.reason)
assert(after.world.entities[1].archetype=="avatar" and RW_GetTurnRecord(after,1).phases[1].back_conversions[1].removed==false)
assert(RW_Undo(after).world==s.world)
print("PASS: interrupted conversion groups journal allocated trigger products and retained sources without leaking speculative primary identity")
