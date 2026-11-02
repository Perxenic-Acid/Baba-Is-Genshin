local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=24,30;w.entities={};w.next_entity_id=10;w.random_state=17
 w.language.nouns.ROCK='rock';w.language.nouns.FLAG='flag'
 for y,words in ipairs(rows) do for x,name in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=name},x=x,y=6+y*2,direction='None'}
 end end
 local f,e=RW_CompileWorld(w,cs);assert(f,e and e.reason);return s,f
end
local function names(products)
 local result={};for _,p in ipairs(products) do result[#result+1]=p.class=='text' and 'text_'..p.text.name or p.archetype end
 return table.concat(result,',')
end
local cases={
 {{{'EMPTY','HAS','FLAG'},{'EMPTY','WITHOUT','FLAG','HAS','ROCK'}},'flag'},
 {{{'EMPTY','WITHOUT','FLAG','HAS','ROCK'},{'EMPTY','HAS','FLAG'}},'rock,flag'},
 {{{'EMPTY','HAS','FLAG'},{'EMPTY','ON','FLAG','HAS','ROCK'}},'flag,rock'},
 {{{'EMPTY','HAS','FLAG'},{'EMPTY','HAS','FLAG'},{'EMPTY','WITHOUT','FLAG','HAS','ROCK'}},'flag,flag'},
 {{{'EMPTY','ON','FLAG','HAS','ROCK'},{'EMPTY','HAS','FLAG'}},'flag'},
 {{{'EMPTY','HAS','TEXT'},{'EMPTY','ON','TEXT','HAS','ROCK'}},'text_EMPTY,rock'},
 {{{'EMPTY','HAS','FLAG'},{'EMPTY','ON','FLAG','HAS','ROCK'},{'FLAG','IS','BROKEN'}},'flag,rock'},
 {{{'EMPTY','HAS','FLAG'},{'EMPTY','HAS','ROCK'},{'EMPTY','ON','FLAG','IS','BROKEN'}},'flag'}
}
for _,case in ipairs(cases) do
 local s,f=fixture(case[1]);local w=s.world
 local p,e,prefix,r=RW_InitializeEmptyHasBirths(w,{{x=5,y=3}},f.relations,f.rules)
 assert(p,e);assert(names(p)==case[2],names(p)..' expected '..case[2]);assert(not prefix)
 local state=17*48271%2147483647;assert(r and r.from==17 and r.to==state)
 for _,product in ipairs(p) do assert(product.direction==({'Right','Up','Left','Down'})[state%4+1] and not product.id) end
 local again=assert(RW_InitializeEmptyHasBirths(w,{{x=5,y=3}},f.relations,f.rules));assert(names(again)==names(p))
 assert(w.random_state==17 and not w.entities[w.next_entity_id])
 if case==cases[7] then assert(p[1].broken==1) end
 local plan,why=RW_PlanEmptyContactPhase(w,{{x=5,y=3}},f.relations,f.rules,{births=RW_InitializeEmptyHasBirths,create=RW_PlanCreate})
 assert(plan,why);local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
 assert(n.world.next_entity_id==w.next_entity_id+#p and n.world.random_state==state)
 assert(RW_Undo(n).world==w)
end
-- Query limits retain earlier births and orientation; ordinary errors reject.
local s,f=fixture({{'EMPTY','HAS','FLAG'},{'EMPTY','HAS','ROCK'}})
local original=RW_RelationApplies
for _,reason in ipairs({'word_rule_limit','rule_complexity_limit','ordinary_error'}) do
 RW_RelationApplies=function(w,r,source)
  if r.op=='empty_has' and r.product.archetype=='rock' then return nil,reason end
  return original(w,r,source)
 end
 local p,e,prefix,r=RW_InitializeEmptyHasBirths(s.world,{{x=5,y=3}},f.relations,f.rules)
 RW_RelationApplies=original
 assert(not p and e==reason)
 if reason=='ordinary_error' then assert(not prefix and not r)
 else assert(names(prefix)=='flag' and r.to==17*48271%2147483647) end
end
-- Mixed movement deaths use the streaming adapter too, with atomic Undo.
local death={entity_id='empty:5:3',class='empty',x=5,y=3,direction='None',cause='weak',frame=s.world.entities}
local plan,e=RW_PlanDestructionPhase(s.world,{},f.relations,'weak',{
 empty_births=RW_InitializeEmptyHasBirths,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete},
 {death},f.rules)
assert(plan,e);local n,result=RW_Commit(s,plan);assert(result.accepted,result.reason)
assert(n.world.next_entity_id==s.world.next_entity_id+2 and RW_Undo(n).world==s.world)
print('PASS: sequential EMPTY HAS clauses, same-cell witnesses/BROKEN/Text, duplicate products, shared RNG, limit prefixes and atomic adapters/Undo')
