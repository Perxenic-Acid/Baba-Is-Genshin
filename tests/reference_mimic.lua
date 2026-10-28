-- Execute the installed MIMIC section of subrules(), without ALL preprocessing.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]],'rb'))
local source=f:read('*a');f:close()
local start=assert(source:find('if (featureindex["mimic"] ~= nil) then',1,true))
local finish=assert(source:find('function postrules',start,true))
local env=setmetatable({},{__index=_G})
local additions,terminal
local function condition(v) for _,c in ipairs(v) do if c[1]=='off' then return false end end;return true end
env.getmat=function(name) return name=='rock' or name=='flag' or name=='avatar' end
env.invertconds=function(c) return {{condition(c) and 'off' or 'on'}} end
env.addoption=function(rule,conds,ids,visible,notrule,tags) additions[#additions+1]={rule,conds,ids,tags} end
env.MF_alert=function() end;env.destroylevel=function(reason) terminal=reason end
local run=assert(load('return function() local mimicprotects={} '..source:sub(start,finish-1),'@original_mimic','t',env))()
local s=RW_CreateSession();s.world.entities={[1]={id=1,class='object',kind='object',archetype='rock',x=1,y=1,direction='Right'}}
local function noun(name) return {tag='noun',type={tag='object',name=name}} end
local total=0
for copies=1,3 do for rules=0,3 do for _,positive in ipairs({false,true}) do
for _,negative in ipairs({false,true}) do for _,ban_enabled in ipairs({false,true}) do
    env.featureindex={mimic={},flag={}};additions={};terminal=nil;local ast={}
    local function add(sub,verb,obj,on)
        local c=on and {} or {{'off'}}
        local r={{sub,verb,obj},c,{}, {}}
        env.featureindex[sub]=env.featureindex[sub] or {};table.insert(env.featureindex[sub],r)
        if verb=='mimic' then table.insert(env.featureindex.mimic,r) end
        ast[#ast+1]={verb=verb,subject=noun(sub),object=verb=='is' and {tag='property',name='pushable'} or
            (obj=='not flag' and {tag='not',operand=noun('flag')} or noun(obj)),
            when=on and {op='always'} or {op='spatial',clauses={},requirements={{op='not',condition={op='always'}}}}}
    end
    for i=1,copies do add('rock','mimic','flag',positive) end
    for i=1,rules do add('flag','is','push',true) end
    if negative then add('rock','mimic','not flag',ban_enabled) end
    run()
    local expected=0;for _,r in ipairs(additions) do if condition(r[2]) then expected=expected+1 end end
    local generated=assert(RW_LowerRuleAST(ast,nil,s.world));local effects=assert(RW_EvaluateRules(s.world,generated))
    local actual=0;for _,e in ipairs(effects) do for _,id in ipairs(e.entity_ids) do if id==1 then actual=actual+1 end end end
    assert(actual==expected,'MIMIC matrix mismatch');total=total+1
end end end end end
-- Original limiter includes the 251st generated declaration, then locks the board.
env.featureindex={mimic={{{'rock','mimic','flag'},{},{},{}}},flag={}};additions={};terminal=nil
for i=1,251 do env.featureindex.flag[i]={{'flag','is','push'},{},{},{}} end
run();assert(terminal=='toocomplex' and #additions==251)
print('PASS: installed MIMIC multiplicity/positive and negative conditions ('..total..' cases), 251-product TOO COMPLEX')
