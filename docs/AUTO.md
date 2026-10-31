# AUTO progress (M9.6F)

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

## Next implementation stage (not complete)

LEVEL AUTO input queuing and command_auto pulse execution remain pending. Original
normal commands save direction instead of moving when AUTO_ON > 0; each native pulse
executes AUTO_ON turns using both queued player directions, defaults absent channels
to wait, then clears auto_dir. This requires the simultaneous playerid=3 path noted
in YOU2.md, plus explicit queue/pulse transactions. The current native adapter still
executes normal inputs immediately, and no real-time AUTO timer is bound. The audit
marks AUTO partial rather than complete. Do not infer timed-mode success from the
unit-motion tests or a registered Text word.

Virtual EMPTY and synthetic scoped autonomous displacement remain shared motion
subsystem gaps. Real unit processing remains sorted serial resolution, not the full
original mutable collision-state scheduler. Native timer cadence and UI bindings
must be handled separately from pure command planning; source Lua exposes native
AUTO_DELAY state but does not define a portable wall-clock period.
