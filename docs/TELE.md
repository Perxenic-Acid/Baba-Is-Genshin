# TELE (M9.6V)

Primary reference: installed Data/blocks.lua moveblock(), TELE loop 738-818;
tools.lua getname 1676-1685 folds physical Text into one text name. Sources are
collected once; each source processes co-occupants, excluding itself and its own
concrete name. A rider must share the source FLOAT layer and lack STILL. SLEEP,
STOP, PUSH, directional locks and destination FLOAT do not prevent teleportation.
Eligible destinations are other TELE identities with the same concrete source
name. All Text words share one network. Facing and identity metadata are preserved.

Each rider may teleport once per turn, including a rider that itself has TELE.
Sources and destinations can be moved by another network before their own pass;
process current positions immediately in physical unit-list order (authored ID
order when no explicit runtime order exists). Overlapping
same-name destinations remain separate random choices. A coincident destination
still consumes its random draw and the rider's one-teleport allowance.

The scheduler adds a TELE atomic stage after conversion/FOLLOW/FALL/MORE and before
contact-frame compilation. Contacts use arrival positions; transported Text may
change rules or trigger a terminal loop before destruction. The triggering TELE
stage and RNG state still commit and Undo restores the entire prior tree snapshot.
No per-entity transported flag is persisted. Empty/scoped map TELE is not simulated.
TELE's projected traits use the phase-start rule frame, as other movement solvers
do; native per-rider conditional STILL/FLOAT re-evaluation after earlier teleports
is a remaining intra-phase parity gap. RW_ResolveTele accepts BACK's transient
physical-ID suppression set; production BACK scheduling remains pending. The existing broader SHIFT timing boundary
is unchanged; this does not claim the entire native moveblock phase graph.

Destination selection uses the existing snapshot-owned Park-Miller random_state,
shared sequentially with MAKE, one draw per eligible rider even for one destination.
The native RNG stream differs deliberately; the source oracle normalizes its RNG
to verify choices and draw counts under the same supplied stream. Rejected plans,
rendering and repeated planning do not consume authoritative randomness.

The 12,288-case oracle executes the installed TELE loop with normalized host objects,
covering Text names, layers, STILL/SLEEP, one/two/three sources, overlapping networks,
mobile teleporters, reversed unit traversal, BACK suppression and RNG consumption.
Separate sequential BACK/TELE tests cover motion, direction-only and unchanged
updates, paradox, restored handles, shared logical IDs, atomic failure and Undo.
Marks suppress only transport of that physical rider, never the source's ability
to carry others. No marks enter worlds, entities or journals; subsequent turns
start unsuppressed. Suppressed riders consume no RNG. Retired BACK handles lose
their marks, so replacement products sharing a physical slot can teleport.
Production tests cover phase order,
collision bypass, denial, destination DEFEAT/HAS, deterministic replay/Undo and a
teleported word creating Infinite Loop. Routine native acceptance is waived; no
native success is inferred. MOTION is now 32x32 with a sparse loose TELE word.

2026-11-05: scoped LEVEL TELE is now implemented separately in the late ordered
map phase; see LEVEL_MOTION.md. It randomizes all same-layer real units, up to
three passes, drawing two coordinates for every unit before layer filtering.
It does not use the ordinary teleporter network or its BACK rider-suppression
set. Atomic RNG/motion journals, late code/status/CRASH/limit handling and Undo
are covered by7680 installed cases plus production scheduler/adapter tests.
Conditional intra-batch map-layer/declaration re-evaluation remains documented.

Ordinary TELE now snapshots riders from the current per-cell arrival list,
independently of global unit traversal. Successful relocations mutate that local
list before later sources are processed. Each actual relocation enters ordered
motion_history with map_update=true; final diagnostic changes remain in global
order. Preview/Commit therefore preserve destination arrival order rather than
reconstructing it from sorted summaries. Same-position teleports still consume
their draw and suppression mark without changing tile order.

The oracle executes installed findallhere/addunitmap/updateunitmap as well as the
TELE loop, independently reverses global and initial cell order, and compares RNG,
positions, the exact relocation journal and all final committed tile lists.
Existing mutable feature-condition query timing remains outside this tile-order fix.

Dynamic scoped map FLOAT is now rechecked per transported identity after preceding
relocations; see LEVEL_MOTION.md and tests/level_tele_layers.lua. The remaining
initial-trait-list declaration scheduling gap is distinct and remains deferred.

Scoped TELE now re-tests ordered motion/terminal declaration conditions after
preceding TELE updates, including initially inactive rows and current REVERSE
parity. Earlier skipped terminals are not revisited; see LEVEL_MOTION.md for
source oracles, transaction details and remaining non-motion LEVEL scheduling.
