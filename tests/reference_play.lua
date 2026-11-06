-- Execute installed grouping, frequency generation and PLAY emission sections.
dofile('external_lua_file/world.lua');dofile('external_lua_file/rules.lua')
local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name) local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({base_octave=4},{__index=_G})
local v=read('values.lua');assert(load(v:sub(assert(v:find('play_data =',1,true)),assert(v:find('controlnames =',1,true))-1),'@original_play_data','t',env))()
local s=read('syntax.lua');assert(load(s:sub(assert(s:find('function generatefreqs()',1,true)),assert(s:find('function setupnounlists()',1,true))-1),'@original_frequencies','t',env))();env.generatefreqs()
s=read('features.lua');assert(load(s:sub(assert(s:find('function getunitswithverb(',1,true)),assert(s:find('function getunitverbtargets(',1,true))-1),'@original_verb_groups','t',env))()
s=read('blocks.lua');local a=assert(s:find('local isplay = getunitswithverb("play",delthese)',1,true));local b=assert(s:find('local ishold =',a,true))
local play=assert(load('return function() local delthese={} '..s:sub(a,b-1)..' end','@original_play','t',env))()
env.nlist={brief={}};env.findnoun=function() return false end;env.DEAD=1;env.XPOS=1;env.YPOS=2;env.roomsizex=4
local units,empties,enabled,played,particles,particle_positions,query_ids
-- Conditions are normalized to a per-unit Boolean for this original-source oracle.
env.testcond=function(_,id) query_ids[#query_ids+1]=id;return enabled end;env.mmf={newObject=function(id) return units[id] end};env.findempty=function() return empties end
env.MF_playsound_freq=function(tune,freq) played[#played+1]={tune=tune,freq=freq} end
env.setsoundname=function() end;env.MF_particles=function(_,x,y) particles=particles+1;particle_positions[#particle_positions+1]={x=x,y=y} end
local notes={};for note in pairs(env.play_data.freqs) do notes[#notes+1]=note end;notes[#notes+1]='unknown';table.sort(notes)
local checked=0
for _,name in ipairs({'rock','avatar','piano','water','text','empty'}) do
for count=0,3 do for copies=1,2 do for _,on in ipairs({false,true}) do for _,note in ipairs(notes) do
    local w=RW_CreateSession().world;w.entities={};w.width=4;w.height=2
    units={};empties={};env.unitlists={[name]={}};env.featureindex={play={}};enabled=on;played={};particles=0;particle_positions={}
    if name=='empty' then
        for i=1,count do empties[i]=i-1 end
        for i=count+1,8 do w.entities[i]={id=i,class='object',archetype='wall',x=(i-1)%4+1,y=math.floor((i-1)/4)+1} end
    else for i=1,count do
        units[i]={values={i,1},flags={[1]=false}};env.unitlists[name][i]=i
        w.entities[i]={id=i,class=name=='text' and 'text' or 'object',archetype=name,text=name=='text' and {name='ROCK'} or nil,x=i,y=1}
    end end
    if name~='empty' then
        -- Original unitlists retain creation order, which need not be numeric ID order.
        w.unit_order={}
        for i=count,1,-1 do w.unit_order[#w.unit_order+1]=i end
        env.unitlists[name]=w.unit_order
    end
    local relations={}
    for i=1,copies do
        env.featureindex.play[i]={{name,'play',note},{},{},{}}
        relations[i]={op='play',source_type=(name=='text' or name=='empty') and '@'..name or name,note=note,
            when=on and {op='always'} or {op='spatial',clauses={},requirements={{op='not',condition={op='always'}}}}}
    end
    query_ids={};play()
    local original_query=RW_RelationApplies;local actual_queries={}
    RW_RelationApplies=function(world,relation,entity,...)
        actual_queries[#actual_queries+1]=entity.id
        return original_query(world,relation,entity,...)
    end
    local actual=assert(RW_ResolvePlayEvents(w,relations));RW_RelationApplies=original_query
    assert(#actual==#played,'event grouping')
    if name~='empty' then
        assert(#actual_queries==#query_ids,'condition query count')
        for i,id in ipairs(query_ids) do assert(actual_queries[i]==id,'condition query unit-list order') end
    end
    local p=0;for i,e in ipairs(actual) do
        assert(e.tune==played[i].tune and e.frequency==played[i].freq,'frequency/tune parity: '..name..':'..note)
        if e.particles then for _,position in ipairs(e.positions) do
            p=p+1
            assert(position.x==particle_positions[p].x and position.y==particle_positions[p].y,'particle unit-list order')
        end end
    end
    assert(p==particles,'particle multiplicity');checked=checked+1
end end end end end
print('PASS: installed PLAY groups/tunes/all generated frequencies/conditions/EMPTY/particles ('..checked..' cases)')
