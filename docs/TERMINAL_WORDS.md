# M9.3U: Too Complex / WRITE / CRASH / SAFE

## 原作依据

本机 Baba Is You/Data：
- rules.lua:calculatesentences，物理句子组合达到 5000 时 destroylevel("toocomplex")；
  subrules 展开 ALL；postrules 用 RHS NOT 取消相同规则，IS NOT TEXT 也取消 WRITE，
  自同一规则保护同来源的 WRITE。
- convert.lua:conversion/convert：WRITE 将目标指定为 text_目标；既不进行 HAS 销毁，
  也不是转换为原对象自己的名词。WRITE ALL 先展开普通词表。
- blocks.lua:block：销毁处理完毕后，仍存活的 CRASH 实体触发 destroylevel("infinity")。
  features.lua:getunitswitheffect 不返回 EMPTY；CRASH 检查没有 issafe 过滤。
- tools.lua:issafe；blocks.lua 的 SINK/DEFEAT 检查：SAFE 保护各个受害者，
  安全的 SINK 仍可销毁同格不安全对象，安全的 DEFEAT 仍是危险源。

原作独立执行核对：`luatex --luaonly tests/reference_terminal_words.lua`。
这项 oracle 不与项目测试共用全局环境。

## 实现与边界

TOO COMPLEX 独立保存为 world.too_complex，不再与 WORD 的 INFINITE LOOP 混淆。
连续至少三格的物理文字路径在组合数达到 5000 时提前结束解析，不创建所有 AST；
原有 50000 遍历/输出上限仍作为额外解析限制。两类限制都触发 TOO COMPLEX。
WORD 200 次求解限制及存活的 CRASH 对象触发 INFINITE LOOP。
二者都提交已完成的触发阶段、保留棋盘，仅允许 Z 撤销；SELECT/F 及直接 Commit 也锁住。
渲染不重新解析终止棋盘；同一状态不能同时标记两种终止原因。

WRITE 支持普通对象、TEXT、EMPTY 主语及 ALL/NOT 主语展开，RHS 普通名词、属性、
TEXT/EMPTY/ALL；WRITE NOT 取消对应产物，WRITE NOT ALL 只取消 ALL 展开。
重复物理规则保留重复产物，ALL WRITE ALL 保留两条展开路径。
结果保留位置、方向及 level_link，首个产物保留 ID，多产物使用事务分配器；
转换不触发 HAS。Text 写成相同的 Text 不提交冗余 retype，后续重复产物仍创建。
尚不支持谓词/连接词作为 WRITE 的 RHS，也沿用已有作用域 LEVEL 文字转换未实现的边界。

SAFE 接入已实现的 SINK/DEFEAT，以及作用域 LEVEL 的 DEFEAT 保护。
它不抑制转换、CRASH 或复杂度终止。EMPTY 的销毁/HAS 和尚未实现的其他销毁词仍属后续工作。
CRASH 在 SINK/DEFEAT 后检查存活真实实体，使用冻结规则帧；已被销毁的 CRASH 不触发。

## 真机路线

从重新试玩的根地图开始：
- D、F → NAT：底行新增 WRITE、SAFE、CRASH，保留 HAS/SINK 与原组合词。
  可构造 ROCK WRITE PUSH 检查 Rock 变成 text_Push；Z 恢复。
  ROCK IS CRASH 应显示 INFINITE LOOP，只能 Z；加 SAFE 不应屏蔽 CRASH。
  AVATAR IS SAFE 可测试 SINK/DEFEAT 免疫，NOT SAFE 可取消免疫。
- D、D、D、D、F → TC：进入时三堆文字分开；W 将 CRATE 堆推入句子，
  触发 TOO COMPLEX。移动、F 都应无效；Z 回到拼接前。
- 旧 LOOP、TXT 和各接触测试关保持原入口。

`luatex --luaonly tests/run.lua` 覆盖真实 TC 输入回调/标题/锁定/Undo，及 WRITE、SAFE、
CRASH 事务测试。完整回归不在正常开局运行。新增关卡后正常启动约 885000 条离线 Lua
指令，仍受 2000000 预算约束；这不是游戏宿主计时器的等价测量。
