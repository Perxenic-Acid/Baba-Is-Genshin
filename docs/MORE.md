# M9.4C MORE

Primary source: installed `Data/blocks.lua`, MORE block (~1174-1240). Sources are
collected once. For each, directions are Right/Up/Left/Down. EDGE, STOP, PUSH,
PULL, and the same concrete UNITNAME block a destination. FLOAT is not consulted.
A new copy is inserted immediately, so it blocks later sources; it does not join
this phase's source list. An inert different noun may be overlapped. Text uses
its specific text token name for equality, not the generic Text class.

RuleWorld implements real Object/Text copying, including direction, explicit Text
token and identity-bound level links. Neighbor occupancy includes planned copies;
EMPTY STOP/PUSH also blocks a cell with no real occupant. Copies allocate through
RW_PlanCreate in one MORE stage after conversion and before contact compilation.
New Text can therefore affect the contact rule frame. Copies get current-turn
WEAK newborn grace. MORE is not destruction and does not trigger HAS.

Existing per-identity conditions and NOT grants select sources. Duplicate MORE
property rules do not multiply a physical source. Contact rules are compiled
again if births changed the board; if no copies were made, the already compiled
rule frame is reused to avoid an additional compilation.

Tests: `luatex --luaonly tests/run.lua`; source oracle:
`luatex --luaonly tests/reference_more.lua`. Cases cover cardinal order, borders,
blocking across FLOAT, inert overlaps, same-noun/newborn occupancy, no recursive
expansion, conditional/negative grants, metadata/Text/facing, EMPTY blockers,
WEAK grace, allocation, late failure and whole-turn Undo. The oracle executes
original MORE code with live occupancy/copy stubs.

MORE is available as a loose word in the imported Meta Booby Trap fixture (TRAP).
The scope excludes virtual EMPTY/scoped LEVEL growth, PULL capability (not yet
implemented) and original transient cached FLOAT/condition timing. In this phase,
blocking capabilities use the projected snapshot; copied obstacles retain source
blocking capabilities until the next projection. Same-name occupancy is immediate.
Player-created growth may become very expensive; normal authored startup still
performs no regression tests and remains under the 2M instruction budget.
Real-device acceptance is pending.
