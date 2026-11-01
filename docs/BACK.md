# BACK infrastructure progress (M9.6N)

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

## Still pending

BACK remains pending in the official catalog and is not registered as a public
word yet. Activation/retraction clocks, the native current/open-frame index mapping,
automatic per-unit history selection and conversion playback, born/dead handling,
TELE-suppression integration, status/reading barriers and synthetic LEVEL/EMPTY semantics
still need implementation and source-oracle verification. Native unchanged-turn
pruning and history beyond this engine's existing 128-turn window remain explicit
integration limits. Do not treat the journal infrastructure as completed BACK.
