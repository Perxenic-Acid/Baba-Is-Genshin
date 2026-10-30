-- Execute installed doconvert + brokenblock. Only host creation/map callbacks
-- and the selected BROKEN condition predicate are adapted; neither loop is copied.
local function read(path) local f=assert(io.open(path,"rb"));local s=f:read("*a");f:close();return s end
local root=[[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/]]
local convert=read(root.."convert.lua")
convert=convert:sub(assert(convert:find("function doconvert(",1,true)),assert(convert:find("function dolevelconversions(",1,true))-1)
local blocks=read(root.."blocks.lua")
blocks=blocks:sub(assert(blocks:find("function brokenblock(",1,true)),assert(blocks:find("function statusblock(",1,true))-1)
local products={{"rock"},{"rock","flag"},{"rock","rock"},{"avatar"},{"@text"}}
local checked=0
for _,names in ipairs(products) do for mode=0,3 do for mask=0,15 do for deny=0,1 do
    local function granted(name)
        local index=({rock=0,flag=1,avatar=2,text=3})[name]
        return index and math.floor(mask/2^index)%2==1 and not (deny==1 and name=="rock") or false
    end
    local env=setmetatable({featureindex={},unitreference={rock="rock",flag="flag",avatar="avatar",text_avatar="text_avatar"}}, {__index=_G})
    for key in (convert..blocks):gmatch("%[([A-Z][A-Z0-9_]*)%]") do env[key]=key end
    local function record(name,id)
        return {fixed=id,className=name,values=setmetatable({XPOS=2,YPOS=2,DIR=2,ID=id},{__index=function() return 0 end}),
            strings=setmetatable({UNITNAME=name,UNITTYPE=name:sub(1,5)=="text_" and "text" or "object"},{__index=function() return "" end}),
            flags=setmetatable({},{__index=function() return false end}),broken=0,originalname="avatar",followed=-1,holder=0}
    end
    local units={[10]=record("avatar",10)};local mapped={[10]=true};local nextfixed=11;local born={}
    env.spritedata={values=setmetatable({},{__index=function() return 0 end})}
    env.generaldata2={values=setmetatable({},{__index=function() return 0 end})}
    env.mmf={newObject=function(id) return assert(units[id]) end}
    env.MF_emptycreate=function(name) local id=nextfixed;nextfixed=id+1;units[id]=record(name,id);return id end
    env.hasfeature=function(name,_,_,id)
        local current=units[id];assert(current.broken==0 and mapped[10],"source deleted before newborn initialization")
        name=name:sub(1,5)=="text_" and "text" or name
        if not granted(name) then return nil end
        local avatar,rock=0,0
        for other in pairs(mapped) do if other~=id then
            local n=units[other].strings.UNITNAME
            if n=="avatar" then avatar=avatar+1 elseif n=="rock" then rock=rock+1 end
        end end
        if mode==0 or mode==1 and avatar>0 or mode==2 and rock>0 or mode==3 and avatar>0 and rock>0 then return true end
    end
    env.addunit=function(id) units[id].broken=0;env.brokenblock({units[id]});born[#born+1]=units[id] end
    env.addunitmap=function(id) mapped[id]=true end
    env.delunit=function(id) mapped[id]=nil end
    for _,name in ipairs({"addundo","poscorrect","dynamic","MF_specialremove"}) do env[name]=function() end end
    assert(load(blocks,"@installed_brokenblock","t",env))()
    assert(load(convert,"@installed_doconvert","t",env))()
    local mats={};for i,name in ipairs(names) do mats[i]={name=="@text" and "text_avatar" or name,i==1 and 1 or 10+i-2,1} end
    env.doconvert({10,"convert",mats})
    assert(not mapped[10] and #born==#names)
    local w=RW_CreateSession().world
    w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=2,y=2,direction="Left"}}
    w.next_entity_id=10
    local when={op="always"}
    if mode>0 then
        local parameters={}
        if mode==1 or mode==3 then parameters[#parameters+1]={tag="noun",type={tag="object",name="avatar"}} end
        if mode==2 or mode==3 then parameters[#parameters+1]={tag="noun",type={tag="object",name="rock"}} end
        when={op="spatial",clauses={{relation="on",negated=false,parameters=parameters}}}
    end
    local rules={}
    for i,name in ipairs({"rock","flag","avatar","text"}) do if math.floor(mask/2^(i-1))%2==1 then
        rules[#rules+1]={when=when,effects={{op="grant_trait",trait="broken",target={kind=name=="text" and "class" or "archetype",value=name}}}}
    end end
    if deny==1 then rules[#rules+1]={when={op="always"},effects={{op="deny_trait",trait="broken",target={kind="archetype",value="rock"}}}} end
    local relations={};for _,name in ipairs(names) do relations[#relations+1]={op="become",source_type="avatar",target_type=name,when={op="always"}} end
    local changes,err,allocation=RW_PlanConversions(w,relations,rules);assert(changes,err)
    local actual=assert(RW_PreviewPlan(w,{consumes_turn=true,changes=changes,id_allocation=allocation}))
    for i,unit in ipairs(born) do
        local e=actual.entities[i==1 and 1 or 10+i-2]
        assert(e and (e.broken or 0)==unit.broken,"doconvert status mismatch "..checked..":"..i)
        assert(e.direction=="Left")
    end
    for id in pairs(actual.entities) do assert(id>0) end
    checked=checked+1
end end end end
assert(checked==640)
print("PASS: installed doconvert/brokenblock ordering, source/earlier-product witnesses, Text, self/duplicate products and negative grants ("..checked.." cases)")
