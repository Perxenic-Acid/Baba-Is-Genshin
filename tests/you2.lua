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
local bad,e=RW_PlanTurn(s.world,{type="move",dx=1,dy=0,player=3},services);assert(not bad and e.reason=="invalid_player")
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
