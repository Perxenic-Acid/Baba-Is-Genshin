-- Execute the installed original take-8 SHIFT task collector with engine stubs.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/movement.lua]],'rb'))
local source=file:read('*a');file:close()
local a=assert(source:find('local shifts = findallfeature(nil,"is","shift",true)',1,true))
local b=assert(source:find('local levelshift = findfeature("level","is","shift")',a,true))
local collect=assert(load(source:sub(a,b-1),'@original_shift_collector'))
XPOS,YPOS,DIR=1,2,3;roomsizex=12
local units,sources={},{ }
mmf={newObject=function(id) return units[id] end}
function findallfeature() return sources end
function floating(a,b) return units[a].layer==units[b].layer end
function isstill_or_locked() return false end
local function run(spec)
 units={};sources={};unitmap={};moving_units={};been_seen={}
 for index,s in ipairs(spec) do
  local id=index+10
  units[id]={values={[XPOS]=s.x,[YPOS]=s.y,[DIR]=s.dir or 0},layer=s.layer or 0}
  local tile=s.x+s.y*roomsizex;unitmap[tile]=unitmap[tile] or {};table.insert(unitmap[tile],id)
  if s.shift then sources[#sources+1]=id end
 end
 collect();return moving_units
end
local tasks=run({{x=3,y=2,shift=true,dir=1},{x=3,y=2}})
assert(#tasks==1 and tasks[1].unitid==12 and tasks[1].dir==1 and tasks[1].moves==1)
tasks=run({{x=3,y=2,shift=true,dir=0},{x=3,y=2,shift=true,dir=1},{x=3,y=2}})
local rider;for _,task in ipairs(tasks) do if task.unitid==13 then rider=task end end
assert(rider and rider.dir==0 and rider.moves==2)
assert(#run({{x=3,y=2,shift=true},{x=3,y=2,layer=1}})==0)
assert(#run({{x=3,y=2,shift=true}})==0)
print('PASS: original SHIFT self exclusion, FLOAT isolation, first-source direction and stacked impulse count')
