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
