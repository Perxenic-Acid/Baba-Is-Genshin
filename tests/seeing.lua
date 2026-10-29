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





local function scene(rows)
    local s=fixture(rows);s.world.entities[1].x=2;s.world.entities[1].y=3
    s.world.entities[1].direction='Right';s.world.language.nouns.WALL='wall'
    return s
end
local function projection(s)
    local f=assert(RW_CompileWorld(s.world,cs));return assert(RW_ProjectWorld(s.world,f.effects)),f
end
local s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'}})
local w,f=projection(s);assert(w.entities[1].behaviors.push)
for id=10,14 do assert(f.active_text_ids[id]) end
object(s.world,3,'crate',4,3)
s.world.rule_sources[#s.world.rule_sources+1]={when={op='always'},effects={{op='grant_trait',target={kind='id',value=3},trait='block_entry'}}}
w=projection(s);assert(not w.entities[1].behaviors.push)
s=scene({{'AVATAR','SEEING','CRATE','IS','PUSH'},{'CRATE','IS','STOP'}})
object(s.world,3,'crate',4,3);w=projection(s);assert(w.entities[1].behaviors.push,'blocking cell itself is visible')
for _,trait in ipairs({'PUSH','PULL','STOP'}) do
    s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'},{'CRATE','IS',trait}})
    object(s.world,3,'crate',4,3);w=projection(s);assert(not w.entities[1].behaviors.push,trait)
end
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'},{'CRATE','IS','STOP','AND','PHANTOM'}})
object(s.world,3,'crate',4,3);w=projection(s);assert(w.entities[1].behaviors.push)
s=scene({{'AVATAR','SEEING','CRATE','IS','PUSH'},{'CRATE','IS','STOP','AND','PHANTOM'}})
object(s.world,3,'crate',4,3);w=projection(s);assert(w.entities[1].behaviors.push,'PHANTOM remains visible')
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'},{'CRATE','IS','STOP','AND','HIDE'}})
object(s.world,3,'crate',4,3);w=projection(s);assert(w.entities[1].behaviors.push and w.entities[3].behaviors.hide)
s=scene({{'AVATAR','SEEING','CRATE','IS','PUSH'},{'CRATE','IS','HIDE'}})
object(s.world,3,'crate',4,3);w=projection(s);assert(not w.entities[1].behaviors.push)
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'}})
s.world.entities[3]={id=3,kind='object',class='text',text={name='FLAG'},x=4,y=3,direction='None'}
w=projection(s);assert(not w.entities[1].behaviors.push,'default TEXT IS PUSH blocks sight')
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'},{'TEXT','IS','NOT','PUSH'}})
s.world.entities[3]={id=3,kind='object',class='text',text={name='FLAG'},x=4,y=3,direction='None'}
w=projection(s);assert(w.entities[1].behaviors.push)
s=scene({{'AVATAR','SEEING','ROCK','AND','ROCK','IS','PUSH'}})
w=projection(s);assert(not w.entities[1].behaviors.push)
object(s.world,3,'rock',6,3);w=projection(s);assert(w.entities[1].behaviors.push,'distinct stacked witnesses')
for _,term in ipairs({'EMPTY','NOT'}) do
    local words=term=='EMPTY' and {'AVATAR','SEEING','EMPTY','AND','EMPTY','IS','PUSH'} or {'AVATAR','SEEING','NOT','EMPTY','IS','PUSH'}
    s=scene({words});w=projection(s);assert(w.entities[1].behaviors.push,'original EMPTY placeholder branch')
end
s=scene({{'AVATAR','NOT','SEEING','ROCK','IS','PUSH'}})
s.world.entities[1].direction='None';w=projection(s);assert(w.entities[1].behaviors.push)
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'},{'CRATE','NEAR','FLAG','IS','STOP'}})
object(s.world,3,'crate',4,3);w=projection(s);assert(w.entities[1].behaviors.push)
object(s.world,4,'flag',4,4);w=projection(s);assert(not w.entities[1].behaviors.push,'rule-derived conditional occlusion')
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'},{'CRATE','SEEING','AVATAR','IS','STOP'}})
object(s.world,3,'crate',4,3,'Left');w=projection(s);assert(not w.entities[1].behaviors.push,'nested SEEING blocker query')
s=scene({{'ROCK','SEEING','AVATAR','BECOME','FLAG'}})
s.world.entities[2].direction='Left';local n,p=step(s);assert(n.world.entities[2].archetype=='flag')
s=scene({{'ROCK','SEEING','AVATAR','HAS','FLAG'},{'ROCK','IS','YOU','AND','DEFEAT'}})
s.world.entities[2].direction='Left';n,p=step(s);local born=false;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then born=true end end;assert(born)
s=scene({{'ROCK','SEEING','AVATAR','IS','WORD'}})
s.world.entities[2].direction='Left';w,f=projection(s);assert(f.word_tokens[2]=='ROCK')
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'},{'AVATAR','IS','FLOAT'}})
w=projection(s);assert(w.entities[1].behaviors.push,'FLOAT does not restrict sight')
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'}})
object(s.world,3,'crate',4,3);s.world.entities[3].behaviors={block_entry=true,hide=true}
w=projection(s);assert(w.entities[1].behaviors.push,'never inherit old projected facts')
assert(not s.world._condition_rules and not s.world._condition_guard)
s=scene({{'AVATAR','SEEING','ROCK','IS','PUSH'},{'ROCK','SEEING','AVATAR','IS','HIDE'}})
s.world.entities[2].direction='Left';w=projection(s);assert(w.entities[2].behaviors.hide and not w.entities[1].behaviors.push)
s=scene({{'ROCK','SEEING','ROCK','IS','STOP'}})
s.world.entities[2].direction='Right';object(s.world,3,'rock',8,3,'Left')
assert(projection(s),'recursive visibility queries must stay bounded')
s=scene({{'AVATAR','IS','YOU'},{'CRATE','IS','STOP','AND','HIDE'}})
object(s.world,3,'crate',3,3);n,p=step(s,{type='move',dx=1,dy=0})
assert(n.world.entities[1].x==2,'HIDE preserves ordinary collision')
s=scene({{'TEXT','IS','HIDE'},{'AVATAR','SEEING','ROCK','IS','PUSH'}})
w,f=projection(s);assert(w.entities[10].behaviors.hide and f.active_text_ids[10] and w.entities[1].behaviors.push,'hidden Text still compiles')
s=scene({{'AVATAR','IS','PHANTOM'},{'AVATAR','SEEING','ROCK','IS','PUSH'},{'CRATE','IS','STOP'}})
object(s.world,3,'crate',4,3);w=projection(s);assert(not w.entities[1].behaviors.push,'observer PHANTOM does not bypass others')
print('PASS: SEEING inclusive occlusion, HIDE/PHANTOM, rule-derived/nested queries, NOT/AND/EMPTY/Text, conversion/HAS/WORD/FLOAT, recursion guards and Undo')
