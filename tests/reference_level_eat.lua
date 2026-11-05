-- Execute the installed outgoing LEVEL EAT victim-selection branch unchanged.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({roomsizex=4,checkeffecthistory=function() return 1,0 end,setsoundname=function() end},{__index=_G})
local source=read('conditions.lua');local a=assert(source:find('without = function',1,true));local b=assert(source:find('above = function',a,true))
local without=assert(load('return {'..source:sub(a,b-1)..'}','@installed_without_outgoing_eat','t',env))().without
source=read('blocks.lua');a=assert(source:find('if (rule[1] == "level") and testcond(conds,1) then',assert(source:find('local levelteledone = 0',1,true)),true))
b=assert(source:find('elseif (rule[1] ~= "level") and (rule[3] == "level") then',a,true))
local native=assert(load('return function(rule,conds,lsafe) local eaten={}; '..source:sub(a,b-1)..' end return eaten end',
 '@installed_outgoing_level_eat','t',env))()
local targets={rock='rock',text='@text',level='@level',empty='@empty',all='@all',flag='flag'}
local cases=0
for mask=0,15 do for _,safe_mask in ipairs({0,5,10,15}) do for _,broken in ipairs({false,true}) do
for _,map_safe in ipairs({false,true}) do for condition=1,3 do for order=1,2 do for name,target in pairs(targets) do
 local w=RW_CreateSession().world;w.width,w.height=2,2;w.entities={};w.next_entity_id=14;w.rule_sources={}
 local occupied,safe={},{};env.unitlists={};w.unit_order=order==1 and {10,11,12,13} or {13,12,11,10}
 for index=0,3 do if math.floor(mask/2^index)%2==1 then
  local id=index+10;local noun=({'rock','text','level','rock'})[index+1]
  local e={id=id,kind='object',class=noun=='text' and 'text' or 'object',archetype=noun=='level' and 'level_block' or noun,
   x=index%2+1,y=math.floor(index/2)+1,direction='Left',behaviors={float=index%2==0}}
  if noun=='text' then e.text={name='ROCK'} end
  if safe_mask==5 and index%2==0 then e.broken=1 end
  w.entities[id]=e;occupied[e.x..':'..e.y]=true
  safe[id]=math.floor(safe_mask/2^index)%2==1 and e.broken~=1
  if math.floor(safe_mask/2^index)%2==1 then
   w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait='safe',target={kind='id',value=id}}}}
  end
 end end
 for _,id in ipairs(w.unit_order) do local e=w.entities[id];if e then
  local noun=e.class=='text' and 'text' or e.archetype=='level_block' and 'level' or e.archetype
  env.unitlists[noun]=env.unitlists[noun] or {};env.unitlists[noun][#env.unitlists[noun]+1]=id
 end end
 if broken then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='broken',when={op='always'}}}} end
 -- EMPTY SAFE has no bearing on the native direct delete(2,x,y) loop.
 if safe_mask>0 then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait='safe',target={kind='empty',value='empty'}}}} end
 local when={op='always'};if condition>1 then when={op='spatial',clauses={{relation='without',negated=condition==3,
  parameters={{tag='noun',type={tag='object',name='rock'}}}}}} end
 env.findempty=function()
  local cells={};for x=1,2 do for y=1,2 do if not occupied[x..':'..y] then cells[#cells+1]=x+y*4 end end end
  return cells
 end
 env.testcond=function()
  if broken then return false end
  if condition==1 then return true end
  local value=without({'rock'},{},{},{name='level',unitid=1,notcond=condition==3})
  return condition==3 and not value or condition~=3 and value
 end
 env.issafe=function(id) return safe[id] end
 local destroyed,cells=false,{}
 env.destroylevel=function() destroyed=true end
 env.generaldata={values={}};env.SHAKE=1;env.MF_particles=function() end
 env.delete=function(id,x,y) assert(id==2);cells[#cells+1]={x=x,y=y} end
 local ids=native({'level','eat',name},when,map_safe) or {}
 local actual,why=RW_ResolveScopedEatTargets(w,{}, {target_type=target,when=when},map_safe);assert(actual,why)
 assert((actual.level_destroy==true)==destroyed and #actual.ids==#ids and #actual.cells==#cells,'outgoing LEVEL EAT selection size/retirement mismatch')
 for i,id in ipairs(ids) do assert(actual.ids[i]==id,'outgoing LEVEL EAT unitlist order mismatch') end
 for i,cell in ipairs(cells) do assert(actual.cells[i].x==cell.x and actual.cells[i].y==cell.y,'outgoing EMPTY order mismatch') end
 cases=cases+1
end end end end end end end
print('PASS: installed outgoing LEVEL EAT Noun/Text/Level/Empty/All, SAFE/BROKEN, conditions, FLOAT independence and unit/cell order ('..cases..' cases)')
