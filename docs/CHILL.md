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

M9.8G adds virtual EMPTY automatic CHILL; see EMPTY_MOTION.md for its separate
collection/dispatch oracle and conditional slot-index gap. Scoped LEVEL automatic
CHILL was subsequently implemented as described below. Random draws use our existing Park-Miller state,
not the original fixedrandom sequence. The existing automatic solver serializes
units; exact original multi-unit collision-state scheduling remains a motion gap.
The oracle covers collection, not the complete original movement solver.
Frontend and authored level design remain deferred.

2026-11-05: scoped LEVEL CHILL is now implemented separately in the late ordered
level_motion stage, including draws while SLEEP/STILL, no CHILL REVERSE, atomic
RNG/facing/scroll and Undo. See LEVEL_MOTION.md for source/oracle coverage and
remaining synthetic map orientation/other motion scope.

2026-11-06: real MOVE/AUTO/CHILL collection now follows property order, physical
declaration order and each noun's creation-order unit list. Each CHILL declaration
assigns its draws in that order, including duplicate declarations; first eligible
collection retains the queued identity's reason and dispatch position. Projection
source groups are transient. Direct capability-only callers retain a numeric-ID
fallback because they have no physical declarations to order.

tests/reference_automatic_order.lua executes installed findfeature/findallfeature,
findall and add_moving_units in 7680 cases with permuted identities, duplicate
clauses, Text, sleeping/locked units and normalized conditional eligibility. It
checks draw assignment, final facing, collision-free displacement and Undo, not
the complete native collision scheduler or dynamic condition-query timing.
Mixed real/EMPTY queue interleaving and nudge collection order remain gaps.
