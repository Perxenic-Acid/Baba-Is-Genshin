-- Installed real/EMPTY DEFEAT and real WIN/END before LEVEL YOU's BONUS scan.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local f=assert(io.open(base..'blocks.lua','rb'));local source=f:read('*a');f:close()
local start=assert(source:find('function levelblock()',1,true))
local a=assert(source:find('local defeats = findfeature(nil,"is","defeat")',start,true))
local b=assert(source:find('if (bonus ~= nil) then',a,true))
local env=setmetatable({},{__index=_G})
local native=assert(load('return function(lsafe)'..source:sub(a,b-1)..';return {win=canwin,ending=canend} end','@installed_level_you_preflight','t',env))()
local function bit(n,i)return math.floor(n/2^i)%2==1 end
local cases=0
for mask=0,3 do for layers=0,3 do for properties=0,7 do
for _,safe in ipairs({false,true}) do for _,empty_defeat in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.entities={};w.unit_order={};w.rule_sources={};w.level_behaviors={safe=safe};w.empty_defeat_declared=empty_defeat
 for i=0,1 do if bit(mask,i) then local id=10+i;w.unit_order[#w.unit_order+1]=id
  w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=i+1,y=1,direction='Right',behaviors={float=not bit(layers,i),safe=true}}
 end end
 for i,trait in ipairs({'defeat','win','end'}) do if bit(properties,i-1) then
  w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait=trait,target={kind='archetype',value='rock'}}}}
 end end
 if safe then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='safe',when={op='always'}}}} end
 env.findfeature=function(_,_,trait)
  for i,name in ipairs({'defeat','win','end'}) do if name==trait and bit(properties,i-1) then return {{'rock',{}}} end end
  return nil
 end
 env.findall=function()return w.unit_order end
 env.issafe=function(id)assert(id==1);return safe end
 env.floating_level=function(id)return id==2 or bit(layers,id-10) end
 env.findallfeature=function(noun,_,trait)assert(noun=='empty' and trait=='defeat');return empty_defeat and {{}} or {} end
 local destroyed=false;env.destroylevel=function()destroyed=true end
 local expected=native(safe);local actual,why=RW_LevelYouPreflight(w,{});assert(actual,why)
 assert((actual.level_destroy==true)==destroyed)
 if not destroyed then assert(actual.win==expected.win and actual.ending==expected.ending) end
 cases=cases+1
end end end end end
print('PASS: installed LEVEL YOU real/EMPTY DEFEAT and pre-delete real WIN/END, target SAFE independence and layers ('..cases..' cases)')
