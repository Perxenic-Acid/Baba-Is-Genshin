local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local ds={births=RW_InitializeHasBirths,empty_births=RW_InitializeEmptyHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 movement_eaters=RW_ResolveMovementEatTargets,
 destroy=function(w,ids,c,k,d,r,n) return RW_PlanDestructionPhase(w,ids,c,k,ds,d,r,n) end,
 contact=function(w,p,k,c,r,n) local adapted={};for key,value in pairs(ds) do adapted[key]=value end
  adapted.victims=RW_ResolveContactVictims;return RW_PlanContactPhase(w,p,k,c,adapted,r,n) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(extra,control)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=20,36;w.next_entity_id=10
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={[1]={id=1,kind='object',class='object',archetype='rock',x=5,y=3,direction='Up'}}
 local rows={{'EMPTY','IS','RIGHT'},{'EMPTY','FACING','ROCK','IS',control or 'YOU'},
  {'EMPTY','EAT','ROCK'},{'ROCK','IS','STOP'},{'ROCK','HAS','FLAG'}}
 for _,row in ipairs(extra or {}) do rows[#rows+1]=row end
 for y,words in ipairs(rows) do for x,name in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=6+y*2,direction='None'}
 end end
 return s
end
local function run(s,action)
 local plan,e=RW_PlanTurn(s.world,action or {type='move',dx=1,dy=0},services);assert(plan,e and e.reason)
 for _,op in ipairs(plan.changes) do assert(op.entity_id>0) end
 local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
 assert(RW_Undo(n).world==s.world and not n.world.movement_eaters)
 for id,entity in pairs(n.world.entities) do assert(id>0 and entity.class~='empty' and not entity.eat_targets) end
 return n
end
local s=fixture();local n=run(s)
assert(not n.world.entities[1] and n.world.entities[s.world.next_entity_id] and n.world.entities[s.world.next_entity_id].archetype=='flag','base virtual eat')
for _,extra in ipairs({{{'ROCK','IS','SAFE'}},{{'ROCK','IS','FLOAT'}}}) do
 s=fixture(extra);n=run(s);assert(n.world.entities[1] and n.world.next_entity_id==s.world.next_entity_id,extra[1][3])
end
s=fixture({{'ROCK','IS','FLOAT'},{'EMPTY','IS','FLOAT'}});n=run(s);assert(not n.world.entities[1])
s=fixture({{'EMPTY','EAT','NOT','ROCK'}});n=run(s);assert(n.world.entities[1])
s=fixture({{'EMPTY','IS','OPEN'},{'ROCK','IS','SHUT'},{'EMPTY','HAS','CRATE'}})
n=run(s);assert(not n.world.entities[1])
assert(n.world.entities[s.world.next_entity_id].archetype=='flag' and n.world.entities[s.world.next_entity_id+1].archetype=='crate')
-- Per-cell source conditions refresh against the actual vacant origin.
s=fixture({{'EMPTY','NEAR','FLAG','EAT','ROCK'}})
for id,e in pairs(s.world.entities) do if e.y==12 then s.world.entities[id]=nil end end
n=run(s);assert(n.world.entities[1])
s.world.entities[2]={id=2,kind='object',class='object',archetype='flag',x=4,y=4,direction='None'}
n=run(s);assert(not n.world.entities[1])
s.world.entities[2].x=3
n=run(s);assert(n.world.entities[1]) -- source condition true, destination false
s.world.entities[2].x=6
n=run(s);assert(n.world.entities[1]) -- destination true, no active source EAT
s=fixture({{'EMPTY','NEAR','FLAG','EAT','ROCK'},{'EMPTY','EAT','TEXT'}})
for id,e in pairs(s.world.entities) do if e.y==12 then s.world.entities[id]=nil end end
s.world.entities[2]={id=2,kind='object',class='object',archetype='flag',x=6,y=4,direction='None'}
n=run(s);assert(not n.world.entities[1]) -- another target grants the source gate
services.automatic=function(w,_,raw) local directions,e=RW_CollectEmptyMotionDirections(w,raw);if not directions then return nil,e end;return RW_ResolveAutomatic(w,directions) end
s=fixture(nil,'MOVE');n=run(s,{type='wait'});assert(not n.world.entities[1]);services.automatic=nil
services.fear=function(w,r,raw) local t,e=RW_ResolveFearTargets(w,r,raw);if not t then return nil,e end;return RW_ResolveFear(w,t) end
s=fixture({{'EMPTY','FACING','ROCK','FEAR','FLAG'}},'STOP')
s.world.entities[2]={id=2,kind='object',class='object',archetype='flag',x=3,y=3,direction='None'}
n=run(s,{type='wait'});assert(not n.world.entities[1]);services.fear=nil
-- Virtual target eating uses the same per-agent source map, without real IDs.
for _,safe in ipairs({false,true}) do
 local w={width=8,height=8,entities={[-1]={id=-1,kind='object',class='empty',x=4,y=4,behaviors={},eat_targets={['@empty']=true}}},
  empty_cells={['5:4']={x=5,y=4,behaviors={block_entry=true,safe=safe}}},empty_eaters={}}
 local p=assert(RW_ResolveMovement(w,{type='move',entity_id=-1,dx=1,dy=0}))
 assert(#(p.destructions or {})==(safe and 0 or 1))
 if not safe then assert(p.destructions[1].class=='empty' and p.destructions[1].x==5 and p.destructions[1].cause=='eat') end
end
print('PASS: virtual EMPTY EAT real/vacant targets, SAFE/FLOAT, per-cell conditions, YOU/MOVE/FEAR, proxy-free atomic HAS and Undo')
