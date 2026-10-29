# GROUP membership, transfer and complements (M9.4V–M9.4X)

Installed primary references: base Data/rules.lua code() invokes subrules then
 grouprules at 138-139; grouprules 1573-2331 categorizes memberships, combines
membership conditions/exclusions, emits subject rules around 1940-2015 and
non-IS RHS group rules around 2172-2245. Its separate group-to-group recursion
and negative group handling are not interchangeable with ordinary memberships.

GROUP, GROUP2 and GROUP3 are compiler-shared noun terms tagged group, not ordinary
archetypes. They do not enter the authored ALL palette. Ordinary concrete nouns,
TEXT and EMPTY may declare IS GROUP membership; IS NOT GROUP excludes matching
membership on the same source noun. There is no conversion or persisted group
flag. Duplicate membership declarations intentionally duplicate derived rules.

After the existing one-generation MIMIC pass, direct memberships expand consumers.
GROUP as subject expands to each member; non-IS predicates with a group target
expand their target products. Membership and consumer conditions are conjoined
and re-evaluated per current source identity (including RHS product membership
conditions, as in the original). Negative membership conditions use the existing
named-condition inversion machinery. Conditions remain in the frozen contact
frame so deletion/HAS need not recompile destroyed text.

The production path covers three independent groups, ordinary properties,
conversions, HAS, TEXT promotion and WORD fixed points. Existing verb semantics
still decide their supported sources/targets; group expansion does not invent
EMPTY lifecycle or scoped LEVEL rules. Activation belongs to the original parsed
physical rules, including membership declarations with no consumer. No renderer,
world-state or Undo-owned membership cache is introduced.

Deliberate first-stage gaps are explicitly deferred, not converted into objects:
- Negative-source cross-group IS recursion and GROUP inside condition parameters.
- ALL/NOT noun/scoped LEVEL membership declarations.
- MIMIC with a GROUP endpoint (ordinary MIMIC copying an IS GROUP declaration
  before the group pass works through the existing one-generation expansion).
These require a subsequent complement/condition pass; catalog implementation
status means the current documented direct execution path, not completion.
Derived expansion is bounded at 5,000 declarations using TOO COMPLEX.

Tests: tests/groups.lua uses production compiler/planner, conditions, exclusions,
multiplicity, three channels, HAS/TEXT/WORD/EMPTY, deferred gaps and Undo.
tests/reference_groups.lua executes installed grouprules() and invertconds(),
normalizing host copy/output helpers, across 648 channel/count/condition/exclusion/
source-and-RHS-HAS cases. No native success is inferred from these tests.
COND includes all three group blocks on the existing sparse grid. Startup remains
under the fixed 2M instruction cap. Next: group complements, condition parameters
and same-group special cases, then ordinary properties. Letters remain deferred.

## M9.4W: cross-group transfers

Positive-source `GROUP IS GROUP2` and `GROUP IS NOT GROUP2` now expand raw
membership declarations in original rule order. References: grouprules()
1719-1796, diffname_used / diffname_done loop. An edge is consumed only when it
first finds members; it processes all currently available positive declarations,
including duplicates, then never runs again. Cycles terminate through consumed
edges rather than arbitrary identity deduplication or endless fixpoint expansion.
Edges without members remain pending until another edge introduces them.

The original loop accumulates the edge condition and each preceding matching
member condition into later derived memberships. This ordering quirk is preserved.
Positive declarations feed transfers before membership exclusions are applied:
excluding a member from the source group does not retrospectively remove its
transferred membership in another group. Negative-target transfers add destination
exclusions. Conditions/exclusions remain per source identity in frozen frames.
Teams now retain original positive declaration order rather than noun sorting.
No group membership state is stored in the world or in UI.

Both positive and negative derived memberships count toward the 5,000 expansion
bound. Existing TOO COMPLEX handling owns the resulting terminal state.
Production tests cover chains, reverse edge order, cycles, conditional transfer,
source/destination exclusions, duplicate edges, bounds and whole-tree Undo.
The installed-source graph oracle tests all 64 directed three-group graphs in two
edge orders, with duplicate/conditional/overlap/negative-transfer variants:
4,096 cases. The previous 648 direct-membership cases remain passing.
Next: group parameters and negative-source cross-group IS recursion.

## M9.4X: complements and same-group special cases

Primary references: grouprules 2018-2170 (cartesian group endpoints and strict
ordinary NOT GROUP consumers), 2208-2245 (ordinary negative group targets),
2248-2331 (same-group CRASH). tools.lua findnoun 2288 and syntax.lua nlist.full
879 confirm the ordinary complement palette excludes GROUP/ALL/TEXT/EMPTY/LEVEL.

Simple NOT GROUP consumers require all membership declarations of that ordinary
noun to be false, tested per source identity. Unconditionally excluded members
are removed before complement construction. Complement expansion uses authored
ordinary vocabulary, never the current surviving entity list or special nouns.
Ordinary RHS NOT GROUP on non-IS predicates expands negative member products;
existing verb-specific bans determine the resulting behavior.

Group-to-group non-membership consumers use the original cartesian expansion.
A negative source in this form uses separate inverted conditional member branches,
plus ordinary names not declared as members. Target membership conditions still
apply to the source unit, as in the original. Negative RHS group declarations
on positive group consumers supply conditional bans rather than products.

GROUP IS GROUP emits the member cartesian rules, including each identity rule:
existing IS identity protection therefore blocks conflicting conversions.
GROUP IS NOT GROUP gives CRASH to members. NOT GROUP IS GROUP gives CRASH to
nonmember branches. NOT GROUP IS NOT GROUP emits no rules in this source path.
CRASH uses the existing surviving-unit Infinite Loop phase and only-Undo lock.
Negative-source IS between different group names remains deferred (evilrecursion
requires its own bounded membership solver). Group condition parameters also remain
pending; this round does not claim GROUP completion.

Known deliberate parity gap: original invertconds can double-invert already
parenthesized membership exclusions into names such as '(lonely))'. Installed
testcond then strips one closing parenthesis, fails to find 'lonely)', alerts and
uses its invalid-condition fallback. RuleWorld retains structured Boolean
inversion for these nested wrappers instead of recreating malformed-name fallback.
Exact flattened named-condition inversion of nested wrappers (including WITHOUT's
non-Boolean NOT behavior) is not claimed. This is separate from supported simple
named-condition inversion and is explicitly retained as unfinished parity work.

Validation: production regressions cover conditional complements, excluded members,
negative HAS, cartesian identity protection, CRASH lock and whole-tree Undo.
The oracle executes installed grouprules, invertconds and testcond; only primitive
LONELY/host data are normalized. Across 3,888 matrix cases (11,664 identity frames),
11,340 valid original frames match; 324 original malformed-name frames are counted
and excluded from parity assertions, never reported as matching. Prior 648 direct
and 4,096 ordered-transfer matrices remain passing. Normal startup is 1,989,000
instructions under the unchanged 2M cap. Offline results do not establish native
runtime parity.
