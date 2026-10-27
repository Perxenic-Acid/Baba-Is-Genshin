# M9.3R：DEFEAT、SINK、HAS

## 本机原版依据

`C:\Program Files (x86)\Steam\steamapps\common\Baba Is You\Data`：

- blocks.lua 约 1327–1390 行：SINK 与不同 ID 的同格对象作用，单体不自沉，
  标记被销毁者并调用 handledels。约 1530–1590 行：DEFEAT 查找 YOU，
  排除自身 ID，再删除接触者。SELECT 不属于 YOU。
- features.lua 的 getunitswitheffect（约 319 行）会查找当前还存在的对象，
  因而较早删除阶段的 HAS 产物可以参加后续效果。
- tools.lua 的 handleinside/delete（约 477–560 行）在销毁时处理内容物；
  inside（约 975–1030 行）逐条扫描 HAS，不按目标词去重，复制位置、方向和
  关卡元数据。HAS TEXT 产生容器名词的文字。
- 接触处理沿用 code() 已编译的规则；blocks.lua 在这些效果之间不调用 code。
  转换由 convert.lua 单独处理，普通转换不是触发 HAS 的销毁。

## 当前契约

**普通 DEFEAT**：有 control/YOU 的实体与另一个有 defeat 的实体同格时，
销毁该 YOU；危险物不因此消失。单体 YOU+DEFEAT 不自毁。
SELECT 不受 DEFEAT 影响，但同时有 YOU 的 SELECT 仍是 YOU。
最后一个 YOU 消失不写入 LEVEL DEFEAT 结果、不锁住选择器；Z 可恢复。
原有 LEVEL IS DEFEAT 的当前关卡失败协议仍独立保留。

**普通 SINK**：与至少一个不同 ID 实体同格时，销毁自身及同格参与对象；
对象可为 Text。孤立 SINK 不自毁。按稳定实体 ID 遍历和记录受害者，
同一批删除同一 ID 只执行一次。SINK 阶段先于 DEFEAT 阶段。

**HAS**：普通名词、Level 外形对象或 Text 类可作为容器；正向名词、Level
或 TEXT 可作为内容物。支持独立重复规则及 RHS AND/重叠文字的完整组合次数。
每次实际销毁按照该容器匹配的每条 HAS 规则各生成一个新 ID。
HAS 自身不转换容器，IS 转换也不触发内容物。HAS 自身同名名词可以替换容器，
没有自动递归销毁；HAS 不是 A IS A 的转换保护。

内容物复制销毁时的位置与六值内蕴方向；Object 产物复制已有关卡指向，
没有指向的 HAS LEVEL 产物仍不可进入。派生属性/行为不复制，由规则重新投影。
HAS TEXT 选当前词典里与容器类型对应的名词（多别名时按名称排序），Text
容器的对应词为 TEXT。仍保持 Mid/None 两个本项目内蕴值，不在此步引入随机朝向。

本步只实现这些词的普通实体语义；SAFE、FLOAT、WEAK、EMPTY/ALL/NOT 条件、
当前关卡作用域 SINK/HAS、销毁动画等未实现，不把已有 deferred 视为执行。
后续词引入时按原版添加对应过滤与时序，不能靠未注册的 trait 名称猜行为。

## 管线与原子性

移动 → 转换 → 编译接触规则帧 → SINK 删除/出生 → DEFEAT 删除/出生 → 胜负检测。
接触帧保存已编译 Rule IR 与 HAS 声明；每阶段重新求值这些规则的条件，
并把目标解析到当前实体。冻结的是语法声明，不是条件的真假。
因此新生 YOU 可以被后续 DEFEAT 删除，后生 SINK 不倒流参与已经完成的 SINK。
被沉没删除的规则文字，其本轮规则仍有效；下一次编译才撤回。
HAS 生成的新文字也在下一次编译后生效。最终 WIN 检测使用同一帧和存活 YOU。

properties.RW_ResolveContactVictims 只判接触；rules.RW_PlanHasBirths 只生成规格；
bootstrap.RW_PlanContactPhase 使用世界创建/删除规划器组合阶段。
阶段事件记录 kind=destroy、cause、entity_id，只是回合诊断，不承担权威状态。
生产宿主提供 contact 与 refresh 服务；保留不启用接触的简化适配器，
但其中出现可执行 HAS 时会明确拒绝 missing_contact_services，避免吞掉内容物。

仍只提交一个回合/整树历史帧。晚期生成失败（包括 ID 耗尽）拒绝整回合，
移动、文字推动、删除、生成和 ID 分配器全部保持原状。Z 恢复完整状态和所在层。

## 真机路线

每组从重新启动试玩开始，根 SELECT 初始 (2,2)，仍使用 F 确认、Z 撤销。

| 入口 | 到入口 | 进入后操作 | 预期 |
| --- | --- | --- | --- |
| DF (4,1) | D、D、W、F | D | Avatar 接触 SKULL 后消失，SKULL 保留；Z 恢复。SELECT 已在父块，F 可返回；Z 跨层恢复 |
| SK (5,1) | D、D、D、W、F | D | 箱子被推入 WATER，箱子和水一起消失，Avatar 保留；Z 全部恢复 |
| HAS (4,2) | D、D、F | D，再 D | 箱子入水后生成两个同格 Rock；下一次 D 时两块 Rock 都受 YOU 控制移动。Z 两次恢复原箱子、水、玩家与分配器 |

HAS 关内提供 CRATE HAS ROCK AND ROCK 与 ROCK IS YOU，观察重叠时会显示两个 R。
原有地图入口/测试保持；危险物按规则能力着色（DEFEAT 红、SINK 蓝），外形有明确标签。

## 验证

启动新增实际映射管线测试：DEFEAT / SINK / repeated HAS / atomic Undo。
tests/contact_words.lua 覆盖孤立/重叠身份、多个 YOU、互相 DEFEAT、Text/Level
内容物、重复 HAS、48 产物、规则删除时序、转换不生内容、后续阶段新生对象、
WIN 顺序、分配器耗尽、各服务失败边界和 Undo/重放。
tests/run.lua 通过 F 宿主入口验证三张样例、最后 YOU 死亡后的 SELECT 返回和跨层撤销。
原有方向、文字推动、转换、重复规则、Level 语义及原生渲染适配器回归均通过。
离线通过，真机手测待用户验证。
