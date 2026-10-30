local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={status=RW_PlanRuleStatus,shift=RW_ResolveShift,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(subject,convert)
    local s=RW_CreateSession();local w=s.world
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=3,y=4,direction="Down"},
        [2]={id=2,kind="object",class="object",archetype="rock",x=8,y=2,direction="Left"}}
    w.language.properties.BROKEN="broken";w.language.nouns.ROCK="rock"
    w.rule_sources={{when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="you"}}}}
    w.rule_sources[2]={when={op="always"},effects={{op="grant_trait",target={kind="class",value="text"},trait="pushable"}}}
    w.next_entity_id=10
    local function text(word,x,y)
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=y,direction="None"}
        return id
    end
    text(subject,1,6);text("IS",2,6);text("BROKEN",3,5)
    if convert then text("TEXT",1,9);text("IS",2,9);text("ROCK",3,9) end
    return s
end
local function move(s)
    local p,e=RW_PlanTurn(s.world,{type="move",dx=0,dy=1},services);assert(p,e and (e.stage..":"..e.reason))
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
    return n,p
end
local s=fixture("TEXT",true)
local frame=assert(RW_CompileWorld(s.world,cs));assert(#frame.code_status.changes==0)
local n,plan=move(s)
assert(n.world.entities[12].y==6)
local index
for i,stage in ipairs(plan.stages) do if stage.name=="code_status_after_move" then index=i end end
assert(index and plan.stages[index+1].name=="conversion")
for id=10,15 do assert(n.world.entities[id].class=="text" and n.world.entities[id].broken==1,"new BROKEN Text converted before status refresh") end
assert(not s.world.entities[10].broken and RW_Undo(n).world==s.world)
-- SHIFT can passively move broken Text, break its rule, and restore its default
-- PUSH within the same atomic turn. Text was never removed from the reader.
s=fixture("TEXT",false)
s.world.rule_sources[1].effects[2]={op="grant_trait",target={kind="archetype",value="avatar"},trait="shift"}
n,plan=move(s)
local recovered,release=move(n)
assert(recovered.world.entities[12].y==7)
for id=10,12 do assert(recovered.world.entities[id].broken==0) end
frame=assert(RW_CompileWorld(recovered.world,cs))
local projected=assert(RW_ProjectWorld(recovered.world,frame.effects))
assert(projected.entities[12].behaviors.push and RW_Undo(recovered).world==n.world)
-- Ordinary ROCK is not part of the code() candidate set. It is latched at the
-- next before-input statusblock rather than being refreshed early after Text push.
s=fixture("ROCK",false)
n=move(s);assert(not n.world.entities[2].broken)
local p,e=RW_PlanTurn(n.world,{type="wait"},services);assert(p,e and e.reason)
local next,r=RW_Commit(n,p);assert(r.accepted and next.world.entities[2].broken==1)
-- A WORD ROCK is included, even when current BROKEN already removes its token.
s=fixture("ROCK",false)
s.world.rule_sources[1].effects[2]={op="grant_trait",target={kind="archetype",value="rock"},trait="word"}
n=move(s);assert(n.world.entities[2].broken==1)
frame=assert(RW_CompileWorld(n.world,cs));assert(not frame.word_tokens[2])
-- A conversion-created Text receives its code-scope status before contacts.
s=fixture("TEXT",false);s.world.entities[12].y=6
for x,word in ipairs({"ROCK","IS","TEXT"}) do local id=12+x
    s.world.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=9,direction="None"}
end
s.world.next_entity_id=16
n,plan=move(s)
assert(n.world.entities[2].class=="text" and n.world.entities[2].text.name=="ROCK" and n.world.entities[2].broken==1)
local found=false;for _,stage in ipairs(plan.stages) do if stage.name=="code_status_after_conversion" then found=true end end
assert(found and RW_Undo(n).world==s.world)
-- BROKEN acquired at the code barrier silences Text CRASH in the contact frame.
s=fixture("TEXT",true);s.world.entities[15].text.name="CRASH"
n,plan=move(s);assert(not n.world.infinite_loop and not plan.infinite_loop)
-- Late failure discards the code-status stage along with the triggering push.
s=fixture("TEXT",false)
local failing={};for k,v in pairs(services) do failing[k]=v end
failing.convert=function() return nil,"after_code_failure" end
local rejected,e=RW_PlanTurn(s.world,{type="move",dx=0,dy=1},failing)
assert(not rejected and e.reason=="after_code_failure" and not s.world.entities[10].broken and s.world.entities[12].y==5)
-- Compilation reports a status intent without changing any source record.
s=fixture("TEXT",false);s.world.entities[12].y=6
frame=assert(RW_CompileWorld(s.world,cs));assert(#frame.code_status.changes==3 and not s.world.entities[10].broken)
-- The subset planner leaves unselected statuses unchanged and validates input.
local selected=assert(RW_PlanBrokenStatus(s.world,function() return true end,{[10]=true}))
assert(#selected.changes==1 and selected.changes[1].entity_id==10)
local bad,why=RW_PlanRuleStatus(s.world,{}, {[999]=true});assert(not bad and why=="invalid_broken_status_selection")
print("PASS: code-scope BROKEN plans, Text-before-conversion disable/release via SHIFT, ordinary-unit latching, WORD candidates, pure compile and whole-turn Undo")
