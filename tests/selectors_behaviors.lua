local function same_ids(ids, expected)
    assert(ids and #ids == #expected)
    for index, id in ipairs(expected) do assert(ids[index] == id) end
end
local s = RW_CreateSession()
local spec = {mode = "field", path = {"text", "name"}, value_type = "string"}
local registry = assert(RW_RegisterSelector(nil, "named", spec))
spec.path[1] = "corrupted"
assert(registry.named.path[1] == "text" and RW_GetSelectorRegistry().named == nil)
s.world.selectors = registry
same_ids(RW_SelectEntities(s.world, {kind = "id", value = 4}), {4})
same_ids(RW_SelectEntities(s.world, {kind = "archetype", value = "crate"}), {4, 5})
same_ids(RW_SelectEntities(s.world, {kind = "class", value = "text"}), {6, 7, 8, 9, 10, 11})
same_ids(RW_SelectEntities(s.world, {kind = "class", value = "object"}), {1,2,3,4,5,6,7,8,9,10,11})
same_ids(RW_SelectEntities(s.world, {kind = "named", value = "IS"}), {7, 10})
same_ids(RW_SelectEntities(s.world, {kind = "named", value = "missing"}), {})
same_ids(RW_SelectEntities(s.world, {kind = "id", value = 999}), {})
local raw = {{op = "grant_trait", target = {kind = "named", value = "IS"}, trait = "drive"}}
local concrete = assert(RW_ResolveEffects(s.world, raw))
same_ids(concrete[1].entity_ids, {7, 10})
assert(raw[1].entity_ids == nil)
local definition = {control = true, push = true}
s.world.behavior_registry = assert(RW_RegisterBehavior({}, "drive", definition))
definition.control = false
assert(s.world.behavior_registry.drive.control and RW_GetBehaviorRegistry().drive == nil)
local projected = assert(RW_ProjectWorld(s.world, concrete))
assert(projected.entities[7].behaviors.control and projected.entities[10].behaviors.push)
assert(projected.entities[6].behaviors.control == nil and s.world.entities[7].behaviors == nil)
local inactive = assert(RW_ProjectWorld(projected, {}))
assert(inactive.entities[7].traits == nil and inactive.entities[7].behaviors.control == nil)
-- Explicit empty capability registry cannot silently restore default YOU.
s.world.behavior_registry = {}
local no_control = assert(RW_ProjectWorld(s.world, assert(RW_ResolveEffects(s.world, {
    {op = "grant_trait", target = {kind = "id", value = 1}, trait = "you"}}))))
assert(no_control.entities[1].traits.you and not no_control.entities[1].behaviors.control)
assert(RW_ResolveTurn(no_control, {type = "move", dx = 1, dy = 0}).reason == "no_you")
-- Unknown traits remain available for display/other consumers, without invented movement behavior.
assert(RW_ProjectWorld(s.world, assert(RW_ResolveEffects(s.world, {
    {op = "grant_trait", target = {kind = "id", value = 1}, trait = "highlighted"}}))))

for _, invalid in ipairs({false, {}, {mode = "unknown", value_type = "string"},
    {mode = "field", path = {}, value_type = "string"},
    {mode = "field", path = {"direction"}, value_type = "table"},
    {mode = "field", path = {"direction"}, value_type = "string", callback = function() end}}) do
    assert(RW_RegisterSelector(nil, "bad", invalid) == nil)
end
assert(RW_RegisterSelector(nil, "bad", nil) == nil)
assert(RW_RegisterSelector(registry, "named", registry.named) == nil)
assert(RW_RegisterBehavior(nil, "bad", nil) == nil)
for _, invalid in ipairs({false, {}, {teleport = true}, {control = "yes"}, {control = false}}) do
    assert(RW_RegisterBehavior(nil, "bad", invalid) == nil)
end
local cycle = {mode = "field", value_type = "string"}
cycle.path = {cycle}
assert(RW_RegisterSelector(nil, "cycle", cycle) == nil)
assert(RW_SelectEntities(s.world, {kind = "unknown", value = "x"}) == nil)
assert(RW_SelectEntities(s.world, {kind = "named", value = 1}) == nil)
assert(RW_ResolveEffects(s.world, {{op = "grant_trait", target = {kind = "unknown"}, trait = "you"}}) == nil)
assert(RW_ProjectWorld(s.world, raw) == nil, "Unresolved effect bypassed query boundary")
local invalid_target = {{op = "grant_trait", entity_ids = {1}, trait = "drive"},
    {op = "grant_trait", entity_ids = {999}, trait = "drive"}}
assert(RW_ProjectWorld(s.world, invalid_target) == nil and s.world.entities[1].traits == nil)
assert(RW_ProjectWorld(s.world, {{op = "grant_trait", entity_ids = {[2] = 1}, trait = "drive"}}) == nil)
assert(RW_ProjectWorld(s.world, {{op = "grant_trait", entity_ids = {1, 1}, trait = "drive"}}) == nil)
s.world.behavior_registry = false
assert(RW_ProjectWorld(s.world, {}) == nil)
s.world.selectors = false
assert(RW_EvaluateRules(s.world) == nil and RW_ResolveEffects(s.world, {}) == nil)
-- Even a disabled condition must not hide invalid effect selectors.
local clean = RW_CreateSession()
assert(RW_EvaluateRules(clean.world, {{when = {op = "any", terms = {}}, effects = {
    {op = "grant_trait", target = {kind = "unknown", value = "x"}, trait = "you"}}}}) == nil)
print("PASS: shared selector coverage, capability mapping/retraction, isolation and invalid data rejection")
