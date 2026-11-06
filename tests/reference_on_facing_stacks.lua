-- Installed single-cell conditions consume witnesses in unitmap arrival order.
local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local s=read('conditions.lua');local a=assert(s:find('on = function',1,true));local b=assert(s:find('without = function',a,true))
local env=setmetatable({ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}},roomsizex=9,DIR=1,XPOS=2,YPOS=3},{__index=_G})
local native=assert(load('return {'..s:sub(a,b-1)..'}','@installed_single_cell_conditions','t',env))()
env.stringintable=function(value,list)for _,v in ipairs(list)do if v==value then return true end end;return false end
local permutations={{11,12,13},{11,13,12},{12,11,13},{12,13,11},{13,11,12},{13,12,11}}
local paramslist={{'not rock','not flag'},{'not rock','not water'},{'rock','not flag'},{'not text','not flag'},{'not rock','not rock'}}
local function term(s)
 local neg=s:sub(1,4)=='not ';if neg then s=s:sub(5)end
 local p=s=='text' and {tag='special',name='text'} or {tag='noun',type={tag='object',name=s}}
 return neg and {tag='not',operand=p} or p
end
local cases=0
for _,relation in ipairs({'on','facing'})do
for _,names in ipairs({{'rock','flag','water'},{'rock','rock','flag'},{'text','flag','water'}})do
for _,stack in ipairs(permutations)do for reverse=0,1 do for explicit=0,1 do for axis=1,4 do
 local w=RW_CreateSession().world;w.width=9;w.height=9;w.entities={};w.rule_sources={}
 w.unit_order=reverse==0 and {10,11,12,13} or {13,12,11,10}
 local observer={id=10,class='object',archetype='avatar',x=4,y=4,direction=({'Right','Up','Left','Down'})[axis]};w.entities[10]=observer
 local dx,dy=env.ndirs[axis][1],env.ndirs[axis][2];if relation=='on'then dx,dy=0,0 end
 local x,y=4+dx,4+dy;local key=x..':'..y;local units={}
 for i,name in ipairs(names)do
  local id=10+i;w.entities[id]={id=id,class=name=='text' and 'text' or 'object',archetype=name,x=x,y=y,direction='None'}
  if name=='text'then w.entities[id].text={name='ROCK'}end
  units[id]={name=name,values={4,x,y}}
 end
 local ordered={};if explicit==1 then w.cell_order={[key]=stack};for _,id in ipairs(stack)do ordered[#ordered+1]=id end
 else for _,id in ipairs(w.unit_order)do if id~=10 then ordered[#ordered+1]=id end end end
 -- Include the querying identity in ON's native cell, as the actual map does.
 if relation=='on'then table.insert(ordered,1,10)end
 env.unitmap={[x+y*9]=ordered};env.mmf={newObject=function(id)return assert(units[id])end};env.getname=function(u)return u.name end
 for _,params in ipairs(paramslist)do
  local terms,sorted={},{};for _,p in ipairs(params)do terms[#terms+1]=term(p);if p:sub(1,4)=='not 'then sorted[#sorted+1]=p else table.insert(sorted,1,p)end end
  for neg=0,1 do
   local expected=native[relation](sorted,{},{},{unitid=10,x=4,y=4,dir=axis-1,extras={},conds={}});if neg==1 then expected=not expected end
   local actual,why=RW_TestEntityCondition(w,{op='spatial',clauses={{relation=relation,negated=neg==1,parameters=terms}}},observer)
   assert(actual==expected,relation..' stack '..cases..' '..tostring(why));cases=cases+1
  end
 end
end end end end end end
assert(cases==5760)
print('PASS: installed ON/FACING ordered stacks, negative AND, repeated witnesses, Text, four axes and explicit/global order ('..cases..' cases)')
