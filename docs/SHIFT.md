# M9.4B SHIFT and Chasm Automated Doors

## Original source

Installed `Data/movement.lua`, take 8 (~383-415), collects non-self, same-FLOAT
occupants of SHIFT objects after normal YOU movement. Each distinct source adds
a move; the first source sets direction. SHIFT state 0 (~535) updates facing
before collision resolution, including blocked riders. The existing push and
unlock/WEAK machinery executes displacement. Duplicate property rules do not
create extra physical SHIFT sources.

Installed `Data/blocks.lua`, `moveblock` (~818-849), also aligns remaining
co-occupants with each source's facing at final positions, without causing
another displacement. The installed original collector is executed directly by
`tests/reference_shift.lua` for multiplicity, FLOAT and self-exclusion checks.

## RuleWorld pipeline

YOU/SELECT movement -> movement destruction/HAS -> SHIFT -> SHIFT destruction/HAS
-> post-movement compile -> conversion -> MORE -> frozen SINK/WEAK/MELT/DEFEAT/unlock ->
CRASH and result processing. Rule declarations are retained for SHIFT, with
conditions re-evaluated for the post-YOU source snapshot.

RW_ResolveShift uses the ordinary movement solver on a private working world;
collected riders get each impulse even if previously pushed. Each impulse round
resolves against pre-update positions, then flushes queued updates: two PUSH Text
riders can converge on the same formerly empty cell without pushing each other. Returning movement
operations compares original/final states; deaths retain their actual source
frames and causes. The scheduler never flattens sequential child preconditions
into simultaneous operations. One Commit/Undo restores all moves, facing, deaths,
HAS births and allocator changes. HAS products from SHIFT get the same transient
WEAK newborn protection as other destruction products.

Wait is a consuming action that leaves YOU/SELECT stationary and runs SHIFT.
KeyboardJumpKeyDown binds it when the host exposes that enum (normally Space).
Missing optional jump events do not prevent startup; bumping an obstruction
still advances an ordinary movement turn. Both special undo-only terminal
states reject wait just like movement.

## Playable later map

Root D ten times, F -> REF; D three times, F -> AUTO (from initial hub cursor).
Source: official `163level.l/.ld`, Automated Doors in Chasm, referenced by
`182level.ld`; generated coordinates/directions/hash remain checked by
`python tools/import_baba_reference.py --check`.

Initial Avatar (15,15): D, W four times reaches (16,10), because the belt at
(16,11) carries the Avatar Up. Z restores (16,12), before entering the belt.
The two visible belts use arrow labels. The parent selector/portal is at the
lower-left, avoiding the upper-left authored rule tiles. Keep testing the actual
WORD/NOT rule puzzle; no hidden base Avatar YOU or Rock PUSH was added.

## Verification and current boundary

Full tests include SHIFT collection after YOU, leaving a belt, stacked/opposing
sources, duplicate grants, FLOAT, Text riders, blocked facing, PUSH, WEAK/HAS,
OPEN/SHUT HAS, wait, conditional/negative grants, rollback, terminal locks and
whole-tree Undo. Native tests traverse AUTO's first conveyor and check wait.

This milestone supports cardinal-direction real Object/Text sources and riders.
Scoped LEVEL SHIFT, virtual EMPTY SHIFT and Mid/None/random source direction
are not implemented. Other original movement passes (MOVE, PULL, STILL, SLEEP,
REVERSE etc.) remain unavailable, and are absent from AUTO's authored words.
Conditional capabilities are projected for the SHIFT snapshot; transient original
engine caches and HAS participation between multiple SHIFT impulses are not
fully reproduced. Death HAS is batched after SHIFT, as documented in the pipeline.

Normal startup still skips regressions and stays under the existing 2M offline
instruction budget. The more complex official puzzle has traversal coverage;
complete solution parity and real-device acceptance remain to be checked.
