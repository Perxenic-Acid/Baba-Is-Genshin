-- Installed selection and collection; collision-free dispatch isolates ordering.
local base='C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/'
local function read(n)local f=assert(io.open(base..n,'rb'));local s=f:read('*a');f:close();return s end
local function section(s,a,b)return s:sub(assert(s:find(a,1,true)),assert(s:find(b,1,true))-1)end
local features=read('features.lua');local tools=read('tools.lua');local movement=read('movement.lua')
local selectors=section(features,'function findfeature(','function findfeatureat(')..section(features,'function findallfeature(','function getunitswitheffect(')..section(tools,'function findall(','function delunit(')
local a=assert(movement:find('function add_moving_units(',1,true));local b=movement:find('\nfunction ',a+1,true)
local collector=movement:sub(a,b and b-1 or #movement)
local permutations={{11,12,13},{11,13,12},{12,11,13},{12,13,11},{13,11,12},{13,12,11}}
local patterns={{{'rock','chill'},{'flag','chill'},{'rock','chill'}},
 {{'rock','move'},{'flag','auto'},{'rock','chill'},{'flag','chill'}},
 {{'flag','chill'},{'rock','move'},{'rock','chill'},{'flag','auto'}},
 {{'text','chill'},{'rock','chill'},{'text','chill'}},
 {{'flag','auto'},{'rock','auto'},{'rock','move'},{'rock','chill'}}}
local directions={'Right','Up','Left','Down'};local vectors={{1,0},{0,-1},{-1,0},{0,1}}
local checked=0
for _,names in ipairs({{'rock','rock','flag'},{'rock','flag','text'}})do for _,order in ipairs(permutations)do
for _,pattern in ipairs(patterns)do for seed=1,16 do for mode=0,7 do
 local w=RW_CreateSession().world;w.width=50;w.height=50;w.entities={};w.next_entity_id=20;w.unit_order=order;w.random_state=seed
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 local units,flags={},{};local effects={};local state=seed
 local env=setmetatable({DIR=1,XPOS=2,YPOS=3,unitlists={},codeunits={},featureindex={}},{__index=_G})
 for i,name in ipairs(names)do
  local id=10+i;local x,y=i*10,i*10;local dir=i%4
  w.entities[id]={id=id,kind='object',class=name=='text' and 'text' or 'object',archetype=name~='text' and name or nil,text=name=='text' and {name='FLAG'} or nil,x=x,y=y,direction=directions[dir+1]}
  units[id]={name=name,values={dir,x,y},broken=0}
  flags[id]={sleep=mode==6 or (mode==1 or mode==5) and id==11,still=mode==7 or (mode==2 or mode==5) and id==12}
 end
 for _,id in ipairs(order)do local name=units[id].name;env.unitlists[name]=env.unitlists[name] or {};env.unitlists[name][#env.unitlists[name]+1]=id
  if name=='text'then env.codeunits[#env.codeunits+1]=id end
 end
 env.mmf={newObject=function(id)return units[id]end};env.getname=function(unit)return unit.name end
 env.testcond=function(conds,id)return not (mode==3 and conds.trait=='chill' and id==13) and not (mode==4 and conds.index%2==0 and id~=12)end
 env.hasfeature=function(_,_,trait,id)return flags[id][trait] and true or nil end
 env.cantmove=function(_,id)return flags[id].still end
 env.updatedir=function(id,dir)units[id].values[1]=dir end
 env.fixedrandom=function()state=state*48271%2147483647;return state%4 end
 assert(load(selectors..collector,'@installed_automatic_source_collection','t',env))()
 for index,spec in ipairs(pattern)do local name,trait=spec[1],spec[2];local conds={index=index,trait=trait}
  env.featureindex[trait]=env.featureindex[trait] or {};env.featureindex[trait][#env.featureindex[trait]+1]={{name,'is',trait},conds}
  local ids={};for id,u in pairs(units)do if u.name==name and env.testcond(conds,id)then ids[#ids+1]=id end end;table.sort(ids)
  effects[#effects+1]={op='grant_trait',trait=trait,target={kind=name=='text' and 'class' or 'archetype',value=name},entity_ids=ids}
 end
 for id,f in pairs(flags)do for _,trait in ipairs({'sleep','still'})do if f[trait]then effects[#effects+1]={op='grant_trait',trait=trait,entity_ids={id}}end end end
 local list,seen={},{}
 for _,trait in ipairs({'move','auto','chill'})do local sources,empty=env.findallfeature(nil,'is',trait);list,seen=env.add_moving_units(trait,sources,list,seen,empty)end
 local projected=assert(RW_ProjectWorld(w,effects));local plan=assert(RW_ResolveAutomatic(projected));local result=assert(RW_PreviewPlan(w,plan))
 assert((plan.random_state and plan.random_state.to or seed)==state,'automatic RNG sequence '..checked)
 local queued={};for _,task in ipairs(list)do queued[task.unitid]=task end
 for id,u in pairs(units)do
  local dir=u.values[1];local task=queued[id];local moves=task and task.moves or 0;local v=vectors[dir+1];local actual=result.entities[id]
  assert(actual.direction==directions[dir+1],'automatic facing allocation '..checked..':'..id)
  assert(actual.x==u.values[2]+v[1]*moves and actual.y==u.values[3]+v[2]*moves,'automatic collected impulses '..checked..':'..id)
 end
 assert(projected.random_state==seed and w.random_state==seed)
 if seed==1 and mode==0 then local session=RW_CreateSession();session.world=w;local n,r=RW_Commit(session,plan);assert(r.accepted,r.reason);assert(RW_Undo(n).world==w)end
 checked=checked+1
end end end end end
assert(checked==7680)
print('PASS: installed findfeature/findallfeature/findall/add_moving_units declaration/unit order, multi-unit CHILL RNG, MOVE/AUTO precedence, duplicates, Text, conditions, SLEEP/STILL and Undo ('..checked..' cases)')
