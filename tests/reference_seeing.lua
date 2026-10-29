-- Execute installed seeing() and simplecheck() with normalized trait declarations.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local source=read('conditions.lua');local a=assert(source:find('seeing = function',1,true));local b=assert(source:find('without = function',a,true))
local env=setmetatable({},{__index=_G});local original=assert(load('return {'..source:sub(a,b-1)..'}','@original_seeing','t',env))().seeing
source=read('tools.lua');local simple_start=assert(source:find('function simplecheck(',1,true));assert(load(source:sub(simple_start),'@original_simplecheck','t',env))()
env.ndirs={{1,0},{0,-1},{-1,0},{0,1},{0,0}};env.roomsizex=9;env.DIR=1;env.XPOS=2;env.YPOS=3
local units,features
env.mmf={newObject=function(id) return units[id] end};env.getname=function(u) return u.name end
env.emptydir=function() return 4 end;env.inbounds=function(x,y) return x>=1 and x<=9 and y>=1 and y<=9 end
env.findobstacle=function(x,y) return env.unitmap[x+y*9] or {} end
env.hasfeature=function(name,verb,trait,id) return (features[id] or {})[trait] and {} or nil end
local dirs={'Right','Up','Left','Down','Mid','None'}
local traits={'stop','push','pull','hide','phantom'};local trait_names={stop='block_entry',push='pushable',pull='pull',hide='hide',phantom='phantom'}
local paramslist={{'rock'},{'not rock'},{'flag'},{'not flag'},{'text'},{'not text'},{'empty'},{'not empty'},{'empty','empty'},{'level'},{'level','level'},{'rock','rock'},{'not rock','rock'}}
local function term(name)
    local neg=name:sub(1,4)=='not ';if neg then name=name:sub(5) end
    local t=(name=='text' or name=='empty') and {tag='special',name=name} or name=='level' and {tag='noun',type={tag='level'}} or {tag='noun',type={tag='object',name=name}}
    return neg and {tag='not',operand=t} or t
end
local count=0
for index,direction in ipairs(dirs) do for bits=0,31 do for _,block_name in ipairs({'rock','flag','text'}) do
for _,far_hidden in ipairs({false,true}) do
    local w=RW_CreateSession().world;w.width=9;w.height=9;w.entities={};w.rule_sources={}
    local v=env.ndirs[math.min(index,5)];if index>4 then v={1,0} end
    local e={id=10,kind='object',class='object',archetype='avatar',x=5,y=5,direction=direction};w.entities[10]=e
    units={};features={};env.unitmap={}
    local function add(id,name,distance)
        local x,y=5+distance*v[1],5+distance*v[2]
        w.entities[id]={id=id,kind='object',class=name=='text' and 'text' or 'object',archetype=name,x=x,y=y,direction='None'}
        units[id]={name=name,values={4,x,y}};env.unitmap[x+y*9]={id};features[id]={}
    end
    local function grant(id,trait)
        features[id][trait]=true
        w.rule_sources[#w.rule_sources+1]={when={op='always'},effects={{op='grant_trait',trait=trait_names[trait],target={kind='id',value=id}}}}
    end
    add(11,block_name,1);add(12,'rock',3)
    for bit,trait in ipairs(traits) do if math.floor(bits/2^(bit-1))%2==1 then grant(11,trait) end end
    if far_hidden then grant(12,'hide') end
    for _,params in ipairs(paramslist) do for _,negative in ipairs({false,true}) do
        local ordered,terms={},{};for _,p in ipairs(params) do terms[#terms+1]=term(p);if p:sub(1,4)=='not ' then ordered[#ordered+1]=p else table.insert(ordered,1,p) end end
        local expected=original(ordered,{},{},{unitid=10,x=5,y=5,dir=math.min(index-1,4),conds={}})
        if negative then expected=not expected end
        local actual=RW_TestEntityCondition(w,{op='spatial',clauses={{relation='seeing',parameters=terms,negated=negative}}},e)
        assert(actual==expected,direction..':'..bits..':'..block_name..':'..tostring(far_hidden)..':'..table.concat(params,','))
        count=count+1
    end end
end end end end
print('PASS: installed SEEING/simplecheck occlusion, HIDE/PHANTOM, six directions, complements/Text/EMPTY/LEVEL/AND matrix ('..count..' cases)')
