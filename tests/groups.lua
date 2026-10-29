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
local s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','FLOAT'}})
local w,f=projection(s);assert(w.entities[2].behaviors.float and not w.entities[1].behaviors.float)
assert(#f.deferred==0 and #f.ast==2)
for id=10,15 do assert(f.active_text_ids[id]) end
local n,p=step(s);assert(n.world.entities[2].archetype=='rock','membership never converts')
assert(not table.concat(RW_NounPalette(s.world),','):find('group',1,true))
for _,name in ipairs({'GROUP','GROUP2','GROUP3'}) do
 s=fixture({{'ROCK','IS',name},{name,'IS','FLOAT'}})
 w=projection(s);assert(w.entities[2].behaviors.float)
end
s=fixture({{'ROCK','IS','GROUP2'},{'GROUP','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float)
s=fixture({{'ROCK','NEAR','AVATAR','IS','GROUP'},{'GROUP','IS','FLOAT'}})
s.world.entities[1].x=6;s.world.entities[1].y=3;object(s.world,3,'rock',15,3)
w=projection(s);assert(w.entities[2].behaviors.float and not w.entities[3].behaviors.float)
s=fixture({{'ROCK','IS','GROUP'},{'ROCK','IS','NOT','GROUP'},{'GROUP','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float)
s=fixture({{'ROCK','IS','GROUP'},{'ROCK','NEAR','AVATAR','IS','NOT','GROUP'},{'GROUP','IS','FLOAT'}})
s.world.entities[1].x=6;s.world.entities[1].y=3;object(s.world,3,'rock',15,3)
w=projection(s);assert(not w.entities[2].behaviors.float and w.entities[3].behaviors.float)
s=fixture({{'ROCK','IS','GROUP'},{'ROCK','IS','GROUP'},{'GROUP','BECOME','FLAG'}})
n,p=step(s);local count=0;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then count=count+1 end end
assert(count==2,'duplicate memberships generate duplicate products')
s=fixture({{'ROCK','IS','GROUP'},{'FLAG','IS','GROUP'},{'AVATAR','HAS','GROUP'},{'AVATAR','IS','YOU','AND','DEFEAT'}})
n,p=step(s);local rocks,flags=0,0;for _,e in pairs(n.world.entities) do
 if e.archetype=='rock' then rocks=rocks+1 elseif e.archetype=='flag' then flags=flags+1 end
end;assert(rocks==2 and flags==1 and not n.world.entities[1])
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','TEXT'}})
n,p=step(s);assert(n.world.entities[2].class=='text' and n.world.entities[2].text.name=='ROCK')
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','WORD'}})
w,f=projection(s);assert(f.word_tokens[2]=='ROCK')
s=fixture({{'TEXT','IS','GROUP'},{'GROUP','IS','SAFE'}})
w=projection(s);assert(w.entities[10].behaviors.safe)
s=fixture({{'EMPTY','IS','GROUP'},{'GROUP','IS','SAFE'}})
w=projection(s);assert(w.empty_cells['1:1'].behaviors.safe)
s=fixture({{'GROUP','IS','GROUP2'},{'GROUP2','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==1)
s=fixture({{'AVATAR','ON','GROUP','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==1 and not w.entities[1].behaviors.float)
s=fixture({{'NOT','GROUP','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==1)
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','FLOAT'}})
local ast=assert(RW_ParseRuleAST(assert(RW_ReadLines(s.world)),s.world.language))
local g,d=RW_LowerRuleAST(ast,{},s.world);assert(#g==0 and #d==2)
print('PASS: direct GROUP channels, conditional/negative membership, duplicates, HAS/TEXT/WORD/EMPTY, activation, deferred gaps and Undo')

s=fixture({{'ROCK','IS','GROUP'},{'NOT','FLAG','IS','GROUP'},{'GROUP','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==1 and w.entities[2].archetype=='rock')
