# BACK infrastructure progress (M9.6R)

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
production turns do not enable this ledger or schedule BACK yet.

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

Allocated conversion branches, ordinary births/removals and repeated conversion
rows still return back_conversion_history_pending. In particular, the native source
can be restored more than once with the same logical ID from multiple branches;
this engine's unique identity map needs explicit source/handle tracking before
that case can be reproduced. Do not guess provenance from noun or original_name.
Native host disposal details and mixed queued-update disposal are not covered by
the isolated branch oracle; current behavior preserves distinct old/new handles.
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
branch copies or introducing native duplicate logical IDs.

## Still pending

BACK remains pending in the official catalog and is not registered as a public
word yet. Automatic activation/status timing, scheduler retain decisions and
branched/repeated conversion playback, born/dead handling,
TELE-suppression integration, status/reading barriers and synthetic LEVEL/EMPTY semantics
still need implementation and source-oracle verification. Exact production
updateundo/pruning decisions and history beyond this engine's existing 128-turn
window remain explicit integration limits. Do not treat the journal infrastructure as completed BACK.
