# AUTO progress (M9.6H)

Installed sources: Data/movement.lua take-2 MOVE/AUTO/CHILL collection,
add_moving_units(), state-3 reversal and blocked state transition;
Data/blocks.lua statusblock()/startblock() AUTO_ON assignment;
Data/syntax.lua command() and command_auto(). 576 tests execute installed
collection plus the original reversal guard; seven original AUTO_ON count cases
verify the scoped multiplicity query. Full original collision solver is not copied.

## Implemented unit motion

Real AUTO is collected between MOVE and CHILL. Its applicable declarations add
impulses, share the final CHILL-facing draw and retain the first collected reason.
If that reason is AUTO, blockage does not reverse. A preceding collected MOVE
retains MOVE reversal; a locked/ineligible AUTO cannot suppress later CHILL reversal.
Duplicate grants preserve count, and SLEEP suppresses self-motion. STILL/locks,
PUSH/PULL, REVERSE, WEAK/unlock/HAS use the existing common solver. Displacement,
facing, death frames, births and any CHILL RNG remain atomic and reversible.
Public AUTO supports ordinary conditions/NOT/BROKEN/MIMIC/GROUP/property queries.

RW_GetAutoTurnCount(projected_world, optional_traits) counts scoped AUTO capability
instances. Unconditional denial/scoped BROKEN are handled by the existing compiled
LEVEL trait frame. Scoped SLEEP/STILL do not stop this count/clock, as in original
statusblock(). Querying counts has no input, RNG, history or host timing effects.

## Pure command queue and pulses

M9.6G supplies simultaneous per-channel movement. M9.6H adds:

- `RW_PlanAutoCommand(tree, action, services)`: ordinary move/wait channels 1/2
  remember their last direction. With scoped AUTO active, only `tree.auto_input`
  changes; no board, input/chance/RNG, status, local history or turn advances.
  Without AUTO the ordinary action runs immediately and still remembers its input.
  Confirm delegates to the existing separate navigation action.
- `RW_CommitAutoInput(tree, plan)`: validated queue-only commit without a history
  entry. Every other tree field must be identical. Stale plans, invalid queue
  keys/directions, terminal states and defeated-without-SELECT are rejected.
- `RW_PlanAutoPulse(tree, services)`: sample initial scoped AUTO multiplicity,
  execute that many dual-channel turns with absent channels waiting, and clear
  both inputs afterward. Each turn has its own input/chance/motion/conversion/
  contact phases. Intermediate tree candidates stay private; one ordinary outer
  `RW_CommitLevelTree` stores the whole pulse and queue for Undo. A zero-count pulse
  only clears the queue through the queue-only commit. The caller selects the
  committer using `plan.kind == "auto_input"`.

Services include existing level action services plus `auto_count` (normally
`RW_GetAutoTurnCount`). YOU2 fallback for queue collection uses generated
property-declaration presence, including failed/negative declarations, rather
than the set of currently qualifying units. Each new input replaces its channel;
it does not overwrite an already queued primary fallback. No input consumes RNG.
All pulse events are returned for dispatch only after successful outer Commit.
Nonterminal late errors reject the whole pulse. Infinite Loop/Too Complex commit
the completed triggering prefix, clear the queue and allow only Undo.

The unchanged installed syntax.lua command()/command_auto() execute in an isolated
host adapter for 60 queue/count combinations. Additional tests cover weighted
independent directions, no-input waits, replacement, negative/conditional YOU2,
RNG/history, queue/stale-plan validation, CRASH prefix and late-error rollback.
Native success is not inferred.

## Remaining scope

Native command routing still uses the existing immediate-action adapter; it must
switch to the queue API together with a host clock binding to avoid stranding
players in timed levels. No native timer cadence is claimed. The catalog remains
partial for this integration. Frontend timing is deferred with the frontend work.
Pulses stop on navigation boundaries or defeat, rather than applying remaining
old-room commands to a newly entered parent. The original defers MF_update until
all pulse turns complete; exact deferred boundary/result ordering remains a gap.
Conditional scoped LEVEL evaluation and the full mutable original collision
scheduler retain their documented shared limits.

Virtual EMPTY and synthetic scoped autonomous displacement remain shared motion
subsystem gaps. Real unit processing remains sorted serial resolution, not the full
original mutable collision-state scheduler. Native timer cadence and UI bindings
must be handled separately from pure command planning; source Lua exposes native
AUTO_DELAY state but does not define a portable wall-clock period.
