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

## Creation-time status (M9.5P)

Installed Data/syntax.lua:82-86 resets a newborn's broken field and immediately
calls statusblock({id}); Data/tools.lua:548 runs inside() before deleting its
source. Creation conditions can therefore still see the dying parent.

`RW_InitializeBirthSpecifications` is a pure ordered initializer. Each newborn is
visible during its own query with broken=0, then keeps the selected saved status;
subsequent products see it. Inherited broken flags reset rather than copying old
status. Nil represents the ordinary zero state. Direction, Text and level links
are preserved. Empty product lists skip all status work.

Native HAS (including EAT and movement OPEN/SHUT/WEAK deaths), MORE and MAKE
adapters initialize products against the phase's actual raw declarations. Contact
births keep the frozen frame after physical Text deletion. Movement deaths use
per-victim death snapshots, and each batch advances its temporary allocator past
earlier products. Newborn status is included in create.to, avoiding another phase
or extra allocator/RNG draw. Whole-turn rejection/Undo includes all births.

Production tests cover the pre-delete ON witness, next-input release into CRASH,
MORE children with distinct cell conditions, duplicate MAKE sequential witnesses,
frozen declarations after SINK deletes BROKEN Text, EAT, paired unlock deaths with
separate birth frames/IDs, metadata purity and Undo. All test sentences are checked
in bounds on a 24-row fixture.

Recursive BROKEN-condition failure during newborn initialization currently rejects the plan;
preserving that triggering partial newborn board as a terminal state also remains
an explicit gap. Neither is being counted as finished gameplay support.

## Conversion products (M9.5Q)

Installed Data/convert.lua:329-381 constructs each product and calls addunit before
adding it to the map. The old source is removed only after the full group (476).
`RW_PlanConversions(world, relations, generated_rules)` now accepts the actual raw
frame from the native scheduler and initializes each product in that order.

The primary product preserves its existing persistent ID. A query-only negative-ID
copy retains the original source as a distinct old-name witness until all products
from that source finish. It never enters the plan, allocator, world or Undo. Extra
products see earlier products and the source; subsequent sources see the completed
earlier group. Stored transform plus binary-status changes share one phase, retype
and create carry status in their full specifications. Same-name BECOME/WRITE also
initialize their primary product even when no archetype change is necessary.
Conversion still does not trigger HAS. Direction, links, duplicate products,
converted-ID MAKE occupancy and allocator behavior are preserved.

The installed full doconvert and brokenblock functions are executed in an isolated
host adapter for 640 cases. The adapter supplies the selected BROKEN/ON predicate
and host map operations; both original creation/deletion loops execute unchanged.
Cases cover old-source and earlier-product witnesses, two simultaneous quotas,
negative grants, physical Text, same-name BECOME and duplicate outputs. Production
turn tests cover late MAKE/CRASH suppression and next-input release, WRITE, links,
identity, allocation and whole-turn Undo. The earlier code-status test now verifies
that converted Text acquires BROKEN directly in conversion.to rather than waiting
for the post-code barrier.

Advanced condition queries using persistent IDs/chance keys on synthetic old-source
witnesses are not covered by this oracle. Synthetic scoped LEVEL status queries and recursive creation-terminal
preservation remain separate gaps.

BROKEN is still pending in the public word audit and default vocabulary. Remaining:
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

## Runtime initialization and boundaries (M9.5R)

Boot and reloaded boundary instances receive one ordered status pass over the
fully authored runtime. Saved BROKEN flags reset before that pass; this is not a
recursive BROKEN fixed point. The installed blocks.lua brokenblock loop supplies
the ordered own-status bypass; the original host load schedule is not reproduced
by the isolated Lua reference. This initialization schedule is an explicit adapter
choice. Definitions and untouched sibling instances remain unchanged.

Initialization consumes no input, RNG draw, allocator ID or local Undo step.
Entry initializes the reloaded parent and child. Return initializes both runtimes,
then refreshes the parent after placing SELECT at its entrance, so the next F
queries its final position. Whole-tree Undo restores the pre-boundary snapshot.
Compile-limit states retain the triggering boundary and permit only Undo, including
when a scoped conversion makes the parent terminal. Terminal boards are not
compiled again. Non-limit initialization errors reject the boundary atomically.

An authored vocabulary/status guard avoids an extra compile on ordinary startup.
Tests cover first-confirm gating, conditional selector placement, aliases and WORD,
reset of authored saved flags, sibling isolation, failure purity, terminal returns,
allocator/RNG/input preservation and tree Undo. Public BROKEN registration remains
pending the synthetic-scope and later lifecycle gaps above.

## Final contact code barrier (M9.5S)

Installed tools.lua deletion invalidates updatecode for Text/WORD-related units;
rules.lua:20-60 selects physical Text and eligible WORD identities, and :163-164
refreshes only that set through brokenblock. A saved-broken WORD object fails
its condition and remains outside this set until the next before-input refresh.

The existing final-board compile after contacts now applies its pure code-status
plan when contact/MAKE operations changed readable data, then reevaluates the
resulting board. This is one explicit barrier, not repeated status stabilization.
The final compilation boundary is our scheduler adapter; host callbacks scheduling
code() outside movement.lua are not exposed in the installed Lua source.
Frozen contact declarations and CRASH-before-final-code timing remain intact.
No SINK/MELT/etc phase reruns when Text regains properties at this barrier.

Tests delete the BROKEN token through SINK, verify restored Text PUSH, ordinary
and disabled-WORD latching, MELT delayed until next turn, exact phase concatenation,
late failure rollback, compile-limit trigger preservation and Undo. Synthetic scope,
recursive creation-terminal preservation and exact WORD invalidation remain pending.
