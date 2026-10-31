local names={"BEST","WONDER","SAD","PET","ANGRY","HAPPY","PARTY"}
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local function fixture(rows)
 local w=RW_CreateSession().world;w.height=30;w.language.nouns.ROCK="rock"
 w.entities={[1]={id=1,kind="object",class="object",archetype="avatar",x=8,y=8,direction="Up"},
 [2]={id=2,kind="object",class="object",archetype="rock",x=8,y=8,direction="Left"}};w.next_entity_id=3
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
 w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=row*2,direction="None"} end end
 return w
end
local function compile(w) local frame=assert(RW_CompileWorld(w,cs));return assert(RW_ProjectWorld(w,frame.effects)),frame end
for _,name in ipairs(names) do
 local w=fixture({{"AVATAR","IS",name},{"ROCK","FEELING",name,"IS","PUSH"}})
 assert(w.language.properties[name]==name:lower());local p=compile(w)
 assert(p.entities[1].behaviors[name:lower()] and not p.entities[2].behaviors[name:lower()])
 assert(not w.entities[1].behaviors,"projection persisted presentation facts")
 -- FEELING is per identity; give ROCK the property via MIMIC to satisfy it.
 w=fixture({{"AVATAR","IS",name},{"ROCK","MIMIC","AVATAR"},{"ROCK","FEELING",name,"IS","PUSH"}})
 p=compile(w);assert(p.entities[2].behaviors[name:lower()] and p.entities[2].behaviors.push)
 w=fixture({{"AVATAR","IS",name},{"AVATAR","IS","NOT",name}});p=compile(w)
 assert(not p.entities[1].behaviors[name:lower()])
 w=fixture({{"AVATAR","ON","ROCK","IS",name}});p=compile(w);assert(p.entities[1].behaviors[name:lower()])
 w.entities[2].x=9;p=compile(w);assert(not p.entities[1].behaviors[name:lower()])
 w=fixture({{"AVATAR","IS",name}});w.entities[1].broken=1;p=compile(w);assert(not p.entities[1].behaviors[name:lower()])
end
local row={"AVATAR","IS"};for i,name in ipairs(names) do if i>1 then row[#row+1]="AND" end;row[#row+1]=name end
local w=fixture({row});w.width=30;local p=compile(w);for _,name in ipairs(names) do assert(p.entities[1].behaviors[name:lower()]) end
-- Catalog is a pure clone, independently checked against original call arguments.
local catalog=RW_GetPresentationEffectCatalog();local byname={};for _,spec in ipairs(catalog) do byname[spec.name]=spec end
catalog[1].palette[1]=99;assert(RW_GetPresentationEffectCatalog()[1].palette[1]==2)
byname={};for _,spec in ipairs(RW_GetPresentationEffectCatalog()) do byname[spec.name]=spec end
local f=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/effects.lua]],"rb"));local source=f:read("*a");f:close()
source=source:sub(1,assert(source:find("function doeffect(",1,true))-1)
local matched={};local env={math={random=function() return 2 end},do_mod_hook=function() end,MF_cleandecors=function() end}
env.doeffect=function(_,_,word,particle,count,chance,timing,palette,special,_,follow)
 local spec=byname[word];if not spec then return end
 assert(spec.particle==particle and spec.count==count and spec.chance==chance and spec.timing==timing)
 assert(spec.palette[1]==palette[1] and spec.palette[2]==palette[2] and spec.special==special and spec.follow==follow)
 matched[word]=true
end
env.doshorteffect=function(_,word,particle,count,xvel,yvel,palettes)
 local spec=assert(byname[word]);assert(spec.particle==particle and spec.count==count and spec.trigger=="short_effect")
 for i=1,2 do assert(spec.xvel[i]==xvel[i] and spec.yvel[i]==yvel[i]) end
 for i,c in ipairs(palettes) do assert(spec.palettes[i][1]==c[1] and spec.palettes[i][2]==c[2]) end
 matched[word]=true
end
assert(load(source,"installed presentation declarations","t",env))();env.effects(0);env.shorteffectblock()
for _,name in ipairs(names) do assert(matched[name:lower()]) end
print("PASS: seven presentation properties, stacking/NOT/conditions/MIMIC/FEELING/BROKEN, pure catalog and installed effect declarations")
