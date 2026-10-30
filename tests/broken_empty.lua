local cs={read=RW_ReadLines,parse=RW_ParseRuleAST,lower=RW_LowerRuleAST,
    evaluate=RW_EvaluateRules,project=RW_ProjectWorld,words=RW_WordTokenMap,code_status=RW_PlanCodeStatus}
local function fixture(rows)
    local w=RW_CreateSession().world;w.height=24;w.language.properties.BROKEN="broken";w.language.nouns.ROCK="rock"
    w.entities={[1]={id=1,kind="object",class="object",archetype="rock",x=8,y=2,direction="Left"}};w.next_entity_id=10
    for row,words in ipairs(rows) do for x,word in ipairs(words) do
        local id=w.next_entity_id;w.next_entity_id=id+1
        w.entities[id]={id=id,kind="object",class="text",text={name=word},x=x,y=4+row*2,direction="None"}
    end end
    return w
end
local function frame(w) local f=assert(RW_CompileWorld(w,cs));return f,assert(RW_ProjectWorld(w,f.effects)) end
local w=fixture({{"EMPTY","IS","BROKEN"},{"EMPTY","IS","STOP"},{"EMPTY","IS","ROCK"}})
local f,p=frame(w)
assert(not p.empty_cells["1:1"] or not p.empty_cells["1:1"].behaviors.block_entry)
local changes=assert(RW_PlanConversions(w,f.relations,f.rules));assert(#changes==0,"broken EMPTY converted")
assert(not w.entities[1].broken and w.next_entity_id==19)
-- Per-cell status queries use the current/frozen frame, and never allocate Empty.
w=fixture({{"EMPTY","NEAR","ROCK","IS","BROKEN"},{"EMPTY","IS","STOP"},{"EMPTY","IS","ROCK"}})
f,p=frame(w)
assert(not p.empty_cells["8:3"] or not p.empty_cells["8:3"].behaviors.block_entry)
assert(p.empty_cells["1:1"].behaviors.block_entry)
local relation
for _,r in ipairs(f.relations) do if r.op=="transform" then relation=r;break end end
assert(relation)
assert(not RW_RelationApplies(w,relation,{class="empty",x=8,y=3}))
assert(RW_RelationApplies(w,relation,{class="empty",x=1,y=1}))
-- Negated clauses cannot invert disabled status into a true condition.
local context={};for k,v in pairs(w) do context[k]=v end;context._condition_rules=f.rules
assert(not RW_TestEntityCondition(context,{op="not",condition={op="always"}},{class="empty",x=8,y=3}))
assert(not RW_TestEntityCondition(context,{op="not",condition={op="not",condition={op="always"}}},{class="empty",x=8,y=3}))
-- A negative BROKEN declaration overrides its positive counterpart.
w=fixture({{"EMPTY","IS","BROKEN"},{"EMPTY","IS","NOT","BROKEN"},{"EMPTY","IS","STOP"}})
f,p=frame(w);assert(p.empty_cells["1:1"].behaviors.block_entry)
-- Execute the installed virtual testcond/isitbroken bridge with a controlled
-- hasfeature predicate: verify ignorebroken is forwarded and recursion is bypassed.
local file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/conditions.lua]],"rb"));local src=file:read("*a");file:close()
file=assert(io.open([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/tools.lua]],"rb"));local tools=file:read("*a");file:close()
local helper=assert(tools:match("(function isitbroken%b()%s*.-)\nfunction getinputcount"))
for broken=0,1 do for ignore=0,1 do
    local calls=0
    local env=setmetatable({features={true},featureindex={broken={true}},
        hasfeature=function(name,verb,prop,id,x,y,checked,bypass)
            assert(name=="empty" and verb=="is" and prop=="broken" and id==2 and x==4 and y==5 and bypass==true and type(checked)=="table")
            calls=calls+1;return broken==1 and {} or nil
        end},{__index=_G})
    assert(load(src,"@installed_conditions","t",env))();assert(load(helper,"@installed_isitbroken","t",env))()
    assert(env.testcond({},2,4,5,nil,nil,nil,ignore==1)==(broken==0 or ignore==1))
    assert(calls==(ignore==1 and 0 or 1))
end end
print("PASS: virtual EMPTY dynamic BROKEN, per-cell frozen conditions, IS NOT precedence, conversion suppression, negation and installed ignorebroken bridge")
