local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local f=assert(io.open(base..'blocks.lua','rb'));local source=f:read('*a');f:close()
local a=assert(source:find('local ismore =',1,true));local b=assert(source:find('local isplay =',a,true))
local body=source:sub(a,b-1):gsub(string.char(10)..string.char(9)..'end%s*$','')
local vectors={{1,0},{0,-1},{-1,0},{0,1}};local cases=0
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
for _,trait in ipairs({'STOP','PUSH','PULL'}) do for negative=0,1 do for oncopy=0,1 do for reverse=0,1 do for axis=1,4 do
 local w=RW_CreateSession().world;w.width=16;w.height=18;w.entities={};w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 local dx,dy=vectors[axis][1],vectors[axis][2]
 w.entities[11]={id=11,kind='object',class='object',archetype='rock',x=5,y=5,direction='Right'}
 w.entities[12]={id=12,kind='object',class='object',archetype='flag',x=5+2*dx,y=5+2*dy,direction='Up'}
 w.entities[13]={id=13,kind='object',class='object',archetype='avatar',x=5+oncopy*dx,y=5+oncopy*dy,direction='None'}
 local rows=reverse==0 and {{'ROCK','IS','MORE'},{'FLAG','IS','MORE'}} or {{'FLAG','IS','MORE'},{'ROCK','IS','MORE'}}
 rows[3]={'ROCK','ON','AVATAR','IS'};if negative==1 then table.insert(rows[3],'NOT') end;table.insert(rows[3],trait)
 if negative==1 then rows[4]={'ROCK','IS',trait} end
 w.next_entity_id=20;w.unit_order={13,12,11}
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=8+row*2,direction='None'};w.unit_order[#w.unit_order+1]=id
 end end
 local frame,why=RW_CompileWorld(w,cs);assert(frame,why and why.reason)
 local units,births={},{}
 for id,e in pairs(w.entities) do units[id]={fixed=id,values={e.x,e.y},strings={e.archetype or 'text_'..e.text.name:lower()},direction=e.direction} end
 local env=setmetatable({XPOS=1,YPOS=2,UNITNAME=1,roomsizex=w.width,ndirs=vectors,delthese={}},{__index=_G})
 env.getunitswitheffect=function()return reverse==0 and {units[11],units[12]} or {units[12],units[11]}end
 env.mmf={newObject=function(id)return units[id]end}
 env.findobstacle=function(x,y)
  if x<1 or y<1 or x>w.width or y>w.height then return {-1} end
  local r={};for id,u in pairs(units) do if u.values[1]==x and u.values[2]==y then r[#r+1]=id end end;return r
 end
 env.hasfeature=function(name,_,property,id,x,y)
  if name=='rock' and property==trait:lower() then
   local avatar=units[13];local yes=avatar.values[1]==x and avatar.values[2]==y
   if negative==1 then yes=not yes end
   return yes and true or nil
  end
  if name:sub(1,5)=='text_' and property=='push' then return true end
 end
 env.copy=function(id,x,y)
  local mother=units[id];local p={fixed=w.next_entity_id+#births,values={x,y},strings={mother.strings[1]},direction=mother.direction}
  units[p.fixed]=p;births[#births+1]=p;return p
 end
 assert(load(body,'@installed_MORE_live_conditions','t',env))()
 local products=assert(RW_ResolveMoreProducts(assert(RW_ProjectWorld(w,frame.effects)),{
  obstacle=function(context,e)return RW_QueryMoreObstacle(context,e,frame.rules)end,
  initialize=function(context,p)return RW_InitializeBirthSpecifications(context,p,frame.rules)end}))
 assert(#products==#births,'MORE live count '..cases)
 for i,p in ipairs(products) do local expected=births[i]
  assert(p.archetype==expected.strings[1] and p.x==expected.values[1] and p.y==expected.values[2] and p.direction==expected.direction,'MORE live sequence '..cases)
 end
 local words=0;for _,r in ipairs(rows) do words=words+#r end;assert(w.next_entity_id==20+words and not w.more_source_groups)
 cases=cases+1
end end end end end
assert(cases==96)
print('PASS: installed MORE live ON/NOT blocker queries, STOP/PUSH/PULL, four axes, source order and complete copy sequence ('..cases..' cases)')
