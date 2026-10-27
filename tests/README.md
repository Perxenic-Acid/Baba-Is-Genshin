# RuleWorld checks (M9.3I)

Run from the repository root with Lua 5.1+ (or TeX Live's Lua):

```
luatex --luaonly tests/run.lua
```

The runner executes the actual bootstrap self-tests, TEXT IS PUSH base-rule
check, AST/legacy parity check, and IS conversion/Undo check. Only native UI
rendering and key registration are mocked. It also exercises movement and
direction-only turns through the registered input callbacks.

All authored Object/Text instances start with intrinsic `direction = "None"`.
Valid values are `Left`, `Up`, `Right`, `Down`, `Mid`, and `None`; Up decreases
grid y. Successful movers and all successful PUSH dependencies face the input
direction. Blocked YOU instances turn; passive objects in a blocked PUSH chain
retain their direction. `Mid` and `None` are valid stored states, not movement
inputs. Rule projection and IS object conversion preserve intrinsic direction.

Movement operations include direction in `from`/`to`. Direction-only operations
use `kind = "direction"` and scalar `from`/`to`. Preview and Commit validate
directions, reject stale or competing writes, and Undo restores the complete
pre-turn state. Coordinate-only legacy movement plans remain supported.

In-game startup should report both new direction self-tests as passed and
`pipeline atomic turn scheduler`, `Atomic create/delete, ID allocation and Undo passed`,
`pipeline created/deleted Text rules / Undo`,
`pipeline alternate grammar/semantics behavior / Undo`,
`pipeline custom selectors/behaviors / atomic Undo`, and `M9.3M initialized`.
Native rendering/input still require an in-game check.

The runner also loads `tests/scheduler.lua`, which checks the extracted turn
planner using real modules: movement + intrinsic direction + IS conversion in
one Undo, failure at each planning stage, complete-plan rejection, invalid
actions, no-YOU empty turns, and separation of subplanner-owned operation lists.
No additional script mapping is needed for M9.3F.

M9.3G adds `tests/lifecycle.lua` and the in-world `RW_LifecycleSelfTest`.
They verify mixed create/delete/move/transform/direction plans, one-step Undo,
replay, operation order independence, nested payload isolation, ID allocation
and exhaustion, stale/invalid operation rejection, and created Text's ordinary
TEXT IS PUSH behavior. Startup also checks that created/deleted CRATE IS YOU
symbols activate/deactivate control through the real rule pipeline.
No additional script mapping is needed for M9.3G.

M9.3H adds verb and semantic registration self-tests and `tests/registration.lua`.
It checks all six subject/verb/object role orders with positive/negative terms,
canonical IR parity, physical source IDs, independently registered parse/semantic
capabilities, deferred fallback, and invalid/duplicate/cyclic configuration rejection.
Startup compares the actual default and alternate spatial language pipelines for
PUSH, multiple YOU, conversion and Undo. No new script mapping is needed.

M9.3I centralizes selector interpretation in rules.lua; EvaluateRules now emits
concrete entity_ids for projection. Raw external effects need RW_ResolveEffects
before RW_ProjectWorld. The new tests/selectors_behaviors.lua checks selector
coverage and isolated registries, capability mapping/retraction, explicit empty
registries, and invalid data rejection. Startup also exercises custom selectors
and behavior names through blocking, pushing, condition changes and atomic Undo.

M9.3J adds tests/levels.lua and RW_LevelInstanceSelfTest. It checks definition
ownership, independent runtime/configuration/ID allocation/history, real rule and
PUSH scheduling, Commit/Undo identity, invalid templates and empty levels.
In-game startup should additionally report Level definition/runtime instance
isolation passed. No new script mapping is needed.

M9.3K adds RW_LevelTreeSelfTest and tests/level_tree.lua. The runner also exercises
A/B/OUT through real host input callbacks: push, return, persistent re-entry,
independent siblings, and local/empty Undo. Native manual steps are documented in
../docs/NESTED_LEVELS.md. No additional mapping or keys are required.

M9.3L supersedes K's automatic portals and local-only Undo. tests/level_transactions.lua
covers SELECT authority independent of YOU, rule retraction, explicit confirmation,
parent/win/level-transform exits, whole-tree Undo/replay and rejection boundaries.
The bootstrap adds a real mapped-pipeline startup probe for all three exits.
Host tests use the registered KeyboardInteractKeyDown callback (F), as clarified
by the user. Physical Enter is not required. Updated manual F-key test sequences
cover parent return, win, level transformation and cross-level Undo.
See ../docs/NESTED_LEVELS.md for the updated scope and reference sources.

M9.3M adds tests/level_semantics.lua for identity-bound links through conversion,
Noun IS Level usability, WIN as a property on arbitrary objects/Text, ordered RHS
AND provenance, LEVEL WIN/DEFEAT ordering, conversion priority, and defeat-only Undo.
The mapped startup probe and F callback tests exercise all five terminal fixtures;
N checks configured versus unconfigured IDs. See ../docs/LEVEL_SEMANTICS.md for
manual test sequences. Native rendering tests also verify property-based WIN color.

## M9.3N

关卡边界重置、持久 LEVEL 转换/结果、LEVEL IS YOU 地图偏移、多目标选关 UI、
四条预设规则，以及 SELECT-only WIN 不退出/DEFEAT 允许 SELECT。
详见 docs/LEVEL_BOUNDARIES.md；离线新增 tests/level_boundaries.lua 与宿主/渲染回归。

## M9.3O

普通名词一对多转换：同格产物、目标去重、身份保护、原子 ID 分配/撤销。
详见 docs/CONVERSION_SPLIT.md，回归 tests/conversion_split.lua，真机入口 SPL。

## M9.3P

修正上一版按目标名词去重的错误：重复规则逐条生成，完整 AND 路径乘到所有项。
用户重叠示例为 24 条完整句子、48 个 Rock。tests/rule_multiplicity.lua 覆盖实际管线；
tests/reference_multiplicity.lua 可独立运行以对照本机原版源码。

## M9.3Q

`tests/stage_transactions.lua` 验证顺序阶段的生命周期、规则重求值、错误阶段、
晚失败回滚、分配器与单次 Undo；原有宿主移动/转换回归也通过阶段计划执行。
