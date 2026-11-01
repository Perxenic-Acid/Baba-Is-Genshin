local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows,origin)
 local s=RW_CreateSession();local w=s.world;w.width=24;w.height=24;w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag"
 w.entities={[1]={id=1,kind="object",class="object",archetype="rock",original_name=origin,x=12,y=18,direction="Down",level_link={target="parent",source_type="level_block"}}};w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
 w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"} end end
 return s
end
local function step(s)
 local p,e=RW_PlanTurn(s.world,{type="wait"},services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n,p
end
local function units(w) local count=0;for _,u in pairs(w.entities) do if u.y==18 then count=count+1 end end;return count end
local s=fixture({{"ROCK","IS","REVERT"}},"avatar");local n,p=step(s)
assert(n.world.entities[1].archetype=="avatar" and n.world.entities[1].direction=="Down" and n.world.entities[1].level_link.target=="parent")
assert(n.world.entities[1].original_name=="avatar" and s.world.entities[1].archetype=="rock")
s=fixture({{"ROCK","IS","REVERT"},{"ROCK","IS","REVERT"},{"ROCK","IS","FLAG"}},"avatar")
n=step(s);assert(units(n.world)==1 and n.world.entities[1].archetype=="avatar","effective REVERT must preempt all other products")
s=fixture({{"ROCK","IS","REVERT"},{"ROCK","IS","FLAG"}})
n=step(s);assert(n.world.entities[1].archetype=="flag","ineffective same-origin REVERT must not suppress ordinary conversions")
s=fixture({{"ROCK","IS","REVERT"},{"ROCK","IS","NOT","REVERT"}},"avatar")
n=step(s);assert(n.world.entities[1].archetype=="rock")
s=fixture({{"ROCK","IS","ROCK"},{"ROCK","IS","REVERT"}},"avatar")
n=step(s);assert(n.world.entities[1].archetype=="rock")
s=fixture({{"ROCK","IS","ROCK"},{"ROCK","BECOME","REVERT"}},"avatar")
n=step(s);assert(n.world.entities[1].archetype=="rock","installed BECOME accepts noun arguments, not REVERT quality")
s=fixture({{"ROCK","BECOME","REVERT"},{"ROCK","BECOME","NOT","REVERT"}},"avatar")
n=step(s);assert(n.world.entities[1].archetype=="rock")
s=fixture({{"ROCK","IS","REVERT"}},"text_FLAG")
n=step(s);assert(n.world.entities[1].class=="text" and n.world.entities[1].text.name=="FLAG" and n.world.entities[1].original_name=="text_FLAG")
s=fixture({{"ROCK","IS","REVERT"},{"ROCK","HAS","FLAG"}},"@empty")
n=step(s);assert(not n.world.entities[1] and units(n.world)==0,"origin EMPTY conversion must delete without HAS")
s=fixture({{"EMPTY","IS","REVERT"}})
n=step(s);assert(units(n.world)==1 and n.world.next_entity_id==s.world.next_entity_id)
s=fixture({{"ROCK","NEAR","FLAG","IS","REVERT"}},"avatar")
n=step(s);assert(n.world.entities[1].archetype=="rock")
s.world.entities[2]={id=2,kind="object",class="object",archetype="flag",x=13,y=18,direction="None"}
n=step(s);assert(n.world.entities[1].archetype=="avatar")
s=fixture({{"ROCK","IS","REVERT"},{"ROCK","IS","BROKEN"}},"avatar");s.world.entities[1].broken=1
n=step(s);assert(n.world.entities[1].archetype=="rock")
s=fixture({{"ROCK","WRITE","REVERT"}})
n=step(s);assert(n.world.entities[1].class=="text" and n.world.entities[1].text.name=="REVERT")
print("PASS: public REVERT priority/suppression, IS identity/BECOME, NOT, Text/Empty origin, conditions/BROKEN, WRITE literal and atomic Undo")

-- Installed convert() product collection, not a reconstructed selection algorithm.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]],"rb"));local source=f:read("*a");f:close()
local code=assert(source:match("(function convert%(stuff,mats,dolevels_%).-)\nfunction doconvert"))
local cases=0
for _,origin in ipairs({"rock","avatar","text_FLAG","@empty"}) do for reverts=0,3 do for ordinary=0,2 do for enabled=0,1 do
 local captured={};local unit={fixed=11,values={x=12,y=18,dir=3,id=1},strings={name="rock"},originalname=origin,flags={converted=false}}
 local env=setmetatable({map={[0]={}},unitlists={rock={11}},editor2={values={cursor=0}},CURSORSEXIST="cursor",XPOS="x",YPOS="y",DIR="dir",ID="id",UNITNAME="name",CONVERTED="converted",
  mmf={newObject=function() return unit end},getname=function() return "rock" end,unitreference={},
  testcond=function(c) return c.enabled~=false end,newid=function() return 100 end,
  addaction=function(_,action) captured=action[2] end},{__index=_G})
 assert(load(code,"@installed_REVERT_convert","t",env))()
 local mats,relations={},{}
 for i=1,ordinary do mats[#mats+1]={"flag",{}};relations[#relations+1]={op="transform",source_type="rock",target_type="flag"} end
 for i=1,reverts do table.insert(mats,1,{"revert",{enabled=enabled==1}});relations[#relations+1]={op="transform",source_type="rock",target_type="@revert",when={op="always"},exclusions=enabled==0 and {{op="always"}} or nil} end
 env.convert("rock",mats)
 local session=fixture({},origin);local changes,e,allocation=RW_PlanConversions(session.world,relations);assert(changes,e)
 local after,r=RW_Commit(session,{consumes_turn=true,changes=changes,id_allocation=allocation});assert(r.accepted,r.reason)
 local expected={};if #captured==0 then expected.rock=1 end
 for _,product in ipairs(captured) do local target=product[1]=="revert" and origin or product[1];if target~="@empty" then expected[target]=(expected[target] or 0)+1 end end
 local actual={};for _,u in pairs(after.world.entities) do local name=u.class=="text" and "text_"..u.text.name or u.archetype;actual[name]=(actual[name] or 0)+1 end
 for k,v in pairs(expected) do assert(actual[k]==v,"installed REVERT product mismatch") end;for k,v in pairs(actual) do assert(expected[k]==v,"unexpected REVERT product") end
 cases=cases+1
end end end end
assert(cases==96);print("PASS: installed REVERT conversion collection oracle (96 cases)")

s=fixture({{"ROCK","IS","GROUP"},{"GROUP","IS","REVERT"}},"avatar")
n=step(s);assert(n.world.entities[1].archetype=="avatar")
s=fixture({{"ROCK","MIMIC","AVATAR"},{"AVATAR","IS","REVERT"}},"flag")
n=step(s);assert(n.world.entities[1].archetype=="flag")
s=fixture({{"ALL","IS","REVERT"}},"avatar")
n=step(s);assert(n.world.entities[1].archetype=="avatar")
s=fixture({{"TEXT","IS","REVERT"}},"avatar");s.world.entities[1].class="text";s.world.entities[1].archetype=nil;s.world.entities[1].text={name="FLAG"}
n=step(s);assert(n.world.entities[1].class=="object" and n.world.entities[1].archetype=="avatar")
-- Concrete noun bans do not become bans on an indirect REVERT destination.
s=fixture({{"ROCK","IS","REVERT"},{"ROCK","IS","NOT","AVATAR"}},"avatar")
n=step(s);assert(n.world.entities[1].archetype=="avatar")
print("PASS: REVERT GROUP/MIMIC/ALL/physical Text and indirect destination ban isolation")

s=fixture({{"LEVEL","IS","REVERT"}},"rock");s.world.language.nouns.LEVEL={tag="level",block_type="level_block"};s.world.entities[1].archetype="level_block"
n=step(s);assert(n.world.entities[1].archetype=="rock" and n.world.entities[1].level_link.target=="parent")
s=fixture({{"LEVEL","IS","REVERT"},{"LEVEL","IS","NOT","REVERT"}},"rock");s.world.language.nouns.LEVEL={tag="level",block_type="level_block"};s.world.entities[1].archetype="level_block"
n=step(s);assert(n.world.entities[1].archetype=="level_block")
print("PASS: physical LEVEL block REVERT/NOT retains destination identity")

s=fixture({{"ROCK","IS","REVERT","AND","FLAG"}},"avatar")
n=step(s);assert(units(n.world)==1 and n.world.entities[1].archetype=="avatar")
print("PASS: REVERT physical RHS AND preemption")
