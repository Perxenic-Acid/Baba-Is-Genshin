-- Run the installed original brokenblock, not a transcription of its loop.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],"rb"))
local source=file:read("*a");file:close()
local first=assert(source:find("function brokenblock(ids)",1,true))
local last=assert(source:find("function statusblock(",first,true))
local cases=0
for subset=0,1 do
for mask=0,255 do
    local function bit(n) return math.floor(mask/2^n)%2==1 end
    local session=RW_CreateSession();local world=session.world
    world.entities={};world.next_entity_id=5
    local units={}
    for id=1,4 do
        local old=bit(id-1) and 1 or 0
        world.entities[id]={id=id,kind="object",class=id==4 and "text" or "object",
            archetype=id~=4 and "rock" or nil,text=id==4 and {name="ROCK"} or nil,
            x=id,y=2,direction="Left",broken=old}
        units[id]={fixed=id,broken=old,values={id},strings={id==4 and "text_rock" or "rock"}}
    end
    local env=setmetatable({units=units,UNITNAME=1,ID=1},{__index=_G})
    env.hasfeature=function(_,_,_,id)
        assert(units[id].broken==0,"own status must be temporarily cleared")
        local previous=units[id==1 and 4 or id-1].broken
        return (bit(id+3)~= (previous==1)) and true or nil
    end
    local undo={}
    env.addundo=function(event) undo[#undo+1]=event end
    assert(load(source:sub(first,last-1),"@installed_brokenblock","t",env))()
    env.brokenblock(subset==1 and {units[2],units[4]} or nil)
    local plan=assert(RW_PlanBrokenStatus(world,function(context,entity)
        assert(entity.broken==0)
        local previous=context.entities[entity.id==1 and 4 or entity.id-1].broken
        return bit(entity.id+3)~=(previous==1)
    end,subset==1 and {[2]=true,[4]=true} or nil))
    assert(#plan.changes==#undo,"count mismatch "..mask..":"..#plan.changes..":"..#undo)
    local completed,result=RW_Commit(session,plan);assert(result.accepted,result.reason)
    for id=1,4 do
        assert(completed.world.entities[id].broken==units[id].broken,"BROKEN ordered status mismatch "..mask..":"..id)
        assert(world.entities[id].broken==(bit(id-1) and 1 or 0),"planner changed source")
    end
    if #plan.changes>0 then assert(RW_Undo(completed).world==world) end
    cases=cases+1
end
end
local s=RW_CreateSession();s.world.entities[1].broken=nil
local plan=assert(RW_PlanBrokenStatus(s.world,function(_,entity) return entity.id==1 end))
assert(plan.changes[1].entity_id==1 and plan.changes[1].from==nil and plan.changes[1].to==1)
local preview=assert(RW_PreviewPlan(s.world,plan));assert(preview.entities[1].broken==1 and not s.world.entities[1].broken)
local bad={consumes_turn=true,changes={{kind="broken",entity_id=1,from=0,to=1}}}
local rejected,result=RW_Commit(s,bad);assert(not result.accepted and result.reason=="stale_broken" and rejected==s)
bad={consumes_turn=true,changes={{kind="broken",entity_id=1,to=2}}}
rejected,result=RW_Commit(s,bad);assert(not result.accepted and result.reason=="invalid_broken" and rejected==s)
local stages={consumes_turn=true,changes={},stages={{name="status",plan=plan},
    {name="invalid_late_status",plan={consumes_turn=true,changes={{kind="broken",entity_id=1,from=0,to=1}}}}}}
for _,stage in ipairs(stages.stages) do for _,change in ipairs(stage.plan.changes) do stages.changes[#stages.changes+1]=change end end
rejected,result=RW_Commit(s,stages);assert(not result.accepted and rejected==s and not s.world.entities[1].broken)
local failed,err=RW_PlanBrokenStatus(s.world,function() return nil,"query_failure" end)
assert(not failed and err=="query_failure" and not s.world.entities[1].broken)
print("PASS: installed BROKEN ordered status loop ("..cases.." cases), own-status bypass, pure planning, stale checks, atomic rejection and Undo")
