-- Execute installed FEELING with normalized rule conditions and property roles.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'));local source=f:read('*a');f:close()
local a=assert(source:find('feeling = function',1,true));local b=assert(source:find('lonely = function',a,true))
local env=setmetatable({},{__index=_G});local original=assert(load('return {'..source:sub(a,b-1)..'}','@original_feeling','t',env))().feeling
local enabled_by_condition
env.testcond=function(condition) return enabled_by_condition[condition] end
env.unitreference={text_push='push',text_float='float',text_safe='safe'};env.getactualdata_objlist=function() return 2 end
local map={push='pushable',float='float',safe='safe'}
local parameter_sets={{'push'},{'not push'},{'float'},{'not float'},{'push','push'},{'not push','not push'},{'push','float'},{'not push','push'},{'not float','not push'},{'safe'}}
local checked=0
for pushes=0,2 do for floats=0,2 do for safes=0,1 do
for _,push_on in ipairs({false,true}) do for _,float_on in ipairs({false,true}) do for _,shared in ipairs({false,true}) do
    local w=RW_CreateSession().world;w.entities={[10]={id=10,kind='object',class='object',archetype='rock',x=2,y=2,direction='Right'}};w.rule_sources={}
    env.featureindex={rock={}};enabled_by_condition={}
    local shared_when=push_on and {op='always'} or {op='spatial',clauses={},requirements={{op='not',condition={op='always'}}}}
    local function add(trait,on)
        local when=shared and shared_when or on and {op='always'} or {op='spatial',clauses={},requirements={{op='not',condition={op='always'}}}}
        enabled_by_condition[when]=shared and push_on or not shared and on
        env.featureindex.rock[#env.featureindex.rock+1]={{'rock','is',trait},when}
        w.rule_sources[#w.rule_sources+1]={when=when,effects={{op='grant_trait',trait=map[trait],target={kind='archetype',value='rock'}}}}
    end
    for i=1,pushes do add('push',push_on) end;for i=1,floats do add('float',float_on) end;for i=1,safes do add('safe',true) end
    for _,params in ipairs(parameter_sets) do for _,negative in ipairs({false,true}) do
        local ordered,terms={},{}
        for _,p in ipairs(params) do
            local neg=p:sub(1,4)=='not ';local name=neg and p:sub(5) or p
            local term={tag='property',name=map[name]};terms[#terms+1]=neg and {tag='not',operand=term} or term
            if neg then ordered[#ordered+1]=p else table.insert(ordered,1,p) end
        end
        local expected=original(ordered,{},{},{name='rock',unitid=10,x=2,y=2,limit=0})
        if negative then expected=not expected end
        local actual=RW_TestEntityCondition(w,{op='spatial',clauses={{relation='feeling',negated=negative,parameters=terms}}},w.entities[10])
        assert(actual==expected,pushes..':'..floats..':'..safes..':'..tostring(shared)..':'..tostring(push_on)..':'..tostring(float_on)..':'..table.concat(params,','))
        checked=checked+1
    end end
end end end end end end
print('PASS: installed FEELING properties/complements/NOT, duplicate/shared condition consumption and disabled rules ('..checked..' cases)')
