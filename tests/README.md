# M9.3E checks

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
`M9.3E initialized`. Native rendering/input still require an in-game check.
