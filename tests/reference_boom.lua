-- Installed BOOM loop, with host effects normalized to no-ops.
dofile('external_lua_file/properties.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('local isboom =',1,true));local b=assert(source:find('delthese,doremovalsound = handledels',a,true))
local checked=0
for count=1,4 do for mask=0,63 do
 local function bit(n) return math.floor(mask/2^n)%2==1 end
 local w={width=12,height=12,entities={},trait_counts={}}
 local units,ids={},{}
 for id=1,4 do
  local x=id==1 and 5 or id==2 and 5 or id==3 and 6 or 8
  local y=id==3 and 6 or 5
  local e={id=id,x=x,y=y,behaviors={boom=id==1 or id==3 and bit(5),safe=id==1 and bit(0) or id~=1 and bit(1),float=id==1 and bit(2) or id~=1 and bit(3)}}
  w.entities[id]=e;w.trait_counts[id]={boom=count}
  units[id]={fixed=id,values={x,y},strings={'rock',bit(4) and 'text' or 'object'}};ids[#ids+1]=id
 end
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,UNITTYPE=2,SHAKE=1,generaldata={values={}},roomsizex=12,roomsizey=12,unitmap={},delthese={}}, {__index=_G})
 for _,e in pairs(w.entities) do env.unitmap[e.x+e.y*12]=true end
 env.getunitswitheffect=function() local r={};for _,id in ipairs(ids) do if w.entities[id].behaviors.boom then r[#r+1]=units[id] end end;return r end
 env.issafe=function(id) return w.entities[id].behaviors.safe end
 env.hasfeature_count=function(_,_,_,id) return count end
 env.inbounds=function(x,y) return x>=1 and x<=12 and y>=1 and y<=12 end
 env.findallhere=function(x,y) local r={};for _,id in ipairs(ids) do local e=w.entities[id];if e.x==x and e.y==y then r[#r+1]=id end end;return r end
 env.floating=function(x,y) return w.entities[x].behaviors.float==w.entities[y].behaviors.float end
 env.MF_particles=function() end;env.checkeffecthistory=function() return 1,0 end;env.getcolour=function() return 0,0 end
 assert(load(source:sub(a,b-1),'@original_boom','t',env))()
 local expected={};for _,id in ipairs(env.delthese) do expected[id]=true end
 local actual={};for _,id in ipairs(assert(RW_ResolveContactVictims(w,'boom'))) do actual[id]=true end
 for _,id in ipairs(ids) do assert((expected[id] or false)==(actual[id] or false),'BOOM mismatch '..count..':'..mask..':'..id) end
 checked=checked+1
end end
print('PASS: installed BOOM radius, diagonal range, SAFE/FLOAT, Text and overlapping blast sources ('..checked..' cases)')
