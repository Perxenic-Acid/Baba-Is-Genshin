-- Execute the installed virtual self-contact pairing and deletion branches.
dofile('external_lua_file/properties.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('local keypair = ""',1,true))
local b=assert(source:find('if emptyboom then',a,true))
local c=assert(source:find('local alive = true',b,true))
local d=assert(source:find('if bonus and',c,true))
local current_level,current_same
local env=setmetatable({},{__index=_G})
env.testcond=function() return true end
env.hasfeature=function(name,_,property) return name=='level' and current_level[property] and true or nil end
env.floating_level=function() return current_same end
env.setsoundname=function() end;env.MF_particles=function() end
env.math=setmetatable({random=function() return 2 end},{__index=math})
local native=assert(load('return function(emptythings,esafe) local i,j=5,5 local ewintiles,eendtiles,edelthese={},{},{} '..source:sub(a,b-1)..source:sub(c,d-1)..' return #edelthese>0 end','@installed_empty_self_contacts','t',env))()
local names={'open','shut','hot','melt','you','you2','defeat'}
local capabilities={you='control',you2='control2',open='open',shut='shut',hot='hot',melt='melt',defeat='defeat'}
local count=0
for mask=0,127 do for levelmask=0,15 do for safe=0,1 do for layer=0,1 do for reverse=0,1 do
 local rows,b={},{}
 for index=1,#names do local i=reverse==0 and index or #names+1-index
  if math.floor(mask/2^(i-1))%2==1 then rows[#rows+1]={{'empty','is',names[i]}, {}};b[capabilities[names[i]]]=true end
 end
 b.safe=safe==1;b.float=layer==1
 current_level={};for i,name in ipairs({'open','shut','hot','defeat'}) do current_level[name]=math.floor(levelmask/2^(i-1))%2==1 end
 current_same=not b.float
 local expected=native(rows,b.safe)
 local result=RW_ResolveEmptyContactVictims({empty_cells={['5:5']={x=5,y=5,behaviors=b}},level_behaviors=current_level})
 assert((#result==1)==expected,table.concat({mask,levelmask,safe,layer,reverse},':'))
 count=count+1
end end end end end
print('PASS: installed EMPTY OPEN/SHUT, HOT/MELT, YOU/DEFEAT self/scoped contacts, order/SAFE/FLOAT ('..count..' cases)')-- inside() draws once at deletion even with no products, sharing orientation
-- across duplicate ordinary/Text HAS declarations for the same empty victim.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local text=file:read('*a'):gsub('\r\n','\n');file:close()
local first=assert(text:find('function inside(',1,true));local last=assert(text:find('function animate(',first,true))
local state,created
local insideenv=setmetatable({nlist={short={}},unitmap={},roomsizex=12,objectlist={rock=true,flag=true},unitreference={rock=true,flag=true}},{__index=_G})
insideenv.findnoun=function(name) return name=='text' or name=='all' or name=='empty' end
insideenv.testcond=function() return true end
insideenv.fixedrandom=function() state=state*48271%2147483647;return state%4 end
insideenv.create=function(name,x,y,dir) created[#created+1]={name=name,direction=dir} end
assert(load(text:sub(first,last-1),'@installed_empty_inside','t',insideenv))()
local dirnames={'Right','Up','Left','Down'}
local insidecases=0
for rock=0,3 do for flag=0,3 do for literal=0,3 do for direction=0,4 do
 local rows,relations={},{}
 for _,spec in ipairs({{'rock',rock},{'flag',flag},{'text',literal}}) do for i=1,spec[2] do
  rows[#rows+1]={{'empty','has',spec[1]}, {}}
  relations[#relations+1]={op='empty_has',source_type='@empty',product=spec[1]=='text' and {kind='text'} or {kind='object',archetype=spec[1]}}
 end end
 insideenv.featureindex={empty=rows};state=17;created={};insideenv.inside('empty',5,5,direction,2)
 local w=RW_CreateSession().world;w.entities={};w.width,w.height=12,12;w.rule_sources={};w.random_state=17
 local rules={}
 if direction<4 then rules[1]={when={op='always'},effects={{op='grant_trait',target={kind='empty',value='empty'},trait=dirnames[direction+1]:lower()}}} end
 local products,why,random=RW_PlanEmptyHasBirths(w,{{x=5,y=5}},relations,rules);assert(products,why)
 assert(#products==#created and (random and random.to or 17)==state)
 local actual,expected={},{}
 for _,p in ipairs(products) do local name=p.class=='text' and 'text_'..p.text.name:lower() or p.archetype
  actual[#actual+1]=name..':'..p.direction end
 for _,p in ipairs(created) do expected[#expected+1]=p.name..':'..dirnames[p.direction+1] end
 table.sort(actual);table.sort(expected);assert(table.concat(actual,';')==table.concat(expected,';'))
 assert(w.random_state==17 and next(w.entities)==nil)
 insidecases=insidecases+1
end end end end
print('PASS: installed EMPTY inside HAS products, duplicates/Text and shared/random-only direction ('..insidecases..' cases)')
