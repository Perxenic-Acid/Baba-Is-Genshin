-- Execute the installed EAT selection body without engine visuals or deletion.
dofile('external_lua_file/properties.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a');f:close()
local a=assert(source:find('local iseat = getunitswithverb("eat",delthese)',1,true))
local b=assert(source:find('delthese,doremovalsound = handledels(delthese,doremovalsound,true)',a,true))
local env=setmetatable({},{__index=_G})
env.XPOS=1;env.YPOS=2;env.SHAKE=1;env.generaldata={values={}}
local units,groups,world
function env.getunitswithverb() return groups end
function env.findtype(spec,x,y,ignore)
    local ids={}
    for id,u in pairs(units) do
        if id~=ignore and u.values[1]==x and u.values[2]==y
            and ((spec[1]=='text' and u.class=='text') or u.name==spec[1]) then ids[#ids+1]=id end
    end
    table.sort(ids);return ids
end
function env.issafe(id) return world.entities[id].behaviors.safe end
function env.floating(a,b) return world.entities[a].behaviors.float==world.entities[b].behaviors.float end
function env.checkeffecthistory() return 1,'test' end
function env.MF_particles() end
local original=assert(load(source:sub(a,b-1),'@original_EAT','t',env))
local function bit(mask,i) return math.floor(mask/2^(i-1))%2==1 end
local checked=0
for scenario=1,6 do for safe=0,7 do for float=0,7 do for positions=0,3 do for duplicate=1,2 do
    world={entities={}};units={};groups={};env.delthese={}
    for id=1,3 do
        local name=id==1 and 'rock' or id==2 and 'avatar' or ((scenario==4 or scenario==5) and 'text_rock' or 'rock')
        local class=name:sub(1,5)=='text_' and 'text' or 'object'
        local x=id==1 and 4 or (bit(positions,id-1) and 4 or 8)
        units[id]={fixed=id,name=name,class=class,values={x,4}}
        world.entities[id]={id=id,kind='object',class=class,archetype=class=='object' and name or nil,
            x=x,y=4,behaviors={safe=bit(safe,id),float=bit(float,id)}}
    end
    local rules
    if scenario==1 then rules={{'rock','avatar'}}
    elseif scenario==2 then rules={{'rock','rock'}}
    elseif scenario==3 then rules={{'rock','avatar'},{'avatar','rock'}}
    elseif scenario==4 then rules={{'rock','text'}}
    elseif scenario==5 then rules={{'text','rock'}}
    else rules={{'rock','rock'},{'rock','avatar'}} end
    local targets={}
    for _,rule in ipairs(rules) do for j=1,duplicate do
        local actors={}
        for id=1,3 do
            local u=units[id];local name=u.class=='text' and 'text' or u.name
            if name==rule[1] then
                actors[#actors+1]=u;targets[id]=targets[id] or {}
                targets[id][#targets[id]+1]=rule[2]=='text' and '@text' or rule[2]
            end
        end
        groups[#groups+1]={rule[2],actors,rule[1]}
    end end
    original();table.sort(env.delthese)
    local actual=RW_ResolveEatVictims(world,targets)
    assert(#actual==#env.delthese,scenario..':'..safe..':'..float..':'..positions)
    for i,id in ipairs(actual) do assert(id==env.delthese[i]) end
    checked=checked+1
end end end end end
print('PASS: installed EAT self/mutual/Text/SAFE/FLOAT/duplicates/occupancy matrix ('..checked..' cases)')
