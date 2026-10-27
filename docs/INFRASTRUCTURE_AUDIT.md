# 2026-10-27：原版源码对照与基础设施缺口

参考本机 Baba Is You/Data 的实际脚本；仅核对与下一步实现有关的路径，
不是对原版所有词或引擎功能的全面兼容认证。这里是基于代码差异的工程安排。

## 已有可用底座

Object/Text、重叠与六值方向；空间 Reader/typed AST/语义和行为注册；
确定性创建/删除/分配器；重复规则和一对多转换；原子预览/提交/Undo；
SELECT 独立于 YOU、F 确认/多入口选择、关卡边界重载、持久 LEVEL 转换和结果。
M9.3Q 补齐回合内多阶段快照，在不增加历史帧的情况下允许修改新对象。

## 剩余能力及推进顺序

| 优先级 | 缺口 | 原版参考 | 后续落地方式 |
| --- | --- | --- | --- |
| 1 | 接触效果与销毁/出生原因、同批次删除、HAS 内容物 | blocks.lua 的 block/handledels；tools.lua 的 handleinside/delete/inside | M9.3R 已实现普通 DEFEAT/SINK/HAS 与冻结接触规则帧；SAFE/FLOAT 等过滤随词扩展 |
| 2 | 实体上下文条件、否定效果与冲突裁决 | conditions.lua 的 testcond/condlist；rules.lua 的 postrules | 当前条件只支持全局布尔/重叠；补每个主体求值，接 ON/NEAR 与 NOT，不能用全局命中替代逐实体条件 |
| 3 | 语法覆盖 | rules.lua 的 docode/calculatesentences | 目前主要单主体、RHS AND；补主体 AND、条件短语等，继续保留物理 ID 与重复次数 |
| 4 | 自主移动、多轮意图与冲突顺序 | movement.lua 的 movecommand/check、blocks.lua 的 moveblock/fallblock | 跟随 MOVE/PULL/SHIFT 等词逐项扩展，不能把所有动作直接当 YOU 输入 |
| 5 | 规则重求值和上下文特殊主语 | rules.lua；convert.lua | M9.3S 已有普通 IS TEXT、WORD 稳定重读和右侧否定；ALL/EMPTY/深层 Meta/复杂 WORD 仍需扩展 |
| 6 | 随机状态与回放 | blocks.lua 的随机处理；原版撤销数据 | 第一个随机词引入时，把 PRNG 状态纳入权威快照；禁止取宿主时间决定结果 |
| 7 | 多目标 LEVEL 转换与地图进度 | convert.lua 的 dolevelconversions/convertlevel；map.lua/mapcursor.lua | 普通实体已支持多目标，当前关卡作用域仍拒绝多个不同转换目标；需要持久父块增殖及身份约定 |

地图揭示、通行条件、子地图达标计数和长期保存仍是关卡包层缺口。
可见性/可达性/可解性分离来自用户设计；Line/Path 是本项目抽象。
这些不阻塞第一批普通属性词，不应为它们无限推迟词语实现。
现有 outcomes 是运行树状态，不等同于已实现退出游戏后的长期存档。

## 下一步

不预建覆盖全部词的万能框架。“接触规划 → 删除/出生”的最小闭环及普通 DEFEAT、SINK/HAS 已在 M9.3R 落地；条件、语法与
自主移动分别随对应词扩展。每次明确已实现与 deferred，保持八个映射脚本。
