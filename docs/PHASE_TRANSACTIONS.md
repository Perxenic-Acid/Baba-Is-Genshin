# M9.3Q：回合内顺序阶段事务

## 原因与边界

原版 movement.lua 约 925–930 行在移动完成后执行 code → conversion →
doupdate → code → moveblock。blocks.lua 的 block 分别处理接触性质，
handledels 约 1926–1948 行区分同时删除时的 handleinside 与实际 delete；
tools.lua 的 handleinside/delete 约 477/509 行、inside 约 998 行关联 HAS。
这说明后续阶段必须能读取前面产生的对象、名称和位置。

此前 RW_PlanTurn 把移动和转换摊平，所有前置条件都对最初世界校验。
对本回合新对象再移动/转换/删除无法成立；同一 ID 跨阶段再次写入也被当作重复操作。
新增顺序计划作为项目内核接口，不声称与原版完整阶段顺序等同。
本步仍只调度原有移动、转换两阶段；尚未实现 SINK/HAS 或销毁回调。

## 接口

```lua
local creation = RW_PlanCreate(world, specifications)
local created = RW_PreviewPlan(world, creation)
local removal = RW_PlanDelete(created, ids)
local plan, error, preview, phase = RW_PlanStages(world, {
    {name="create", plan=creation},
    {name="remove", plan=removal}
})
local next_session, result = RW_Commit(session, plan)
```

每个子计划是已有 flat Plan，前置条件相对于该阶段开始时的世界。
RW_PlanStages 深拷贝输入并返回最终私有预览；不提交、不写历史。
Preview 和 Commit 共用同一条顺序校验/应用路径，Commit 重新检查所有阶段。
任意阶段失败整步拒绝；错误保留 phase 名称，原 session、ID 分配器和历史不变。
成功只记录一个世界快照；Undo 恢复整回合之前的状态。

顶层 changes 是按阶段拼接的诊断摘要，必须与 stages 完全一致；不得当作
flat Plan 直接应用。顶层不接受 id_allocation/board_shift；它们属于各自阶段。
摘要兼容已有日志和上层树计划的变化记录。Commit 结果附带 stages。
阶段名必须非空且不重复；只允许一层、1–32 个阶段，防止递归/循环计划。
有效空阶段允许存在；完全空回合继续保留一帧历史，changed=false。

创建后删除仍推进分配器；同回合再创建不得复用已删 ID。Undo 恢复分配器，
重放恢复相同 ID。单阶段内仍保持同时操作、删除终结、重复写入拒绝的原有契约。
规则重求值保持显式：读取阶段预览并调用 Reader/Parser/Evaluate/Project，
阶段事务本身不解释语法，也不隐式循环至不动点。

## 验证

现有 bootstrap 移动/转换改走两个阶段，操作、方向、多产物和跨层 Undo 回归通过。
启动新增 RW_StageTransactionSelfTest。tests/stage_transactions.lua 覆盖：
新对象修改与删除、连续分配、删除后创建、同 ID 跨阶段转换、规则生成/撤回、
晚阶段失败回滚、输入隔离、非法嵌套/重复名称/摘要、单次 Undo 和重放。
本步未改变测试地图及预期玩法；不要求额外手动路线。

## M9.7A：运动阶段的有序历史

可选 `motion_history` 是阶段拥有的运动路径，补充最终同时操作摘要。
每项为物理 ID 与完整 `from/to` 位置、方向；允许相等更新和中间往返。
只允许运动/方向摘要，逐项验证前置状态，并核对全路径终点与摘要一致。
不可放在带 stages 的顶层，不引入嵌套阶段，也不改变实体/world 事实。
Commit 日志复制路径；BACK 优先读取路径而非重复读取摘要。仅相等的记录
不使 BACK 保留新帧；`retain=false` 表示原作直接赋值但不设置 updateundo
的对齐记录，即使改变方向也不单独保留。其他中间实际运动/转向即使最终
抵消仍保留，不能再用最终摘要覆盖记录的保留标志。用户 Undo
继续恢复整次命令，晚阶段失败不得留下历史、随机数或状态更新。
