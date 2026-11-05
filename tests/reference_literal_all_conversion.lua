-- Standalone installed literal ALL conversion oracle; no project approximation.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/syntax.lua]],'rb'))
local source=file:read('*a');file:close()
local first=assert(source:find('function createall_single(',1,true))
local last=assert(source:find('\nfunction ',first+1,true))
local env=setmetatable({}, {__index=_G})
assert(load(source:sub(first,last-1),'@original_createall_single','t',env))()
env.XPOS,env.YPOS,env.DIR,env.ID=1,2,3,4
env.objectlist={rock=true,crate=true,flag=true}
env.findnoun=function() return false end
env.emptydir=function() return 0 end
local names={'rock','crate','flag'}
local checked=0
for _,name in ipairs({'rock','text','empty'}) do for occupied=0,7 do for denied=0,7 do
 local units={[1]={values={2,2,0,10},originalname=name}}
 env.mmf={newObject=function(id) return assert(units[id]) end}
 env.getname=function() return name end
 local function selected(mask,target)
  for index,noun in ipairs(names) do if noun==target then return math.floor(mask/2^(index-1))%2==1 end end
 end
 env.hasfeature=function(_,verb,target)
  assert(verb=='is','literal ALL must query IS NOT even when selected by BECOME')
  return selected(denied,target:sub(5)) and true or nil
 end
 env.findtype=function(data) return selected(occupied,data[1]) and {99} or {} end
 local births={}
 env.create=function(noun)
  births[noun]=(births[noun] or 0)+1
  local id=#units+1;units[id]={};return id,id+100
 end
 env.addundo=function() end
 env.createall_single(name=='empty' and 2 or 1,nil,2,2)
 for _,noun in ipairs(names) do
  local expected=noun~=name and not selected(occupied,noun) and not selected(denied,noun)
  assert((births[noun] or 0)==(expected and 1 or 0),'literal ALL occupancy/denial mismatch')
 end
 checked=checked+1
end end end
print('PASS: installed literal ALL excludes own noun and occupied/IS NOT targets for real/Text/Empty ('..checked..' cases)')
-- Later literal records see earlier births, including current-turn products.
local serial=0
for _,name in ipairs({'rock','text','empty'}) do for mask=0,7 do
 local units={[1]={values={2,2,0,10},originalname=name}}
 env.mmf={newObject=function(id) return assert(units[id]) end}
 env.getname=function() return name end
 env.hasfeature=function(_,verb) assert(verb=='is');return nil end
 local occupancy={};for index,noun in ipairs(names) do if math.floor(mask/2^(index-1))%2==1 then occupancy[noun]=true end end
 env.findtype=function(data) return occupancy[data[1]] and {99} or {} end
 local births={}
 env.create=function(noun)
  births[#births+1]=noun;occupancy[noun]=true
  local id=#units+1;units[id]={};return id,id+100
 end
 env.addundo=function() end
 env.createall_single(name=='empty' and 2 or 1,nil,2,2)
 local first_count=#births
 env.createall_single(name=='empty' and 2 or 1,nil,2,2)
 env.createall_single(name=='empty' and 2 or 1,nil,2,2)
 assert(#births==first_count,'repeated literal ALL must observe earlier birth occupancy')
 serial=serial+1
end end
print('PASS: installed repeated literal ALL observes serial newborn occupancy ('..serial..' cases)')
