-- grammar.lua
-- RuleWorld M7: A replaceable three-token grammar
--
-- This grammar recognizes:
-- NOUN COPULA PROPERTY
--
-- The vocabulary is provided by the level.

local function valid_language(language)
    return type(language) == "table"
        and type(language.nouns) == "table"
        and type(language.copulas) == "table"
        and type(language.properties) == "table"
end

local function compile_triplet(a, b, c, language)
    local archetype = language.nouns[a.token]
    local operation = language.copulas[b.token]
    local property = language.properties[c.token]

    if not archetype
        or operation ~= "grant_trait"
        or not property then
        return nil
    end

    return {
        when = {
            op = "always"
        },

        effects = { {
            op = "grant_trait",
            target = {
                kind = "archetype",
                value = archetype
            },
            trait = property
        } }
    }
end

-- Spatial lines + vocabulary -> Rule IR
function RW_CompileRules(lines, language)
    if type(lines) ~= "table"
        or not valid_language(language) then
        return nil, "invalid_grammar_input"
    end

    local rules = {}

    for _, line in ipairs(lines) do
        if type(line) ~= "table"
            or type(line.cells) ~= "table" then
            return nil, "invalid_line"
        end

        local cells = line.cells

        -- Every contiguous three-cell window.
        for i = 1, #cells - 2 do
            local first = cells[i]
            local second = cells[i + 1]
            local third = cells[i + 2]

            if type(first) ~= "table"
                or type(second) ~= "table"
                or type(third) ~= "table" then
                return nil, "invalid_cell"
            end

            -- Every combination of stacked symbols.
            for _, a in ipairs(first) do
                for _, b in ipairs(second) do
                    for _, c in ipairs(third) do
                        local rule = compile_triplet(
                            a, b, c, language
                        )

                        if rule then
                            -- Optional source information.
                            -- Ignored by the existing IR evaluator.
                            rule.source = {
                                axis = line.axis,
                                line = line.index,
                                start = i,
                                entity_ids = {
                                    a.id, b.id, c.id
                                }
                            }

                            rules[#rules + 1] = rule
                        end
                    end
                end
            end
        end
    end

    return rules
end

function RW_GrammarSelfTest()
    -- Deliberately use a different vocabulary
    -- to verify that words are not hardcoded.
    local language = {
        nouns = {
            BOX = "crate",
            STONE = "rock"
        },
        copulas = {
            LINK = "grant_trait"
        },
        properties = {
            MOVE = "pushable"
        }
    }

    local lines = { {
        axis = "horizontal",
        index = 1,
        cells = {
            {
                { id = 1, token = "BOX" },
                { id = 4, token = "STONE" }
            },
            {
                { id = 2, token = "LINK" }
            },
            {
                { id = 3, token = "MOVE" }
            }
        }
    } }

    local rules = RW_CompileRules(lines, language)

    if not rules or #rules ~= 2 then
        return false, "Grammar compilation failed"
    end

    if rules[1].effects[1].target.value ~= "crate"
        or rules[2].effects[1].target.value ~= "rock"
        or rules[1].effects[1].trait ~= "pushable" then
        return false, "Rule IR incorrect"
    end

    -- Break the sentence.
    lines[1].cells[2] = {}

    local broken = RW_CompileRules(lines, language)

    if not broken or #broken ~= 0 then
        return false, "Broken sentence still active"
    end

    return true, "Grammar compiler passed"
end

-- RuleWorld M9.3A
-- Typed Rule AST and verb registry.
-- This parser does not execute rules.

local AST_VERBS = {
    is = {
        phase = "relation",
        rhs = {
            noun = true,
            property = true,
            special = true
        }
    },

    has = {
        phase = "lifecycle",
        rhs = {
            noun = true,
            special = true
        }
    },

    become = {
        phase = "conversion",
        rhs = {
            noun = true,
            special = true
        }
    },

    mimic = {
        phase = "rule_derivation",
        rhs = {
            noun = true,
            special = true
        }
    },

    fear = {
        phase = "movement_intent",
        rhs = {
            noun = true,
            special = true
        }
    }
}

local function ast_clone(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for k, v in pairs(value) do
        copy[ast_clone(k)] = ast_clone(v)
    end

    return copy
end

-- Expose a copy so callers cannot mutate the registry.
function RW_GetVerbRegistry()
    return ast_clone(AST_VERBS)
end

local function valid_verb_registry(registry)
    if type(registry) ~= "table" then return false end
    for name, spec in pairs(registry) do
        if type(name) ~= "string" or name == "" or type(spec) ~= "table"
            or type(spec.phase) ~= "string" or spec.phase == ""
            or type(spec.rhs) ~= "table" then return false end
        for field in pairs(spec) do
            if field ~= "phase" and field ~= "rhs" then return false end
        end
        local categories = 0
        for category, enabled in pairs(spec.rhs) do
            if (category ~= "noun" and category ~= "property" and category ~= "special")
                or type(enabled) ~= "boolean" then return false end
            if enabled then categories = categories + 1 end
        end
        if categories == 0 then return false end
    end
    return true
end

-- Pure data registration: return a new registry, never mutate module globals.
function RW_RegisterVerb(registry, name, specification)
    if registry == nil then registry = AST_VERBS end
    if not valid_verb_registry(registry) or type(name) ~= "string" or name == ""
        or type(specification) ~= "table" then return nil, "invalid_verb_registration" end
    if registry[name] ~= nil then return nil, "duplicate_verb" end
    if not valid_verb_registry({[name] = specification}) then
        return nil, "invalid_verb_registration"
    end
    local result = ast_clone(registry)
    result[name] = ast_clone(specification)
    if not valid_verb_registry(result) then return nil, "invalid_verb_registration" end
    return result
end

local DEFAULT_ORDER = {"subject", "verb", "object"}
local function valid_order(order)
    if type(order) ~= "table" or #order ~= 3 then return false end
    local seen = {}
    for key, role in pairs(order) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 3
            or (role ~= "subject" and role ~= "verb" and role ~= "object")
            or seen[role] then return false end
        seen[role] = true
    end
    return seen.subject and seen.verb and seen.object
end

local function ast_valid_language(language)
    return type(language) == "table"
        and type(language.nouns) == "table"
        and type(language.properties) == "table"
        and type(language.verbs) == "table"
        and (
            language.specials == nil
            or type(language.specials) == "table"
        )
        and (
            language.operators == nil
            or type(language.operators) == "table"
        )
end

-- A lexical token may have multiple interpretations.
-- Grammar does not assume token names are unique
-- across all vocabulary categories.
local function ast_term_options(token, language, property_ok)
    local result = {}

    local noun = language.nouns[token]

    if type(noun) == "string" and noun ~= "" then
        result[#result + 1] = {
            tag = "noun",
            type = {
                tag = "object",
                name = noun
            }
        }
    elseif type(noun) == "table" then
        result[#result + 1] = {
            tag = "noun",
            type = ast_clone(noun)
        }
    end

    local specials = language.specials or {}
    local special = specials[token]

    if type(special) == "string" and special ~= "" then
        result[#result + 1] = {
            tag = "special",
            name = special
        }
    end

    if property_ok then
        local property = language.properties[token]

        if type(property) == "string"
            and property ~= "" then
            result[#result + 1] = {
                tag = "property",
                name = property
            }
        end
    end

    return result
end

local function ast_is_not(word, language)
    local operators = language.operators or {}

    return word ~= nil
        and operators[word.token] == "not"
end

local function ast_wrap_not(term, enabled)
    if not enabled then
        return term
    end

    return {
        tag = "not",
        operand = term
    }
end

-- Enumerate complete physical RHS paths before lowering their terms. A stacked
-- continuation multiplies EVERY term in that sentence, not only the last term.
local function ast_extend_rhs(base, chosen, language, line, start, output)
    local order = language.order or DEFAULT_ORDER
    if order[3] ~= "object" then output[#output+1]=base; return end
    local operators = language.operators or {}
    local registry = language.verb_registry or AST_VERBS
    local function extend(previous, finish, chain)
        local continued = false
        local conjunctions = line.cells[finish+1] or {}
        for _, conjunction in ipairs(conjunctions) do
            if operators[conjunction.token] == "and" then
                local function term_at(position, negated, prefix)
                    for _, word in ipairs(line.cells[position] or {}) do
                        for _, object in ipairs(ast_term_options(word.token,language,true)) do
                            if registry[base.verb].rhs[object.tag] then
                                continued = true
                                local rule = ast_clone(base)
                                rule.object = ast_wrap_not(object,negated)
                                rule.source.entity_ids = ast_clone(previous.source.entity_ids)
                                rule.source.entity_ids[#rule.source.entity_ids+1] = conjunction.id
                                if prefix then rule.source.entity_ids[#rule.source.entity_ids+1] = prefix.id end
                                rule.source.entity_ids[#rule.source.entity_ids+1] = word.id
                                rule.source.finish = position
                                rule.source.rhs_index = (previous.source.rhs_index or 1)+1
                                local next_chain = {}
                                for i, item in ipairs(chain) do next_chain[i]=item end
                                next_chain[#next_chain+1] = rule
                                extend(rule,position,next_chain)
                            end
                        end
                    end
                end
                term_at(finish+2,false)
                for _, word in ipairs(line.cells[finish+2] or {}) do
                    if ast_is_not(word,language) then term_at(finish+3,true,word) end
                end
            end
        end
        if not continued then
            for _, item in ipairs(chain) do
                local rule = ast_clone(item)
                rule.source.sentence_entity_ids = ast_clone(previous.source.entity_ids)
                output[#output+1] = rule
            end
        end
    end
    extend(base,start+#chosen-1,{base})
end

-- Parse one candidate token sequence.
-- Each semantic role occupies one token, with optional NOT before terms.
-- Their spatial order is selected by language.order.
local function ast_parse_candidate(
    chosen, sub_not, obj_not,
    language, line, start, output
)
    local order = language.order or DEFAULT_ORDER
    local registry = language.verb_registry or AST_VERBS
    local positions, cursor = {}, 1
    for _, role in ipairs(order) do
        local negated = (role == "subject" and sub_not == 1)
            or (role == "object" and obj_not == 1)
        if negated then
            if not ast_is_not(chosen[cursor], language) then return end
            cursor = cursor + 1
        end
        positions[role] = cursor
        cursor = cursor + 1
    end
    local subject_pos, verb_pos, object_pos =
        positions.subject, positions.verb, positions.object
    local verb_token = chosen[verb_pos].token
    local verb = language.verbs[verb_token]
    local spec = registry[verb]

    if not spec then
        return
    end

    local subjects = ast_term_options(
        chosen[subject_pos].token,
        language,
        false
    )

    local objects = ast_term_options(
        chosen[object_pos].token,
        language,
        true
    )

    for _, subject in ipairs(subjects) do
        for _, object in ipairs(objects) do
            if spec.rhs[object.tag] then
                local ids = {}

                for i = 1, #chosen do
                    ids[i] = chosen[i].id
                end

                local rule = {
                    subject = ast_wrap_not(
                        subject, sub_not == 1
                    ),

                    verb = verb,

                    object = ast_wrap_not(
                        object, obj_not == 1
                    ),

                    when = {
                        op = "always"
                    },

                    source = {
                        axis = line.axis,
                        line = line.index,
                        leading_not = (order[1] == "subject" and sub_not == 1)
                            or (order[1] == "object" and obj_not == 1),
                        start = start,
                        finish = start + #chosen - 1,
                        entity_ids = ids
                    }
                }
                ast_extend_rhs(rule,chosen,language,line,start,output)
            end
        end
    end
end

-- Suppress only the shorter candidate that starts inside
-- a valid leading NOT expression and shares exactly the same
-- physical word instances. Other overlaps are legitimate.
local function ast_filter_shadowed(rules)
    local hidden = {}

    for _, longer in ipairs(rules) do
        if longer.source.leading_not then
            local a = longer.source

            for j, shorter in ipairs(rules) do
                local b = shorter.source

                if longer.verb == shorter.verb
                    and a.axis == b.axis
                    and a.line == b.line
                    and b.start == a.start + 1
                    and b.finish == a.finish
                    and #a.entity_ids == #b.entity_ids + 1 then

                    local identical_suffix = true

                    for k = 1, #b.entity_ids do
                        if b.entity_ids[k]
                            ~= a.entity_ids[k + 1] then
                            identical_suffix = false
                            break
                        end
                    end

                    if identical_suffix then
                        hidden[j] = true
                    end
                end
            end
        end
    end

    local filtered = {}

    for i, rule in ipairs(rules) do
        if not hidden[i] then
            filtered[#filtered + 1] = rule
        end
    end

    return filtered
end

function RW_GrammarRegistrationSelfTest()
    local spec = {phase = "relation", rhs = {property = true, noun = true}}
    local registry = RW_RegisterVerb(nil, "bind", spec)
    if not registry or registry.bind == nil or RW_GetVerbRegistry().bind ~= nil then
        return false, "Verb registration isolation failed"
    end
    spec.rhs.property = false
    if registry.bind.rhs.property ~= true
        or RW_RegisterVerb(registry, "bind", registry.bind) ~= nil then
        return false, "Verb registration alias/duplicate failed"
    end
    local language = {nouns = {BOX = "crate"}, verbs = {LINK = "bind"},
        properties = {SHOVE = "pushable"}, operators = {NOT = "not"}, verb_registry = registry}
    for _, order in ipairs({
        {"subject", "verb", "object"}, {"object", "verb", "subject"},
        {"verb", "subject", "object"}, {"verb", "object", "subject"},
        {"subject", "object", "verb"}, {"object", "subject", "verb"}
    }) do
        language.order = order
        local cells = {}
        for _, role in ipairs(order) do
            local token = role == "subject" and "BOX" or (role == "verb" and "LINK" or "SHOVE")
            cells[#cells + 1] = {{id = #cells + 1, token = token}}
        end
        local parsed = RW_ParseRuleAST({{axis = "horizontal", index = 1, cells = cells}}, language)
        if not parsed or #parsed ~= 1 or parsed[1].subject.type.name ~= "crate"
            or parsed[1].verb ~= "bind" or parsed[1].object.name ~= "pushable" then
            return false, "Configurable role order failed"
        end
    end
    language.order = {"object", "verb", "subject"}
    local cells = {}
    for index, token in ipairs({"NOT", "SHOVE", "LINK", "BOX"}) do
        cells[index] = {{id = index, token = token}}
    end
    local negated = RW_ParseRuleAST({{axis = "horizontal", index = 1, cells = cells}}, language)
    if not negated or #negated ~= 1 or negated[1].object.tag ~= "not"
        or negated[1].source.entity_ids[1] ~= 1 then
        return false, "Reordered NOT shadowing/provenance failed"
    end
    language.order = {"subject", "subject", "verb"}
    if RW_ParseRuleAST({}, language) ~= nil then return false, "Invalid order accepted" end
    return true, "Isolated verb registration and configurable role order passed"
end

-- Spatial lines -> typed, non-executable Rule AST.
function RW_ParseRuleAST(lines, language)
    if type(lines) ~= "table"
        or not ast_valid_language(language) then
        return nil, "invalid_ast_input"
    end

    local order = language.order
    if order == nil then order = DEFAULT_ORDER end
    if not valid_order(order) then return nil, "invalid_ast_order" end
    local registry = language.verb_registry
    if registry == nil then registry = AST_VERBS end
    if not valid_verb_registry(registry) then return nil, "invalid_verb_registry" end

    local output = {}

    for _, line in ipairs(lines) do
        if type(line) ~= "table"
            or type(line.cells) ~= "table" then
            return nil, "invalid_ast_line"
        end

        local cells = line.cells

        for i = 1, #cells do
            if type(cells[i]) ~= "table" then
                return nil, "invalid_ast_cell"
            end

            for _, word in ipairs(cells[i]) do
                if type(word) ~= "table"
                    or type(word.token) ~= "string"
                    or type(word.id) ~= "number" then
                    return nil, "invalid_ast_token"
                end
            end
        end

        for start = 1, #cells do
            for sub_not = 0, 1 do
                for obj_not = 0, 1 do
                    local span = 3 + sub_not + obj_not
                    local finish = start + span - 1

                    if finish <= #cells then
                        local chosen = {}

                        -- Enumerate stacked text alternatives
                        -- in each cell.
                        local function enumerate(offset)
                            if offset > span then
                                ast_parse_candidate(
                                    chosen,
                                    sub_not,
                                    obj_not,
                                    language,
                                    line,
                                    start,
                                    output
                                )
                                return
                            end

                            local cell =
                                cells[start + offset - 1]

                            for _, word in ipairs(cell) do
                                chosen[offset] = word
                                enumerate(offset + 1)
                            end
                        end

                        enumerate(1)
                    end
                end
            end
        end
    end

    return ast_filter_shadowed(output)
end

function RW_GrammarASTSelfTest()
    local language = {
        nouns = {
            AVATAR = "avatar",
            ROCK = "rock",

            TEXT_TEXT_AVATAR = {
                tag = "text",
                of = {
                    tag = "text",
                    of = {
                        tag = "object",
                        name = "avatar"
                    }
                }
            }
        },

        verbs = {
            IS = "is",
            HAS = "has",
            BECOME = "become",
            MIMIC = "mimic",
            FEAR = "fear"
        },

        properties = {
            PUSH = "pushable",
            YOU = "you"
        },

        specials = {
            TEXT = "text",
            ALL = "all",
            EMPTY = "empty"
        },

        operators = {
            NOT = "not"
        }
    }

    local function parse(tokens)
        local cells = {}

        for i, token in ipairs(tokens) do
            cells[i] = { {
                id = i,
                token = token
            } }
        end

        return RW_ParseRuleAST({ {
            axis = "horizontal",
            index = 2,
            cells = cells
        } }, language)
    end

    local function one(tokens)
        local result = parse(tokens)

        if result and #result == 1 then
            return result[1]
        end

        return nil
    end

    -- All registered verbs are preserved as relations.
    local cases = {
        { "IS",     "is" },
        { "HAS",    "has" },
        { "BECOME", "become" },
        { "MIMIC",  "mimic" },
        { "FEAR",   "fear" }
    }

    for _, item in ipairs(cases) do
        local ast = one({
            "AVATAR", item[1], "ROCK"
        })

        if not ast or ast.verb ~= item[2]
            or ast.subject.tag ~= "noun"
            or ast.object.tag ~= "noun" then
            return false, "Verb parsing: " .. item[1]
        end
    end

    -- IS accepts properties, not just object types.
    local property = one({
        "AVATAR", "IS", "PUSH"
    })

    if not property
        or property.object.tag ~= "property"
        or property.object.name ~= "pushable" then
        return false, "Property RHS failed"
    end

    -- Self-identity is preserved, not silently
    -- converted into a grant_trait operation.
    local identity = one({
        "AVATAR", "IS", "AVATAR"
    })

    if not identity
        or identity.subject.type.name ~= "avatar"
        or identity.object.type.name ~= "avatar" then
        return false, "Identity rule failed"
    end

    -- Negation belongs to the RHS expression.
    local negated = one({
        "AVATAR", "IS", "NOT", "AVATAR"
    })

    if not negated
        or negated.object.tag ~= "not"
        or negated.object.operand.tag ~= "noun" then
        return false, "RHS NOT failed"
    end

    -- Both sides may contain unary NOT.
    local double = one({
        "NOT", "ALL", "IS", "NOT", "TEXT"
    })

    if not double
        or double.subject.tag ~= "not"
        or double.subject.operand.name ~= "all"
        or double.object.tag ~= "not"
        or double.object.operand.name ~= "text" then
        return false, "Dual NOT failed"
    end

    -- EMPTY is kept as a special semantic term.
    local empty = one({
        "NOT", "EMPTY", "IS", "PUSH"
    })

    if not empty
        or empty.subject.tag ~= "not"
        or empty.subject.operand.name ~= "empty" then
        return false, "EMPTY expression failed"
    end

    -- TEXT is not yet reduced to a specific effect.
    local text = one({
        "AVATAR", "IS", "TEXT"
    })

    if not text
        or text.object.tag ~= "special"
        or text.object.name ~= "text" then
        return false, "TEXT expression failed"
    end

    -- Text(Text(Avatar)) remains a structured type.
    local nested = one({
        "TEXT_TEXT_AVATAR", "IS", "PUSH"
    })

    if not nested then
        return false, "Nested text parsing failed"
    end

    local t = nested.subject.type

    if t.tag ~= "text"
        or t.of.tag ~= "text"
        or t.of.of.tag ~= "object"
        or t.of.of.name ~= "avatar" then
        return false, "Nested text structure lost"
    end

    -- Invalid RHS category is rejected.
    local illegal = parse({
        "AVATAR", "HAS", "PUSH"
    })

    if not illegal or #illegal ~= 0 then
        return false, "Verb RHS restriction failed"
    end

    -- NOT-prefix suppression must not erase independent
    -- overlapping sentences or stacked token alternatives.
    local overlapping = parse({
        "AVATAR", "IS", "ROCK", "IS", "PUSH"
    })

    if not overlapping
        or #overlapping ~= 2
        or overlapping[1].source.start ~= 1
        or overlapping[2].source.start ~= 3 then
        return false, "Valid overlapping rules lost"
    end

    local negated_subject = one({
        "NOT", "AVATAR", "IS", "ROCK"
    })

    if not negated_subject
        or negated_subject.subject.tag ~= "not"
        or negated_subject.source.finish ~= 4 then
        return false, "NOT subject shadowing failed"
    end

    -- Source information must survive parsing.
    if property.source.axis ~= "horizontal"
        or property.source.line ~= 2
        or property.source.start ~= 1
        or property.source.finish ~= 3
        or property.source.entity_ids[2] ~= 2 then
        return false, "AST source mapping failed"
    end

    -- Registered definitions must not be mutable
    -- through returned references.
    local registry = RW_GetVerbRegistry()

    registry.is.phase = "corrupted"

    if RW_GetVerbRegistry().is.phase
        ~= "relation" then
        return false, "Verb registry was mutated"
    end

    return true, "Typed Rule AST passed"
end
