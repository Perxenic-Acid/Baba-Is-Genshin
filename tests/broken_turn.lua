local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Left"}}
    w.next_entity_id=10;w.language.properties.BROKEN="broken"
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="None"}
    end end
    return s
end
local s=fixture({{"AVATAR","IS","YOU"},{"AVATAR","IS","BROKEN"}})
local plan,err=RW_PlanTurn(s.world,{type="move",dx=1,dy=0},services);assert(plan,err and err.reason)
assert(plan.stages[1].name=="status_before" and plan.stages[1].plan.changes[1].to==1)
local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
assert(n.world.entities[1].broken==1 and n.world.entities[1].x==2 and n.world.entities[1].direction=="Left")
assert(not s.world.entities[1].broken and s.world.chance_seed~=n.world.chance_seed)
assert(RW_Undo(n).world==s.world)
-- Remove the authored rule without changing the old saved status. The input
-- status phase must release the actor before solving this same movement.
n.world.entities[15].x=7
local move,why=RW_PlanTurn(n.world,{type="move",dx=1,dy=0},services);assert(move,why and why.reason)
local moved,result=RW_Commit(n,move);assert(result.accepted,result.reason)
assert(moved.world.entities[1].broken==0 and moved.world.entities[1].x==3)
assert(RW_Undo(moved).world==n.world and n.world.entities[1].broken==1)
-- Planning is pure and an error after the refresh must discard its whole result.
local failing={};for k,v in pairs(services) do failing[k]=v end
failing.convert=function() return nil,"conversion_failure" end
local rejected,e=RW_PlanTurn(s.world,{type="wait"},failing)
assert(not rejected and e.reason=="conversion_failure" and not s.world.entities[1].broken)
-- A same-frame BROKEN declaration prevents object WORD expansion even before the
-- persistent status barrier. Physical Text remains readable.
s=fixture({{"AVATAR","IS","WORD"},{"AVATAR","IS","BROKEN"}})
local frame=assert(RW_CompileWorld(s.world,cs))
assert(not frame.word_tokens[1] and frame.active_text_ids[10] and not s.world.entities[1].broken)
-- A later terminal trigger commits the already planned status phase too.
s=fixture({{"AVATAR","IS","BROKEN"},{"ROCK","IS","CRASH"}})
s.world.language.nouns.ROCK="rock"
s.world.entities[2]={id=2,kind="object",class="object",archetype="rock",x=8,y=2,direction="None"}
plan=assert(RW_PlanTurn(s.world,{type="wait"},services));assert(plan.infinite_loop)
n,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
assert(n.world.infinite_loop and n.world.entities[1].broken==1 and RW_Undo(n).world==s.world)
-- Terminal lockout happens before status services, including a potential release.
for _,terminal in ipairs({"infinite_loop","too_complex"}) do
    local locked=fixture({});locked.world[terminal]=true;locked.world.entities[1].broken=1
    local guarded={};for k,v in pairs(services) do guarded[k]=v end
    guarded.status=function() error("terminal state attempted status refresh") end
    local p,e=RW_PlanTurn(locked.world,{type="wait"},guarded)
    assert(not p and e.reason==terminal.."_undo_only" and locked.world.entities[1].broken==1)
end
-- Empty status frames should not produce another phase or another compilation.
s=fixture({{"AVATAR","IS","YOU"}})
local count=0;local counted={};for k,v in pairs(services) do counted[k]=v end
counted.evaluate=function(w) count=count+1;return services.evaluate(w) end
plan=assert(RW_PlanTurn(s.world,{type="move",dx=1,dy=0},counted))
assert(plan.stages[1].name=="movement")
local calls=count
count=0;counted.status=nil
assert(RW_PlanTurn(s.world,{type="move",dx=1,dy=0},counted));assert(count==calls,"empty status frame duplicated compilation")
print("PASS: BROKEN before-input atomic status/movement, immediate release, WORD gating, failure purity, input/RNG Undo, terminal lockout and empty-phase compile reuse")
