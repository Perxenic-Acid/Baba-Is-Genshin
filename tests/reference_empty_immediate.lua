-- Installed levelblock scan-prefix returns, independent of post-delete outcomes.
for _,m in ipairs({'world','reader','grammar','rules','properties','movement','renderer','bootstrap'}) do dofile('external_lua_file/'..m..'.lua') end
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/blocks.lua]],'rb'))
local source=f:read('*a'):gsub('\r\n','\n');f:close()
local a=assert(source:find('local keypair = ""',1,true));local b=assert(source:find('if emptyboom then',a,true))
local c=assert(source:find('local alive = true',b,true));local d=assert(source:find('\n\t\t\t\t\tend',c,true))
local won,ended,reward
local env=setmetatable({roomsizex=24,generaldata={strings={world='custom',base='base'}},WORLD='world',BASEWORLD='base',editor={values={ineditor=1}},INEDITOR='ineditor'},{__index=_G})
env.testcond=function() return true end;env.hasfeature=function() return nil end;env.floating_level=function() return true end
env.setsoundname=function() end;env.MF_particles=function() end;env.MF_playsound=function() end;env.addundo=function() end
env.math=setmetatable({random=function() return 2 end},{__index=math})
env.MF_win=function() won=true end;env.MF_end_single=function() ended=true end;env.MF_credits=function() end
env.MF_bonus=function(n) reward=reward+n end
local native=assert(load('return function(cells) local emptybonus=false local ewintiles,eendtiles,edelthese={},{},{} '..
 'for _,cell in ipairs(cells) do local i,j,emptythings,esafe=cell.x,cell.y,cell.rows,cell.safe '..
 source:sub(a,b-1)..source:sub(c,d-1)..' end end','@installed_empty_immediate','t',env))()
local before={{'you','bonus'},{'you','defeat','win'},{'hot','melt','you','win'},{'end','you','defeat'},{'you','win','boom'}}
local middle={{'you','win'},{'end','you'},{'you','end','win'},{'you','win','boom','safe'},{'you','defeat','win','safe'}}
local after={{'you','bonus'},{'end','you'},{'you','win'}}
local checked=0
for _,first in ipairs(before) do for _,second in ipairs(middle) do for _,third in ipairs(after) do
 local w=RW_CreateSession().world;w.width,w.height=24,10;w.random_state=7;w.entities={}
 local effects,cells={},{}
 for index,traits in ipairs({first,second,third}) do
  local cell={x=index+1,y=2,rows={},safe=false};cells[#cells+1]=cell
  for _,trait in ipairs(traits) do
   cell.rows[#cell.rows+1]={{'empty','is',trait},{}};if trait=='safe' then cell.safe=true end
   effects[#effects+1]={op='grant_trait',trait=trait,entity_ids={},cells={{x=cell.x,y=cell.y}}}
  end
 end
 won,ended,reward=false,false,0;native(cells)
 local projected=assert(RW_ProjectWorld(w,effects))
 local forbidden=function() error('queued EMPTY work after immediate outcome') end
 local plan=assert(RW_PlanEmptyLateContacts(w,projected,{}, {},{victims=RW_ResolveEmptyContactVictims,
  create=RW_PlanCreate,boom=forbidden,products=forbidden,initialize=forbidden,destroy=forbidden}))
 assert(plan.empty_scan_return and (plan.empty_win_contact==true)==(won and not ended) and (plan.end_contact~=nil)==ended)
 assert((plan.bonus_state and plan.bonus_state.to or 0)==reward)
 assert(#plan.changes==0 and not plan.random_state and w.random_state==7)
 if reward>0 then assert(plan.events[1].x==2 and plan.events[1].y==2) end
 checked=checked+1
end end end
print('PASS: installed EMPTY alive WIN/END scan returns, earlier BONUS, later suppression and queued-work bypass ('..checked..' cases)')

