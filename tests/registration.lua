local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local registry = assert(RW_RegisterVerb(nil, "bind",
    {phase = "relation", rhs = {noun = true, property = true}}))
local semantics = assert(RW_RegisterSemantics(nil, "bind",
    {property = "grant_trait", noun = "transform"}))
local function parse(tokens, language)
    local cells = {}
    for index, token in ipairs(tokens) do cells[index] = {{id = index, token = token}} end
    return RW_ParseRuleAST({{axis = "vertical", index = 2, cells = cells}}, language)
end
local language = {nouns = {BOX = "crate", HERO = "avatar"}, verbs = {LINK = "bind"},
    properties = {SHOVE = "pushable"}, operators = {NOT = "not"}, verb_registry = registry}
local standard = {nouns = {CRATE = "crate"}, verbs = {IS = "is"},
    properties = {PUSH = "pushable"}, operators = {NOT = "not"}}
local normal = assert(parse({"CRATE", "IS", "PUSH"}, standard))
local canonical = assert(RW_LowerRuleAST(normal))
canonical[1].source = nil
for _, order in ipairs({
    {"subject", "verb", "object"}, {"object", "verb", "subject"},
    {"verb", "subject", "object"}, {"verb", "object", "subject"},
    {"subject", "object", "verb"}, {"object", "subject", "verb"}
}) do
    language.order = order
    for _, negation in ipairs({{false, false}, {true, false}, {false, true}, {true, true}}) do
        local tokens = {}
        for _, role in ipairs(order) do
            if (role == "subject" and negation[1]) or (role == "object" and negation[2]) then
                tokens[#tokens + 1] = "NOT"
            end
            tokens[#tokens + 1] = role == "subject" and "BOX"
                or (role == "verb" and "LINK" or "SHOVE")
        end
        local ast = assert(parse(tokens, language))
        assert(#ast == 1, "Reordered NOT emitted duplicate positive rule")
        assert(ast[1].subject.tag == (negation[1] and "not" or "noun"))
        assert(ast[1].object.tag == (negation[2] and "not" or "property"))
        for index = 1, #tokens do assert(ast[1].source.entity_ids[index] == index) end
        local ir, deferred = RW_LowerRuleAST(ast, semantics)
        if negation[1] or negation[2] then
            assert(#ir == 0 and #deferred == 1, "Unsupported NOT executed")
        else
            ir[1].source = nil
            assert(same(ir, canonical), "Role order changed semantic IR")
        end
    end
end
language.order = {"object", "verb", "subject"}
local relation = assert(parse({"HERO", "LINK", "BOX"}, language))
local _, _, conversion = RW_LowerRuleAST(relation, semantics)
assert(#conversion == 1 and conversion[1].source_type == "crate"
    and conversion[1].target_type == "avatar")
local property_only = assert(RW_RegisterSemantics({}, "bind", {property = "grant_trait"}))
local _, deferred, disabled_conversion = RW_LowerRuleAST(relation, property_only)
assert(#deferred == 1 and #disabled_conversion == 0)
local _, _, identity = RW_LowerRuleAST(assert(parse({"BOX", "LINK", "BOX"}, language)), semantics)
assert(identity[1].op == "protect_transform")

-- Invalid configuration fails before any rules can be returned.
for _, order in ipairs({false, {}, {"subject", "verb", "verb"},
    {"subject", "object", "verb", extra = true}}) do
    language.order = order
    assert(parse({}, language) == nil)
end
language.order = nil
language.verb_registry = false
assert(parse({}, language) == nil)
language.verb_registry = {bind = {phase = "relation", rhs = {unknown = true}}}
assert(parse({}, language) == nil)
assert(RW_RegisterVerb(registry, "invalid", {phase = "relation", rhs = {}}) == nil)
assert(RW_RegisterVerb(registry, "invalid", {phase = "relation",
    rhs = {noun = true}, callback = function() end}) == nil)
assert(RW_RegisterSemantics(semantics, "invalid", {noun = "spawn"}) == nil)
assert(RW_LowerRuleAST(normal, {is = {property = "bad"}}) == nil)
local cycle = {phase = "relation", rhs = {noun = true}}
cycle.loop = cycle
assert(RW_RegisterVerb(nil, "cycle", cycle) == nil)
local semantic_cycle = {}
semantic_cycle.noun = semantic_cycle
assert(RW_RegisterSemantics(nil, "cycle", semantic_cycle) == nil)
assert(RW_GetVerbRegistry().bind == nil and RW_GetSemanticRegistry().bind == nil)
print("PASS: six role orders, semantic IR parity, NOT provenance, registration validation/isolation")
