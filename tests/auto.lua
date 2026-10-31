local directions={"Right","Up","Left","Down"}
local vectors={Right={1,0},Up={0,-1},Left={-1,0},Down={0,1}}
local opposite={Right="Left",Up="Down",Left="Right",Down="Up"}
local function projected(moves,autos,chills,seed,sleep,still)
 local w=RW_CreateSession().world;w.width=30;w.height=30;w.random_state=seed
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=12,y=12,direction="Right",
  behaviors={move=moves>0,auto=autos>0,chill=chills>0,sleep=sleep,still=still}}}
 w.next_entity_id=10;w.trait_counts={[1]={move=moves,auto=autos,chill=chills}};return w
end
local function raw(w)
 local r={};for k,v in pairs(w) do if k~="trait_counts" then r[k]=v end end;r.entities={}
 for id,e in pairs(w.entities) do local c={};for k,v in pairs(e) do if k~="behaviors" then c[k]=v end end;r.entities[id]=c end
 return r
end
-- Original collection and the original state-3 reversal guard, not copied logic.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],"rb"));local source=f:read("*a");f:close()
local first=assert(source:find("function add_moving_units(",1,true));local last=source:find("\nfunction ",first+1,true)
local collection=source:sub(first,last and last-1 or #source)
local guard=assert(source:match('elseif %(state == 3%) then%s*if (.-) then'))
local reverses=assert(load('return function(data) return '..guard..' end',"installed reversal guard"))()
local cases=0
for moves=0,2 do for autos=0,2 do for chills=0,1 do for seed=1,8 do for sleep=0,1 do for still=0,1 do
 local state=seed;local unit={values={dir=0,x=12,y=12}}
 local env={ipairs=ipairs,pairs=pairs,table=table,DIR="dir",XPOS="x",YPOS="y",mmf={newObject=function() return unit end},getname=function() return "avatar" end,
  hasfeature=function() return sleep==1 and true or nil end,cantmove=function() return still==1 end,updatedir=function(_,d) unit.values.dir=d end,
  fixedrandom=function() state=state*48271%2147483647;return state%4 end}
 assert(load(collection,"installed MOVE/AUTO/CHILL collection","t",env))()
 local list,seen={},{}
 for _,spec in ipairs({{"move",moves},{"auto",autos},{"chill",chills}}) do local ids={};for i=1,spec[2] do ids[i]=1 end
  list,seen=env.add_moving_units(spec[1],ids,list,seen,{})
 end
 local w=projected(moves,autos,chills,seed,sleep==1,still==1)
 local d=directions[unit.values.dir+1];local v=vectors[d]
 -- Stop immediately in the collected final facing; a bounced move has ample room.
 w.entities[2]={id=2,kind="object",class="object",archetype="rock",x=12+v[1],y=12+v[2],direction="None",behaviors={block_entry=true}}
 local p=RW_ResolveAutomatic(w);local after=assert(RW_PreviewPlan(raw(w),p))
 local expected_dir=d;local distance=0
 if #list>0 and reverses(list[1]) then expected_dir=opposite[d];distance=list[1].moves end
 local displacement=vectors[expected_dir]
 assert(after.entities[1].x==12+displacement[1]*distance and after.entities[1].y==12+displacement[2]*distance,"original AUTO movement/reversal mismatch")
 assert(after.entities[1].direction==expected_dir,"original AUTO collected facing mismatch")
 assert((p.random_state and p.random_state.to or seed)==state and w.random_state==seed)
 cases=cases+1
end end end end end end
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local lifecycle={victims=RW_ResolveContactVictims,birth_products=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete,
 births=function(w,ids,c,rules) local p,e=RW_PlanHasBirths(w,ids,c);if not p then return nil,e end;return RW_InitializeBirthSpecifications(w,p,rules) end}
local services={status=RW_PlanRuleStatus,project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,automatic=RW_ResolveAutomatic,
 destroy=function(w,ids,c,k,deaths,rules) return RW_PlanDestructionPhase(w,ids,c,k,lifecycle,deaths,rules) end,
 contact=function(w,p,k,c,rules) return RW_PlanContactPhase(w,p,k,c,lifecycle,rules) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules,f.code_status end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width=24;w.height=24;w.language.nouns.ROCK="rock";w.language.nouns.FLAG="flag";w.language.nouns.LEVEL={tag="level",block_type="level_block"}
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=12,y=18,direction="Right"},[2]={id=2,kind="object",class="object",archetype="rock",x=13,y=18,direction="Left"}};w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
 w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"} end end
 assert(w.language.properties.AUTO=="auto");return s
end
local function step(s)
 local p,e=RW_PlanTurn(s.world,{type="wait"},services);assert(p,e and e.reason)
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(RW_Undo(n).world==s.world);return n,p
end
local s=fixture({{"AVATAR","IS","AUTO"},{"ROCK","IS","STOP"}});local n,p=step(s);assert(n.world.entities[1].x==12 and n.world.entities[1].direction=="Right")
s=fixture({{"AVATAR","IS","AUTO","AND","MOVE"},{"ROCK","IS","STOP"}});n=step(s);assert(n.world.entities[1].x==10 and n.world.entities[1].direction=="Left")
s=fixture({{"AVATAR","IS","AUTO"},{"AVATAR","IS","AUTO"},{"ROCK","IS","PUSH"}});n=step(s);assert(n.world.entities[1].x==14 and n.world.entities[2].x==15 and n.world.entities[2].direction=="Right")
s=fixture({{"AVATAR","IS","AUTO","AND","WEAK"},{"AVATAR","HAS","FLAG"},{"ROCK","IS","STOP"}});n=step(s)
assert(not n.world.entities[1] and n.world.entities[s.world.next_entity_id].archetype=="flag" and n.world.entities[s.world.next_entity_id].x==12)
s=fixture({{"AVATAR","IS","AUTO","AND","BROKEN"}});n=step(s);assert(n.world.entities[1].x==12)
s=fixture({{"AVATAR","IS","AUTO"},{"AVATAR","IS","NOT","AUTO"}});n=step(s);assert(n.world.entities[1].x==12)
s=fixture({{"AVATAR","ON","ROCK","IS","AUTO"}});s.world.entities[2].x=12;n=step(s);assert(n.world.entities[1].x==13)
s=fixture({{"AVATAR","IS","AUTO","AND","REVERSE"}});n=step(s);assert(n.world.entities[1].x==11 and n.world.entities[1].direction=="Right")
s=fixture({{"AVATAR","IS","AUTO","AND","SLEEP"}});n=step(s);assert(n.world.entities[1].x==12)
s=fixture({{"AVATAR","IS","AUTO","AND","LOCKEDRIGHT"}});n=step(s);assert(n.world.entities[1].x==12)
s=fixture({{"AVATAR","IS","AUTO","AND","CHILL"},{"ROCK","IS","STOP"}});s.world.entities[2].x=12;s.world.entities[2].y=19;n=step(s)
assert(n.world.entities[1].y==18 and n.world.entities[1].direction=="Down","AUTO-first CHILL must not bounce")
s=fixture({{"AVATAR","IS","AUTO","AND","CHILL","AND","LOCKEDRIGHT"},{"ROCK","IS","STOP"}});s.world.entities[2].x=12;s.world.entities[2].y=19;n=step(s)
assert(n.world.entities[1].y==17 and n.world.entities[1].direction=="Up","uncollected locked AUTO must not suppress CHILL bounce")
for _,dir in ipairs({"Mid","None"}) do s=fixture({{"AVATAR","IS","AUTO"}});s.world.entities[1].direction=dir;n=step(s);assert(n.world.entities[1].x==12 and n.world.entities[1].direction==dir) end
local function scoped(rows)
 local w=fixture(rows).world;local frame=assert(RW_CompileWorld(w,cs));local denied,traits={},{}
 for _,r in ipairs(frame.relations) do if r.op=="deny_level_trait" then denied[r.trait]=true end end
 for _,r in ipairs(frame.relations) do if r.op=="level_trait" and not denied[r.trait] then traits[#traits+1]=r.trait end end
 return assert(RW_ProjectWorld(w,frame.effects,traits))
end
local world=scoped({{"LEVEL","IS","AUTO","AND","AUTO","AND","SLEEP","AND","STILL"}});assert(RW_GetAutoTurnCount(world)==2)
world=scoped({{"LEVEL","IS","AUTO"},{"LEVEL","IS","NOT","AUTO"}});assert(RW_GetAutoTurnCount(world)==0)
world=scoped({{"LEVEL","IS","AUTO"},{"LEVEL","IS","BROKEN"}});assert(RW_GetAutoTurnCount(world)==0)
-- Query the same original AUTO_ON assignment used by statusblock/startblock.
f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],"rb"));source=f:read("*a");f:close()
first=assert(source:find('generaldata5.values[AUTO_ON] = 0',1,true));last=assert(source:find('if (ids == nil) then',first,true));local assignment=source:sub(first,last-1)
for count=0,6 do local env={generaldata5={values={}},AUTO_ON="auto",featureindex={level=true},hasfeature_count=function() return count>0 and count or nil end}
 assert(load(assignment,"installed scoped AUTO count","t",env))();assert(RW_GetAutoTurnCount({},(function() local t={};for i=1,count do t[i]="auto" end;return t end)())==env.generaldata5.values.auto)
end
print("PASS: AUTO nonbouncing weighted motion, MOVE/CHILL precedence, PUSH/WEAK/HAS/status/conditions/Undo, scoped count and "..cases.." installed collection/guard oracle cases")
