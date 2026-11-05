-- Native contract and production scoped OPEN/SHUT selection oracle.
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local f=assert(io.open(base..'blocks.lua','rb'));local source=f:read('*a');f:close()
local env=setmetatable({XPOS=1,YPOS=2,SHAKE=1,generaldata={values={}},
 checkeffecthistory=function()return 1,0 end,setsoundname=function()end,MF_particles=function()end},{__index=_G})
local cases=0
for _,kind in ipairs({'open','shut'}) do
 local opposite=kind=='open' and 'shut' or 'open'
 local a=assert(source:find('elseif (action == "'..kind..'") then',1,true))
 local b=assert(source:find('elseif (action == "'..(kind=='open' and 'shut' or 'sink')..'") then',a,true))
 local native=assert(load('return function(lsafe)local action="'..kind..'";if false then '..source:sub(a,b-1)..' end;suffix=true end','@installed_level_'..kind,'t',env))()
 for mask=0,3 do for layers=0,3 do for safe=0,3 do
 for copies=1,2 do for _,map_safe in ipairs({false,true}) do
 for _,scoped in ipairs({false,true}) do for _,empty in ipairs({false,true}) do
  local trace,deleted={},{};env.deleted={}
  local function bit(n,i)return math.floor(n/2^i)%2==1 end
  env.findfeature=function(_,verb,trait)
   assert(verb=='is' and trait==opposite)
   local rows={};for i=1,copies do rows[#rows+1]={'rock',{}} end
   if scoped then rows[#rows+1]={'level',{}} end
   return rows
  end
  env.findall=function(row)
   assert(row[1]=='rock');trace[#trace+1]='findall'
   local ids={};for i=0,1 do if bit(mask,i) then ids[#ids+1]=10+i end end;return ids
  end
  env.floating_level=function(id)
   trace[#trace+1]='float:'..id
   return id==2 or bit(layers,id-10)
  end
  env.issafe=function(id)trace[#trace+1]='safe:'..id;return bit(safe,id-10) end
  env.testcond=function(_,id)assert(id==1);trace[#trace+1]='level';return true end
  env.findallfeature=function(noun,verb,trait)
   assert(noun=='empty' and verb=='is' and trait==opposite)
   trace[#trace+1]='empty';return empty and {{}} or {}
  end
  env.mmf={newObject=function(id)return {values={id,1}} end}
  env.delete=function(id)deleted[#deleted+1]=id;trace[#trace+1]='delete:'..id end
  local destroyed=false;env.destroylevel=function()destroyed=true;trace[#trace+1]='destroy' end
  env.suffix=false;native(map_safe)
  local witnesses,expected={},{}
  for i=0,1 do if bit(mask,i) and bit(layers,i) then witnesses[#witnesses+1]=10+i end end
  local early=not map_safe and (#witnesses>0 or scoped)
  local expected_trace={}
  for copy=1,copies do
   expected_trace[#expected_trace+1]='findall'
   for i=0,1 do if bit(mask,i) then
    expected_trace[#expected_trace+1]='float:'..(10+i)
    if bit(layers,i) then expected_trace[#expected_trace+1]='safe:'..(10+i) end
   end end
   if not map_safe and #witnesses>0 then break end
  end
  if not map_safe and #witnesses>0 then expected_trace[#expected_trace+1]='destroy'
  else
   if scoped then expected_trace[#expected_trace+1]='level' end
   if early then expected_trace[#expected_trace+1]='destroy' end
  end
  if not early then for copy=1,copies do for _,id in ipairs(witnesses) do
   if not bit(safe,id-10) then expected[#expected+1]=id end
  end end end
  assert(destroyed==(not map_safe and (early or empty)))
  assert(env.suffix==not destroyed and #deleted==#expected)
  for i,id in ipairs(expected) do assert(deleted[i]==id,'native grouped duplicate deletion order') end
  if not early then
   for _,id in ipairs(expected) do expected_trace[#expected_trace+1]='delete:'..id end
   expected_trace[#expected_trace+1]='empty'
   if empty then
    expected_trace[#expected_trace+1]='float:2'
    if not map_safe then expected_trace[#expected_trace+1]='destroy' end
   end
  end
  assert(table.concat(trace,',')==table.concat(expected_trace,','),'native unlock query barrier/order')
  if early then
   for _,event in ipairs(trace) do assert(event~='empty' and event:sub(1,7)~='delete:','early map destruction must skip deletes and EMPTY') end
  else
   local empty_index;for i,event in ipairs(trace) do if event=='empty' then empty_index=i end end
   assert(empty_index)
   for i,event in ipairs(trace) do if event:sub(1,7)=='delete:' then assert(i<empty_index) end end
  end
  if RW_ResolveScopedUnlockTargets then
   local w=RW_CreateSession().world;w.entities={};w.unit_order={};w.rule_sources={}
   for i=0,1 do if bit(mask,i) then
    local id=10+i;w.unit_order[#w.unit_order+1]=id
    w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=i+1,y=1,direction='Right',behaviors={float=not bit(layers,i)}}
    if bit(safe,i) then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait='safe',target={kind='id',value=id}}}} end
   end end
   for i=1,copies do w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait=opposite,target={kind='archetype',value='rock'}}}} end
   if scoped then w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait=opposite,target={kind='archetype',value='level_block'}}},scoped_conditions={{op='level_trait',trait=opposite,when={op='always'}}}} end
   local selected=assert(RW_ResolveScopedUnlockTargets(w,{},kind,map_safe))
   assert((selected.level_destroy==true)==early,'production early map retirement '..table.concat({kind,mask,layers,safe,copies,tostring(map_safe),tostring(scoped)},':'))
   local unique,seen={},{};for _,id in ipairs(expected) do if not seen[id] then seen[id]=true;unique[#unique+1]=id end end
   assert(#selected.ids==#unique,'production delete guard multiplicity')
   for i,id in ipairs(unique) do assert(selected.ids[i]==id,'production grouped selection order') end
   w['empty_'..opposite..'_declared']=empty
   assert(RW_LevelUnlockEmptyDestroys(w,{},kind,map_safe)==(empty and not map_safe),'production EMPTY placeholder retirement')
  end
  cases=cases+1
 end end end end end end end
end
print('PASS: installed LEVEL OPEN/SHUT contract, grouped duplicates, SAFE/FLOAT, scoped/EMPTY return and deletion order ('..cases..' cases)')

if RW_ResolveScopedUnlockTargets then
 local w=RW_CreateSession().world;w.entities={};w.unit_order={10,11};w.rule_sources={}
 for _,id in ipairs(w.unit_order) do w.entities[id]={id=id,kind='object',class='object',archetype='rock',x=id-9,y=1,direction='Right'} end
 local marker={op='spatial',clauses={},unlock_safe_marker=true}
 local rules={{when={op='always'},effects={{op='grant_trait',trait='shut',target={kind='archetype',value='rock'}}}},
  {when=marker,effects={{op='grant_trait',trait='safe',target={kind='id',value=11}}}}}
 local original=RW_TestEntityCondition;local queried=false
 RW_TestEntityCondition=function(world,c,e)if c.unlock_safe_marker then queried=true;return nil,'invalid_unlock_safe' end;return original(world,c,e) end
 local result,why=RW_ResolveScopedUnlockTargets(w,rules,'open',false)
 RW_TestEntityCondition=original
 assert(not result and why=='invalid_unlock_safe' and queried,'unsafe map must finish target SAFE queries before destruction')
 rules[2]={when={op='always'},effects={{op='deny_trait',trait='shut',target={kind='archetype',value='rock'}}}}
 assert(not RW_ResolveScopedUnlockTargets(w,rules,'open',false).level_destroy,'negative complementary property blocks witnesses')
 w.entities[10].archetype='level_block';w.entities[11]=nil;w.unit_order={10}
 rules={{when={op='always'},effects={{op='grant_trait',trait='shut',target={kind='archetype',value='level_block'}}}},
  {when={op='always'},effects={},scoped_conditions={{op='level_trait',trait='shut',when={op='always'}}}}}
 assert(#RW_ResolveScopedUnlockTargets(w,rules,'open',true).ids==0,'LEVEL complementary declaration is synthetic, not physical entrance selection')
 print('PASS: scoped unlock SAFE error barrier, negative protection and synthetic LEVEL selection')
end
