# BACK integration progress (M9.7B)

BACK is now available in the default property vocabulary and behavior registry.
The official catalog explicitly marks its public real-unit history execution as
partial: native phase/declaration/lifetime parity remains pending. Historical
sections below saying "not registered" describe earlier milestones and are
superseded by M9.7B. This is not a complete original-engine compatibility claim.

## Installed primary references

Data/blocks.lua statusblock() sets unit.back_init to #undobuffer+1 when BACK first
applies and clears it when BACK retracts. moveblock() processes FOLLOW first,
then BACK: undooffset=#undobuffer-back_init; undotargetid=undooffset*2+1. Its update
rows use historical absolute position when position changed, and direction-only
updates otherwise. Creation rows can restore matching removal rows/conversion
identities; paradox guards and tele suppression also participate. This is not a
whole-world Undo or an original-type REVERT.

Data/undo.lua addundo() inserts each native operation at the front of the current
history frame. newundo() opens the next frame and may discard an unchanged one.
BACK therefore needs ordered operation history, not a difference between the
start and end snapshots: a same-turn movement cycle can return to the same cell
while still containing movement rows BACK must inspect.

## Session journals implemented

RW_Commit now owns optional session.turn_records aligned with session.history.
Each accepted transaction records its phases in application order, retaining each
phase's ordered changes, allocator/board/input/chance/random/bonus metadata and
terminal flags. Only the fields needed from the plan are copied; compiler frames,
services, event callbacks and nested world history are not stored in the journal.
World snapshots remain the paired source of historical entity state. The current
journal represents this engine's operations; native create/remove pairs must be
translated from our identity-preserving transforms/retypes during BACK playback.

RW_GetTurnRecord(session, age) returns an owned clone (age 1 is the latest committed
local turn). Reverse phase/operation traversal corresponds to native newest-first
addundo ordering; an unchanged installed addundo() oracle verifies the motion-row
ordering. Querying does not mutate history, world, RNG or input. Shape/alignment
checks reject inconsistent journals before Commit, Undo or tree acceptance.

Rejected plans produce no record. Metadata-only accepted waits remain turns.
Undo removes the corresponding record; both records and snapshots share the
existing 128-turn cap. Legacy snapshot-only frames are explicitly unavailable
(false slots), never reconstructed from state differences. Once no known records
remain, Undo drops the optional field. Boundary runtime reloads reset local journals
with local history; whole-tree Undo restores the previous session and journal.
No normal-startup regression tests or extra world initialization pass were added.

Tests cover net-zero staged movement/facing, conversion create/delete and allocation,
metadata-only turns, plan/query ownership, rejection purity, cap alignment, legacy
history, terminal Undo, tree/sibling isolation and boundary/whole-tree restoration.
Native success is not inferred.

## Selected-frame motion primitive

RW_PlanBackMotion accepts explicit identity/snapshot/journal selections. It reconstructs
implicit historical facing forward, then replays updates newest-first. Displacements
restore absolute historical positions; direction-only and zero-displacement updates
retain the current position. Collision, FLOAT and motion locks do not intervene.
Paradox-map presence suppresses playback. Every replayed update returns a transient
TELE-suppression mark, even when the final plan has no persistent changes.

The pure plan preserves identity/links and uses ordinary atomic Commit/Undo. Invalid
or stale records fail without writes. Selected lifecycle operations explicitly return
back_conversion_history_pending; they are never silently skipped. An unchanged
installed BACK update-branch oracle covers 72 combinations of motion records,
current positions/facing and paradox presence. No scheduler or startup work is added.

## Explicit native clock/status primitive

RW_PlanBackStatus receives the complete eligible real-identity set and an explicit
native buffer count (including the current/open frame). It starts back_init at
count+1, retains a live clock, and clears it when eligibility retracts. back_init
is validated intrinsic state with stale-checked atomic changes, journaling and
whole-tree Undo. Clock-only history does not produce motion or TELE suppression.
RW_BackFrameIndex preserves the native index and dead-unit gate. In particular,
a freshly activated clock can select a nonpositive absent frame while native
updateundo still becomes true; callers must not clamp it to the latest frame.

624 unchanged installed status/index branch combinations verify absent BACK,
failed conditions, activation/retraction, retained clocks and dead eligibility.
These primitives do not infer native counts from capped history, prune waits,
query BACK rules, or register/schedule BACK. Lifecycle clock inheritance remains
part of conversion playback work. No normal-startup pass has been added.

## Native-frame ledger and motion selection

Opt-in top-level plan.back_frame={from=count,retain=boolean} separates the native
open-frame clock from user-facing Undo commands. Each journal records its decision;
session.back_frame_count advances only for retained frames. The explicit decision
must come from scheduler updateundo semantics, not snapshot equality: an empty
retained frame occupies a slot, while a pruned accepted command remains user-undoable.
Missing/stale decisions reject atomically once this ledger is enabled. It can start
only on a fresh local history, never silently reinterpret legacy snapshots.

RW_GetBackFrame maps native index 1 to a validated current phase prefix, and older
indices to retained journal/snapshot pairs. It returns owned data and distinguishes
absent indices from evicted/unavailable history. Absolute counts survive the 128-turn
cap; eviction does not retarget a clock. Local Undo restores each preceding command's
count/decision; whole-tree Undo and boundaries restore/reset the complete session.
A capped empty session keeps its absolute clock without inventing missing frames.

RW_PlanBackHistoryMotion selects frames independently for eligible identities using
their intrinsic clocks, then invokes the motion primitive. It handles current/past
updates, absent-frame retention and paradox marks, returning transient back_retain
for the future scheduler. Unavailable or lifecycle history fails explicitly.

An unchanged installed newundo() oracle checks 1,260 queries through 180 retained/
pruned commands, including cap eviction. Tests also cover current/past atomic phase
playback, ownership, stale/late rejection, local/tree Undo, sibling isolation and
boundary reset. Native retain decisions/rule eligibility are supplied explicitly;
M9.6X's session-aware scheduler below now supplies these decisions for production
turns; direct world-only diagnostic calls still leave the ledger opt-in.

## Primary conversion restoration

RW_PlanBackPlayback reconstructs selected identities through ordered phase rows.
A single primary transform/retype restores the immediately preceding source shape
at the current position, with the source direction, link, followed identity and
BACK clock. It resets original_name to the restored concrete name (implicit field),
holder/BROKEN to their fresh defaults and drops projected traits. This follows
blocks.lua's create/remove branch and syntax.lua addunit(...,true), rather than
copying the old snapshot wholesale or applying ordinary REVERT/IS conversion.

The exclusive back_restore operation validates complete current/source/product
snapshots before atomic replacement and journals its source. It triggers no HAS.
Queued motion refers to the retired native handle; it does not displace the restored
one. Restoration itself does not suppress TELE on the new handle. Motion-only
selections retain their earlier behavior. Clock-ledger selection invokes this
combined playback path. 54 unchanged installed create/remove branch cases verify
shape, position/direction, link, origin/default resets and paradox presence, with
additional staged motion, stale/conflicting operation and clock/Undo tests.

The older selected-entity RW_PlanBackPlayback helper still reports allocated
branches/repeated rows as pending; full-frame playback below supersedes that limit. The native source can be restored more than once with the same logical ID from
multiple branches. Full-frame playback below now tracks those identities explicitly;
do not guess provenance from noun or original_name.
Native host disposal details are not covered by the isolated branch oracle itself;
M9.6U separately checked delunit() invalidating queued actions on retired handles.
No public BACK registration or production scheduling is enabled.

## Ordered conversion source journals

RW_PlanConversions now returns optional back_conversions as its sixth result.
Each event owns the pre-conversion source snapshot (or an EMPTY cell origin),
ordered product IDs and a removed Boolean. Duplicate products keep distinct IDs;
ALL/source-retaining groups do not fabricate a source removal. Same-name BECOME
and WRITE emit events even if no shape operation is necessary. Direct conversion
deletion records an empty product list. Interrupted status-limit groups discard
speculative primary mappings and record only their actual allocated prefix, with
the old source retained.

The scheduler attaches these events to the conversion phase. Phase validation
checks source snapshots/cells, unique real product identities and actual creation
operations; journal copies own their metadata. Events are not persisted on units
or worlds. Combined BACK playback now recognizes recorded same-name primary
conversions and can restore their fresh origin/status defaults. Legacy single
transform/retype rows retain the existing fallback. 48 unchanged installed
convert() cases verify source/product identity order; integration tests cover the
real compiler/turn/Commit path, ownership/Undo, stale metadata, EMPTY/ALL/deletion
and interrupted groups. This records branch provenance without yet restoring
branch copies or introducing native duplicate logical IDs by itself. The full-frame
playback added below consumes these records.

## Full-frame logical identity and branch playback

RW_BackHistoryRows validates each phase against its preceding full snapshot and
translates source journals/operations into native newest-first update/create/remove
rows. RW_PlanBackFramePlayback uses those rows, including every matching removal
partner for every matching creation. Branches restore their source at the current
position; repeated conversions can restore multiple old shapes. Ordinary births
and EMPTY creations without a removal partner disappear without HAS. Retained ALL
products use ordinary creation's -1 base; interrupted conversion prefixes retain
their actual conversion base. Source-base paradox guards differ from update guards.

Entity IDs remain unique physical instances. Optional intrinsic back_identity
holds a shared native history identity after branch restoration. Primary replacement
reuses the current instance; extra restored products allocate fresh instances with
the same history identity. Every alias participates in older matching update rows,
including frames with multiple aliased movers. Conversions preserve a primary's
history identity and give allocated products fresh identities. HAS/MORE/MAKE births
already build fresh specs. Allocated scoped products clear inherited aliases.
The allocator, aliases, restore source facts and extra create/back bases all remain
atomic and undoable. Motion/TELE marks on retired handles are not inherited.

RW_PlanBackHistoryMotion now invokes full-frame playback, including branches absent
from the paired pre-frame snapshot. New phase journals mark back_format=1; older
unannotated creation rows reject as ambiguous, rather than guess whether they were
births or conversion copies. Legacy unambiguous primary motion/shape rows remain
readable. 24 unchanged installed BACK branch/repeated/birth cases verify ordered
products/identity/source guards, plus shared-ID older motion, allocation/Undo,
clock selection and legacy rejection tests. The prior isolated 54-case primary
oracle remains useful but its selected-entity helper is no longer the scheduler path.

## FOLLOW and HOLD shared-identity memory

FOLLOW compares and stores a target's native history identity, while retaining
physical-instance self exclusion. Adjacent aliased targets can satisfy remembered
followed IDs even when their entity slot differs. HOLD records the source's history
identity and keys capability presence by that identity. Its follow step resolves
the first matching unit from the complete ordered unit list, including a non-HOLD
alias, matching blocks.lua plus tools.lua getunitid(). Locks and final FLOAT checks
apply to that actual resolved instance. Acquisition still excludes the source's
physical instance, so another instance sharing the rider's native ID can produce
a holder value equal to the rider's entity ID. Validation allows this only with a
separate matching partner and retains stale/atomic checks.

750 additional unchanged installed FOLLOW cases and 128 installed HOLD/getunitid
cases cover alias memory, first/non-HOLD matches, stale physical IDs, shared source
IDs, layers, locks and acquisition. Commit/Undo tests cover both memory fields.
The next section adds creation/reinsertion order for these consumers; unrelated
motion solvers retain their existing deterministic scheduling.

## Native unit-list ordering

Optional world.unit_order records physical instance traversal; omission means
ascending authored IDs. Structural Preview/Commit updates append new/replaced
instances and remove retired ones, using ordered conversion source/product events.
Same-name conversions can change order without shape operations, and those changes
count as real world changes. Canonical ascending orders need no extra stored list.
The list is validated as a complete unique permutation at plan/definition/tree gates.
RW_UnitIds returns owned IDs; projected worlds preserve the list.

Ordinary flat independent operations keep their simultaneous, permutation-invariant
contract with a deterministic default. A phase may supply validated unit_sequence
for native lifetime order; full-frame BACK records its actual restoration/allocation
sequence there. Journals preserve that metadata and full historical snapshots carry
unit order. FOLLOW, HOLD, conversion-source traversal and BACK selection/playback
consume the order. Existing sorted BROKEN status and other movement scheduling
contracts are intentionally unchanged; this is not a claim of universal native
mutable-list scheduling parity.

Boundary reload restores authored order, filters removed slots and appends persistent
allocations; whole-tree Undo restores pre-boundary order. 80 unchanged installed
addunit/delunit/getunitid structural turns verify replacement, no-op conversion,
births/deletions and shared lookup. Added 750 noncanonical FOLLOW cases and 128
noncanonical HOLD cases, plus order-only changes, simultaneous/explicit sequences,
malformed data, late failure and tree/boundary Undo tests. Native delunit() also
explicitly marks queued actions DELETED, confirming restored handles must not
inherit the retired unit's queued motion.

## TELE handoff

RW_ResolveTele(world, suppressed) consumes the physical-ID marks returned by
BACK playback. The optional set is validated and remains transient. Direction-only
and unchanged BACK update rows suppress transport without consuming RNG; paradox
guards do not mark the rider. Restored products do not inherit a retired handle's
mark, even when the implementation reuses its physical slot. Aliases sharing a
logical identity remain independent riders. Marked TELE sources may carry others.
TELE now follows runtime unit-list order for sources, riders and destination choices.

The installed TELE loop passes 6,144 cases across suppression/order/network variants.
Sequential BACK then TELE Commit/Undo tests cover the handoff, replacement and
failure purity. This closes the solver handoff; production BACK scheduler placement
and transient-set routing are integrated by the session scheduler below. Public
BACK registration still waits for initialization/lifecycle timing.

## Isolated mapped-script services

Mapped movement/world scripts do not share Lua globals. BACK history selection,
full-frame playback and the legacy conversion helper now accept explicit world
services: preview, frame, rows, restore and identity (the legacy helper needs only
preview/restore). Calls inside movement use that supplied table exclusively;
omission retains combined-module compatibility for offline callers. Missing or
invalid services fail with a diagnostic instead of a nil global call.

Bootstrap supplies Invoke adapters in turn_services.back_history/back_status;
its TELE adapter also forwards the transient suppression set. The session scheduler
below consumes these bindings; they do not enable the public word yet.

An isolated-host test loads world, movement and properties into separate global
tables with only standard Lua libraries. It exercises activation clocks, current
and past native-frame queries, primary/branch/repeated conversions, legacy
playback, shared identities, TELE handoff, Commit/Undo and missing/failing service
diagnostics. It explicitly verifies movement has no world globals and compares
results with the combined-module reference path. No native success is inferred.

## Session-aware production scheduling

RW_PlanTurn(world, action, services, session) uses session-owned BACK history when
the BACK services are supplied. Production RW_PlanLevelAction passes the active
session, including its initial compile-limit path. Ordinary world-only diagnostic
calls keep their existing contract. A fresh session starts an open native count of
one. Legacy local history without a ledger is explicitly unavailable; it is never
silently reinterpreted. Confirm/navigation stays separate and boundary reload resets
the ledger; whole-tree Undo restores it.

Before input movement, BROKEN refresh runs first. BACK eligibility then comes from
current rule effects, including per-identity conditions, NOT denial and the command's
IDLE/chance state. Apply clock changes atomically with input/RNG metadata. The current
BACK frame includes this prefix plus movement/conversion/FOLLOW phases, retaining
their previous-phase preconditions. Clock changes do not require recompilation.

After FOLLOW and before the existing FALL/DONE/MORE/TELE phases, surviving real
eligible identities select historical frames and replay them. An empty eligibility
set skips playback. This preserves the project's existing broader phase boundaries;
it does not claim complete native phase-graph parity. BACK's temporary retain/tag
results feed the session ledger and TELE only. Filter tags of riders deleted before
TELE (for example DONE), without inheriting tags on new products. Restored instances
also count as current-turn conversions for late MAKE occupancy.

Recompile after BACK changes. If physical/WORD reading changed, apply compiler
code_status once at that barrier before later phases, then re-evaluate. Compile
limits retain the triggering BACK board/clock phases and enter only-Undo lockout.
Ordinary failures reject clocks, input, RNG, movement and history together.

RW_BackRetainDecision validates the complete staged plan and classifies native-style
updateundo effects. Real displacement/direction changes, lifetime actions, conversion
events and explicit map updates retain frames, including net-zero movement cycles.
BACK eligibility can retain an otherwise empty frame, even for an absent negative
target index. Memory/status/input/RNG-only changes do not retain a native frame,
but remain user-undoable commands. The helper returns its validated preview as a
third result so the scheduler need not repeat a full preview. Terminal/bonus actions
also retain. Structural host actions are mapped to retaining gameplay actions;
their opaque MF_* implementation is not claimed as an unchanged-source oracle.

392 installed update/updatedir/BACK/newundo cases check changed/no-op motion and
facing, eligibility/absence/dead gates and frame pruning. Further tests cover metadata
pruning, net-zero phases and late validation. Real compiler/session tests cover
activation/retraction, current/old frame selection, expiry, NOT/ON/BROKEN/IDLE,
FOLLOW memory, TELE/RNG and retired tags, Text status barriers, terminal triggering,
legacy/error purity, replay, local/tree Undo and boundary reset. Routine real-device
acceptance remains waived; offline success is not native acceptance.

The separate-global host test now also runs the complete compiler/status/session
planner across Invoke adapters, including BACK/TELE, native counts, RNG and Undo.

## Birth/conversion clocks and saved runtime reset

Installed syntax.lua addunit() resets back_init and broken to zero before its
statusblock call. blocks.lua statusblock() refreshes BROKEN first, then queries
BACK; active newborns receive #undobuffer+1. convert.lua doconvert() calls addunit
for each product before removing its source, without restoring the source clock.
This includes primary products, same-name BECOME and WRITE retypes. BACK's own
restoration is different: addunit(...,true) skips that status branch, and moveblock
explicitly restores the historical source clock. The existing back_restore helper
continues to implement that distinction.

The session scheduler now supplies the absolute current native count explicitly to
convert, destruction/contact, MORE, MAKE, EAT and BONUS services. Those Invoke
adapters forward it through initialization helpers to rules.lua. It is transient
call context, never a new world/compiler fact or a global variable. World-only
diagnostic calls may omit it and retain their prior clock behavior.

RW_InitializeBirthSpecifications(..., back_count) clears inherited clocks, initializes
BROKEN, then queries BACK in the same raw/frozen frame. Each prior initialized birth
remains a witness for later products. HAS queries still see the dying parent, and
movement death frames retain their shifted temporary allocators. MORE copies and
late MAKE births get new clocks, without retaining the source's old activation.

RW_PlanConversions(..., back_count) uses the same ordered query sequence, with its
existing negative-ID source witness when the primary reuses a persistent ID. Full
retypes store the new clock directly; primary transforms/same-name conversions emit
stale-checked back_init operations when needed. Duplicate products initialize
separately. BROKEN or a failed/denied BACK condition leaves the reset zero clock.

Query limits retain earlier initialized clocks and a zero clock on the triggering
newborn. Interrupted conversion groups materialize their allocated prefix while
keeping the old source and its old clock; speculative primary updates are discarded.
HAS similarly preserves the triggering parent and earlier completed deaths/births.
These terminal plans remain atomically undoable; ordinary errors reject everything.

Boot/boundary initialization treats saved nonzero clocks as runtime data: the cheap
authored status guard detects them and the existing reset phase clears them before
the ordered BROKEN initialization pass. No BACK activation pass or history/RNG/input
entry is added at startup. In the installed Lua loader, clear/clearunits clears
feature/history state; addunit resets clock zero and startblock only runs
moveblock(true), without BACK playback. The backend keeps its documented fresh
one-open-frame normalization and lets the first input status pass activate clocks.
Opaque MF_* loader scheduling/initial retained host frames are not reconstructed.

648 unchanged installed reset/brokenblock/hasfeature/BACK clause cases compare real
Object/Text birth and primary-conversion clocks, old values, conditions and BROKEN
gating. Scheduled tests cover HAS (contacts/movement/EAT/BONUS), MORE/MAKE, duplicate
conversions, ON source witnesses, WRITE/BECOME, recursive-query terminal prefixes,
saved clock reset and local/tree Undo. Separate-global tests verify the session
count crosses Invoke into conversion initialization. Startup still runs no tests.

## M9.6Z: restored WEAK birth grace

Installed blocks.lua BACK restoration calls addunit(newunitid,true) around line
685. syntax.lua addunit leaves unit.new=true, while convert.lua explicitly clears
it for ordinary conversion products. blocks.lua's WEAK contact branch around
1473 requires unit.new=false. Accordingly, BACK back_restore operations and
allocated restoration create operations now enter the turn-local WEAK newborn
set. This includes primary-ID reuse, separately restored duplicate branches and
the cartesian allocated products of repeated conversions. This set is never
saved on entities; next input removes the grace and Undo restores the complete
pre-turn state. Other contact phases retain their ordinary behavior.

Scheduler tests replay real conversion journals into overlapping WEAK sources,
verify both reused and allocated identities survive restoration, then verify
destruction on the next input and Undo in both directions. Public BACK remains
pending; offline checks do not assert native acceptance.

## M9.7A: ordered SHIFT motion history

Installed moveblock() final SHIFT alignment (blocks.lua ~818–845) unconditionally
adds an update row for every surviving same-layer co-occupant of an awake source.
The old final-state summary discarded equal-direction writes. It also could not
retain the intermediate directions of multiple stacked sources.

SHIFT now emits an owned ordered motion_history alongside its unchanged atomic
changes summary. Rows carry physical entity IDs, full from/to positions/facing
and an optional retain flag (default true for actual motion).
Impulse applications and final alignment share that path; every alignment writes
a row, even when equal. Sources/riders follow the authoritative unit-list order.
Validation checks each row against its predecessor and the complete path against
the ordinary final changes, rejecting structural/status mixtures, stale rows and
out-of-bounds positions. A nontrivial net-zero motion path retains a BACK frame;
final alignment uses retain=false even when facing changes, because that direct
assignment does not set updateundo (addundo only stores the row). The final
changes summary must not independently override those explicit retention flags.
An independently retained/current BACK frame can still contain such equal rows.

The phase journal clones this metadata. BACK's newest-first row translation uses
the ordered path instead of duplicating the final move/direction summary. Replaying
an equal update marks that physical rider for TELE suppression without moving it
or drawing destination RNG. The world-only diagnostic motion path supports the
same metadata. No new entity/world facts or stage nesting are introduced.

384 unchanged installed SHIFT alignment oracle cases cover directions, multiple
sources, unit-list order, SLEEP, FLOAT and non-retaining changed/unchanged alignment.
Another 32 impulse/PUSH/WEAK scenarios
validate the full path and its inverse. Complete and isolated mapped schedulers
verify current-frame BACK/TELE routing; validation, ownership, retention, late
failure and Undo tests cover history-only and net-zero phases. Native impulse
batching and intra-impulse HAS/conditional cache differences remain documented
separately; this does not claim complete phase-graph parity or native acceptance.

## M9.7B: public vocabulary and source-confirmed special scope

Default BACK tokens now parse as property arguments, activate their complete
sentences and project the back capability. The already wired production session
planner handles clocks/history/playback; default gameplay needs no custom token
registration. FEELING BACK and WORD object sentences use the ordinary compiler.
Tests also use RW_PlanLevelAction/RW_CommitLevelTree rather than only the session
helper, checking retained clocks, reload and whole-tree Undo. The existing
session scheduler regression now asserts the public default instead of injecting
the token. Public admission does not change the world-only diagnostic API contract.

Installed blocks.lua ~580 calls findallfeature(nil,"is","back",true). features.lua
~245 explicitly excludes EMPTY when that fourth argument is true; tools.lua
findall() enumerates unitlists/codeunits. Real LEVEL blocks therefore participate,
but no virtual EMPTY observer or map-wide synthetic LEVEL playback is invented.
No BACK branch was found in levelblock(). This replaces the earlier generic
"synthetic LEVEL/EMPTY pending" note for this property with source-confirmed
non-participation. Ordinary EMPTY/scoped declaration queries may still project
BACK, but their projection does not create runtime clocks, IDs or playback.

The installed findfeature/findallfeature/findall functions run unchanged in 32
scope-oracle cases covering real LEVEL/Text, ignored EMPTY, failed conditions,
BROKEN and duplicate declarations. Tests verify linked real level-block replay
preserves the configured destination. Source inspection across base Data Lua
(excluding Worlds/mods) found paradox only initialized/cleared/read; convert.lua
~443 has its sole indexed write commented out. Production therefore keeps the
empty/default guard; existing explicit playback helpers still support nonempty
guard maps for diagnostics. No unsupported native host writer is fabricated.

## Still pending

Broader native phase-graph/conditional intra-phase differences remain. The
installed selection oracle preserves repeated declarations, while the current
scheduler coalesces eligibility per physical unit; exact duplicate processing
against retiring/replaced native handles remains a declaration/lifetime gap.
Future native host evidence of a nonempty paradox writer would require an
explicit transaction-owned integration rather than guessing new persistent facts.
Opaque host lifetime updateundo behavior and history beyond this engine's existing
128-turn window remain integration limits. Do not treat the current session
scheduler as completed public BACK.
