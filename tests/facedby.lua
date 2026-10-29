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
local s=fixture({{'AVATAR','FACEDBY','ROCK','IS','PUSH'}})
object(s.world,2,'rock',3,2,'Left')
local w,f=projection(s);assert(w.entities[1].behaviors.push)
s.world.entities[1].direction='Down';w=projection(s);assert(w.entities[1].behaviors.push)
s.world.entities[2].direction='Right';w=projection(s);assert(not w.entities[1].behaviors.push)
s=fixture({{'AVATAR','FACEDBY','NOT','ROCK','IS','PUSH'}})
object(s.world,2,'rock',3,2,'Right');w=projection(s);assert(w.entities[1].behaviors.push,'wrong-facing ROCK is a negative witness')
s.world.entities[2].direction='Left';w=projection(s);assert(not w.entities[1].behaviors.push)
s.world.entities[2].class='text';s.world.entities[2].text={name='ROCK'};s.world.entities[2].archetype=nil
w=projection(s);assert(not w.entities[1].behaviors.push,'negative noun excludes Text')
s=fixture({{'AVATAR','FACEDBY','ROCK','AND','ROCK','IS','PUSH'}})
object(s.world,2,'rock',3,2,'Left');w=projection(s);assert(not w.entities[1].behaviors.push)
object(s.world,3,'rock',2,1,'Down');w,f=projection(s);assert(w.entities[1].behaviors.push)
for id=10,16 do assert(f.active_text_ids[id]) end
s=fixture({{'AVATAR','NOT','FACEDBY','ROCK','IS','PUSH'}})
object(s.world,2,'rock',3,2,'Left');w=projection(s);assert(not w.entities[1].behaviors.push)
s.world.entities[2].direction='None';w=projection(s);assert(w.entities[1].behaviors.push)
s=fixture({{'ROCK','FACEDBY','AVATAR','BECOME','FLAG'}})
s.world.entities[1].x=5;s.world.entities[1].y=3;s.world.entities[1].direction='Right'
local n,p=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','FACEDBY','AVATAR','HAS','FLAG'},{'ROCK','IS','YOU','AND','DEFEAT'}})
s.world.entities[1].x=5;s.world.entities[1].y=3;s.world.entities[1].direction='Right'
n,p=step(s);local born=false;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then born=true end end;assert(born)
s=fixture({{'ROCK','FACEDBY','AVATAR','IS','WORD'}})
s.world.entities[1].x=5;s.world.entities[1].y=3;s.world.entities[1].direction='Right'
w,f=projection(s);assert(f.word_tokens[2]=='ROCK')
s=fixture({{'AVATAR','FACEDBY','ROCK','IS','PUSH'},{'AVATAR','IS','FLOAT'}})
object(s.world,2,'rock',3,2,'Left');w=projection(s);assert(w.entities[1].behaviors.push,'FLOAT does not filter conditions')
s=fixture({{'EMPTY','FACEDBY','ROCK','IS','PUSH'}})
s.world.entities[1]=nil;object(s.world,2,'rock',3,2,'Left')
w=projection(s);assert(w.empty_cells['2:2'].behaviors.push,'virtual Empty can be watched by real units')
print('PASS: FACEDBY incoming cardinal directions, negative wrong-facing witnesses, Text/AND/NOT, activation, conversion/HAS/WORD/FLOAT and Undo')
