-- Installed global Noun EAT LEVEL branch, with installed WITHOUT conditions.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({checkeffecthistory=function() return 1,0 end,setsoundname=function() end},{__index=_G})
local source=read('conditions.lua');local a=assert(source:find('without = function',1,true));local b=assert(source:find('above = function',a,true))
local without=assert(load('return {'..source:sub(a,b-1)..'}','@installed_without_eat_level','t',env))().without
source=read('blocks.lua');a=assert(source:find('elseif (rule[1] ~= "level") and (rule[3] == "level") then',1,true))
b=assert(source:find('for a,b in ipairs(eaten) do',a,true))
local original=assert(load('return function(rule,conds,lsafe) if false then '..source:sub(a,b-1)..' return false end',
 '@installed_eat_level','t',env))()
local cases=0
for mask=0,15 do for broken=0,7 do for _,safe in ipairs({false,true}) do for kind=1,4 do for _,name in ipairs({'rock','text','empty'}) do
 local w=RW_CreateSession().world;w.width,w.height=2,2;w.entities={};w.next_entity_id=14;w.rule_sources={};w.level_behaviors={safe=safe,float=true}
 env.unitlists={};local occupied={}
 for index=0,3 do if math.floor(mask/2^index)%2==1 then
  local id=index+10;local noun=({'rock','text','flag','rock'})[index+1]
  local e={id=id,kind='object',class=noun=='text' and 'text' or 'object',archetype=noun,
   x=index%2+1,y=math.floor(index/2)+1,direction='Left',behaviors={safe=true,float=index%2==0}}
  if noun=='text' then e.text={name='ROCK'} end
  if noun=='rock' and broken%2==1 or noun=='text' and math.floor(broken/2)%2==1 then e.broken=1 end
  w.entities[id]=e;occupied[e.x..':'..e.y]=true
  env.unitlists[noun]=env.unitlists[noun] or {};env.unitlists[noun][#env.unitlists[noun]+1]=id
 end end
 local empty_broken=math.floor(broken/4)%2==1
 if empty_broken then w.rule_sources={{when={op='always'},effects={{op='grant_trait',trait='broken',target={kind='empty',value='empty'}}}}} end
 local when,params,negative={op='always'},nil,false
 if kind>1 then
  local target=kind==4 and 'flag' or 'rock';negative=kind==3;params={target}
  when={op='spatial',clauses={{relation='without',negated=negative,parameters={{tag='noun',type={tag='object',name=target}}}}}}
 end
 env.testcond=function(_,id,x,y)
  local entity=w.entities[id]
  if entity and entity.broken==1 or id==2 and empty_broken then return false end
  if not params then return true end
  local own=entity and (entity.class=='text' and 'text' or entity.archetype) or 'empty'
  local active=without(params,{},{},{name=own,unitid=id,notcond=negative})
  return negative and not active or not negative and active
 end
 env.findempty=function(conds)
  local cells={};for x=1,2 do for y=1,2 do
   if not occupied[x..':'..y] and (not conds or env.testcond(conds,2,x,y)) then cells[#cells+1]=x+y*4 end
  end end;return cells
 end
 env.findall=function(rule)
  local ids={};for _,id in ipairs(env.unitlists[rule[1]] or {}) do if env.testcond(rule[2],id) then ids[#ids+1]=id end end
  return ids
 end
 env.findnoun=function(noun) return noun=='empty' end
 local destroyed=false;env.destroylevel=function() destroyed=true end
 original({name,'eat','level'},when,safe)
 local row={op='eat_level',relation={op='eat',source_type=name=='rock' and 'rock' or '@'..name,target_type='level_block',when=when}}
 local actual,why=RW_LevelMotionDeclarationActive(w,{},row);assert(actual~=nil,why)
 assert(actual==destroyed,'global Noun EAT LEVEL source/SAFE/condition/BROKEN mismatch')
 assert(not w.infinite_loop and not w.too_complex)
 cases=cases+1
end end end end end
print('PASS: installed global Noun/Text/Empty EAT LEVEL, source conditions/BROKEN, map SAFE, source SAFE/FLOAT independence ('..cases..' cases)')
