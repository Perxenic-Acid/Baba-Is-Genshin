local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.entities={}
    for id,o in ipairs({{'avatar',3,3},{'rock',4,3},{'rock',8,3},{'crate',4,3},{'flag',5,4}}) do
        w.entities[id]={id=id,kind='object',class='object',archetype=o[1],x=o[2],y=o[3],direction='Mid'}
    end
    for _,name in ipairs({'rock','crate','avatar','flag'}) do w.language.nouns[name:upper()]=name end
    w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',
        target={kind='archetype',value='avatar'},trait='you'}}}
    w.next_entity_id=10
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=5+row*2,direction='None'}
    end end
    return s
end
local function frame(s)
    local f,e=RW_CompileWorld(s.world,cs);assert(f,e and e.reason)
    return RW_ProjectWorld(s.world,f.effects),f
end
local function step(s)
    local plan,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
    local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n,plan
end
for _,word in ipairs({'IS','HAS','WRITE','ON','NEAR','AND'}) do
    local s=fixture({{'ROCK','WRITE',word}});local n=step(s)
    assert(n.world.entities[2].text.name==word and n.world.entities[3].text.name==word)
end
local s=fixture({{'ROCK','AND','CRATE','IS','SAFE','AND','WORD'}})
local p,f=frame(s);assert(#f.ast==4 and #f.deferred==0)
assert(p.entities[2].behaviors.safe and p.entities[3].behaviors.safe and p.entities[4].behaviors.word)
s=fixture({{'ROCK','AND','NOT','CRATE','IS','WORD'}});p,f=frame(s)
assert(#f.ast==2 and p.entities[2].behaviors.word and not p.entities[4].behaviors.word)
s=fixture({{'ROCK','ON','CRATE','IS','WORD'}});p,f=frame(s)
assert(#f.ast==1 and #f.deferred==0 and p.entities[2].behaviors.word and not p.entities[3].behaviors.word)
s=fixture({{'ROCK','NEAR','FLAG','IS','SAFE'}});p=frame(s)
assert(p.entities[2].behaviors.safe and not p.entities[3].behaviors.safe) -- diagonal witness
s=fixture({{'ROCK','NEAR','ROCK','IS','SAFE'}});p=frame(s)
assert(not p.entities[2].behaviors.safe and not p.entities[3].behaviors.safe) -- self excluded
s=fixture({{'ROCK','NOT','ON','CRATE','IS','SAFE'}});p,f=frame(s)
assert(#f.ast==1 and not p.entities[2].behaviors.safe and p.entities[3].behaviors.safe)
s=fixture({{'ROCK','ON','NOT','ROCK','IS','SAFE'}});p=frame(s)
assert(p.entities[2].behaviors.safe and not p.entities[3].behaviors.safe)
s=fixture({{'ROCK','ON','CRATE','AND','CRATE','IS','WORD'}});p=frame(s)
assert(not p.entities[2].behaviors.word)
s.world.entities[6]={id=6,kind='object',class='object',archetype='crate',x=4,y=3,direction='None'}
p=frame(s);assert(p.entities[2].behaviors.word)
s=fixture({{'ROCK','ON','CRATE','NEAR','FLAG','IS','SAFE'}});p,f=frame(s)
assert(#f.ast==1 and p.entities[2].behaviors.safe and not p.entities[3].behaviors.safe)
s=fixture({{'ROCK','AND','CRATE','ON','CRATE','IS','WORD'}});p,f=frame(s)
assert(#f.ast==2 and p.entities[2].behaviors.word and not p.entities[4].behaviors.word)
-- Context gates per-source conversions, protections, denials and explicit Text outputs.
s=fixture({{'ROCK','ON','CRATE','WRITE','AND'}});local n=step(s)
assert(n.world.entities[2].text.name=='AND' and n.world.entities[3].archetype=='rock')
s=fixture({{'ROCK','IS','FLAG'},{'ROCK','ON','CRATE','IS','ROCK'}});n=step(s)
assert(n.world.entities[2].archetype=='rock' and n.world.entities[3].archetype=='flag')
s=fixture({{'ROCK','IS','FLAG'},{'ROCK','ON','CRATE','IS','NOT','FLAG'}});n=step(s)
assert(n.world.entities[2].archetype=='rock' and n.world.entities[3].archetype=='flag')
s=fixture({{'ROCK','WRITE','FLAG'},{'ROCK','ON','CRATE','WRITE','NOT','FLAG'}});n=step(s)
assert(n.world.entities[2].archetype=='rock' and n.world.entities[3].text.name=='FLAG')
-- HAS tests the frozen declaration again at victim identity/position.
s=fixture({{'ROCK','ON','CRATE','HAS','FLAG'},{'ROCK','IS','SINK'}})
local frontier=s.world.next_entity_id;n=step(s)
assert(n.world.entities[frontier].archetype=='flag' and not n.world.entities[2])
s=fixture({{'ROCK','HAS','FLAG'},{'ROCK','ON','CRATE','HAS','NOT','FLAG'},{'ROCK','IS','SINK'}})
frontier=s.world.next_entity_id;n=step(s);assert(n.world.next_entity_id==frontier)
-- Empty conditions are coordinate-local, not global properties of every vacant cell.
s=fixture({{'EMPTY','NEAR','FLAG','IS','STOP'}});p=frame(s)
assert(p.empty_cells['6:4'].behaviors.block_entry and not p.empty_cells['1:1'])
assert(not p.empty_behaviors.block_entry)
print('PASS: WRITE syntax words; subject/RHS AND; per-identity ON/NEAR/NOT/parameters, conditional WORD/conversion/HAS and Undo')

-- Physical conjunction alternatives multiply complete sentences, not just the last term.
s=fixture({{'ROCK','AND','CRATE','IS','SAFE','AND','WORD'}})
s.world.entities[100]={id=100,kind='object',class='text',text={name='AND'},x=2,y=7,direction='None'}
s.world.next_entity_id=101;p,f=frame(s);assert(#f.ast==8)
s=fixture({{'ROCK','ON','NOT','ROCK','AND','CRATE','IS','SAFE'}})
p=frame(s);assert(not p.entities[2].behaviors.safe) -- one Crate cannot fill both parameters
s=fixture({{'ROCK','ON','ALL','IS','WORD'}})
s.world.language.nouns={ROCK='rock',CRATE='crate',AVATAR='avatar',FLAG='flag'}
s.world.entities[1].x=4
s.world.entities[5].x,s.world.entities[5].y=4,3
s.world.entities[6]={id=6,kind='object',class='object',archetype='rock',x=4,y=3,direction='None'}
p=frame(s);assert(p.entities[2].behaviors.word and not p.entities[3].behaviors.word)
s=fixture({{'ROCK','NEAR','NOT','ALL','IS','SAFE'}})
s.world.entities[6]={id=6,kind='object',class='text',text={name='IS'},x=5,y=3,direction='None'}
p=frame(s);assert(p.entities[2].behaviors.safe and not p.entities[3].behaviors.safe)
s=fixture({{'ROCK','IS','SAFE'},{'ROCK','ON','CRATE','IS','NOT','SAFE'}})
p=frame(s);assert(not p.entities[2].behaviors.safe and p.entities[3].behaviors.safe)
s=fixture({{'LEVEL','ON','ROCK','IS','SAFE'}})
s.world.language.nouns.LEVEL={tag='level',block_type='level_block'}
p,f=frame(s);assert(#f.deferred==1 and #f.relations==0)
print('PASS: complete subject-AND path multiplicity, ALL/NOT ALL parameters, conditional denials and explicit scoped-LEVEL boundary')

s=fixture({{'ROCK','ON','NOT','EMPTY','IS','SAFE'}});p=frame(s)
assert(p.entities[2].behaviors.safe)
s.world.entities[5].x,s.world.entities[5].y=4,3
p=frame(s);assert(not p.entities[2].behaviors.safe) -- original counts both remaining occupants
print('PASS: original ON NOT EMPTY co-occupant counting')
