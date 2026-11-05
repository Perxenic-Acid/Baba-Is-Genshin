# Scoped LEVEL autonomous motion

Primary reference: installed `Data/blocks.lua` levelblock(), around2075 (capture
lstill/lsleep),3195–3346 (MOVE/CHILL/nudges/FALL); `Data/tools.lua` cantmove()
around2248 and reversecheck() around2469. `clears.lua`123 and `load.lua`79 set
the initial mapdir to Down. MOVE/nudges/FALL scroll the synthetic map; the separate
late TELE branch below displaces real units.

## Implemented

`RW_ResolveLevelMotion(world, traits, stop_index)` plans ordered MOVE, CHILL,
NUDGERIGHT/UP/LEFT/DOWN and FALL/FALLRIGHT/FALLUP/FALLLEFT from the surviving scoped
declarations. Duplicate declarations execute repeatedly. No unit coordinates,
identities, collisions, contacts or HAS products are changed by map scrolling.

- MOVE uses current map facing; REVERSE changes travel without changing facing.
- CHILL always draws/sets map facing, even when SLEEP or STILL prevents scrolling.
  CHILL does not apply REVERSE to its draw. A later MOVE sees the new facing.
- Nudges use their cardinal travel, apply REVERSE and retain map facing.
- FALL moves20 cells vertically or35 horizontally per declaration. SLEEP does
  not suppress it; REVERSE reverses its displacement.
- The original captures STILL/directional-lock status once using initial map
  facing (including cantmove's reversed lock lookup). A later CHILL draw does not
  change this status. LEVEL HOLD does not hold the synthetic map itself.
- Absent map state uses native Down lazily. The first actual scroll materializes
  that facing so the next turn continues in the same direction. Explicit None
  remains None; CHILL can supply a cardinal direction.

The scheduler adds `level_motion` after final contacts/code-status/orientation,
before the final tree outcome/boundary. It queries surviving scoped declarations
and projects current capabilities. The production adapter stops at the first
applicable ordered WIN/DEFEAT/END according to the existing outcome contract;
WIN without YOU does not stop scrolling. Capability queries still see the full
frame, including later STILL/REVERSE declarations. IS NOT and BROKEN gating use
RW_QueryLevelTraits. Prior compile-limit/CRASH terminal states and scoped level
conversion destruction skip this phase. Conversion-before-terminal priority is
unchanged; no previous contact/conversion phase reruns.

Offsets/facing use the existing stale-checked `board_shift`; CHILL uses a pure
random_state from/to journal. Park-Miller draws deliberately differ from the
original RNG sequence. Earlier automatic/MAKE/TELE draws feed this late phase.
An RNG-only turn still commits a stage. Preview is pure; late errors/stale
metadata reject atomically; local and whole-tree Undo restore input, random
state, offsets, facing, boundaries and allocators together.

## Verification and remaining limits

`tests/level_motion.lua` executes the installed motion branches, cantmove and
reversecheck unchanged with host scrolling/RNG callbacks isolated:6480 combinations
of facing, duplicate REVERSE, SLEEP, STILL/four locks, declaration sequences and
seeds. The oracle compares actual offsets/mapdir and draw order, not the native
undo-row facing fields (some MOVE/FALL rows record reversed travel as facing).

Compiler/scheduler tests cover physical rules, conditions, NOT/BROKEN, RNG-only
stages, terminal order, CRASH, stale metadata and late-error rollback. A tree WIN
boundary roundtrip verifies whole-tree Undo. Actual production OnStart/wait/Undo
adapters run with mapped-script and UI mocks. `tests/run.lua` includes this test;
real-device success is not inferred.

Remaining synthetic scope: ongoing cardinal orientation dispatch and verification
of FEAR/FOLLOW map-source behavior. Scoped TELE, startup cardinal assignment and
TURN/DETURN are implemented below.
Frontend rotation is deferred. This oracle does
not establish the complete native levelblock destruction/terminal interleaving:
our frozen contact phases remain grouped before late scrolling, and terminal
selection retains the user's established outcome semantics. Conditional scoped
surroundings retain their existing saved-surroundings/current-child query contract.
Exact native mutable unit scheduling and queued conversion/host boundary dispatch
remain shared gaps. No timer or native AUTO routing is added here.

## Ordered rotation and boundary initialization

Installed blocks.lua startblock() around1972–2000 resets rotation and applies
active RIGHT/UP/LEFT/DOWN declarations in order, with the last assignment winning.
It does not use the ordinary unit weighted-direction algorithm, nor SLEEP/STILL.
`RW_ResolveLevelStart` performs that initialization after the existing one-pass
status initialization on boot and reloaded boundaries. The production vocabulary
guard avoids an extra compile when no cardinal LEVEL declaration is possible;
it recognizes aliases, custom Level block types, WORD Level candidates and authored
scoped declarations. Actual eligibility still comes from compilation and
RW_QueryLevelTraits, including NOT/BROKEN and conditions. No input/RNG/local
history advances; the outer tree transaction owns boundary Undo. Compile-limit
boards retain the existing initialization terminal policy and are never recompiled.

TURN/DETURN join the ordered late motion loop using installed blocks.lua3348–3368
unchanged arithmetic. Both change facing and rotation despite SLEEP/STILL. Later
MOVE/CHILL sees their new facing; the initial still/lock decision stays frozen.
In particular, TURN computes its angle from the old facing, not the cardinal
angle associated with the new facing. Direction and angle must remain independent.

`board_offset.rotation` is an optional backend angle0/90/180/270; absent means0.
The existing stale-checked board_shift carries it atomically with offset/facing.
World/definition validation rejects unsupported angles. YOU scrolling preserves
the angle, and CHILL only changes facing. Rotation-only changes retain BACK
frames and phase journals; whole-tree/local Undo restores exact prior metadata.
The temporary renderer ignores the angle until the deferred frontend workstream.

The installed oracle now covers11340 motion/lock/turn cases and500 startblock
assignments, including duplicate/conflicting/inactive declarations and initial
angles. Tests additionally exercise startup guard/conditions/NOT/BROKEN, invalid
and stale rotation, RNG-only and rotation-only journals, BACK retention, actual
mapped OnStart/wait/Undo, enter/parent-return initialization and boundary Undo.

Ongoing cardinal assignment timing is deliberately unresolved: effects.lua's
domaprotation() defines the operation, but its rules.lua caller is commented out
in the installed source. No per-turn binding is invented from that definition;
native callback timing needs separate evidence. This does not block the explicit
startblock initialization or levelblock TURN/DETURN paths above.

## Late LEVEL TELE

Installed blocks.lua3178–3194 executes at most three eligible TELE clauses per
levelblock call. Unless the map's initially captured STILL/lock test is true,
each clause walks all real units in unit-list order. It draws X and Y before
calling tools.lua floating_level(), so mismatched-layer units consume draws too.
Eligible units update to an interior cell without collision, rider STILL/locks,
SLEEP, destination FLOAT or BACK transport-suppression checks. Map SLEEP does not
disable this branch. The cap counts an executed pass even with no eligible units.

This operation now shares RW_ResolveLevelMotion's ordered trait loop and RNG with
CHILL/turns/map scrolling. It preserves unit facing, links, logical identities and
map angle; TELE-only RNG does not materialize map facing. unit_order controls
physical traversal. A flat final move per identity is accompanied by every actual
intermediate update in motion_history, including a trip returning to its start.
Unchanged destinations issue no motion history, matching installed update().
RNG-only passes still commit, and BACK/journals retain zero-net actual motion.

After late transport the scheduler recompiles the surviving board, applies one
reading-related BROKEN code-status barrier and checks surviving real CRASH. A
WORD/complexity limit commits the triggering transport/RNG prefix into the existing
only-Undo terminal state; other errors reject the entire turn. Later outcome
queries use the new rules. Contact destruction, orientation and conversions do
not rerun after late code release. Earlier phases still use their frozen frames.

tests/reference_level_tele.lua executes the installed TELE/motion branches,
floating_level(), cantmove() and reversecheck() unchanged in7680 cases: zero to
five TELE declarations, layer patterns, map locks/sleep/reverse, alternate unit
order, Text/linked/shared-identity units and interleaved CHILL/turn/FALL/MOVE.
Host update stubs retain only changes, as independently inspected tools.lua299.
Scheduler tests cover Text recompilation, the shared scoped query, all-mismatched
RNG-only transport, late errors/limits/CRASH, code status, zero-net BACK history
and actual mapped boot/wait/Undo. Both tests run in run.lua.

The established phase capability snapshot is used for unit and map FLOAT inside
the batch. Native unit FLOAT is a stored status value, but floating_level()
re-tests scoped LEVEL FLOAT conditions after each earlier relocation. Exact
intra-batch conditional map-layer/remaining declaration re-evaluation is still a
shared scoped-query gap; this oracle isolates unconditional supplied status/layers.
Particles/sound and native callback timing remain deferred frontend/host work.

2026-11-05 dynamic-layer follow-up: each TELE coordinate draw is recorded in a
transient attempt tape. The rules module replays preceding eligible relocations
on a private position copy and rechecks raw scoped FLOAT/BROKEN declarations for
each unit, retaining the real unit's stored phase FLOAT. The movement module then
replays those decisions with the same pure RNG draws. Query limits commit the
completed prefix plus the triggering attempt's two draws, and stop later motion;
other errors reject atomically. Neither tape nor condition caches enter world/Undo.
This supersedes the intra-batch map-layer gap above. Remaining declaration
eligibility/terminal ordering after TELE still uses the initial late trait list;
that separate scoped scheduling gap remains. tests/level_tele_layers.lua compares
1280 changing-occupancy cases with installed WITHOUT/floating_level, including
repeated EMPTY quotas, negation, fixed unit layers, RNG prefixes and Undo.

Scoped-query terminal follow-up: compile-limit diagnostics from the last pre-motion
trait query and the post-TELE trait query now commit their completed turn prefix,
using TOO COMPLEX for rule_complexity_limit and INFINITE LOOP for WORD limits or
cycles. Pre-motion failure consumes no TELE/CHILL draws; post-TELE failure retains
all completed transport/RNG/history. Ordinary query errors still reject atomically.
The tests inject all three diagnostics at both barriers, check subsequent command
lockout and local Undo, and exercise whole-tree Commit/Undo after late transport.
This repairs error propagation only; the remaining ordered-declaration scheduling
gap above is unchanged. No extra startup compilation or native bindings are added.

2026-11-05 ordered TELE/motion declarations: when the raw frame contains LEVEL
TELE, retain positive motion and WIN/DEFEAT/END declarations in their original
order, including initially false conditions. Recheck each declaration at its
execution position against preceding TELE positions. Earlier skipped declarations
are not revisited. Motion uses captured phase-start SLEEP/STILL/lock status;
REVERSE parity is queried at each MOVE/nudge/FALL, matching native reversecheck.
TELE's three-pass cap counts executed eligible clauses, not inactive declarations.
A pure action prefix is replayed with initial capability counts and recorded
per-action REVERSE; per-unit map FLOAT is replayed as described above. No closures
cross mapped-script Invoke. Query limits retain the completed action prefix,
ordinary errors reject, and no attempt tape enters the committed world.

A transient level_motion_outcome records the ordered scoped terminal or false for
no terminal. Tree outcome selection uses it without re-testing earlier skipped
WIN/DEFEAT/END from the final board. Ordinary unit/Empty WIN contacts remain active;
scoped YOU+WIN cannot bypass this ordered result through the generic WIN fallback.
Conversions retain existing priority, contacts do not rerun, and saved state gains
no new field. Non-TELE frames retain the previous fast path.

Source: blocks.lua2471/2553 tests each raw row's conditions in the loop;
TELE3178 precedes MOVE3195 and CHILL, with no in-loop sentence recompile.
tests/level_motion_order.lua executes installed motion branches and WITHOUT /
reversecheck in1440 cases, comparing RNG, scrolling/rotation, per-unit ordered
motion history, final positions and Undo. Cases cover duplicate/inactive rows,
repeated EMPTY quotas/NOT, conditional REVERSE multiplicity, and conditional
SLEEP/STILL capture. Production scheduler tests cover physical and scoped YOU,
early/late conditional WIN, whole-tree Undo and a mapped OnStart/input/Undo route.
The intra-batch motion-declaration scheduling gap above is superseded for these
supported actions. Interleaving other native LEVEL effects (EAT/destruction/etc.)
with these actions remains part of the broader scoped-phase scheduling gap;
current contact/conversion scheduling and conditional synthetic surroundings are
unchanged. Real-unit stored capabilities and the existing synthetic outcome
contact projection remain phase snapshots; this does not claim complete original
levelblock() scheduling. Particles/host map rotation bindings remain deferred.

Incoming Noun/Text/Empty EAT LEVEL rows now share this ordered loop, even without
TELE. Eligible sources retire the map at their declaration position, using captured
map SAFE and ignoring source SAFE/FLOAT. Preserve any earlier motion/RNG and stop
later actions; skip post-motion code/CRASH on the doomed board. See EAT.md for the
installed global-branch oracle, compiler/native-adapter tests and outgoing gaps.

Outgoing LEVEL EAT now introduces flat destruction/HAS barriers in this ordered
loop. Prefix replay carries captured motion locks/SLEEP and TELE count across
barriers; per-unit phase FLOAT is retained for survivors and initialized for births.
The scheduler flattens these children into its existing transaction and rebuilds
code/status once afterward, without rerunning contacts. See EAT.md for native
selection/serial deletion references, 9216 source cases, budget and remaining gaps.

## Scoped LEVEL WEAK

Installed blocks.lua2724-2734 marks destroylevel for any real unit on the map's
FLOAT layer when captured map SAFE is false. A witness may be Text, SAFE or BROKEN;
virtual EMPTY alone is not a witness. floating_level (tools.lua1294+) queries raw
map FLOAT at the current ordered row, using stored real-unit FLOAT. The check is
not an ordinary overlap or a WEAK contact on a physical entrance.

Unlike incoming/outgoing EAT map retirement, this native branch does not return:
tools.lua1533 only sets the delayed destruction flag. Preserve subsequent map
motion, RNG and EAT/HAS stages before final no-HAS map erasure. A transient
level_pending_destroy flag carries this fact across motion chunks; the scheduler
consumes it after the entire ordered loop. Nothing is saved on world or Undo.
Compile-limit prefixes retain the existing only-Undo policy; ordinary errors
reject the complete transaction. Earlier terminal returns retain their order.

reference_level_weak.lua executes installed WEAK/floating_level in1024 cases,
plus late query failure prefixes. level_motion.lua covers SAFE/FLOAT, subsequent
motion and EAT/HAS/CHILL, allocator/no-HAS erasure, local Undo and actual mapped
OnStart/input/whole-tree Undo. These are offline checks. Other scoped destruction
actions and complete original levelblock scheduling remain pending.

## Scoped LEVEL MELT

Installed blocks.lua2757-2785 distinguishes real/scoped HOT from virtual EMPTY
HOT. Real HOT declarations query current source identities/conditions/BROKEN and
stored FLOAT; source SAFE does not protect the map. Scoped HOT can melt the map
itself. Captured map SAFE protects it. These paths set delayed destruction without
returning, retaining later motion, RNG and EAT/HAS before final no-HAS erasure.

EMPTY HOT instead uses findallfeature's declaration placeholder, not the number
of qualifying vacancies. It can trigger on a full board or a failed conditional
cell list; EMPTY FLOAT likewise uses declaration presence. With matching map
FLOAT and unsafe map, this path returns immediately, skipping the ordered suffix.
The projector now publishes transient empty_hot_declared beside the existing
FLOAT/YOU/WIN/END metadata. No virtual entities, saved flags or host RNG are added.
The shared pending flag is now named level_pending_destroy.

reference_level_melt.lua executes installed MELT, floating_level and
findallfeature in3072 cases, including full boards and conditional placeholders.
Production projection/turn/mapped-adapter tests cover SAFE/FLOAT, self-HOT,
EMPTY early return, before/after EAT witnesses, HAS/allocator, motion and Undo.
Native host boundary timing and complete original declaration-query dispatch order
remain shared scope limits. Other scoped destruction actions remain pending.

MELT HOT query-order follow-up: real hot-source queries now traverse maintained
world.unit_order, with sorted legacy IDs only as a fallback. Native findall uses
the target unit list, including replacement/reinsertion order. An installed
findall regression with one HOT declaration fails under pairs traversal and
passes after this change. Injected diagnostics verify the practical distinction:
an earlier ordinary condition error rejects preceding TELE atomically, whereas
an earlier WORD limit commits its RNG/motion prefix into Infinite Loop. Both
orders leave the source world untouched. This closes real-unit ordering within
one target declaration; cross-declaration and scoped-versus-real dispatch order
remain the documented broader limitation.

## Scoped LEVEL HOT

Installed blocks.lua2735-2756 freezes findfeature(MELT), then runs findall once
per declaration against current units. Snapshot that group's conditional MELT
membership before deletion. Each candidate's SAFE and map FLOAT are queried
immediately before its own delete; earlier serial HAS/deletions can change these
queries. Target SAFE protects it; map SAFE does not. Duplicate MELT declarations
can consume earlier groups' newborns, without recompiling physical Text.

The ordered LEVEL sequence adds a flat destruction/HAS stage per MELT declaration,
not per victim. RW_InitializeHasBirths accepts an internal level_hot eligibility
mode with stored unit layers, returning actual completed victims even on success.
Skipped victims do not consume inside() direction RNG. Keep source conditions,
unit_order, sequential newborn status, late failure prefixes and whole-tree Undo.
The existing 32-stage bound applies to declaration groups; a large ordinary group
does not spend one stage per victim. Existing native query-order/host boundaries
remain documented; this is not a full levelblock scheduling claim.

reference_level_hot.lua executes the installed HOT branch in3072 cases covering
repeated MELT/HAS, SAFE, FLOAT, survivors, newborn identities and allocation.
Production turn tests additionally cover serial SAFE births, frozen conditional
membership and mapped OnStart/input/whole-tree Undo.

HOT group isolation follow-up: after this MELT declaration's own condition passes,
query only matching denials; never aggregate other positive MELT declarations.
The ordinary property-query helper accepts an internal known-grant argument while
retaining its BROKEN/recursion guard and negative-condition checks. Installed
findall confirms that deleting the first group's units can leave a later failing
condition entirely unqueried. A regression reproduces premature WORD-limit
propagation before the fix; another requires exactly one own-condition query.
This does not close broader cross-declaration MELT source dispatch gaps above.

## Scoped LEVEL SINK

Installed blocks.lua2894-2931 first scans real units in list order. For each,
floating_level precedes both SAFE checks. Any matching-layer witness immediately
retires an unsafe map and returns, without querying that unit's SAFE or triggering
HAS. SAFE on the witness cannot protect the map; virtual EMPTY is not a witness.
With captured map SAFE, gather unsafe matching-layer identities before any
removal, then delete/HAS serially. Unlike HOT, later births cannot change the
current group's selected SAFE/layer results. Repeated SINK clauses select again.

RW_ResolveScopedSinkTargets feeds the existing flat ordered deletion/birth stages;
level_sink uses serial initialized HAS and frozen rules. Preserve prior motion,
RNG, links/status, late terminal prefixes, ordinary atomic errors and whole-tree
Undo. Native query dispatch and other scoped destruction gaps remain separate.
reference_level_sink.lua executes installed SINK/floating_level in8192 cases,
including Text/BROKEN, independent SAFE, FLOAT, return and noncanonical unit order.
Turn/mapped adapter tests cover immediate map retirement/no HAS, motion suffixes,
serial HAS after fixed SAFE selection, repeated clauses and whole-tree Undo.

## Scoped LEVEL BOOM

Installed blocks.lua2932-2968 uses the same simulation as scoped SINK: inspect
all real units, compare stored unit FLOAT with current map FLOAT, retire an unsafe
map immediately on any matching witness, otherwise gather unsafe targets before
serial HAS/deletion. This is whole-map behavior, independent of an ordinary
unit's multiplicity-scaled local blast radius. Each physical scoped BOOM clause
executes again and may select earlier HAS newborns. Native audiovisual differences
remain in the deferred frontend workstream.

RW_ResolveScopedAreaTargets shares that selection with SINK; the existing SINK
entry point remains a compatibility wrapper. Ordered stages/events retain BOOM's
own name/cause. The source matrix in reference_level_sink.lua now executes both
unchanged installed branches in16384 cases. Added production transaction tests
cover distant victims, no-HAS map retirement, skipped suffix RNG, repeated births,
map scrolling, distinct event causes and actual mapped-input/whole-tree Undo.
Ordinary BOOM radius/multiplicity is unchanged. Broader original levelblock and
native host boundary timing gaps remain as previously documented.

## Scoped OPEN/SHUT source contract (integration pending)

tests/reference_level_unlock.lua executes the installed blocks.lua2786-2893
branches directly in 2048 cases. This is a native contract oracle, not evidence
that scoped OPEN/SHUT is implemented. Ordinary real-unit unlocking is unchanged.

Each complementary property declaration runs findall in declaration order. The
branch queries each matching-layer target's SAFE even when the map is unsafe,
then immediately retires an unsafe map after that declaration's scan. A matching
scoped complementary LEVEL declaration can also retire the map, without a real
unit witness or FLOAT comparison. Neither path reaches queued target deletion.
On a safe map, all declaration groups collect before any serial delete/HAS;
duplicate declarations retain duplicate queued IDs. The EMPTY complementary
placeholder check follows these deletions and can immediately retire an unsafe
map. Integration must preserve these query/deletion barriers and cannot reuse
SINK's earlier map-destruction shortcut or HOT's per-group deletion timing.
