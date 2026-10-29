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
