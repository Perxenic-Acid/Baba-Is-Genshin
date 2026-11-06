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

Ordinary MORE source collection now preserves physical declaration groups and
saved unit_order instead of globally sorting sources by numeric ID. Installed
getunitswitheffect returns declarations in order, so different nouns with blocking
copies can compete for the same empty cell; the first physical source must win.
Repeated source entries are retained, but their earlier same-name copies block
additional products. Source lists remain frozen and newborns never join them.
The more_source_groups projection is transient; raw capability-only diagnostics
retain the legacy sorted fallback.

tests/reference_more_order.lua executes installed getunitswitheffect and MORE in
3,072 cases with permuted/duplicate source clauses, Object/Text, overlapping and
competing growth, STOP/PUSH/PULL and full product sequence comparisons. Conditions
are normalized to per-clause source identities; copied blocker capabilities use
the existing frozen-source convention, without claiming native dynamic condition
parity. A physical FLAG/ROCK MORE AND PUSH turn verifies contested-cell ownership,
allocation, facing and whole-turn Undo. Historical PULL/lifecycle scope notes above
are superseded by later subsystem work; frontend/native acceptance remains separate.

MORE now queries STOP/PUSH/PULL from frozen raw declarations at each current
obstacle, including initialized earlier copies and virtual EMPTY vacancies.
A tentative phase-local world includes each copy immediately, so spatial
conditions on old occupants can change as growth proceeds. Source MORE lists
remain frozen; copies do not join them. BROKEN/BACK initialization happens before
later obstacle queries. No projection cache or temporary identity is persisted.
The production adapter uses RW_PlanMorePhase; the capability-only resolver call
without services remains a diagnostic fallback.

Query limits commit only already completed products; birth initialization limits
also retain the triggering newborn, matching the existing creation-prefix rule.
Ordinary errors reject the whole turn. Tests cover conditional STOP/PUSH/PULL,
old blockers activated by growth, BROKEN newborns, prefix allocation and Undo.
The installed MORE body is executed in 96 ON/conditional-NOT, cardinal-axis and
source-order cases, comparing complete product sequences. Its host hasfeature
adapter supplies normalized spatial eligibility; native creation choreography and
full recursive condition timing are not claimed. This supersedes the inherited
newborn blocker convention noted above. Coordinate occupancy keys are canonical
for equal integer/float coordinates.
