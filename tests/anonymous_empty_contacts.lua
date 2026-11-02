local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local ds={births=RW_InitializeHasBirths,empty_births=RW_InitializeEmptyHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 movement_eaters=RW_ResolveMovementEatTargets,
 destroy=function(w,ids,c,k,d,r,n) return RW_PlanDestructionPhase(w,ids,c,k,ds,d,r,n) end,
 contact=function(w,p,k,c,r,n) local adapted={};for key,value in pairs(ds) do adapted[key]=value end
  adapted.victims=RW_ResolveContactVictims;return RW_PlanContactPhase(w,p,k,c,adapted,r,n) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(extra)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=20,40;w.next_entity_id=10
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.language.nouns.WALL='wall'
 w.entities={[1]={id=1,kind='object',class='object',archetype='avatar',x=4,y=3,direction='Left'},
  [2]={id=2,kind='object',class='object',archetype='rock',x=6,y=3,direction='Up'}}
 local rows={{'AVATAR','IS','YOU'},{'EMPTY','IS','RIGHT'},{'EMPTY','FACING','ROCK','IS','PUSH'},
  {'ROCK','IS','STOP'},{'ROCK','HAS','FLAG'},{'EMPTY','HAS','CRATE'}}
 for _,row in ipairs(extra or {}) do rows[#rows+1]=row end
 for y,words in ipairs(rows) do for x,name in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=6+y*2,direction='None'}
 end end
 return s
end
local function run(s)
 local plan,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
 for _,op in ipairs(plan.changes) do assert(op.entity_id>0) end
 local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
 assert(RW_Undo(n).world==s.world and not n.world.empty_deleted and not n.world.movement_eaters)
 return n
end
local s=fixture({{'EMPTY','EAT','ROCK'}});local n=run(s)
assert(n.world.entities[1].x==5 and not n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id+1)
assert(n.world.entities[s.world.next_entity_id].archetype=='flag' and n.world.entities[s.world.next_entity_id].x==6)
for _,extra in ipairs({{{'EMPTY','EAT','ROCK'},{'ROCK','IS','SAFE'}},{{'EMPTY','EAT','ROCK'},{'ROCK','IS','FLOAT'}}}) do
 s=fixture(extra);n=run(s);assert(n.world.entities[1].x==4 and n.world.entities[2])
end
s=fixture({{'EMPTY','EAT','ROCK'},{'EMPTY','FACING','ROCK','IS','SLEEP'}});n=run(s);assert(not n.world.entities[2])
for _,source_safe in ipairs({false,true}) do for _,target_safe in ipairs({false,true}) do
 local extra={{'EMPTY','FACING','ROCK','IS','OPEN'},{'ROCK','IS','SHUT'},{'EMPTY','EAT','ROCK'}}
 if source_safe then extra[#extra+1]={'EMPTY','FACING','ROCK','IS','SAFE'} end
 if target_safe then extra[#extra+1]={'ROCK','IS','SAFE'} end
 s=fixture(extra);n=run(s)
 assert((n.world.entities[1].x==5)==not (source_safe and target_safe))
 assert((n.world.entities[2]~=nil)==target_safe)
 local expected=(target_safe and 0 or 1)+(source_safe and 0 or 1)
 assert(n.world.next_entity_id==s.world.next_entity_id+expected)
 if not target_safe then assert(n.world.entities[s.world.next_entity_id].archetype=='flag') end
end end
s=fixture({{'EMPTY','FACING','ROCK','IS','OPEN'},{'ROCK','IS','SHUT'},{'EMPTY','NEAR','FLAG','HAS','CRATE'}})
for id,e in pairs(s.world.entities) do if e.y==18 then s.world.entities[id]=nil end end
n=run(s);assert(n.world.next_entity_id==s.world.next_entity_id+2)
assert(n.world.entities[s.world.next_entity_id].archetype=='flag' and n.world.entities[s.world.next_entity_id+1].archetype=='crate')
assert(n.world.entities[s.world.next_entity_id].direction=='Up' and n.world.entities[s.world.next_entity_id+1].direction=='Right')
s=fixture({{'EMPTY','EAT','ROCK'},{'WALL','IS','STOP'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='wall',x=6,y=3,direction='Down'}
n=run(s);assert(n.world.entities[1].x==4 and n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id)
s=fixture({{'EMPTY','FACING','ROCK','IS','PHANTOM'}});n=run(s)
assert(n.world.entities[1].x==5 and n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id)
-- Same-layer WEAK removes front solidity even when SAFE. Virtual movement
-- does not kill the real target; the later ordinary contact phase still does.
for _,safe in ipairs({false,true}) do
 local extra={{'ROCK','IS','WEAK'}}
 if safe then extra[#extra+1]={'ROCK','IS','SAFE'} end
 s=fixture(extra);n=run(s)
 assert(n.world.entities[1].x==5 and n.world.entities[2])
 assert(n.world.next_entity_id==s.world.next_entity_id)
end
s=fixture({{'ROCK','IS','WEAK'},{'ROCK','IS','FLOAT'}});n=run(s)
assert(n.world.entities[1].x==4 and n.world.entities[2])
for _,extra in ipairs({{{'ROCK','IS','SWAP'}},
 {{'ROCK','IS','SWAP'},{'ROCK','IS','FLOAT'},{'ROCK','IS','PUSH'}},
 {{'ROCK','IS','SWAP'},{'EMPTY','FACING','ROCK','IS','PHANTOM'}}}) do
 s=fixture(extra);n=run(s)
 assert(n.world.entities[1].x==5 and n.world.entities[2].x==5 and n.world.entities[2].direction=='Up')
 assert(n.world.next_entity_id==s.world.next_entity_id)
end
s=fixture({{'ROCK','IS','SWAP'},{'ROCK','IS','STILL'}});n=run(s)
assert(n.world.entities[1].x==4 and n.world.entities[2].x==6)
s=fixture({{'ROCK','IS','SWAP'},{'WALL','IS','STOP'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='wall',x=6,y=3,direction='Down'}
n=run(s);assert(n.world.entities[1].x==4 and n.world.entities[2].x==6)
-- Anonymous virtual-target dispatch preserves EAT-before-lock and never
-- promotes its string-local source key into an entity or operation ID.
for _,source_safe in ipairs({false,true}) do for _,target_safe in ipairs({false,true}) do
 local w={width=8,height=8,entities={[1]={id=1,x=4,y=4,behaviors={}}},
  empty_cells={['5:4']={x=5,y=4,behaviors={push=true,open=true,safe=source_safe}},
   ['6:4']={x=6,y=4,behaviors={block_entry=true,shut=true,safe=target_safe}}},
  movement_eaters={empty_cells={['5:4']={['@empty']=true},['6:4']={['@empty']=true}}},empty_eaters={}}
 local p=assert(RW_ResolveMovement(w,{type='move',entity_id=1,dx=1,dy=0}))
 assert((#p.changes>0)==not (source_safe and target_safe))
 local deaths=p.destructions or {};assert(#deaths==(source_safe and 0 or 1)+(target_safe and 0 or 1))
 if not target_safe then assert(deaths[1].x==6 and deaths[1].cause=='eat') end
 if not source_safe then assert(deaths[#deaths].x==5 and deaths[#deaths].cause=='unlock') end
 for _,death in ipairs(deaths) do assert(death.class=='empty' and type(death.entity_id)=='string') end
end end
print('PASS: anonymous EMPTY PUSH EAT/unlock, independent SAFE/FLOAT, target/source HAS, real/virtual special order, PHANTOM, rollback and Undo')
