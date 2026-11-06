local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local tools,blocks=read('tools.lua'),read('blocks.lua')
local function section(s,a,b)local first=assert(s:find('function '..a..'(',1,true));local last=assert(s:find('function '..b..'(',first,true));return s:sub(first,last-1)end
local query=section(tools,'cantmove','findnoun')..section(tools,'reversecheck','simplecheck')
local a=assert(blocks:find('local ishold =',1,true));local b=assert(blocks:find('local issink =',a,true));local body=blocks:sub(a,b-1)
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local directions={{1,0},{0,-1},{-1,0},{0,1}};local cases=0
for _,trait in ipairs({'STILL','LOCKEDRIGHT','LOCKEDUP','LOCKEDLEFT','LOCKEDDOWN'}) do for axis=1,4 do for count=0,2 do for mode=0,1 do for reverse=0,1 do
 local s=RW_CreateSession();local w=s.world;w.width=24;w.height=28;w.entities={};w.next_entity_id=20;w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 local dx,dy=directions[axis][1],directions[axis][2]
 w.unit_order=reverse==0 and {11,14,12,13} or {14,11,12,13}
 for _,spec in ipairs({{11,'avatar',0,12},{12,'rock',2,0},{13,'rock',4,0},{14,'flag',0,13}}) do
  local id=spec[1];w.entities[id]={id=id,kind='object',class='object',archetype=spec[2],x=7+spec[3]*dx,y=7+spec[3]*dy,direction='Up',holder=spec[4]}
 end
 local rows={{'ROCK','IS','HOLD'},mode==0 and {'FLAG','ON','AVATAR','IS',trait} or {'FLAG','IS',trait}}
 for i=1,count do rows[#rows+1]=mode==0 and {'FLAG','IS','REVERSE'} or {'FLAG','ON','AVATAR','IS','REVERSE'} end
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=15+row*2,direction='None'};w.unit_order[#w.unit_order+1]=id
 end end
 local frame,why=RW_CompileWorld(w,cs);assert(frame,why and why.reason)
 local units,ordered={},{};for _,id in ipairs(w.unit_order) do local e=w.entities[id]
  local u={fixed=id,values={e.x,e.y,1,id},strings={e.archetype or 'text_'..e.text.name:lower()},holder=e.holder or 0};units[id]=u;ordered[#ordered+1]=u
 end
 local env=setmetatable({XPOS=1,YPOS=2,DIR=3,ID=4,UNITNAME=1,units=ordered,roomsizex=w.width,delthese={},unitmap={},featureindex={reverse={}}},{__index=_G})
 env.mmf={newObject=function(id)return units[id]end};env.getname=function(u)return u.strings[1]end;env.getunitid=function(id)return id end
 env.getunitswitheffect=function()return {units[12],units[13]}end
 env.findallhere=function(x,y)local r={};for _,u in ipairs(ordered) do if u.values[1]==x and u.values[2]==y then r[#r+1]=u.fixed end end;return r end
 for _,u in ipairs(ordered) do env.unitmap[u.values[1]+u.values[2]*w.width]=true end
 local function onavatar(x,y)return units[11].values[1]==x and units[11].values[2]==y end
 env.hasfeature=function(name,_,property,id,x,y)
  if id==14 and property==trait:lower() and (mode==1 or onavatar(x,y)) then return true end
 end
 env.hasfeature_count=function(name,_,property,id,x,y)return id==14 and property=='reverse' and (mode==0 or onavatar(x,y)) and count or 0 end
 env.floating=function()return true end;env.floating_level=function()return true end;env.addundo=function()end
 env.reversedir=function(dir)return (dir+2)%4 end
 env.update=function(id,x,y,d)local u=units[id];u.values[1],u.values[2],u.values[3]=x,y,d end
 assert(load(query..body,'@installed_HOLD_live_cantmove','t',env))()
 local plan=assert(RW_ResolveHold(assert(RW_ProjectWorld(w,frame.effects)),frame.rules,RW_QueryHoldLocked))
 local result=assert(RW_PreviewPlan(w,plan))
 for id,u in pairs(units) do local e=result.entities[id];assert(e.x==u.values[1] and e.y==u.values[2] and (e.holder or 0)==u.holder,'HOLD live cantmove '..cases)end
 if #plan.changes>0 then local n,r=RW_Commit(s,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==w)end
 assert(w.entities[11].x==7 and w.entities[14].holder==13)
 cases=cases+1
end end end end end
assert(cases==240)
print('PASS: installed HOLD/cantmove/reversecheck live STILL and directional locks, conditional weighted REVERSE, four axes, chain order and Undo ('..cases..' cases)')
