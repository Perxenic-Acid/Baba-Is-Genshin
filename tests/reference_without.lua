-- Execute the installed WITHOUT function with normalized parameters.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],'rb'));local source=f:read('*a');f:close()
local a=assert(source:find('without = function',1,true));local b=assert(source:find('above = function',a,true))
local env=setmetatable({},{__index=_G});local original=assert(load('return {'..source:sub(a,b-1)..'}','@original_without','t',env))().without
local function term(name)
    local neg=name:sub(1,4)=='not ';if neg then name=name:sub(5) end
    local t=(name=='text' or name=='empty' or name=='all') and {tag='special',name=name} or name=='level' and {tag='noun',type={tag='level'}} or {tag='noun',type={tag='object',name=name}}
    return neg and {tag='not',operand=t} or t
end
local parameter_sets={{'rock'},{'rock','rock'},{'rock','flag'},{'not rock'},{'not rock','not rock'},{'not text'},{'text'},{'empty'},{'empty','empty'},{'level'},{'level','level'},{'not empty'},{'not level'},{'not rock','not flag'},{'not rock','not text'},{'rock','not flag'}}
local checked=0
for _,own in ipairs({'rock','flag','text','empty'}) do for rocks=0,3 do for flags=0,2 do for texts=0,2 do
    local w=RW_CreateSession().world;w.entities={};w.width=5;w.height=4;env.unitlists={};local id=10
    local function add(name)
        local e={id=id,class=name=='text' and 'text' or 'object',archetype=name,x=(id-10)%5+1,y=math.floor((id-10)/5)+1}
        w.entities[id]=e;env.unitlists[name]=env.unitlists[name] or {};table.insert(env.unitlists[name],id);id=id+1;return e
    end
    local entity=own=='empty' and {class='empty',x=5,y=4} or add(own)
    for i=1,rocks do add('rock') end;for i=1,flags do add('flag') end;for i=1,texts do add('text') end
    local empties={};local occupied={};for _,e in pairs(w.entities) do occupied[e.x..':'..e.y]=true end
    for y=1,w.height do for x=1,w.width do if not occupied[x..':'..y] then empties[#empties+1]=x+y*5 end end end
    env.findempty=function() return empties end
    for _,params in ipairs(parameter_sets) do for _,negated in ipairs({false,true}) do
        local normalized={};for _,p in ipairs(params) do if p:sub(1,4)=='not ' then normalized[#normalized+1]=p else table.insert(normalized,1,p) end end
        local expected=original(normalized,{},{},{name=own,unitid=entity.id or 2,notcond=negated})
        if negated then expected=not expected end
        local terms={};for _,name in ipairs(params) do terms[#terms+1]=term(name) end
        local actual=RW_TestEntityCondition(w,{op='spatial',clauses={{relation='without',negated=negated,parameters=terms}}},entity)
        assert(actual==expected,own..':'..rocks..':'..flags..':'..texts..':'..table.concat(params,',')..':'..tostring(negated))
        checked=checked+1
    end end
end end end end
print('PASS: installed WITHOUT counts/self/Text/EMPTY/LEVEL/complements/NOT ('..checked..' cases)')
