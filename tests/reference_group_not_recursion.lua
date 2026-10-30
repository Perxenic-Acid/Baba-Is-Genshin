-- Execute the installed grouprules() and invertconds(), normalize only host APIs.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('function grouprules()',1,true));local b=assert(source:find('function copyrule(',a,true))
local ia=assert(source:find('function invertconds(',1,true));local ib=assert(source:find('function rulelog(',ia,true))
local env=setmetatable({},{__index=_G})
env.copyconds=function(dst,src) for _,v in ipairs(src or {}) do dst[#dst+1]=v end;return dst end
env.concatenate=function(...) local dst={};for _,src in ipairs({...}) do for _,v in ipairs(src) do dst[#dst+1]=v end end;return dst end
env.findnoun=function() return false end
env.MF_alert=function() end;env.destroylevel=function() error('unexpected group recursion') end
assert(load(source:sub(ia,ib-1),'@original_invertconds','t',env))()
assert(load(source:sub(a,b-1),'@original_groups','t',env))()
local function noun(name) return {tag='noun',type={tag='object',name=name}} end
local function team(name) return {tag='noun',type={tag='group',name=name}} end
local function when(lonely) return lonely and {op='spatial',clauses={{relation='lonely',negated=false,parameters={}}}} or {op='always'} end
local terminal
 env.destroylevel=function(reason) terminal=reason end
local edges={{'group','group2'},{'group','group3'},{'group2','group'},{'group2','group3'},{'group3','group'},{'group3','group2'}}
local checked,loops=0,0
for mask=0,63 do for polarity=0,2 do for seed=0,3 do for copies=1,2 do
for _,conditional in ipairs({false,true}) do for _,positive_edge in ipairs({false,true}) do
 local w=RW_CreateSession().world;w.width=20;w.height=20;w.entities={};w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 for id,kind in ipairs({'rock','flag','avatar'}) do w.entities[id]={id=id,kind='object',class='object',archetype=kind,x=id*4,y=3,direction='Right'} end
 if conditional then w.entities[1].x=w.entities[3].x end
 local ast={};env.groupfeatures={};env.objectlist={};for _,kind in ipairs(RW_NounPalette(w)) do env.objectlist[kind]=true end
 local captured={};env.addoption=function(rule,conds) captured[#captured+1]={rule,conds} end
 local function neg(term) return {tag='not',operand=term} end
 local function add(subject,verb,object,condition,rawsubject,rawobject,rawconds)
  ast[#ast+1]={subject=subject,verb=verb,object=object,when=condition}
  env.groupfeatures[#env.groupfeatures+1]={{rawsubject,verb,rawobject},rawconds or {},{}, {}}
 end
 for channel=1,2 do if math.floor(seed/2^(channel-1))%2==1 then
  local name=channel==1 and 'group' or 'group2'
  add({tag='not',operand=noun('rock')},'is',team(name),when(conditional),'not rock',name,conditional and {{'lonely',{}}} or {})
 end end
 if positive_edge then add(team('group'),'is',team('group2'),when(false),'group','group2') end
 for i,edge in ipairs(edges) do if math.floor(mask/2^(i-1))%2==1 then
  local negative=polarity==1 or (polarity==2 and i%2==0)
  for copy=1,copies do
   add(neg(team(edge[1])),'is',negative and neg(team(edge[2])) or team(edge[2]),when(conditional),'not '..edge[1],(negative and 'not ' or '')..edge[2],conditional and {{'lonely',{}}} or {})
  end
 end end
 for _,name in ipairs({'group','group2','group3'}) do add(team(name),'has',noun('avatar'),when(false),name,'avatar') end
 terminal=nil;env.grouprules()
 local generated,deferred,relations=RW_LowerRuleAST(ast,nil,w)
 if terminal=='infinity' then assert(not generated and deferred=='word_rule_limit','negative group loop mismatch');loops=loops+1
 else
  assert(generated and #deferred==0)
  for id=1,3 do
   local lonely=true;for other,e in pairs(w.entities) do if other~=id and e.x==w.entities[id].x and e.y==w.entities[id].y then lonely=false end end
   local expected=0
   for _,rule in ipairs(captured) do if rule[1][1]==w.entities[id].archetype and rule[1][2]=='has' then
    local active=true;for _,clause in ipairs(rule[2]) do local c=clause[1]:gsub('[()]','')
     if c=='never' or (c=='lonely' and not lonely) or (c=='not lonely' and lonely) then active=false end
    end
    if active then expected=expected+1 end
   end end
   assert(#RW_PlanHasBirths(w,{id},relations)==expected,'negative group source mismatch: '..mask..':'..polarity..':'..seed..':'..copies..':'..tostring(conditional)..':'..tostring(positive_edge))
  end
 end
 checked=checked+1
end end end end end end
assert(checked==6144 and loops==2880)
print('PASS: installed NOT noun seeded negative-source GROUP IS graphs, conditions/duplicates/negative targets, direct base and positive transfer ordering ('..checked..' cases; '..loops..' loops)')
