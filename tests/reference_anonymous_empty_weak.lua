dofile('external_lua_file/movement.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('function trypush(',1,true));local b=assert(source:find('function move(',a,true))
local weak,safe,blocked,deaths
local env=setmetatable({roomsizex=8,generaldata={values={}},generaldata2={strings={turn=''}},SHAKE='shake',TURNSOUND='turn'},{__index=_G})
env.hasfeature=function(_,_,trait) return trait=='weak' and weak and true or nil end
env.issafe=function() return safe end;env.findfeatureat=function() end
env.check=function(_,_,_,_,pulling) return {not pulling and blocked and 1 or 0},{200},{} end
env.delete=function(id,x,y) deaths[#deaths+1]={id=id,x=x,y=y} end
env.checkeffecthistory=function() return 1,'' end;env.setsoundname=function() end;env.MF_particles=function() end
assert(load(source:sub(a,b-1),'@installed_anonymous_weak_push','t',env))()
local vectors={{1,0},{0,-1},{-1,0},{0,1}};local count=0
for _,v in ipairs(vectors) do for _,isweak in ipairs({false,true}) do for _,issafe in ipairs({false,true}) do
for _,isblocked in ipairs({false,true}) do for _,layer in ipairs({false,true}) do for _,sleep in ipairs({false,true}) do
 weak,safe,blocked,deaths=isweak,issafe,isblocked,{}
 env.movemap={};env.pushedunits={};env.movelist={};env.HACK_MOVES=0
 local dir=v==vectors[1] and 0 or v==vectors[2] and 1 or v==vectors[3] and 2 or 3
 local result=env.trypush(2,v[1],v[2],dir,false,4,4,'you',100)
 if result==0 then result=env.dopush(2,v[1],v[2],dir,false,4,4,'you',100) end
 local w={width=8,height=8,entities={[1]={id=1,x=4-v[1],y=4-v[2],behaviors={float=not layer}}},
  empty_cells={['4:4']={x=4,y=4,behaviors={push=true,weak=weak,safe=safe,float=layer,sleep=sleep}}}}
 if blocked then w.entities[2]={id=2,x=4+v[1],y=4+v[2],behaviors={block_entry=true}} end
 local plan=assert(RW_ResolveMovement(w,{type='move',entity_id=1,dx=v[1],dy=v[2]}))
 assert((#plan.changes>0)==(result==0),count..' move')
 assert(#(plan.destructions or {})==#deaths,count..' deaths')
 if #deaths>0 then assert(plan.destructions[1].class=='empty' and plan.destructions[1].x==4 and plan.destructions[1].y==4 and deaths[1].id==2) end
 count=count+1
end end end end end end
print('PASS: installed trypush/dopush anonymous EMPTY WEAK, SAFE, free/blocked, SLEEP, FLOAT independence and four axes ('..count..' cases)')
