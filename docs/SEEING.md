# SEEING and HIDE (M9.4P)

Primary references: installed Data/conditions.lua seeing() at 1063-1214;
Data/tools.lua simplecheck() at 2496; HIDE filtering in both functions. Only the
installed base Data files are used, not mod copies.

SEEING scans ahead along the subject's cardinal facing, excludes its own cell,
and collects every visible identity up to AND including the first blocking cell.
STOP/PUSH/PULL block sight across FLOAT layers. HIDE removes a unit from visible
targets and from occlusion. PHANTOM remains visible but does not occlude; a phantom
observer still cannot see through ordinary blockers. WEAK STOP remains opaque.
The board's 1-based playable rectangle is the normalized inbounds region.

Parameters preserve original concrete-before-complement order, physical duplicate
multiplicity and distinct real witnesses. Text cannot witness a negative ordinary
noun. An enclosing LEVEL parameter is available once with a cardinal facing.
Mid/None yields false, or true under NOT SEEING. Original EMPTY quirks are retained:
a cell containing only hidden objects creates an Empty placeholder; positive and
negative EMPTY both seek a placeholder; repeated EMPTY parameters may reuse one.
EMPTY solidity is ignored by simplecheck(...,true), as in the source.

Rule-derived trait queries

Visibility and occlusion query the current authored plus generated declaration
frame, including conditions and negative trait grants. They never inherit stale
entity.behaviors. RW_EvaluateRules builds a temporary context only for SEEING
conditions. Conditional conversion/HAS/verb declarations carry transient
condition_rules pointing to generated rules. RW_RelationApplies builds the same
context against the current phase world. Frozen contacts keep their declarations
while spatial conditions and targets refresh after changes.

The context and recursion guards are not persisted in world/entities/Undo. Repeated
entity/trait queries on the active recursion path return false; depth 80 propagates
the existing word_rule_limit signal into Infinite Loop handling for a triggering
in-level turn. This bounds recursion, without claiming exhaustive parity with the
original checkedconds cache for pathological mutually recursive visibility rules.
Normal OnStart still runs no diagnostics and retains its fixed instruction budget.

HIDE is a rule-derived capability. The renderer omits hidden physical controls and
line annotations, restores cached controls when HIDE ceases, and suppresses hidden
virtual Empty labels. It does not delete units, remove collisions, stop text reading,
block SELECT or change contact rules. PLAY requests remain presentation-independent.

Scope gaps: virtual Empty has no rule-derived facing, so EMPTY SEEING remains None;
scoped LEVEL subjects/campaign surrounds, GROUP, and full original postrules/cache
semantics remain deferred. ALL uses the existing authored palette. Actual HIDE
animation/transitions belong to the later frontend design.

Validation: tests/seeing.lua uses the real compiler and atomic turn planner for
inclusive blockers, conditional/nested queries, HIDE/PHANTOM/negative grants,
TEXT/EMPTY/AND/NOT/FLOAT, conversions/HAS/WORD, recursion bounds and Undo.
tests/navigation_view.lua verifies hide/unhide through native setter mocks.
tests/reference_seeing.lua executes installed seeing() AND simplecheck() across
29,952 normalized direction/trait/name/parameter cases, including all 32 blocker
trait combinations. It does not execute the entire original parser/hasfeature cache.
Full regression passes; startup remains below 2M offline instructions. Native
acceptance is waived, and offline checks do not establish native runtime parity.

Loose SEEING and HIDE replace redundant AND/IS in MOTION, preserving its dimensions
and three-cell spacing. Next: remaining conditions (FEELING and POWERED families),
then prefixes, GROUP and the remaining properties in the agreed user order.
