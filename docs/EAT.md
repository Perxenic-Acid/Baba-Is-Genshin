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
