-- HOT/MELT uses the production compiler and scheduled, frozen-rule contact phases.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.entities={
        [1]={id=1,kind='object',class='object',archetype='avatar',x=2,y=2,direction='Left'},
        [2]={id=2,kind='object',class='object',archetype='rock',x=3,y=2,direction='Down'},
        [3]={id=3,kind='object',class='object',archetype='rock',x=7,y=2,direction='None'}}
    w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
    w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',
        target={kind='archetype',value='avatar'},trait='you'}}}
    w.next_entity_id=10
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=4+row*2,direction='None'}
    end end
    return s
end
local function step(s)
    local plan,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
    local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world)
    assert(#n.history==#s.history+1);return n,plan
end
local function float_rows(a,b,rows)
 local all={};for _,r in ipairs(rows) do all[#all+1]=r end
 if a then all[#all+1]={'AVATAR','IS','FLOAT'} end
 if b then all[#all+1]={'ROCK','IS','FLOAT'} end
 return all
end
-- Every contact phase shares the same layer equality, not a global FLOAT toggle.
for _,a in ipairs({false,true}) do for _,b in ipairs({false,true}) do
 for _,case in ipairs({{'SINK','sink'},{'WEAK','weak'},{'HOT','melt'},{'DEFEAT','defeat'},{'SHUT','unlock'}}) do
  local rows={{'ROCK','IS',case[1]}}
  if case[1]=='HOT' then rows[#rows+1]={'AVATAR','IS','MELT'} end
  if case[1]=='SHUT' then rows[#rows+1]={'AVATAR','IS','OPEN'} end
  local s=fixture(float_rows(a,b,rows));local n=step(s)
  if case[1]=='WEAK' then assert((n.world.entities[2]==nil)==(a==b))
  else assert((n.world.entities[1]==nil)==(a==b)) end
  assert(n.world.entities[3]) -- remote hazard doesn't contact
 end
end end
-- STOP and PUSH act across layers.
for _,a in ipairs({false,true}) do for _,b in ipairs({false,true}) do
 local s=fixture(float_rows(a,b,{{'ROCK','IS','STOP'}}));local n=step(s)
 assert(n.world.entities[1].x==2 and n.world.entities[2].x==3)
 s=fixture(float_rows(a,b,{{'ROCK','IS','PUSH'}}));n=step(s)
 assert(n.world.entities[1].x==3 and n.world.entities[2].x==4)
 -- WEAK STOP bypasses solidity only on the same layer.
 s=fixture(float_rows(a,b,{{'ROCK','IS','WEAK','AND','STOP'}}));n=step(s)
 assert(n.world.entities[1].x==(a==b and 3 or 2))
 assert((n.world.entities[2]==nil)==(a==b))
end end
-- Cross-layer OPEN cannot bypass SHUT STOP/PUSH, nor generate HAS.
local s=fixture({{'AVATAR','IS','OPEN','AND','FLOAT'},{'ROCK','IS','SHUT','AND','STOP'},{'ROCK','HAS','CRATE'}})
local f=s.world.next_entity_id;local n=step(s)
assert(n.world.entities[1].x==2 and n.world.entities[2] and n.world.next_entity_id==f)
s=fixture({{'AVATAR','IS','OPEN','AND','FLOAT'},{'ROCK','IS','SHUT','AND','PUSH'}});n=step(s)
assert(n.world.entities[1].x==3 and n.world.entities[2].x==4)
-- WIN requires same-layer overlap, but self WIN still works.
for _,a in ipairs({false,true}) do for _,b in ipairs({false,true}) do
 s=fixture(float_rows(a,b,{{'ROCK','IS','WIN'}}));n=step(s)
 local frame=assert(RW_CompileWorld(n.world,cs));local w=assert(RW_ProjectWorld(n.world,frame.effects))
 assert(RW_HasWinContact(w)==(a==b))
end end
s=fixture({{'AVATAR','IS','WIN','AND','FLOAT'}});n=step(s)
local frame=assert(RW_CompileWorld(n.world,cs));assert(RW_HasWinContact(assert(RW_ProjectWorld(n.world,frame.effects))))
-- ON ignores height. Conditional FLOAT lifts only the object on its witness.
s=fixture({{'ROCK','ON','AVATAR','IS','FLOAT'},{'ROCK','IS','DEFEAT'}});n=step(s)
assert(n.world.entities[1] and n.world.entities[2])
frame=assert(RW_CompileWorld(n.world,cs));local w=assert(RW_ProjectWorld(n.world,frame.effects))
assert(w.entities[2].behaviors.float and not w.entities[3].behaviors.float)
s=fixture({{'AVATAR','IS','FLOAT'},{'AVATAR','IS','NOT','FLOAT'},{'ROCK','IS','DEFEAT'}});n=step(s)
assert(not n.world.entities[1])
-- HAS products derive their own FLOAT: they do not inherit the victim's layer.
s=fixture({{'AVATAR','IS','FLOAT'},{'ROCK','IS','SINK','AND','FLOAT'},{'AVATAR','HAS','CRATE'},{'CRATE','IS','FLOAT'}})
f=s.world.next_entity_id;n=step(s);frame=assert(RW_CompileWorld(n.world,cs));w=assert(RW_ProjectWorld(n.world,frame.effects))
assert(w.entities[f].behaviors.float and w.entities[f].direction=='Right')
s=fixture({{'ROCK','WRITE','FLOAT'}});n=step(s);assert(n.world.entities[2].text.name=='FLOAT')
print('PASS: FLOAT contact matrix, cross-layer STOP/PUSH, WEAK STOP, OPEN/SHUT, WIN, conditional/NOT FLOAT, HAS and Undo')

-- Floating Text remains readable; spatial predicates remain geometric.
s=fixture({{'TEXT','IS','FLOAT'},{'ROCK','IS','DEFEAT'}})
n=step(s);assert(not n.world.entities[1])
frame=assert(RW_CompileWorld(s.world,cs));w=assert(RW_ProjectWorld(s.world,frame.effects))
for _,entity in pairs(w.entities) do if entity.class=='text' then assert(entity.behaviors.float) end end
-- Layer isolation is symmetric for OPEN/SHUT; SAFE does not bridge it.
s=fixture({{'AVATAR','IS','SHUT','AND','FLOAT'},{'ROCK','IS','OPEN','AND','SAFE'}})
n=step(s);assert(n.world.entities[1] and n.world.entities[2])
print('PASS: floating Text reading and symmetric OPEN/SHUT layer isolation')
