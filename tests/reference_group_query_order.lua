-- Actual findgroup/hasconds with normalized per-identity condition answers.
local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local f=assert(io.open(base..'tools.lua','rb'));local s=f:read('*a');f:close()
local a=assert(s:find('function findgroup(',1,true));local b=assert(s:find('function groupcheck(',a,true))
local env=setmetatable({XPOS=1,YPOS=2},{__index=_G});assert(load(s:sub(a,b-1),'@installed_findgroup_query_order','t',env))()
env.destroylevel=function()error('unexpected recursive GROUP limit')end
local permutations={{11,12,13},{11,13,12},{12,11,13},{12,13,11},{13,11,12},{13,12,11}}
local saved=RW_TestEntityCondition;local cases=0
local function signature(names)local result={};for _,n in ipairs(names or {})do result[#result+1]=n=='@text' and 'text' or n end;return table.concat(result,',')end
local ok,why=pcall(function()
for channel=1,3 do for _,name in ipairs({'rock','flag','text'})do for _,order in ipairs(permutations)do
for mask=0,7 do for duplicates=1,3 do for recursive=0,1 do
 local group=channel==1 and 'group' or 'group'..channel
 local w=RW_CreateSession().world;w.width=9;w.height=9;w.entities={};w.rule_sources={};w.unit_order={10,order[1],order[2],order[3]}
 local observer={id=10,class='object',archetype='avatar',x=4,y=4,direction='Right'};w.entities[10]=observer
 for id=11,13 do w.entities[id]={id=id,class=name=='text' and 'text' or 'object',archetype=name,x=4,y=4,direction='None'}
  if name=='text'then w.entities[id].text={name='ROCK'}end
 end
 env.unitlists={[name]=order};env.groupmembers={};env.mmf={newObject=function()return {values={4,4}}end}
 local expected_trace,actual_trace={},{};local probes={};local members={}
 for i=1,duplicates do
  local native_condition={{'probe',{}}};native_condition.marker=i
  env.groupmembers[i]={name,native_condition,group,recursive==1}
  local node={op='spatial',clauses={{relation='idle',negated=false,parameters={}}}};probes[node]=i
  members[i]={name=name=='text' and '@text' or name,when=node,recursive=recursive==1}
 end
 w._condition_rules={{group_members={[group]=members}}}
 local function answer(id)return math.floor(mask/2^(id-11))%2==1 end
 env.testcond=function(conds,id,_,_,_,_,_,_,previous)
  expected_trace[#expected_trace+1]=conds.marker..':'..id..':'..signature(previous);return answer(id)
 end
 local expected=env.findgroup(group)
 RW_TestEntityCondition=function(world,node,e,autofail)
  local marker=probes[node]
  if marker then actual_trace[#actual_trace+1]=marker..':'..e.id..':'..signature(world._group_override);return answer(e.id)end
  return saved(world,node,e,autofail)
 end
 local condition={op='spatial',clauses={{relation='on',negated=false,parameters={{tag='noun',type={tag='group',name=group}}}}}}
 local value,reason=saved(w,condition,observer)
 assert(value==(#expected>0 and #expected<=3),'GROUP membership truth '..cases..':'..tostring(reason))
 assert(table.concat(actual_trace,';')==table.concat(expected_trace,';'),'GROUP condition query order '..cases..' expected '..table.concat(expected_trace,';')..' actual '..table.concat(actual_trace,';'))
 if mask==4 and order[1]==13 and duplicates==1 then
  local failid=11
  RW_TestEntityCondition=function(world,node,e,autofail)
   if probes[node]then if e.id==failid then return nil,'word_rule_limit' end;return answer(e.id)end
   return saved(world,node,e,autofail)
  end
  assert(saved(w,condition,observer)==true,'matching first member must skip a later query failure')
  failid=13;local value,reason=saved(w,condition,observer)
  assert(value==nil and reason=='word_rule_limit','first membership failure must propagate')
 end
 cases=cases+1
end end end end end end
end)
RW_TestEntityCondition=saved;assert(ok,why)
assert(cases==2592)
print('PASS: installed GROUP condition unit-list order and first-match short circuit, three channels, Text, duplicates, recursive previous-round signatures and query failures ('..cases..' cases)')
