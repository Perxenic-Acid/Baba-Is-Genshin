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
local units,empties,enabled,played,particles
-- Conditions are normalized to a per-unit Boolean for this original-source oracle.
env.testcond=function() return enabled end;env.mmf={newObject=function(id) return units[id] end};env.findempty=function() return empties end
env.MF_playsound_freq=function(tune,freq) played[#played+1]={tune=tune,freq=freq} end
env.setsoundname=function() end;env.MF_particles=function() particles=particles+1 end
local notes={};for note in pairs(env.play_data.freqs) do notes[#notes+1]=note end;notes[#notes+1]='unknown';table.sort(notes)
local checked=0
for _,name in ipairs({'rock','avatar','piano','water','text','empty'}) do
for count=0,3 do for copies=1,2 do for _,on in ipairs({false,true}) do for _,note in ipairs(notes) do
    local w=RW_CreateSession().world;w.entities={};w.width=4;w.height=2
    units={};empties={};env.unitlists={[name]={}};env.featureindex={play={}};enabled=on;played={};particles=0
    if name=='empty' then
        for i=1,count do empties[i]=i-1 end
        for i=count+1,8 do w.entities[i]={id=i,class='object',archetype='wall',x=(i-1)%4+1,y=math.floor((i-1)/4)+1} end
    else for i=1,count do
        units[i]={values={i,1},flags={[1]=false}};env.unitlists[name][i]=i
        w.entities[i]={id=i,class=name=='text' and 'text' or 'object',archetype=name,text=name=='text' and {name='ROCK'} or nil,x=i,y=1}
    end end
    local relations={}
    for i=1,copies do
        env.featureindex.play[i]={{name,'play',note},{},{},{}}
        relations[i]={op='play',source_type=(name=='text' or name=='empty') and '@'..name or name,note=note,
            when=on and {op='always'} or {op='spatial',clauses={},requirements={{op='not',condition={op='always'}}}}}
    end
    play();local actual=assert(RW_ResolvePlayEvents(w,relations));assert(#actual==#played,'event grouping')
    local p=0;for i,e in ipairs(actual) do
        assert(e.tune==played[i].tune and e.frequency==played[i].freq,'frequency/tune parity: '..name..':'..note)
        if e.particles then p=p+#e.positions end
    end
    assert(p==particles,'particle multiplicity');checked=checked+1
end end end end end
print('PASS: installed PLAY groups/tunes/all generated frequencies/conditions/EMPTY/particles ('..checked..' cases)')
