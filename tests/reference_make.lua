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
    births[#births+1]={name=name,direction=names[dir+1]}
    units[100+#births]=unit(name,dir,true)
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
