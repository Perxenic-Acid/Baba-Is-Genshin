# RuleWorld checks (M9.3F)

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
`pipeline atomic turn scheduler` followed by `M9.3F initialized`.
Native rendering/input still require an in-game check.

The runner also loads `tests/scheduler.lua`, which checks the extracted turn
planner using real modules: movement + intrinsic direction + IS conversion in
one Undo, failure at each planning stage, complete-plan rejection, invalid
actions, no-YOU empty turns, and separation of subplanner-owned operation lists.
No additional script mapping is needed for M9.3F.
