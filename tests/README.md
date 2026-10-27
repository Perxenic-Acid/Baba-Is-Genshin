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
`pipeline custom selectors/behaviors / atomic Undo`, and `M9.3I initialized`.
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
