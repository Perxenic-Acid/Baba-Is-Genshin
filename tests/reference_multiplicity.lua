-- Optional local-source oracle; run standalone, never inside the project test process.
-- Engine object/UI boundaries are stubbed; docode/calculatesentences/conversion are original.
dofile([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]])
XPOS,YPOS=1,2
roomsizex=20
dirs={[1]={1,0}}
local slots={}
local next_id=1
for x,spec in ipairs({{"box",0,1},{"is",1,3},{"rock",0,2},{"and",6,2},{"rock",0,2}}) do
 slots[x]={}
 for i=1,spec[3] do slots[x][#slots[x]+1]={{next_id},1,spec[1],spec[2],1}; next_id=next_id+1 end
end
mmf={newObject=function(id) return {values={[1]=0,[2]=0},strings={}} end}
codecheck=function(id,ox,oy) return slots[ox+1] or {},false,false end
unitreference={text_is="text_is"}
tileslist={text_is={argtype={0}}}
changes={}
generaldata={flags={}}
LOGGING=1
function copytable(a,b) for _,v in ipairs(b) do a[#a+1]=v end return a end
function MF_alert(s) print(s) end
function destroylevel(s) error(s) end
local count=0
features,featureindex={}, {box={}}
addoption=function(rule,conds,ids) count=count+1; local entry={rule,conds,ids}; features[#features+1]=entry; featureindex.box[#featureindex.box+1]=entry end
docode({{{1},1,1,"box",0,{}}})
assert(count == 48); print("PASS: original parser emitted 48 rules from 24 physical sentences")

dofile([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]])
objectlist={rock=true}
nlist={brief={}}
getmat=function(name) if name == "rock" then return name end end
findnoun=function() return false end
convert=function(name,mats) assert(name == "box" and #mats == 48); print("PASS: original conversion passed 48 products per source") end
conversion()
