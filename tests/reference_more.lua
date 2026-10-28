-- Execute the installed game's exact MORE block with a live occupancy stub.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=file:read('*a');file:close()
local a=assert(source:find('local ismore = getunitswitheffect("more",false,delthese)',1,true))
local b=assert(source:find('local isplay = getunitswithverb("play",delthese)',a,true))
local fragment=source:sub(a,b-1):gsub(string.char(10)..string.char(9)..'end%s*$','')
local more=assert(load(fragment,'@original_more'))
XPOS,YPOS,UNITNAME=1,2,1;roomsizex=8
ndirs={{1,0},{0,-1},{-1,0},{0,1}}
local units,empty_block,births={},false,{}
mmf={newObject=function(id) return units[id] end}
function getunitswitheffect()
 local result={};for _,u in ipairs(units) do if u.more then result[#result+1]=u end end;return result
end
function findobstacle(x,y)
 if x<1 or y<1 or x>8 or y>8 then return {-1} end
 local result={};for id,u in ipairs(units) do if u.values[1]==x and u.values[2]==y then result[#result+1]=id end end;return result
end
function hasfeature(name,_,property,id)
 if name=='empty' then if empty_block and property=='stop' then return true end
 elseif units[id][property] then return true end
end
function copy(id,x,y)
 local u=units[id];local new={fixed=#units+1,values={x,y},strings={u.strings[1]}}
 units[#units+1]=new;births[#births+1]=new;return new
end
local function run(spec,expected,empty)
 units={};births={};empty_block=empty
 for id,s in ipairs(spec) do units[id]={fixed=id,values={s.x or 3,s.y or 3},strings={s.name or 'rock'},more=s.more,stop=s.stop,push=s.push} end
 more();assert(#births==expected,'original MORE birth count: '..#births..' expected '..expected)
end
run({{more=true}},4)
run({{more=true},{x=4,y=3,name='wall',stop=true}},3)
run({{more=true},{x=4,y=3,name='wall',push=true}},3)
run({{more=true},{x=4,y=3,name='rock'}},3)
run({{more=true},{x=4,y=3,name='flag'}},4)
run({{more=true,x=1,y=1}},2)
run({{more=true},{more=true,x=5,y=3}},7)
run({{more=true}},0,true)
print('PASS: original MORE four-way copy, blockers, same-noun/newborn occupancy, inert overlaps and EMPTY STOP')
