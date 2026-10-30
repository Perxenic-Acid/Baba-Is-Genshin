# HOLD (M9.5I)

Installed primary reference: Data/blocks.lua 1259-1327, immediately before SINK.
First enumerate current HOLD sources and assign same-cell, same-FLOAT non-self
units their holder identity; later sources overwrite earlier assignments. Then
process held units in native unit order: if the holder remains a HOLD source,
move directly to its current position preserving rider direction, bypassing normal
collision. cantmove still applies to the displacement direction (including its
non-cardinal sentinel). A blocked rider releases instead of moving. FLOAT mismatch
is checked after moving and releases the rider. A missing/inactive holder releases.
Neither SLEEP nor differing source/rider names prevents acquisition.

The installed-loop oracle tests 16 acquisition/missing-holder/blocked/layer/facing
cases. Production implementation remains pending: add validated holder identity
metadata and stale-checked operations, scheduled pre-SINK motion with rule refresh,
and whole-tree Undo, identity-preserving conversions and deletion/release tests.
Do not substitute a transient overlap-only displacement: holding persists across
turns after the holder leaves the rider's old cell. Resolve native unit-order
cycles without recursively traversing the holder graph.

Production HOLD is now scheduled after TELE before frozen contact compilation.
Entity holder metadata and stale-checked holder operations participate in ordinary
Plan/Preview/Commit and whole-tree Undo. Sources/riders use ascending identity order
as the deterministic replacement for native unit order; cycles are processed once,
not recursively. STILL and directional locks release riders, REVERSE maps lock
queries, and direction/identity survive transport. Conditional capabilities use the
phase-start projection; native dynamic per-rider condition re-evaluation remains a
gap as for TELE. EMPTY and scoped LEVEL HOLD remain deferred. Conversion-created
copies currently follow existing product metadata rules; full native holder-copy
parity is not claimed. The earlier pending implementation paragraph is historical.

The 16-case installed-loop test now compares production solver outcomes too.
Production tests cover persistent acquisition/following, deletion/release, stale
holder rejection, facing and Undo. Startup clone scalar-call optimization preserves
table-key/cycle cloning and reduces normal startup to about 1.86M instructions.

Further source audit: tools.lua cantmove 2248-2286 also checks scoped LEVEL HOLD
before STILL/locks. That global movement restriction is not yet implemented and
must be integrated across active/passive motion, rather than only the HOLD solver.
convert.lua 330-390 creates replacement units and copies selected metadata without
explicit holder propagation; our identity-preserving first product and cloned extra
products therefore need a dedicated conversion policy/parity pass. Do not infer
native holder inheritance merely from ordinary ID/link preservation.

The installed-loop comparison now covers 272 cases: 256 additional source-order,
mobile-holder/cycle, FLOAT, STILL, directional-lock and REVERSE combinations match
production positions and holder metadata. This is stronger ordinary solver evidence,
not completion of the scoped/conversion/dynamic-condition gaps above.
