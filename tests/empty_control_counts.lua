-- EMPTY control uses typed, counted temporary agents and only commits real units.
local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap}
local services={project=RW_ProjectWorld,resolve=RW_ResolveTurn,preview=RW_PreviewPlan,convert=RW_PlanConversions,refresh=RW_EvaluateRules,
 contact=function(w,p,k,c) return RW_PlanContactPhase(w,p,k,c,{victims=RW_ResolveContactVictims,births=RW_PlanHasBirths,create=RW_PlanCreate,delete=RW_PlanDelete}) end,
 evaluate=function(w) local f,e=RW_CompileWorld(w,cs);if not f then return nil,e.reason end;return f.effects,nil,f.relations,f.rules end}
local function fixture(rows)
 local s=RW_CreateSession();local w=s.world;w.width,w.height=14,28;w.language.nouns.ROCK='rock';w.language.nouns.LEVEL={tag='level',block_type='level_block'}
 w.entities={[1]={id=1,kind='object',class='object',archetype='rock',x=6,y=3,direction='Left'}};w.next_entity_id=10
 for row,words in ipairs(rows) do for x,word in ipairs(words) do local id=w.next_entity_id;w.next_entity_id=id+1
  w.entities[id]={id=id,kind='object',class='text',text={name=word},x=x,y=6+row*2,direction='None'}
 end end;return s
end
local base={{'EMPTY','NEAR','ROCK','IS','YOU'},{'ROCK','IS','PUSH'}}
local function rows()
 local r={};for _,v in ipairs(base) do r[#r+1]=v end;return r
end
local function run(s,expected)
 local f=assert(RW_CompileWorld(s.world,cs));local traits={};for _,r in ipairs(f.relations) do if r.op=='level_trait' then traits[#traits+1]=r.trait end end
 local projection=assert(RW_ProjectWorld(s.world,f.effects,traits))
 local p,e=RW_PlanTurn(s.world,{type='move',dx=1,dy=0},services);assert(p,e and e.reason)
 for _,c in ipairs(p.changes) do assert(c.entity_id>0,'virtual ID leaked into Plan') end
 local n,r=RW_Commit(s,p);assert(r.accepted,r.reason);assert(n.world.entities[1].x==expected)
 assert(n.world.next_entity_id==s.world.next_entity_id and RW_Undo(n).world==s.world)
 for id,entity in pairs(n.world.entities) do assert(id>0 and entity.class~='empty') end
 assert(not s.world.trait_counts and not s.world.empty_cells)
 return projection,n,p
end
for count=0,4 do
 local r=rows();for i=1,count do r[#r+1]={'EMPTY','IS','REVERSE'} end
 local s=fixture(r);local projected,n=run(s,count%2==0 and 7 or 5)
 assert((projected.empty_cells['5:3'].trait_counts.reverse or 0)==count)
 assert(n.world.entities[1].direction==(count%2==0 and 'Right' or 'Left'))
end
local r=rows();r[#r+1]={'EMPTY','IS','REVERSE'};r[#r+1]={'EMPTY','IS','NOT','REVERSE'}
local projected=run(fixture(r),7);assert(not projected.empty_cells['5:3'].trait_counts.reverse and not projected.empty_cells['5:3'].behaviors.reverse)
r=rows();r[#r+1]={'EMPTY','NEAR','ROCK','IS','REVERSE'};r[#r+1]={'EMPTY','NEAR','ROCK','IS','REVERSE'}
projected=run(fixture(r),7);assert(projected.empty_cells['5:3'].trait_counts.reverse==2)
assert(not projected.empty_cells['1:1'] or not projected.empty_cells['1:1'].trait_counts.reverse)
-- Virtual EMPTY exemption is the explicit project HOLD contract; real pushed
-- targets remain subject to HOLD on their own layer, irrespective of EMPTY FLOAT.
for _,empty_float in ipairs({false,true}) do for _,level_float in ipairs({false,true}) do
 r=rows();r[#r+1]={'LEVEL','IS','HOLD'}
 if level_float then r[#r+1]={'LEVEL','IS','FLOAT'} else r[#r+1]={'ROCK','IS','FLOAT'} end
 if empty_float then r[#r+1]={'EMPTY','IS','FLOAT'} end
 run(fixture(r),7)
end end
for _,trait in ipairs({'SLEEP','STILL','LOCKEDRIGHT'}) do r=rows();r[#r+1]={'EMPTY','IS',trait};run(fixture(r),6) end
print('PASS: EMPTY YOU counted REVERSE parity/NOT/conditions, typed HOLD exemption/layers, SLEEP/STILL/locks, real-only plans/allocators and Undo')
