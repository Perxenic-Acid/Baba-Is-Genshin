dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('facing = function',1,true));local b=assert(source:find('facedby = function',a,true))
local env=setmetatable({roomsizex=5,ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}}},{__index=_G})
local original=assert(load('return {'..source:sub(a,b-1)..'}','@original_level_facing','t',env))().facing
local sets={{'rock'},{'rock','rock'},{'rock','flag'},{'not rock'},{'not rock','not rock'},
 {'text'},{'not text'},{'empty'},{'not empty'},{'level'},{'right'},{'not right'},{'right','right'}}
local checked=0
for dir=0,4 do for pattern=0,7 do for _,params in ipairs(sets) do for _,negated in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.entities={};w.rule_sources={}
 local surrounds={dir=dir,r={},u={},l={},d={}}
 if pattern<4 then surrounds[({'r','u','l','d'})[pattern+1]]={'rock','text','level'}
 elseif pattern==4 then surrounds.r={'-'};surrounds.l={'flag'}
 elseif pattern==5 then surrounds.u={'right'}
 elseif pattern==6 then surrounds.d={'empty','rock'} end
 w.level_surrounds=surrounds
 local native,terms={},{}
 for _,name in ipairs(params) do
  local negative=name:sub(1,4)=='not ';local noun=negative and name:sub(5) or name
  local term=noun=='right' and {tag='property',name='right'}
   or (noun=='text' or noun=='empty') and {tag='special',name=noun}
   or {tag='noun',type=noun=='level' and {tag='level'} or {tag='object',name=noun}}
  terms[#terms+1]=negative and {tag='not',operand=term} or term
  if negative then native[#native+1]=name else table.insert(native,1,name) end
 end
 local expected=original(native,{},{},{unitid=1,x=0,y=0,dir=dir,surrounds=surrounds,extras={'right','up','left','down'}})
 if negated then expected=not expected end
 local actual=RW_TestEntityCondition(w,{op='spatial',clauses={{relation='facing',negated=negated,parameters=terms}}},
  {id=0,class='level',x=0,y=0,direction='None'})
 assert(actual==expected,dir..':'..pattern..':'..table.concat(params,',')..':'..tostring(negated))
 checked=checked+1
end end end end
print('PASS: installed scoped LEVEL FACING saved direction/region, duplicate names, literal extras, Empty/Text/Level/NOT ('..checked..' cases)')
