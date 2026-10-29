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
    w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.language.nouns.LEVEL={tag='level',block_type='level_block'}
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





local function projected(s)
    local f=assert(RW_CompileWorld(s.world,cs));return assert(RW_ProjectWorld(s.world,f.effects)),f
end
local s=fixture({{'AVATAR','WITHOUT','ROCK','IS','PUSH'}})
local w,f=projected(s);assert(not w.entities[1].behaviors.push)
s.world.entities[2]=nil;w=projected(s);assert(w.entities[1].behaviors.push)
s=fixture({{'ROCK','WITHOUT','ROCK','IS','PUSH'}})
w=projected(s);assert(w.entities[2].behaviors.push,'exclude source identity')
s.world.entities[3]={id=3,kind='object',class='object',archetype='rock',x=10,y=3,direction='Down'}
w=projected(s);assert(not w.entities[2].behaviors.push)
s=fixture({{'AVATAR','WITHOUT','ROCK','AND','ROCK','IS','PUSH'}})
w,f=projected(s);assert(w.entities[1].behaviors.push,'duplicate quantity threshold')
for id=10,16 do assert(f.active_text_ids[id]) end
s=fixture({{'AVATAR','NOT','WITHOUT','ROCK','AND','FLAG','IS','PUSH'}})
w=projected(s);assert(not w.entities[1].behaviors.push,'NOT WITHOUT requires all parameter quotas, not just one')
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=10,y=3,direction='None'}
w=projected(s);assert(w.entities[1].behaviors.push)
s=fixture({{'ROCK','WITHOUT','AVATAR','BECOME','FLAG'}})
s.world.entities[1]=nil
local n,p=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','WITHOUT','AVATAR','HAS','FLAG'},{'ROCK','IS','YOU','AND','DEFEAT'}})
s.world.entities[1]=nil
n,p=step(s);local born=false;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then born=true end end;assert(born)
s=fixture({{'ROCK','WITHOUT','AVATAR','IS','WORD'}})
s.world.entities[1]=nil;w,f=projected(s);assert(f.word_tokens[2]=='ROCK')
s=fixture({{'AVATAR','WITHOUT','TEXT','IS','PUSH'}})
w=projected(s);assert(not w.entities[1].behaviors.push)
s=fixture({{'AVATAR','WITHOUT','LEVEL','IS','PUSH'}})
w=projected(s);assert(not w.entities[1].behaviors.push)
s=fixture({{'AVATAR','NOT','WITHOUT','LEVEL','IS','PUSH'}})
w=projected(s);assert(w.entities[1].behaviors.push)
s=fixture({{'ROCK','MIMIC','FLAG'},{'ROCK','WITHOUT','AVATAR','AND','FLAG','MIMIC','NOT','FLAG'},{'FLAG','IS','PUSH'}})
w=projected(s);assert(not w.entities[2].behaviors.push,'original invertconds preserves NOT WITHOUT quota semantics')
s.world.entities[3]={id=3,kind='object',class='object',archetype='flag',x=10,y=3,direction='None'}
w=projected(s);assert(w.entities[2].behaviors.push)
print('PASS: WITHOUT identity exclusion/count thresholds/NOT, activation, conversion/HAS/WORD and Undo')
