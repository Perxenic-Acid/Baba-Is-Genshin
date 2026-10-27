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
`1level.l/.ld` (Where Do I Go?), with tile definitions from `Data/values.lua`.
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
* A Cursor/Line and parent link occupy the empty upper-left corner for navigation.
* Base Text Push/Cursor Select/Line Path/Level Stop remain; no hidden Avatar You,
  Rock Push, Wall Stop or Flag Win is added. Those rules must come from the tiles.

## Navigation and manual checks

Root cursor starts at (2,2): D ten times, F opens REF.
REF: D, F enters BIY; D twice, F enters WHERE. The cursor stays on the chosen
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
