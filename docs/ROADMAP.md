# 基础设施进度与后续顺序

更新：2026-10-27。以下后续顺序是恢复历史设计后对当前代码的实施安排，
不是声称从历史记录中找到了 M9.3F 及以后原定编号。

最新能力盘点见 [INFRASTRUCTURE_AUDIT.md](INFRASTRUCTURE_AUDIT.md)。
下文按历史里程碑保留；有冲突时以较新里程碑为准。

## 当前基线

八个映射脚本：bootstrap、world、reader、grammar、rules、properties、
movement、renderer。已具备多实体重叠、完整世界快照、原子 Plan/Preview/
Commit/Undo、Rule IR 来源、AST、IS 属性与对象转换、TEXT IS PUSH、
多 YOU 和 PUSH 链。M9.3E 的六值方向已通过用户提供的真机启动自测日志，
该日志还展示了文字推动、规则拆装、对象转换及边界阻挡；未包含手动 Undo。

## M9.3F：明确回合调度边界

将回合规划从输入回调中提取为不依赖 UI 的 RW_PlanTurn：

旧规则求值 → 效果投影 → 意图/移动求解 → 移动预览 → 新规则求值 →
转换操作计划 → 完整计划预览校验。

宿主仅在完整计划成功后执行一次 Commit，然后更新显示。调度器返回阶段
轨迹与结构化失败信息；它不拥有 session/history，不渲染，不提交。
无效动作不进入后续阶段；受阻、无 YOU 等有效空回合继续保留历史语义。

当前算法仍是明确的初版阶段顺序，不声称已经支持任意阶段重排或不动点求解。
函数暂驻现有 bootstrap 映射脚本，避免为了物理拆文件要求新增编辑器映射。
逻辑入口和服务边界先独立，后续有需要再调整部署文件。

## M9.3G：原子创建、删除及 ID 分配

已实现 RW_PlanCreate/RW_PlanDelete、快照内 next_entity_id、连续分配与
删除不回收、完整删除快照校验、终结删除语义，以及统一 Preview/Commit
应用路径。混合回合撤销、确定性重放、失败整步拒绝和新 Text 的规则管线
已通过离线自测。操作契约见 ATOMIC_OPERATIONS.md。直接读取 2026-10-26
21:58:01 的第 56 份真机日志：18 项自测通过，82 次 Undo 一直恢复至
history=0，未提取到失败或异常信息。

## M9.3H：语序与关系语义注册

新增关卡级 language.order、verb_registry、world.semantics 和纯数据注册
接口。支持六种角色排列；解析类别与可执行语义独立，未实现关系仍 deferred。
默认 IS/语序保持不变。两套空间语言的属性效果、移动、多 YOU、转换、
方向与原子 Undo 对照已通过离线管线测试。2026-10-27 09:10:37 第 57 份
真机日志包含 21 项通过记录及 M9.3H initialized，未提取到失败信息。
详见 LANGUAGE_REGISTRATION.md。

## M9.3I：统一选择器与行为能力注册

选择器由 rules.lua 单一实现，同时用于条件与具体效果目标。EvaluateRules
返回 entity_ids；ProjectWorld 消费具体效果，不再重复解释选择器。
关卡可注册派生属性到 control/push/block_entry 的映射，移动求解器读取能力。
自定义条件、目标、能力、阻挡/PUSH/撤回/Undo 已通过离线实际管线测试，
2026-10-27 09:22:35 第 58 份真机日志包含 23 项通过记录及
M9.3I initialized，未提取到失败信息。接口见 SELECTORS_BEHAVIORS.md。

## M9.3J：关卡定义与运行实例分离

默认演示改为可复用定义，实例持有独立世界和历史，并显式携带 definition_id /
instance_id。原有无参 CreateSession 保持兼容。定义数据、实例配置、实体、
分配器均深拷贝隔离，Commit/Undo 保留实例身份。离线完整管线与新增隔离、
生命周期和非法定义测试通过。2026-10-27 09:33:18 第 59 份真机日志
包含 24 项通过记录及 M9.3J initialized，未提取到失败信息。
详见 LEVEL_INSTANCES.md。

## M9.3K：嵌套进入、返回与状态保留

新增定义目录、实例集合、父实例/slot 绑定、导航栈和树内实例分配器。
进入/返回保留各实例完整状态与局部历史；Z 只撤销当前实例，空历史不返回。
当前测试棋盘新增 A/B/OUT 入口及实例标题，支持实操比较同定义的独立实例。
离线测试虽通过，但用户真机指出自动进入、YOU/SELECT 混淆和撤销范围错误；
由下面 M9.3L 修正，不能视为 K 的玩法已验收。

## M9.3L：SELECT 确认、三种退出与整树事务

对照用户本机 Baba Is You/Data 的 mapcursor.lua、convert.lua，拆开 YOU/SELECT。
关卡块改为世界实体；SELECT 只产生候选，确认动作单独进入。Z 改用整树快照，
撤销移动、确认、父块返回、获胜返回与 LEVEL 转换返回时恢复当前层及全部状态。
新增实际映射管线启动测试和离线回归通过，真机待验证。用户最新澄清直接用 F 交互确认，已绑定 KeyboardInteractKeyDown；
确认入口仍可 Invoke，不要求物理 Enter。
详见 NESTED_LEVELS.md。原版语义查阅约定已写入 AGENTS.md。

## M9.3M：有序关卡属性与 ID 指向

核对原版 convert.lua/mapcursor.lua/blocks.lua，修复转换后仍可选关的指向保留。
支持 NOUN IS LEVEL，明确可用性来自具体 ID 的 level_link，而不是 Level 外形。
新增配置化 RHS AND、按序关卡属性、直接 WIN 和仅 Undo 的 DEFEAT，覆盖用户
给出的五种终局结果。测试地图第三行新增 W/D/WD/DW/RW/N 六组实操样例。
启动实际映射管线和离线 F 回调测试通过；真机待验证。见 LEVEL_SEMANTICS.md。

## 后续顺序

1. 回合内顺序阶段事务（M9.3Q 已完成），支持本回合新对象被后续阶段处理。
2. 接触/销毁/出生最小闭环：普通 DEFEAT、SINK/HAS 已在 M9.3R 完成。
3. 主体上下文条件、否定规则、主体 AND，与对应词一起推进。
4. 自主移动、随机状态、特殊主语、多目标 LEVEL 等按词的需求补齐。
5. 地图揭示/通行/进度和长期保存单独建设，不阻塞第一批普通词。

具体源码依据和范围见 INFRASTRUCTURE_AUDIT.md，不把 deferred 当作已实现。

## 本地工作约定

直接修改用户指定的 Beyond_Local_Save_Level/1073741831 仓库，减少手动
拉取。写入前检查本地改动；只提交本次明确修改的文件。用户的 .gil 修改
不得顺带提交或覆盖。离线运行实际 bootstrap 管线；平台 UI/映射依赖真机。
真机日志可直接从 BeyondLocal/<account>/Beyond_Debug_Log 中按修改时间读取
最新 .gia，提取可读脚本消息；.gia/.gil 均含二进制和文本，不能按普通文本
覆盖保存。日志只读，不加入游戏源码提交。

## M9.3N

关卡边界重置、持久 LEVEL 转换/结果、LEVEL IS YOU 地图偏移、多目标选关 UI、
四条预设规则，以及 SELECT-only WIN 不退出/DEFEAT 允许 SELECT。
详见 docs/LEVEL_BOUNDARIES.md；离线新增 tests/level_boundaries.lua 与宿主/渲染回归。

## M9.3O

普通名词一对多转换：同格产物、目标去重、身份保护、原子 ID 分配/撤销。
详见 docs/CONVERSION_SPLIT.md，回归 tests/conversion_split.lua，真机入口 SPL。

## M9.3P

修正上一版按目标名词去重的错误：重复规则逐条生成，完整 AND 路径乘到所有项。
用户重叠示例为 24 条完整句子、48 个 Rock。tests/rule_multiplicity.lua 覆盖实际管线；
tests/reference_multiplicity.lua 可独立运行以对照本机原版源码。

## M9.3Q

新增顺序阶段计划 RW_PlanStages；现有移动/转换管线改走阶段快照，保持一次
Commit/Undo。允许后续阶段修改本回合新对象，晚失败整步拒绝并报告 phase。
启动自测与 tests/stage_transactions.lua 通过；不改变当前地图的预期玩法。
详见 PHASE_TRANSACTIONS.md。

## M9.3R

普通实体 DEFEAT、SINK 与 HAS 已接入。SINK 先于 DEFEAT，接触规则帧在本轮固定，
重复 HAS 逐条出生，销毁/生成/移动共享一次原子 Undo。新增 DF/SK/HAS 三个入口，
启动自测、F 宿主管线、48 产物和失败回滚等离线回归通过。见 CONTACT_WORDS.md。
下一步优先补逐实体条件与否定/主体 AND，之后按词推进自主移动等剩余基础。

## M9.3S

普通 NOUN IS TEXT 通过 retype 保留身份/方向/指向；WORD 对象参与实际词流，
编译器从物理文字重新建立稳定 WORD 集合。新增默认 IS 的右侧属性/名词否定，
循环编译原子拒绝。根 TXT 入口提供用户要求的自由对象及额外 TEXT，Rock 配置 PUSH。
启动自测与实际 F/移动路线离线回归通过，详见 TEXT_WORD.md。

## M9.3T

WORD 超限进入可撤销的 Infinite Loop，锁住包括 SELECT/F 的全部后续动作。
新增 NOT 主语/重复 NOT、ALL/NOT ALL 展开、TEXT 反向转换、EMPTY 转换与虚拟属性，
以及 NOUN IS ALL 的保留源对象语义。新增 NAT 组合关卡、LOOP 一步循环关卡。
原版依据、试玩路线、EMPTY 生命周期等剩余范围见 SPECIAL_NOUNS.md。

M9.3T.1 修复真机启动解析超时：按实际词流而非所有 NOT 长度枚举；启动指令回归
预算与重复/语序/堆叠测试通过。选关 UI 缺少鼠标事件方法时继续支持键盘选关。

M9.3T.2 将全部启动回归移到显式 RW_StartWithSelfTests；生产 OnStart 固定不运行自测，
正常启动约 72 万条离线指令，预算收紧到 200 万。验证无自测的实际输入/导航/Undo。

## Official vocabulary completion (active user priority)

Finish logic before frontend/level design. Track the installed official editor
catalog in OFFICIAL_WORDS.md; generated audit includes 327 text entries and is
checked by tools/audit_official_words.py --check. Do not treat unimplemented words
as complete merely because parsing/token storage permits their names.

M9.4D adds 17 motion/direction properties and six directional/spatial conditions.
Tests and deliberate gaps: MOTION_WORDS.md. Next priority: PULL/SWAP/FALL/REVERSE/
PHANTOM, then MAKE/EAT/BECOME/REVERT and remaining rule/condition families. Continue
through the pending catalog and close documented scoped LEVEL/EMPTY/timing gaps
before declaring all official words finished. Real-device acceptance is separate.

M9.4E adds PULL/SWAP/PHANTOM and all four FALL directions, source-referenced
support/cancellation checks and whole-turn regressions. Next movement priorities:
REVERSE, FEAR/FOLLOW, TELE/HOLD, then the pending lifecycle/syntax/temporal families.


M9.4F adds REVERSE parity across active movement, SELECT and scoped LEVEL, preserving
original facing/lock behavior. Combined FALL axes now settle sequentially instead
of selecting only one axis; the expanded installed-source oracle covers 540 cases.
Next: FEAR/FOLLOW, TELE/HOLD; then remaining lifecycle/syntax/temporal families.


M9.4G adds FEAR as a scheduled noun predicate with duplicate strength, per-identity
conditions and atomic destruction/HAS/Undo. Installed findfears() oracle: 2,048
cases. MOTION expands to 32x28 with three-cell-spaced loose words and a ready-made
FLAG FEAR AVATAR route. Next: FOLLOW, then TELE/HOLD and remaining families.


## Current user ordering (supersedes earlier next-batch suggestions)

Verbs -> conditions -> prefixes -> GROUP -> properties. Letter/number/accidental
composition is deferred until the user chooses to revisit it. Keep this ordering
instead of moving TELE/HOLD ahead of the unfinished verbs.

M9.4H adds FOLLOW and atomic remembered-target state, source-oracle comparison and
complete-name wrapping for single Text labels. Remaining verbs: MAKE, EAT, BECOME,
MIMIC, PLAY. Next implementation: MAKE. See MOTION_WORDS.md for acceptance routes
and deliberate FOLLOW/renderer scope limits.


M9.4I adds MAKE: late physical creation, duplicate products, original converted-vs-old
occupancy checks, MAKE TEXT/ALL and atomic deterministic random-facing state.
Reference matrix: 1,200 installed-source cases. Native route and gaps: MAKE.md.
Next verb: EAT, then BECOME, MIMIC and PLAY, before conditions/prefixes/GROUP/properties.


M9.4J adds EAT after ordinary contacts and before MAKE, with simultaneous victim
selection, SAFE/FLOAT, frozen declarations, HAS and whole-turn Undo. Source matrix:
3,072 cases. Next: BECOME, MIMIC, PLAY. The user waived routine native acceptance;
continue implementation with offline regressions/source oracles without waiting.


M9.4K adds BECOME with independent IS identity/negative semantics, duplicate self
products, TEXT conversion and transient converted tracking for MAKE. Installed
conversion oracle: 432 normalized-rule cases. See BECOME.md for scoped LEVEL gaps.
Next verbs: MIMIC, then PLAY; conditions/prefixes/GROUP/properties follow.


M9.4L adds MIMIC one-generation rule copying, combined per-identity conditions,
verb-specific bans and the original 250-copy limit. Source matrix: 96 cases.
See MIMIC.md for ALL/NOT-subject, EMPTY, scoped LEVEL and GROUP gaps. Next: PLAY,
then conditions, prefixes, GROUP and properties in the agreed order.


M9.4M adds PLAY logic and transient presentation events, dedicated complete note
tokens, grouped emission and original frequency/tune parameters. Source oracle:
7,872 cases. Actual native audio/particles remain pending (diagnostic logs only);
see PLAY.md. Core execution paths now exist for every official verb, with the
previously documented scoped/special-noun gaps retained. Next: remaining conditions,
then prefixes, GROUP and properties; letter assembly remains deferred.


M9.4N adds WITHOUT quantity/self-exclusion and original NOT WITHOUT behavior,
including named-condition inversion for MIMIC. Installed source matrix: 4,608 cases;
startup 1,935,000 instructions. See WITHOUT.md for ordering/postrules boundaries.
Next conditions: FACEDBY, SEEING, then remaining conditions before prefixes/GROUP.


M9.4O adds FACEDBY incoming-neighbor conditions, preserving wrong-facing negative
witnesses, physical multiplicity and distinct IDs. Source matrix: 36,288 cases.
See FACEDBY.md for virtual Empty direction boundaries. Next condition: SEEING,
including rule-derived visibility/occlusion prerequisites; no routine confirmation
is required between implementation batches.


M9.4P adds SEEING, guarded frame-based visibility/occlusion queries and HIDE as
a prerequisite, including temporary renderer visibility. Installed seeing() plus
simplecheck() oracle: 29,952 cases. See SEEING.md for virtual facing/recursive-cache
boundaries. Next: FEELING and POWERED conditions, then prefixes/GROUP/properties.


M9.4Q adds FEELING property/declaration queries, complements and consumed condition
instances, reusing transient guarded frames. Installed source matrix: 2,880 cases;
startup 1,949,000 instructions. FEELING completes the catalog condition category
within documented scopes. POWERED is type 3 (prefix), so next is prefix parsing
and POWERED families, then other prefixes/GROUP/properties. See FEELING.md.


M9.4R adds canonical prefix paths and three independent POWERED/POWER channels,
including Text/Empty and unconditional scoped LEVEL sources. Installed powered()
oracle: 1,080 cases. COND is now 32x28 with sparse prefix words. Startup 1,983,000
instructions, unchanged 2M cap. See POWERED.md. Next prefixes: LONELY, IDLE,
OFTEN/SELDOM; GROUP/properties follow.

## M9.4S — LONELY

Physical identity occupancy prefix, NOT and shared prefix/subject syntax;
conversion/Undo regressions and twenty installed-source oracle cases.
Next: IDLE input state, then OFTEN/SELDOM turn-stable randomness, GROUP.

## M9.4T — IDLE

Current-command wait prefix with validated atomic input metadata and whole-tree
Undo. Blocked/no-YOU direction input remains non-idle. COND contains IDLE.
Eighteen installed-source oracle cases plus planner/scheduler regressions.
Next: OFTEN/SELDOM turn-stable randomness, then GROUP.

## M9.4U — OFTEN / SELDOM

Chance prefixes with 3/4 and 1/6 success, stable physical-head/clause/identity
samples, atomic seed transitions and Undo/replay. Original RNG stream/cache
allocation differences are explicit in CHANCE_PREFIXES.md. Source oracle:
1,440 normalized-roll cases. COND includes both words. Next: GROUP.

## M9.4V — direct GROUP foundation

Three group nouns, conditional/excluded direct memberships, subject and non-IS
target expansion, multiplicity and frozen-frame reuse. Original grouprules oracle:
648 cases. See GROUP.md for the explicit remaining closure/complement/condition
parameter work before ordinary properties.

## M9.4W — ordered GROUP transfers

Cross-group positive/negative-target transfer, original consumed-edge order and
cumulative-condition semantics, source exclusions applied after raw transfer.
4,096 installed-source graph cases plus direct-member regression, bounds and Undo.
Remaining GROUP work: NOT GROUP consumers/targets, group condition parameters,
same-group special cases and negative-source recursion.

## M9.4X — GROUP complements and same-group semantics

NOT GROUP consumers/negative targets, cartesian group endpoints and same-group
identity/CRASH rules. Production regressions and original-source matrix cover
11,340 valid identity frames; 324 malformed original conditional frames are
explicit parity gaps (GROUP.md), not successful comparisons. Next: group condition
parameters, negative-source IS recursion and remaining membership syntax.

## M9.4Y — GROUP condition parameters

Nonrecursive GROUP/NOT GROUP parameter lookup through frozen compiled membership
frames, global conditional-noun promotion, duplicate witnesses, original mutable
parameter order and missing-name behavior. Original preprocessing oracle: 9,720
cases; production conversion/HAS/WORD/Undo coverage. Next: recursive membership
conditions and negative-source cross-group IS membership.

## M9.4Z — recursive GROUP member conditions

Previous-round subgroup substitution, ordered duplicate signatures, original
ten-change Infinite Loop bound and converged-base multiplicity. Rule-query loops
commit triggering command/movement/contact stages through whole-tree Undo.
Original preprocessing oracle: 2,592 cases, including 324 terminal oscillations.
Next: negative-source cross-group IS membership solver; prior nested-inversion
and remaining membership/MIMIC scope gaps remain explicit in GROUP.md.

## M9.5A — negative-source GROUP membership

Implement original evilrecursion declaration-presence iteration, negative-target
presence, destination replacement, duplicate edge products and ten-change lock.
Installed-source matrix: 6,144 cases including 3,024 loops. Triggering movement,
only-Undo and expansion bounds have production regressions. Next: remaining
ALL/NOT/LEVEL membership syntax, then GROUP-endpoint MIMIC; documented parity gaps
remain in GROUP.md.

## M9.5B — ordinary NOT subjects in GROUP membership

Preserve literal NOT declarations through group transfer/negative recursion,
then expand ordinary complements with concrete-name exclusions. Source matrices:
5,184 direct cases plus 6,144 negative-recursion cases (2,880 loops). Production
coverage includes channels, literal bans, Text exclusion, duplicates and Undo.
Next: ALL and scoped LEVEL membership, then GROUP-endpoint MIMIC.
