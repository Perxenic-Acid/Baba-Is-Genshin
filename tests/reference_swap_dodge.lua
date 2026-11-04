local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local move=assert(source:find('function move(',1,true))
local a=assert(source:find('local b = v[1]',move,true));local b=assert(source:find('if (dodge == false) then',a,true))
local env=setmetatable({XPOS='x',YPOS='y'}, {__index=_G})
local px,py
env.mmf={newObject=function() return {values={x=px,y=py}} end};env.MF_alert=function() end
local native=assert(load('return function(x,y,ox,oy,target,kind) local v={target,kind} '..
 source:sub(a,b-1)..' return dodge end','@installed_special_dodge','t',env))()
local count=0
for _,axis in ipairs({{1,0},{0,-1},{-1,0},{0,1}}) do
for _,reason in ipairs({'eat','lock','weak'}) do for _,target in ipairs({200,2}) do
for gone=0,1 do for relocated=0,1 do for mode=0,5 do for queued=0,1 do
 local dx,dy=axis[1],axis[2];local x,y=4,4;local nx,ny=x+dx,y+dy
 px,py=nx+(relocated==1 and 2 or 0),ny
 env.deleted=gone==1 and {[target]=true} or {}
 local lists={
  {},{{201,dx,dy}},{{target,nx,ny}},{{target,dx,dy}},
  {{target,nx,ny},{target,dx,dy}},{{target,dx,dy},{target,nx,ny}}}
 env.movelist=lists[mode+1]
 -- addaction("update") lives outside movelist; it must not manufacture a
 -- dodge before that queued position is actually applied.
 env.updatelist=queued==1 and {{target,{'update',x,y,nil}}} or {}
 local displaced=mode>=3
 local expected=target~=2 and (gone==1 or reason~='weak' and (relocated==1 or displaced))
 assert(native(x,y,dx,dy,target,reason)==expected,
  table.concat({reason,target,gone,relocated,mode,queued,dx,dy},':'))
 count=count+1
end end end end end end end
print('PASS: installed four-axis EAT/lock/WEAK dodge, real/EMPTY, deleted/relocated, unrelated/matching/mixed movelist and queued SWAP ('..count..' cases)')
