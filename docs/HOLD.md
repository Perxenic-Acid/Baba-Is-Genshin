# HOLD source contract (implementation pending)

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
