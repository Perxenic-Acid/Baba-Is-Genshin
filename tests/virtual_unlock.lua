-- Exercise the virtual-vs-virtual path without putting any proxies in world.
for _,source_deleted in ipairs({false,true}) do for _,target_deleted in ipairs({false,true}) do
 local s=RW_CreateSession();local w=s.world;w.width,w.height=8,8;w.entities={};w.next_entity_id=10;w.random_state=7
 w.language.nouns.FLAG='flag'
 local effects={}
 for _,spec in ipairs({{'you',4},{'open',4},{'shut',5},{'stop',5}}) do
  effects[#effects+1]={op='grant_trait',trait=spec[1],entity_ids={},cells={{x=spec[2],y=4}}}
 end
 local projected=assert(RW_ProjectWorld(w,effects));projected.empty_deleted={}
 if source_deleted then projected.empty_deleted['4:4']=true end
 if target_deleted then projected.empty_deleted['5:4']=true end
 local movement=assert(RW_ResolveTurn(projected,{type='move',dx=1,dy=0}))
 assert(#movement.changes==0)
 local ids={};for _,death in ipairs(movement.destructions) do
  assert(death.class=='empty' and not death.frame[-1]);ids[#ids+1]=death.entity_id
 end
 -- The proxy must retire even when source delete() already ran this command.
 local last=movement.destructions[#movement.destructions]
 assert(last.x==4 and last.entity_id<0 and (last.skip_inside==true)==source_deleted)
 local relations={{op='empty_has',source_type='@empty',when={op='always'},product={kind='object',archetype='flag'}}}
 local phase=assert(RW_PlanDestructionPhase(w,ids,relations,'unlock',{
  births=function() error('real HAS for virtual victim') end,
  empty_products=RW_PlanEmptyHasBirths,initialize=RW_InitializeBirthSpecifications,
  create=RW_PlanCreate,delete=RW_PlanDelete},movement.destructions,{}))
 local births=(source_deleted and 0 or 1)+(target_deleted and 0 or 1)
 assert(#phase.changes==births)
 local plan={consumes_turn=true,changes=phase.changes,stages={{name='movement',plan={consumes_turn=true,changes={}}},{name='unlock',plan=phase}}}
 local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
 assert(n.world.next_entity_id==10+births and not n.world.empty_deleted and not n.world.empty_eaters)
 local seed=7;for i=1,births do seed=seed*48271%2147483647 end;assert(n.world.random_state==seed)
 if not target_deleted then assert(n.world.entities[10].x==5) end
 if not source_deleted then assert(n.world.entities[9+births].x==4) end
 for id,e in pairs(n.world.entities) do assert(id>0 and e.class~='empty') end
 assert(RW_Undo(n).world==w)
end end
print('PASS: virtual-to-virtual unlock target/source HAS, cached-source proxy retirement, per-cell RNG/allocators, positive-only Commit and Undo')
