# Virtual EMPTY destruction and HAS

## M9.8J self-contact phase

Primary installed references: blocks.lua levelblock(), around2081-2450; tools.lua
handleinside:477, delete:509 and inside:977. levelblock scans vacant cells after
ordinary block destruction/creation, pairs OPEN/SHUT, HOT/MELT and YOU/DEFEAT,
then invokes delete(2,x,y). There is no persistent EMPTY unit to remove. SAFE
protects the cell. SINK or WEAK alone does not self-destruct a vacancy. Matching
FLOAT gates EMPTY contact with scoped LEVEL, but not a cell's own property pair.

The new empty_contact stage runs after ordinary EAT/MAKE and before late END,
BONUS, CRASH and final reading checks. It refreshes conditions from the frozen
contact declarations, selects each unsafe vacant victim once, and handles
self OPEN/SHUT, MELT/HOT, YOU/YOU2+DEFEAT plus scoped LEVEL SHUT/OPEN/HOT/DEFEAT.
Selection order is x then y, matching the original levelblock traversal. There
are no virtual delete operations, persistent tombstones or negative committed IDs.
HAS products are real creations in this atomic whole-tree transaction.

EMPTY HAS now lowers to an explicit empty_has relation with per-source conditions,
negative bans, duplicate products and ordinary/Text/ALL/Level targets. HAS EMPTY
produces nothing. Text products are text_EMPTY, and Level shapes have no destination
metadata because an empty cell has none. Ordinary HAS handling and IS conversion
remain separate. HAS ALL retains the project's authored palette and multiplicity.
MIMIC/GROUP expand before this lowering as for other declarations.

inside() shares one orientation across a cell's ordinary/Text products. It draws
once when emptydir is unset even if there are no eligible HAS products. The planner
uses the existing pure transactional RNG stream; random-only cell destruction is
therefore still a stale-checked stage and Undo restores it. Known direction avoids
the draw. Newborns run the existing ordered BROKEN initialization and later CRASH/
WORD checks. Compile-limit creation prefixes enter the existing only-Undo state.
No production boot tests or extra mapped scripts are introduced.

Tests/empty_contacts.lua exercises both declaration orders, SAFE/FLOAT, scoped
contacts, HAS duplicates/Text/ALL/NOT/conditions, newborn BROKEN/CRASH, allocation,
random-only stages, stale metadata and whole-tree Undo. The standalone installed
source oracle tests/reference_empty_contacts.lua executes the real pairing/deletion
branches for 16,384 combinations and inside() for 320 ordinary/Text/direction cases.
These are source/dispatch oracles, not native-device acceptance.

## Remaining scope

Movement unlock/WEAK/EAT virtual victims,
per-command cross-phase virtual deletion deduplication and complete scoped LEVEL
lifecycle remain pending. This phase does not add EMPTY SINK/WEAK self-destruction
which the original levelblock does not perform. Native late-empty victory/re-entry
ordering, HAS ALL's exact createall bookkeeping/random draws/protection, and
source-specific zero-vector probes remain separate parity work.

Victims are selected once, then virtual delete/HAS calls run serially in native
x/y order. RW_PlanEmptyContactPhase supplies earlier initialized real products as
witnesses for later HAS conditions/status, advances tentative allocators and RNG
purely, and finally emits one atomic creation plan. A creation-limit prefix stops
before later victims and their orientation draws. Tests include WITHOUT-driven
birth witnesses and terminal-prefix RNG/allocation/Undo.
## M9.8K virtual BONUS pickups

The same installed levelblock branch pairs EMPTY BONUS with YOU/YOU2, or with
matching-layer scoped LEVEL YOU/YOU2. Unsafe qualifying cells enter the shared
virtual destruction set; SAFE prevents both this cell's reward and deletion.
Unlike real BONUS's property-instance multiplication, emptybonus gates exactly
one award across all qualifying cells in the entire scan. Another contact killing
the cell does not suppress the award, and multiple causes still run HAS once.

The late empty_contact stage now carries a stale-checked bonus_state increment
and one transient event with cell coordinates, without fabricated entity IDs.
Events reach campaign accounting and native diagnostics only after accepted
whole-tree Commit. The actual native event dispatch distinguishes an EMPTY cell
from real entity/collector IDs. Undo restores local and campaign reward totals,
products, allocation and RNG; reload retains the campaign total. Existing serial
HAS and creation-terminal handling retain rewards issued before delete() calls.

The installed selection oracle now covers 65,536 combinations including BONUS and
scoped YOU as well as SAFE/FLOAT, duplicate pair ordering and other contact deaths.
Turn tests cover one/many cells, duplicate grants, both YOU variants, SAFE, layers,
shared HAS, stale counters, campaign reload/Undo and actual native event formatting.
Synthetic LEVEL BONUS, virtual BOOM and movement-specific destruction are still
separate remaining paths; original late-empty WIN/END ordering remains documented.

## M9.8L virtual BOOM

Installed blocks.lua:2293-2353 explodes every qualifying vacant source using a
square radius of BOOM declaration count minus one. SAFE protects each real victim
independently and prevents the source cell's own deletion, without disabling its
blast. Ordinary victims are queued once; no new HAS product recursively explodes.
One BOOM has radius zero, so its vacant source cannot hit a real same-cell unit.

The installed floating(f,2,x,y) call is significant: tools.lua floating:1254 queries
EMPTY FLOAT at the victim coordinates, not at the remote blast source. The rules
planner uses current/frozen declaration queries at occupied victim cells as well,
including conditional FLOAT and virtual BROKEN; projected vacant-source facing or
FLOAT is not substituted for that query. Radius and multiplicity still come from
the active source cell's compiled projection.

RW_PlanEmptyLateContacts collects virtual self-contact/BOOM victims from one late
snapshot, deduplicates cells, and plans a real empty_boom destruction/HAS stage
before the empty_contact cell-HAS stage. Later virtual HAS queries see initialized
real births and the advanced allocator. Each stage keeps its own stale preconditions;
the top-level changes list is only a diagnostic summary. Frozen declarations survive
destroyed Text until final WORD/CRASH evaluation. Scoped traits refresh after either
stage changes units.

EMPTY BONUS is awarded during the original scan, before those delete() calls.
When a real blast stage exists, it carries the reward counter/event so a later
virtual query/creation limit preserves that prefix. A real birth initialization
limit likewise retains the blast/reward prefix and skips all virtual inside()
calls. Ordinary errors reject the entire transaction. Pure RNG, actual partial
allocations and whole-tree Undo remain intact.

Turn tests cover radii/counts, diagonal/Text/SAFE victims, source-vs-target FLOAT,
real-before-virtual HAS and allocators, earlier-birth conditions, no recursive
newborn explosion, BONUS, stale counters and real/virtual terminal prefixes.
Tests/reference_empty_boom.lua executes the installed BOOM body and floating()
helper for 1,280 range/SAFE/layer/multiple-source cases.

Remaining boundaries include native real-victim mutable unitmap traversal (the
project normalizes victim IDs), cross-phase virtual delete deduplication, movement
unlock/WEAK/EAT cell victims, exact HAS ALL bookkeeping and late-empty WIN/END
scheduling. Scoped LEVEL BOOM and other synthetic lifecycle paths are separate.
