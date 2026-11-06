-- Execute the installed block() MAKE body, including CONVERTED occupancy rules.
dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('local ismake = getunitswithverb("make",delthese)',1,true))
local b=assert(source:find('delthese,doremovalsound = handledels(delthese,doremovalsound)',a,true))
local body=source:sub(a,b-1):gsub('%s*end%s*$','')
local env=setmetatable({},{__index=_G})
env.XPOS=1;env.YPOS=2;env.DIR=3;env.U_LEVELFILE=2;env.U_LEVELNAME=3;env.COLOUR=4;env.CLEARCOLOUR=5;env.UNITNAME=1;env.UNITTYPE=6
env.VISUALLEVEL=4;env.VISUALSTYLE=5;env.COMPLETED=6;env.MAPLEVEL=1;env.CONVERTED=2
env.objectlist={rock=1,avatar=1,flag=1};env.nlist={short={}}
env.delthese={}
local units,groups,births,state
local names={'Right','Up','Left','Down','None'}
function env.fixedrandom(low,high) state=(state*48271)%2147483647;return low+state%(high-low+1) end
function env.getname(unit) return unit.strings[6]=='text' and 'text' or unit.strings[1] end
function env.getunitswithverb() return groups end
env.mmf={newObject=function(id) return units[id] end}
function env.findallhere(x,y)
    local ids={};for id,u in pairs(units) do if u.values[1]==x and u.values[2]==y then ids[#ids+1]=id end end
    table.sort(ids);return ids
end
function env.findnoun(name) return name=='text' or name=='empty' or name=='all' end
local function unit(name,dir,converted)
    return {values={4,4,dir,0,0,0},strings={name,'','','','',name:sub(1,5)=='text_' and 'text' or 'object'},flags={false,converted}}
end
function env.create(name,x,y,dir)
    births[#births+1]={name=name,direction=names[dir+1],x=x,y=y}
    units[100+#births]=unit(name,dir,true)
    units[100+#births].values[1]=x;units[100+#births].values[2]=y
end
local original=assert(load(body,'@original_MAKE','t',env))
local checked=0
for _,source_name in ipairs({'rock','text_rock'}) do for dir=0,4 do
for _,target in ipairs({'rock','avatar','flag','text','empty'}) do
for occupant=0,3 do for duplicate=1,3 do for _,converted_source in ipairs({false,true}) do
    units={[10]=unit(source_name,dir,converted_source)};groups={};births={};state=1
    local raw=units[10]
    local class=raw.strings[6]
    local w={entities={[10]={id=10,kind='object',class=class,x=4,y=4,direction=names[dir+1]}},language={nouns={ROCK='rock',AVATAR='avatar',FLAG='flag'}}}
    if class=='text' then w.entities[10].text={name='ROCK'} else w.entities[10].archetype='rock' end
    local ignored={[10]=converted_source}
    if occupant>0 then
        local noun=occupant==3 and 'text_avatar' or (target=='text' and 'text_flag' or target)
        units[11]=unit(noun,0,occupant==2)
        local other={id=11,kind='object',class=units[11].strings[6],x=4,y=4,direction='Right'}
        if other.class=='text' then other.text={name=noun:sub(6):upper()} else other.archetype=noun end
        w.entities[11]=other;ignored[11]=occupant==2
    end
    local relations={}
    for i=1,duplicate do
        local producers={}
        for _,source_id in ipairs({10,11}) do if units[source_id] and env.getname(units[source_id])==env.getname(raw) then producers[#producers+1]=units[source_id] end end
        groups[i]={target,producers,env.getname(raw)}
        relations[i]={op='make',source_type=class=='text' and '@text' or 'rock',target_type=target=='text' and '@text' or target=='empty' and '@empty' or target}
    end
    original()
    local products,rng=RW_PlanMakeProducts(w,relations,ignored)
    assert(#products==#births,source_name..':'..target..':'..occupant..':'..duplicate)
    for i,p in ipairs(products) do
        local name=p.class=='text' and 'text_'..p.text.name:lower() or p.archetype
        assert(name==births[i].name and p.direction==births[i].direction)
    end
    assert((rng and rng.to or 1)==state)
    checked=checked+1
end end end end end end
print('PASS: installed MAKE duplicate/converted/old-occupant/TEXT/direction-draw matrix ('..checked..' cases)')

-- Run the installed EMPTY MAKE branch, including emptydir's unset direction
-- and random draws even for the non-producing EMPTY target.
env.roomsizex=9;env.emptydir=function() return 4 end
local empty_cases=0
for _,target in ipairs({'rock','avatar','flag','text','empty'}) do for duplicate=1,3 do
    units={};groups={};births={};state=1
    local w={width=8,height=8,entities={},language={nouns={ROCK='rock',AVATAR='avatar',FLAG='flag'}}}
    local id=1
    for y=1,8 do for x=1,8 do if x~=4 or y~=4 then
        w.entities[id]={id=id,kind='object',class='object',archetype='wall',x=x,y=y,direction='None'};id=id+1
    end end end
    local relations={}
    for i=1,duplicate do
        groups[i]={target,{40},'empty'}
        relations[i]={op='make',source_type='@empty',target_type=target=='text' and '@text' or target=='empty' and '@empty' or target}
    end
    original()
    local products,rng=RW_PlanMakeProducts(w,relations)
    assert(#products==#births)
    for i,p in ipairs(products) do
        local name=p.class=='text' and 'text_'..p.text.name:lower() or p.archetype
        assert(name==births[i].name and p.direction==births[i].direction and p.x==4 and p.y==4)
    end
    assert(rng and rng.to==state)
    empty_cases=empty_cases+1
end end
print('PASS: installed EMPTY MAKE unset-facing/Text/duplicates/non-product RNG oracle ('..empty_cases..' cases)')

-- Execute native grouping as well as creation, with nonnumeric creation order.
local features=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/features.lua]],'rb'))
local text=features:read('*a');features:close()
assert(load(text:sub(assert(text:find('function getunitswithverb(',1,true)),assert(text:find('function getunitverbtargets(',1,true))-1),'@original_make_groups','t',env))()
env.nlist.brief={};env.DEAD=3;env.testcond=function() return true end
env.findnoun=function(name,list)
    if list==env.nlist.brief then return false end
    return name=='text' or name=='empty' or name=='all'
end
local ordered_cases=0
for _,order in ipairs({{30,10,20},{20,30,10},{10,20,30}}) do
for _,source_name in ipairs({'rock','text_rock'}) do
for _,target in ipairs({'avatar','flag','text'}) do
for copies=1,2 do for _,unset in ipairs({false,true}) do
    units={};births={};state=17;env.unitlists={};env.featureindex={make={}}
    local name=source_name=='rock' and 'rock' or 'text'
    env.unitlists[name]=order
    local w={entities={},unit_order=order,random_state=17,language={nouns={ROCK='rock',AVATAR='avatar',FLAG='flag'}}}
    for i,id in ipairs({10,20,30}) do
        local dir=unset and 4 or i-1
        units[id]=unit(source_name,dir,false);units[id].values[1]=i+1;units[id].flags[env.DEAD]=false
        w.entities[id]={id=id,kind='object',class=name=='text' and 'text' or 'object',archetype='rock',text=name=='text' and {name='ROCK'} or nil,x=i+1,y=4,direction=names[dir+1]}
    end
    local relations={}
    for i=1,copies do
        env.featureindex.make[i]={{name,'make',target},{},{},{}}
        relations[i]={op='make',source_type=name=='text' and '@text' or name,target_type=target=='text' and '@text' or target}
    end
    original()
    local products,rng=RW_PlanMakeProducts(w,relations)
    assert(#products==#births,'ordered MAKE count')
    for i,p in ipairs(products) do
        local product_name=p.class=='text' and 'text_'..p.text.name:lower() or p.archetype
        local expected=births[i]
        assert(product_name==expected.name and p.x==expected.x and p.y==expected.y and p.direction==expected.direction,'ordered MAKE product and per-source RNG')
    end
    assert((rng and rng.to or 17)==state,'ordered MAKE final RNG')
    ordered_cases=ordered_cases+1
end end end end end
print('PASS: installed MAKE grouping, unit-list product order and per-source random directions ('..ordered_cases..' cases)')
