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





local function projection(s)
    local f=assert(RW_CompileWorld(s.world,cs));return assert(RW_ProjectWorld(s.world,f.effects)),f
end
local s=fixture({{'ROCK','IS','POWER'},{'POWERED','AVATAR','IS','PUSH'}})
local w,f=projection(s);assert(w.entities[1].behaviors.push and w.entities[2].behaviors.power)
for id=13,16 do assert(f.active_text_ids[id]) end
assert(#f.ast==2,'prefix must suppress unconditional interior sentence')
s=fixture({{'POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(not w.entities[1].behaviors.push)
for channel=1,3 do
    local suffix=channel==1 and '' or tostring(channel)
    s=fixture({{'ROCK','IS','POWER'..suffix},{'POWERED','AVATAR','IS','PUSH'},{'POWERED2','AVATAR','IS','FLOAT'},{'POWERED3','AVATAR','IS','SAFE'}})
    w=projection(s);assert((w.entities[1].behaviors.push==true)==(channel==1));assert((w.entities[1].behaviors.float==true)==(channel==2));assert((w.entities[1].behaviors.safe==true)==(channel==3))
end
s=fixture({{'NOT','POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(w.entities[1].behaviors.push)
s=fixture({{'ROCK','IS','POWER'},{'NOT','NOT','POWERED','AVATAR','IS','PUSH'}})
w,f=projection(s);assert(w.entities[1].behaviors.push and #f.ast==2)
s=fixture({{'ROCK','IS','POWER'},{'POWERED','NOT','AVATAR','IS','FLOAT'}})
w=projection(s);assert(w.entities[2].behaviors.float and not w.entities[1].behaviors.float)
s=fixture({{'ROCK','IS','POWER'},{'POWERED','POWERED2','AVATAR','IS','PUSH'}})
w=projection(s);assert(not w.entities[1].behaviors.push)
s=fixture({{'ROCK','IS','POWER','AND','POWER2'},{'POWERED','POWERED2','AVATAR','IS','PUSH'}})
w=projection(s);assert(w.entities[1].behaviors.push)
for _,words in ipairs({{'POWERED','AVATAR','AND','ROCK','IS','FLOAT'},{'AVATAR','AND','POWERED','ROCK','IS','FLOAT'}}) do
    s=fixture({{'ROCK','IS','POWER'},words});w,f=projection(s);assert(w.entities[1].behaviors.float and w.entities[2].behaviors.float)
    s.world.entities[2]=nil;w=projection(s);assert(not w.entities[1].behaviors.float,'prefix applies to the whole subject group')
end
s=fixture({{'ROCK','IS','POWER'},{'AVATAR','POWERED','IS','PUSH'}})
w=projection(s);assert(w.entities[1].behaviors.push)
s=fixture({{'ROCK','NEAR','AVATAR','IS','POWER'},{'POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(not w.entities[1].behaviors.push)
s.world.entities[1].x=5;s.world.entities[1].y=3;w=projection(s);assert(w.entities[1].behaviors.push)
s=fixture({{'ROCK','IS','POWER','AND','SLEEP','AND','HIDE','AND','FLOAT'},{'POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(w.entities[1].behaviors.push,'power is global, not filtered by layer/visibility/sleep')
s=fixture({{'ROCK','IS','POWER'},{'ROCK','IS','NOT','POWER'},{'POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(not w.entities[1].behaviors.push)
s=fixture({{'EMPTY','IS','POWER'},{'POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(w.entities[1].behaviors.push)
s=fixture({{'TEXT','IS','POWER2'},{'POWERED2','AVATAR','IS','PUSH'}})
w=projection(s);assert(w.entities[1].behaviors.push)
s=fixture({{'LEVEL','IS','POWER3'},{'POWERED3','AVATAR','IS','PUSH'}})
s.world.language.nouns.LEVEL={tag='level',block_type='level_block'};w=projection(s);assert(w.entities[1].behaviors.push)
s=fixture({{'LEVEL','IS','POWER3'},{'LEVEL','IS','NOT','POWER3'},{'POWERED3','AVATAR','IS','PUSH'}})
s.world.language.nouns.LEVEL={tag='level',block_type='level_block'};w=projection(s);assert(not w.entities[1].behaviors.push)
s=fixture({{'ROCK','IS','POWER'},{'POWERED','ROCK','BECOME','FLAG'}})
local n,p=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','IS','POWER','AND','YOU','AND','DEFEAT'},{'POWERED','ROCK','HAS','FLAG'}})
n,p=step(s);local born=false;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then born=true end end;assert(born)
s=fixture({{'ROCK','IS','POWER'},{'POWERED','ROCK','IS','WORD'}})
w,f=projection(s);assert(f.word_tokens[2]=='ROCK')
s=fixture({{'POWERED','ROCK','IS','POWER'},{'POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(not w.entities[1].behaviors.push and not w.entities[2].behaviors.power,'no self-grounding power')
s=fixture({{'POWERED2','ROCK','IS','POWER'},{'POWERED','ROCK','IS','POWER2'},{'POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(not w.entities[1].behaviors.push,'bounded channel cycles')
s=fixture({{'POWERED','AVATAR','IS','PUSH'}})
s.world.entities[2].behaviors={power=true};w=projection(s);assert(not w.entities[1].behaviors.push,'ignore stale capabilities')
assert(not s.world._condition_rules and not s.world._condition_guard)
s=fixture({{'ROCK','IS','POWER2'},{'POWERED2','ROCK','IS','POWER'},{'POWERED','AVATAR','IS','PUSH'}})
w=projection(s);assert(w.entities[1].behaviors.push,'grounded cross-channel dependency')
s=fixture({{'ROCK','IS','POWER'},{'POWERED','AVATAR','IS','FLOAT','AND','SAFE'}})
w=projection(s);assert(w.entities[1].behaviors.float and w.entities[1].behaviors.safe)
s=fixture({{'ROCK','IS','POWER'},{'POWERED','ROCK','ON','AVATAR','IS','FLOAT'}})
s.world.entities[1].x=6;s.world.entities[1].y=3;object(s.world,3,'rock',10,3)
w=projection(s);assert(w.entities[2].behaviors.float and not w.entities[3].behaviors.float)
s=fixture({{'ROCK','IS','POWER'},{'POWERED','ROCK','BECOME','FLAG'}})
local duplicate=s.world.next_entity_id;s.world.next_entity_id=duplicate+1
s.world.entities[duplicate]={id=duplicate,kind='object',class='text',text={name='POWERED'},x=1,y=8,direction='None'}
n,p=step(s);local count=0;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then count=count+1 end end
assert(count==2,'stacked prefix sentence variants preserve product multiplicity')
print('PASS: POWERED three global channels, prefixes/NOT/AND/activation/shadowing, spatial sources/EMPTY/Text/LEVEL, conversion/HAS/WORD, bounded grounding and Undo')

-- LONELY shares the prefix parser, but checks physical occupancy per identity.
s=fixture({{'LONELY','AVATAR','IS','FLOAT'}})
w,f=projection(s);assert(w.entities[1].behaviors.float)
object(s.world,3,'flag',2,2);s.world.entities[3].behaviors={hide=true,float=true}
w=projection(s);assert(not w.entities[1].behaviors.float)
s=fixture({{'NOT','LONELY','AVATAR','IS','FLOAT'}})
w=projection(s);assert(not w.entities[1].behaviors.float)
object(s.world,3,'flag',2,2);w=projection(s);assert(w.entities[1].behaviors.float)
s=fixture({{'LONELY','ROCK','BECOME','FLAG'}})
n,p=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','IS','POWER'},{'POWERED','LONELY','AVATAR','IS','SAFE'}})
w=projection(s);assert(w.entities[1].behaviors.safe)
s=fixture({{'LONELY','AVATAR','AND','ROCK','IS','FLOAT'}})
object(s.world,3,'flag',6,3);w=projection(s)
assert(w.entities[1].behaviors.float and not w.entities[2].behaviors.float)
print('PASS: LONELY physical identity occupancy, NOT, grouped prefixes/subjects, conversion and Undo')

-- IDLE is the current wait command, never a lack of successful displacement.
s=fixture({{'IDLE','AVATAR','IS','FLOAT'}})
w=projection(s);assert(not w.entities[1].behaviors.float)
n,p=step(s);assert(n.world.last_input=='wait' and s.world.last_input==nil)
w=projection(n);assert(w.entities[1].behaviors.float)
local again=assert(RW_PlanTurn(s.world,{type='wait'},services))
local replay=RW_Commit(s,again);assert(replay.world.last_input=='wait')
local moved=step(n,{type='move',dx=1,dy=0});w=projection(moved)
assert(moved.world.last_input=='move' and not w.entities[1].behaviors.float)
assert(RW_Undo(moved).world==n.world)
s=fixture({{'IDLE','ROCK','BECOME','FLAG'}})
n,p=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'NOT','IDLE','ROCK','BECOME','FLAG'}})
n,p=step(s,{type='move',dx=1,dy=0});assert(n.world.entities[2].archetype=='flag')
s=fixture({{'IDLE','AVATAR','IS','YOU'}})
-- The new move command disables IDLE before YOU resolution.
s.world.last_input='wait'
n,p=step(s,{type='move',dx=1,dy=0});assert(n.world.entities[1].x==2 and n.world.last_input=='move')
s=fixture({{'AVATAR','IS','YOU'},{'IDLE','ROCK','IS','FLOAT'}})
s.world.entities[1].x=24
n,p=step(s,{type='move',dx=1,dy=0});assert(n.world.last_input=='move' and n.world.entities[1].x==24)
w=projection(n);assert(not w.entities[2].behaviors.float)
local invalid=assert(RW_PlanTurn(s.world,{type='move',dx=2,dy=0},services))
assert(not invalid.consumes_turn and not invalid.input_state and not s.world.last_input)
local stale={consumes_turn=true,changes={},input_state={from='wait',to='move'}}
local unchanged,reject=RW_Commit(s,stale);assert(unchanged==s and reject.reason=='stale_input_state')
print('PASS: IDLE current input before movement/conversion, wait, blocked/no-YOU move, rejection, replay and Undo')

-- Chance decisions are pure per head/clause/identity and persist through a turn.
for _,prefix in ipairs({'OFTEN','SELDOM'}) do
 local hits,total=0,0
 s=fixture({{prefix,'AVATAR','IS','FLOAT','AND','SAFE'}})
 for seed=1,240 do
  s.world.chance_seed=seed
  local before=s.world.chance_seed
  w,f=projection(s);local repeated=projection(s)
  local active=w.entities[1].behaviors.float==true
  assert(active==(w.entities[1].behaviors.safe==true),'RHS AND shares a draw')
  assert(active==(repeated.entities[1].behaviors.float==true) and s.world.chance_seed==before)
  assert(f.ast[1].when.clauses[1].chance_key)
  if active then hits=hits+1 end;total=total+1
 end
 assert(hits>0 and hits<total,'chance must vary across turns')
 s=fixture({{prefix,'ROCK','BECOME','FLAG'}})
 for seed=1,24 do
  s.world.chance_seed=seed
  local future={};for k,v in pairs(s.world) do future[k]=v end
  future.chance_seed=(seed*48271)%2147483647;future.last_input='wait'
  local frame=assert(RW_CompileWorld(future,cs));local expected=false
  for _,relation in ipairs(frame.relations) do
   if relation.op=='become' and RW_RelationApplies(future,relation,future.entities[2]) then expected=true end
  end
  n,p=step(s)
  assert((n.world.entities[2].archetype=='flag')==expected,'conversion uses the accepted turn seed')
  assert(n.world.chance_seed==future.chance_seed and s.world.chance_seed==seed)
  local replay=RW_Commit(s,assert(RW_PlanTurn(s.world,{type='wait'},services)))
  assert(replay.world.entities[2].archetype==n.world.entities[2].archetype and replay.world.chance_seed==n.world.chance_seed)
 end
end
s=fixture({{'OFTEN','OFTEN','ROCK','BECOME','FLAG'}})
w,f=projection(s)
assert(f.ast[1].when.clauses[1].chance_key~=f.ast[1].when.clauses[2].chance_key)
local joint=0
for seed=1,8192 do
 s.world.chance_seed=seed
 if RW_TestEntityCondition(s.world,f.ast[1].when,s.world.entities[2]) then joint=joint+1 end
end
assert(joint>4350 and joint<4850,'repeated OFTEN clauses need separate draws, approximately 9/16')

s=fixture({{'OFTEN','ROCK','IS','WORD'}})
w,f=projection(s);assert(f.iterations<=2,'WORD queries must not reroll')
s=fixture({{'SELDOM','AVATAR','IS','FLOAT'}})
local invalid=assert(RW_PlanTurn(s.world,{type='move',dx=2,dy=0},services))
assert(not invalid.consumes_turn and not invalid.chance_state and not s.world.chance_seed)
local unchanged,reject=RW_Commit(s,{consumes_turn=true,changes={},chance_state={from=2,to=3}})
assert(unchanged==s and reject.reason=='stale_chance_state')
unchanged,reject=RW_Commit(s,{consumes_turn=false,changes={},chance_state={from=1,to=3}})
assert(unchanged==s and reject.reason=='invalid_no_turn_plan')
print('PASS: OFTEN/SELDOM stable head/clause/identity draws, RHS AND, conversion, WORD, pure replay/rejection and Undo')

local node={op='spatial',clauses={{relation='often',negated=false,parameters={},chance_key='identity:1'}}}
local e1={id=1,class='object',x=2,y=2};local e2={id=2,class='object',x=2,y=2}
local empty1={class='empty',x=2,y=2};local empty2={class='empty',x=3,y=2}
local distinct,empty_distinct=false,false
for seed=1,128 do
 s.world.chance_seed=seed
 local a=RW_TestEntityCondition(s.world,node,e1)
 if a~=RW_TestEntityCondition(s.world,node,e2) then distinct=true end
 e1.x=3;assert(RW_TestEntityCondition(s.world,node,e1)==a);e1.x=2
 if RW_TestEntityCondition(s.world,node,empty1)~=RW_TestEntityCondition(s.world,node,empty2) then empty_distinct=true end
end
assert(distinct and empty_distinct,'real identities and virtual EMPTY cells need distinct draws')
