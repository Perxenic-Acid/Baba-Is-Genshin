-- Actual doconvert -> addunit -> addunitmap -> brokenblock -> ON lifecycle.
local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local function section(s,a,b)return s:sub(assert(s:find(a,1,true)),assert(s:find(b,1,true))-1)end
local convert=section(read('convert.lua'),'function doconvert(','function dolevelconversions(')
local addunit=section(read('syntax.lua'),'function addunit(','function cleanup(')
local addmap=section(read('tools.lua'),'function addunitmap(','function updateunitmap(')
local broken=section(read('blocks.lua'),'function brokenblock(','function statusblock(')
local on=section(read('conditions.lua'),'on = function','near = function')
local paramslist={{'not water','not avatar'},{'not avatar','not flag'},{'avatar','not flag'},{'not rock','not flag'}}
local productlists={{'rock'},{'rock','flag'},{'rock','rock'},{'avatar'},{'@text'}}
local checked=0
for others=1,2 do
local permutations=others==1 and {{1,2},{2,1}} or {{1,2,3},{1,3,2},{2,1,3},{2,3,1},{3,1,2},{3,2,1}}
for _,stack in ipairs(permutations)do for _,products in ipairs(productlists)do for _,params in ipairs(paramslist)do
 local env=setmetatable({featureindex={},unitreference={rock='rock',flag='flag',avatar='avatar',text_avatar='text_avatar'},
  roomsizex=9,changes={},units={},unitlists={},objectlist={},unitmap={},unittypeshere={},tiledunits={},animunits={},codeunits={},letterunits={},visiontargets={}}, {__index=_G})
 for key in (convert..addunit..broken):gmatch('%[([A-Z][A-Z0-9_]*)%]')do env[key]=key end
 local function record(id,name)
  return {fixed=id,className=name,values=setmetatable({XPOS=2,YPOS=2,DIR=2,ID=id},{__index=function()return 0 end}),
   strings=setmetatable({NAME=name,UNITNAME=name,UNITTYPE=name:sub(1,5)=='text_' and 'text' or 'object'},{__index=function()return '' end}),
   flags=setmetatable({},{__index=function()return false end}),broken=0,originalname='avatar',followed=-1,holder=0}
 end
 local units={[1]=record(1,'avatar'),[2]=record(2,'flag'),[3]=record(3,'water')};local born={};local frontier=20
 env.mmf={newObject=function(id)return assert(units[id])end}
 env.getname=function(u)return u.strings.UNITTYPE=='text' and 'text' or u.strings.UNITNAME end
 env.spritedata={values=setmetatable({},{__index=function()return 0 end})}
 env.generaldata2={values=setmetatable({},{__index=function()return 0 end})};env.generaldata={flags={}}
 env.setcolour=function()return 0,0 end
 for _,name in ipairs({'getmetadata','addundo','poscorrect','dynamic','MF_specialremove','MF_animframe'})do env[name]=function()end end
 env.MF_emptycreate=function(name)local id=frontier;frontier=id+1;units[id]=record(id,name);return id end
 env.delunit=function(id)
  local cell=env.unitmap[2+2*9];for i=#cell,1,-1 do if cell[i]==id then table.remove(cell,i)end end
 end
 assert(load(addmap,'@installed_conversion_addmap','t',env))()
 local native_on=assert(load('return {'..on..'}','@installed_conversion_on','t',env))().on
 assert(load(broken..addunit..convert,'@installed_conversion_lifecycle','t',env))()
 env.statusblock=function(ids)
  local id=ids[1];local cell=env.unitmap[2+2*9];assert(cell[#cell]==id,'newborn not appended before status')
  local old=false;for _,other in ipairs(cell)do if other==1 then old=true end end;assert(old,'source removed before status')
  env.brokenblock({units[id]});born[#born+1]=units[id]
 end
 env.hasfeature=function(_,_,trait,id)
  assert(trait=='broken');return native_on(params,{},{},{unitid=id,x=2,y=2}) and true or nil
 end
 for _,id in ipairs(stack)do env.units[#env.units+1]=units[id];env.addunitmap(id,2,2,units[id].strings.UNITNAME)end
 local mats={};for i,name in ipairs(products)do mats[i]={name=='@text' and 'text_avatar' or name,i==1 and 1 or 10+i-2,1}end
 env.doconvert({1,'convert',mats})
 local w=RW_CreateSession().world;w.width=9;w.height=9;w.entities={};w.rule_sources={};w.next_entity_id=10
 -- Global order intentionally differs from explicit cell order.
 w.unit_order={};for id=1,others+1 do
  w.unit_order[#w.unit_order+1]=id;w.entities[id]={id=id,kind='object',class='object',archetype=units[id].strings.UNITNAME,x=2,y=2,direction='Left'}
 end
 w.cell_order={['2:2']=stack}
 local terms={};for _,p in ipairs(params)do local neg=p:sub(1,4)=='not ';local name=neg and p:sub(5) or p
  terms[#terms+1]=neg and {tag='not',operand={tag='noun',type={tag='object',name=name}}} or {tag='noun',type={tag='object',name=name}}
 end
 local rules={{when={op='spatial',clauses={{relation='on',negated=false,parameters=terms}}},effects={}}}
 for _,name in ipairs({'rock','flag','avatar','text'})do rules[1].effects[#rules[1].effects+1]={op='grant_trait',trait='broken',target={kind=name=='text' and 'class' or 'archetype',value=name}}end
 local relations={};for _,name in ipairs(products)do relations[#relations+1]={op='become',source_type='avatar',target_type=name,when={op='always'}}end
 local changes,why,allocation=RW_PlanConversions(w,relations,rules);assert(changes,why)
 local result=assert(RW_PreviewPlan(w,{consumes_turn=true,changes=changes,id_allocation=allocation}))
 for i,u in ipairs(born)do local e=result.entities[i==1 and 1 or 10+i-2];assert((e.broken or 0)==u.broken,'conversion stack status '..checked..':'..i)end
 for id in pairs(result.entities)do assert(id>0,'temporary witness persisted')end
 checked=checked+1
end end end end
assert(checked==160)
print('PASS: installed conversion/addunit/addunitmap/BROKEN/ON ordered old-source and newborn stacks, negative AND, self/duplicate/Text products ('..checked..' cases)')
