-- Standalone oracle executes the installed game's exact OPEN/SHUT contact block.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=file:read('*a');file:close()
local first=assert(source:find('local isshut = getunitswitheffect("shut",false,delthese)',1,true))
local last=assert(source:find('local iseat = getunitswithverb("eat",delthese)',first,true))
local melt=assert(load(source:sub(first,last-1),'@original_blocks_unlock'))
XPOS,YPOS,SHAKE=1,2,3
generaldata={values={}}
local units={}
function getunitswitheffect(property)
 local r={};for _,u in ipairs(units) do if u[property] then r[#r+1]=u end end;return r
end
function findfeature(_,_,property)
 local r,seen={},{}
 for _,u in ipairs(units) do if u[property] and not seen[u.name] then
  seen[u.name]=true;r[#r+1]={u.name,'is',property}
 end end
 return #r>0 and r or nil
end
function findtype(rule,x,y)
 local r={};for _,u in ipairs(units) do
  if u.name==rule[1] and u[rule[3]] and u.values[1]==x and u.values[2]==y then r[#r+1]=u.fixed end
 end;return r
end
function issafe(id) for _,u in ipairs(units) do if u.fixed==id then return u.safe==true end end end
function floating() return true end
function checkeffecthistory() return 1,'' end
function MF_particles() end
function handledels(ids,sound) return ids,sound end
function setsoundname() end
local function run(spec,expected)
 units={};delthese={}
 for id,v in ipairs(spec) do units[#units+1]={fixed=id,name=v[1],values={[1]=v[2],[2]=v[3]},
  open=v.open,shut=v.shut,safe=v.safe} end
 melt();local got={};for _,id in ipairs(delthese) do got[id]=true end
 for id in ipairs(units) do assert((got[id]==true)==(expected[id]==true),'original victim mismatch '..id) end
end
run({{'avatar',3,2,open=true},{'rock',3,2,shut=true}},{[1]=true,[2]=true})
run({{'rock',3,2,open=true,shut=true}},{[1]=true})
run({{'avatar',3,2,open=true,safe=true},{'rock',3,2,shut=true}},{[2]=true})
run({{'avatar',3,2,open=true},{'rock',3,2,shut=true,safe=true}},{[1]=true})
run({{'avatar',3,2,open=true,safe=true},{'rock',3,2,shut=true,safe=true}},{})
run({{'avatar',3,2,open=true},{'rock',4,2,shut=true}},{})
run({{'avatar',3,2,open=true},{'rock',3,2,shut=true},{'avatar',3,2,open=true}}, {[1]=true,[2]=true})
run({{'avatar',3,2,open=true},{'rock',3,2,shut=true},{'crate',3,2,open=true}}, {[1]=true,[2]=true,[3]=true})
print('PASS: original OPEN/SHUT contact, self, SAFE matrix, separation, first-per-type multiplicity')
