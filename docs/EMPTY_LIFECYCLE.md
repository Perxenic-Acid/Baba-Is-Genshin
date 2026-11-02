# Virtual EMPTY destruction and HAS

## M9.8J self-contact phase

Primary installed references: blocks.lua levelblock(), around2081-2450; tools.lua
handleinside:477, delete:509 and inside:977. levelblock scans vacant cells after
ordinary block destruction/creation, pairs OPEN/SHUT, HOT/MELT and YOU/DEFEAT,
then invokes delete(2,x,y). There is no persistent EMPTY unit to remove. SAFE
protects the cell. SINK or WEAK alone does not self-destruct a vacancy. Matching
FLOAT gates EMPTY contact with scoped LEVEL, but not a cell's own property pair.

The new empty_contact stage runs after ordinary EAT/MAKE and before late END,
BONUS, CRASH and final reading checks. It refreshes conditions from the frozen
contact declarations, selects each unsafe vacant victim once, and handles
self OPEN/SHUT, MELT/HOT, YOU/YOU2+DEFEAT plus scoped LEVEL SHUT/OPEN/HOT/DEFEAT.
Selection order is x then y, matching the original levelblock traversal. There
are no virtual delete operations, persistent tombstones or negative committed IDs.
HAS products are real creations in this atomic whole-tree transaction.

EMPTY HAS now lowers to an explicit empty_has relation with per-source conditions,
negative bans, duplicate products and ordinary/Text/ALL/Level targets. HAS EMPTY
produces nothing. Text products are text_EMPTY, and Level shapes have no destination
metadata because an empty cell has none. Ordinary HAS handling and IS conversion
remain separate. HAS ALL retains the project's authored palette and multiplicity.
MIMIC/GROUP expand before this lowering as for other declarations.

inside() shares one orientation across a cell's ordinary/Text products. It draws
once when emptydir is unset even if there are no eligible HAS products. The planner
uses the existing pure transactional RNG stream; random-only cell destruction is
therefore still a stale-checked stage and Undo restores it. Known direction avoids
the draw. Newborns run the existing ordered BROKEN initialization and later CRASH/
WORD checks. Compile-limit creation prefixes enter the existing only-Undo state.
No production boot tests or extra mapped scripts are introduced.

Tests/empty_contacts.lua exercises both declaration orders, SAFE/FLOAT, scoped
contacts, HAS duplicates/Text/ALL/NOT/conditions, newborn BROKEN/CRASH, allocation,
random-only stages, stale metadata and whole-tree Undo. The standalone installed
source oracle tests/reference_empty_contacts.lua executes the real pairing/deletion
branches for 16,384 combinations and inside() for 320 ordinary/Text/direction cases.
These are source/dispatch oracles, not native-device acceptance.

## Remaining scope

Movement unlock/WEAK/EAT virtual victims,
per-command cross-phase virtual deletion deduplication and complete scoped LEVEL
lifecycle remain pending. This phase does not add EMPTY SINK/WEAK self-destruction
which the original levelblock does not perform. Native late-empty victory/re-entry
ordering, HAS ALL's exact createall bookkeeping/random draws/protection, and
source-specific zero-vector probes remain separate parity work.

Victims are selected once, then virtual delete/HAS calls run serially in native
x/y order. RW_PlanEmptyContactPhase supplies earlier initialized real products as
witnesses for later HAS conditions/status, advances tentative allocators and RNG
purely, and finally emits one atomic creation plan. A creation-limit prefix stops
before later victims and their orientation draws. Tests include WITHOUT-driven
birth witnesses and terminal-prefix RNG/allocation/Undo.
## M9.8K virtual BONUS pickups

The same installed levelblock branch pairs EMPTY BONUS with YOU/YOU2, or with
matching-layer scoped LEVEL YOU/YOU2. Unsafe qualifying cells enter the shared
virtual destruction set; SAFE prevents both this cell's reward and deletion.
Unlike real BONUS's property-instance multiplication, emptybonus gates exactly
one award across all qualifying cells in the entire scan. Another contact killing
the cell does not suppress the award, and multiple causes still run HAS once.

The late empty_contact stage now carries a stale-checked bonus_state increment
and one transient event with cell coordinates, without fabricated entity IDs.
Events reach campaign accounting and native diagnostics only after accepted
whole-tree Commit. The actual native event dispatch distinguishes an EMPTY cell
from real entity/collector IDs. Undo restores local and campaign reward totals,
products, allocation and RNG; reload retains the campaign total. Existing serial
HAS and creation-terminal handling retain rewards issued before delete() calls.

The installed selection oracle now covers 65,536 combinations including BONUS and
scoped YOU as well as SAFE/FLOAT, duplicate pair ordering and other contact deaths.
Turn tests cover one/many cells, duplicate grants, both YOU variants, SAFE, layers,
shared HAS, stale counters, campaign reload/Undo and actual native event formatting.
Synthetic LEVEL BONUS, virtual BOOM and movement-specific destruction are still
separate remaining paths; original late-empty WIN/END ordering remains documented.

## M9.8L virtual BOOM

Installed blocks.lua:2293-2353 explodes every qualifying vacant source using a
square radius of BOOM declaration count minus one. SAFE protects each real victim
independently and prevents the source cell's own deletion, without disabling its
blast. Ordinary victims are queued once; no new HAS product recursively explodes.
One BOOM has radius zero, so its vacant source cannot hit a real same-cell unit.

The installed floating(f,2,x,y) call is significant: tools.lua floating:1254 queries
EMPTY FLOAT at the victim coordinates, not at the remote blast source. The rules
planner uses current/frozen declaration queries at occupied victim cells as well,
including conditional FLOAT and virtual BROKEN; projected vacant-source facing or
FLOAT is not substituted for that query. Radius and multiplicity still come from
the active source cell's compiled projection.

RW_PlanEmptyLateContacts collects virtual self-contact/BOOM victims from one late
snapshot, deduplicates cells, and plans a real empty_boom destruction/HAS stage
before the empty_contact cell-HAS stage. Later virtual HAS queries see initialized
real births and the advanced allocator. Each stage keeps its own stale preconditions;
the top-level changes list is only a diagnostic summary. Frozen declarations survive
destroyed Text until final WORD/CRASH evaluation. Scoped traits refresh after either
stage changes units.

EMPTY BONUS is awarded during the original scan, before those delete() calls.
When a real blast stage exists, it carries the reward counter/event so a later
virtual query/creation limit preserves that prefix. A real birth initialization
limit likewise retains the blast/reward prefix and skips all virtual inside()
calls. Ordinary errors reject the entire transaction. Pure RNG, actual partial
allocations and whole-tree Undo remain intact.

Turn tests cover radii/counts, diagonal/Text/SAFE victims, source-vs-target FLOAT,
real-before-virtual HAS and allocators, earlier-birth conditions, no recursive
newborn explosion, BONUS, stale counters and real/virtual terminal prefixes.
Tests/reference_empty_boom.lua executes the installed BOOM body and floating()
helper for 1,280 range/SAFE/layer/multiple-source cases.

Remaining boundaries include native real-victim mutable unitmap traversal (the
project normalizes victim IDs), cross-phase virtual delete deduplication, movement
unlock/WEAK/EAT cell victims, exact HAS ALL bookkeeping and late-empty WIN/END
scheduling. Scoped LEVEL BOOM and other synthetic lifecycle paths are separate.

## M9.8M original-tile post-delete WIN/END evidence

Installed levelblock records ewintiles/eendtiles while scanning, before delete()
and serial HAS. After deletion, around2440 onward, it checks those original tiles
for current occupancy. A self-defeated winning vacancy can therefore win if it
remains empty; a HAS product occupying it blocks this route. Later births can
retract the WIN/END condition without erasing the already-recorded tile. WIN tiles
are tested before END tiles. The original END-first pairing quirk remains intact.

Virtual unsafe self-contact selection now records ordered transient outcome cells
for those queued deaths. After real and virtual HAS previews, the phase emits
empty_win_contact/end_contact evidence for surviving vacant original tiles. That
metadata belongs to the turn plan, never to persisted world facts or the renderer.
The tree outcome adapter consumes it alongside existing ordinary contact evidence;
late END queries cannot overwrite it or outrank a recorded late EMPTY WIN. Scoped
LEVEL terminal/conversion precedence remains the project's existing explicit policy.
Final compile/CRASH terminal states still suppress outcomes and permit only Undo.

SAFE EMPTY YOU+WIN+DEFEAT also retains ordinary victory, since SAFE prevents that
self DEFEAT removal. This fixes the previous unconditional DEFEAT veto in the
standalone win-contact query. No physical entity contact semantics change.

Turn/tree tests cover both WIN/DEFEAT orders, MELT/BONUS destruction, HAS occupancy,
SAFE, END pairing/priority, birth-induced condition retraction and terminal lockout.
Tests/reference_empty_outcomes.lua executes installed selection and original-tile
post-check branches for 16 dead-cell/order/HAS cases. These checks supplement the
65,536 selection and 320 inside() cases; they do not claim complete native scheduling.

Remaining immediate-return gap: native victory/ending at an alive scanned cell can
return before queued BOOM/cell deletions and HAS, even for an unsafe BOOM source
which does not clear the local alive flag. That scan-prefix interruption, and its
interaction with earlier BONUS rewards and ordinary/synthetic outcomes, still
needs separate implementation. This milestone handles the post-delete path only.

## M9.8N alive-cell scan returns

Installed levelblock around 2348-2418 tests WIN/END immediately after each cell's
unsafe self-contact/bonus handling. BOOM only queues deletion and does not clear
alive. A surviving winning/ending vacancy therefore returns before all queued
real blast victims and virtual delete/inside() calls, including earlier cells.
Earlier BONUS awards survive; later cells cannot award BONUS. The first outcome
in x-then-y order wins, with WIN before END at the same cell. An immediate END can
outrank an earlier dead cell's queued post-delete WIN.

The projection query returns the earliest alive outcome and truncates the reward
prefix. The late planner emits transient outcome/reward metadata without querying
BOOM or initializing HAS products, allocating IDs or consuming inside() RNG.
Whole-tree Undo restores the transaction. Existing project scheduling remains:
ordinary earlier phases already occurred, final CRASH/compile limits still lock
out outcomes, and explicit scoped LEVEL conversion/terminal precedence is retained.
This change interrupts queued EMPTY work, not the entire project's turn pipeline.

Turn/tree tests cover BOOM suppression, HAS/allocator/RNG stability, SAFE,
terminal-only Undo and outcomes. tests/reference_empty_immediate.lua executes the
installed selection/death/bonus/return branches for 75 three-cell permutations,
including earlier dead WIN versus immediate END, reward cutoffs and forbidden
queued-work callbacks. Post-delete outcome tests remain separate.

Remaining boundaries: cross-phase virtual delete deduplication, movement
unlock/WEAK/EAT virtual victims, exact HAS ALL bookkeeping, native mutable real
victim ordering and synthetic LEVEL lifecycle. Frontend/level design remain deferred.

## M9.8P moving into EMPTY WEAK and cell deletion transactions

Installed movement.lua check around1140 queues an unsafe same-FLOAT EMPTY WEAK
special and bypasses its STOP/PUSH/PULL/STILL collision. move around1634 deletes
the vacancy only for a real mover (unitid != 2); an EMPTY mover passes without
calling delete. PHANTOM skips this collision branch. tools.lua delete around509
keys EMPTY deletion by coordinates, once per command, and inside around977 queries
cell direction before HAS. The existing virtual LEVEL HOLD exception is unchanged.

The common solver now emits typed transient empty destruction records with
coordinates, cause and the pre-move positive-identity frame. These record keys
are diagnostics, not allocated entities. YOU, automatic, FEAR, SHIFT and FALL
retain the records in their existing sequential destruction stages. Ordinary
real delete operations receive only positive IDs. Cell HAS runs in the saved
frame, with earlier initialized births and allocator/RNG advances visible to
later records. Products retain ordinary status initialization/newborn treatment.

A command-local coordinate cache suppresses repeated cell delete/HAS in convergent
SHIFT and later self-contact/BOOM phases. It does not suppress the properties,
blast selection, rewards or outcome evidence of that still-virtual cell. No cache
is saved in world or Undo; the next command begins empty. A products-query compile
limit commits triggering movement and any returned orientation draw, then locks
the appropriate only-Undo state. Birth-initialization limits keep their existing
product-prefix adapter. Ordinary errors reject the entire transaction.

Tests cover source-frame conditions, compiled SAFE/FLOAT/PHANTOM/solidity,
BROKEN/CRASH births, automatic/FALL propagation, convergent SHIFT, late conditional
HAS suppression and next-command reset, RNG-only deaths, stale metadata, limits
and Undo. tests/reference_empty_weak.lua executes installed check and move WEAK
branches for 2,048 cases; existing inside() and collision oracles supplement it.

Remaining: movement OPEN/SHUT and EAT EMPTY, failed virtual mover WEAK semantics,
query-limit partial products within a single HAS clause-selection batch, exact
HAS ALL/createall behavior, dynamically re-queried conditional vacancies created
inside one motion solver, and native mutable dispatch order. No native acceptance
or complete EMPTY lifecycle parity is claimed.

## M9.8Q real mover unlocks EMPTY

Installed check around1131 queues lock before weak, bypassing vacancy solidity
when OPEN/SHUT partners share FLOAT and at least one is unsafe. move around1567
checks each participant's SAFE independently, deletes the target first, then the
mover at its source, and skips remaining specials when the mover is gone. Two SAFE
participants retain ordinary collisions. OPEN takes precedence when the mover
also has SHUT. Pulling probes do not queue these EMPTY unlock/WEAK specials.

Real-unit entry now uses that branch of the shared collision solver. Mixed cell
and real destruction records preserve native order through the M9.8P transaction
adapter: target HAS allocations/witnesses precede the mover's HAS, origins remain
separate, and duplicate WEAK deletion of the same vacancy is suppressed. An unsafe
mover dies without reaching the vacancy; a SAFE mover can enter after the unsafe
vacancy's deletion. PHANTOM bypasses this interaction and FLOAT still gates it.

Turn tests cover the SAFE matrix, target-before-source birth IDs and positions,
conditional HAS seeing the earlier cell product, WEAK dedup, solidity/PHANTOM/layers
and Undo. tests/reference_empty_unlock.lua executes installed check and move
lock/weak branches for 16,384 partner/safety/layer/solidity cases. Existing real
unlock semantics and atomically staged HAS are retained.

Still deferred: virtual EMPTY movers' own unlock deletion and virtual pushing
chains with unlock, EAT EMPTY entry, exact native mutable scheduling and the other
M9.8P limitations. The new branch covers real movers targeting virtual vacancies;
it does not claim complete virtual-vs-virtual lifecycle parity.

## M9.8R real EAT EMPTY entry

Installed movement.lua check around1122 queues eat before lock/weak when the
source has EAT EMPTY and the vacancy is unsafe on the same FLOAT layer. This
bypasses its collision traits. move around1620 deletes the vacancy, then may run
unlock and weak; the command-local delete cache prevents duplicate HAS. Source
SAFE/SLEEP do not protect the target. PHANTOM and pulling probes skip the special.
conditions.lua testcond's real-unit branch uses the unit's own position/direction,
not check's supplied target coordinates; features.lua hasfeature returns on the
first successful declaration.

RW_ResolveEmptyEatSources evaluates lowered positive/negative/conditional EAT
relations per real identity, short-circuiting already-enabled sources. Bootstrap
bridges this pure data through Invoke and rebuilds the transient source map before
YOU, automatic/FEAR/SHIFT and FALL against their current frames. The solver uses
it for root and passive PUSH participants. Unadorned vacancies are valid targets,
without fabricating persistent EMPTY units. Cell HAS, RNG, status/terminal handling,
ordered mixed deaths, deduplication and Undo reuse M9.8P/Q.

Compiled tests cover bare/STOP/PUSH/STILL targets, duplicate/negative predicates,
source-origin spatial conditions, SAFE/FLOAT/PHANTOM/BROKEN, EAT-unlock-WEAK order,
Object/Text PUSH and post-YOU condition refresh. tests/reference_empty_eat.lua runs
installed check and move eat/lock/weak branches for 32,768 combinations. Normal
startup remains below the unchanged 2M instruction budget; no native acceptance
is inferred.

Scope: the eater map is a motion-phase snapshot, like the existing projected
capabilities. Conditions do not re-query after each impulse within one solver;
inert-source eager query/limit ordering is normalized rather than a complete
native lazy-dispatch match. Virtual EMPTY/LEVEL EAT sources, virtual-vs-virtual
unlock, dynamic intermediate vacancy conditions, and prior lifecycle gaps remain.
