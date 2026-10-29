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





services.play=RW_ResolvePlayEvents
local s=fixture({{'ROCK','PLAY','C4'}})
object(s.world,3,'rock',8,3)
local n,p=step(s);assert(#(p.events or {})==1 and #p.events[1].entity_ids==2)
assert(p.events[1].tune=='drum_snare' and p.events[1].note=='c4' and p.events[1].frequency>0)
assert(p.events[1].particles and #p.events[1].positions==2)
assert(n.world.entities[2].archetype=='rock' and not n.world.events)
local restored=RW_Undo(n);local replay,r=step(restored);assert(r.events[1].frequency==p.events[1].frequency)
s=fixture({{'ROCK','PLAY','C4'},{'ROCK','PLAY','C4'}})
n,p=step(s);assert(#(p.events or {})==2,'duplicate clauses play twice')
s=fixture({{'ROCK','PLAY','C4','AND','D4'}})
n,p=step(s);assert(#(p.events or {})==2 and p.events[1].note~=p.events[2].note)
s=fixture({{'ROCK','PLAY','C4'},{'ROCK','PLAY','NOT','C4'}})
n,p=step(s);assert(#(p.events or {})==0)
s=fixture({{'ROCK','PLAY','C4'},{'ROCK','ON','AVATAR','PLAY','NOT','C4'}})
n,p=step(s);assert(#(p.events or {})==1)
s.world.entities[1].x=6;s.world.entities[1].y=3
n,p=step(s);assert(#(p.events or {})==0)
s=fixture({{'ROCK','ON','AVATAR','PLAY','C4'}})
n,p=step(s);assert(#(p.events or {})==0)
s.world.entities[1].x=6;s.world.entities[1].y=3
n,p=step(s);assert(#(p.events or {})==1)
s=fixture({{'ROCK','IS','SLEEP','AND','SAFE','AND','FLOAT'},{'ROCK','PLAY','C4'}})
n,p=step(s);assert(#(p.events or {})==1)
s=fixture({{'ROCK','IS','YOU','AND','DEFEAT'},{'ROCK','PLAY','C4'}})
n,p=step(s);assert(#(p.events or {})==1 and not n.world.entities[2],'PLAY precedes contact destruction')
s=fixture({{'ROCK','EAT','ROCK'},{'ROCK','PLAY','C4'}})
object(s.world,3,'rock',6,3)
n,p=step(s);assert(not n.world.entities[2] and not n.world.entities[3] and #(p.events or {})==1,'PLAY precedes EAT')
s=fixture({{'AVATAR','MAKE','ROCK'},{'ROCK','PLAY','C4'}})
s.world.entities[2]=nil
n,p=step(s);assert(#(p.events or {})==0,'MAKE births first play next turn')
local _,nextp=step(n);assert(#nextp.events==1)
s=fixture({{'TEXT','PLAY','C4'}})
n,p=step(s);assert(#(p.events or {})==1 and #p.events[1].entity_ids==3)
s=fixture({{'EMPTY','PLAY','C4'}})
n,p=step(s);assert(#(p.events or {})==1 and #p.events[1].entity_ids==0 and not p.events[1].particles)
assert(#p.events[1].positions==24*24-5)
s=fixture({{'ROCK','MIMIC','FLAG'},{'FLAG','PLAY','C4'}})
n,p=step(s);assert(#(p.events or {})==1 and p.events[1].source_type=='rock')
s=fixture({{'ROCK','PLAY','FLAG'},{'ROCK','IS','C4'},{'ROCK','HAS','C4'}})
local f=assert(RW_CompileWorld(s.world,cs));assert(#f.ast==0,'notes are PLAY-only, noun RHS is invalid for PLAY')
s=fixture({{'ROCK','PLAY','C4'}})
f=assert(RW_CompileWorld(s.world,cs));assert(f.active_text_ids[10] and f.active_text_ids[11] and f.active_text_ids[12])
local events=assert(RW_ResolvePlayEvents(s.world,{{op='play',source_type='avatar',note='invalid',when={op='always'}}}))
assert(events[1].tune=='beep' and events[1].frequency==24000,'original fallback values')
print('PASS: PLAY grouped/duplicate events, notes/AND/NOT, conditions, TEXT/EMPTY/MIMIC, contact and MAKE ordering, no state persistence and Undo')
