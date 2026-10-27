# M9.3T：Infinite Loop、NOT / ALL / EMPTY / TEXT

## 原版依据

本机 `C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data`：
- rules.lua 的 code（约 137–156 行）在 WORD 集合变化后重读，并在迭代上限触发 infinity。
- rules.lua 的 addoption/subrules（约 1084–1206 行）展开否定主语、ALL、NOT ALL；
  syntax.lua 的 setupnounlists（约 878 行）与 tools.lua 的 findnoun 定义特殊名词范围。
- convert.lua 的 conversion/convert 处理 NOT 自身、TEXT、EMPTY 和普通转换。
- syntax.lua 的 createall_single（约 402 行）保留普通源对象，排除自身与同格已有目标。
- movement.lua 的 check（约 1112–1181 行）处理 EMPTY STOP/PUSH，PUSH 优先于 STOP。
- blocks.lua 的 EMPTY 分支（约 2090–2390 行）区分空格属性与普通实体接触。

## Infinite Loop

WORD 编译从物理 Text 冷启动，使用迭代而不是递归，最多重求值 **200 次**。
不稳定时停止解析，保留触发循环的移动/已完成阶段，进入 `world.infinite_loop`。
这是临时采用的锁局处理，不模拟原版的销毁动画。

状态属于权威世界快照；移动、F、SELECT、胜利/返回均不能继续，**仅 Z 撤销**。
屏幕标题和提示显示 INFINITE LOOP。一次撤销恢复触发前的棋盘、方向、分配器和运行树。
转换后以及接触结束后的规则循环同样检查；接触本身仍使用冻结声明帧。
解析器另有每条空间线 50,000 次候选探索预算，以及总计 50,000 条规则产物上限；组合爆炸也进入相同锁局。

## 名词与否定

| 句式 | 行为 |
| --- | --- |
| NOT A IS 属性/名词 | 对当前关卡词典中的其他普通名词展开；不包含 TEXT、EMPTY、LEVEL |
| ALL IS 属性/名词 | 对词典中所有普通名词展开，即使该类型目前没有对象 |
| NOT ALL IS … | 展开为 TEXT IS … 和 EMPTY IS … |
| NOT TEXT / NOT EMPTY IS … | 普通名词范围，不包括其他特殊名词 |
| 多个 NOT | 主语、宾语及 RHS AND 后都可连续使用；奇数次否定，偶数次抵消 |
| A IS NOT 属性 | 否定覆盖正向属性，与顺序无关；LEVEL 的否定也取消棋盘作用域属性 |
| A IS NOT B / TEXT / ALL | 禁止对应转换；NOT ALL 仅禁止 IS ALL，不扩成普通宾语的补集 |
| A IS NOT A | 删除 A；这是转换，不触发 HAS。也适用于 TEXT IS NOT TEXT |
| A IS EMPTY | 删除对象，不触发 HAS |
| A IS ALL | 保留普通 A，同格增加其他普通类型；已有目标不再补出 |
| TEXT IS A | 所有文字变回 A，保留首产物的身份、方向、位置和关卡指向 |
| TEXT IS TEXT | 文字自我保护，不引入额外 Meta 层级 |
| A HAS ALL / ALL HAS A | 按普通名词范围展开，仍保留物理重复规则 |

ALL 范围以 `world.language.nouns` 的普通类型为本项目的关卡调色板。
词典别名按类型去重；不同物理句子不去重。下沉接口 `RW_LowerRuleAST` 的第三个参数
提供世界/词典，`RW_CompileWorld` 及实际宿主已接入；无世界参数的旧接口保留原行为。

## EMPTY

EMPTY 是当前没有任何实体的格子，不是隐藏实体；文字、Line、SELECT 等同样占格。
转换使用冻结的转换前占位快照：EMPTY IS A/TEXT/ALL 在每个空格产生对应产物，
同一阶段不级联；EMPTY IS TEXT 生成 text_Empty。EMPTY IS EMPTY 保护空格转换。
创建仍经过 ID 分配、完整校验和同一次 Commit/Undo；新对象方向暂取 None。

空格属性投影为坐标和能力，支持否定。STOP 阻止进入空格；PUSH 沿空格链求解，
遇到其他对象继续按 PUSH/STOP 约束处理。EMPTY YOU 通过临时移动代理推动普通对象，
代理不会进入 Plan、分配器或撤销快照；EMPTY YOU + WIN 可触发胜利。
显示有属性的空格为淡色 E；PUSH 不会把空格制造成真正的物块。

## 当前边界

- EMPTY 的持久逐格方向、销毁/HAS 生命周期尚未实现；EMPTY HAS … 明确保留 deferred。
  EMPTY YOU + DEFEAT 的逐格销毁效果和与作用域 LEVEL 的所有交互尚未全面复刻。
- 当前 LEVEL 作用域的 ALL/TEXT/EMPTY 转换、多个不同 LEVEL 转换目标仍未实现。
- 主体 AND、实体上下文条件、GROUP/MIMIC、任意 Meta 深度仍在后续范围；NOT HAS 不执行。
- WORD 仍使用物理 Text 冷启动的有界求解，不声称覆盖原版所有递归来源判断。

## 真机测试

从重新试玩的根地图开始：

- **D、F → NAT**：开放组合关卡。提供 ROCK、CRATE、AVATAR、ALL、EMPTY、TEXT，
  四块 IS、四块 NOT、两块 WORD、PUSH、YOU、AND、WIN。文字按间隔摆放，开局不形成句子；
  Avatar IS YOU、Rock/Crate IS PUSH 是关卡配置，便于自由实验。
- **D、D、D、F → LOOP**：再按一次 **W** 推入 NOT，触发 WORD 自否定循环。
  移动/F 均应失效，标题变成 INFINITE LOOP；**Z** 恢复，再 W 可重现。
  撤销恢复后 **D、F** 可让 SELECT 通过 PARENT 返回。
- 原 **A、W、F → TXT** 测试保持，包括第二块 WORD。

离线 `luatex --luaonly tests/run.lua` 包含组合语义、物理 NOT 重叠、空格生成/推动、
实际 LOOP/NAT F 回调、Infinite Loop 锁局/撤销/重放，以及原有全部回归。
启动日志新增 `pipeline ALL WORD / EMPTY TEXT / Undo`，版本 M9.3T。
离线通过不代表本步已真机验收。

## M9.3T.1 启动超时修复

真机导出日志 2026-10-27_13-46-43_73_513013168.gia 显示，在启动的 LEVEL 自测阶段，
RW_ParseRuleAST 触发 `Lua execution took too long`，尚未创建棋盘。
解析器改为沿实际语义角色/NOT 前缀遍历，不再穷举所有前缀长度与空格组合。
相同离线启动流程从约 75,342,000 条指令降至 19,977,000 条；tests/run.lua 增加
30,000,000 条启动预算以捕捉此次回归。此预算是离线回归指标，不等同于游戏的计时器。
重复 NOT、六种语序、物理重叠与 AND 的规则数回归保持通过。
另修复旧日志暴露的 AddCursorEventListener 缺失：宿主无该方法时不绑定鼠标事件，
选关继续使用 W/S/F/Z；测试覆盖缺失方法的原生控件。

## TXT 关卡的 Cursor 词典修正

截图的 NOT ROCK IS WORD 应使 Cursor/Line 获得 WORD。原 TXT 关卡放置了这两个普通
对象，却没有注册相应名词；现已给 TXT 及其 NAT/LOOP 派生关卡补 CURSOR、LINE 与
特殊 LEVEL 的明确词典项。测试复现 Cursor 和父关卡块重叠，再接 IS TEXT，验证
Cursor 转成 text_Cursor、父关卡块不转换、Z 恢复 SELECT 与 WORD。
LEVEL 是特殊名词，不在 NOT ROCK 或 ALL 的展开范围；不会借该句得到 WORD。
这是与 Cursor 配置遗漏不同的情况；原版依据见 rules.lua:addoption 与 syntax.lua:setupnounlists。

## M9.3T.2 正常开局与完整诊断分离

按用户要求，正常开局不能被回归自测拖到爆栈/超时。OnStart 固定走无自测路径，
仅检查映射依赖、创建实际关卡树、绑定输入并显示棋盘。模块自测、转换/接触/
多语言/LEVEL 等管线回归只在显式 RW_StartWithSelfTests 入口运行；此入口供离线
或全新诊断宿主使用，不绑定游戏键，不应在正在运行的游戏上重复调用。

离线正常 OnStart 约 723,000 条指令，增加 2,000,000 条预算防止回归；
完整诊断仍在 tests/run.lua 单独执行。另验证关闭自测的移动、进入/退出关卡和 Undo。
数字不包含原生 UI 调用的宿主成本，不是对游戏计时器的替代。
局内玩家构造的极端/未定义行为不扩展开局的兜底要求；已有 Infinite Loop 约定保留。
启动版本为 M9.3T.2，不再在普通启动打印 TEST PASSED 测试串。
