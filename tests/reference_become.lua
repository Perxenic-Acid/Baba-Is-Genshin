-- Execute original conversion()/convert() with normalized rule conditions.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local f=assert(io.open(base..'convert.lua','rb'));local original_source=f:read('*a');f:close()
local env=setmetatable({},{__index=_G})
assert(load(original_source,'@original_convert','t',env))()
env.XPOS=1;env.YPOS=2;env.DIR=3;env.ID=4;env.CONVERTED=1;env.CURSORSEXIST=1
local unit,actions,frontier
local materials={rock=true,flag=true,text=true}
env.getmat=function(name) return materials[name] and name or nil end
env.getmat_text=function() return true end
env.findnoun=function(name) return name=='text' or name=='all' or name=='empty' end
env.nlist={brief={}}
env.map={[0]={}};env.editor2={values={[1]=0}}
env.objectlist={rock=true,flag=true}
env.unitreference={rock='rock',flag='flag',text='text',text_text='text_text',text_rock='text_rock'}
env.tileslist={};for name in pairs(env.unitreference) do env.tileslist[name]={name=name} end
env.changes={}
env.mmf={newObject=function() return unit end}
env.getname=function() return unit.name end
env.testcond=function(conds) return not conds.blocked end
env.newid=function() frontier=frontier+1;return frontier end
env.addaction=function(_,data) actions[#actions+1]=data end
local function term(name)
    if name=='text' then return {tag='special',name='text'} end
    return {tag='noun',type={tag='object',name=name}}
end
-- Test the exact original IS-identity protection predicate (BECOME is excluded).
f=assert(io.open(base..'rules.lua','rb'));local rs=f:read('*a');f:close()
local pa=assert(rs:find('if (targetrule[1] == target) and',1,true))
local pb=assert(rs:find(' then',pa,true))
local predicate=assert(load('return function(targetrule,target,object) return '..rs:sub(pa+3,pb-1)..' end','@original_identity_predicate','t',env))()
assert(predicate({'rock','is','flag'},'rock','flag'))
assert(not predicate({'rock','is','rock'},'rock','rock'))
assert(not predicate({'rock','become','flag'},'rock','flag'))
assert(not predicate({'rock','become','rock'},'rock','rock'))
local checked=0
for _,name in ipairs({'rock','text'}) do for self_count=0,2 do for become_count=0,2 do
for _,protect in ipairs({false,true}) do for is_count=0,2 do
for _,is_not in ipairs({false,true}) do for _,become_not in ipairs({false,true}) do
    unit={fixed=1,name=name,values={2,2,0,1},flags={[1]=false}}
    env.unitlists={[name]={1}};env.features={};env.featureindex={[name]={}}
    actions={};frontier=9
    local ast={}
    local function add(verb,target,negative,blocked)
        local rule={{name,verb,(negative and 'not ' or '')..target},{blocked=blocked}}
        env.features[#env.features+1]=rule;env.featureindex[name][#env.featureindex[name]+1]=rule
        local rhs=term(target);if negative then rhs={tag='not',operand=rhs} end
        ast[#ast+1]={verb=verb,subject=term(name),object=rhs,when={op='always'}}
    end
    if protect then add('is',name,false,false) end
    for i=1,is_count do add('is','flag',false,protect or is_not) end
    for i=1,self_count do add('become',name,false,false) end
    for i=1,become_count do add('become','flag',false,become_not) end
    if is_not then add('is','flag',true,false) end
    if become_not then add('become','flag',true,false) end
    env.conversion(false)
    local expected={}
    if #actions==0 then expected[1]=name=='text' and 'text_rock' or name
    else for _,action in ipairs(actions) do for _,mat in ipairs(action[2]) do expected[#expected+1]=mat[1] end end end
    local s=RW_CreateSession();s.world.entities={[1]={id=1,kind='object',class=name=='text' and 'text' or 'object',x=2,y=2,direction='Right'}}
    if name=='text' then s.world.entities[1].text={name='ROCK'} else s.world.entities[1].archetype=name end
    s.world.next_entity_id=10;s.world.language.nouns.ROCK='rock';s.world.language.nouns.FLAG='flag'
    local _,deferred,relations=RW_LowerRuleAST(ast,nil,s.world);assert(#deferred==0)
    local changes,why,allocation=RW_PlanConversions(s.world,relations);assert(changes,why)
    local n,r=RW_Commit(s,{consumes_turn=true,changes=changes,id_allocation=allocation});assert(r.accepted,r.reason)
    local actual={};for _,e in pairs(n.world.entities) do actual[#actual+1]=e.class=='text' and 'text_'..e.text.name:lower() or e.archetype end
    table.sort(actual);table.sort(expected)
    assert(table.concat(actual,',')==table.concat(expected,','),table.concat({name,self_count,become_count,tostring(protect),is_count,tostring(is_not),tostring(become_not)},':'))
    checked=checked+1
end end end end end end end
print('PASS: original BECOME/IS conversion multiplicity, Text and verb-specific negative/protection matrix ('..checked..' cases)')
