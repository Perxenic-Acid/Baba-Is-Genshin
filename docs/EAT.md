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
