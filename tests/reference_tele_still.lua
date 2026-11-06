local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local f=assert(io.open(base..'blocks.lua','rb'));local text=f:read('*a');f:close()
local a=assert(text:find('for i,unitid in ipairs(istele) do',1,true));local b=assert(text:find('for a,unitid in ipairs(isshift) do',a,true))
local body='return function(istele) '..text:sub(a,b-1)..' end'
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local cases=0
for _,condition in ipairs({'ON','NEAR'}) do for negative=0,1 do for reverse=0,1 do for source_reverse=0,1 do for floats=0,3 do for seed=1,4 do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.width=16;w.height=18;w.next_entity_id=20;w.random_state=seed
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag';w.unit_order={14,13,12,11}
 for _,spec in ipairs({{11,'avatar',3},{12,'rock',3},{13,'rock',7},{14,'flag',3}}) do
  local id,name,x=spec[1],spec[2],spec[3];w.entities[id]={id=id,kind='object',class='object',archetype=name,x=x,y=3,direction=id==14 and 'Up' or 'Left'}
 end
 local rows={{'ROCK','IS','TELE'},{'FLAG',condition,'AVATAR','IS'}}
 if negative==1 then table.insert(rows[2],'NOT');rows[3]={'FLAG','IS','STILL'} end
 table.insert(rows[2],'STILL')
 if floats%2==1 then rows[#rows+1]={'AVATAR','IS','FLOAT'} end
 if floats>=2 then rows[#rows+1]={'FLAG','IS','FLOAT'} end
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'};w.unit_order[#w.unit_order+1]=id
 end end
 local stack=reverse==0 and {11,14,12} or {14,11,12};w.cell_order={['3:3']=stack}
 local frame,why=RW_CompileWorld(w,cs);assert(frame,why and why.reason)
 local projected=assert(RW_ProjectWorld(w,frame.effects));local sources=source_reverse==0 and {12,13} or {13,12}
 projected.tele_source_groups={sources}
 local units,cells,arrivals={},{['3:3']={},['7:3']={13}},{}
 for _,id in ipairs(stack) do table.insert(cells['3:3'],id) end
 for id,e in pairs(w.entities) do units[id]={fixed=id,values={e.x,e.y},strings={e.archetype or 'text_'..e.text.name:lower(),'object'},flags={false},float=id==11 and floats%2==1 or id==14 and floats>=2 or false} end
 local state=seed
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,UNITTYPE=2,DEAD=1,objectdata={}}, {__index=_G})
 env.mmf={newObject=function(id)return units[id]end};env.getname=function(u)return u.strings[1]end;env.isgone=function()return false end
 env.findallhere=function(x,y)local r={};for _,id in ipairs(cells[x..':'..y] or {}) do r[#r+1]=id end;return r end
 env.hasfeature=function(_,_,trait,id,x,y)
  if trait~='still' or id~=14 then return nil end
  local avatar=units[11];local dx,dy=math.abs(avatar.values[1]-x),math.abs(avatar.values[2]-y)
  local yes=condition=='ON' and dx==0 and dy==0 or condition=='NEAR' and dx<=1 and dy<=1
  if negative==1 then yes=not yes end
  return yes and true or nil
 end
 env.floating=function(x,y)return units[x].float==units[y].float end
 env.fixedrandom=function(lo,hi)state=state*48271%2147483647;return lo+state%(hi-lo+1)end
 env.update=function(id,x,y)
  local u=units[id];local ox,oy=u.values[1],u.values[2]
  if ox~=x or oy~=y then
   local old=cells[ox..':'..oy];for i=#old,1,-1 do if old[i]==id then table.remove(old,i)end end
   local k=x..':'..y;cells[k]=cells[k] or {};table.insert(cells[k],id);arrivals[#arrivals+1]=id
  end
  u.values={x,y}
 end
 env.checkeffecthistory=function()return 1,0 end;env.MF_particles=function()end;env.setsoundname=function()end
 assert(load(body,'@installed_TELE_live_STILL','t',env))()(sources)
 local plan=assert(RW_ResolveTele(projected,nil,frame.rules,RW_QueryTeleStill));local n,r=RW_Commit(s,plan)
 assert(r.accepted or (#plan.changes==0 and not plan.random_state),r.reason)
 local result=r.accepted and n.world or w
 for id,u in pairs(units) do assert(result.entities[id].x==u.values[1] and result.entities[id].y==u.values[2],'TELE live position '..cases)end
 assert((plan.random_state and plan.random_state.to or seed)==state,'TELE live RNG')
 assert(#arrivals==#(plan.motion_history or {}));for i,id in ipairs(arrivals) do assert(plan.motion_history[i].entity_id==id)end
 if r.accepted then assert(RW_Undo(n).world==w)end
 assert(w.entities[11].x==3 and w.entities[14].x==3 and w.random_state==seed)
 cases=cases+1
end end end end end end
assert(cases==256)
print('PASS: installed TELE live STILL/NOT conditions, tile/source order, frozen FLOAT, RNG, arrival history and Undo ('..cases..' cases)')
