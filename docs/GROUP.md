# GROUP membership, transfer, parameters and recursive conditions (M9.4V–M9.4Z)

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
- Negative-source cross-group IS recursion.
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
requires its own bounded membership solver). Nonrecursive group condition parameters are added in M9.4Y below; recursive
membership conditions remain pending. This does not claim GROUP completion.

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

## M9.4Y: nonrecursive condition parameters

Primary source: tools.lua findgroup()/hasconds() 2300-2446; conditions.lua
 testcond() group parameter insertion/removal 135-208. A condition GROUP expands
all active member noun declarations, not a per-witness membership predicate.
Unconditional members contribute a name even if absent. Conditional declarations
contribute once if any real unit of that name satisfies the member condition.
Thus a distant qualifying Rock enables a nearby nonqualifying Rock to satisfy
ON GROUP. Duplicate declarations contribute duplicate required parameters.
Conditional EMPTY has no real unitlist and contributes nothing in this source path.
Text can contribute through its real unitlist. Membership checks ignore FLOAT.

NOT GROUP parameters expand the currently missing ordinary noun names, uniquely,
rather than applying NOT to each positive member. The original short noun exclusion
also allows authored LEVEL; RuleWorld includes it when LEVEL is in the authored
language. Empty groups inject the original missing-name sentinel _NONE_, preserving
ON/NEAR failure and WITHOUT shortage semantics rather than treating an empty list
as trivially true. Existing condition solvers own distinct witnesses and NOT.

Parameter processing reproduces the installed order: reverse concrete parameters,
keep complement parameters, scan the mutable list, insert positive group names at
the front and negative-group names at the end, then remove recorded placeholders.
The original scans ordinary entries too and can append _NONE_ / stop early, leaving
unexpanded names in mixed or repeated group forms. This behavior is deliberately
preserved, not silently changed to set union. The source matrix includes these
mixed/repeated forms and positive/negative WITHOUT.

Lowering carries a transient effect-free group_members declaration in the compiled
frame. contains_rule_query detects typed group parameters; rule projection and
relation queries receive that frame. A query refreshes qualifying units against
current phase positions/deletions while preserving frozen declarations for contact
and HAS. No membership/parameter cache or new world fields are persisted. Guards
bound indirect rule-query dependencies; depth exhaustion uses word_rule_limit.
Direct GROUP-in-condition membership declarations and conditional cross-group
transfers remain deferred until the explicit recursive member solver is implemented.
Negative-source IS recursion and earlier malformed nested inversion parity gaps
remain unfinished. Group endpoints in MIMIC and ALL/NOT/LEVEL membership syntax
also retain the prior documented limits.

Production tests cover all-member and duplicate witnesses, global conditional-name
promotion, empty groups, physical Text, virtual Empty, activation, conversion,
HAS, WORD and whole-tree Undo. The 9,720-case oracle executes installed grouprules,
findgroup/hasconds and testcond parameter preprocessing; primitive ON/NEAR/WITHOUT
checks are delegated to the already tested production solver, not claimed as an
independent original primitive-condition oracle. It varies channels, duplicates,
conditional/negative memberships, nearby/remote units, mixed/repeated parameters,
positive/negative conditions. Prior group source matrices remain passing.
Native success is not inferred; the unchanged production startup budget is 2M.
Next: recursive membership conditions and negative-source group IS recursion.

## M9.4Z: recursive membership conditions

Primary reference: installed tools.lua findgroup() 2300-2428, especially its
handlerecursion / currmembers / reclimit loop; conditions.lua testcond subgroup_
replacement 147-188. GROUP parameters in direct membership conditions and in
positive-source cross-group transfer conditions are now supported. Negative-source
cross-group IS declarations still require their separate grouprules evilrecursion
solver and remain deferred.

The compiled member frame marks conditions that contain typed group parameters,
including inherited transfer/exclusion conditions. The query first gathers live
unit lists and evaluates nonrecursive members as a base. Recursive conditions are
then tested against the previous round's noun list. Original subgroup_ substitutes
that same previous list for every referenced group name, including other channels;
NOT GROUP uses its authored complement. Preserve ordered names and duplicates,
and the original concatenated-name signature rather than deduplicated identities.
Ten consecutive changed rounds propagate word_rule_limit / Infinite Loop.
On convergence, the original appends the stable list to the base list, so seeded
names can occur twice in the result. This multiplicity is intentionally retained.

All solver state (previous lists, guards and compiled member declarations) is
transient and private. No _group_override or membership cache becomes a world fact.
Unit lists are reconstructed from current real identities; native empty unit-list
tombstones, if present, are not modeled as persistent state. Existing malformed
nested inversion and indirect rule-query parity limits remain documented above.

Loop detection is transactional even in frozen-rule refreshes before SHIFT or
between destruction phases. Earlier movement/death/HAS stages commit, then the
terminal board permits only Undo. A valid command that activates a loop during
initial rule projection commits its input/seed with an empty geometry stage;
whole-tree navigation preserves that terminal transaction. Invalid direction
vectors do not activate a new command snapshot. Normal OnStart still runs no
self-tests and retains the unchanged 2M instruction cap.

Production tests cover unseeded positive convergence, seeded members, a movement
creating an oscillating overlap, IDLE-activated oscillation, whole-tree command
handling, direct Commit/wait lockout, and DEFEAT/HAS births that remove grounding
before frozen contact refresh. Undo restores triggering geometry, units and input.
The 2,592-case oracle executes installed grouprules/findgroup/testcond preprocessing
with the existing normalized primitive condition callbacks: 324 cases reach the
original ten-change limit, the remainder match stable query results. It varies
channels, seed/recursive duplicate declarations, member names, ON/NEAR/WITHOUT,
NOT, positions and cross-name previous-list substitution. These are offline checks,
not a claim of native acceptance. Next: negative-source cross-group IS recursion,
then remaining ALL/NOT/LEVEL membership and GROUP-endpoint MIMIC scope.

## M9.5A: negative-source cross-group IS

Primary reference: installed Data/rules.lua grouprules(), the evilrecursion branch
around lines 1770-1920, following positive consumed-edge transfers. NOT GROUP IS
GROUP2 and NOT GROUP IS NOT GROUP2 now use that separate ten-round solver.

Its base contains direct positive declaration names before evaluating conditions
or exclusions. Positive transfer products do not enter the base. Each round derives
ordinary vocabulary names absent from the previous source group; negative targets
also count as presence during iteration. Derived destination maps replace their
whole base entry rather than union with it. Signatures retain empty destination
groups and the original repeated base prefix. On convergence, each duplicate edge
produces its own declaration with its own conditions. Positive transfers are not
rerun afterward. Ten changed rounds yield Infinite Loop; excessive derived output
yields Too Complex. Both retain the triggering transaction and permit only Undo.

Group/noun traversal uses sorted keys for deterministic allocation, deliberately
replacing native pairs order. The source oracle compares products/counts and loop
outcomes, not native allocation order. The 6,144-case installed-source matrix covers
three channels, graph edges, positive/negative targets, direct seeds, inactive
conditional declarations, duplicate edges and positive transfer ordering; 3,024
cases reach the original loop limit. Production tests additionally cover a pushed
word completing an oscillation, terminal lockout, Undo and expansion limits.

This supersedes the earlier negative-source IS deferrals above. Remaining gaps:
ALL/ordinary NOT noun/scoped LEVEL membership declarations, GROUP endpoints in
MIMIC, malformed nested inversion, native empty unit-list tombstones and indirect
query/cache parity described above. Offline checks do not imply native acceptance.
