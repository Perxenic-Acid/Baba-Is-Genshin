local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,
    refresh=RW_EvaluateRules,contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},rules) end,
    evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
    local s=RW_CreateSession();local w=s.world;w.height=32;w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag"
    assert(w.language.properties.YOU2=="you2")
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Up"},
        [2]={id=2,kind="object",class="object",archetype="rock",x=5,y=2,direction="Up"}}
    w.next_entity_id=10
    for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="None"} end end
    return s
end
local function step(s,player)
    local p,e=RW_PlanTurn(s.world,{type="move",dx=1,dy=0,player=player},services);assert(p,e and e.reason)
    local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n,p
end
local s=fixture({{"AVATAR","IS","YOU"},{"ROCK","IS","YOU2"}})
local n=step(s,1);assert(n.world.entities[1].x==3 and n.world.entities[2].x==5)
n=step(s,2);assert(n.world.entities[1].x==2 and n.world.entities[2].x==6)
assert(s.world.entities[1].x==2 and s.world.entities[2].x==5)
s=fixture({{"AVATAR","IS","YOU"}});n=step(s,2);assert(n.world.entities[1].x==3,"secondary fallback failed")
s=fixture({{"AVATAR","IS","YOU"},{"ROCK","IS","YOU2"},{"ROCK","IS","SLEEP"}})
n=step(s,2);assert(n.world.entities[1].x==2 and n.world.entities[2].x==5,"sleeping YOU2 must prevent fallback")
s=fixture({{"AVATAR","IS","YOU"},{"ROCK","IS","YOU2"},{"ROCK","IS","NOT","YOU2"}})
n=step(s,2);assert(n.world.entities[1].x==3 and n.world.entities[2].x==5)
s=fixture({{"AVATAR","IS","YOU2"},{"AVATAR","IS","YOU"}});n=step(s,2);assert(n.world.entities[1].x==3,"dual channel double-stepped")
-- Secondary motion uses the ordinary collision/blocked facing/PUSH solver.
s=fixture({{"AVATAR","IS","YOU2"},{"ROCK","IS","PUSH"}});s.world.entities[2].x=3
n=step(s,2);assert(n.world.entities[1].x==3 and n.world.entities[2].x==4 and n.world.entities[2].direction=="Right")
s=fixture({{"AVATAR","IS","YOU2"},{"ROCK","IS","STOP"}});s.world.entities[2].x=3
n=step(s,2);assert(n.world.entities[1].x==2 and n.world.entities[1].direction=="Right")
-- WIN/DEFEAT are independent of which channel supplied the current input.
s=fixture({{"AVATAR","IS","YOU2"},{"ROCK","IS","WIN"}});s.world.entities[2].x=2
local f=assert(RW_CompileWorld(s.world,cs));local projected=assert(RW_ProjectWorld(s.world,f.effects))
assert(RW_HasWinContact(projected));assert(RW_ResolveLevelPropertyOutcome(projected,{"win"})=="win")
assert(#RW_LevelSelectionCandidates(projected)==0)
s=fixture({{"AVATAR","IS","YOU2"},{"AVATAR","IS","DEFEAT"}})
n=step(s,1);assert(not n.world.entities[1],"self-DEFEAT omitted YOU2")
s=fixture({{"AVATAR","IS","YOU2"},{"AVATAR","IS","BROKEN"}})
n=step(s,2);assert(n.world.entities[1].x==2 and n.world.entities[1].broken==1)
-- EMPTY declaration placeholder prevents fallback even with no qualifying cells.
s=fixture({{"AVATAR","IS","YOU"},{"EMPTY","NEAR","FLAG","IS","YOU2"}})
f=assert(RW_CompileWorld(s.world,cs));projected=assert(RW_ProjectWorld(s.world,f.effects))
assert(projected.empty_control2_declared)
n=step(s,2);assert(n.world.entities[1].x==2 and not n.world.empty_control2_declared)
s=fixture({{"AVATAR","IS","YOU"},{"EMPTY","IS","YOU2"},{"EMPTY","IS","NOT","YOU2"}})
n=step(s,2);assert(n.world.entities[1].x==3)
-- Scoped LEVEL channel selection and fallback are independent of unit channels.
s=fixture({{"LEVEL","IS","YOU2"}});s.world.language.nouns.LEVEL={tag="level",block_type="level_block"}
n=step(s,2);assert(n.world.board_offset.x==1)
local primary=step(s,1);assert(not primary.world.board_offset or primary.world.board_offset.x==0)
-- Invalid channels reject without input/chance/RNG changes.
local bad,e=RW_PlanTurn(s.world,{type="move",dx=1,dy=0,player=4},services);assert(not bad and e.reason=="invalid_player")
assert(not s.world.last_input and not s.world.chance_seed)
-- A defeated tree permits SELECT displacement but freezes both YOU channels.
s=fixture({{"AVATAR","IS","YOU2"}})
s.world.entities[3]={id=3,kind="object",class="object",archetype="cursor",x=2,y=4,direction="None"}
s.world.entities[4]={id=4,kind="object",class="object",archetype="line",x=3,y=4,direction="None"}
local nav={};for k,v in pairs(services) do nav[k]=v end
nav.active=RW_GetActiveLevel;nav.update=RW_UpdateActiveLevel;nav.enter=RW_EnterLevel;nav.return_level=RW_ReturnLevel
nav.selectors=RW_LevelSelectorIDs;nav.place_selectors=RW_PlaceLevelSelectors;nav.bind_entry=RW_BindLevelEntry
nav.commit_session=RW_Commit;nav.outcome=RW_RecordLevelOutcome;nav.candidates=RW_LevelSelectionCandidates
nav.win=RW_HasWinContact;nav.level_outcome=RW_ResolveLevelPropertyOutcome
local tree=assert(RW_CreateLevelTree({root=assert(RW_CreateLevelDefinition("root",s.world))},"root"))
tree=assert(RW_RecordLevelOutcome(tree,"defeat"))
local turn,err=RW_PlanLevelAction(tree,{type="move",dx=1,dy=0,player=2},nav);assert(turn,err and err.reason)
local selected,res=RW_CommitLevelTree(tree,turn);assert(res.accepted)
assert(RW_GetActiveLevel(selected).world.entities[1].x==2 and RW_GetActiveLevel(selected).world.entities[3].x==3)
assert(RW_UndoLevelTree(selected).active_id==tree.active_id)
-- Execute the installed player-list selection branch unchanged. Empty's sentinel
-- counts for fallback even when its cell table has no eligible positions.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],"rb"));local source=file:read("*a");file:close()
local branch=assert(source:match("(\t\t\t\tif %(playerid == 1%) then.-)\n\t\t\t\tlocal fdir"))
local env=setmetatable({},{__index=_G})
local original=assert(load("return function(playerid) local players,players2,empty,empty2={},{},{},{} "..branch.." return players end","@installed_player_selection","t",env))()
local cases=0
for you=0,3 do for you2=0,3 do for sleep=0,3 do for empty=0,1 do for player=1,2 do
    local function bit(mask,id) return math.floor(mask/2^(id-1))%2==1 end
    local world={width=20,height=10,entities={},empty_control2_declared=empty==1}
    for id=1,2 do world.entities[id]={id=id,x=id*4,y=2,direction="Right",behaviors={control=bit(you,id),control2=bit(you2,id),sleep=bit(sleep,id)}} end
    -- Use a distinct Empty sentinel in the adapter result (the original host's
    -- special ID=2 cannot collide with real fixed IDs; our real IDs may equal 2).
    env.findallfeature=function(_,_,trait)
        local list={};for id=1,2 do if bit(trait=="you2" and you2 or you,id) then list[#list+1]=id+10 end end
        if trait=="you2" and empty==1 then list[#list+1]=2 end
        return list,{}
    end
    local selected={};for _,id in ipairs(original(player)) do if id~=2 then selected[id-10]=true end end
    local movement=RW_ResolveTurn(world,{type="move",dx=1,dy=0,player=player})
    local moved={};for _,change in ipairs(movement.changes) do if change.kind=="move" then moved[change.entity_id]=true end end
    for id=1,2 do assert((moved[id]==true)==(selected[id]==true and not bit(sleep,id)),"installed channel selection mismatch") end
    cases=cases+1
end end end end end
assert(cases==256)
print("PASS: YOU2 independent channel/fallback, sleeping/negative/dual controllers, PUSH/blocked facing, contacts, BROKEN, EMPTY placeholder, LEVEL, atomic Undo and installed channel-selection oracle (256 cases)")

-- Dual input is one scheduled turn and one Undo; absent channels wait, no fallback.
s=fixture({{"AVATAR","IS","YOU"},{"ROCK","IS","YOU2"}})
local function dual(a,b,c,d)
 local p,e=RW_PlanTurn(s.world,{type="move",player=3,dx=a,dy=b,dx2=c,dy2=d},services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n
end
n=dual(1,0,0,1);assert(n.world.entities[1].x==3 and n.world.entities[2].y==3)
n=dual(0,0,-1,0);assert(n.world.entities[1].x==2 and n.world.entities[2].x==4)
n=dual(0,0,0,0);assert(n.world.entities[1].x==2 and n.world.entities[2].x==5)
s=fixture({{"AVATAR","IS","YOU"},{"AVATAR","IS","YOU2"}})
n=dual(1,0,0,1);assert(n.world.entities[1].x==3 and n.world.entities[1].y==2)
n=dual(0,0,0,1);assert(n.world.entities[1].x==2 and n.world.entities[1].y==3)
s=fixture({{"AVATAR","IS","YOU2"}});n=dual(1,0,0,0);assert(n.world.entities[1].x==2)
print("TEST PASSED: simultaneous YOU/YOU2 independent intents and atomic Undo")

s=fixture({{"AVATAR","IS","YOU"},{"ROCK","IS","YOU2"},{"FLAG","IS","STOP"}})
s.world.entities[3]={id=3,kind="object",class="object",archetype="flag",x=3,y=2,direction="None"}
n=dual(1,0,0,1);assert(n.world.entities[1].x==2 and n.world.entities[1].direction=="Right" and n.world.entities[2].y==3)
s=fixture({{"AVATAR","IS","YOU"},{"ROCK","IS","YOU2"},{"ROCK","IS","DEFEAT"}})
s.world.entities[2].x=4
n=dual(1,0,-1,0);assert(not n.world.entities[1] and not n.world.entities[2],"both final contacts must share one phase")
services.more=function(w,p) return RW_PlanCreate(w,RW_ResolveMoreProducts(p)) end
s=fixture({{"AVATAR","IS","YOU"},{"ROCK","IS","YOU2"},{"AVATAR","IS","MORE"}})
n=dual(1,0,0,1);local count=0;for _,e in pairs(n.world.entities) do if e.archetype=="avatar" then count=count+1 end end
assert(count==5,"two inputs must not run creation twice: "..count)
n=dual(0,0,0,0);assert(n.world.last_input=="wait")
n=dual(0,0,0,1);assert(n.world.last_input=="move")
local p,e=RW_PlanTurn(s.world,{type="move",player=3,dx=0,dy=0,dx2=1,dy2=1},services)
assert(p and not p.consumes_turn and p.reason=="invalid_direction");assert(not s.world.last_input and not s.world.chance_seed)
print("PASS: dual input blocked facing, shared destruction/creation, IDLE state and invalid direction purity")

-- Execute the installed direction/been_seen collection code with host queries stubbed.
local collect=assert(source:match("(\t\t\t\tlocal fdir = 4.-)\n\t\t\t\tfdir = 4"))
local oracle_env=setmetatable({XPOS=1,YPOS=2},{__index=_G})
local collect_original=assert(load("return function(players,players2,dir_,dir_2) local playerid=3; local moving_units,been_seen,empty={},{},{} "..collect.." return moving_units end","@installed_dual_collection","t",oracle_env))()
local vectors={{1,0},{0,-1},{-1,0},{0,1},{0,0}}
local count=0
for mask=0,15 do for a=1,5 do for b=1,5 do
 local w={width=20,height=15,entities={}};local first,second={},{}
 for id=1,2 do
  local one=math.floor(mask/2^(id-1))%2==1;local two=math.floor(mask/2^(id+1))%2==1
  w.entities[id]={id=id,x=id*5,y=6,direction="Right",behaviors={control=one,control2=two}}
  if one then first[#first+1]=id+10 end;if two then second[#second+1]=id+10 end
 end
 local all={};for _,id in ipairs(first) do all[#all+1]=id end;for _,id in ipairs(second) do all[#all+1]=id end
 oracle_env.mmf={newObject=function(id) local u=w.entities[id-10];return {values={u.x,u.y}} end}
 oracle_env.getname=function() return "unit" end;oracle_env.hasfeature=function() return nil end
 oracle_env.cantmove=function() return false end;oracle_env.updatedir=function() end
 local expected={};for _,item in ipairs(collect_original(all,second,a-1,b-1)) do expected[item.unitid-10]=vectors[item.dir+1] end
 local plan=RW_ResolveTurn(w,{type="move",player=3,dx=vectors[a][1],dy=vectors[a][2],dx2=vectors[b][1],dy2=vectors[b][2]})
 assert(plan.consumes_turn);local actual={};for _,op in ipairs(plan.changes) do if op.kind=="move" then actual[op.entity_id]={op.to.x-op.from.x,op.to.y-op.from.y} end end
 for id=1,2 do local x,y=expected[id],actual[id];assert((x==nil)==(y==nil));if x then assert(x[1]==y[1] and x[2]==y[2]) end end
 count=count+1
end end end
assert(count==400);print("PASS: installed simultaneous direction/seen-identity oracle (400 cases)")

s=fixture({{"LEVEL","IS","YOU2"}});s.world.language.nouns.LEVEL={tag="level",block_type="level_block"}
n=dual(1,0,0,1);assert(n.world.board_offset.x==1 and n.world.board_offset.y==0)
n=dual(0,0,0,1);assert(not n.world.board_offset or n.world.board_offset.x==0)
local wait_plan=assert(RW_PlanTurn(s.world,{type="wait",player=3},services))
local waited,accepted=RW_Commit(s,wait_plan);assert(accepted.accepted and waited.world.last_input=="wait")
assert(RW_Undo(waited).world==s.world)
print("PASS: simultaneous scoped LEVEL first-direction preference and wait shorthand")
