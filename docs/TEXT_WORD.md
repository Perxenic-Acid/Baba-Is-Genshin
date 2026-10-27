# M9.3S：IS TEXT、WORD 与自由测试关卡

## 本机原版依据

Baba Is You/Data/convert.lua 的 conversion 将 NOUN IS TEXT 转为 text_ + 源名词，
convert 保存位置、方向、ID 与关卡元数据。这里以 Text.name=ROCK 表示 text_Rock。
rules.lua 的 code（约 22–31、137–150 行）查 WORD 对象并在 WORD 集合改变后重读；
codecheck（约 880–910 行）将有效 WORD 对象用原 UNITNAME 放入词流。
findwordunits（约 2398–2565 行）含来源与递归稳定性检查，不能把上轮 WORD 缓存当作内蕴。

## IS TEXT

普通正向 NOUN IS TEXT 将对应 Object 改为 Text，Text.name 取该类型在当前词典中的
名词（有别名时按名称排序）。保留原 ID、位置、六值方向、明确的 level_link。
Text 的 PUSH 来自正常 Text IS Push 规则；没有把 PUSH 写进新对象本体。
重复 TEXT/混合名词目标继续逐条生成，首产物使用原 ID，其余分配新 ID。
A IS A 仍保护 A，A IS NOT TEXT 阻止对应 TEXT 转换。

新增原子操作 retype：from 是完整源快照，to 是同 ID 的完整新类别实体。
校验类别数据、位置/方向/指向保持和快照是否过期；同一 flat 阶段不能再对该 ID
同时写位置或别的操作。跨阶段修改仍允许。Text 现在可保留原有明确关卡指向，
不会因类别改变丢失入口身份。Undo 同时恢复原类型与本回合其他变化。
M9.3T 已补 TEXT IS NOUN 的反向类转换；任意深度 Meta 与当前 LEVEL 作用域的 TEXT 转换仍未实现。

## WORD 编译

WORD 是派生读取能力，不是 Text 类，不自动给予 PUSH。
对象获得 WORD 后以本身名词进入空间词流，在主语或宾语位置都能参与规则；
物理实体 ID 继续作为规则来源，重叠的不同 ID 仍产生各自组合。
同一对象有多条 WORD 来源不会被当成多个物理词。

Reader 增加可选 word_tokens 映射，只消费编译器提供的 ID→词面；它不解释词典或属性。
rules.RW_WordTokenMap 从正常属性投影生成该映射，RW_NounTextName 同时服务 IS TEXT、
WORD、HAS TEXT。物理 Text 本来就可读，不会因为 NOT WORD 变成不可读。

bootstrap.RW_CompileWorld 从纯物理 Text 开始，执行读句→AST→语义→求值/投影→
WORD 词流，直到 WORD 映射稳定。每次编译重新建立有根据的集合，不继承上一帧
可读对象；仅由对象自身支持的 WORD 句子不能凭空自启动或在外部来源断开后残留。
生产宿主所有移动前后、转换后、进入/返回和显示规则读取都使用该编译入口。
接触阶段仍冻结编译后的声明，不因销毁文字而在半轮重新读句。

M9.3T 改为最多 200 轮；超限停止解析并进入 Infinite Loop，仅允许撤销。
保留触发这一步的棋盘，不复刻原版 infinity 的整关销毁动画。
完整的条件 WORD、GROUP/MIMIC/NOT 主语递归等复杂语义仍待对应词实现。

## NOT 的本步范围

默认 IS 增加右侧否定：IS NOT 属性产生 deny_trait，逐实体覆盖该属性的正向授予；
IS NOT 名词/IS NOT TEXT 阻止对应对象转换。正负规则顺序不改变覆盖结果。
Text 类的属性否定也可用，例如 TEXT IS NOT PUSH。
自定义关系须显式注册 negative_property / negative_noun 才执行否定，保持已有语言隔离。
M9.3T 已支持主语 NOT、重复 NOT 与 ALL/EMPTY/TEXT 组合；NOT HAS 已在 M9.3T.3 接入；复杂条件仍保留 deferred。
WORD 自否定循环按上面的 Infinite Loop 锁局处理，详见 SPECIAL_NOUNS.md。

## TXT 自由测试关卡

根入口在 (1,1)，标签 TXT。从重新试玩开始按 **A、W、F** 进入。
12×12 开放空间，中央无墙；左上只有 SELECT、父关卡块与一格 Line，用于 F 返回。
配置规则：Avatar IS You；另有 Rock IS Push，便于移动你要求的普通 Rock。
Text IS Push 等现有预设继续适用，不占用可移动文字。

| 实体 | 初始位置 |
| --- | --- |
| Avatar | (6,8) |
| text_Rock | (4,5) |
| Rock | (4,3) |
| text_Is | (5,5) |
| text_Is | (5,3) |
| text_Word | (6,6) |
| text_Not | (8,4) |
| text_Text（额外提供） | (8,7) |
| 第二块 text_Word（用于矛盾测试） | (9,9) |

- 进来后 W、W：把 WORD 推上去形成 ROCK IS WORD。普通 Rock 保持对象类别，
  显示 WORD 颜色；它与旁边 IS 可以继续组成别的规则。
- 接着 D、D、D、S、A、A、S、A、W、W：把 TEXT 推入同一规则，同时把 WORD 推开，
  形成 ROCK IS TEXT。原 Rock 变成第二块 text_Rock。
- Z：同时恢复推动的文字、原 Rock 类别和 WORD 能力。其余部件可继续自由摆放。
- 返回时把 SELECT 移到左上 PARENT 并按 F；从上述路线结束处按 D、F 即可。

## 验证

启动自测新增 pipeline IS TEXT / WORD object reading / Undo。
tests/text_word.lua 验证类转换/身份/指向、混合重复产物、原子失败、WORD 主宾语、
来源撤回、自支持、右侧否定、循环拒绝和 Reader 边界；tests/run.lua 通过实际按键
回调验证上述整条 TXT 路线及整树 Undo。原有 DEFEAT/SINK/HAS、移动/方向、转换、
重叠重复规则与关卡导航回归通过。离线验证不代表本步已真机验收。

Flag 不再有隐藏的 WIN 预设。旧 A/B、T 胜利测试关卡通过棋盘上可见的 FLAG IS WIN 赋予属性。
