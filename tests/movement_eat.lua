local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local death_services={births=RW_InitializeHasBirths,empty_births=RW_InitializeEmptyHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete,
 initialized_births=function(w,ids,c,r,n,k) return RW_InitializeHasBirths(w,ids,c,r,n,k=='weak' or k=='melt' or k=='eat') end}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 movement_eaters=RW_ResolveMovementEatTargets,
 destroy=function(w,ids,c,k,d,r,n) return RW_PlanDestructionPhase(w,ids,c,k,death_services,d,r,n) end,
 contact=function(w,p,k,c,r,n) local adapted={};for key,value in pairs(death_services) do adapted[key]=value end
  adapted.victims=RW_ResolveContactVictims;return RW_PlanContactPhase(w,p,k,c,adapted,r,n) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(extra)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=24,40;w.next_entity_id=10
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.language.nouns.WALL='wall'
 w.entities={[1]={id=1,kind='object',class='object',archetype='avatar',x=4,y=3,direction='Right'},
  [2]={id=2,kind='object',class='object',archetype='rock',x=5,y=3,direction='Up'}}
 local rows={{'AVATAR','IS','YOU'},{'AVATAR','EAT','ROCK'},{'ROCK','HAS','FLAG'}}
 for _,row in ipairs(extra or {}) do rows[#rows+1]=row end
 for y,words in ipairs(rows) do for x,name in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=6+y*2,direction='None'}
 end end
 return s
end
local function run(s,action)
 local plan,e=RW_PlanTurn(s.world,action or {type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
 local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
 assert(RW_Undo(n).world==s.world and not n.world.movement_eaters and not n.world.empty_eaters)
 return n,plan
end
for _,trait in ipairs({'STOP','PUSH','PULL','SWAP','STILL'}) do
 local s=fixture({{'ROCK','IS',trait}});local n=run(s)
 assert(n.world.entities[1].x==5 and not n.world.entities[2])
 local born=n.world.entities[s.world.next_entity_id];assert(born.archetype=='flag' and born.x==5 and born.direction=='Up')
end
for _,extra in ipairs({{{'ROCK','IS','STOP'},{'ROCK','IS','SAFE'}},{{'ROCK','IS','STOP'},{'ROCK','IS','FLOAT'}}}) do
 local s=fixture(extra);local n=run(s);assert(n.world.entities[1].x==4 and n.world.entities[2])
end
local s=fixture({{'ROCK','IS','STOP'},{'ROCK','IS','FLOAT'},{'AVATAR','IS','FLOAT'},{'AVATAR','IS','SAFE'}})
local n=run(s);assert(n.world.entities[1].x==5 and not n.world.entities[2])
-- Unrelated blockers cancel speculative eating and all HAS births.
s=fixture({{'ROCK','IS','STOP'},{'WALL','IS','STOP'}})
s.world.entities[3]={id=3,kind='object',class='object',archetype='wall',x=5,y=3,direction='Down'}
n=run(s);assert(n.world.entities[1].x==4 and n.world.entities[2] and n.world.next_entity_id==s.world.next_entity_id)
-- Unlock kills an unsafe mover before its EAT special can run on later targets.
s=fixture({{'AVATAR','IS','OPEN'},{'ROCK','IS','SHUT'},{'ROCK','IS','STOP'},{'AVATAR','HAS','ROCK'}})
n=run(s);assert(not n.world.entities[1] and not n.world.entities[2])
assert(n.world.entities[s.world.next_entity_id].archetype=='flag' and n.world.entities[s.world.next_entity_id+1].archetype=='rock')
-- Source conditions use the source origin, not its desired destination.
s=fixture({{'ROCK','IS','STOP'},{'AVATAR','ON','FLAG','EAT','ROCK'}})
for id,entity in pairs(s.world.entities) do if entity.y==10 then s.world.entities[id]=nil end end
n=run(s);assert(n.world.entities[1].x==4 and n.world.entities[2])
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=4,y=3,direction='None'}
n=run(s);assert(n.world.entities[1].x==5 and not n.world.entities[2])
-- Passive PUSH participants use their own EAT declarations.
s=fixture({{'FLAG','IS','PUSH'},{'FLAG','EAT','ROCK'},{'ROCK','IS','STOP'}})
s.world.entities[2].x=6;s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=5,y=3,direction='Left'}
n=run(s);assert(n.world.entities[1].x==5 and n.world.entities[3].x==6 and not n.world.entities[2])
s=fixture({{'TEXT','EAT','ROCK'},{'ROCK','IS','STOP'}})
s.world.entities[2].x=6;s.world.entities[3]={id=3,kind='object',class='text',text={name='IS'},x=5,y=3,direction='Left'}
n=run(s);assert(n.world.entities[3].x==6 and not n.world.entities[2])
s=fixture({{'AVATAR','EAT','TEXT'},{'TEXT','HAS','ROCK'}})
s.world.entities[2]={id=2,kind='object',class='text',text={name='FLAG'},x=5,y=3,direction='Down'}
n=run(s);assert(n.world.entities[1].x==5 and not n.world.entities[2])
assert(n.world.entities[s.world.next_entity_id].archetype=='rock' and n.world.entities[s.world.next_entity_id].direction=='Down')
local direct={width=8,height=8,entities={
 [1]={id=1,class='object',archetype='avatar',x=4,y=4,behaviors={}},
 [2]={id=2,class='object',archetype='rock',x=4,y=4,behaviors={block_entry=true}},
 [3]={id=3,class='object',archetype='flag',x=3,y=4,behaviors={pull=true}}},movement_eaters={[3]={rock=true}}}
local pulled=assert(RW_ResolveMovement(direct,{type='move',entity_id=1,dx=1,dy=0}))
assert(#pulled.changes==1 and pulled.changes[1].entity_id==1 and #(pulled.destructions or {})==0)
-- Automatic and falling movement share the same collision path.
services.automatic=RW_ResolveAutomatic
s=fixture({{'AVATAR','IS','MOVE'},{'ROCK','IS','STOP'}});n=run(s,{type='wait'})
assert(n.world.entities[1].x==5 and not n.world.entities[2]);services.automatic=nil
services.fall=RW_ResolveFall
s=fixture({{'AVATAR','IS','FALLRIGHT'},{'ROCK','IS','STOP'}});n=run(s,{type='wait'})
assert(n.world.entities[1].x>5 and not n.world.entities[2]);services.fall=nil
print('PASS: real movement EAT bypasses target solidity, SAFE/FLOAT, ordered unlock/HAS, source conditions, passive PUSH, MOVE/FALL and atomic Undo')
