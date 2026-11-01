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

## M9.7A history update

The earlier milestone boundary above is historical; subsequent motion words are
tracked in MOTION_WORDS.md. SHIFT now follows authoritative unit-list order and
emits ordered phase-owned motion_history in addition to its atomic final changes.
Final alignment records every awake same-layer surviving co-occupant, including
equal facing and intermediate stacked-source facing. These direct native
addundo/assignment rows use retain=false: even changed alignment does not alone
set updateundo. Ordinary impulse updates retain their motion history semantics.
BACK replays the path once, including equal-update TELE suppression; no transient
marks/history are stored on entities. See BACK.md M9.7A and shift_history.lua for
384 installed alignment oracle cases, 32 inverse-path cases and scheduler/Undo
coverage. Native intra-impulse death/HAS and conditional-cache differences remain.

## M9.7F: effective SHIFT dispatch invalidates reading

Installed tools.lua update()/updatedir() sets updatecode on effective physical
Text updates. blocks.lua moveblock() final SHIFT alignment instead calls addundo
and assigns DIR directly, without setting updatecode. A blocked impulse can turn
a Text and final alignment can restore its starting facing; the empty final Text
summary must not erase the earlier invalidation.

The movement code-status barrier additionally observes validated effective
motion_history rows from the pre-conversion motion phases. SHIFT's direct
alignment rows (retain=false) do not independently trigger this new path. The
flag is transient plan-local data; intermediate boards are not recompiled, and
the existing single status pass remains before conversions and frozen contacts.
Tests use actual SHIFT resolution with a sleeping left-facing source, an awake
right-facing source and a STOP wall, plus TEXT ON AVATAR IS BROKEN. They cover
cancelled Text facing, one status barrier, whole-turn Undo and no refresh from
pure equal-facing alignment, both compile-limit terminal prefixes, atomic late
failure and malformed history rejection before inspection. Existing final-summary and conservative WORD
invalidation behavior remains unchanged; this does not claim exact native
intra-phase code timing or WORD dependency parity.

## M9.7G: exclude direct alignment from final-summary invalidation

M9.7F covered cancelled dispatch paths but still passed the flattened movement
summary to reading_changed. A changed direct SHIFT alignment therefore acquired
an unintended Text code-status refresh, although installed blocks.lua only
records Undo and assigns DIR. Its updatecode flag stays unchanged.

Movement invalidation now accumulates events against each phase's source snapshot.
The initial movement/destruction prefix and later destruction products retain
their ordinary detection. For journaled motion identities, effective dispatch
rows decide invalidation; their final commit summary cannot count a second time.
Unjournaled changes keep their existing dispatch contract. This is transient
scheduler data and neither changes the stored history nor replays contacts.

A real compiler/SHIFT regression begins with a STILL physical Text facing Up,
an awake right-facing source and TEXT ON AVATAR IS BROKEN. Avatar moves onto
Text; pure alignment turns it Right but leaves its saved BROKEN status latched.
The previous implementation incorrectly refreshed it. Undo restores the original
facing/status. A service without a motion journal retains its normal direction
write/refresh behavior. All 384 installed alignment oracle cases additionally
assert that original code leaves updatecode at zero. Earlier M9.7F effective
blocked-dispatch tests remain active. Exact WORD dependency and native phase
ordering gaps remain documented separately.
