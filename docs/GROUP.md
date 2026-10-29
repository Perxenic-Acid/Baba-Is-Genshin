# Direct GROUP membership (M9.4V, first stage)

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
- Group-to-group transfer/recursion, same-group identity/contradiction rules.
- NOT GROUP consumers/targets and GROUP inside condition parameters.
- ALL/NOT noun/scoped LEVEL membership declarations.
- MIMIC with a GROUP endpoint (ordinary MIMIC copying an IS GROUP declaration
  before the group pass works through the existing one-generation expansion).
These require a subsequent group closure/complement pass; catalog implementation
status means the current documented direct execution path, not completion.
Derived expansion is bounded at 5,000 declarations using TOO COMPLEX.

Tests: tests/groups.lua uses production compiler/planner, conditions, exclusions,
multiplicity, three channels, HAS/TEXT/WORD/EMPTY, deferred gaps and Undo.
tests/reference_groups.lua executes installed grouprules() and invertconds(),
normalizing host copy/output helpers, across 648 channel/count/condition/exclusion/
source-and-RHS-HAS cases. No native success is inferred from these tests.
COND includes all three group blocks on the existing sparse grid. Startup remains
under the fixed 2M instruction cap. Next: group closure, complements and condition
parameters, then ordinary properties. Letters remain deferred.
