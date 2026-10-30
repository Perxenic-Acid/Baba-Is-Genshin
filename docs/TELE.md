# TELE (M9.5F)

Primary reference: installed Data/blocks.lua moveblock(), TELE loop 738-818;
tools.lua getname 1676-1685 folds physical Text into one text name. Sources are
collected once; each source processes co-occupants, excluding itself and its own
concrete name. A rider must share the source FLOAT layer and lack STILL. SLEEP,
STOP, PUSH, directional locks and destination FLOAT do not prevent teleportation.
Eligible destinations are other TELE identities with the same concrete source
name. All Text words share one network. Facing and identity metadata are preserved.

Each rider may teleport once per turn, including a rider that itself has TELE.
Sources and destinations can be moved by another network before their own pass;
process current positions immediately in stable identity order. Overlapping
same-name destinations remain separate random choices. A coincident destination
still consumes its random draw and the rider's one-teleport allowance.

The scheduler adds a TELE atomic stage after conversion/FOLLOW/FALL/MORE and before
contact-frame compilation. Contacts use arrival positions; transported Text may
change rules or trigger a terminal loop before destruction. The triggering TELE
stage and RNG state still commit and Undo restores the entire prior tree snapshot.
No per-entity transported flag is persisted. Empty/scoped map TELE is not simulated.
TELE's projected traits use the phase-start rule frame, as other movement solvers
do; native per-rider conditional STILL/FLOAT re-evaluation after earlier teleports
is a remaining intra-phase parity gap. BACK's native tele-suppression tag will need
integration when BACK is implemented. The existing broader SHIFT timing boundary
is unchanged; this does not claim the entire native moveblock phase graph.

Destination selection uses the existing snapshot-owned Park-Miller random_state,
shared sequentially with MAKE, one draw per eligible rider even for one destination.
The native RNG stream differs deliberately; the source oracle normalizes its RNG
to verify choices and draw counts under the same supplied stream. Rejected plans,
rendering and repeated planning do not consume authoritative randomness.

The 768-case oracle executes the installed TELE loop with normalized host objects,
covering Text names, layers, STILL/SLEEP, one/two/three sources, overlapping networks,
mobile teleporters and RNG consumption. Production tests cover phase order,
collision bypass, denial, destination DEFEAT/HAS, deterministic replay/Undo and a
teleported word creating Infinite Loop. Routine native acceptance is waived; no
native success is inferred. MOTION is now 32x32 with a sparse loose TELE word.
