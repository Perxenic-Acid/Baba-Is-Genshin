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
local function fixture()
    local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=20
    for id=1,3 do w.entities[id]={id=id,kind="object",class="object",archetype="crate",x=id+2,y=3,direction="Down",
        level_link={target="child",definition_id="child",source_type="crate"}} end
    return s
end
local contents={}
for _,entry in ipairs({{1,"flag"},{2,"flag"},{2,"rock"},{2,"flag"},{3,"flag"}}) do
    contents[#contents+1]={op="has",target={kind="id",value=entry[1]},product={kind="object",archetype=entry[2]}}
end
local raw=recursive_frame("rock")
local contacts={birth_products=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete,
    births=function(w,ids,c,rules)
        local specs,e=RW_PlanHasBirths(w,ids,c);if not specs then return nil,e end
        return RW_InitializeBirthSpecifications(w,specs,rules)
    end}
local function verify(s,p)
    assert(p.infinite_loop)
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
    assert(n.world.infinite_loop and not n.world.entities[1] and n.world.entities[2] and n.world.entities[3],"triggering/later parents removed")
    assert(n.world.next_entity_id==23 and n.world.entities[20].archetype=="flag" and n.world.entities[21].archetype=="flag" and n.world.entities[22].archetype=="rock")
    assert(n.world.entities[22].level_link.definition_id=="child" and n.world.entities[22].direction=="Down")
    assert(not n.world.entities[23] and s.world.entities[1] and s.world.next_entity_id==20)
    assert(RW_Undo(n).world==s.world)
    return n
end
local s=fixture()
local p=assert(RW_PlanDestructionPhase(s.world,{1,2,3},contents,"sink",contacts,nil,raw))
verify(s,p);assert(#p.events==1 and p.events[1].entity_id==1)
local deaths={};for id=1,3 do deaths[#deaths+1]={entity_id=id,frame=s.world.entities,cause="weak"} end
p=assert(RW_PlanDestructionPhase(s.world,{1,2,3},contents,"movement",contacts,deaths,raw))
verify(s,p);assert(#p.events==1)
-- A first-victim failure deletes no parent. Earlier zero-product victims still
-- complete their deletion when the next parent's product triggers the limit.
local first=recursive_frame("flag")
p=assert(RW_PlanDestructionPhase(s.world,{1,2,3},contents,"sink",contacts,nil,first))
local first_board,r=RW_Commit(s,p);assert(r.accepted and first_board.world.infinite_loop)
assert(first_board.world.entities[1] and first_board.world.entities[2] and first_board.world.entities[3] and #p.events==0)
assert(first_board.world.next_entity_id==21 and first_board.world.entities[20].archetype=="flag")
local reduced={};for i=2,#contents do reduced[#reduced+1]=contents[i] end
p=assert(RW_PlanDestructionPhase(s.world,{1,2,3},reduced,"sink",contacts,nil,raw))
local partial,r=RW_Commit(s,p);assert(r.accepted and not partial.world.entities[1] and partial.world.entities[2])
assert(partial.world.next_entity_id==22 and #p.events==1)
local complex={};for k,v in pairs(contacts) do complex[k]=v end
complex.births=function(w,ids,has)
    local specs=assert(RW_PlanHasBirths(w,ids,has));return nil,"rule_complexity_limit",{specs[1],specs[2],specs[3]}
end
p=assert(RW_PlanDestructionPhase(s.world,{1,2,3},contents,"sink",complex,nil,raw))
assert(p.too_complex and not p.infinite_loop)
local locked,r=RW_Commit(s,p);assert(r.accepted and locked.world.too_complex and locked.world.entities[2])
assert(RW_Undo(locked).world==s.world)
-- Every scheduler destruction slot stops immediately after the terminal phase.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
for _,slot in ipairs({"movement","automatic","fear","shift","fall","sink","boom","weak","melt","defeat","unlock","eat"}) do
    s=fixture();local stopped=false
    local c={};for k,v in pairs(contacts) do c[k]=v end
    c.births=function(...)
        local specs,e,prefix=contacts.births(...);if prefix then stopped=true end
        return specs,e,prefix
    end
    local d={};for id=1,3 do d[#d+1]={entity_id=id,frame=s.world.entities,cause="weak"} end
    local function deathplan() return {consumes_turn=true,changes={},destructions=d} end
    local services={project=RW_ProjectWorld,preview=RW_PreviewPlan,resolve=RW_ResolveTurn,convert=RW_PlanConversions,
        refresh=RW_EvaluateRules,
        destroy=function(w,ids,has,kind,deaths,rules) return RW_PlanDestructionPhase(w,ids,has,kind,c,deaths,rules) end,
        contact=function(w,projected,kind,has,rules)
            if kind~=slot then return {consumes_turn=true,changes={}} end
            return RW_PlanDestructionPhase(w,{1,2,3},has,kind,c,nil,rules)
        end,
        evaluate=function(w)
            assert(not stopped,"terminal HAS was compiled again")
            local f=assert(RW_CompileWorld(w,cs));local relations={};for i,v in ipairs(contents) do relations[i]=v end
            if slot=="fear" then relations[#relations+1]={op="fear",source_type="crate",target_type="rock"} end
            if slot=="eat" then relations[#relations+1]={op="eat",source_type="crate",target_type="crate"} end
            if slot=="automatic" or slot=="fall" then f.effects[#f.effects+1]={op="grant_trait",trait=slot=="fall" and "fall" or "move",target={kind="archetype",value="crate"},entity_ids={1}} end
            return f.effects,nil,relations,raw
        end}
    if slot=="movement" then services.resolve=deathplan
    elseif slot=="automatic" or slot=="fear" or slot=="shift" or slot=="fall" then services[slot]=deathplan
    elseif slot=="eat" then services.eat=function(w,projected,relations,has,rules) return RW_PlanDestructionPhase(w,{1,2,3},has,"eat",c,nil,rules) end end
    local turn,e=RW_PlanTurn(s.world,{type="wait"},services);assert(turn,e and (e.stage..":"..e.reason))
    local n=verify(s,turn)
    local final=turn.stages[#turn.stages].name
    assert(final==slot or final==slot.."_destruction",slot..":"..final)
    local rejected,err=RW_PlanTurn(n.world,{type="wait"},services);assert(not rejected and err.reason=="infinite_loop_undo_only")
end
-- A malformed prefix cannot bypass ordinary creation/transaction validation.
s=fixture();local invalid={};for k,v in pairs(contacts) do invalid[k]=v end
invalid.births=function() return nil,"invalid_condition",{{class="object"}} end
local bad,e=RW_PlanDestructionPhase(s.world,{1,2,3},contents,"sink",invalid,nil,raw)
assert(not bad and e=="invalid_condition" and s.world.entities[1])
print("PASS: HAS recursive creation prefix, retained triggering parent/later victims, death frames, links/allocator/events, every destruction slot terminal propagation and Undo")
