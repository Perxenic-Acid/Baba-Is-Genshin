local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local source=read('conditions.lua');local a=assert(source:find('facedby = function',1,true));local b=assert(source:find('without = function',a,true))
local env=setmetatable({ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}},roomsizex=9,DIR=1,XPOS=2,YPOS=3,map={[0]={get_x=function()return 255 end}}},{__index=_G})
local native=assert(load('return {'..source:sub(a,b-1)..'}','@installed_ordered_conditions','t',env))()
local tools=read('tools.lua');a=assert(tools:find('function simplecheck(',1,true));assert(load(tools:sub(a),'@installed_simplecheck_stacks','t',env))()
local units,features;env.mmf={newObject=function(id)return units[id]end};env.getname=function(u)return u.name end
 env.emptydir=function()return 4 end;env.inbounds=function(x,y)return x>=1 and x<=9 and y>=1 and y<=9 end
 env.findobstacle=function(x,y)return env.unitmap[x+y*9] or {}end
 env.hasfeature=function(_,_,trait,id)return (features[id] or {})[trait] and true or nil end
local function term(s)
 local neg=s:sub(1,4)=='not ';if neg then s=s:sub(5)end
 local p=s=='text' and {tag='special',name='text'} or {tag='noun',type={tag='object',name=s}}
 return neg and {tag='not',operand=p} or p
end
local permutations={{11,12,13},{11,13,12},{12,11,13},{12,13,11},{13,11,12},{13,12,11}}
local paramslist={{'not rock','not flag'},{'not rock','not water'},{'rock','not flag'},{'not text','not flag'}}
local faces={'Right','Up','Left','Down'};local cases,changed=0,0
for _,names in ipairs({{'rock','flag','water'},{'rock','rock','flag'},{'text','flag','water'}})do
for _,stack in ipairs(permutations)do for reverse=0,1 do for explicit=0,1 do for axis=1,4 do for _,mask in ipairs({0,1,3,7})do
 local w=RW_CreateSession().world;w.width=9;w.height=9;w.entities={};w.rule_sources={}
 w.unit_order=reverse==0 and {10,11,12,13} or {13,12,11,10}
 local observer={id=10,class='object',archetype='avatar',x=4,y=4,direction=faces[axis]};w.entities[10]=observer
 local dx,dy=env.ndirs[axis][1],env.ndirs[axis][2];local x,y=4+dx,4+dy;local key=x..':'..y
 units={};features={};env.unitmap={}
 for i,name in ipairs(names)do
  local id=10+i;local toward=math.floor(mask/2^(i-1))%2==1;local dir=toward and (axis+1)%4+1 or axis
  local e={id=id,class=name=='text' and 'text' or 'object',archetype=name,x=x,y=y,direction=faces[dir]};if name=='text'then e.text={name='ROCK'}end
  w.entities[id]=e;units[id]={name=name,values={dir-1,x,y}};features[id]={}
 end
 if explicit==1 then w.cell_order={[key]=stack};env.unitmap[x+y*9]=stack
 else local ids={};for _,id in ipairs(w.unit_order)do if id~=10 then ids[#ids+1]=id end end;env.unitmap[x+y*9]=ids end
 -- Fixed declaration eligibility; source conditions and native parsing have
 -- independent oracles. HIDE/PHANTOM/STOP vary while traversal order is tested.
 for i,trait in ipairs({'hide','phantom','stop'})do if (mask+i+axis)%3==0 then
  local id=10+i;features[id][trait]=true
  w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait=trait=='stop' and 'block_entry' or trait,target={kind='id',value=id}}}}
 end end
 for _,params in ipairs(paramslist)do
  local terms,ordered={},{};for _,p in ipairs(params)do terms[#terms+1]=term(p);if p:sub(1,4)=='not ' then ordered[#ordered+1]=p else table.insert(ordered,1,p)end end
  for _,relation in ipairs({'facedby','seeing'})do for neg=0,1 do
   local expected=native[relation](ordered,{},{},{unitid=10,x=4,y=4,dir=axis-1,conds={}});if neg==1 then expected=not expected end
   local actual=RW_TestEntityCondition(w,{op='spatial',clauses={{relation=relation,negated=neg==1,parameters=terms}}},observer)
   assert(actual==expected,relation..' stack query '..cases)
   cases=cases+1
  end end
 end
end end end end end end
assert(cases==18432)
print('PASS: installed FACEDBY/SEEING ordered stacked witnesses, complements, four axes, facing, HIDE/PHANTOM/STOP and global/explicit order ('..cases..' cases)')
