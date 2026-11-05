-- Native contract oracle; production scoped OPEN/SHUT integration is pending.
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
  cases=cases+1
 end end end end end end end
end
print('PASS: installed LEVEL OPEN/SHUT contract, grouped duplicates, SAFE/FLOAT, scoped/EMPTY return and deletion order ('..cases..' cases)')
