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
