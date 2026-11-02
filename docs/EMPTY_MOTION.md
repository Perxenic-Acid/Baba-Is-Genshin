# Virtual EMPTY motion

## M9.8F counted, typed YOU agents

Installed tools.lua reversecheck:2469 counts EMPTY IS REVERSE declarations by
hasfeature_count and reverses only odd totals. cantmove:2248 also reverses its
lock query. Existing projection lost EMPTY declaration multiplicity and typed its
YOU proxies as ordinary objects, so even REVERSE counts behaved as a single grant
and proxies incorrectly participated in the project's real-unit LEVEL HOLD gate.

Projected empty_cells now carry trait_counts alongside traits/behaviors. Positive
active declarations add counts; conditional/negative suppression and fresh
projection remove retracted counts. These remain display/execution projection
data, not world schema fields. RW_ResolveTurn copies the real trait-count map and
adds read-only per-cell counts for temporary negative-ID agents, typed class=empty.
All emitted changes remain real positive IDs; no allocator or persisted virtual
entity is introduced. YOU input facing still follows its intention; there is no
saved EMPTY direction to update or Undo.

The HOLD exemption is the explicit workspace contract (AGENTS.md), not a newly
claimed native equivalence: native floating_level(2,x,y) can evaluate an EMPTY
layer, whereas this project defers that scoped virtual HOLD interaction. Real
pushed units still honor HOLD on their own FLOAT layer. Correctly typing the
controller must not bypass a real victim/dependency's restrictions.

Tests/empty_control_counts.lua covers 0..4 REVERSE grants, conditional and negative
counts, scoped HOLD/FLOAT combinations, SLEEP/STILL/locks, positive-only committed
IDs, unchanged allocators and Undo. tests/reference_reverse.lua adds 80 installed
reversecheck/cantmove EMPTY count/lock comparisons. Full regression retains startup
at 1,980,000 offline instructions; no native acceptance is inferred.

Remaining work includes EMPTY automatic MOVE/AUTO/CHILL/nudge intention collection,
shared emptydir in those phases, virtual destruction/HAS and the full per-cell
lifecycle. This milestone fixes prerequisites in the existing YOU route, not those
unimplemented automatic/destruction paths. General native mutable-list ordering
and recursive emptydir invalidation retain their existing documented limits.

## M9.8G automatic EMPTY intentions

Installed movement.lua add_moving_units:1727 collects EMPTY vacancies separately
from real units; state-0 dispatch around508 draws an unset MOVE direction and
always draws CHILL. AUTO never draws. Collection slot numbers are shared across
MOVE/AUTO/CHILL, but emptyseen is local to each collection call: a later property
whose slot is already occupied does not increment the earlier task. Duplicate
slots of one property start at independent original coordinates, not the previous
slot's arrival. Nudges likewise start at their original vacancy.

The production rules-script bridge queries shared emptydir before automatic
motion and passes only a transient direction map to the movement script. Typed
negative agents reuse ordinary PUSH/STOP/PULL/WEAK/unlock solving; other temporary
agents never count as physical occupants or trailing PULL units. Only real-ID
changes and real destruction frames leave the solver. Source facing is queried
again next turn; no EMPTY direction, ID or allocator product persists. Random
state remains a stale-checked atomic plan, shared with later conversion/MAKE and
restored by whole-tree Undo. Real-unit collection behavior is unchanged.

Tests/empty_automatic.lua covers MOVE/AUTO/CHILL counts and mixed slots, four
nudges, FOLLOW direction, unset direction/RNG, blocked bounce, SLEEP/STILL/locks,
REVERSE parity, real WEAK/HAS, positive-only plans, stale/late rejection and Undo.
Tests/reference_empty_automatic.lua executes installed collection and state-0
code for 720 count/direction/SLEEP/STILL cases. This is a collection/dispatch
oracle, not a complete native collision-state-machine oracle.

Remaining gaps: projection retains per-cell property counts rather than global
physical declaration slot indices. Conditional declarations matching different
vacancies can therefore merge cross-property slots differently from native.
Task order is normalized by real identity then vacancy y/x, rather than native
mutable lists. Virtual EMPTY destruction/HAS, source-specific special contacts,
scoped automatic motion and exact multi-agent collision scheduling remain pending.
The project's intentional virtual LEVEL HOLD exemption still applies. Random
numbers use the project's transactional stream, not native fixedrandom values.
