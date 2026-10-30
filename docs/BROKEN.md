# BROKEN status infrastructure (M9.5L)

Primary references: installed base Data/blocks.lua `brokenblock` (157-181),
Data/conditions.lua `testcond` (1-83), Data/rules.lua `codecheck` (858 onward)
and `findwordunits` (2426 onward), Data/undo.lua (388 onward).

BROKEN is a saved per-unit status. The original updates units sequentially,
clears only the current unit temporarily for its own BROKEN query, then saves
any change for Undo. Ordinary condition queries fail for broken units. Physical
Text still participates in codecheck; non-Text WORD units are separately filtered.
Do not implement BROKEN by simply removing physical Text from the reader.

This batch adds only the status transaction prerequisite. `RW_PlanBrokenStatus`
uses a caller-supplied rule query, copies unit records before querying and returns
stale-checked `broken` operations. Missing status means zero. Updates follow sorted
entity ID order, matching this engine's other ordered phases; native unit-list
order can differ. Queries see earlier updates and the current unit temporarily
cleared. Failed queries and rejected later stages leave the source world intact.

## Query layer (M9.5M)

Saved real-unit status now suppresses direct property queries, default and other
unconditional effects, contextual/negated conditions, and relation applicability.
The unconditional conversion fast path also checks status; HAS, MAKE and verb
source selection use the shared relation query. POWERED/SEEING/FEELING declaration
queries cannot bypass BROKEN. Broken objects remain physical spatial witnesses.
`RW_PlanRuleStatus` connects the pure planner to raw generated/default declarations,
including negative BROKEN declarations, while temporarily clearing the queried
unit exactly as the original status loop does.

Tests additionally execute installed `testcond` for unconditional Object/Text
queries with/without the original ignorebroken override, and cover physical Text
reading/default PUSH, WORD filtering, conversion/HAS, MAKE/FEAR/FOLLOW/EAT,
POWERED, physical witnesses, status acquisition/retraction and Undo.

## Before-input status barrier (M9.5N)

The native turn service now invokes the rule-status planner before resolving move
or wait input, matching Data/movement.lua:2 (`statusblock(nil,nil,true)`). Changed
status is prepended as an atomic `status_before` stage; later stages use the updated
snapshot. Final Preview validates the combined transaction against the original
world, including input/chance state. Undo restores the entire input. Failed later
planning and both terminal states cannot leak or refresh statuses. An empty status
plan adds no phase and reuses the initial compile rather than compiling twice.

WORD eligibility additionally rejects a current positive BROKEN declaration before
persisted status is refreshed, matching `findwordunits`' separate BROKEN query.
Physical Text remains readable. The raw query handles NOT via normal projection.

## Post-code status barriers (M9.5O)

Installed Data/rules.lua:20-60 collects Text and readable WORD candidates; the
outer code() call runs brokenblock on that list (163-164), rather than every real
unit. Data/movement.lua:926-929 compiles before conversion and again afterward.
Data/tools.lua:update/updatedir invalidate code when Text moves/turns; update.lua
also tracks WORD and wordrelatedunits updates.

The compiler optionally returns `code_status` as a separate pure plan after its
WORD fixed point. It never applies it or changes saved fields during display.
Only selected Text/WORD records update; ordinary units retain their old status
until before-input statusblock. Current positive WORD grants include candidates
whose token BROKEN has already excluded. Selected updates preserve the original
ordered-loop behavior and are checked against installed brokenblock with both
complete and subset unit lists (512 cases).

The turn scheduler commits code-status stages after changed reading positions,
before conversion, and after conversion creates/retypes reading units. Conditions
and conversion selection read the updated snapshot. Text can disable its own
conversion, and passive SHIFT can break TEXT IS BROKEN and restore default PUSH.
Conversion-created Text gets its status before contacts. Terminal CRASH observes
updated status. All phases remain one Undo; later rejection discards everything.

Known timing boundary: WORD invalidation is conservative whenever any generated
WORD declaration and a change coexist. The original wordrelatedunits dependency
list is not reproduced yet. Candidate history still follows our agreed grounded
WORD expansion, rather than inheriting the prior native rule tree. Late contact
birth/destruction refresh and exact initialization/newborn timing remain pending.

BROKEN is still pending in the public word audit and default vocabulary. Remaining:
initialization and boundaries, ordinary/newborn status, late contact changes,
conditional timing, outcome/navigation integration, and the LEVEL and EMPTY
synthetic query paths. These must be implemented/tested before claiming
complete gameplay support. In particular, do not insert a BROKEN fixed-point loop:
original saved status is refreshed at explicit lifecycle points, not recursively
until a Boolean state stabilizes.

Validation: tests/broken_status.lua executes the installed original brokenblock
in an isolated adapter and compares 512 ordered status cases, including mixed
Object/Text and dependencies on earlier/later units. Production transaction tests
cover nil-to-one, Preview purity, stale/invalid status, atomic late failure and Undo.
Native gameplay acceptance is not inferred from these tests.
