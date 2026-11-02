-- Installed state-3 rotation and final blocked-WEAK branch over static STOPs.
dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('if ((data.reason == "move") or (data.reason == "chill")) and (state < 4) then',1,true))
local b=assert(source:find('solved = true',a,true))
local c=assert(source:find('local newdir_ = rotate(dir)',1,true));local d=assert(source:find('if (data.unitid ~= 2) and (unit.flags[DEAD] == false)',c,true))
local weak,safe,deletes
local env=setmetatable({generaldata={values={}},SHAKE='shake'},{__index=_G})
env.hasfeature=function() return weak and true or nil end;env.issafe=function() return safe end
env.delete=function() deletes=deletes+1 end;env.checkeffecthistory=function() return 1,'' end
env.setsoundname=function() end;env.MF_particles=function() end
env.rotate=function(dir) return (dir+2)%4 end;env.cantmove=function() return false end
local terminal=assert(load('return function(reason,state,unitid) local data={reason=reason,unitid=unitid,state=state} local name="empty" local x,y=4,4 local result_check=false '..
 source:sub(a,b-1)..' end return data.state==4 end','@installed_blocked_weak','t',env))()
local rotate=assert(load('return function(dir,unitid) local data={unitid=unitid} local name="empty" local x,y=4,4 '..source:sub(c,d-1)..' return dir end','@installed_move_bounce','t',env))()
local dirs={'Right','Up','Left','Down'};local vectors={{1,0},{0,-1},{-1,0},{0,1}}
local nudge={'nudgeright','nudgeup','nudgeleft','nudgedown'}
local count=0
for _,virtual in ipairs({false,true}) do for _,isweak in ipairs({false,true}) do for _,issafe in ipairs({false,true}) do
for dir=0,3 do for _,front in ipairs({false,true}) do for _,back in ipairs({false,true}) do for _,reason in ipairs({'move','auto','nudge'}) do
 weak,safe,deletes=isweak,issafe,0
 if front then
  local retry=terminal(reason,3,virtual and 2 or 100)
  if retry then assert(rotate(dir,virtual and 2 or 100)==(dir+2)%4);if back then terminal(reason,4,virtual and 2 or 100) end end
 end
 local capability=reason=='nudge' and nudge[dir+1] or reason
 local behavior={[capability]=true,weak=isweak,safe=issafe}
 local w={width=8,height=8,entities={}}
 if virtual then w.empty_cells={['4:4']={x=4,y=4,behaviors=behavior,trait_counts={[capability]=1}}}
 else w.entities[100]={id=100,class='object',archetype='rock',x=4,y=4,direction=dirs[dir+1],behaviors=behavior} end
 local v=vectors[dir+1]
 if front then w.entities[201]={id=201,x=4+v[1],y=4+v[2],behaviors={block_entry=true}} end
 if back then w.entities[202]={id=202,x=4-v[1],y=4-v[2],behaviors={block_entry=true}} end
 local p=RW_ResolveAutomatic(w,{['4:4']=dirs[dir+1]})
 assert(#(p.destructions or {})==deletes,table.concat({tostring(virtual),tostring(isweak),tostring(issafe),dir,tostring(front),tostring(back),reason},':'))
 if deletes>0 then assert((p.destructions[1].class=='empty')==virtual and p.destructions[1].x==4 and p.destructions[1].y==4) end
 for _,op in ipairs(p.changes) do assert(op.entity_id>0) end
 count=count+1
end end end end end end end
print('PASS: installed MOVE bounce and blocked real/EMPTY WEAK terminal branches, AUTO/nudges, SAFE and four axes ('..count..' cases)')
