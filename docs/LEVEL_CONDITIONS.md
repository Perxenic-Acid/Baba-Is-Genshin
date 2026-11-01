# Scoped LEVEL conditions (M9.7L)

Installed conditions.lua testcond() uses unitid=1 for the synthetic map, obtains
its parent-entry surroundings from parsesurrounds(), and separately handles its
BROKEN query. IDLE consults last_key; OFTEN/SELDOM cache a draw by clause and unit
identity (unitid=1 for the map). These three prefixes do not inspect parent tiles.

## Input and chance prefix integration

Conditional LEVEL clauses composed entirely of IDLE/OFTEN/SELDOM, including NOT
and conjunction/requirements trees, now use one shared lowerer path. Evaluate the
map's condition with a transient synthetic identity id=0, class=level, at the
current input/chance frame. This identity is never in world.entities or an
allocator. Its result selects scoped typed commands for properties, protections,
conversions, BECOME and self-negative destruction. Existing scoped BROKEN filtering
still runs after all applicable scoped declarations are collected.

Physical Level blocks keep the original condition on their ordinary generated
rules/relations. Do not replace their condition with the map's Boolean: chance
prefixes use each physical ID independently. Source/physical sentence identity,
multiplicity and activation remain intact even when the map condition fails.
The compiler does not persist condition outcomes or caches. Input/chance metadata
is still owned by the accepted move/wait's first atomic stage and whole-tree Undo.

OFTEN/SELDOM retain the agreed pure keyed RNG policy. The synthetic identity is
separate from every positive physical ID; it does not claim to duplicate the
original global RNG sequence. Repeated compilation/planning cannot consume draws.
Normal startup neither advances seeds nor runs regression tests.

## Validation and open scope

level_prefixes.lua covers current wait/move and NOT IDLE, scoped conversion/WIN,
physical declarations, BROKEN/identity protection/self-negative destruction,
sentence activation, Undo and 64 repeated pure chance plans with distinct map and
physical decisions. Installed prefix oracles now include LEVEL: 24 IDLE cases and
1,920 normalized OFTEN/SELDOM cases with repeated-query caching.

Parent-dependent spatial conditions (including mixes with the supported prefixes)
remain explicitly deferred. POWERED/FEELING and other query-dependent prefixes
need a complete current-frame scoped declaration query, not this input-only path.
LONELY needs actual parent occupancy. Scoped HAS lifecycle and other unrelated
LEVEL consumers keep their existing subsystem limits. No child-grid coordinate
substitution is used to fake parent surroundings; native acceptance is unclaimed.
