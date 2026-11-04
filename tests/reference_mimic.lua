-- Execute the installed MIMIC section of subrules(), without ALL preprocessing.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]],'rb'))
local source=f:read('*a');f:close()
local start=assert(source:find('if (featureindex["mimic"] ~= nil) then',1,true))
local finish=assert(source:find('function postrules',start,true))
local env=setmetatable({},{__index=_G})
local additions,terminal
local function condition(v) for _,c in ipairs(v) do if c[1]=='off' then return false end end;return true end
local toolsfile=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local toolsource=toolsfile:read('*a');toolsfile:close()
local ma=assert(toolsource:find('function getmat(m)',1,true));local mb=assert(toolsource:find('function getmat_text(',ma,true))
env.objectlist={rock=1,flag=1,avatar=1,empty=1}
assert(load(toolsource:sub(ma,mb-1),'@original_getmat','t',env))()
env.invertconds=function(c) return {{condition(c) and 'off' or 'on'}} end
env.addoption=function(rule,conds,ids,visible,notrule,tags) additions[#additions+1]={rule,conds,ids,tags} end
env.MF_alert=function() end;env.destroylevel=function(reason) terminal=reason end
local run=assert(load('return function() local mimicprotects={} '..source:sub(start,finish-1),'@original_mimic','t',env))()
local s=RW_CreateSession();s.world.entities={[1]={id=1,class='object',kind='object',archetype='rock',x=1,y=1,direction='Right'}}
local function noun(name)
 if name=='empty' then return {tag='special',name='empty'} end
 return {tag='noun',type={tag='object',name=name}}
end
local total=0
for _,source_name in ipairs({'rock','empty'}) do for _,target_name in ipairs({'flag','empty'}) do
for copies=1,3 do for rules=0,3 do for _,positive in ipairs({false,true}) do
for _,negative in ipairs({false,true}) do for _,ban_enabled in ipairs({false,true}) do
    env.featureindex={mimic={},flag={}};additions={};terminal=nil;local ast={}
    local function add(sub,verb,obj,on)
        local c=on and {} or {{'off'}}
        local r={{sub,verb,obj},c,{}, {}}
        env.featureindex[sub]=env.featureindex[sub] or {};table.insert(env.featureindex[sub],r)
        if verb=='mimic' then table.insert(env.featureindex.mimic,r) end
        ast[#ast+1]={verb=verb,subject=noun(sub),object=verb=='is' and {tag='property',name='pushable'} or
            (obj:sub(1,4)=='not ' and {tag='not',operand=noun(obj:sub(5))} or noun(obj)),
            when=on and {op='always'} or {op='spatial',clauses={},requirements={{op='not',condition={op='always'}}}}}
    end
    for i=1,copies do add(source_name,'mimic',target_name,positive) end
    for i=1,rules do add(target_name,'is','push',true) end
    if negative then add(source_name,'mimic','not '..target_name,ban_enabled) end
    run()
    local expected=0;for _,r in ipairs(additions) do if condition(r[2]) then expected=expected+1 end end
    local generated=assert(RW_LowerRuleAST(ast,nil,s.world));local effects=assert(RW_EvaluateRules(s.world,generated))
    local actual=0;for _,e in ipairs(effects) do
     if source_name=='empty' then
      for _,cell in ipairs(e.cells or {}) do if cell.x==2 and cell.y==2 then actual=actual+1 end end
     else for _,id in ipairs(e.entity_ids) do if id==1 then actual=actual+1 end end end
    end
    if source_name==target_name then actual=actual-rules end
    assert(actual==expected,'MIMIC matrix mismatch');total=total+1
end end end end end end end
-- Original limiter includes the 251st generated declaration, then locks the board.
env.featureindex={mimic={{{'rock','mimic','flag'},{},{},{}}},flag={}};additions={};terminal=nil
for i=1,251 do env.featureindex.flag[i]={{'flag','is','push'},{},{},{}} end
run();assert(terminal=='toocomplex' and #additions==251)
print('PASS: installed MIMIC multiplicity/positive and negative conditions ('..total..' cases), 251-product TOO COMPLEX')
