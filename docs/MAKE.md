# MAKE

M9.4I implements the official MAKE predicate for physical ordinary noun/Text sources.
Primary references from the installed original game:

- blocks.lua 1660–1740: late MAKE phase, direction draw, old-occupant checks, Text products.
- features.lua getunitswithverb() 379 onward: rule-group/source snapshots and conditions.
- tools.lua create() 813 onward: inherited facing/level data and CONVERTED=true births.
- rules.lua subrules() 1112 onward: ALL expansion through both subject/object axes.

## Behavior and timing

MAKE creates at the source cell, preserving source facing and identity-bound level
metadata, without converting or destroying the source. STOP/PUSH/FLOAT/SAFE do not
block creation. A pre-existing matching concrete object blocks that target; any old
Text blocks MAKE TEXT. Current-turn converted/newborn entities are excluded from
that check, and MAKE's own products do not block later duplicate declarations.
Thus duplicate physical MAKE clauses may create overlapping products; a matching
old product normally blocks production on the next turn. MAKE TEXT creates the
source's noun Text. Text sources cannot MAKE TEXT. Ordinary authored ALL expands
through the existing vocabulary; ALL MAKE ALL preserves both expansion paths.
Conditions and right-NOT exclusions are per source identity.

The phase runs after SINK/WEAK/MELT/DEFEAT/OPEN-SHUT, using surviving sources with
the frozen contact rule declarations.
MAKE products do not rerun earlier destruction or MAKE in their birth turn; they
participate in late CRASH, final WORD/complexity checks and normal win projection.
When EAT is added it must be scheduled before MAKE, as in the original.

Transient converted IDs are reconstructed from transaction create/transform/retype
operations; they are not persisted as world facts. Allocations, products and random
state are validated and committed in the same whole-tree transaction. Any late
failure rolls everything back, and Undo restores the complete pre-turn snapshot.

## Random direction

None/Mid sources draw a cardinal direction before the occupant check, even if MAKE
is blocked. world.random_state defaults logically to seed 1. The pure generator is
`state = state * 48271 % 2147483647`; choose `state % 4` in Right/Up/Left/Down order.
This is our deterministic sequence, not a claim to reproduce the original game's
fixedrandom seed stream. Planning never mutates global or world RNG. The make stage
carries stale-checked random_state={from,to}; authored schema, RNG-only transactions,
no-turn rejection, Preview, Commit and Undo use the same rules. Boundary reloads
restore authored random state, consistently with other nonpersistent runtime facts.

## Tests and native route

`tests/make.lua` covers ordinary/Text/ALL products, duplicates, old/conversion
blockers, conditions/NOT, links/direction, contact timing, late CRASH, random Undo/
replay, invalid/stale RNG, allocator restoration and complete rollback after failure.
`tests/reference_make.lua` executes the installed MAKE body across 1,200 combinations
of source class/facing, target, occupant state, duplicates and source conversion.
Its create stub mirrors the inspected original CONVERTED=true assignment.

MOTION remains 32x28 with three-cell loose-word spacing. Root D x10 F, then D x5 F
enters it. Authored ROCK IS MOVE and ROCK MAKE FLAG create a trail: Space moves Rock
right and creates Flag at that position; Z removes the product and restores Rock.
Further Space turns create at new positions. Existing old Flags block repeats where
Rock returns. There is also a spare MAKE for building variants. The production input
adapter test executes the initial creation/Undo route with diagnostics disabled.
Startup measured 1,914,000 offline instructions (unchanged 2M limit).

## Remaining scope

Scoped LEVEL and virtual EMPTY sources remain deferred. GROUP behavior is deferred
until the requested GROUP batch. Finite board boundaries and authored noun vocabulary
remain current engine scope. Converted-flag lifetime across repeated original engine
block() subpasses and original mutable unit-list/group traversal order are not fully
replicated; this engine has explicit scheduled phases and stable ID ordering. Tests
establish the listed matrices, not whole-game or native-renderer parity.
