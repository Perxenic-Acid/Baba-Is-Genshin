-- Execute the installed original layer predicate, without game UI.
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('function floating(id1,id2,x1_,y1_,x2_,y2_)',1,true))
local b=assert(source:find('function floating_level(',a,true))
assert(load(source:sub(a,b-1),'@original_floating'))()
FLOAT=1
local layers={};mmf={newObject=function(id) return {values={[FLOAT]=layers[id]}} end}
local empty_float=false
function hasfeature() if empty_float then return true end end
for _,x in ipairs({0,1}) do for _,y in ipairs({0,1}) do
 layers[10]=x;layers[11]=y;assert(floating(10,11)==(x==y))
 empty_float=y==1;assert(floating(10,2,3,4)==(x==y))
end end
print('PASS: original FLOAT same-layer predicate and virtual EMPTY layer lookup')
