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

-- Parse one candidate token sequence.
-- Grammar:
-- [NOT] SUBJECT VERB [NOT] OBJECT
local function ast_parse_candidate(
    chosen, sub_not, obj_not,
    language, line, start, output
)
    local subject_pos = 1 + sub_not
    local verb_pos = subject_pos + 1
    local object_pos = verb_pos + 1 + obj_not

    if sub_not == 1
        and not ast_is_not(chosen[1], language) then
        return
    end

    if obj_not == 1
        and not ast_is_not(
            chosen[verb_pos + 1], language
        ) then
        return
    end

    local verb_token = chosen[verb_pos].token
    local verb = language.verbs[verb_token]
    local spec = AST_VERBS[verb]

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

                output[#output + 1] = {
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
                        start = start,
                        finish = start + #chosen - 1,
                        entity_ids = ids
                    }
                }
            end
        end
    end
end

-- Spatial lines -> typed, non-executable Rule AST.
function RW_ParseRuleAST(lines, language)
    if type(lines) ~= "table"
        or not ast_valid_language(language) then
        return nil, "invalid_ast_input"
    end

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

    return output
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
