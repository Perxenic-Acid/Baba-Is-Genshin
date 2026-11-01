# Scoped LEVEL conditions (M9.7O)

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
remain explicitly deferred; parent-dependent queries need actual surroundings.
LONELY is supported: installed lonely() explicitly returns false for unitid=1,
regardless of surroundings; NOT LONELY returns true. Physical blocks keep their
ordinary identity-based occupancy query. Scoped HAS lifecycle and other unrelated
LEVEL consumers keep their existing subsystem limits. No child-grid coordinate
substitution is used to fake parent surroundings; native acceptance is unclaimed.

## POWERED channels and dynamic scoped BROKEN

M9.7M admits POWERED/POWERED2/POWERED3 and their NOT/conjunctions alongside
input/chance prefixes. Installed conditions.lua powered() queries conditional
LEVEL sources through testcond(unitid=1), alongside real units and EMPTY.
Generated frames now carry raw scoped property declarations with their conditions,
rather than a latched scoped_power Boolean. Query scoped BROKEN dynamically with
its nested ignorebroken bypass. Conditions therefore see later declarations and
can lose their power source in a frozen contact frame. Recursion guards and depth
limits remain transient; no query result enters world state or Undo.

level_prefixes.lua covers conditional map power, channels, ungrounded recursion,
BROKEN suppression/release, conversion/Undo and frozen-frame source deletion.
reference_powered.lua now uses raw conditional scoped declarations in its 1,080
installed-source comparisons. Startup remains 1,979,000 instructions. Parent
spatial conditions and native acceptance remain open.

M9.7N adds scoped LONELY/NOT LONELY to the shared condition path. Compiler/tree
conversion and Undo tests keep physical Level behavior separate; the installed
LONELY oracle includes synthetic LEVEL with zero through four co-occupants.

M9.7O supports FEELING with property/direction arguments, NOT arguments and repeated
parameters through raw scoped condition instances. Mixes with other supported
input/chance/POWERED/LONELY clauses use the shared path. Frozen queries re-evaluate
conditions and BROKEN dynamically; they do not read old projections. See FEELING.md
for the 5,760-case normalized source oracle and remaining recursive/postrules gaps.
