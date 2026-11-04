-- Occupancy validation is local to each projection, shared by grant/deny cells.
local function effect(x,y,op)
 return {op=op or 'grant_trait',trait='you',entity_ids={},cells={{x=x,y=y}}}
end
local w={width=8,height=8,entities={
 [1]={id=1,class='object',archetype='rock',x=3.0,y=4.0},
 [2]={id=2,class='text',text={name='IS'},x=3,y=4}}}
for _,op in ipairs({'grant_trait','deny_trait'}) do
 local p,e=RW_ProjectWorld(w,{effect(3,4,op)});assert(not p and e=='occupied_empty_cell')
 assert(RW_ProjectWorld(w,{effect(4,4,op)}))
end
-- A later call must observe moved entities, never a cached prior occupancy map.
w.entities[1].x=4;w.entities[2].x=4
assert(RW_ProjectWorld(w,{effect(3,4)}))
local p,e=RW_ProjectWorld(w,{effect(4,4)});assert(not p and e=='occupied_empty_cell')
p,e=RW_ProjectWorld(w,{effect(0,4)});assert(not p and e=='invalid_empty_cell')
local repeated=effect(3,4);repeated.cells[2]={x=3,y=4}
p,e=RW_ProjectWorld(w,{repeated});assert(not p and e=='invalid_empty_cell')
print('PASS: projection occupancy preserves stacked/numeric identity, grant/deny validation, fresh calls and invalid cells')
