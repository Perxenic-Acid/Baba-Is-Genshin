-- Execute installed LEVEL BONUS, including its unsafe-map no-reward return.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local f=assert(io.open(base..'blocks.lua','rb'));local source=f:read('*a');f:close()
local a=assert(source:find('elseif (action == "bonus") then',source:find('function levelblock()',1,true),true))
local b=assert(source:find('elseif (action == "win") then',a,true))
local env=setmetatable({MF_playsound=function()end,addundo=function()end},{__index=_G})
local native=assert(load('return function(lsafe)local action="bonus";if false then '..source:sub(a,b-1)..' end;suffix=true end','@installed_level_bonus','t',env))()
local function bit(n,i)return math.floor(n/2^i)%2==1 end
local cases=0
for mask=0,3 do for layers=0,3 do for channels=0,3 do for copies=1,2 do
for _,safe in ipairs({false,true}) do for _,scoped in ipairs({false,true}) do for _,empty in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.entities={};w.unit_order={};w.rule_sources={}
 for i=0,1 do if bit(mask,i) then
  local id=10+i;w.unit_order[#w.unit_order+1]=id
  w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=i+1,y=1,direction='Right',behaviors={float=not bit(layers,i)}}
 end end
 for channel,trait in ipairs({'you','you2'}) do if bit(channels,channel-1) then
  for copy=1,copies do w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait=trait,target={kind='archetype',value='rock'}}}} end
 end end
 if scoped then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='you2',when={op='always'}}}} end
 w.empty_control2_declared=empty
 env.findfeature=function(_,_,trait)
  local rows={};if trait=='3d' then return nil end
  if bit(channels,trait=='you' and 0 or 1) then for copy=1,copies do rows[#rows+1]={'rock',{}} end end
  if trait=='you2' and scoped then rows[#rows+1]={'level',{}} end
  return rows
 end
 env.findall=function()local ids={};for _,id in ipairs(w.unit_order) do ids[#ids+1]=id end;return ids end
 env.floating_level=function(id)return id==2 or bit(layers,id-10) end
 env.testcond=function()return true end
 env.findallfeature=function(noun,_,trait)assert(noun=='empty');return empty and trait=='you2' and {{}} or {} end
 local destroyed,rewards=false,0
 env.destroylevel=function(style)assert(style=='bonus');destroyed=true end
 env.MF_bonus=function(amount)rewards=rewards+amount end;env.suffix=false
 native(safe)
 local result,why=RW_ResolveScopedBonus(w,{},safe);assert(result,why)
 assert((result.level_destroy==true)==destroyed and (result.pickup and 1 or 0)==rewards,'LEVEL BONUS return/reward mismatch')
 assert(env.suffix==not destroyed)
 cases=cases+1
end end end end end end end
print('PASS: installed LEVEL BONUS, YOU/YOU2 declaration multiplicity, scoped/EMPTY, FLOAT, SAFE and unsafe no-reward return ('..cases..' cases)')
do
 local w=RW_CreateSession().world;w.entities={[10]={id=10,kind='object',class='text',text={name='ROCK'},x=1,y=1,direction='None'}};w.unit_order={10};w.rule_sources={}
 local rules={{when={op='always'},effects={{op='grant_trait',trait='you2',target={kind='class',value='text'}}}}}
 assert(RW_ResolveScopedBonus(w,rules,true).pickup,'physical Text control may collect map BONUS')
 w.entities[10].broken=1;assert(not RW_ResolveScopedBonus(w,rules,true).pickup)
 w.entities[10].broken=nil;rules[2]={when={op='always'},effects={{op='deny_trait',trait='you2',target={kind='class',value='text'}}}}
 assert(not RW_ResolveScopedBonus(w,rules,true).pickup,'negative YOU2 removes collectors')
 w.entities={};w.unit_order={};w.language.nouns.CUSTOMLEVEL={tag='level',block_type='custom_portal'}
 rules={{when={op='always'},effects={{op='grant_trait',trait='you2',target={kind='archetype',value='custom_portal'}}}},
  {when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='you2',when={op='always'}}}}}
 assert(RW_ResolveScopedBonus(w,rules,true).pickup,'custom typed LEVEL collector remains synthetic without an entrance')
 rules[1].effects[1].trait='shut';rules[2].scoped_conditions[1].trait='shut'
 assert(RW_ResolveScopedUnlockTargets(w,rules,'open',false).level_destroy,'custom typed LEVEL complementary declaration remains synthetic')
 print('PASS: scoped BONUS physical Text, BROKEN and negative collector declarations')
end
