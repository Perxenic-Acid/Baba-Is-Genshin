# M9.3Y WEAK

## Original reference

Installed `Data/movement.lua`: blocked controller branch (~799) deletes unsafe
WEAK; `check` (~1041-1082) excludes WEAK from bare STOP solidity independently
of SAFE, while PUSH still enters the push solver. `trypush` (~1235) lets unsafe
WEAK dependencies reach `dopush`; `dopush` (~1460) deletes a blocked weak push.
Free PUSH moves normally. Do not approximate all these paths with overlap alone.

Installed `Data/blocks.lua` (~1470): after SINK and before MELT, unsafe WEAK
with `unit.new == false` dies when overlapping another same-layer unit. Self
alone does not count. Victims are selected before the batch is flushed.
`effectblock` resets new (~61); `syntax.lua` marks creations new; `convert.lua`
(~388) clears the flag for conversions.

## Implementation

Movement death records now carry unlock/weak causes. A failed unsafe WEAK
subtree restores speculative pushes/deletions before shattering the root at its
source. The movement_destruction stage shares OPEN/SHUT's HAS, allocation,
conditional death frames and atomic whole-tree Undo.

The scheduler runs SINK, WEAK, MELT, DEFEAT, unlock under frozen declarations.
HAS products from movement and SINK receive transient WEAK immunity until next
turn; conversion changes remove that immunity. The set is never stored in the
committed world and does not protect against other hazards.

## Manual test

Root: D five times, W, D four times, F enters WEAK.

* W: Avatar tries entering a STOP Rock, shatters at its source, leaves a Crate
  there facing Up. Z restores Avatar and allocator.
* From initial state, D twice: first approach the Crate; then push it against the
  right-hand STOP Rock. Crate shatters; Avatar advances into its former cell.
  Z twice restores both steps.
* Loose SAFE/NOT/AND allow changing rules; NAT includes WEAK as a loose word.

## Verification and scope

`luatex --luaonly tests/run.lua`: blocked YOU/edge/PUSH, free PUSH, SAFE,
WEAK STOP, simultaneous overlap, isolated self, conditional and negative grants,
HAS positions/directions/newborn grace, conversion vulnerability, phase order,
rollback, native F/input and whole-tree Undo.
`luatex --luaonly tests/reference_weak.lua` executes the installed original WEAK
contact block for self/SAFE/newborn/simultaneous cases using UI stubs.

FLOAT layers, virtual EMPTY/scoped LEVEL WEAK lifecycle, PULL/MOVE and original
multi-pass movement ordering are not implemented in this milestone. Normal
startup remains regression-free and under the existing 2M instruction budget.
Real-device acceptance is pending.
