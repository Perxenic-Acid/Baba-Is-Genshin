-- Normalize the random roll: compare installed thresholds/cache semantics, not
-- the engine's math.random stream (RuleWorld deliberately uses a pure keyed stream).
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('often = function',1,true))
local env=setmetatable({},{__index=_G})
local original=assert(load('return {'..source:sub(a),'@original_chance','t',env))()
local count=0
for _,relation in ipairs({'often','seldom'}) do
 local sides=relation=='often' and 4 or 6;local seen={}
 for seed=1,120 do for _,class in ipairs({'object','text','empty'}) do for _,negated in ipairs({false,true}) do
  local e={id=10,class=class,x=2,y=3};local w=RW_CreateSession().world;w.chance_seed=seed
  local identity=class=='empty' and 'empty:2:3' or '10'
  local key='head:1:'..identity;local sample=seed
  for index=1,#key do sample=(sample*(131+key:byte(index))+key:byte(index))%2147483647 end
  sample=(sample*48271)%2147483647;local roll=sample%sides+1;seen[roll]=true
  env.condstatus={};env.fixedrandom=function(low,high) assert(low==1 and high==sides);return roll end
  local conditions={};local data={unitid=class=='empty' and 2 or 10,x=2,y=3,conds=conditions,i=1}
  local expected=original[relation]({}, {}, {}, data)
  -- A different subsequent random roll must not replace the cached decision.
  env.fixedrandom=function() return roll%sides+1 end
  assert(original[relation]({}, {}, {}, data)==expected)
  if negated then expected=not expected end
  local clause={relation=relation,negated=negated,parameters={},chance_key='head:1'}
  local actual=RW_TestEntityCondition(w,{op='spatial',clauses={clause}},e)
  assert(actual==expected,'chance source mismatch')
  assert(RW_TestEntityCondition(w,{op='spatial',clauses={clause}},e)==expected and w.chance_seed==seed)
  count=count+1
 end end end
 for roll=1,sides do assert(seen[roll],'missing roll bucket') end
end
print('PASS: installed OFTEN/SELDOM normalized rolls, cached repeats, NOT/Object/Text/EMPTY ('..count..' cases)')
