local directions={"Right","Up","Left","Down"}
local function fixture(seed,traits)
    local w=RW_CreateSession().world;w.width=20;w.height=20;w.random_state=seed
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=10,y=10,direction="Up"}}
    w.entities[1].behaviors=traits or {chill=true};w.trait_counts={[1]={chill=1}};return w
end
local function raw(w)
 local r={};for k,v in pairs(w) do r[k]=v end;r.trait_counts=nil;r.entities={}
 for id,e in pairs(w.entities) do local copy={};for k,v in pairs(e) do if k~="behaviors" then copy[k]=v end end;r.entities[id]=copy end
 return r
end
local function preview(w,p) return RW_PreviewPlan(raw(w),p) end
local function check(seed,traits)
    local w=fixture(seed,traits);local a=RW_ResolveAutomatic(w);local b=RW_ResolveAutomatic(w)
    assert(w.random_state==seed and w.entities[1].direction=="Up")
    assert(a.random_state.to==b.random_state.to)
    local out=assert(preview(w,a));local d=directions[a.random_state.to%4+1]
    assert(out.entities[1].direction==d)
    local v=({Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}})[d]
    assert(out.entities[1].x==10+v[1] and out.entities[1].y==10+v[2])
    local s=RW_CreateSession();s.world=raw(w);local n,r=RW_Commit(s,a);assert(r.accepted,r.reason)
    assert(RW_Undo(n).world==s.world)
    local stale=fixture(seed+1);assert(not preview(stale,a))
end
for seed=1,64 do check(seed) end
local w=fixture(1,{chill=true,sleep=true});local p=RW_ResolveAutomatic(w)
assert(not p.random_state and #p.changes==0,"sleep consumed random draw")
w=fixture(1,{chill=true,still=true});p=RW_ResolveAutomatic(w)
local out=assert(preview(w,p));assert(p.random_state and out.entities[1].x==10 and out.entities[1].y==10)
assert(out.entities[1].direction=="Down","STILL must retain random facing")
w=fixture(1);w.trait_counts[1].chill=2;p=RW_ResolveAutomatic(w);out=assert(preview(w,p))
assert(p.random_state.to==182605794 and out.entities[1].x==8,"duplicate CHILL shares final facing")
w=fixture(1);w.trait_counts[1].move=1;p=RW_ResolveAutomatic(w);out=assert(preview(w,p))
assert(out.entities[1].y==12,"MOVE + CHILL must share the random facing")
w=fixture(1);w.entities[2]={id=2,kind="object",class="object",archetype="rock",x=10,y=11,direction="Left"}
w.entities[2].behaviors={block_entry=true};p=RW_ResolveAutomatic(w);out=assert(preview(w,p))
assert(out.entities[1].y==9 and out.entities[1].direction=="Up","blocked CHILL must reverse")
-- Run installed collection code unchanged, adapting only host queries and RNG.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],"rb"))
local code=f:read("*a");f:close();local first=assert(code:find("function add_moving_units(",1,true))
local last=code:find("\nfunction ",first+1,true);code=code:sub(first,last and last-1 or #code)
local cases=0
for seed=1,32 do for grants=1,3 do for sleep=0,1 do for still=0,1 do
    local state=seed;local unit={values={dir=1,x=10,y=10}};local draws=0
    local env={ipairs=ipairs,pairs=pairs,table=table,DIR="dir",XPOS="x",YPOS="y",
        mmf={newObject=function() return unit end},getname=function() return "avatar" end,
        hasfeature=function() return sleep==1 and true or nil end,
        cantmove=function() return still==1 end,updatedir=function(_,d) unit.values.dir=d end,
        fixedrandom=function() state=state*48271%2147483647;draws=draws+1;return state%4 end}
    assert(load(code,"installed add_moving_units","t",env))()
    local ids={};for i=1,grants do ids[i]=1 end
    local list=env.add_moving_units("chill",ids,{}, {},{})
    local world=fixture(seed,{chill=true,sleep=sleep==1,still=still==1});world.trait_counts[1].chill=grants
    local plan=RW_ResolveAutomatic(world);local result=assert(preview(world,plan))
    assert((plan.random_state and plan.random_state.to or seed)==state)
    assert(result.entities[1].direction==directions[unit.values.dir+1])
    assert(#list==((sleep==0 and still==0) and 1 or 0))
    if #list>0 then assert(list[1].moves==grants) end
    cases=cases+1
end end end end
-- Exercise native scheduler wiring including RNG-only turns and Undo.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,automatic=RW_ResolveAutomatic,
 evaluate=function(world) local frame,e=RW_CompileWorld(world,cs);if not frame then return nil,e.reason end;return frame.effects,nil,frame.relations,frame.rules,frame.code_status end}
local s=RW_CreateSession();s.world.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=5,y=5,direction="Up"}};s.world.next_entity_id=2
assert(s.world.language.properties.CHILL=="chill")
for row,words in ipairs({{"AVATAR","IS","CHILL"},{"AVATAR","IS","STILL"}}) do for x,word in ipairs(words) do
 local id=s.world.next_entity_id;s.world.next_entity_id=id+1;s.world.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row,direction="None"}
end end
local plan,e=RW_PlanTurn(s.world,{type="wait"},services);assert(plan,e and e.reason)
local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(n.world.random_state==48271 and n.world.entities[1].y==5)
assert(RW_Undo(n).world==s.world)
print("CHILL: deterministic motion/rollback and "..cases.." installed collection oracle cases passed")
