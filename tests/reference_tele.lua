-- Execute the installed TELE loop; normalize host objects and RNG draws only.
dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('for i,unitid in ipairs(istele) do',1,true))
local b=assert(source:find('for a,unitid in ipairs(isshift) do',a,true))
local checked=0
for count=1,3 do for mask=0,255 do
 local function bit(n) return math.floor(mask/2^n)%2==1 end
 local w={entities={},random_state=97}
 local function add(id,kind,x,y,tele,float,still)
  w.entities[id]={id=id,class=kind=='text' and 'text' or 'object',archetype=kind~='text' and kind or nil,
   text=kind=='text' and {name='IS'} or nil,x=x,y=y,direction='Left',behaviors={tele=tele,float=float,still=still,sleep=bit(4)}}
 end
 local source_name=bit(5) and 'text' or 'rock'
 add(1,bit(6) and source_name or 'avatar',2,2,false,bit(0),bit(3))
 add(10,source_name,2,2,true,bit(1),false)
 if count>=2 then add(20,source_name,8,2,true,bit(2),false) end
 if count>=3 then add(30,source_name,8,5,true,not bit(2),false) end
 if bit(7) then add(5,'flag',2,2,true,bit(1),false);add(35,'flag',12,2,true,false,false) end
 local units,ids,teles={},{},{}
 for id in pairs(w.entities) do ids[#ids+1]=id end;table.sort(ids)
 for _,id in ipairs(ids) do local e=w.entities[id]
  units[id]={fixed=id,values={e.x,e.y},strings={e.class=='text' and 'text_is' or e.archetype,e.class},flags={false}}
  if e.behaviors.tele then teles[#teles+1]=id end
 end
 local state=w.random_state
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,UNITTYPE=2,DEAD=1,objectdata={}}, {__index=_G})
 env.mmf={newObject=function(id) return assert(units[id]) end}
 env.isgone=function() return false end
 env.getname=function(unit) return unit.strings[2]=='text' and 'text' or unit.strings[1] end
 env.findallhere=function(x,y) local result={};for _,id in ipairs(ids) do if units[id].values[1]==x and units[id].values[2]==y then result[#result+1]=id end end;return result end
 env.hasfeature=function(_,_,trait,id) return w.entities[id].behaviors[trait] and true or nil end
 env.floating=function(x,y) return w.entities[x].behaviors.float==w.entities[y].behaviors.float end
 env.fixedrandom=function(lo,hi) state=(state*48271)%2147483647;return lo+state%(hi-lo+1) end
 env.update=function(id,x,y) units[id].values={x,y} end
 env.checkeffecthistory=function() return 1,0 end;env.MF_particles=function() end;env.setsoundname=function() end
 local run=assert(load('return function(istele) '..source:sub(a,b-1)..' end','@original_tele','t',env))()
 run(teles)
 local plan=assert(RW_ResolveTele(w));local actual={}
 for _,id in ipairs(ids) do actual[id]={x=w.entities[id].x,y=w.entities[id].y} end
 for _,change in ipairs(plan.changes) do actual[change.entity_id]={x=change.to.x,y=change.to.y};assert(change.to.direction=='Left') end
 for _,id in ipairs(ids) do assert(actual[id].x==units[id].values[1] and actual[id].y==units[id].values[2],'TELE position mismatch '..count..':'..mask..':'..id) end
 assert((plan.random_state and plan.random_state.to or w.random_state)==state,'TELE RNG draw mismatch')
 assert(w.entities[1].x==2 and w.random_state==97,'TELE planning mutated input')
 checked=checked+1
end end
assert(checked==768)
print('PASS: installed TELE source/destination names, Text, FLOAT/STILL/SLEEP, overlapping networks, moving sources, one-teleport limit and RNG draws ('..checked..' cases)')
