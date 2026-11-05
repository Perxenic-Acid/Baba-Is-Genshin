-- Compare vacancy pruning/indexed queries with unindexed per-cell evaluation.
local function noun(name) return {tag='noun',type={tag='object',name=name}} end
local function neg(t) return {tag='not',operand=t} end
for _,relation in ipairs({'on','near','nextto'}) do
 for _,negative in ipairs({false,true}) do
  for _,params in ipairs({{noun('rock')},{noun('rock'),noun('rock')},{noun('rock'),neg(noun('crate'))},{neg(noun('rock'))}}) do
   local w=RW_CreateSession().world;w.width,w.height=12,10;w.rule_sources={}
   w.entities={
    [1]={id=1,class='object',archetype='rock',x=4.0,y=5.0,direction='Right',broken=1},
    [2]={id=2,class='object',archetype='rock',x=4,y=5,direction='Left'},
    [3]={id=3,class='object',archetype='crate',x=5,y=5,direction='Up'},
    [4]={id=4,class='text',archetype='rock',text={name='IS'},x=8,y=8,direction='None'}}
   local when={op='spatial',clauses={{relation=relation,negated=negative,parameters=params}}}
   local rule={when=when,effects={{op='grant_trait',trait='you',target={kind='empty',value='empty'}}}}
   for pass=1,2 do
    local effects=assert(RW_EvaluateRules(w,{rule}));local actual={}
    for _,cell in ipairs(effects[1].cells) do actual[cell.x..':'..cell.y]=true end
    for y=1,w.height do for x=1,w.width do
     local occupied=false;for _,e in pairs(w.entities) do if e.x==x and e.y==y then occupied=true end end
     local expected=not occupied and assert(type(RW_TestEntityCondition(w,when,{class='empty',x=x,y=y}))=='boolean')
     if expected then expected=RW_TestEntityCondition(w,when,{class='empty',x=x,y=y}) end
     assert((actual[x..':'..y] or false)==expected,relation..' vacancy mismatch')
    end end
    assert(w._query_traits==nil and w._query_occupancy==nil,'query indexes leaked to world')
    w.entities[1].x=9;w.entities[2].x=9
   end
  end
 end
end
print('PASS: bounded EMPTY local queries match full scans, duplicate/negative/stacked/BROKEN witnesses and fresh positions')
-- A batch shares its immutable query frame, while conditions still vary by cell.
do
 local w=RW_CreateSession().world;w.width,w.height=12,10;w.rule_sources={}
 w.entities={[1]={id=1,class='object',archetype='rock',x=4,y=5,direction='Right'}}
 local when={op='spatial',clauses={{relation='near',negated=false,parameters={noun('rock')}}}}
 local rules={{when=when,effects={{op='grant_trait',trait='broken',target={kind='empty',value='empty'}}}}}
 local relation={op='eat',source_type='@empty',target_type='rock',condition_rules=rules,
  when={op='spatial',clauses={{relation='nextto',negated=true,parameters={noun('rock')}}}}}
 for pass=1,2 do
  local actual=assert(RW_ResolveMovementEatTargets(w,{relation,relation})).empty_cells
  for y=1,w.height do for x=1,w.width do
   local expected=RW_RelationApplies(w,relation,{class='empty',x=x,y=y})
   assert((actual[x..':'..y] and actual[x..':'..y].rock or false)==expected,'batched EAT condition/status mismatch')
  end end
  assert(w._query_traits==nil and w._condition_rules==nil,'batch context leaked')
  w.entities[1].x=9
 end
end
print('PASS: batched EMPTY movement EAT preserves per-cell conditions/BROKEN and fresh phase queries')
