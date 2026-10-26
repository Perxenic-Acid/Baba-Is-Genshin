# M9.3G：实体生命周期与原子操作

本轮提供世界内核接口，不新增 MAKE/HAS/消除等词汇，也不改变实际关卡布局。
继续使用已有 world/bootstrap 脚本映射。

## 权威状态与 ID

`world.next_entity_id` 是快照的一部分，必须为大于所有已有实体 ID 的正整数。
当前初始实体为 1–11，初始 frontier 为 12。创建批次按输入规格列表顺序分配
连续 ID；删除不降低 frontier。Undo 恢复世界和 frontier，因此 Undo 后重放
同一创建计划会得到相同 ID。跨关卡身份域留待关卡实例规格另行定义。

ID 限制在 1–9007199254740991 的精确整数范围内。一次创建还必须能够表示
创建完成后的 frontier，耗尽时拒绝计划，不分配近似或重复 ID。

## 计划构造接口

```lua
local create_plan, error = RW_PlanCreate(world, {
    {kind = "object", class = "text", x = 2, y = 3,
        direction = "None", text = {name = "CRATE"}},
    {kind = "object", class = "object", archetype = "crate",
        x = 2, y = 3, direction = "Mid"}
})

local delete_plan, error = RW_PlanDelete(world, {6, 4})
```

两者均返回完整 Plan，不修改 world，也不提交历史。输入必须为连续列表。
空批次返回有效空回合计划。删除 ID 列表会排序，重复或未知 ID 会报错。
创建规格不允许指定 ID，且必须明确提供 kind、class、方向及棋盘内整数坐标；
同格重叠合法。Object archetype 可省略；若提供须为非空字符串。Text.name
须为非空字符串，Text 不同时携带 archetype。traits 和旧 symbol 字段不合法；
规则派生行为继续通过投影获得。

```lua
-- 创建操作
{kind = "create", entity_id = 12, to = complete_entity}
-- 整个创建批次对应的 Plan 元数据
plan.id_allocation = {from = 12, to = 14}
-- 删除操作，from 是原世界中的完整实体快照
{kind = "delete", entity_id = 6, from = complete_original_entity}
```

创建无 from，删除无 to。构造器复制嵌套实体数据，Preview/Commit 再复制
进入新世界的数据，防止外部修改创建载荷污染已提交的世界。

## 混合计划与冲突

- 所有操作的 from 都针对同一个原世界校验。删除比较完整实体记录，包括
  Text.name、方向及其他已有状态；不能只凭 ID 删除已变化的实体。
- 已有实体允许移动、转换或转向后最终删除；删除在应用阶段统一最后执行，
  不由操作列表先后顺序决定结果。同一实体重复删除拒绝。
- 对于被删除的实体，其他操作仍须合法；删除不能掩盖失效移动或转换。
- 新实体由 create.to 完整定义，同一步不再移动、转换、转向或删除它。
- 不能通过“删旧建同 ID”替换身份。创建只能使用本次 frontier 起的连续 ID。
- 合并创建批次和其他计划时，复制其 changes，并保留一次完整的
  id_allocation。多个生成源应先汇总规格，再统一分配，不能各自独立分配
  同一 frontier 的 ID。已有回合调度器目前没有自动生成/消除阶段。
- 移动、转换、方向已有冲突规则保持不变。任何非法操作、失效快照、重复
  写入或 ID 分配冲突，都会令完整 Preview/Commit 失败，世界与历史不变。

Preview 与 Commit 共用 apply_plan；一次混合计划只产生一个历史项。Undo
同时恢复创建/删除、位置、类型、方向及 ID frontier。

## 验证

游戏启动自测包含 `Atomic create/delete, ID allocation and Undo passed`，
以及 `pipeline created/deleted Text rules / Undo`。离线 `tests/run.lua` 另覆盖
无效创建、重复/失效删除、分配冲突、耗尽、载荷隔离和新 Text 的默认 PUSH。
本轮不代表后续跨层原子操作、进度持久化或完整阶段扩展接口已经完成。
