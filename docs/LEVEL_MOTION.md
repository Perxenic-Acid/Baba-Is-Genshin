# Scoped LEVEL autonomous motion

Primary reference: installed `Data/blocks.lua` levelblock(), around2075 (capture
lstill/lsleep),3195–3346 (MOVE/CHILL/nudges/FALL); `Data/tools.lua` cantmove()
around2248 and reversecheck() around2469. `clears.lua`123 and `load.lua`79 set
the initial mapdir to Down. This is synthetic map scrolling, not unit displacement.

## Implemented

`RW_ResolveLevelMotion(world, traits, stop_index)` plans ordered MOVE, CHILL,
NUDGERIGHT/UP/LEFT/DOWN and FALL/FALLRIGHT/FALLUP/FALLLEFT from the surviving scoped
declarations. Duplicate declarations execute repeatedly. No unit coordinates,
identities, collisions, contacts or HAS products are changed by map scrolling.

- MOVE uses current map facing; REVERSE changes travel without changing facing.
- CHILL always draws/sets map facing, even when SLEEP or STILL prevents scrolling.
  CHILL does not apply REVERSE to its draw. A later MOVE sees the new facing.
- Nudges use their cardinal travel, apply REVERSE and retain map facing.
- FALL moves20 cells vertically or35 horizontally per declaration. SLEEP does
  not suppress it; REVERSE reverses its displacement.
- The original captures STILL/directional-lock status once using initial map
  facing (including cantmove's reversed lock lookup). A later CHILL draw does not
  change this status. LEVEL HOLD does not hold the synthetic map itself.
- Absent map state uses native Down lazily. The first actual scroll materializes
  that facing so the next turn continues in the same direction. Explicit None
  remains None; CHILL can supply a cardinal direction.

The scheduler adds `level_motion` after final contacts/code-status/orientation,
before the final tree outcome/boundary. It queries surviving scoped declarations
and projects current capabilities. The production adapter stops at the first
applicable ordered WIN/DEFEAT/END according to the existing outcome contract;
WIN without YOU does not stop scrolling. Capability queries still see the full
frame, including later STILL/REVERSE declarations. IS NOT and BROKEN gating use
RW_QueryLevelTraits. Prior compile-limit/CRASH terminal states and scoped level
conversion destruction skip this phase. Conversion-before-terminal priority is
unchanged; no previous contact/conversion phase reruns.

Offsets/facing use the existing stale-checked `board_shift`; CHILL uses a pure
random_state from/to journal. Park-Miller draws deliberately differ from the
original RNG sequence. Earlier automatic/MAKE/TELE draws feed this late phase.
An RNG-only turn still commits a stage. Preview is pure; late errors/stale
metadata reject atomically; local and whole-tree Undo restore input, random
state, offsets, facing, boundaries and allocators together.

## Verification and remaining limits

`tests/level_motion.lua` executes the installed motion branches, cantmove and
reversecheck unchanged with host scrolling/RNG callbacks isolated:6480 combinations
of facing, duplicate REVERSE, SLEEP, STILL/four locks, declaration sequences and
seeds. The oracle compares actual offsets/mapdir and draw order, not the native
undo-row facing fields (some MOVE/FALL rows record reversed travel as facing).

Compiler/scheduler tests cover physical rules, conditions, NOT/BROKEN, RNG-only
stages, terminal order, CRASH, stale metadata and late-error rollback. A tree WIN
boundary roundtrip verifies whole-tree Undo. Actual production OnStart/wait/Undo
adapters run with mapped-script and UI mocks. `tests/run.lua` includes this test;
real-device success is not inferred.

Remaining synthetic scope: cardinal orientation/statusblock and TURN/DETURN map
rotation, FEAR, TELE and FOLLOW. Frontend rotation is deferred. This oracle does
not establish the complete native levelblock destruction/terminal interleaving:
our frozen contact phases remain grouped before late scrolling, and terminal
selection retains the user's established outcome semantics. Conditional scoped
surroundings retain their existing saved-surroundings/current-child query contract.
Exact native mutable unit scheduling and queued conversion/host boundary dispatch
remain shared gaps. No timer or native AUTO routing is added here.
