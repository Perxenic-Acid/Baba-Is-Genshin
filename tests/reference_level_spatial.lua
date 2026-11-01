-- Execute the installed synthetic LEVEL branches, with stable child witness order.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'))
local source=f:read('*a');f:close()
local env=setmetatable({roomsizex=4,roomsizey=3},{__index=_G})
env.pairs=function(t)
 if t~=env.unitlists then return pairs(t) end
 local entries={};for name,ids in pairs(t) do for _,id in ipairs(ids) do entries[#entries+1]={name,id} end end
 table.sort(entries,function(a,b) return a[2]<b[2] end);local i=0
 return function() i=i+1;local e=entries[i];if e then return e[1],{e[2]} end end
end
local originals={}
for _,pair in ipairs({{'on','near'},{'near','nextto'},{'nextto','facing'},{'above','below'},{'below','besideright'},{'besideright','besideleft'},{'besideleft','feeling'}}) do
 local a=assert(source:find(pair[1]..' = function',1,true));local b=assert(source:find(pair[2]..' = function',a,true))
 originals[pair[1]]=assert(load('return {'..source:sub(a,b-1)..'}','@original_level_'..pair[1],'t',env))()[pair[1]]
end
local parameters={{'rock'},{'rock','rock'},{'rock','flag'},{'not rock'},{'not rock','not rock'},
 {'text'},{'text','text'},{'not text'},{'empty'},{'empty','empty'},{'not empty'},
 {'level'},{'level','level'},{'not level'},{'rock','not flag'},{'not rock','not flag'}}
local checked=0
for rocks=0,2 do for texts=0,1 do for levels=0,1 do for pattern=0,7 do for _,full in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.width=4;w.height=3;w.entities={};w.rule_sources={}
 -- Native ABOVE/BESIDELEFT iterate this absent list instead of findempty().
 -- Normalize its missing-table fault to an empty list, preserving the asymmetry.
 env.unitlists={empty={}};env.units={};local nextid=100
 local function add(name)
  local index=nextid-100;local id=nextid;nextid=id+1
  w.entities[id]={id=id,kind='object',class=name=='text' and 'text' or 'object',
   archetype=name=='level' and 'level_block' or name,x=index%4+1,y=math.floor(index/4)+1}
  env.unitlists[name]=env.unitlists[name] or {};table.insert(env.unitlists[name],id)
  env.units[#env.units+1]={className=name=='level' and 'level' or 'object',fixed=id}
 end
 for i=1,rocks do add('rock') end;for i=1,texts do add('text') end;for i=1,levels do add('level') end
 if full then while nextid<112 do add('flag') end end
 local surrounds={dir=0,r={},u={},l={},d={},dr={},ur={},ul={},dl={},o={}}
 if pattern==1 then surrounds.o={'rock','text','level'}
 elseif pattern==2 then surrounds.dr={'rock'};surrounds.r={'-'}
 elseif pattern==3 then surrounds.o={'-'};surrounds.ul={'flag'}
 elseif pattern>=4 then surrounds[({'r','u','l','d'})[pattern-3]]={'rock'} end
 w.level_surrounds=surrounds
 local occupied={};for _,e in pairs(w.entities) do occupied[e.x..':'..e.y]=true end
 local empties={};for y=1,3 do for x=1,4 do if not occupied[x..':'..y] then empties[#empties+1]=x+y*4 end end end
 env.findempty=function() return empties end
 for _,relation in ipairs({'on','near','nextto','above','below','besideleft','besideright'}) do for _,params in ipairs(parameters) do for _,negated in ipairs({false,true}) do
  local native,terms={},{}
  for _,name in ipairs(params) do
   local negative=name:sub(1,4)=='not ';local noun=negative and name:sub(5) or name
   local term=(noun=='text' or noun=='empty') and {tag='special',name=noun}
    or {tag='noun',type=noun=='level' and {tag='level'} or {tag='object',name=noun}}
   terms[#terms+1]=negative and {tag='not',operand=term} or term
   if negative then native[#native+1]=name else table.insert(native,1,name) end
  end
  local ok,expected=xpcall(function() return originals[relation](native,{},{},{unitid=1,x=0,y=0,surrounds=surrounds}) end,debug.traceback)
  assert(ok,relation..':'..tostring(expected))
  if negated then expected=not expected end
  local actual,why=RW_TestEntityCondition(w,{op='spatial',clauses={{relation=relation,negated=negated,parameters=terms}}},
   {id=0,class='level',archetype='level_block',x=0,y=0,direction='None'})
  assert(actual==expected,relation..':'..rocks..':'..texts..':'..levels..':'..pattern..':'..tostring(full)..':'..table.concat(params,',')..':'..tostring(negated)..':'..tostring(why))
  checked=checked+1
 end end end
end end end end end
print('PASS: installed scoped LEVEL ON/NEAR/NEXTTO/directional child quotas, parent snapshots, Text/Empty/Level/NOT ('..checked..' normalized cases)')
