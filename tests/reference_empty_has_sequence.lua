for _,name in ipairs({'world','reader','grammar','rules','properties'}) do dofile('external_lua_file/'..name..'.lua') end
dofile('external_lua_file/bootstrap.lua')
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local source=file:read('*a'):gsub('\r\n','\n');file:close()
local first=assert(source:find('function inside(',1,true));local last=assert(source:find('function animate(',first,true))
local created,state
local env=setmetatable({nlist={short={}},unitmap={},roomsizex=24,objectlist={flag=true,rock=true},unitreference={flag=true,rock=true}},{__index=_G})
env.findnoun=function(name) return name=='text' or name=='all' or name=='empty' end
-- Isolate native inside() ordering; compiler/condition semantics are tested by
-- the production queries on the other side and their dedicated source oracles.
env.testcond=function(conds)
 if conds[1]=='always' then return true end
 local found=false;for _,p in ipairs(created) do if p.name=='flag' then found=true end end
 return conds[1]=='on' and found or conds[1]=='without' and not found
end
env.fixedrandom=function() state=state*48271%2147483647;return state%4 end
env.create=function(name,x,y,dir) created[#created+1]={name=name,direction=dir} end
assert(load(source:sub(first,last-1),'@installed_inside_sequence','t',env))()
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local count=0
for _,container in ipairs({'empty','avatar'}) do
for _,a in ipairs({'always','on','without'}) do for _,b in ipairs({'always','on','without'}) do
 for _,pa in ipairs({'flag','rock','text'}) do for _,pb in ipairs({'flag','rock','text'}) do
  local w=RW_CreateSession().world;w.width,w.height=24,20;w.entities={};w.next_entity_id=10;w.random_state=17
  w.language.nouns.FLAG='flag';w.language.nouns.ROCK='rock'
  local rows={}
  for i,spec in ipairs({{a,pa},{b,pb}}) do
   rows[i]={{container,'has',spec[2]},{spec[1]}}
   local words={container:upper()};if spec[1]~='always' then words[#words+1]=spec[1]:upper();words[#words+1]='FLAG' end
   words[#words+1]='HAS';words[#words+1]=spec[2]:upper()
   for x,name in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
    w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=8+i*2,direction='None'}
   end
  end
  if container=='avatar' then w.entities[1]={id=1,kind='object',class='object',archetype='avatar',x=5,y=3,direction='Up'} end
  env.featureindex={[container]=rows};created={};state=17;env.inside(container,5,3,container=='empty' and 4 or 1,container=='empty' and 2 or 1)
  local frame,e=RW_CompileWorld(w,cs);assert(frame,e and e.reason)
  local products,why,rng
  if container=='empty' then local prefix;products,why,prefix,rng=RW_InitializeEmptyHasBirths(w,{{x=5,y=3}},frame.relations,frame.rules)
  else products,why=RW_InitializeHasBirths(w,{1},frame.relations,frame.rules) end
  assert(products,why);assert(#products==#created and (rng and rng.to or 17)==state)
  for i,p in ipairs(products) do
   local name=p.class=='text' and 'text_'..p.text.name:lower() or p.archetype
   assert(name==created[i].name and p.direction==({'Right','Up','Left','Down'})[created[i].direction+1],a..':'..b..':'..pa..':'..pb)
  end
  count=count+1
 end end
end end
end
print('PASS: installed inside() sequential EMPTY/real HAS ordinary/Text, ON/WITHOUT birth witnesses and direction oracle ('..count..' cases)')

-- Execute the original handledels() wrapper as well: its simultaneous mode
-- keeps every parent present throughout the inside pass.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local blocks=file:read('*a'):gsub('\r\n','\n');file:close()
local a=assert(blocks:find('function handledels(',1,true));local b=assert(blocks:find('function startblock(',a,true))
local parents
env.handleinside=function(id) env.inside('avatar',id==1 and 5 or 8,3,1,id) end
env.delete=function(id,_,__,___,noinside) if not noinside then env.handleinside(id) end;parents[id]=nil end
env.testcond=function(conds,id)
 if conds[1]=='always' then return true end
 for other in pairs(parents) do if other~=id then return false end end
 return true
end
assert(load(blocks:sub(a,b-1),'@installed_handledels_sequence','t',env))()
for _,simultaneous in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.width,w.height=24,20;w.next_entity_id=10
 w.language.nouns.FLAG='flag';w.entities={}
 for id=1,2 do w.entities[id]={id=id,kind='object',class='object',archetype='avatar',x=id==1 and 5 or 8,y=3,direction='Up'} end
 for x,name in ipairs({'AVATAR','WITHOUT','AVATAR','HAS','FLAG'}) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=10,direction='None'} end
 env.featureindex={avatar={{{'avatar','has','flag'},{'without'}}}};parents={[1]=true,[2]=true};env.deleted={};created={}
 env.handledels({1,2},false,simultaneous)
 local frame=assert(RW_CompileWorld(w,cs))
 local products,why=RW_InitializeHasBirths(w,{1,2},frame.relations,frame.rules,nil,simultaneous);assert(products,why)
 assert(#products==#created and #products==(simultaneous and 0 or 1))
end
print('PASS: installed handledels serial/simultaneous HAS parent-presence ordering')
