-- Execute installed POWERED using normalized source conditions, with fresh source cache.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'));local source=f:read('*a');f:close()
local a=assert(source:find('powered = function',1,true));local b=assert(source:find('idle = function',a,true))
local env=setmetatable({},{__index=_G});local original=assert(load('return {'..source:sub(a,b-1)..'}','@original_powered','t',env))().powered
local on,empties
env.testcond=function() return on end;env.findempty=function() return on and empties or {} end
local checked=0
for _,kind in ipairs({'rock','flag','text','empty','level'}) do for count=0,2 do
for _,enabled in ipairs({false,true}) do for channel=1,3 do for requested=1,3 do
for _,full in ipairs({false,true}) do for _,negated in ipairs({false,true}) do
    local w=RW_CreateSession().world;w.width=4;w.height=3;w.entities={};w.rule_sources={}
    w.entities[10]={id=10,kind='object',class='object',archetype='avatar',x=1,y=1,direction='Right'}
    env.unitlists={[kind]={}};local occupied={['1:1']=true};local id=11
    local function add(name)
        local position=id-10;local x,y=position%4+1,math.floor(position/4)+1
        w.entities[id]={id=id,kind='object',class=name=='text' and 'text' or 'object',archetype=name,x=x,y=y}
        occupied[x..':'..y]=true;id=id+1
    end
    if kind~='empty' and kind~='level' then for i=1,count do env.unitlists[kind][i]=id;add(kind) end end
    if full then for y=1,3 do for x=1,4 do if not occupied[x..':'..y] then
        w.entities[id]={id=id,kind='object',class='object',archetype='wall',x=x,y=y};occupied[x..':'..y]=true;id=id+1
    end end end end
    empties={};for y=1,3 do for x=1,4 do if not occupied[x..':'..y] then empties[#empties+1]=x+y*4 end end end
    local suffix=channel==1 and '' or tostring(channel);local trait='power'..suffix
    local req_suffix=requested==1 and '' or tostring(requested)
    local when=enabled and {op='always'} or {op='not',condition={op='always'}}
    local generated={{when={op='spatial',clauses={{relation='powered'..req_suffix,negated=negated,parameters={}}}},effects={{op='grant_trait',trait='safe',target={kind='id',value=10}}}}}
    if kind=='level' then
        if enabled then generated[#generated+1]={when={op='always'},effects={},scoped_power={[trait]=true}} end
    else
        local selector=kind=='empty' and {kind='empty',value='empty'} or kind=='text' and {kind='class',value='text'} or {kind='archetype',value=kind}
        w.rule_sources[1]={when=when,effects={{op='grant_trait',trait=trait,target=selector}}}
    end
    env.featureindex={[trait]={{{kind,'is',trait},when}}};env.poweredstatus={};on=enabled
    local expected=original({}, {}, {}, {x=1,y=1,limit=0,subtype=req_suffix,conds={}})
    if negated then expected=not expected end
    local effects=assert(RW_EvaluateRules(w,generated));local actual=false
    for _,effect in ipairs(effects) do if effect.trait=='safe' then for _,eid in ipairs(effect.entity_ids) do if eid==10 then actual=true end end end end
    assert(actual==expected,kind..':'..count..':'..tostring(enabled)..':'..channel..':'..requested..':'..tostring(full)..':'..tostring(negated))
    checked=checked+1
end end end end end end end
print('PASS: installed POWERED three channels, live counts/conditions/Text/EMPTY/LEVEL/full board/NOT ('..checked..' cases)')
