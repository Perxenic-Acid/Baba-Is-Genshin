-- Extend collision-only oracles with the installed anonymous PUSH dispatch.
-- The downstream cell is either clear or a static STOP; no new model of WEAK.
return function(source,env)
 local a=assert(source:find('function trypush(',1,true));local b=assert(source:find('function move(',a,true))
 local obstructed
 env.roomsizex=8;env.TURNSOUND='turn';env.generaldata2={strings={turn=''}}
 env.findfeatureat=function() end
 env.check=function(_,_,_,_,pulling) return {not pulling and obstructed and 1 or 0},{999},{} end
 assert(load(source:sub(a,b-1),'@installed_empty_push_dispatch','t',env))()
 return function(blocked)
  obstructed=blocked;env.movemap={};env.pushedunits={};env.movelist={};env.HACK_MOVES=0
  local result=env.trypush(2,1,0,0,false,5,4,'you',100)
  if result==0 then result=env.dopush(2,1,0,0,false,5,4,'you',100) end
  return result==0
 end
end
