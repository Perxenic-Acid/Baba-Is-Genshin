# M9.3O：一对多名词转换

旧版 RW_PlanConversions 主动拒绝多个目标，返回 multiple_conversion_targets；
这是一项未实现的基础能力，并非关卡规则不允许。

现在同一个源对象对所有不同目标各产生一个产物，位置、六值朝向和已有关卡指向
从移动完成后的快照复制。首个目标沿用原 ID，其他目标按源 ID 顺序分配新 ID。
未绑定对象的 Level 产物仍不可用，不凭 Level 外形猜测目的地。
规则目标按首次出现顺序去重；A IS A 继续保护 A；本回合产物不再级联转换。
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
新增 tests/conversion_split.lua 覆盖双句、AND、去重、保护、无回合内级联、
指向隔离、朝向、分配器耗尽和撤销/重做。离线通过不等于本步已真机验收。
