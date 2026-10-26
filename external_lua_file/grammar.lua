
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

        effects = {{
            op = "grant_trait",
            target = {
                kind = "archetype",
                value = archetype
            },
            trait = property
        }}
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

    local lines = {{
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
    }}

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
