local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(file) local f=assert(io.open(base..file,'rb'));local s=f:read('*a');f:close();return s end
local blocks,tools=read('blocks.lua'),read('tools.lua')
local a=assert(blocks:find('elseif (action == "tele") and (levelteledone < 3)',1,true))
local b=assert(blocks:find('elseif (action == "empty") then',a,true))
local env=setmetatable({XPOS=1,YPOS=2,FLOAT=3,ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}},tilesize=1,
 roomsizex=9,roomsizey=7,MF_particles=function() end,setsoundname=function() end,
 checkeffecthistory=function() return 1,0 end,addundo=function() end,MF_levelrotation=function() end},{__index=_G})
local native=assert(load('return function(actions,lstill,lsleep) local levelteledone=0; for _,action in ipairs(actions) do rule={"level","is",action}; if false then '
 ..blocks:sub(a,b-1)..' end end return levelteledone end','@installed_level_tele_motion','t',env))()
local function install(first,last)
 local x=assert(tools:find('function '..first..'(',1,true));local y=assert(tools:find('function '..last..'(',x+1,true))
 assert(load(tools:sub(x,y-1),'@installed_'..first,'t',env))()
end
install('floating_level','emptydir');install('cantmove','findnoun');install('reversedir','reversecheck');install('reversecheck','simplecheck')
local sequences={}
for n=0,5 do local seq={};for i=1,n do seq[i]='tele' end;sequences[#sequences+1]=seq end
for _,seq in ipairs({{'tele','chill','tele','move'},{'chill','tele','chill','tele'},
 {'turn','tele','deturn','tele','fallright'},{'tele','tele','tele','chill','tele','move'}}) do sequences[#sequences+1]=seq end
local flags={{},{'still'},{'sleep'},{'lockedright'},{'lockedup'},{'reverse','lockedleft'}}
local cases=0
for pattern=0,15 do for mapfloat=0,1 do for order=1,2 do for _,flag in ipairs(flags) do
 for _,seq in ipairs(sequences) do for _,seed in ipairs({1,17}) do
  local s=RW_CreateSession();local w=s.world;w.width,w.height=7,5;w.entities={};w.next_entity_id=5
  w.random_state=seed;w.board_offset={x=2,y=-1,direction='Right',rotation=180}
  local ids=order==1 and {1,2,3,4} or {4,2,1,3};w.unit_order=ids
  local objects,counts,traits={}, {},{}
  for _,t in ipairs(seq) do traits[#traits+1]=t;counts[t]=(counts[t] or 0)+1 end
  for _,t in ipairs(flag) do traits[#traits+1]=t;counts[t]=(counts[t] or 0)+1 end
  if mapfloat==1 then traits[#traits+1]='float';counts.float=1 end
  env.units={};env.Xoffset,env.Yoffset,env.mapdir,env.maprotation=2,-1,0,180
  for id=1,4 do
   local floating=math.floor(pattern/2^(id-1))%2==1
   local e={id=id,kind='object',class=id==2 and 'text' or 'object',archetype=id==3 and 'level_block' or 'rock',
    x=id+1,y=id,direction=({'Up','Down','Left','Right'})[id],behaviors={float=floating,still=true,sleep=true,lockedright=true}}
   if id==2 then e.text={name='IS'} end
   if id==3 then e.level_link={target='child',definition_id='child',source_type='level_block'} end
   if id==2 or id==4 then e.back_identity=77 end
   w.entities[id]=e;objects[id]={fixed=id+100,values={[1]=e.x,[2]=e.y,[3]=floating and 1 or 0}}
  end
  for _,id in ipairs(ids) do env.units[#env.units+1]=objects[id] end
  env.mmf={newObject=function(id) return objects[id-100] end}
  env.findfeature=function() return mapfloat==1 and {{{'level','is','float'},{}}} or nil end
  env.testcond=function() return true end
  env.hasfeature=function(_,_,trait) return counts[trait] and 1 or nil end
  env.hasfeature_count=function(_,_,trait) return counts[trait] or 0 end
  env.featureindex=counts.reverse and {reverse={}} or {}
  local rng,history=seed,{}
  env.fixedrandom=function(low,high) rng=(rng*48271)%2147483647;return low+rng%(high-low+1) end
  env.update=function(native_id,x,y)
   local id=native_id-100
   local e=objects[id];local oldx,oldy=e.values[1],e.values[2]
   if x~=oldx or y~=oldy then history[#history+1]={id=id,from={x=oldx,y=oldy},to={x=x,y=y}} end
   e.values[1],e.values[2]=x,y
  end
  env.MF_scrollroom=function(x,y) env.Xoffset,env.Yoffset=env.Xoffset+x,env.Yoffset+y end
  native(seq,env.cantmove('level',1,0),counts.sleep~=nil)
  local p=RW_ResolveLevelMotion(w,traits)
  assert((p.random_state and p.random_state.to or seed)==rng,'LEVEL TELE draws/order/cap mismatch')
  local offset=p.board_shift and p.board_shift.to or w.board_offset
  assert(offset.x==env.Xoffset and offset.y==env.Yoffset and offset.rotation==env.maprotation)
  assert(offset.direction==({'Right','Up','Left','Down'})[env.mapdir+1])
  assert(#(p.motion_history or {})==#history,'LEVEL TELE update journal count mismatch')
  for i,row in ipairs(p.motion_history or {}) do local expected=history[i]
   assert(row.entity_id==expected.id and row.from.x==expected.from.x and row.from.y==expected.from.y
    and row.to.x==expected.to.x and row.to.y==expected.to.y,'LEVEL TELE unit/phase update order mismatch')
  end
  local n,r=RW_Commit(s,p);assert(r.accepted,r.reason)
  for id,e in pairs(n.world.entities) do
   assert(e.x==objects[id].values[1] and e.y==objects[id].values[2],'LEVEL TELE position mismatch')
   assert(e.direction==w.entities[id].direction and e.back_identity==w.entities[id].back_identity)
   assert((e.level_link and e.level_link.definition_id)==(w.entities[id].level_link and w.entities[id].level_link.definition_id))
  end
  assert(RW_Undo(n).world==w and w.random_state==seed)
  cases=cases+1
 end end
end end end end
print('PASS: installed scoped LEVEL TELE cap/order/RNG, FLOAT, Text/linked/aliased identities, rider lock bypass, map locks, mixed motion and Undo ('..cases..' cases)')
