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

Virtual BOOM and BONUS deletion, movement unlock/WEAK/EAT virtual victims,
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