local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local f=assert(io.open(base..'blocks.lua','rb'));local source=f:read('*a');f:close()
local a=assert(source:find('local ending = findfeature(nil,"is","end")',1,true))
local b=assert(source:find('local win = findfeature(nil,"is","win")',a,true))
local section=source:sub(a,b-1):gsub('end%s*$','') -- close of the surrounding small==false block
local body='return function(unit) local x,y=unit.values[1],unit.values[2] '..section..' end'
local cases=0
for channel=0,1 do for reverse=0,1 do for mask=0,15 do for _,targets in ipairs({{{13,14}},{{14},{13}},{{13},{14}},{{14,13},{14}}}) do
 local w=RW_CreateSession().world;w.entities={};w.unit_order=reverse==0 and {11,12,13,14} or {14,13,12,11}
 local units={};local effects={};local groups=channel==0 and {{12},{11}} or {{11},{12}}
 for _,id in ipairs(w.unit_order) do
  w.entities[id]={id=id,kind='object',class='object',archetype=id<13 and 'avatar' or 'rock',x=3,y=3,direction='Right'}
  units[id]={fixed=id,values={3,3}}
  if math.floor(mask/2^(id-11))%2==1 then effects[#effects+1]={op='grant_trait',trait='float',entity_ids={id}} end
 end
 for i,g in ipairs(groups) do effects[#effects+1]={op='grant_trait',trait=i==1 and 'you' or 'you2',entity_ids=g} end
 for _,g in ipairs(targets) do effects[#effects+1]={op='grant_trait',trait='end',entity_ids=g} end
 local first
 local env=setmetatable({generaldata={values={mode=0},strings={world='base',base='base'}},MODE='mode',WORLD='world',BASEWORLD='base',
 findfeature=function()return targets end,findtype=function(g)
  local r={};for _,id in ipairs(w.unit_order) do for _,v in ipairs(g) do if v==id then r[#r+1]=id;break end end end;return r end,
 floating=function(x,y)return math.floor(mask/2^(x-11))%2==math.floor(mask/2^(y-11))%2 end,
 MF_particles=function()end,MF_end=function(x,y)first=first or {x,y}end},{__index=_G})
 local run=assert(load(body,'@installed_END_order','t',env))()
 for _,g in ipairs(groups) do for _,id in ipairs(g) do run(units[id]) end end
 local projected=assert(RW_ProjectWorld(w,effects));local actual=RW_ResolveEndContact(projected)
 assert((actual~=nil)==(first~=nil),'END presence')
 if first then assert(actual.source.entity_id==first[1] and actual.target.entity_id==first[2],'END ordered witnesses') end
 assert(not w.end_source_groups);cases=cases+1
end end end end
assert(cases==256)
print('PASS: installed END first witness order across YOU/YOU2, physical target clauses, stack order and FLOAT ('..cases..' cases)')
