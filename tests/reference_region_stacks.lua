local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local f=assert(io.open(base..'conditions.lua','rb'));local source=f:read('*a');f:close()
local env=setmetatable({roomsizex=9,roomsizey=9,UNITNAME=1},{__index=_G});assert(load(source,'@installed_region_stacks','t',env))()
local permutations={{11,12,13},{11,13,12},{12,11,13},{12,13,11},{13,11,12},{13,12,11}}
local paramslist={{'not rock','not flag'},{'not rock','not water'},{'rock','not flag'},{'not text','not flag'},{'not rock','not rock'}}
local vectors={above={0,1},below={0,-1},besideleft={1,0},besideright={-1,0}}
local function term(s)
 local neg=s:sub(1,4)=='not ';if neg then s=s:sub(5)end
 local p=s=='text' and {tag='special',name='text'} or {tag='noun',type={tag='object',name=s}}
 return neg and {tag='not',operand=p} or p
end
local cases=0
for _,relation in ipairs({'near','nextto','above','below','besideleft','besideright'})do
for _,names in ipairs({{'rock','flag','water'},{'rock','rock','flag'},{'text','flag','water'}})do
for _,stack in ipairs(permutations)do for reverse=0,1 do for explicit=0,1 do for layout=0,3 do for empty=0,1 do
 local w=RW_CreateSession().world;w.width=7;w.height=7;w.entities={};w.rule_sources={};w.unit_order={}
 local observer={id=empty==0 and 10 or nil,class=empty==0 and 'object' or 'empty',archetype='avatar',x=4,y=4,direction='Right'}
 if empty==0 then w.entities[10]=observer;w.unit_order[1]=10 end
 local units={};env.unitmap={};env.mmf={newObject=function(id)return assert(units[id])end};env.getname=function(u)return u.name end
 for i,name in ipairs(names)do
  local dx,dy;local v=vectors[relation]
  if v then
   local distance=layout==1 and i or layout==2 and (i==3 and 2 or 1) or 1
   dx,dy=v[1]*distance,v[2]*distance
   if layout==3 and i==3 then dx,dy=dx+v[2],dy+v[1]end
  elseif layout==0 then dx,dy=-1,0
  elseif layout==1 then
   local offsets=relation=='near' and {{-1,-1},{-1,0},{0,-1}} or {{-1,0},{0,-1},{0,1}}
   dx,dy=offsets[i][1],offsets[i][2]
  elseif layout==2 then dx,dy=i==3 and 1 or -1,0
  else dx,dy=0,0 end
  local id=10+i;local x,y=4+dx,4+dy
  w.entities[id]={id=id,class=name=='text' and 'text' or 'object',archetype=name,x=x,y=y,direction='None'}
  if name=='text'then w.entities[id].text={name='ROCK'}end
  units[id]={name=name}
 end
 local global=reverse==0 and {11,12,13} or {13,12,11}
 for _,id in ipairs(global)do w.unit_order[#w.unit_order+1]=id end
 local ordered=explicit==1 and stack or global;if explicit==1 then w.cell_order={}end
 if empty==0 then env.unitmap[4+4*9]={10}end
 for _,id in ipairs(ordered)do
  local e=w.entities[id];local key=e.x..':'..e.y;local tile=e.x+e.y*9
  env.unitmap[tile]=env.unitmap[tile] or {};env.unitmap[tile][#env.unitmap[tile]+1]=id
  if explicit==1 then w.cell_order[key]=w.cell_order[key] or {};w.cell_order[key][#w.cell_order[key]+1]=id end
 end
 for _,params in ipairs(paramslist)do
  local terms,sorted={},{};for _,p in ipairs(params)do terms[#terms+1]=term(p);if p:sub(1,4)=='not 'then sorted[#sorted+1]=p else table.insert(sorted,1,p)end end
  for neg=0,1 do
   local expected=env.condlist[relation](sorted,{},{},{unitid=empty==0 and 10 or 2,x=4,y=4,surrounds={}});if neg==1 then expected=not expected end
   local actual,why=RW_TestEntityCondition(w,{op='spatial',clauses={{relation=relation,negated=neg==1,parameters=terms}}},observer)
   assert(actual==expected,relation..' region stack '..cases..' layout '..layout..' '..tostring(why));cases=cases+1
  end
 end
end end end end end end end
assert(cases==34560)
print('PASS: installed real/EMPTY NEAR/NEXTTO/four-ray coordinate and stack order, NOT/AND, repeated witnesses, Text, off-axis and overlapping layouts ('..cases..' cases)')
