# M9.4D: motion and directional conditions

Primary references are the installed official `Data` files, not mod copies.

- `movement.lua` takes 1–7 and `add_moving_units` (around 1730): YOU, MOVE and
  directional nudges; MOVE reverses when blocked, nudges preserve mover facing.
- `movement.lua` state 3 (around 516): reversal; check/solidity (around 1058):
  immobile PUSH behaves as STOP, while SLEEP alone does not prevent being pushed.
- `tools.lua` cantmove (2248): STILL and directional locks. A locked direction
  refers to attempted displacement, not current facing. SLEEP gates self-motion.
- `blocks.lua` statusblock (218–350): count cardinal grants, choose a unique
  maximum or use the original tie order, then apply TURN minus DETURN. TURN is
  clockwise (Right to Down), DETURN counterclockwise. SLEEP skips this update.
- `movement.lua` take 8 and `blocks.lua` moveblock (827): SLEEP on a SHIFT source
  does not suppress take-8 displacement; only final facing alignment checks it.
- `conditions.lua`: NEXTTO 647, FACING 828, ABOVE 1333, BELOW 1499,
  BESIDERIGHT 1665, BESIDELEFT 1831. NEXTTO is cardinal adjacency, excluding
  co-location; ABOVE/BELOW/BESIDE scan the whole aligned ray, not one cell.

## New vocabulary

MOVE, SLEEP, STILL, LOCKEDRIGHT/UP/LEFT/DOWN, RIGHT/UP/LEFT/DOWN,
TURN, DETURN, NUDGERIGHT/UP/LEFT/DOWN; NEXTTO, ABOVE, BELOW,
BESIDELEFT, BESIDERIGHT, FACING (including cardinal direction arguments).

All are actual grammar/query/behavior paths. Subject/RHS AND and NOT remain
physical-path based, with duplicate source clauses retained. Spatial conditions
remain per identity for ordinary effects, conversions and frozen HAS declarations.

## Transactions and cost

YOU movement precedes automatic MOVE/nudge impulses, then SHIFT, conversion,
MORE and frozen contacts. Automatic collision deaths use the existing source-frame
HAS path and current-turn newborn WEAK grace. Surviving direction/rotation grants
are applied after contacts as an orientation stage; final WORD compilation is checked
again if orientation changes. Everything is one Commit and one whole-tree Undo.

No automatic movement phase is projected when no relevant pre-turn capability is
active. Orientation reuses the existing final rule evaluation and skips projection
when no surviving direction/rotation grant exists. Production startup stays below
2M Lua instructions; no regressions run on native boot.

## Checks and native test route

`tests/motion_words.lua` covers bounce, two-sided blocking, repeated clauses,
negative grants, SLEEP/passive PUSH, STILL and directional locks, nudges/facing,
weighted directions, turns, WEAK/HAS, SHIFT, late failure rollback and Undo.
`tests/spatial_extra.lua` covers parsing, directional parameters, region geometry,
AND witnesses, NOT, conditional Text conversion and HAS.

`tests/reference_motion.lua` executes the installed statusblock body and compares
5,832 combinations. `tests/reference_spatial_extra.lua` executes the installed
condition functions and compares 8,820 cases. These source comparisons are separate
from in-game acceptance.

Root D x10, F; reference menu D x5, F enters MOTION. Wait/Space advances the Rock;
D pushes the sleeping Crate and advances the Rock in the same turn. Z restores both.
The room includes loose new words for constructing variants. Production mock input
callbacks execute this route with diagnostics disabled in `tests/run.lua`.

## Remaining scope

This batch does not complete the official catalog; see OFFICIAL_WORDS.md. Automatic
movement currently serializes different moving sources by ID within each family;
the full original multi-source retry graph is not implemented. Scoped LEVEL and
virtual EMPTY autonomous movement/orientation are not implemented. Authored initial
cardinal grants are applied at the first consuming turn's final orientation stage,
not by a separate level-load statusblock. Rendering the four direction traits and
SLEEP as original sprites/animations is left to the later frontend work. Directional
FACING against out-of-board EMPTY/edge and full original parameter witness ordering
outside the tested matrices remain to be expanded. These are tracked gaps, not claims
of whole-game parity.

## M9.4E: PULL, SWAP, PHANTOM and FALL

References: original movement.lua check (950–1204), swap updates (677–708),
trypush/dopush (1205 onward), blocks.lua fallblock (850–1130).

- PULL is solid from the front unless PUSH takes precedence. A successful movement
  attempts trailing pull chains. Failed pulls roll back only their speculative subtree;
  the leading mover stays moved. Blocked pulled WEAK does not shatter from that pull.
- SWAP on a mover exchanges all eligible destination occupants, keeping their facing;
  SWAP on a target exchanges that target after a successful arrival. Unrelated blockers
  can cancel target swap. STILL partners remain in place; layers do not filter swaps.
- PHANTOM bypasses ordinary entity/virtual-cell collision, including pushing and
  movement unlock. It does not suppress later contacts, including DEFEAT. The current
  finite authored board boundary remains solid (original off-board extent deferred).
- FALL/FALLRIGHT/FALLUP/FALLLEFT settle after conversion and before MORE/contact
  compilation. Opposite grants cancel by count. PUSH/PULL/STOP support rather than
  being pushed away. SLEEP does not stop falling; STILL/locks do. Facing is preserved.
  Unsafe bare WEAK encountered in transit dies with HAS; falling WEAK does not shatter
  merely from resting. FALL passes over SWAP without relocating that partner.
- Settling and its source-frame destruction/HAS are sequential atomic stages. HAS
  newborns receive WEAK grace. A 6000-step fall limit commits INFINITE LOOP and locks
  the board to Undo, matching the original fall limiter's terminal kind.

`tests/pull_swap.lua` and `tests/fall_words.lua` exercise these through the full
compiler/scheduler/Commit/Undo. `tests/reference_fall.lua` executes original check()
plus fallblock() and compares 45 support/cancellation/facing scenarios. The existing
MOTION room has loose words for all seven new properties. Startup remains <=2M.

Remaining differences: full original multi-source movement retry ordering is still
pending; pulled PUSH interactions and transient original collision cache behavior
need broader parity. FALL HAS births are resolved after settling and cannot become
support in the middle of that same settle. Scoped LEVEL/EMPTY lifecycle scope and
independently authored same-target level conversion linkage remain documented gaps.


## M9.4F: REVERSE and combined FALL directions

References: installed tools.lua reversecheck() (2469 onward), cantmove() (2248),
movement.lua active intention/returnolddir (545–592), mapcursor.lua (172 onward),
and blocks.lua fallblock (850–1125). REVERSE counts rule instances: odd reverses,
even cancels. It changes active YOU/MOVE/nudge/SHIFT displacement, while ordinary
PUSH/PULL dependencies follow the physical displacement without a second reversal.
Root facing retains the intention; SELECT and scoped LEVEL face their actual travel.
Directional lock checks preserve the original cantmove() reverse mapping, including
its second reversal after an active intention has already reversed.

FALL reverses the directional lists before opposite-count cancellation. All remaining
axes settle in down/right/up/left order, repeating until stable; it no longer drops
secondary FALL axes. Facing, source-frame destruction/HAS and whole-turn Undo remain
atomic. The existing 6000-step INFINITE LOOP limit also bounds combined-axis cycles.
Final SHIFT alignment retains the original belt facing (the original calculates a
reversed temporary direction but does not assign that value).

`tests/reverse.lua` covers compiler/scheduler/Commit/Undo, parity, PUSH dependencies,
MOVE/nudge/FALL/SHIFT, locks, SELECT and scoped LEVEL. `tests/reference_reverse.lua`
executes installed reversecheck()/cantmove(): 28 vector cases and 80 lock cases.
Expanded `tests/reference_fall.lua` executes original check()/fallblock() across 540
count/reverse/multi-axis/support cases. These are offline checks, not native acceptance.
Normal startup measured 1,876,000 instructions with diagnostics disabled (limit 2M).
The MOTION room now includes loose REVERSE; route remains root D x10 F, then D x5 F.
Construct AVATAR IS YOU AND REVERSE to move against WASD, then Z to restore the turn.

FEAR/FOLLOW/TELE/HOLD remain pending; this checkpoint only completes REVERSE and the
related multi-axis FALL correction. Existing multi-source retry, scoped autonomous
LEVEL/EMPTY, and same-settle HAS support gaps above still apply.


## M9.4G: FEAR and a sparse laboratory

Primary references: installed features.lua getunitverbtargets() (468 onward),
tools.lua findfears() (2071–2233), movement.lua take 7 (299 onward), and rules.lua
negative-rule cancellation (1165 onward). FEAR is a noun predicate, not a property.
It reads the four cardinal neighbor cells, excluding overlap and without FLOAT
filtering. Each matching target parameter adds one strength; stacked identities of
the same target do not add strength, but duplicate physical rules do. The strongest
side(s) determine the fleeing direction. Preserve original facing/clockwise/
counterclockwise/opposite tie search and its exact `score == 1` test, including
its peculiar duplicate-parameter behavior.

FEAR runs after MOVE/nudges, before SHIFT, using the pre-conversion declarations
and refreshed per-source spatial conditions. Collect all source intentions from
that phase snapshot. Resolve movement with PUSH/PULL/STOP, REVERSE, locks, WEAK,
unlock and source-frame HAS. SLEEP suppresses fear; STILL/locks may retain a facing
change without displacement. FEAR destruction and HAS are atomic stages; newborns
receive current-turn WEAK grace. Negative noun declarations veto matching grants
per source/condition; ALL uses our authored ordinary vocabulary. TEXT and EMPTY
are supported as targets. Real physical Text can be a source.

`tests/fear.lua` uses the compiler/scheduler/Commit/Undo, including conditions,
negative clauses, multiplicity, phase timing, PUSH, SLEEP/STILL/REVERSE, locks and
WEAK/HAS grace. `tests/reference_fear.lua` executes the installed findfears() body
against 2,048 combinations of neighbor masks, blocker masks, facing and duplicate
parameters. Existing regression suite passes. Native behavior still needs acceptance.
Normal production startup: 1,896,000 offline instructions, below the 2M budget.

MOTION is now 32x28. Authored rules are separated in the upper area; objects and
open working space occupy the middle. The 44 loose words occupy a three-cell grid
from row 15, leaving two empty cells between adjacent loose pieces. Extra nouns,
IS, AND and NOT are available. Tests check spacing and production input callbacks.
Route: root D x10 F, then reference menu D x5 F. From the initial room position,
S D D approaches a Flag with authored FLAG FEAR AVATAR: the Flag moves right one
cell on the second D. Z restores both the approach and the fleeing Flag together.
The room also retains the MOVE, sleeping PUSH and SHIFT examples.

Pending: scoped LEVEL/virtual EMPTY FEAR sources and the original multi-source
movement retry graph. Finite board boundaries still apply. The tie oracle covers
cardinal initial facing and static STOP blockers; broader original PUSH/unlock
probe ordering is not claimed. FOLLOW, TELE and HOLD remain pending.
