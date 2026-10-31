local function recursive_frame(archetype)
    local rules={}
    local function effect(trait) return {op="grant_trait",target={kind="archetype",value=archetype},trait=trait} end
    for i=0,82 do
        rules[#rules+1]={when={op="spatial",clauses={{relation="feeling",negated=false,parameters={{tag="property",name="limit_"..(i+1)}}}}},
            effects={effect(i==0 and "broken" or "limit_"..i)}}
    end
    rules[#rules+1]={when={op="always"},effects={effect("limit_83")}}
    return rules
end
local function product(name,x) return {kind="object",class="object",archetype=name,x=x or 2,y=3,direction="Left"} end
local s=RW_CreateSession();s.world.entities={};s.world.next_entity_id=20
local specs={product("flag",1),product("rock",2),product("flag",3)}
local raw=recursive_frame("rock")
local result,why,prefix=RW_InitializeBirthSpecifications(s.world,specs,raw)
assert(not result and why=="word_rule_limit" and #prefix==2 and prefix[2].archetype=="rock")
assert(not prefix[2].broken and not specs[1].id and s.world.next_entity_id==20 and not next(s.world.entities))
local creation_services={initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate}
local p=assert(RW_PlanInitializedCreation(s.world,specs,raw,creation_services))
assert(p.infinite_loop and #p.changes==2 and p.id_allocation.to==22)
local n,r=RW_Commit(s,p);assert(r.accepted and n.world.infinite_loop and n.world.entities[21].archetype=="rock" and not n.world.entities[22])
assert(RW_Undo(n).world==s.world)
-- Non-limit status failures never turn into terminal commits or partial products.
local invalid={initialize=function() return nil,"invalid_condition",{specs[1]} end,create=RW_PlanCreate}
local bad,e=RW_PlanInitializedCreation(s.world,specs,raw,invalid);assert(not bad and e=="invalid_condition")
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
for _,phase in ipairs({"more","make"}) do
    s=RW_CreateSession();local w=s.world;w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=5,y=3,direction="Right"}}
    w.next_entity_id=20
    w.rule_sources[#w.rule_sources+1]={when={op="always"},effects={{op="grant_trait",target={kind="archetype",value="avatar"},trait="more"}}}
    local raw=recursive_frame("rock")
    local stopped=false
    local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,
        evaluate=function(world)
            assert(not stopped,"terminal birth was recompiled")
            local f=assert(RW_CompileWorld(world,cs))
            local relations=phase=="make" and {{op="make",source_type="avatar",target_type="rock"}} or {}
            return f.effects,nil,relations,raw
        end}
    local function create(world)
        local p=assert(RW_PlanInitializedCreation(world,specs,raw,creation_services));stopped=true
        p.random_state={from=world.random_state or 1,to=12345};return p
    end
    if phase=="more" then services.more=create else
        -- The native MAKE slot requires frozen contact services; no contact deaths.
        services.make=create;services.refresh=RW_EvaluateRules
        services.contact=function() return {consumes_turn=true,changes={}} end
    end
    local turn,err=RW_PlanTurn(w,{type="wait"},services);assert(turn,err and err.reason)
    assert(turn.infinite_loop and turn.stages[#turn.stages].name==phase)
    n,r=RW_Commit(s,turn);assert(r.accepted and n.world.infinite_loop and n.world.next_entity_id==22 and n.world.random_state==12345)
    assert(n.world.entities[20].archetype=="flag" and n.world.entities[21].archetype=="rock" and not n.world.entities[22])
    local rejected,e=RW_PlanTurn(n.world,{type="wait"},services);assert(not rejected and e.reason=="infinite_loop_undo_only")
    assert(RW_Undo(n).world==w and w.next_entity_id==20)
end
-- TOO COMPLEX uses its own terminal flag when an initializer reports that limit.
local complex={initialize=function() return nil,"rule_complexity_limit",{specs[1]} end,create=RW_PlanCreate}
p=assert(RW_PlanInitializedCreation(s.world,specs,{},complex));assert(p.too_complex and not p.infinite_loop)
print("PASS: real nested FEELING birth status limit, prefix products/allocator purity, MORE/MAKE terminal phases, RNG/input Undo, non-limit rejection and TOO COMPLEX separation")
