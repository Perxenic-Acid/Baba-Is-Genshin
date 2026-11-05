-- EAT uses the production compiler and frozen destruction/HAS transaction.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={eat=function(w,p,r,c)
    return RW_PlanDestructionPhase(w,RW_ResolveEatVictims(p,RW_ResolveVerbTargets(w,r,"eat")),c,"eat",
        {births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete})
end,make=function(w,r,c)
    local products,rng=RW_PlanMakeProducts(w,r,c)
    local p,e=RW_PlanCreate(w,products);if not p then return nil,e end;p.random_state=rng;return p
end,follow=function(w,r) return RW_ResolveFollow(w,RW_ResolveVerbTargets(w,r,"follow")) end,fear=function(w,r) return RW_ResolveFear(w,RW_ResolveFearTargets(w,r)) end,fall=RW_ResolveFall,automatic=RW_ResolveAutomatic,orient=RW_ResolveOrientation,more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end,shift=RW_ResolveShift,destroy=function(w,ids,c,k,deaths) return RW_PlanDestructionPhase(w,ids,c,k,{births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},deaths) end,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
    convert=RW_PlanConversions,refresh=RW_EvaluateRules,
    contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,
        births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end
        return f.effects,nil,f.relations,f.rules end}

local function fixture(rows)
    local s=RW_CreateSession();local w=s.world
    w.width,w.height=24,24;w.entities={};w.next_entity_id=10
    w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
    w.entities[1]={id=1,kind='object',class='object',archetype='avatar',x=2,y=2,direction='Right'}
    w.entities[2]={id=2,kind='object',class='object',archetype='rock',x=6,y=3,direction='Right'}
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row,direction='None'}
    end end
    return s
end
local function step(s,action)
    local p,e=RW_PlanTurn(s.world,action or {type='wait'},services);assert(p,e and e.reason)
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
    assert(RW_Undo(n).world==s.world and #n.history==#s.history+1)
    return n,p
end

local function object(w,id,name,x,y,dir)
    w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=y,direction=dir or 'Left'}
end





local s=fixture({{'ROCK','MIMIC','AVATAR'},{'AVATAR','IS','YOU'}})
local frame=assert(RW_CompileWorld(s.world,cs));assert(#frame.deferred==0)
local n=step(s,{type='move',dx=1,dy=0});assert(n.world.entities[2].x==7)
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','IS','PUSH'},{'AVATAR','MIMIC','ROCK'}})
frame=assert(RW_CompileWorld(s.world,cs))
local function trait(frame,id,name)
    local p=assert(RW_ProjectWorld(s.world,frame.effects));return (p.entities[id].traits or {})[name]
end
assert(trait(frame,2,'pushable'));assert(not trait(frame,1,'pushable'),'no transitive MIMIC')
s=fixture({{'ROCK','MIMIC','FLAG'},{'ROCK','MIMIC','NOT','FLAG'},{'FLAG','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(not trait(frame,2,'pushable'))
s=fixture({{'ROCK','ON','AVATAR','MIMIC','FLAG'},{'FLAG','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(not trait(frame,2,'pushable'))
s.world.entities[1].x=6;s.world.entities[1].y=3
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,2,'pushable'))
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','ON','AVATAR','IS','PUSH'}})
s.world.entities[1].x=6;s.world.entities[1].y=3
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,2,'pushable'),'copied condition evaluated at imitator')
s=fixture({{'ROCK','MIMIC','FLAG'},{'ROCK','ON','AVATAR','MIMIC','NOT','FLAG'},{'FLAG','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,2,'pushable'))
s.world.entities[1].x=6;s.world.entities[1].y=3
frame=assert(RW_CompileWorld(s.world,cs));assert(not trait(frame,2,'pushable'))
s=fixture({{'ROCK','MIMIC','FLAG'},{'ROCK','MIMIC','FLAG'},{'FLAG','BECOME','CRATE'}})
n=step(s);local count=0;for _,e in pairs(n.world.entities) do if e.archetype=='crate' then count=count+1 end end
assert(count==2,'duplicate copied conversions')
s=fixture({{'ROCK','MIMIC','ROCK'},{'ROCK','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,2,'pushable'))
s=fixture({{'TEXT','MIMIC','ROCK'},{'ROCK','IS','SAFE'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(trait(frame,10,'safe'))
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','IS','NOT','PUSH'},{'ROCK','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(not trait(frame,2,'pushable'))
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','HAS','CRATE'},{'ROCK','IS','YOU','AND','DEFEAT'}})
n=step(s);assert(not n.world.entities[2]);local born=false
for _,e in pairs(n.world.entities) do if e.archetype=='crate' and e.x==6 and e.y==3 then born=true end end
assert(born,'copied HAS participates in frozen contact destruction')
s=fixture({{'ALL','HAS','FLAG'},{'ROCK','MIMIC','CRATE'},{'ROCK','IS','YOU','AND','DEFEAT'}})
n=step(s);local all_births=0
for _,unit in pairs(n.world.entities) do if unit.archetype=='flag' and unit.x==6 and unit.y==3 then all_births=all_births+1 end end
assert(all_births==2,'ALL must supply the original HAS and the pre-MIMIC CRATE declaration exactly once')
s=fixture({{'ALL','IS','SAFE'},{'ROCK','MIMIC','CRATE'}})
frame=assert(RW_CompileWorld(s.world,cs))
assert(RW_ProjectWorld(s.world,frame.effects).trait_counts[2].safe==2)
s=fixture({{'ROCK','IS','GROUP'},{'ALL','HAS','GROUP'},{'ROCK','MIMIC','CRATE'},
 {'ROCK','IS','YOU','AND','DEFEAT'}})
n=step(s);local group_births=0
for id,unit in pairs(n.world.entities) do if id~=2 and unit.archetype=='rock' and unit.x==6 and unit.y==3 then group_births=group_births+1 end end
assert(group_births==2,'ALL HAS GROUP is a consumer, not already-normalized ALL IS GROUP membership')
print('PASS: ALL declarations expand before MIMIC without duplicating original runtime HAS/property grants, with Undo')
do
 local noun=function(name) return {tag='noun',type={tag='object',name=name}} end
 local lookup={{verb='mimic',subject=noun('rock'),object=noun('crate'),when={op='always'}},
  {verb='is',subject={tag='special',name='all'},object={tag='property',name='safe'},when={op='always'}}}
 local row={verb='is',subject=noun('flag'),object={tag='property',name='pushable'},when={op='always'}}
 for i=1,4998-#RW_NounPalette(s.world) do lookup[#lookup+1]=row end
 assert(RW_LowerRuleAST(lookup,nil,s.world),'exact 5000-entry copy lookup must remain valid')
 lookup[#lookup+1]=row
 local generated,reason=RW_LowerRuleAST(lookup,nil,s.world)
 assert(not generated and reason=='rule_complexity_limit','trailing original entry escaped copy lookup bound')
end
-- Virtual endpoints share the raw one-generation pass, not a persisted unit.
for _,case in ipairs({
 {{'NOT','ROCK','HAS','FLAG'},'CRATE',1},
 {{'NOT','ALL','HAS','FLAG'},'EMPTY',1},
 {{'NOT','ALL','HAS','FLAG'},'TEXT',1},
 {{'NOT','ALL','HAS','GROUP'},'EMPTY',1},
 {{'NOT','ROCK','HAS','GROUP'},'CRATE',0}
}) do
 s=fixture({case[1],{'ROCK','MIMIC',case[2]},{'FLAG','IS','GROUP'},
  {'ROCK','IS','YOU','AND','DEFEAT'}})
 n=step(s);local births=0
 for _,unit in pairs(n.world.entities) do if unit.archetype=='flag' and unit.x==6 and unit.y==3 then births=births+1 end end
 assert(births==case[3],'NOT declaration expansion order or GROUP exception mismatch')
end
print('PASS: NOT noun/NOT ALL declarations feed MIMIC before copying, EMPTY/Text targets, GROUP exceptions, HAS and Undo')
for _,excluded in ipairs({'ROCK','CRATE'}) do
 s=fixture({{'NOT',excluded,'MIMIC','FLAG'},{'FLAG','IS','YOU'}})
 n=step(s,{type='move',dx=1,dy=0})
 assert(n.world.entities[1].x==3 and n.world.entities[2].x==(excluded=='ROCK' and 6 or 7))
end
s=fixture({{'NOT','CRATE','MIMIC','FLAG'},{'NOT','CRATE','MIMIC','NOT','FLAG'},{'FLAG','IS','YOU'}})
frame=assert(RW_CompileWorld(s.world,cs));local disabled=assert(RW_ProjectWorld(s.world,frame.effects))
assert(not disabled.entities[1].behaviors.control and not disabled.entities[2].behaviors.control)
for _,target in ipairs({'FLAG','GROUP'}) do
 s=fixture({{'NOT','ALL','MIMIC',target},{target,'IS','SAFE'}})
 frame=assert(RW_CompileWorld(s.world,cs));local p=assert(RW_ProjectWorld(s.world,frame.effects))
 assert(p.empty_cells['12:3'].behaviors.safe and p.entities[10].behaviors.safe)
 assert(not p.entities[1].behaviors.safe and not p.entities[2].behaviors.safe)
end
print('PASS: NOT noun MIMIC control/exclusions/bans and Undo; NOT ALL MIMIC copies only EMPTY/Text, including GROUP endpoints')
for _,ban in ipairs({false,true}) do for _,direct in ipairs({false,true}) do
 local rows={{'ROCK','MIMIC','ALL'},{'FLAG','IS','SAFE'}}
 if ban then rows[#rows+1]={'ROCK','MIMIC','NOT','ALL'} end
 if direct then rows[#rows+1]={'ROCK','MIMIC','FLAG'} end
 s=fixture(rows);frame=assert(RW_CompileWorld(s.world,cs))
 local p=assert(RW_ProjectWorld(s.world,frame.effects))
 assert((p.entities[2].behaviors.safe==true)==(not ban or direct),'NOT ALL must not ban a separate explicit MIMIC target')
end end
s=fixture({{'ROCK','MIMIC','ALL'},{'LONELY','ROCK','MIMIC','NOT','ALL'},{'FLAG','IS','SAFE'}})
frame=assert(RW_CompileWorld(s.world,cs));assert(not RW_ProjectWorld(s.world,frame.effects).entities[2].behaviors.safe)
s.world.entities[1].x=6;s.world.entities[1].y=3
frame=assert(RW_CompileWorld(s.world,cs));assert(RW_ProjectWorld(s.world,frame.effects).entities[2].behaviors.safe)
s=fixture({{'ALL','HAS','FLAG'},{'ROCK','MIMIC','ALL'},{'ROCK','IS','YOU','AND','DEFEAT'}})
n=step(s);local all_copies=0
for _,unit in pairs(n.world.entities) do if unit.archetype=='flag' and unit.x==6 and unit.y==3 then all_copies=all_copies+1 end end
assert(all_copies==#RW_NounPalette(s.world)+2,'MIMIC ALL must retain the literal ALL declaration plus ordinary target copies and the base HAS')
s=fixture({{'ALL','HAS','FLAG'},{'NOT','ROCK','MIMIC','ALL'},{'AVATAR','IS','YOU','AND','DEFEAT'}})
n=step(s);local negative_copies=0
for _,unit in pairs(n.world.entities) do
 if unit.archetype=='flag' and unit.x==2 and unit.y==2 then negative_copies=negative_copies+1 end
end
assert(negative_copies==2*#RW_NounPalette(s.world)+2,'NOT-source MIMIC ALL must keep both native expansion paths')
print('PASS: MIMIC ALL targets, raw ALL declarations/duplicates, conditional NOT ALL, independent explicit targets and HAS Undo')
for _,case in ipairs({
 {subject={'CRATE'},target='CRATE',factor=1},
 {subject={'ALL'},target='CRATE',factor=4},
 {subject={'NOT','ROCK'},target='CRATE',factor=2},
 {subject={'NOT','ALL'},target='TEXT',factor=2},
}) do
 local row={};for _,word in ipairs(case.subject) do row[#row+1]=word end
 row[#row+1]='HAS';row[#row+1]='ALL'
 s=fixture({row,{'ROCK','MIMIC',case.target},{'ROCK','IS','YOU','AND','DEFEAT'}})
 n=step(s);local products={}
 for _,unit in pairs(n.world.entities) do if unit.class=='object' and unit.x==6 and unit.y==3 then
  products[unit.archetype]=(products[unit.archetype] or 0)+1
 end end
 for _,name in ipairs(RW_NounPalette(s.world)) do
  assert(products[name]==case.factor,'pre-MIMIC RHS ALL birth multiplicity: '..name)
 end
end
print('PASS: copied RHS ALL concrete products, two ALL axes, NOT/NOT ALL source paths and atomic HAS Undo')
for _,verb in ipairs({'HAS','MAKE'}) do
 local rows={{'NOT','ROCK',verb,'ALL'}}
 if verb=='HAS' then rows[#rows+1]={'AVATAR','IS','YOU','AND','DEFEAT'} end
 s=fixture(rows);n=step(s)
 local products={}
 for _,unit in pairs(n.world.entities) do if unit.class=='object' and unit.x==2 and unit.y==2 then
  products[unit.archetype]=(products[unit.archetype] or 0)+1
 end end
 for _,name in ipairs(RW_NounPalette(s.world)) do
  local expected=verb=='MAKE' and name=='avatar' and 1 or 2
  assert(products[name]==expected,'base negative-subject '..verb..' ALL multiplicity: '..name)
 end
end
print('PASS: base NOT noun HAS/MAKE ALL preserve both paths without MIMIC, old MAKE blockers and Undo')

s=fixture({{'ALL','HAS','FLAG'},{'CRATE','HAS','ROCK'},{'ROCK','MIMIC','CRATE'},
 {'ROCK','IS','YOU','AND','DEFEAT'}})
n=step(s)
for offset,name in ipairs({'flag','rock','flag'}) do
 assert(n.world.entities[s.world.next_entity_id+offset-1].archetype==name,'ALL derivatives must follow original target declarations in MIMIC lookup')
end
s=fixture({{'EMPTY','MIMIC','FLAG'},{'FLAG','NEAR','ROCK','IS','PUSH'},
 {'EMPTY','NEAR','AVATAR','MIMIC','NOT','FLAG'}})
frame=assert(RW_CompileWorld(s.world,cs))
local projected=assert(RW_ProjectWorld(s.world,frame.effects))
assert(projected.empty_cells['5:3'].behaviors.push and not projected.empty_cells['12:3'])
s.world.entities[1].x=6;s.world.entities[1].y=2
frame=assert(RW_CompileWorld(s.world,cs));projected=assert(RW_ProjectWorld(s.world,frame.effects))
assert(not projected.empty_cells['5:3'] or not projected.empty_cells['5:3'].behaviors.push)
assert(projected.empty_cells['6:4'].behaviors.push)
s=fixture({{'EMPTY','MIMIC','EMPTY'},{'EMPTY','IS','PUSH'}})
frame=assert(RW_CompileWorld(s.world,cs));projected=assert(RW_ProjectWorld(s.world,frame.effects))
assert(projected.empty_cells['12:3'].trait_counts.pushable==2)
s=fixture({{'ROCK','MIMIC','EMPTY'},{'EMPTY','HAS','CRATE'},{'EMPTY','HAS','CRATE'},
 {'ROCK','IS','YOU','AND','DEFEAT'}})
n=step(s);assert(not n.world.entities[2])
local copied_births=0
for _,unit in pairs(n.world.entities) do if unit.archetype=='crate' and unit.x==6 and unit.y==3 then copied_births=copied_births+1 end end
assert(copied_births==2,'EMPTY target duplicates must feed real frozen HAS')
print('PASS: EMPTY MIMIC endpoints, per-vacancy copied/negative conditions, self multiplicity, copied real HAS and Undo')
local ast={{verb='mimic',subject={tag='noun',type={tag='object',name='rock'}},object={tag='noun',type={tag='object',name='flag'}},when={op='always'}}}
for i=1,251 do ast[#ast+1]={verb='is',subject={tag='noun',type={tag='object',name='flag'}},object={tag='property',name='pushable'},when={op='always'}} end
local g,err=RW_LowerRuleAST(ast,nil,s.world);assert(not g and err=='rule_complexity_limit')
table.remove(ast);assert(RW_LowerRuleAST(ast,nil,s.world))
print('PASS: MIMIC one generation, per-identity combined/negative conditions, self/duplicate conversions, limit and Undo')
for _,case in ipairs({{subject={'CRATE'},factor=2},{subject={'NOT','ROCK'},factor=3}}) do
 local row={};for _,word in ipairs(case.subject) do row[#row+1]=word end
 row[#row+1]='BECOME';row[#row+1]='ALL'
 s=fixture({row,{'ROCK','MIMIC','CRATE'}});n=step(s)
 local counts={}
 for _,unit in pairs(n.world.entities) do if unit.class=='object' and unit.x==6 and unit.y==3 then
  counts[unit.archetype]=(counts[unit.archetype] or 0)+1
 end end
 for _,name in ipairs(RW_NounPalette(s.world)) do assert(counts[name]==case.factor,'MIMIC BECOME ALL product count: '..name) end
end
s=fixture({{'CRATE','BECOME','ALL'},{'CRATE','BECOME','NOT','ALL'},{'CRATE','BECOME','FLAG'},{'ROCK','MIMIC','CRATE'}})
n=step(s);assert(n.world.entities[2].archetype=='flag','copied NOT ALL must preserve an explicit BECOME FLAG')
print('PASS: MIMIC BECOME ALL literal/concrete paths, NOT subjects, own NOT ALL, explicit products and Undo')
