# M9.3O：一对多名词转换

旧版 RW_PlanConversions 主动拒绝多个目标，返回 multiple_conversion_targets；
这是一项未实现的基础能力，并非关卡规则不允许。

现在同一个源对象对每条转换规则实例各产生一个产物，位置、六值朝向和已有关卡指向
从移动完成后的快照复制。首个目标沿用原 ID，其他产物按源 ID 顺序分配新 ID。
未绑定对象的 Level 产物仍不可用，不凭 Level 外形猜测目的地。
M9.3P 修订：每条规则实例独立产生一个产物，即使目标相同；不再按名词去重。
A IS A 继续保护 A；本回合产物不再级联转换。
创建、转换、移动及 ID 分配都进入同一个原子计划，Z 全部恢复，重做复用相同 ID。
ID 耗尽整步拒绝。

原版依据：本机 Baba Is You/Data/convert.lua 约 157–173 行首产物保留 ID，
其他产物 newid；约 330–378 行复制位置、朝向与 U_LEVELFILE/U_LEVELNAME。
本步仅扩展普通实体的名词转换；当前关卡作用域的多目标 LEVEL 转换另需持久结构支持。

真机：重新试玩后 D 四次、W、F 进入 SPL，再 W 组成 CRATE IS LEVEL AND ROCK。
两个箱子各变为同格 Level + Rock。Z 应恢复两个 Crate 和被推动的文字。
原有两条分开排列的 CRATE IS ROCK / CRATE IS LEVEL 也支持同样的转换。
SPL 中只有原本带目标的箱子及其派生产物带关卡指向，另一组 Level 不可进入。

最新真机日志 2026-10-27_11-10-25_66_513013168.gia 中 M9.3N 启动自测均通过；
观察到 multiple_conversion_targets 拒绝和一次 no_selected_level，未见 TEST FAILED。
新增 tests/conversion_split.lua 覆盖双句、AND、重复规则、保护、无回合内级联、
指向隔离、朝向、分配器耗尽和撤销/重做。离线通过不等于本步已真机验收。

## M9.3P：完整句子与重复次数

同格文字按物理 ID 组合，不按词面合并。完整的 RHS AND 句子先枚举所有路径，
每条路径再展开各 RHS 项。后续格的重叠也会乘到前面的 RHS 项；不能仅复制末项。
AST source.entity_ids 保留各项的前缀来源，sentence_entity_ids 记录完整路径。

用户示例：BOX / IS×3 / ROCK×2 / AND×2 / ROCK×2，完整路径有
3×2×2×2=24 条，每条含两个 ROCK，故每个 Box 产生 48 个 Rock，分配 47 个新 ID。
简单 BOX IS ROCK AND ROCK 产生两个；IS×3、ROCK×2 的三格句子产生六个。
对象转换和所有新 ID 仍在同一个原子回合中，Undo 全部恢复。

本机原版验证：tests/reference_multiplicity.lua 使用引擎边界替身，直接加载
原版 rules.lua 的 docode/calculatesentences 与 convert.lua 的 conversion；
前者输出 48 条规则，后者交给 convert 的产物表有 48 项。
原版 rules.lua 约 622–646 行只排除完全相同物理 ID 的重复句子，
约 818–857 行把完整句子的每个目标交给 addoption；convert.lua 逐项保留转换。
这个验证不依赖我们的解析器，也不包含复制的原版函数实现。
可在安装了原版的本机运行 `luatex --luaonly tests/reference_multiplicity.lua`。

tests/rule_multiplicity.lua 在项目实际读句/规划/提交管线上验证上述 6/2/48 个
产物及另一组 24 个产物，检查完整来源、同格朝向、ID 分配和撤销。
本步用户暂不真机测试，未将这些离线结果描述为真机验收。
