local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.entities={
        [1]={id=1,kind="object",class="object",archetype="rock",x=2,y=2,direction="Left",broken=1},
        [2]={id=2,kind="object",class="object",archetype="rock",x=4,y=2,direction="Right"},
        [3]={id=3,kind="object",class="object",archetype="avatar",x=6,y=2,direction="Up"}}
    w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag"
    w.next_entity_id=10
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="None",broken=1}
    end end
    return s
end
local function frame(s)
    local f,e=RW_CompileWorld(s.world,cs);assert(f,e and e.reason)
    return f,assert(RW_ProjectWorld(s.world,f.effects))
end
local s=fixture({{"ROCK","IS","YOU","AND","WORD"}})
local f,p=frame(s)
assert(not p.entities[1].behaviors.control and not p.entities[1].behaviors.word)
assert(p.entities[2].behaviors.control and p.entities[2].behaviors.word)
assert(not f.word_tokens[1] and f.word_tokens[2]=="ROCK")
for id=10,s.world.next_entity_id-1 do
    assert(f.active_text_ids[id],"broken physical Text must still form complete sentences")
    assert(not p.entities[id].behaviors.push,"broken Text must lose default PUSH")
end
local saved=s.world.entities[10].broken;s.world.entities[10].broken=0
local healthy_frame,healthy=frame(s);assert(healthy.entities[10].behaviors.push,"fixture lost default TEXT IS PUSH")
s.world.entities[10].broken=saved
local relation={when={op="always"}}
assert(not RW_RelationApplies(s.world,relation,s.world.entities[1]))
assert(RW_RelationApplies(s.world,relation,s.world.entities[2]))
local inverse={op="not",condition={op="not",condition={op="always"}}}
assert(not RW_TestEntityCondition(s.world,inverse,s.world.entities[1]))
assert(RW_TestEntityCondition(s.world,inverse,s.world.entities[2]))
s=fixture({{"ROCK","IS","FLAG"},{"ROCK","HAS","FLAG"}})
f=frame(s)
local conversions,has={},{}
for _,r in ipairs(f.relations) do if r.op=="has" then has[#has+1]=r else conversions[#conversions+1]=r end end
local changes=assert(RW_PlanConversions(s.world,conversions))
assert(#changes==1 and changes[1].entity_id==2 and changes[1].to=="flag")
assert(#assert(RW_PlanHasBirths(s.world,{1},has))==0)
assert(#assert(RW_PlanHasBirths(s.world,{2},has))==1)
s=fixture({{"ROCK","IS","POWER"},{"POWERED","AVATAR","IS","YOU"}})
s.world.entities[2].broken=1
f,p=frame(s);assert(not p.entities[3].behaviors.control,"broken POWER must not energize POWERED")
s.world.entities[2].broken=0
f,p=frame(s);assert(p.entities[3].behaviors.control)
s=fixture({{"ROCK","MAKE","FLAG"},{"ROCK","FEAR","AVATAR"},{"ROCK","FOLLOW","AVATAR"},{"ROCK","EAT","AVATAR"}})
f=frame(s)
for _,verb in ipairs({"fear","follow","eat"}) do
    local targets=RW_ResolveVerbTargets(s.world,f.relations,verb)
    assert(not targets[1] and targets[2] and #targets[2]==1,"broken predicate source: "..verb)
end
local products=assert(RW_PlanMakeProducts(s.world,f.relations,{}))
assert(#products==1 and products[1].x==4 and products[1].y==2)
s=fixture({{"AVATAR","NEAR","ROCK","IS","YOU"}})
s.world.entities[2].x=10;s.world.entities[3].x=3
f,p=frame(s);assert(p.entities[3].behaviors.control,"broken witnesses remain physical ON/NEAR targets")
-- Raw declaration queries: own BROKEN must not be silenced by its old status;
-- spatial conditions still test the source identity rather than a board Boolean.
s=fixture({});local w=s.world
local rules={{when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="rock"},trait="broken"}}}}
local status=assert(RW_PlanRuleStatus(w,rules));assert(#status.changes==1 and status.changes[1].entity_id==2)
local n,result=RW_Commit(s,status);assert(result.accepted and n.world.entities[1].broken==1 and n.world.entities[2].broken==1)
local clear=assert(RW_PlanRuleStatus(n.world,{}));assert(#clear.changes==2)
local recovered,accepted=RW_Commit(n,clear);assert(accepted.accepted and recovered.world.entities[1].broken==0)
assert(RW_Undo(recovered).world==n.world)
rules[#rules+1]={when={op="always"},effects={{op="deny_trait",target={kind="id",value=1},trait="broken"}}}
status=assert(RW_PlanRuleStatus(w,rules));assert(#status.changes==2 and status.changes[1].to==0 and status.changes[2].to==1)
-- Installed testcond checks status even for an empty/unconditional condition list.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],"rb"))
local source=file:read("*a");file:close()
for broken=0,1 do for text=0,1 do for ignore=0,1 do
    local u={values={2,2,0},strings={"rock",text==1 and "text" or "object"},broken=broken}
    local env=setmetatable({XPOS=1,YPOS=2,DIR=3,UNITNAME=1,UNITTYPE=2,features={true},
        mmf={newObject=function() return u end}},{__index=_G})
    assert(load(source,"@installed_conditions","t",env))()
    assert(env.testcond({},3,nil,nil,nil,nil,nil,ignore==1)==(broken==0 or ignore==1))
end end end
print("PASS: BROKEN rule queries, physical Text/WORD separation, default properties, conversion/HAS, POWERED, raw status refresh and installed testcond oracle")
