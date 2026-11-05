local base=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local function read(name)local f=assert(io.open(base..name,'rb'));local s=f:read('*a');f:close();return s end
local source=read('movement.lua')
local a=assert(source:find('local shifts = findallfeature(nil,"is","shift",true)',1,true))
local b=assert(source:find('local levelshift = findfeature("level","is","shift")',a,true))
local collector=source:sub(a,b-1)
source=read('blocks.lua')
local alignment=assert(source:match('(\t\tfor a,unitid in ipairs%(isshift%) do.-)\n\t\tdoupdate%(%)'))
source=read('tools.lua')
a=assert(source:find('function addunitmap(',1,true));b=assert(source:find('function inside(',a,true));local maps=source:sub(a,b-1)
a=assert(source:find('function findallhere(',1,true));b=assert(source:find('function findempty(',a,true));maps=maps..source:sub(a,b-1)
for _,reverse in ipairs({false,true}) do for _,global_reverse in ipairs({false,true}) do
 local s=RW_CreateSession();local w=s.world;w.entities={};w.next_entity_id=30;w.width=12;w.height=8
 w.unit_order=global_reverse and {2,1,20,10} or {10,20,1,2}
 local tile=reverse and {2,10,1} or {1,10,2};w.cell_order={['3:2']=tile}
 local units={};local sources={};local align_ids={}
 for _,id in ipairs(w.unit_order) do
  local belt=id>=10;local x=id==20 and 4 or 3
  w.entities[id]={id=id,kind='object',class='object',archetype=belt and 'rock' or 'avatar',x=x,y=2,direction=id==20 and 'Up' or belt and 'Right' or 'Down',behaviors={shift=belt}}
  units[id]={values={x,2,id==20 and 1 or belt and 0 or 3,id},strings={belt and 'rock' or 'avatar'},flags={false}}
  if belt then sources[#sources+1]=id end
 end
 local env=setmetatable({XPOS=1,YPOS=2,DIR=3,ID=4,UNITNAME=1,DEAD=1,roomsizex=12,unitmap={},unittypeshere={},moving_units={},been_seen={},featureindex={}}, {__index=_G})
 env.mmf={newObject=function(id)return units[id]end};env.findallfeature=function()return sources end
 env.floating=function()return true end;env.isstill_or_locked=function()return false end
 env.isgone=function()return false end;env.issleep=function()return false end
 env.addundo=function(row)align_ids[#align_ids+1]=row[9]end
 assert(load(maps,'@installed_shift_tiles','t',env))()
 for _,id in ipairs(tile) do env.addunitmap(id,3,2,units[id].strings[1]) end;env.addunitmap(20,4,2,'rock')
 assert(load(collector,'@installed_shift_collection','t',env))()
 local expected={}
 for _,task in ipairs(env.moving_units) do
  local id=task.unitid;expected[#expected+1]=id
  assert(task.dir==0 and task.moves==1)
  env.updateunitmap(id,3,2,4,2,units[id].strings[1]);units[id].values[1]=4;units[id].values[3]=0
 end
 assert(load('return function(isshift) '..alignment..' end','@installed_shift_alignment_order','t',env))()(sources)
 local plan=assert(RW_ResolveShift(w));local moved,aligned={},{}
 for _,row in ipairs(plan.motion_history or {}) do
  if row.from.x~=row.to.x or row.from.y~=row.to.y then moved[#moved+1]=row.entity_id end
  if row.retain==false then aligned[#aligned+1]=row.entity_id;assert(row.map_update==false) end
 end
 assert(#moved==#expected and #aligned==#align_ids)
 for i,id in ipairs(expected) do assert(moved[i]==id,'SHIFT task/arrival dispatch order') end
 for i,id in ipairs(align_ids) do assert(aligned[i]==id,'SHIFT final alignment tile order') end
 local committed,r=RW_Commit(s,plan);assert(r.accepted,r.reason)
 for id,unit in pairs(units) do local e=committed.world.entities[id]
  assert(e.x==unit.values[1] and e.y==unit.values[2] and e.direction==({'Right','Up','Left','Down'})[unit.values[3]+1],'SHIFT final position/facing')
 end
 local stack=committed.world.cell_order and committed.world.cell_order['4:2']
 if not stack then stack={};for _,id in ipairs(w.unit_order) do if committed.world.entities[id].x==4 then stack[#stack+1]=id end end end
 for i,id in ipairs(env.unitmap[28]) do assert(stack[i]==id,'SHIFT committed destination tile order') end
 assert(RW_Undo(committed).world==w)
end end
print('PASS: installed SHIFT independent global/tile collection, queued arrivals, final alignment and Undo (4 cases)')
