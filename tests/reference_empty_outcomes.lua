-- Compare dead EMPTY cells' original-tile WIN/END post-check with installed code.
for _,m in ipairs({'world','reader','grammar','rules','properties','movement','renderer','bootstrap'}) do dofile('external_lua_file/'..m..'.lua') end
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('local keypair = ""',1,true));local b=assert(source:find('if emptyboom then',a,true))
local c=assert(source:find('local alive = true',b,true));local d=assert(source:find('if victory and alive',c,true))
local e=assert(source:find('if (#ewintiles > 0) then',d,true));local g=assert(source:find('if (#things > 0) then',e,true))
local won,ended=false,false
local env=setmetatable({roomsizex=24,generaldata={strings={world='custom',base='base'}},WORLD='world',BASEWORLD='base',editor={values={ineditor=1}},INEDITOR='ineditor'},{__index=_G})
env.testcond=function() return true end;env.hasfeature=function() return nil end;env.floating_level=function() return true end
env.setsoundname=function() end;env.MF_particles=function() end;env.MF_playsound=function() end;env.MF_bonus=function() end;env.addundo=function() end
env.math=setmetatable({random=function() return 2 end},{__index=math})
env.MF_win=function() won=true end;env.MF_end_single=function() ended=true end;env.MF_credits=function() end
local native=assert(load('return function(emptythings) local i,j=5,3 local esafe=false local lsafe=true local emptybonus=false local ewintiles,eendtiles,edelthese={},{},{} '..source:sub(a,b-1)..source:sub(c,d-1)..source:sub(e,g-1)..' end','@installed_empty_post_outcomes','t',env))()
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local checked=0
for _,traits in ipairs({{'YOU','DEFEAT','WIN'},{'WIN','DEFEAT','YOU'},{'END','YOU','DEFEAT'},{'YOU','END','DEFEAT'},
 {'END','YOU','DEFEAT','WIN'},{'YOU','HOT','MELT','WIN'},{'END','YOU','HOT','MELT'},{'YOU','BONUS','WIN'}}) do
for has=0,1 do
 local w=RW_CreateSession().world;w.width,w.height=24,30;w.next_entity_id=10;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 w.entities={[1]={id=1,kind='object',class='object',archetype='rock',x=6,y=3,direction='Right'}}
 local rows={{'EMPTY','IS','RIGHT'}};local original={}
 for _,trait in ipairs(traits) do rows[#rows+1]={'EMPTY','FACING','ROCK','IS',trait};original[#original+1]={{'empty','is',trait:lower()}, {}} end
 if has==1 then rows[#rows+1]={'EMPTY','HAS','FLAG'} end
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'}
 end end
 local frame=assert(RW_CompileWorld(w,cs));local projected=assert(RW_ProjectWorld(w,frame.effects))
 local plan=assert(RW_PlanEmptyLateContacts(w,projected,frame.relations,frame.rules,{
 victims=RW_ResolveEmptyContactVictims,boom=RW_ResolveEmptyBoom,preview=RW_PreviewPlan,
 products=RW_PlanEmptyHasBirths,initialize=RW_InitializeBirthSpecifications,create=RW_PlanCreate,
 destroy=function() error('unexpected real blast') end}))
 env.unitmap={};if has==1 then env.unitmap[5+3*24]={999} end;won,ended=false,false;native(original)
 assert((plan.empty_win_contact==true)==(won and not ended) and (plan.end_contact~=nil)==ended,table.concat(traits,',')..':'..has)
 assert(w.next_entity_id>10 and not w.entities[w.next_entity_id] and not w.infinite_loop)
 checked=checked+1
end end
print('PASS: installed dead EMPTY original-tile WIN/END checks, HAS occupancy and declaration order ('..checked..' cases)')