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

local AST_NOTES = {C="c",CSHARP="csharp",CFLAT="cflat",D="d",DSHARP="dsharp",DFLAT="dflat",E="e",ESHARP="esharp",EFLAT="eflat",F="f",FSHARP="fsharp",FFLAT="fflat",G="g",GSHARP="gsharp",GFLAT="gflat",A="a",ASHARP="asharp",AFLAT="aflat",B="b",BSHARP="bsharp",BFLAT="bflat",C4="c4",CSHARP4="csharp4",CFLAT4="cflat4",D4="d4",DSHARP4="dsharp4",DFLAT4="dflat4",E4="e4",ESHARP4="esharp4",EFLAT4="eflat4",F4="f4",FSHARP4="fsharp4",FFLAT4="fflat4",G4="g4",GSHARP4="gsharp4",GFLAT4="gflat4",A4="a4",ASHARP4="asharp4",AFLAT4="aflat4",B4="b4",BSHARP4="bsharp4",BFLAT4="bflat4",C5="c5",CSHARP5="csharp5",CFLAT5="cflat5",D5="d5",DSHARP5="dsharp5",DFLAT5="dflat5",E5="e5",ESHARP5="esharp5",EFLAT5="eflat5",F5="f5",FSHARP5="fsharp5",FFLAT5="fflat5",G5="g5",GSHARP5="gsharp5",GFLAT5="gflat5",A5="a5",ASHARP5="asharp5",AFLAT5="aflat5",B5="b5",BSHARP5="bsharp5",BFLAT5="bflat5",C6="c6",CSHARP6="csharp6",D6="d6",DSHARP6="dsharp6",DFLAT6="dflat6",E6="e6",ESHARP6="esharp6",EFLAT6="eflat6",F6="f6",FSHARP6="fsharp6",FFLAT6="fflat6",G6="g6",GSHARP6="gsharp6",GFLAT6="gflat6",A6="a6",AFLAT6="aflat6"}

local AST_VERBS = {
    play={phase="presentation",rhs={note=true}},
    write = {phase="conversion",rhs={noun=true,property=true,special=true,literal=true}},
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

    eat = {phase="destruction",rhs={noun=true,special=true}},
    make = {phase="creation",rhs={noun=true,special=true}},
    follow = {phase="orientation",rhs={noun=true,special=true}},
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
            if (category ~= "noun" and category ~= "property" and category ~= "special" and category ~= "literal" and category ~= "note")
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
        and (language.prepositions == nil or type(language.prepositions) == "table")
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

    if property_ok and type((language.notes or AST_NOTES)[token])=="string" then
        result[#result+1]={tag="note",name=(language.notes or AST_NOTES)[token]}
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

    if property_ok and ((language.verbs or {})[token] or (language.prepositions or {})[token]
        or (language.operators or {})[token] == "and") then
        result[#result+1]={tag="literal",token=token}
    end
    return result
end

local function ast_is_not(word, language)
    local operators = language.operators or {}

    return word ~= nil
        and operators[word.token] == "not"
end

local function ast_wrap_not(term, enabled)
    local count=type(enabled) == "number" and enabled or (enabled and 1 or 0)
    for _=1,count do term={tag="not",operand=term} end
    return term
end

-- Enumerate complete physical RHS paths before lowering their terms. A stacked
-- continuation multiplies EVERY term in that sentence, not only the last term.
local function ast_extend_rhs(base, chosen, language, line, start, output)
    local order = language.order or DEFAULT_ORDER
    if order[3] ~= "object" then output[#output+1]=base; return end
    local operators = language.operators or {}
    local registry = language.verb_registry or AST_VERBS
    local function extend(previous, finish, chain)
        if #output > 50000 then return end
        local continued = false
        local conjunctions = line.cells[finish+1] or {}
        for _, conjunction in ipairs(conjunctions) do
            if operators[conjunction.token] == "and" then
                local function term_at(position, negated, prefixes)
                    for _, word in ipairs(line.cells[position] or {}) do
                        for _, object in ipairs(ast_term_options(word.token,language,true)) do
                            if registry[base.verb].rhs[object.tag] then
                                continued = true
                                local rule = ast_clone(base)
                                rule.object = ast_wrap_not(object,negated)
                                rule.source.entity_ids = ast_clone(previous.source.entity_ids)
                                rule.source.entity_ids[#rule.source.entity_ids+1] = conjunction.id
                                for _,prefix in ipairs(prefixes or {}) do rule.source.entity_ids[#rule.source.entity_ids+1]=prefix.id end
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
                local function prefixes_at(position,prefixes)
                    if #output > 50000 then return end
                    term_at(position,#prefixes,prefixes)
                    for _,word in ipairs(line.cells[position] or {}) do
                        if ast_is_not(word,language) then
                            local more=ast_clone(prefixes); more[#more+1]=word
                            prefixes_at(position+1,more)
                        end
                    end
                end
                prefixes_at(finish+2,{})
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
        local count=role == "subject" and sub_not or (role == "object" and obj_not or 0)
        for _=1,count do
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
                        subject, sub_not
                    ),

                    verb = verb,

                    object = ast_wrap_not(
                        object, obj_not
                    ),

                    when = {
                        op = "always"
                    },

                    source = {
                        axis = line.axis,
                        line = line.index,
                        leading_not = (order[1] == "subject" and sub_not > 0)
                            or (order[1] == "object" and obj_not > 0),
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

-- Canonical syntax: subjects joined by AND, followed by spatial clauses.
local function ast_parse_heads(line,language,output)
    local cells=line.cells
    local registry=language.verb_registry or AST_VERBS
    local operators=language.operators or {}
    local budget=0
    local function append(a,b)
        local r=ast_clone(a);for _,v in ipairs(b) do r[#r+1]=v end;return r
    end
    local function terms(position,property_ok,callback,prefixes)
        budget=budget+1;if budget > 50000 or #output > 50000 then return end
        prefixes=prefixes or {}
        for _,word in ipairs(cells[position] or {}) do
            if ast_is_not(word,language) then terms(position+1,property_ok,callback,append(prefixes,{word})) end
            for _,term in ipairs(ast_term_options(word.token,language,property_ok)) do
                callback(ast_wrap_not(term,#prefixes),position+1,append(prefixes,{word}),#prefixes)
            end
        end
    end
    for start=1,#cells do
        local walk
        walk=function(subjects,clauses,position,path,leading)
            budget=budget+1;if budget > 50000 or #output > 50000 then return end
            for _,word in ipairs(cells[position] or {}) do
                local verb=language.verbs[word.token];local spec=registry[verb]
                if spec then
                    terms(position+1,true,function(object,finish,rhs)
                        local raw=object;while raw.tag == "not" do raw=raw.operand end
                        if spec.rhs[raw.tag] then
                            local chosen=append(append(path,{word}),rhs)
                            local ids={};for _,w in ipairs(chosen) do ids[#ids+1]=w.id end
                            for _,subject in ipairs(subjects) do
                                local base={subject=ast_clone(subject),verb=verb,object=object,
                                    when=#clauses == 0 and {op="always"} or {op="spatial",clauses=ast_clone(clauses)},
                                    source={axis=line.axis,line=line.index,start=start,finish=finish-1,
                                        leading_not=leading > 0,prefix_finish=position-1,entity_ids=ids}}
                                ast_extend_rhs(base,chosen,language,line,start,output)
                            end
                        end
                    end)
                end
                if operators[word.token] == "and" and #clauses == 0 then
                    terms(position+1,false,function(subject,finish,words)
                        walk(append(subjects,{subject}),clauses,finish,append(append(path,{word}),words),leading)
                    end)
                end
            end
            local function condition_at(cursor,prefix)
                for _,word in ipairs(cells[cursor] or {}) do
                    if ast_is_not(word,language) then condition_at(cursor+1,append(prefix,{word})) end
                    local relation=(language.prepositions or {})[word.token]
                    if relation == "on" or relation == "near" or relation == "nextto" or relation == "above"
                        or relation == "below" or relation == "besideleft" or relation == "besideright" or relation == "facing" then
                        local arguments
                        arguments=function(at,params,words)
                            terms(at,relation=="facing",function(parameter,finish,more)
                                local raw=parameter;while raw.tag=="not" do raw=raw.operand end
                                if raw.tag=="property" and raw.name~="right" and raw.name~="up" and raw.name~="left" and raw.name~="down" then return end
                                local next_params=append(params,{parameter});local next_words=append(words,more)
                                local clause={relation=relation,negated=#prefix % 2 == 1,parameters=next_params}
                                walk(subjects,append(clauses,{clause}),finish,append(path,next_words),leading)
                                for _,conjunction in ipairs(cells[finish] or {}) do
                                    if operators[conjunction.token] == "and" then
                                        arguments(finish+1,next_params,append(next_words,{conjunction}))
                                    end
                                end
                            end)
                        end
                        arguments(cursor+1,{},append(prefix,{word}))
                    end
                end
            end
            condition_at(position,{})
        end
        terms(start,false,function(subject,position,path,leading) walk({subject},{},position,path,leading) end)
    end
    if budget > 50000 or #output > 50000 then return nil,"rule_complexity_limit" end
    return true
end

-- Suppress only the shorter candidate that starts inside
-- a valid leading NOT expression and shares exactly the same
-- physical word instances. Other overlaps are legitimate.
local function ast_filter_shadowed(rules)
    local function key(rule,start,ids)
        local src=rule.source
        return rule.verb .. ":" .. tostring(src.axis) .. ":" .. tostring(src.line) .. ":"
            .. start .. ":" .. src.finish .. ":" .. table.concat(ids,",")
    end
    local hidden={}
    for _,rule in ipairs(rules) do
        local count=rule.source.prefix_finish and (rule.source.prefix_finish-rule.source.start)
            or (rule.source.leading_not and 1 or 0)
        for offset=1,count do
            local suffix={}
            for i=offset+1,#rule.source.entity_ids do suffix[#suffix+1]=rule.source.entity_ids[i] end
            hidden[key(rule,rule.source.start+offset,suffix)]=true
        end
    end
    local filtered={}
    for _,rule in ipairs(rules) do
        if not hidden[key(rule,rule.source.start,rule.source.entity_ids)] then filtered[#filtered+1]=rule end
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

        -- Original calculatesentences bounds physical sentence variants at 5000,
        -- before allocating each AST path. Keep extreme stacks out of Lua cloning.
        local variants,span=1,0
        for _,cell in ipairs(cells) do
            if #cell == 0 then variants,span=1,0
            else
                variants=math.min(5000,variants*#cell);span=span+1
                if span >= 3 and variants >= 5000 then return nil,"rule_complexity_limit" end
            end
        end
        if order[1] == "subject" and order[2] == "verb" and order[3] == "object" then
            local ok,err=ast_parse_heads(line,language,output)
            if not ok then return nil,err end
        else
        local budget=0
        for start=1,#cells do
            local chosen={}
            -- Follow only real role/token paths. Trying every possible NOT count
            -- rescans empty cells quadratically and trips the native Lua watchdog.
            local function role_at(role_index,position,sub_count,obj_count)
                budget=budget+1
                if budget > 50000 or #output > 50000 then return end
                if role_index > 3 then
                    ast_parse_candidate(chosen,sub_count,obj_count,language,line,start,output)
                    return
                end
                local role=order[role_index]
                local function term_at(cursor,count)
                    budget=budget+1
                    if budget > 50000 or #output > 50000 then return end
                    for _,word in ipairs(cells[cursor] or {}) do
                        chosen[#chosen+1]=word
                        if role ~= "verb" and ast_is_not(word,language) then term_at(cursor+1,count+1) end
                        local valid
                        if role == "verb" then valid=registry[language.verbs[word.token]] ~= nil
                        else valid=#ast_term_options(word.token,language,role == "object") > 0 end
                        if valid then
                            role_at(role_index+1,cursor+1,role == "subject" and count or sub_count,
                                role == "object" and count or obj_count)
                        end
                        chosen[#chosen]=nil
                    end
                end
                term_at(position,0)
            end
            role_at(1,start,0,0)
        end
        if budget > 50000 or #output > 50000 then return nil,"rule_complexity_limit" end
        end -- alternate role order
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
