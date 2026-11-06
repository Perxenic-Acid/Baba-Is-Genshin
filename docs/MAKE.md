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

Scoped LEVEL sources remain deferred. Virtual EMPTY sources are supported as of
M9.8B below. GROUP behavior is deferred
until the requested GROUP batch. Finite board boundaries and authored noun vocabulary
remain current engine scope. Converted-flag lifetime across repeated original engine
block() subpasses and original mutable unit-list/group traversal order are not fully
replicated; this engine has explicit scheduled phases and stable ID ordering. Tests
establish the listed matrices, not whole-game or native-renderer parity.

## M9.8B virtual EMPTY creation

The installed features.lua getunitswithverb collects matching vacancy lists before
the MAKE loop. blocks.lua:1660 then creates at each EMPTY source, using emptydir
and drawing a direction when unset. EMPTY bypasses the old-occupant MAKE blocker;
Text products use text_empty. The compiler now admits EMPTY MAKE (including ALL,
conditional rules and negative target exclusions). The planner enumerates the
current vacancy snapshot once per phase and reuses it for duplicate declarations,
without IDs or persisted EMPTY entities. Earlier MAKE births cannot consume those
snapshot sources. Vacancies refresh on the next accepted turn.

Conditions use the current frozen relation frame, including dynamic EMPTY BROKEN;
query errors propagate before Commit. Existing creation initialization, allocator,
random-state, terminal checks and whole-tree Undo remain in the normal MAKE stage.
Tests cover duplicate overlap, Text, spatial/negative rules, BROKEN, ALL, replay,
late CRASH and Undo. Fifteen cases execute the installed EMPTY branch including
random draws for a non-producing EMPTY target.

At this milestone EMPTY used the virtual None convention and a planned random
direction; M9.8C below supersedes that MAKE limitation. Scoped LEVEL sources and
EMPTY destruction/HAS are separate remaining lifecycle work. No native acceptance
is inferred from offline tests.

## M9.8C queried EMPTY direction for MAKE

RW_QueryEmptyDirection follows installed tools.lua:1339 emptydir over the current
raw/frozen declaration frame. Ordered cardinal IS declarations overwrite facing;
the first FOLLOW target list with an eligible non-overlapping target locks further
FOLLOW searches, while later cardinal IS declarations still overwrite it. Nearest
Manhattan targets use the last equal-distance witness and favor the vertical axis
on a diagonal. Physical traversal is normalized to stable ID order. FOLLOW ALL,
EMPTY and LEVEL are not orientation targets. SLEEP or dynamic BROKEN yields None.

The compiler retains the mixed direction/FOLLOW declaration order as transient
empty_directions metadata, including source conditions and target exclusions.
EMPTY MAKE receives this frame even without other rule-query conditions. MAKE
queries direction before drawing; a known direction consumes no RNG. No virtual
identity, saved facing, inherited behavior cache or additional mapped script is
introduced. Positive FACING/SEEING clauses autofail during the direct direction
declaration query, as testcond's native autofail list specifies; they are not simply
ignored. Negated clauses retain their normal query behavior.

Compiler/turn tests cover order, conditions/NOT, SLEEP/BROKEN, FOLLOW, RNG-free
products and Undo. tests/reference_empty_direction.lua executes the installed
emptydir across 2,744 ordering/target/condition/SLEEP cases. Existing 1,200 real-unit
and 15 EMPTY MAKE source-oracle cases continue passing. Startup remains 1,980,000
instructions. Native acceptance is not inferred.

At this milestone the shared query was connected to MAKE only. M9.8D extends it
to condition observers; conversion products and virtual movement still require
their separate orientation integration.
Original postrules condition rewrites and mutable native unit-list ordering beyond
the explicit normalized cases remain known parity boundaries.

## M9.8D EMPTY directional condition observers

Installed conditions.lua:835/960/1020/1071 queries emptydir for EMPTY FACING,
FACEDBY and SEEING. These consumers now query the current raw/frozen declaration
frame too. FACING/FACEDBY relations retain condition_rules even when they have no
other property-query clause. Only temporary observer copies receive direction;
the source probe/world is never mutated. FACEDBY tests each in-bounds adjacent
vacancy's facing, preserves occupied-cell complements and permits reuse of a
watching EMPTY cell for repeated parameters, as the original placeholder path does.

Nested queries share the existing transient guard/depth frame. Re-entering the
same cell's emptydir returns None, while depth 80 reports word_rule_limit. Guard
entries clear after successful or failed queries. The direct positive FACING/SEEING
autofail remains in place. Native checkedconds keys are per condition-table identity;
our cell-based recursion guard is an explicit remaining parity boundary for
pathological recursive declarations, not a claim of exact native invalidation.

Turn tests exercise FACING/SEEING MAKE, occlusion, FOLLOW-derived FACEDBY,
occupied/complement witnesses, repeat-query isolation, failure cleanup and Undo.
Installed-source comparisons add 3,920 EMPTY FACING and 640 EMPTY-observer FACEDBY
cases; the real/EMPTY SEEING matrix now covers 59,904 cases. Existing direction
and MAKE source oracles remain separate checks. Startup remains 1,980,000 offline
instructions. No native-rendering or manual acceptance is inferred.

M9.8E also connects the direction query to EMPTY conversion products and carries
conversion RNG through the scheduled stage. See EMPTY_CONVERSIONS.md for per-product
versus shared ALL draws, tests and remaining lifecycle/parity limits.

Real MAKE sources now follow saved world.unit_order within each declaration, with
sorted identity fallback for diagnostic worlds without that metadata. This matches
installed features.lua getunitswithverb's unitlists traversal and blocks.lua's
producer loop: random facing draws and product allocation follow source creation
order, not numeric IDs. Existing converted-occupant and duplicate-rule behavior is
unchanged. The source oracle adds 72 native grouping/MAKE cases with permuted unit
lists, ordinary/Text sources, known/unset facing and duplicate clauses. Scheduled
coverage checks allocated identities, per-source RNG assignment and complete Undo.
Cross-noun group dispatch retains deterministic relation order; native pairs(group)
ordering is not portable and no exact cross-noun dispatch guarantee is claimed.
