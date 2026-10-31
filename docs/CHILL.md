# CHILL (M9.6A)

Primary reference: installed Data/movement.lua, movecommand take 2 collection
(MOVE, AUTO, CHILL), add_moving_units, state 0 EMPTY direction and state 3 reversal.
Tests execute installed add_moving_units unchanged with host adapters in 384 cases.

## Implemented real-unit scope

Public CHILL participates in the existing automatic phase after input movement,
before FEAR/SHIFT. Awake CHILL grants each draw a cardinal facing before any
unit displacement. STILL/locks do not prevent the facing draw; each grant adds
an impulse only when its drawn direction is permitted. SLEEP suppresses draws.
MOVE collection precedes CHILL; their counts share the final collected facing.
Duplicate grants draw repeatedly and add impulses. Autonomous blockage uses the
ordinary MOVE reversal/PUSH/WEAK/unlock solver; nudges retain their later order.

Plans carry stale-checked random_state from/to, including facing-only and RNG-only
turns. Scheduling preserves this metadata before destruction and subsequent RNG
consumers. Preview is pure, rejection consumes nothing and whole-tree Undo restores
the draw sequence. Production startup still does not execute diagnostic tests.

## Deliberate gaps

Virtual EMPTY and scoped LEVEL automatic CHILL are not implemented. Real-unit
collection is sorted by persistent identity rather than the original mutable
unitlist/declaration traversal. Random draws use our existing Park-Miller state,
not the original fixedrandom sequence. The existing automatic solver serializes
units; exact original multi-unit collision-state scheduling remains a motion gap.
The oracle covers collection, not the complete original movement solver.
Frontend and authored level design remain deferred.
