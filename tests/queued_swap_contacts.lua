local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
 evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local ds={births=RW_InitializeHasBirths,empty_births=RW_InitializeEmptyHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,
 convert=RW_PlanConversions,refresh=RW_EvaluateRules,movement_eaters=RW_ResolveMovementEatTargets,
 destroy=function(w,ids,c,k,d,r,n) return RW_PlanDestructionPhase(w,ids,c,k,ds,d,r,n) end,
 contact=function(w,p,k,c,r,n) local adapted={};for key,value in pairs(ds) do adapted[key]=value end
  adapted.victims=RW_ResolveContactVictims;return RW_PlanContactPhase(w,p,k,c,adapted,r,n) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
for _,axis in ipairs({{1,0},{0,-1},{-1,0},{0,1}}) do
for _,eat in ipairs({false,true}) do for _,blocked in ipairs({false,true}) do
for _,protected in ipairs(eat and {false,true} or {false}) do
 local dx,dy=axis[1],axis[2];local s=RW_CreateSession();local w=s.world
 w.width,w.height=12,36;w.next_entity_id=10
 w.language.nouns.FLAG='flag';w.language.nouns.ROCK='rock';w.language.nouns.WALL='wall'
 local function unit(id,name,step)
  return {id=id,kind='object',class='object',archetype=name,x=5+step*dx,y=5+step*dy,direction='Mid'}
 end
 w.entities={[1]=unit(1,'avatar',0),[2]=unit(2,'crate',1),[3]=unit(3,'flag',1),[4]=unit(4,'rock',2)}
 if blocked then w.entities[5]=unit(5,'wall',2) end
 local rows={{'AVATAR','IS','YOU'},{'CRATE','IS','PUSH'},{'FLAG','IS','PUSH'},
  {'ROCK','IS','SWAP'},{'ROCK','HAS','CRATE'},{'FLAG','HAS','ROCK'},{'WALL','IS','STOP'}}
 if eat then rows[#rows+1]={'FLAG','EAT','ROCK'}
 else rows[#rows+1]={'FLAG','IS','OPEN'};rows[#rows+1]={'ROCK','IS','SHUT'} end
 if protected then rows[#rows+1]={'ROCK','IS','SAFE'} end
 for row,words in ipairs(rows) do for x,name in ipairs(words) do
  local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=10+row*2,direction='None'}
 end end
 local plan,e=RW_PlanTurn(w,{type='move',dx=dx,dy=dy},services);assert(plan,e and e.reason)
 for _,op in ipairs(plan.changes) do
  assert(not (op.kind=='move' and op.entity_id==4 and not blocked and not protected),'destroyed queued target retained displacement')
 end
 local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
 if blocked then
  assert(n.world.entities[1].x==5 and n.world.entities[1].y==5)
  assert(n.world.entities[4].x==5+2*dx and n.world.entities[4].y==5+2*dy)
  assert(n.world.next_entity_id==w.next_entity_id)
 elseif protected then
  assert(n.world.entities[4].x==5+dx and n.world.entities[4].y==5+dy and n.world.entities[4].direction=='Mid')
  assert(n.world.entities[3].x==5+2*dx and n.world.entities[3].y==5+2*dy)
  assert(n.world.next_entity_id==w.next_entity_id)
 else
  assert(not n.world.entities[4] and (n.world.entities[3]~=nil)==eat,
   table.concat({dx,dy,tostring(eat),tostring(n.world.entities[4]~=nil),tostring(n.world.entities[3]~=nil)},':'))
  assert(n.world.entities[2].x==5+2*dx and n.world.entities[2].y==5+2*dy)
  local birth=n.world.entities[w.next_entity_id]
  assert(birth.archetype=='crate' and birth.x==5+2*dx and birth.y==5+2*dy)
  if not eat then
   birth=n.world.entities[w.next_entity_id+1]
   assert(birth.archetype=='rock' and birth.x==5+dx and birth.y==5+dy)
  end
 end
 assert(RW_Undo(n).world==w)
end end end end
print('PASS: later stacked PUSH EAT/unlock reaches queued SWAP targets, target-first HAS, SAFE retained exchange, no stale displacement, four axes, rollback and Undo')
