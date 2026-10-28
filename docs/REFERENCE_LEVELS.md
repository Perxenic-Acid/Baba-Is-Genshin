# M9.4A Text activation and official reference fixtures

## Text display

The original `Data/rules.lua`, `postrules` (~1353-1387), clears active state then
marks the physical Text IDs participating in parsed features. It does not require
objects matching the subject or spatial conditions to succeed.

RuleWorld derives `active_text_ids` from the final WORD fixed-point AST, including
full sentence provenance for AND chains. The display projection receives the set;
entities and committed worlds do not store it. Physical Text is bright gold when
in a complete sentence, dark brown otherwise. The Text palette takes precedence
over object WIN/DEFEAT colors. WORD objects retain their object palette. Breaking
and undoing rules refreshes colors. Terminal boards still render without parsing.

## Imported fixtures

Source: installed official `Data/Worlds/baba/0level.l/.ld` (Baba Is You) and
`1level.l/.ld` (Where Do I Go?), plus `163level.l/.ld` (Automated Doors, Chasm),
with tile definitions from `Data/values.lua`.
These are temporary engine test fixtures, not our authored level pack.

`tools/import_baba_reference.py` reads zlib MAIN tile grids and DATA direction
grids, resolves per-level tile-name overrides, and embeds a small Lua layout in
world.lua. There is no game-file dependency on normal startup. Each layout has a
source SHA256 comment. `python tools/import_baba_reference.py --check` verifies
embedded parity against the local originals. No original scripts/assets are bundled.

Adaptations:

* Baba/text_Baba maps to Avatar/text_Avatar.
* Decorative tile/grass and UI-control specials are omitted.
* The special EDGE border becomes the world boundary: dimensions shrink by two;
  original interior coordinate (x,y) becomes Lua (x,y). No playable rows/columns
  are cropped. Object/Text coordinates and authored directions are preserved.
* A Cursor/Line and parent link occupy an empty corner for navigation; Automated
  Doors uses the lower-left corner because its upper-left contains rule tiles.
* Base Text Push/Cursor Select/Line Path/Level Stop remain; no hidden Avatar You,
  Rock Push, Wall Stop or Flag Win is added. Those rules must come from the tiles.

## Navigation and manual checks

Root cursor starts at (2,2): D ten times, F opens REF.
REF: D, F enters BIY; D twice, F enters WHERE; D three times, F enters AUTO. The cursor stays on the chosen
portal after returning, so adjust the number of moves accordingly.

BIY: D eight times pushes through the Rock barrier, reaches Flag and wins.
WHERE: initially Flag/IS/WIN are dark, Avatar IS YOU and Wall IS STOP are bright.
A three times breaks Wall IS STOP; its three tiles become dark and walls become
passable. Z restores the rule, colors and obstruction. Reassemble Flag IS WIN
and reach Flag to test victory. Parent links still use SELECT + F.

The native regression completes both levels, including the WHERE rule assembly,
WIN return and Undo back into the previous world. Renderer tests check dim/bright
palette precedence, reuse after a rule changes, and large-board scaling/reset.
Compiler tests cover AND/NOT, false conditions, missing targets and isolated Text.

## Frontend size

Boards larger than 12 by 12 scale tiles/spacing proportionally into the existing
816-unit footprint. Fonts scale with the board (minimum 7). Small fixture sizes
and existing direction/board-scroll geometry remain unchanged. This temporary UI
can make the 33-wide reference board's words small; no gameplay coordinates change.

Run `luatex --luaonly tests/run.lua` for the full suite and startup budget check.
Normal start remains self-test-free; real-device acceptance is pending.

## Later reference: Automated Doors (M9.4B)

The official Chasm map (`182level.ld`) references `163level` as Automated Doors.
AUTO preserves the authored WORD/NOT/AND rules and directional belts. SHIFT is
implemented for this fixture; see SHIFT.md. The native regression checks initial
YOU/PUSH, belt SHIFT, entering the upper passage, wait and atomic Undo. It does
not claim an end-to-end proof of every solution to this more complex puzzle.

## Meta: Booby Trap (M9.4C)

`302level.l/.ld`, referenced by official Meta (`283level.ld`), is now TRAP at
(6,2) in REF. From initial root cursor: D ten times, F, D four times, F.
Authored nouns Ghost/Lava and special LEVEL/EMPTY/Text vocabulary are imported;
MORE was implemented for the loose growth rule. Source tile layers/directions
and SHA256 are checked by the existing generator. Parent link is in the empty
upper-left corner. Helpers do not overwrite authored units.

Initial Avatar (7,7): S seven times steps onto the Right belt and lands at (8,14).
Z restores (7,13). DDSSD from the authored start approaches Ghost, exercising
Avatar NEAR Ghost IS EMPTY; Z restores the converted Avatar. The regression
checks these routes, zero deferred initial rules and whole-tree Undo. This is
mechanics coverage, not a proof of full Meta progression/solution parity.

SHIFT now correctly queues concurrent arrivals: two Text/PUSH riders converging
on a shared empty destination form a stack. Tests push the whole resulting stack
and verify atomic Undo. The temporary frontend still subdivides each cell for
multiple identities, with short labels on narrow subdivisions.

Renderer performance: stable Color objects and per-control state skip unchanged
positions, sizes, visibility and paint values. Cell annotations are composed
before painting, avoiding clear/repaint churn for paths and portals. Native mock
counters require zero repeated position/size/font/visibility calls for identical
frames, and one position call when only one entity moves. Rule/turn computation
still runs; actual frame latency requires real-device measurement.
