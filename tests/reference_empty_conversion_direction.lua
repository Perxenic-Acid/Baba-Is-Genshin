-- Run the installed emptyconvert branch, including its per-product RNG draws.
dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]],'rb'))
local source=f:read('*a');f:close()
source=source:gsub('\r\n','\n')
local body=assert(source:match('elseif %(style == "emptyconvert"%) then(.-)\n\tend\nend'))
local env=setmetatable({ONLINE=1,XPOS=2,YPOS=3,DIR=4,ID=5,EFFECT=6,UNITTYPE=1,UNITNAME=2,CONVERTED=2,roomsizex=3,featureindex={}},{__index=_G})
local units,state,dir,id
local function noop() end
env.addundo=noop;env.addunit=noop;env.addunitmap=noop;env.dynamic=noop
function env.newid() id=id+1;return id end
function env.emptydir() return dir end
function env.fixedrandom(low,high) state=state*48271%2147483647;return low+state%(high-low+1) end
env.mmf={newObject=function(i) return units[i] end}
function env.MF_emptycreate(name,x,y)
 local i=100+#units+1
 -- Sequential handles are separate from persistent IDs, just as in the engine.
 while units[i] do i=i+1 end
 units[i]={values={},flags={},strings={name:sub(1,5)=='text_' and 'text' or 'object',name}}
 return i
end
env.unitreference={rock='rock',text_empty='text_empty',text_rock='text_rock'}
local original=assert(load('return function(mats2,cdata) '..body..' end','@installed_emptyconvert','t',env))()
local names={'Right','Up','Left','Down','None'}
local count=0
for direction=0,4 do for duplicate=1,4 do for _,seed in ipairs({1,17,2147483646}) do
for _,target in ipairs({'rock','text_empty','text_rock'}) do
 dir=direction;units={};state=seed;id=0;env.emptydata={}
 local mats,relations={},{}
 for i=1,duplicate do
  mats[i]={target,1,1}
  relations[i]=target=='rock' and {op='transform',source_type='@empty',target_type='rock'}
   or target=='text_empty' and {op='transform_text',source_type='@empty'}
   or {op='write_text',source_type='@empty',target_text='ROCK'}
 end
 original(mats,{})
 local w={width=1,height=1,entities={},next_entity_id=10,random_state=seed,rule_sources={},language={nouns={ROCK='rock'}}}
 if direction<4 then w.rule_sources={{when={op='always'},effects={{op='grant_trait',trait=names[direction+1]:lower(),target={kind='empty',value='empty'}}}}} end
 local changes,err,allocation,_,_,_,rng=RW_PlanConversions(w,relations)
 assert(changes,err);assert(#changes==duplicate and allocation.to==10+duplicate)
 local expected={};for handle,u in pairs(units) do expected[#expected+1]={handle=handle,unit=u} end
 table.sort(expected,function(a,b) return a.handle<b.handle end)
 for i,c in ipairs(changes) do
  local p=c.to;local name=p.class=='text' and 'text_'..p.text.name:lower() or p.archetype
  assert(name==target and p.direction==names[expected[i].unit.values[4]+1] and p.original_name=='@empty')
 end
 assert((rng and rng.to or seed)==state and (not rng or rng.from==seed) and w.random_state==seed)
 count=count+1
end end end end
print('PASS: installed EMPTY conversion cardinal/unset/Text/WRITE/duplicate products and per-product random stream ('..count..' cases)')

-- ALL is dispatched through createall_single: one shared direction draw, even
-- when every palette target is denied. It differs from ordinary duplicate rows.
f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/syntax.lua]],'rb'));source=f:read('*a'):gsub('\r\n','\n');f:close()
local all_body=assert(source:match('(function createall_single%(.-)\nfunction setunitmap'))
assert(load(all_body,'@installed_createall_single','t',env))()
env.objectlist={rock=1,flag=1};env.findnoun=function() return false end;env.findtype=function() return {} end
local denied
env.hasfeature=function() return denied and {} or nil end
function env.create(name,x,y,direction)
 local handle=200;while units[handle] do handle=handle+1 end
 units[handle]={values={[env.DIR]=direction},strings={'object',name},flags={}}
 return handle,env.newid()
end
local all_count=0
for direction=0,4 do for _,seed in ipairs({1,17,2147483646}) do for _,blocked in ipairs({false,true}) do
 dir=direction;state=seed;id=0;units={};env.emptydata={};denied=blocked
 original({{'createall',1,1}},{})
 local w={width=1,height=1,entities={},next_entity_id=10,random_state=seed,rule_sources={},language={nouns={ROCK='rock',FLAG='flag'}}}
 if direction<4 then w.rule_sources={{when={op='always'},effects={{op='grant_trait',trait=names[direction+1]:lower(),target={kind='empty',value='empty'}}}}} end
 local relations={{op='transform_all',source_type='@empty'}}
 if blocked then relations[#relations+1]={op='forbid_transform',source_type='@empty',target_type='rock'};relations[#relations+1]={op='forbid_transform',source_type='@empty',target_type='flag'} end
 local changes,err,_,_,_,_,rng=RW_PlanConversions(w,relations);assert(changes,err)
 local expected={};for _,u in pairs(units) do expected[u.strings[2]]=names[u.values[env.DIR]+1] end
 assert(#changes==(blocked and 0 or 2))
 for _,c in ipairs(changes) do assert(c.to.direction==expected[c.to.archetype]) end
 assert((rng and rng.to or seed)==state)
 all_count=all_count+1
end end end
print('PASS: installed EMPTY ALL shared direction/RNG and fully denied groups ('..all_count..' cases)')
