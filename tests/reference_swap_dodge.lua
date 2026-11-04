local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local move=assert(source:find('function move(',1,true))
local a=assert(source:find('local b = v[1]',move,true));local b=assert(source:find('if (dodge == false) then',a,true))
local env=setmetatable({XPOS='x',YPOS='y'}, {__index=_G})
local position
env.mmf={newObject=function() return {values={x=position,y=4}} end};env.MF_alert=function() end
local native=assert(load('return function() local x,y,ox,oy=4,4,1,0 local v={200,"eat"} '..
 source:sub(a,b-1)..' return dodge end','@installed_special_dodge','t',env))()
local count=0
for gone=0,1 do for relocated=0,1 do for moving=0,1 do for queued=0,1 do
 position=relocated==1 and 3 or 5;env.deleted=gone==1 and {[200]=true} or {}
 env.movelist=moving==1 and {{200,1,0}} or {}
 -- addaction("update") lives outside movelist; it must not manufacture a
 -- dodge before that queued position is actually applied.
 env.updatelist=queued==1 and {{200,{'update',4,4,nil}}} or {}
 assert(native()==(gone==1 or relocated==1 or moving==1))
 count=count+1
end end end end
print('PASS: installed contact dodge distinguishes queued SWAP from movelist/current position/deletion ('..count..' cases)')
