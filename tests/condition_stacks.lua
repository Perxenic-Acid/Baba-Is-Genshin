local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local svc={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c)return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete})end,
 evaluate=function(w)local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
for _,relation in ipairs({'FACEDBY','SEEING','ON','FACING','NEAR','NEXTTO','ABOVE','BELOW','BESIDELEFT','BESIDERIGHT'})do for explicit=0,1 do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=10;w.width=16;w.height=16
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.language.nouns.WATER='water'
 w.entities[1]={id=1,kind='object',class='object',archetype='avatar',x=2,y=2,direction='Right'}
 w.entities[2]={id=2,kind='object',class='object',archetype=relation=='FACEDBY' and 'rock' or 'water',x=3,y=2,direction='Right'}
 w.entities[3]={id=3,kind='object',class='object',archetype='flag',x=3,y=2,direction='Left'}
 if relation=='ON'then w.entities[2].x=2;w.entities[3].x=2 end
 local positions={ABOVE={2,3},BELOW={2,1},BESIDERIGHT={1,2}}
 if positions[relation]then for _,id in ipairs({2,3})do w.entities[id].x,w.entities[id].y=positions[relation][1],positions[relation][2]end end
 w.unit_order={1,2,3}
 for x,word in ipairs({'AVATAR',relation,'NOT','ROCK','AND','NOT','FLAG','IS','PUSH'})do
  local id=w.next_entity_id;w.next_entity_id=id+1;w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=8,direction='None'};w.unit_order[#w.unit_order+1]=id
 end
 if explicit==1 then local e=w.entities[2];w.cell_order={[e.x..':'..e.y]=relation=='ON' and {1,3,2} or {3,2}}end
 local f=assert(RW_CompileWorld(w,cs));local projected=assert(RW_ProjectWorld(w,f.effects))
 assert((projected.entities[1].behaviors.push==true)==(explicit==1),relation..' physical AND witness order')
 local p,e=RW_PlanTurn(w,{type='wait'},svc);assert(p,e and e.reason);local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 assert(RW_Undo(n).world==w and n.world.next_entity_id==w.next_entity_id)
end end
for _,relation in ipairs({'BELOW','BESIDERIGHT'})do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=10;w.width=16;w.height=16
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.language.nouns.WATER='water'
 w.entities[1]={id=1,kind='object',class='object',archetype='avatar',x=4,y=4,direction='Right'}
 w.entities[2]={id=2,kind='object',class='object',archetype='water',x=relation=='BELOW' and 4 or 3,y=relation=='BELOW' and 3 or 4,direction='None'}
 w.entities[3]={id=3,kind='object',class='object',archetype='flag',x=relation=='BELOW' and 4 or 2,y=relation=='BELOW' and 2 or 4,direction='None'}
 w.unit_order={1,3,2}
 for x,word in ipairs({'AVATAR',relation,'NOT','ROCK','AND','NOT','FLAG','IS','PUSH'})do
  local id=w.next_entity_id;w.next_entity_id=id+1;w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=8,direction='None'};w.unit_order[#w.unit_order+1]=id
 end
 local frame=assert(RW_CompileWorld(w,cs));local projected=assert(RW_ProjectWorld(w,frame.effects))
 assert(not projected.entities[1].behaviors.push,relation..' must consume nearer WATER before distant FLAG')
 local p,e=RW_PlanTurn(w,{type='wait'},svc);assert(p,e and e.reason);local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 assert(RW_Undo(n).world==w)
end
print('PASS: compiled spatial negative AND witnesses follow cell arrival and near-to-far ray order, with turn Commit and Undo')
