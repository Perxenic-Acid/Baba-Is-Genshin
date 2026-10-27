# M9.3Z FLOAT

## Primary references

Installed original `Data/tools.lua`, `floating` (~1254), compares the two numeric
FLOAT values; real units use cached values and EMPTY queries its FLOAT feature.
`Data/blocks.lua`, `statusblock` (~373), maps ordinary FLOAT to height 1.
Contact consumers call `floating`: SINK (~1431), WEAK (~1479), MELT (~1511),
DEFEAT (~1554), OPEN/SHUT (~1598), and WIN (~1884).

`Data/movement.lua`, `check` (~1025-1100), gates unlocking on matching layers,
but does not gate PUSH/STOP on height. Bare WEAK STOP is permeable only if its
layer matches the mover's; across layers it remains STOP, including SAFE cases.
Spatial conditions and sentence reading are not contact consumers.

## Implementation

FLOAT is a projected behavior from positive/negative/conditional rules, using
binary equality with absent FLOAT treated as ground. All ordinary contact
victim phases share coordinate plus height matching. Movement unlock and WIN
use the same equality rule in the movement module, including legacy trait tests.
STOP/PUSH retain cross-layer operation. HAS and conversion products use their
own rule projection; FLOAT is not stored as permanent identity metadata.

This follows RuleWorld's existing per-phase projection contract. It does not
reproduce the original cached numeric FLOAT field's transient update timing
for conditional rules or freshly created products. Scoped LEVEL FLOAT contact
lifecycle and virtual EMPTY destruction remain outside this milestone. The
original special numeric heights >=2 are also not represented. SELECT, ON/NEAR,
text reading, CRASH and blocked-WEAK shattering are not filtered by FLOAT.

## Manual fixture

Root: D five times, W, D five times, F enters FLOAT.
Avatar IS FLOAT AND MELT; the Rock directly above is HOT and grounded.

* W overlaps the Rock without melting; Z restores the start.
* D is blocked by the grounded STOP Crate; Z restores facing.
* A pushes the grounded Flag left; Z restores its position and direction.

The FLOAT and NOT loose tiles allow changing height rules. NAT includes FLOAT;
the previously overlapping loose WEAK/ON tiles have been separated.

## Validation

`luatex --luaonly tests/run.lua`: both heights for every implemented contact,
STOP/PUSH, WEAK STOP, movement unlock, WIN/self WIN, conditional/negative FLOAT,
HAS projection, floating Text reading, native fixture F/input and whole-tree Undo.
`luatex --luaonly tests/reference_float.lua`: executes the installed original
`floating` predicate with real-unit and EMPTY lookup stubs.

Normal production startup still skips regression tests and stays under the
existing 2M instruction budget. Real-device acceptance is pending.
