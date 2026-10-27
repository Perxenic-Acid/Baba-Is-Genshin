# M9.3M：关卡指向、转换与有序终局属性

后续边界/选择器修订见 [LEVEL_BOUNDARIES.md](LEVEL_BOUNDARIES.md)。

本步按用户修订，替换 M9.3L 中“外形改变就不可进入”的错误限制。

## 本机原版源码依据

`C:\Program Files (x86)\Steam\steamapps\common\Baba Is You\Data`：

- convert.lua 的单体转换路径（约 335–385 行）保留 ID、U_LEVELFILE /
  U_LEVELNAME；level 外形若有 LEVELFILE 会成为可用关卡。
- mapcursor.lua 的 mapcursor_enter（约 243–288 行）检查 SELECT、关卡指向和
  可用性，不以当前外形必须是 level 作为进入条件。
- blocks.lua 的 levelblock（约 2075 行起）按 feature 列表逐项处理，win 分支
  会返回；defeat 分支会改变后续处理条件。不能把顺序相关的终局性质简化为集合。
- convert.lua 的 dolevelconversions（约 549–716 行）是独立的关卡转换阶段。

具体行为以本次用户要求和逐项测试为契约；不声称复刻了完整原版阶段图。

## 对象属性与当前关卡属性

WIN 是普通派生属性。行为注册把默认 win 属性映射到 win 能力。
RW_HasWinContact 检测 control（YOU）对象与 win 对象的同格接触，触发获胜；
对象可以是任何 archetype 或 Text，不要求叫 Flag。投影为空会撤回能力。
UI 接收独立的规则投影快照，按 win 能力着色；Flag 的名称显示 FLAG。

LEVEL 的词汇定义为 {tag="level", block_type="level_block"}。
当作主语时，它既描述当前关卡作用域，也匹配当前世界的 Level 外形对象。
当前关卡属性以 level_trait IR 顺序保留，交给行为注册解释，不能转成哈希集合。

当前接受右侧的 AND 连词链：language.operators.AND="and"。
每个结果词展开为独立的 typed AST 条目，保留语序、rhs_index 和包含 AND 的
物理 Text ID 前缀。支持 object 位于语序最后的配置；其他语序原有单项语法
仍保留，尚未实现其连接项语法。NOT 等原有不执行语义仍 deferred。

## 用户指定的有序结果

| 规则 | 结果 |
| --- | --- |
| LEVEL IS WIN | 存在 YOU 时获胜并返回父级；只有 SELECT 不获胜 |
| LEVEL IS DEFEAT | 留在当前实例，YOU 停止；SELECT 仍可移动/确认 |
| LEVEL IS WIN AND DEFEAT | 获胜 |
| LEVEL IS DEFEAT AND WIN | 失败；SELECT 仍可操作 |
| LEVEL IS ROCK AND WIN | 转换父级中的对应关卡块，不获胜 |

阶段上先完成实体/关卡转换，再处理当前关卡有序属性，最后检查普通 WIN 接触。
终局属性按顺序取第一个 win/defeat 能力。LEVEL IS LEVEL 仍保护转换。
失败态在规划和树 Commit 两层阻止 YOU 操作，允许 SELECT；无 SELECT 时只可撤销。Undo 恢复失败前
整个树快照。根关卡获胜只记录结果；根的外层转换仍因没有父块而整步拒绝。
普通对象 DEFEAT 的完整碰撞/删除机制不在本步范围内。

## ID 指向与外形分离

实体的 level_link 是 ID 上的明确关卡指向配置，随转换保留。
source_type 现在只用于显示原外形提示，不参与进入资格判定。
任意外形的有指向对象，都可响应 SELECT、沿用原入口的子实例身份并确认进入。
父关卡转换为 Rock/Crate 后仍可进入；Undo 还原外形、所在层和结果。

NOUN IS LEVEL 转换为该词汇配置的 block_type，保留实体 ID 与已有 level_link。
没有配置指向的对象也能转换，但只是不可用 Level（UI 显示 LEVEL?）。
SELECT 可以移动到其上，F 返回 unavailable_level；不凭 archetype、位置、相邻
关卡或同一名词自动推断目标。删除绑定对象后新建的不同 ID 也不会继承指向。

## 具体真机测试

每组从重新启动试玩开始，根地图 SEL 初始在 (2,2)。
根的第三行从左到右有 W、D、WD、DW、RW、N 六块，均按 F 进入。
子关卡中按 W 将主语推入横向规则，之前不会有提前生效的终局前缀。

| 根入口 | 到入口的按键 | 进入后 | 应观察到 |
| --- | --- | --- | --- |
| W | A、S、F | W | 获胜回 MAP；Z 回到规则形成前 |
| D | S、F | W | DEFEAT，YOU 停止；D 移动 SELECT，F 返回 |
| WD | D、S、F | W | 获胜回 MAP |
| DW | D、D、S、F | W | DEFEAT，SELECT 仍可移动和确认 |
| RW | D、D、D、S、F | W | 回 MAP，RW 变 Rock（重叠时 RW*）；F 仍能再次进入 |
| N | D、D、D、D、S、F | W | 两箱都变 Level，仅原 ID 4 有指向 |

N 组继续：S、D、D 把 SEL 移到绑定块，F 可进入内层关卡；D、F 通过父块
返回 N 后普通箱子转换已重置；不可用块应在退出 N 前测试。
失败与获胜/转换都在原子树历史中，Z 要同时恢复所在层和相关对象/结果。
A/B/T 原入口仍保留用于前一轮回归。

## 验证范围

启动新增 pipeline ordered LEVEL WIN/DEFEAT/transform and Noun IS LEVEL / Undo。
版本标记 M9.3M initialized。离线 tests/level_semantics.lua 覆盖上述全部分支、
无 YOU 的直接 LEVEL WIN、不可用新 ID、Text WIN、能力撤回与 AST 顺序/来源。
tests/run.lua 通过真实 F 回调执行终局矩阵及 N 的可用/不可用关卡对照。
tests/navigation_view.lua 检查属性着色、普通 Flag 标签和转换后关卡标签。
原生 UI、输入和运行时启动自测仍待用户真机验证。
