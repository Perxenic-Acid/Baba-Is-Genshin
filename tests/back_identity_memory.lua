local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],"rb"));local source=f:read("*a");f:close()
local start=assert(source:find("local ishold =",1,true));local finish=assert(source:find("local issink =",start,true));local code=source:sub(start,finish-1)
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],"rb"));local tools=f:read("*a");f:close()
local lookup=assert(tools:match("(function getunitid%(id%).-)\nfunction newid"))
local function clone(v) if type(v)~="table" then return v end;local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r end
local count=0
for permutation=0,1 do for scenario=1,4 do for mask=0,31 do
 local function bit(n) return math.floor(mask/2^n)%2==1 end
 local w={width=12,height=10,next_entity_id=10,entities={
  [1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Down",holder=scenario==3 and 2 or 7,back_identity=scenario==2 and 7 or nil,behaviors={still=bit(2),float=false}},
  [2]={id=2,kind="object",class="object",archetype="rock",x=7,y=2,direction="Right",back_identity=7,behaviors={hold=bit(0),float=bit(3)}},
  [3]={id=3,kind="object",class="object",archetype="rock",x=9,y=2,direction="Up",back_identity=7,behaviors={hold=bit(1),float=bit(4)}}}}
 if scenario==4 then w.entities[1].x=9;w.entities[1].holder=0 end
 local order=permutation==0 and {1,2,3} or {3,2,1}
 if permutation==1 then w.unit_order=order end
 local units,handles={},{}
 for _,id in ipairs(order) do local e=w.entities[id];local u={fixed=id,values={e.x,e.y,id==1 and 3 or id==2 and 0 or 1,RW_GetBackIdentity(e)},strings={e.archetype},holder=e.holder or 0}
  units[#units+1]=u;handles[id]=u
 end
 local env=setmetatable({XPOS=1,YPOS=2,DIR=3,ID=4,roomsizex=12,unitmap={},units=units},{__index=_G})
 for _,e in pairs(w.entities) do env.unitmap[e.x+e.y*12]=true end
 env.getunitswitheffect=function() local r={};for _,id in ipairs(order) do if w.entities[id].behaviors.hold then r[#r+1]=handles[id] end end;return r end
 env.findallhere=function(x,y) local r={};for _,id in ipairs(order) do local u=handles[id];if u.values[1]==x and u.values[2]==y then r[#r+1]=id end end;return r end
 env.mmf={newObject=function(id) return assert(handles[id]) end}
 env.getname=function(u) return u.strings[1] end
 env.floating=function(a,b) return (w.entities[a].behaviors.float==true)==(w.entities[b].behaviors.float==true) end
 env.cantmove=function(_,id) return w.entities[id].behaviors.still==true end
 env.addundo=function() end
 env.update=function(id,x,y,dir) local u=handles[id];u.values[1],u.values[2],u.values[3]=x,y,dir end
 env.MF_alert=function() error("unexpected missing logical identity") end
 assert(load(lookup,"@installed_getunitid","t",env))()
 assert(load(code,"@installed_HOLD_aliases","t",env))()
 local p=assert(RW_ResolveHold(w));local base={world=w,history={}};local n,r=RW_Commit(base,p);assert(r.accepted,r.reason)
 for id=1,3 do local actual=n.world.entities[id];local native=handles[id]
  assert(actual.x==native.values[1] and actual.y==native.values[2] and (actual.holder or 0)==native.holder,"shared HOLD lookup mismatch")
 end
 assert(RW_Undo(n).world==w);count=count+1
end end end
assert(count==256);print("PASS: installed HOLD/getunitid shared-identity and unit-order oracle (256 cases), first non-HOLD alias, stale handles, layers, locks, acquisition and Undo")

-- Physical self-ID is a valid stored holder only when another instance shares
-- that native identity; fixed-handle self-exclusion still applies to acquisition.
local w={width=8,height=8,next_entity_id=10,entities={
 [1]={id=1,kind="object",class="object",archetype="avatar",x=3,y=3,direction="Down",behaviors={}},
 [2]={id=2,kind="object",class="object",archetype="rock",x=3,y=3,direction="Up",back_identity=1,behaviors={hold=true}}}}
local p=assert(RW_ResolveHold(w));local n,r=RW_Commit({world=w,history={}},p);assert(r.accepted,r.reason);assert(n.world.entities[1].holder==1)
local single=clone(w);single.entities[2]=nil
local same,r=RW_Commit({world=single,history={}},{consumes_turn=true,changes={{kind="holder",entity_id=1,to=1}}});assert(not r.accepted and r.reason=="invalid_holder")
-- FOLLOW memory uses a restored target's identity rather than its physical slot.
local follow={width=8,height=8,next_entity_id=20,entities={
 [1]={id=1,kind="object",class="object",archetype="rock",x=3,y=3,direction="Right",followed=7,behaviors={}},
 [10]={id=10,kind="object",class="object",archetype="avatar",x=3,y=2,direction="Up",back_identity=7,behaviors={}}}}
local p=assert(RW_ResolveFollow(follow,{[1]={"avatar"}}));local n,r=RW_Commit({world=follow,history={}},p);assert(r.accepted and n.world.entities[1].followed==7 and n.world.entities[1].direction=="Up")
assert(RW_Undo(n).world==follow)
print("PASS: shared-identity HOLD acquisition validation and FOLLOW memory atomic Commit/Undo")
