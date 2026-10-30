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
w,f=projection(s);assert(#f.deferred==0)
s=fixture({{'AVATAR','ON','GROUP','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==0 and not w.entities[1].behaviors.float)
s=fixture({{'NOT','GROUP','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==0 and w.entities[1].behaviors.float)
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','FLOAT'}})
local ast=assert(RW_ParseRuleAST(assert(RW_ReadLines(s.world)),s.world.language))
local g,d=RW_LowerRuleAST(ast,{},s.world);assert(#g==0 and #d==2)
print('PASS: direct GROUP channels, conditional/negative membership, duplicates, HAS/TEXT/WORD/EMPTY, activation, deferred gaps and Undo')

s=fixture({{'ROCK','IS','GROUP'},{'NOT','FLAG','IS','GROUP'},{'GROUP','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==0 and w.entities[2].archetype=='rock' and w.entities[2].behaviors.float)

-- Original group transfer is a finite ordered edge pass, not unbounded closure.
s=fixture({{'ROCK','IS','GROUP'},{'GROUP2','IS','GROUP3'},{'GROUP','IS','GROUP2'},{'GROUP3','IS','FLOAT'}})
w,f=projection(s);assert(w.entities[2].behaviors.float and #f.deferred==0)
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','GROUP2'},{'GROUP2','IS','GROUP'},{'GROUP2','BECOME','FLAG'}})
n,p=step(s);assert(n.world.entities[2].archetype=='flag')
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','GROUP2'},{'ROCK','IS','NOT','GROUP'},{'GROUP2','IS','FLOAT'}})
w=projection(s);assert(w.entities[2].behaviors.float,'source exclusion is applied after raw transfers')
s=fixture({{'ROCK','IS','GROUP'},{'ROCK','IS','GROUP2'},{'GROUP','IS','NOT','GROUP2'},{'GROUP2','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float)
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','GROUP2'},{'GROUP','IS','GROUP2'},{'GROUP2','BECOME','FLAG'}})
n,p=step(s);local products=0;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then products=products+1 end end
assert(products==2,'duplicate transfer edges preserve products')
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','NEAR','AVATAR','IS','GROUP2'},{'GROUP2','IS','FLOAT'}})
object(s.world,3,'rock',15,3);s.world.entities[1].x=6;s.world.entities[1].y=3
w=projection(s);assert(w.entities[2].behaviors.float and not w.entities[3].behaviors.float)
print('PASS: GROUP ordered cross-channel transfers, conditions, cycles, raw exclusions, duplicate edges and Undo')

s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','GROUP2'}})
local many=assert(RW_ParseRuleAST(assert(RW_ReadLines(s.world)),s.world.language))
local edge=many[2];for i=3,5002 do many[i]=edge end
local limited,limit_reason=RW_LowerRuleAST(many,nil,s.world)
assert(not limited and limit_reason=='rule_complexity_limit','group transfer expansion must be bounded')

-- Complement consumers use all membership declarations, per identity.
s=fixture({{'ROCK','NEAR','AVATAR','IS','GROUP'},{'NOT','GROUP','IS','FLOAT'}})
s.world.entities[1].x=6;s.world.entities[1].y=3;object(s.world,3,'rock',15,3)
w,f=projection(s);assert(not w.entities[2].behaviors.float and w.entities[3].behaviors.float)
assert(not w.entities[10].behaviors.float,'ordinary complement excludes Text')
s=fixture({{'ROCK','IS','GROUP'},{'ROCK','IS','NOT','GROUP'},{'NOT','GROUP','IS','FLOAT'}})
w=projection(s);assert(w.entities[2].behaviors.float)
s=fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','NOT','GROUP'}})
n,p=step(s);assert(n.world.infinite_loop and p.infinite_loop,'same-group contradiction grants CRASH')
local locked,why=RW_PlanTurn(n.world,{type='wait'},services);assert(not locked and why.reason=='infinite_loop_undo_only')
s=fixture({{'ROCK','IS','GROUP'},{'NOT','GROUP','IS','GROUP'}})
n,p=step(s);assert(n.world.infinite_loop,'same-group nonmember contradiction grants CRASH')
s=fixture({{'ROCK','IS','GROUP'},{'FLAG','IS','GROUP'},{'GROUP','IS','GROUP'},{'ROCK','IS','AVATAR'}})
n,p=step(s);assert(n.world.entities[2].archetype=='rock','self group cartesian includes identity protection')
s=fixture({{'NOT','GROUP','IS','NOT','GROUP'}})
n,p=step(s);assert(not n.world.infinite_loop)
s=fixture({{'ROCK','IS','GROUP'},{'AVATAR','HAS','ROCK'},{'AVATAR','HAS','NOT','GROUP'},{'AVATAR','IS','YOU','AND','DEFEAT'}})
n,p=step(s);local rocks=0;for _,e in pairs(n.world.entities) do if e.archetype=='rock' then rocks=rocks+1 end end
assert(rocks==1,'negative group product forbids the matching HAS birth')
print('PASS: NOT GROUP per-identity complements, negative HAS, same-group CRASH/lock/Undo and cartesian identity protection')

-- GROUP condition parameters expand all live member noun declarations.
s=fixture({{'ROCK','IS','GROUP'},{'FLAG','IS','GROUP'},{'AVATAR','ON','GROUP','IS','FLOAT'}})
s.world.entities[1].x=6;s.world.entities[1].y=3
w=projection(s);assert(not w.entities[1].behaviors.float,'ON GROUP needs all expanded nouns')
object(s.world,3,'flag',6,3);w=projection(s);assert(w.entities[1].behaviors.float)
s=fixture({{'ROCK','IS','GROUP'},{'ROCK','IS','GROUP'},{'AVATAR','NEAR','GROUP','IS','FLOAT'}})
s.world.entities[1].x=6;s.world.entities[1].y=3;w=projection(s);assert(not w.entities[1].behaviors.float)
object(s.world,3,'rock',7,3);w=projection(s);assert(w.entities[1].behaviors.float,'duplicate member parameters require distinct witnesses')
s=fixture({{'ROCK','NEAR','FLAG','IS','GROUP'},{'AVATAR','ON','GROUP','IS','FLOAT'}})
s.world.entities[2].x=2;s.world.entities[2].y=2
object(s.world,3,'flag',20,20);object(s.world,4,'rock',20,20)
w=projection(s);assert(w.entities[1].behaviors.float,'any qualifying member promotes the whole noun for condition parameters')
s.world.entities[4]=nil;w=projection(s);assert(not w.entities[1].behaviors.float)
s=fixture({{'AVATAR','WITHOUT','GROUP','IS','FLOAT'}})
w=projection(s);assert(w.entities[1].behaviors.float,'missing group passes WITHOUT via a missing-name sentinel')
s=fixture({{'ROCK','IS','GROUP'},{'AVATAR','ON','GROUP','BECOME','FLAG'}})
s.world.entities[1].x=6;s.world.entities[1].y=3
n,p=step(s);assert(n.world.entities[1].archetype=='flag')
s=fixture({{'ROCK','IS','GROUP'},{'AVATAR','ON','GROUP','HAS','FLAG'},{'AVATAR','IS','YOU','AND','DEFEAT'}})
s.world.entities[1].x=6;s.world.entities[1].y=3
n,p=step(s);local found=false;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then found=true end end;assert(found)
s=fixture({{'ROCK','IS','GROUP'},{'AVATAR','ON','GROUP','IS','WORD'}})
s.world.entities[1].x=6;s.world.entities[1].y=3
w,f=projection(s);assert(f.word_tokens[1]=='AVATAR')
s=fixture({{'ROCK','ON','GROUP','IS','GROUP'}})
w,f=projection(s);assert(#f.deferred==0,'recursive group membership is a declaration')
assert(not s.world.group_members and not s.world._condition_rules)
print('PASS: GROUP condition parameters, all-member/duplicate witnesses, global conditional nouns, empty group, conversion/HAS/WORD and Undo')

s=fixture({{'TEXT','IS','GROUP'},{'AVATAR','ON','GROUP','IS','FLOAT'}})
s.world.entities[1].x=4;s.world.entities[1].y=4
s.world.entities[100]={id=100,kind='object',class='text',text={name='ROCK'},x=4,y=4,direction='None'}
s.world.next_entity_id=101
w,f=projection(s);assert(w.entities[1].behaviors.float)
for _,rule in ipairs(f.ast) do for _,id in ipairs(rule.source.sentence_entity_ids or rule.source.entity_ids) do assert(f.active_text_ids[id]) end end
s=fixture({{'EMPTY','NEAR','AVATAR','IS','GROUP'},{'AVATAR','WITHOUT','GROUP','IS','FLOAT'}})
w=projection(s);assert(w.entities[1].behaviors.float,'conditional Empty lacks real unitlists in original findgroup')

-- A movement-created recursive oscillation commits its triggering geometry.
s=fixture({{'ROCK','NOT','ON','GROUP','IS','GROUP'},{'GROUP','IS','FLOAT'},{'ROCK','ON','AVATAR','IS','YOU'}})
s.world.entities[1].x=6;s.world.entities[1].y=3;object(s.world,3,'rock',7,3)
w,f=projection(s);assert(#f.deferred==0 and w.entities[2].behaviors.control)
n,p=step(s,{type='move',dx=1,dy=0})
assert(n.world.infinite_loop and n.world.entities[2].x==7 and n.world.entities[3].x==7,'triggering overlap must commit before loop lock')
assert(not n.world._group_override and not n.world._condition_rules)
local failed,why=RW_PlanTurn(n.world,{type='wait'},services);assert(not failed and why.reason=='infinite_loop_undo_only')
local unchanged,reject=RW_Commit(n,{consumes_turn=true,changes={}});assert(unchanged==n and reject.reason=='infinite_loop_undo_only')
assert(RW_Undo(n).world==s.world and not s.world.infinite_loop)
s=fixture({{'ROCK','NEAR','GROUP','IS','GROUP'},{'AVATAR','NEAR','GROUP','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==0 and not w.entities[1].behaviors.float,'unseeded positive recursion stays empty')
s=fixture({{'ROCK','IS','GROUP'},{'FLAG','NEAR','GROUP','IS','GROUP'},{'AVATAR','NEAR','GROUP','IS','FLOAT'}})
object(s.world,3,'flag',6,3);object(s.world,4,'flag',7,3)
w,f=projection(s);assert(#f.deferred==0)
print('PASS: recursive GROUP convergence/empty grounding, movement-triggered oscillation commits, only-Undo lock and restored geometry')

s=fixture({{'IDLE','ROCK','NOT','ON','GROUP','IS','GROUP'},{'GROUP','IS','FLOAT'}})
object(s.world,3,'rock',6,3)
w=projection(s);assert(not s.world.last_input)
n,p=step(s);assert(n.world.infinite_loop and n.world.last_input=='wait' and not s.world.infinite_loop,'input-triggered recursive loop commits its command state')
local invalid=RW_PlanTurn(s.world,{type='move',dx=2,dy=0},services);assert(invalid and not invalid.consumes_turn)
local tree={session=s};local ts={};for k,v in pairs(services) do ts[k]=v end
 ts.active=function(t) return t.session end
 ts.commit_session=RW_Commit
 ts.update=function(t,session) return {session=session} end
local tree_plan=assert(RW_PlanLevelAction(tree,{type='wait'},ts))
assert(tree_plan.before==tree and tree_plan.after.session.world.infinite_loop and not tree.session.world.infinite_loop)
assert(RW_Undo(tree_plan.after.session).world==s.world)
print('PASS: input-triggered recursive GROUP loop commits through whole-tree navigation without accepting invalid input')

-- Frozen contact refresh must lock after retaining the death/HAS that removed grounding.
s=fixture({{'ROCK','WITHOUT','FLAG','IS','GROUP'},{'ROCK','NOT','ON','GROUP','IS','GROUP'},{'GROUP','IS','FLOAT'},{'AVATAR','IS','YOU','AND','DEFEAT'},{'AVATAR','HAS','FLAG'}})
object(s.world,3,'rock',6,3)
w=projection(s)
n,p=step(s);local flag=false;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then flag=true end end
assert(n.world.infinite_loop and not n.world.entities[1] and flag,'contact/HAS-triggered group loop must commit prior phases')
assert(RW_Undo(n).world==s.world and s.world.entities[1])
print('PASS: recursive GROUP contact refresh commits DEFEAT/HAS trigger before only-Undo lock')

-- Negative-source membership iterates declaration names before conditions/bans.
local function negative_fixture(rows)
 local result=fixture(rows)
 for _,e in pairs(result.world.entities) do if e.class=='text' then e.y=7+(e.y-7)*3 end end
 return result
end
s=negative_fixture({{'ROCK','IS','GROUP'},{'NOT','GROUP','IS','GROUP2'},{'GROUP2','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==0 and w.entities[1].behaviors.float and not w.entities[2].behaviors.float)
s=negative_fixture({{'ROCK','ON','AVATAR','IS','GROUP'},{'NOT','GROUP','IS','GROUP2'},{'GROUP2','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float,'conditional declaration presence participates before its condition')
s=negative_fixture({{'ROCK','IS','GROUP'},{'GROUP','IS','GROUP2'},{'NOT','GROUP2','IS','GROUP3'},{'GROUP3','IS','FLOAT'}})
w=projection(s);assert(w.entities[2].behaviors.float,'positive transfer products are not negative solver base declarations')
s=negative_fixture({{'ROCK','IS','GROUP2'},{'NOT','GROUP','IS','NOT','GROUP2'},{'GROUP2','IS','FLOAT'}})
w=projection(s);assert(not w.entities[2].behaviors.float)
s=negative_fixture({{'ROCK','IS','GROUP'},{'NOT','GROUP','IS','GROUP2'},{'NOT','GROUP','IS','GROUP2'},{'GROUP2','BECOME','FLAG'}})
n,p=step(s);local flags=0;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then flags=flags+1 end end
assert(flags==2 and n.world.entities[2].archetype=='rock','duplicate negative edges preserve products')
-- Push the final noun into a second inverse edge: the triggering words must commit.
s=fixture({{'NOT','GROUP2','IS','GROUP'},{'NOT','GROUP','IS'},{'AVATAR','IS','YOU'}})
s.world.entities[1].x=4;s.world.entities[1].y=10
local id=s.world.next_entity_id;s.world.next_entity_id=id+1
s.world.entities[id]={id=id,kind='object',class='text',text={name='GROUP2'},x=4,y=9,direction='None'}
w,f=projection(s);assert(#f.deferred==0)
n,p=step(s,{type='move',dx=0,dy=-1})
assert(n.world.infinite_loop and n.world.entities[id].y==8 and n.world.entities[1].y==9)
assert(RW_Undo(n).world==s.world and s.world.entities[id].y==9)
local blocked,why=RW_PlanLevelAction({session=n},{type='confirm'},{active=function(t) return t.session end})
assert(not blocked and why.reason=='infinite_loop_undo_only')
s=fixture({{'NOT','GROUP','IS','GROUP2'},{'GROUP2','IS','FLOAT'}})
local rules=assert(RW_ParseRuleAST(assert(RW_ReadLines(s.world)),s.world.language))
local edge=rules[1];for i=3,math.floor(5000/#RW_NounPalette(s.world))+4 do rules[i]=edge end
local result,reason=RW_LowerRuleAST(rules,nil,s.world);assert(not result and reason=='rule_complexity_limit')
assert(not s.world.negative_base and not s.world._condition_rules)
print('PASS: negative-source GROUP declaration iteration, conditions, positive-transfer ordering, duplicate products, bounds and triggering-move Infinite Loop/Undo')

-- Ordinary NOT subjects expand after membership transfers, with literal bans.
s=negative_fixture({{'NOT','ROCK','IS','GROUP'},{'GROUP','IS','FLOAT'}})
w,f=projection(s);assert(#f.deferred==0 and w.entities[1].behaviors.float and not w.entities[2].behaviors.float)
s=negative_fixture({{'NOT','ROCK','IS','GROUP'},{'GROUP','IS','GROUP2'},{'GROUP2','IS','FLOAT'}})
w=projection(s);assert(w.entities[1].behaviors.float and not w.entities[2].behaviors.float)
s=negative_fixture({{'NOT','ROCK','IS','GROUP'},{'NOT','ROCK','IS','NOT','GROUP'},{'GROUP','IS','FLOAT'}})
w=projection(s);assert(w.entities[1].behaviors.float,'literal negative-source exclusion does not ban expanded concrete members')
s=negative_fixture({{'NOT','ROCK','IS','GROUP'},{'AVATAR','IS','NOT','GROUP'},{'GROUP','IS','FLOAT'}})
w=projection(s);assert(not w.entities[1].behaviors.float)
s=negative_fixture({{'NOT','TEXT','IS','GROUP'},{'GROUP','IS','FLOAT'}})
w=projection(s);assert(w.entities[1].behaviors.float and w.entities[2].behaviors.float and not w.entities[10].behaviors.float)
s=negative_fixture({{'NOT','ROCK','IS','GROUP'},{'NOT','ROCK','IS','GROUP'},{'GROUP','BECOME','FLAG'}})
n,p=step(s);local count=0;for _,e in pairs(n.world.entities) do if e.archetype=='flag' then count=count+1 end end
assert(count==2 and n.world.entities[2].archetype=='rock')
print('PASS: ordinary NOT noun GROUP delayed expansion, literal/concrete bans, channels, duplicate conversion and Undo')
