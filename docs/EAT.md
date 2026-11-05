# EAT (M9.4J)

Primary source: installed Data/blocks.lua 1625–1657 and features.lua
getunitswithverb() (379 onward). EAT is a noun predicate. A source destroys matching
non-self identities at the same cell and FLOAT layer, except SAFE victims. SLEEP,
STILL and source SAFE do not disable eating. Multiple actors/duplicate clauses
select a victim only once; mutually selected eaters still participate before the
simultaneous victim set is deleted. Each victim executes its HAS declarations once,
with their own duplicate multiplicity. HAS newborns are not recursively eaten.

Schedule: SINK -> WEAK -> MELT -> DEFEAT -> OPEN/SHUT -> EAT -> MAKE -> CRASH/final
rule checks. Source conditions and exclusions refresh against phase positions,
using frozen post-conversion declarations. Deleting Text does not recompile away
remaining frozen EAT/HAS/MAKE declarations halfway through the turn. EAT births
are current-turn converted IDs for subsequent MAKE occupancy checks. Surviving
HAS newborns can trigger late CRASH. All deletions, births, allocators and later
phases remain one atomic Plan/Commit/whole-tree Undo transaction.

Physical Text can be a source or target. Ordinary ALL uses the authored palette;
EMPTY has no persistent target identity. Scoped LEVEL and virtual EMPTY sources
remain deferred, consistently with the other noun predicates. Source/target order
uses stable IDs; original mutable engine-list ordering outside the tested victim
matrix is not a claim of complete parity.

Checks:

- tests/eat.lua: self/mutual/duplicate cases, SAFE/FLOAT/SLEEP, spatial conditions,
  right-NOT, HAS, Text removal with frozen MAKE, earlier WEAK death, newborn timing,
  ALL/EMPTY targets, surviving/eaten CRASH and Undo.
- tests/reference_eat.lua executes the installed EAT selection body across 3,072
  combinations of actors, occupancy, source/target classes, layers, SAFE and duplicates.
- Full offline regression passes; production startup is 1,919,000 instructions
  with diagnostics disabled (unchanged 2M limit). Sparse MOTION has a loose EAT.

The user waived routine native acceptance as a progress gate. Continue using
simulations/source comparisons and record scope gaps; do not label these as native
verification or wait for a manual test before implementing the next word.

M9.8R: real movers (including passive Object/Text PUSH) can EAT EMPTY during
entry. Source-origin conditions refresh per motion phase; targets need no EMPTY
property and use SAFE/FLOAT. EAT precedes unlock/WEAK and shares atomic cell HAS,
RNG and per-command deletion dedup. Phase-snapshot versus native lazy per-impulse
query timing remains a documented boundary in EMPTY_LIFECYCLE.md.

## M9.8Y real-target movement EAT

Installed movement.lua check() around1020-1045 tests EAT before ordinary target
solidity, with per-target SAFE/FLOAT and no pulling/PHANTOM collision specials.
move() around1567-1635 dispatches real-target lock before EAT and stops specials
when the source is gone. This differs from the virtual-target EAT-before-lock
ordering already covered by M9.8R.

Production motion phases now query a transient per-real-source target-name map
through RW_ResolveMovementEatTargets. It includes physical Text and passive
PUSH participants and also supplies the existing EAT EMPTY map without duplicate
condition queries. Eligible real targets bypass STOP/PUSH/PULL/SWAP/STILL and
are destroyed in the common movement solver. Unrelated blockers still roll back
speculative movement/deletion. Typed death frames retain target positions and
HAS, initialized newborn status, allocation and RNG in atomic stages and Undo.
Automatic/SHIFT/FEAR/FALL inherit the same collision path; late overlap EAT
remains a separate frozen contact phase.

tests/movement_eat.lua covers solidity, SAFE/FLOAT, unlock/HAS order, origin
conditions, passive Object/Text PUSH, Text victims, no-eating pull trials,
MOVE/FALL, rollback and Undo. tests/reference_movement_eat.lua executes installed
real-target collision/deletion branches for 4096 SAFE/FLOAT/PHANTOM/lock/solidity
cases and checks ordered deaths. This is offline/source validation only.

Source conditions remain phase snapshots rather than original lazy per-impulse
queries. Virtual EMPTY/scoped LEVEL source predicates and native mutable-list
ordering remain deferred. This change does not persist the target maps as facts.

## M9.8Z virtual EMPTY movement sources

The same installed check() explicitly names unitid=2 as EMPTY, including its EAT
query against real or virtual targets. EMPTY EAT predicates now lower to the
existing typed relation IR (including negative targets/exclusions). Motion
preparation evaluates them per cell, including occupied destination coordinates.
Original check() requires any active EAT at the source, then a matching target
EAT at the destination. EMPTY testcond uses the supplied coordinates (unlike
real units, which use their intrinsic origin). YOU, MOVE/nudge and FEAR agents
carry the source gate from their collected origin and use the destination's
phase-local target set. No negative IDs or eater data enter persisted entities.

Virtual movers use real-target lock-before-EAT and virtual-target EAT-before-lock
ordering, with independent SAFE/FLOAT checks and the existing cell delete cache.
tests/virtual_eat.lua covers real/vacant targets, conditions, YOU/MOVE/FEAR,
positive-only HAS transactions and Undo. The installed real-target collision
oracle now includes virtual movers for 8192 combinations plus eight source-any/
destination-specific coordinate-gate cases. Anonymous recursive
EMPTY PUSH chains, lazy per-impulse condition changes and scoped LEVEL EAT
sources remain deferred. Late overlap EAT has no occupied EMPTY source identity.

2026-11-05: incoming Noun EAT LEVEL now participates in the ordered synthetic
LEVEL stage. Installed blocks.lua2516-2534 calls findall(source,conditions) or
findempty(conditions,true); any qualifying source destroys the map when captured
lsafe is false. No overlap, FLOAT comparison or eater SAFE test is involved.
This is separate from the existing ordinary EAT of physical level_block targets.

Lowering marks only typed LEVEL targets, preserves source expansion and predicate
exclusions, and retains a query-only eat_level row alongside scoped properties in
the raw generated declaration order. Conditions and per-source BROKEN are checked
at that row's execution position; EMPTY is queried only at actual vacant cells.
Text and ordinary NOT/ALL/GROUP subject expansions use their existing lowering.
Map SAFE is the phase's captured projection, as native lsafe is. A successful row
stops later motion/terminals and reuses whole-map retirement: no HAS, no contacts
or late CRASH/code work on the doomed units, no new persisted metadata. Completed
preceding TELE/motion and RNG remain in the same transaction; Undo restores them.
Normal physical EAT collisions/overlaps retain their earlier scheduling.

Tests: reference_eat_level.lua executes the installed global branch plus original
WITHOUT in3072 combinations of Noun/Text/Empty, occupancy, source BROKEN, map SAFE,
conditions and source SAFE/FLOAT independence. Production compiler/scheduler tests
cover typed word sentences, RHS NOT, HAS suppression, map SAFE, ordered TELE/EAT/
CHILL draw prefixes and local Undo. A mapped OnStart/input/whole-tree Undo route
checks the cleared board and restored eater. Startup still runs no self-tests.

Outgoing LEVEL EAT noun/LEVEL/EMPTY, native interleaving of ordinary physical EAT
with this late stage, and the remaining synthetic surroundings remain gaps. Older
notes describing all scoped LEVEL EAT sources as deferred still apply to outgoing
LEVEL, not the now implemented incoming Noun EAT LEVEL case. Native particles and
sound remain frontend work.

2026-11-05 outgoing LEVEL EAT: direct ordinary nouns, TEXT, LEVEL, EMPTY and ALL
now lower to raw level_eat declarations in the same ordered synthetic loop.
Installed blocks.lua2478-2515 selects every matching real unit, ignores FLOAT,
queries each real victim's current SAFE, then calls delete() serially. LEVEL EAT
ALL does nothing in this branch. LEVEL EAT LEVEL retires the whole map when any
physical Level shape exists and captured map SAFE is false; when the map is SAFE,
only unsafe physical shapes are deleted normally with HAS. LEVEL EAT EMPTY calls
delete(2,x,y) on every current vacancy without SAFE/FLOAT filtering. tools.lua430
uses X-major/Y-minor vacancy order; delete()509 runs inside()/HAS before removal
and guards repeated virtual-cell deletion with the command's deleted cache.

RW_ResolveScopedEatTargets queries frozen raw declarations and current occupancy,
including source conditions, exclusions and synthetic BROKEN. Real victims keep
unit_order. The compiler retains raw scoped clauses but does not pass their new
opcode to ordinary conversion planning. RHS NOT uses the existing verb exclusion
contract. Typed LEVEL metadata, rather than an ordinary noun alias, selects the
synthetic branch. Existing ordinary EAT scheduling is unchanged.

RW_PlanScopedLevelSequence emits flat motion/death/birth stages. HAS for this
serial native branch sees preceding parents already removed and earlier births
already present, unlike simultaneous ordinary EAT contacts. HAS births initialize
BROKEN/BACK and their projected FLOAT before later TELE; surviving old units retain
stored phase capabilities. Later scoped conditions and incoming Noun EAT LEVEL
see the new occupancy. Contacts/conversions do not rerun. Capture map SLEEP/STILL/
locks once and carry TELE's three-pass counter across every deletion barrier;
per-action REVERSE and per-unit map FLOAT remain current queries. Stage metadata,
allocators, RNG, events and motion journals participate in one whole-tree Undo.

EMPTY's transient deleted-cell cache survives all outgoing clauses and is seeded
from earlier motion/contact deletion. It never enters world/Undo. Compile-limit
HAS prefixes retain the triggering parent and completed/trigger newborns, stop
later phases, and commit the only-Undo state. Ordinary errors reject all preceding
motion/creation as well. The existing 32-flat-stage transaction bound reserves two
late slots; exceeding the available scoped-stage budget commits the representable
prefix as TOO COMPLEX, without leaking planned-but-uncommitted births or RNG.
This is an explicit backend representation limit, not an original levelblock cap.

Tests: reference_level_eat.lua executes the installed outgoing selection branch
and WITHOUT unchanged in9216 cases (all direct target kinds, source conditions,
map/target SAFE, BROKEN, FLOAT independence and identity/cell order). Scheduler
coverage includes frozen Text HAS after code deletion, serial conditional HAS,
duplicate clauses eating newborns, EMPTY births and duplicate-cell suppression,
TELE/EAT/HAS/TELE RNG/unit lists/cap, captured direction locks, newborn FLOAT,
incoming eat-on-newborn, later condition activation, stale-delete rejection,
HAS terminal prefixes and ordinary late errors. A mapped OnStart/input/whole-tree
Undo test exercises production adapters. These are offline/source checks, not a
new claim of real-device acceptance.

The older outgoing direct-target deferral above is superseded.

Scoped EAT GROUP follow-up: raw positive/negative GROUP consumers remain
in authored order; grouprules-derived member consumers append afterward. Raw
findgroup-style queries promote conditional nouns globally, gather victims once
and deduplicate identities before serial HAS. Derived clauses can consume those
newborns. Literal GROUP members ALL/EMPTY use concrete unit lists, without
re-entering the direct virtual EMPTY branch. LEVEL members retain map retirement.

Correction to the direct ALL branch note: installed subrules (rules.lua1112+)
expands authored LEVEL EAT ALL into ordinary noun clauses before MIMIC and
GROUP expansion. The raw ALL clause itself remains inert. GROUP-derived ALL
arrives after subrules and stays inert. ALL-origin copies also retain NOT ALL
protection. reference_level_eat_groups.lua executes installed addoption/subrules/
grouprules in90 ordering/multiplicity cases. Another96 cases execute installed
findgroup and the late EAT branch to check conditional global promotion, SAFE,
duplicate victim aggregation, unit-list order and map retirement.
level_motion.lua checks raw duplicate
GROUP membership, successive HAS newborn consumption, bans and atomic Undo.
Other synthetic LEVEL effects still do not share this whole ordered loop.
Conditional synthetic surroundings and host audiovisual bindings remain deferred.
Ordinary earlier EAT/contact phase order is preserved, rather than claimed to be
complete original levelblock scheduling.
