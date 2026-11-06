# M9.3X OPEN / SHUT

Implemented ordinary real-object and Text OPEN/SHUT, including conditional and
negative grants, WRITE literals, SAFE, HAS and atomic Undo.

## Primary reference

Installed Baba Is You `Data/movement.lua`, `check` (~978) and `move` (~1512):
OPEN takes precedence when a mover has both properties. Complementary targets
ignore PUSH/STOP when either participant is unsafe. Other blockers still block.
Target deletion precedes mover deletion; an unsafe mover is consumed at its
source, a SAFE mover continues. Both SAFE means normal collision handling.

`Data/blocks.lua` (~1585): after DEFEAT, SHUT overlaps OPEN, including self;
SAFE protects each victim independently. The first OPEN identity per noun type
participates, and all noun types can participate before the deletion batch.
Identity order within a type is deterministic ID order in RuleWorld.

## Transactions

Movement produces ordered death records with immutable position/direction frames.
The scheduler applies movement then movement_destruction destruction/HAS before parsing
post-movement rules and conversion. Door HAS appears at the destination, key HAS
at its source. Conditional HAS sees the death frame and earlier HAS products.
Contact phases freeze declarations in order SINK, MELT, DEFEAT, unlock, then CRASH.
A single Commit/Undo includes every stage and allocator change. Planning failures
leave the original session untouched.

## Playable test

From root cursor: D five times, W, D three times, F enters LOCK.
Avatar IS YOU/OPEN faces a Rock IS SHUT AND STOP directly above. W consumes
both, creating FLAG at the door and CRATE at the avatar source. Z restores both,
including IDs/directions. Loose SAFE/NOT/AND allow editing immunity. F with the
cursor on the parent block returns normally. No hidden Flag WIN rule.
NAT also includes loose OPEN and SHUT.

## Validation and boundaries

`luatex --luaonly tests/run.lua` tests native F/W/Z, all SAFE combinations,
PUSH key chains, unrelated blockers, multiple doors, self contact, heterogeneous
OPEN types, conditional HAS, directions, rollback, NOT and WRITE vocabulary.
`luatex --luaonly tests/reference_open_shut.lua` executes the installed original
contact block with UI stubs to compare SAFE/self/multiplicity behavior.

Scoped LEVEL and virtual EMPTY OPEN/SHUT lifecycle, FLOAT layers, WEAK and more
advanced original movement-pass ordering remain deferred. This milestone does
not claim those semantics. Normal startup does not run regression tests; the
existing 2M instruction budget still applies. Real-device acceptance is pending.

## Ordinary contact declaration and tile order

The earlier milestone's scope notes are historical; later EMPTY/scoped lifecycle
work is documented separately. Current ordinary contact projection retains each
physical OPEN and SHUT declaration as transient source groups, with unit_order.
For each SHUT source, each OPEN clause independently selects its first same-FLOAT
matching key in cell_order (unit_order fallback). Same-name keys satisfying distinct
conditions must not collapse into one noun-level search. Both SAFE participants
still stop that clause's search; they do not cause a later key to be selected.

Unsafe doors are selected before their non-self unsafe keys, preserving first
encounter order for once-per-victim HAS allocation. Selection remains simultaneous:
already selected doors/keys can participate in other physical clauses. Self OPEN
and SHUT still selects its one unsafe identity. This update changes the ordinary
post-DEFEAT contact branch; movement unlock and scoped loops retain their existing
separate semantics. Raw capability-only diagnostic worlds retain the legacy path.

tests/reference_unlock_order.lua executes installed getunitswitheffect and the
OPEN/SHUT contact body in 16,384 cases, comparing first-encounter deletion order
across source/conditional-key groups, duplicates, unit/tile order and SAFE/FLOAT.
OPEN condition results are normalized per physical clause/identity in this oracle.
A physical FACING RIGHT/FACING UP test checks two same-name conditional keys,
door-first HAS identity/facing allocation and complete Undo. Native dense-list
pairs deletion traversal uses our explicit encounter-order convention. Routine
native acceptance is waived; these are offline/source checks.
