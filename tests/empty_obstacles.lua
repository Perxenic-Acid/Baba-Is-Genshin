local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(traits,stop,phantom)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=18,32;w.language.nouns.FLAG='flag';w.next_entity_id=10
 w.entities={[1]={id=1,kind='object',class='object',archetype='avatar',x=4,y=3,direction='Left'},
  [2]={id=2,kind='object',class='object',archetype='flag',x=6,y=3,direction='Up'}}
 local rows={{'AVATAR','IS','YOU'},{'EMPTY','IS','RIGHT'}}
 for _,trait in ipairs(traits) do rows[#rows+1]={'EMPTY','FACING','FLAG','IS',trait} end
 if stop then rows[#rows+1]={'FLAG','IS','STOP'} end
 if phantom then rows[#rows+1]={'AVATAR','IS','PHANTOM'} end
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'}
 end end
 return s
end
for _,case in ipairs({
 {{'PUSH'},true,false,false},{{'PUSH','SWAP'},true,false,true},{{'PUSH','STILL'},false,false,false},
 {{'SWAP','STOP','STILL'},false,false,false},{{'SWAP','STILL'},false,false,true},
 {{'PUSH','SLEEP'},false,false,true},{{'SWAP','STOP','SLEEP'},true,false,true},
 {{'PUSH','REVERSE','LOCKEDLEFT'},false,false,false},{{'PUSH','REVERSE','REVERSE','LOCKEDLEFT'},false,false,true},
 {{'SWAP','STOP','LOCKEDRIGHT'},false,false,false},{{'PUSH','STILL'},true,true,true}
}) do
 local s=fixture(case[1],case[2],case[3]);local p,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 assert(n.world.entities[1].x==(case[4] and 5 or 4),table.concat(case[1],','))
 assert(n.world.entities[1].direction=='Right' and n.world.entities[2].x==6 and n.world.entities[2].direction=='Up')
 assert(n.world.next_entity_id==s.world.next_entity_id and RW_Undo(n).world==s.world)
 for _,op in ipairs(p.changes) do assert(op.entity_id>0) end
end
print('PASS: EMPTY passive collision compiled conditions, PUSH/SWAP/STILL/locks, counted REVERSE, SLEEP/PHANTOM, facing, real-only Commit and Undo')
-- Both recursive virtual chains and real PUSH dependencies share classification.
for _,recursive in ipairs({false,true}) do for _,swap in ipairs({false,true}) do
 local s=RW_CreateSession();local w=s.world;w.width,w.height=8,6
 w.entities={[1]={id=1,kind='object',class='object',archetype='avatar',x=2,y=3,direction='Left',behaviors={}}}
 w.empty_cells={['4:3']={x=4,y=3,behaviors={push=true,still=not swap,swap=swap}}}
 if recursive then w.empty_cells['3:3']={x=3,y=3,behaviors={push=true}}
 else w.entities[2]={id=2,kind='object',class='object',archetype='rock',x=3,y=3,direction='Up',behaviors={push=true}} end
 local p=RW_ResolveMovement(w,{type='move',entity_id=1,dx=1,dy=0})
 assert((#p.changes>0)==swap)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
 assert(n.world.entities[1].x==(swap and 3 or 2))
 if not recursive then assert(n.world.entities[2].x==(swap and 4 or 3)) end
 assert(RW_Undo(n).world==w)
end end
print('PASS: recursive EMPTY PUSH and real dependencies share SWAP/lock handling without speculative leakage')
