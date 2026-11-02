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
for _,a in ipairs({'always','on','without'}) do for _,b in ipairs({'always','on','without'}) do
 for _,pa in ipairs({'flag','rock','text'}) do for _,pb in ipairs({'flag','rock','text'}) do
  local w=RW_CreateSession().world;w.width,w.height=24,20;w.entities={};w.next_entity_id=10;w.random_state=17
  w.language.nouns.FLAG='flag';w.language.nouns.ROCK='rock'
  local rows={}
  for i,spec in ipairs({{a,pa},{b,pb}}) do
   rows[i]={{'empty','has',spec[2]},{spec[1]}}
   local words={'EMPTY'};if spec[1]~='always' then words[#words+1]=spec[1]:upper();words[#words+1]='FLAG' end
   words[#words+1]='HAS';words[#words+1]=spec[2]:upper()
   for x,name in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
    w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=8+i*2,direction='None'}
   end
  end
  env.featureindex={empty=rows};created={};state=17;env.inside('empty',5,3,4,2)
  local frame,e=RW_CompileWorld(w,cs);assert(frame,e and e.reason)
  local products,why,_,rng=RW_InitializeEmptyHasBirths(w,{{x=5,y=3}},frame.relations,frame.rules);assert(products,why)
  assert(#products==#created and rng.to==state)
  for i,p in ipairs(products) do
   local name=p.class=='text' and 'text_'..p.text.name:lower() or p.archetype
   assert(name==created[i].name and p.direction==({'Right','Up','Left','Down'})[created[i].direction+1],a..':'..b..':'..pa..':'..pb)
  end
  count=count+1
 end end
end end
print('PASS: installed inside() sequential EMPTY HAS ordinary/Text, ON/WITHOUT birth witnesses and direction oracle ('..count..' cases)')
