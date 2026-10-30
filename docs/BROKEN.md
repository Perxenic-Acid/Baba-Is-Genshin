# BROKEN status infrastructure (M9.5L)

Primary references: installed base Data/blocks.lua `brokenblock` (157-181),
Data/conditions.lua `testcond` (1-83), Data/rules.lua `codecheck` (858 onward)
and `findwordunits` (2426 onward), Data/undo.lua (388 onward).

BROKEN is a saved per-unit status. The original updates units sequentially,
clears only the current unit temporarily for its own BROKEN query, then saves
any change for Undo. Ordinary condition queries fail for broken units. Physical
Text still participates in codecheck; non-Text WORD units are separately filtered.
Do not implement BROKEN by simply removing physical Text from the reader.

This batch adds only the status transaction prerequisite. `RW_PlanBrokenStatus`
uses a caller-supplied rule query, copies unit records before querying and returns
stale-checked `broken` operations. Missing status means zero. Updates follow sorted
entity ID order, matching this engine's other ordered phases; native unit-list
order can differ. Queries see earlier updates and the current unit temporarily
cleared. Failed queries and rejected later stages leave the source world intact.

The production compiler/scheduler do not call this planner yet. BROKEN remains
pending in the official-word audit; there is no claim of gameplay support. Next:
connect status refresh to compilation/turn phases, apply it to unconditional and
conditional queries (including relations), preserve physical Text reading while
suppressing broken WORD, and cover acquisition/retraction/conditional timing,
conversion/HAS, terminal checks, navigation and whole-tree Undo. LEVEL and EMPTY
need their original synthetic query paths rather than real unit records.

Validation: tests/broken_status.lua executes the installed original brokenblock
in an isolated adapter and compares 256 ordered status cases, including mixed
Object/Text and dependencies on earlier/later units. Production transaction tests
cover nil-to-one, Preview purity, stale/invalid status, atomic late failure and Undo.
Native gameplay acceptance is not inferred from these tests.
