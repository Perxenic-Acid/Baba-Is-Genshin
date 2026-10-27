-- Standalone original conditions oracle with engine object/occupancy boundaries stubbed.
dofile([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]])
roomsizex=12;UNITNAME=1
local objects={
 [10]={fixed=10,strings={[1]='rock'},x=4,y=4},
 [11]={fixed=11,strings={[1]='crate'},x=4,y=4},
 [12]={fixed=12,strings={[1]='rock'},x=8,y=4},
 [13]={fixed=13,strings={[1]='flag'},x=5,y=5}}
mmf={newObject=function(id) return objects[id] end}
function getname(unit) return unit.strings[1] end
map={[0]={get_x=function(_,x,y) return x>=1 and x<=12 and y>=1 and y<=12 and 255 or 0 end}}
local function occupancy()
 unitmap={}
 for id,o in pairs(objects) do local key=o.x+o.y*roomsizex;unitmap[key]=unitmap[key] or {};table.insert(unitmap[key],id) end
end
local function check(kind,params,id)
 occupancy();local o=objects[id]
 return condlist[kind](params,{},nil,{unitid=id,x=o.x,y=o.y,surrounds={}})
end
assert(check('on',{'crate'},10))
assert(not check('on',{'rock'},10))
assert(check('near',{'flag'},10)) -- diagonal
assert(not check('near',{'rock'},10)) -- excludes self
assert(check('on',{'not rock'},10))
assert(not check('on',{'crate','crate'},10))
objects[14]={fixed=14,strings={[1]='crate'},x=4,y=4}
assert(check('on',{'crate','crate'},10))
assert(check('on',{'level'},10))
assert(not check('on',{'empty'},10))
assert(check('near',{'empty'},10))
print('PASS: original ON/NEAR overlap/diagonals/self-exclusion/NOT noun/distinct repeated witnesses/LEVEL/EMPTY')

assert(not check('on',{'not empty'},10)) -- two Crates: original counts two for a single parameter
objects[14]=nil
assert(check('on',{'not empty'},10))
print('PASS: original ON NOT EMPTY consumes all remaining co-occupants')
