# M9.3I：统一选择器与行为能力注册

## 查询与具体效果的边界

rules.lua 中的选择器实现同时用于条件查询和效果目标；properties.lua 不再
保存一套独立的 class/archetype/id 匹配逻辑。

```lua
local selectors = RW_RegisterSelector(RW_GetSelectorRegistry(), "named", {
    mode = "field", path = {"text", "name"}, value_type = "string"
})
world.selectors = selectors
local ids = RW_SelectEntities(world, {kind = "named", value = "IS"})
```

默认支持 id、archetype 和 Object/Text 的 class 选择。field 模式沿非空字符串
路径读取实体字段；字段不存在时不匹配，value_type 为 string 或 integer。
object_class 模式保留 Text 属于 Object 的类关系。返回 ID 按数值排序。
条件 overlap 仍要求两个不同实体；同一实体不能与自己满足重叠条件。

Get 返回副本；Register 返回新表，拒绝重复名称、非法配置和回调字段。
world.selectors 省略时使用默认注册表；显式提供的注册表完全替换默认项，
因此通常应从默认副本扩展。选择器不是新词汇，也不改变 Reader 的空间规则。

```lua
local effects = RW_EvaluateRules(world, generated_rules)
-- 或外部 IR 生产者先单独解析目标：
local effects = RW_ResolveEffects(world, raw_effects)
local projected = RW_ProjectWorld(world, effects)
```

EvaluateRules 现在返回已解析的具体效果，保留 target 用于来源追踪，增加
entity_ids。ResolveEffects 不信任输入已有的 entity_ids，按目标重新求值。
具体效果是对应当前世界的临时求值结果，不写回 rule_sources，也不可跨世界
变化继续复用；移动后必须按新世界重新求值。

**接口迁移：**直接给 ProjectWorld 传原始 target 选择器的外部调用，需要先
调用 ResolveEffects；缺少 entity_ids 会返回 unresolved_effect。现有宿主已
通过 EvaluateRules 获取具体效果。ProjectWorld 验证全部 ID 存在且无重复后
才投影，不接受未知实体目标或非连续列表。

## 行为属性与移动能力分开

```lua
local behaviors = RW_RegisterBehavior({}, "drive", {control = true})
behaviors = RW_RegisterBehavior(behaviors, "shove", {push = true})
behaviors = RW_RegisterBehavior(behaviors, "solid", {block_entry = true})
world.behavior_registry = behaviors
```

默认映射 you→control、pushable→push、block_entry→block_entry。一个属性可
授予多个能力，多条生效规则的能力取并集。未注册属性仍可成为派生 traits，
但不凭空获得移动行为；显式空表禁用所有默认映射。

投影实体的 traits 和 behaviors 都是派生数据，每次投影重新构造，支持效果
撤回。movement 优先读取 behaviors，继续使用原有的多控制者、推动优先于
阻挡、方向更新和原子计划策略。它不需要识别 drive/shove 等属性名称。
旧的默认原始 traits 测试夹具保留兼容路径；存在自定义 behavior_registry 时
不会通过这个路径恢复默认能力，实际宿主始终先做投影。

权威实体不保存这些派生能力，创建规格也不允许夹带 behaviors。Commit
仍只应用已校验的状态操作，Undo 恢复位置、方向、类型与生命周期状态。
本轮只注册已实现的三种移动能力，不支持任意插件回调或新行为执行器。

## 验证与范围

启动自测覆盖共享查询、选择器隔离及行为映射；管线自测使用自定义字段选择
和 Text.name 条件驱动 drive/shove/solid，验证阻挡转向、移除障碍、PUSH 链、
条件失效撤回控制、权威状态不泄漏派生能力，以及原子 Undo。
tests/selectors_behaviors.lua 另覆盖默认选择器、缺失字段、无匹配集合、未知
属性、显式空注册表、非法/重复目标、配置隔离和失效条件中的非法效果拒绝。

无新增脚本映射。本轮没有增加关卡内容、嵌套世界、持久化进度或跨层操作；
下一阶段是关卡定义与运行实例的分离规格及最小闭环。
