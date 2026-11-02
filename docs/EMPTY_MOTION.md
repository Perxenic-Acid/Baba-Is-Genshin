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

At M9.8G, projection retained per-cell property counts rather than global
physical declaration slot indices. Conditional declarations matching different
vacancies can therefore merge cross-property slots differently from native.
Task order is normalized by real identity then vacancy y/x, rather than native
mutable lists. Virtual EMPTY destruction/HAS, source-specific special contacts,
scoped automatic motion and exact multi-agent collision scheduling remain pending.
The project's intentional virtual LEVEL HOLD exemption still applies. Random
numbers use the project's transactional stream, not native fixedrandom values.

## M9.8H global conditional collection slots

Installed features.lua findallfeature:245 appends each matching real unit to the
same list as one placeholder per valid EMPTY declaration, even when its vacancy
set is empty. movement.lua seen codes refer to those global positions. Projection
now retains per-cell motion_slots for MOVE/AUTO/CHILL, counting real matches and
inactive EMPTY placeholders. Fully unconditional denied EMPTY declarations are
excluded. Ordinary projection trait_counts remain unchanged.

Automatic collection resolves seen slots globally across all eligible vacancies
before proceeding to the next property. SLEEP/STILL-filtered cells do not consume
a seen code. This fixes later CHILL at another cell being incorrectly emitted,
and preserves later CHILL when an earlier property's slot was shifted by a real
match or a nonmatching EMPTY declaration. These are transient projection records,
not persisted world schema, and rendering has no role in their calculation.

The installed collection/state-0 oracle adds all 4,096 combinations of two slots,
two vacancies and three properties. Whole-turn tests exercise real offsets,
nonmatching placeholders, cross-vacancy suppression, RNG and Undo. The earlier
per-cell-slot gap is resolved within the engine's declaration order. Native
mutable feature/unit-list ordering, exceptional malformed/negative rule rewriting
and complete multi-agent collision scheduling remain separate parity boundaries.
Virtual destruction/HAS and other lifecycle gaps listed above remain pending.

## M9.8I virtual FEAR sources

Installed movement.lua take7 explicitly calls findfears(2,targets,x,y), checks
EMPTY SLEEP/cantmove at the source and queues amount impulses. tools.lua
findfears:2071 obtains EMPTY facing through emptydir and scans real occupants or
vacant cells in four cardinal neighbors. Repeated parameters increase strength;
stacked equal-name witnesses do not. Its exact score==1 tie test is retained.

Lowering now admits EMPTY FEAR with the existing predicate bans/conditions/ALL
expansion. The rules-script collector enumerates current vacancies only when an
EMPTY FEAR relation exists, applies BROKEN/conditions/exclusions per cell and
queries shared emptydir from the raw frame. It returns transient typed source
records with projected capabilities/counts; direction-query failure propagates
instead of emitting partial intentions. The native script bridge supplies raw
rules explicitly, without assuming shared script globals.

Movement collects every real and virtual intention against one snapshot. Temporary
agents are not physical witnesses, collision occupants or persisted IDs. Real
PUSH/PULL/WEAK/unlock dependencies use the existing solver; real deaths retain
source-frame HAS and newborn grace through the scheduler. Only positive-ID changes
and real death records leave the phase. REVERSE multiplicity, locks and the explicit
virtual LEVEL HOLD exemption share the existing typed-agent path. Whole-tree Undo
restores dependent motion, births and allocations; no virtual facing is saved.

For unset EMPTY facing, the native tie search can retain direction None by probing
its own empty cell. The implementation retains that no-displacement intention,
including ordinary STOP/PULL obstruction and PHANTOM/unsafe-WEAK bypass. Exact
zero-vector PUSH/SWAP/unlock/EAT probing and virtual destruction remain lifecycle
gaps, alongside native mutable multi-source retry ordering and scoped LEVEL FEAR.

Tests/empty_fear.lua uses the production compile/phase/Commit/Undo pipeline for
conditions, negative targets, duplicate strength, FOLLOW, BROKEN, SLEEP/STILL/locks,
REVERSE, real WEAK/HAS, positive-only changes and late atomic rejection.
Tests/reference_fear.lua adds 5,120 installed findfears comparisons for virtual
cardinal/None facing, counts, ties, static neighbor and source-cell STOP blockers.
It retains 2,048 real-source cases. This does not claim a complete native movement
state-machine oracle or native-device acceptance.
