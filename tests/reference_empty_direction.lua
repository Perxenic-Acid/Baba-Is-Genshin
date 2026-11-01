-- Execute installed tools.lua emptydir; normalize native unit-list order to IDs.
dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],'rb'))
local source=f:read('*a');f:close()
local body=assert(source:match('(function emptydir%(.-\nend)\r?\n'))
local env=setmetatable({XPOS=1,YPOS=2},{__index=_G})
assert(load(body,'@installed_emptydir','t',env))()
local sleep,units
function env.issleep() return sleep end
function env.testcond(c) return c.enabled~=false end
function env.findgroup() return {} end
env.objectlist={rock=1,flag=1,text=1}
env.mmf={newObject=function(id) return units[id] end}
local choices={'right','up','left','follow_rock','follow_flag','follow_text','disabled_down'}
local count=0
for _,a in ipairs(choices) do for _,b in ipairs(choices) do for _,c in ipairs(choices) do
for layout=1,4 do for _,sleeping in ipairs({false,true}) do
    sleep=sleeping;units={};env.unitlists={rock={},flag={},text={}};env.featureindex={empty={}}
    local w={width=9,height=9,entities={},rule_sources={},language={nouns={ROCK='rock',FLAG='flag'}}}
    local positions={
        {{'rock',4,2},{'flag',2,4},{'text',6,4}},
        {{'rock',3,3},{'rock',5,5},{'flag',4,1}},
        {{'flag',4,4},{'flag',6,3},{'text',4,8}},
        {}}
    for id,p in ipairs(positions[layout]) do
        units[id]={values={p[2],p[3]}};table.insert(env.unitlists[p[1]],id)
        w.entities[id]={id=id,kind='object',class=p[1]=='text' and 'text' or 'object',archetype=p[1]~='text' and p[1] or nil,
            text=p[1]=='text' and {name='ROCK'} or nil,x=p[2],y=p[3],direction='None'}
    end
    local rules,ordered={},{}
    if sleep then rules[#rules+1]={when={op='always'},effects={{op='grant_trait',trait='sleep',target={kind='empty',value='empty'}}}} end
    for _,choice in ipairs({a,b,c}) do
        local following=choice:sub(1,7)=='follow_'
        local enabled=choice~='disabled_down'
        local target=following and choice:sub(8) or enabled and choice or 'down'
        local when=enabled and {op='always'} or {op='not',condition={op='always'}}
        env.featureindex.empty[#env.featureindex.empty+1]={{'empty',following and 'follow' or 'is',target},{enabled=enabled}}
        if following then
            ordered[#ordered+1]={op='follow',relation={source_type='@empty',target_type=target=='text' and '@text' or target,when=when}}
        else
            rules[#rules+1]={when=when,effects={{op='grant_trait',trait=target,target={kind='empty',value='empty'}}}}
            ordered[#ordered+1]={op='direction',trait=target,when=when}
        end
    end
    rules[#rules+1]={when={op='always'},effects={},empty_directions=ordered}
    local expected=({'Right','Up','Left','Down','None'})[env.emptydir(4,4)+1]
    local actual=assert(RW_QueryEmptyDirection(w,4,4,rules))
    assert(actual==expected,table.concat({a,b,c},',')..':'..layout..':'..tostring(sleep)..':'..actual..'/'..expected)
    count=count+1
end end end end end
print('PASS: installed EMPTY direction/FOLLOW ordering, nearest/ties/overlap/empty targets, SLEEP/disabled declarations ('..count..' cases)')
