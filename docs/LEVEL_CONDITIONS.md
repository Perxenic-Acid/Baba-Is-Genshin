# Scoped LEVEL conditions (M9.7T)

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

M9.7P adds global WITHOUT/NOT WITHOUT, including noun/Text/Empty/LEVEL counts,
repeated quotas and complement parameters. It needs no parent coordinates.
Physical level_block counts map to LEVEL while the synthetic observer stays
unallocated. See WITHOUT.md for the normalized 20,736-case installed oracle and
its documented native complement-order difference.

## M9.7Q entry surroundings transport

Installed tools.lua getlevelsurrounds() saves the entrance direction and nine
one-cell regions r/u/l/d/dr/ur/ul/dl/o. It excludes the entrance itself, retains
other names in unitmap order, writes '-' for an unoccupied cell, and writes no
name for a cell occupied only by the entrance. Physical Text is named 'text';
physical level shapes are named 'level', regardless of destination metadata.
parsesurrounds() supplies these saved names to synthetic LEVEL condition queries.

The tree confirm path now passes the pre-reset source world to BindLevelEntry.
Capture into the child runtime's validated level_surrounds record; retain it when
reloading that instance and replace it on fresh entry. Do not derive it from the
already-reset authored parent or from the child board. This snapshot is semantic
boundary data, never UI state. Root instances have no inherited surroundings.
Whole-tree Undo restores the exact prior runtime; queries must not mutate arrays.

The nine-region transport is in place, but parent-spatial consumers remain
explicitly deferred until their original branch semantics are integrated. Tests
execute installed getlevelsurrounds across six intrinsic directions and sparse/
stacked neighborhoods, including transformed Text entrances and explicit unit
order. They also cover pre-reset movement, reload isolation, schema rejection and
whole-tree Undo. Startup remains 1,980,000 instructions; native success is unclaimed.

## M9.7R ON / NEAR / NEXTTO consumers

Execute the installed synthetic LEVEL branches, rather than transplanting ordinary
object geometry. Search child contents globally first, consuming distinct child
identities (and vacancy witnesses for EMPTY). ON may consume real Level shapes;
NEAR/NEXTTO do not take this positive LEVEL shortcut. Positive TEXT succeeds even
without a physical Text witness. Negative parameters can consume Text here, unlike
ordinary spatial complement queries. Child complement traversal uses the engine's
existing stable identity-order normalization instead of native unitlists hash order.

Then search saved entrance names: ON uses o; NEAR uses all nine regions; NEXTTO uses
all eight non-o regions (including diagonals in the original synthetic branch).
Parent names are reusable across repeated parameters, and '-' remains a literal
name for complementary matching, not an EMPTY object. Preserve concrete-before-
complement parameter order, NOT-clause inversion and current/frozen child contents.
No query result or witness set is saved to world state. Physical Level blocks keep
ordinary spatial semantics and never use the enclosing map's surroundings.

Compiler/tree cases cover parent-only/child-only witnesses, duplicate parameters,
Text/Level special behavior, mixed IDLE and conversion/Undo. The installed branch
oracle covers 9,216 normalized cases, full/empty child rooms, parent patterns and
positive/negative parameters. ABOVE/BELOW/side rays, FACING/FACEDBY/SEEING remain
explicit scoped gaps; ordinary implementations are unchanged.

## M9.7S ABOVE / BELOW / BESIDELEFT / BESIDERIGHT

Installed conditions.lua uses global child witnesses first, then exactly one saved
entrance side: ABOVE reads d, BELOW u, BESIDELEFT r, BESIDERIGHT l. These synthetic
branches do not scan distant parent rays or diagonal cells. Reuse parent names,
consume child identities, and retain Text/LEVEL/complement behavior from the
shared spatial query. Ordinary physical blocks keep their existing ray semantics.

Deliberate fault handling: original ABOVE/BESIDELEFT EMPTY queries findempty(),
but then iterate unitlists.empty rather than those vacancies. A missing list can
raise a native Lua error. The backend treats this unpopulated list as empty, not
as a global vacancy list, and never crashes normal startup for that native fault.
BELOW/BESIDERIGHT still use actual vacancy witnesses. The installed oracle
normalizes only the missing list to {}; this asymmetry has explicit tree tests.
No persistent Empty identities or Empty lifecycle are introduced.

The seven-branch source oracle now covers 43,008 normalized cases, including all
four cardinal parent regions, wrong sides, full rooms and repeated/NOT parameters.
Compiler/tree tests verify correct/opposite/diagonal/child-only witnesses and Undo.
FACING/FACEDBY/SEEING remain scoped gaps. No frontend or authored layout changes.

## M9.7T FACING

Installed conditions.lua facing() uses the saved entrance dir for unitid=1, then
checks only that one surrounding region. It does not search child contents, use
current physical-block facing, or consume distinct parent names. Repeated noun
parameters may reuse a name. Direction 4 fails positive FACING, including negative
noun parameters; a NOT FACING clause still reverses that result.

Direction arguments are literal names in this synthetic branch. LEVEL FACING
RIGHT does not directly mean the map entrance points right; it seeks a saved name
'right' on the selected side. EMPTY likewise matches the literal name 'empty', not
the '-' vacancy sentinel. The physical-unit branch keeps existing direction and
next-cell semantics. Frozen queries read the saved boundary context unchanged.

Compiler/tree tests cover six intrinsic directions, repeated names, complements,
literal direction arguments and conversion/Undo. Installed facing() comparisons
cover 1,040 direction/region/parameter/NOT cases. FACEDBY and SEEING remain scoped
gaps; the surrounding snapshot and other conditional subsystems are unchanged.
