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

## M9.5C — ALL / NOT ALL GROUP membership

Keep literal ALL plus ordinary declarations and NOT ALL's TEXT/EMPTY copies.
Preserve source/RHS HAS asymmetry, exclusions and duplicate products. Full installed
addoption/subrules/grouprules oracle: 576 cases; production conversion/Undo checks.
Next: scoped LEVEL membership and GROUP/MIMIC integration, including ALL ordering.

## M9.5D — LEVEL GROUP membership

Typed membership/exclusions preserve physical and scoped LEVEL consumers, ordered
terminal outcomes, conversions, destination metadata and whole-tree Undo. Source
matrix: 144 cases. Conditional scoped consumers remain explicitly deferred under
the existing campaign-context condition boundary. Next: GROUP/MIMIC integration.

## M9.5E — GROUP / LEVEL MIMIC endpoints

Raw one-generation copies precede GROUP expansion; ALL membership normalization
now precedes MIMIC once. Source matrix: 1,152 complete-pass cases. Production
coverage includes empty groups, negatives, multiplicity, LEVEL and Undo. Remaining
endpoint/conditional parity gaps are documented; proceed with ordinary properties.

## M9.5F — TELE

Same-name networks, cross-name riders, source FLOAT/STILL filtering, immediate
source movement, once-per-turn riders and atomic snapshot RNG. Arrival contacts
and loop-triggering Text retain Undo. Source-loop oracle: 768 cases. MOTION grows
to 32x32 for its sparse TELE word. Native dynamic per-rider trait/BACK integration
gaps are recorded in TELE.md. Next: ordinary properties and startup-cost headroom.

## M9.5G — capability whitelist lookup

Replace the repeated string-comparison chain with a private implemented-capability
lookup built from the fixed built-in registry. Accepted capability vocabulary is
unchanged (verified against the previous chain); custom aliases still require a
nonempty Boolean capability specification. Full regression passes. Normal startup
uses 1,992,000 instructions versus M9.5F's 1,994,000; the 2M cap remains unchanged.

## M9.5H — BOOM

Add multiplicity-scaled square blasts after SINK, before WEAK, with independent
SAFE/FLOAT filtering, destruction/HAS and whole-tree Undo. Scope in BOOM.md.

## Scope update / BOOM source matrix

Skip 3D by user request. Color properties combine as stacked filters. Frontend
and authored level design remain separate deferred major workstreams. BOOM's
installed-loop oracle passes 256 radius/layer/safety/multiple-source cases.

## M9.5I — HOLD identity transactions

Persistent holder metadata, acquisition, collision-bypassing follow/release before
SINK, stale validation and Undo. Source/production comparisons and regression tests
cover the ordinary path; conditional/copy/scope gaps remain in HOLD.md. Deep clone
skips recursive scalar calls while retaining table keys/cycles, restoring startup
headroom under the unchanged 2M cap.

## M9.5J — scoped LEVEL HOLD movement

Shared movement restriction respects the map FLOAT layer and excludes virtual
EMPTY. Covers active/passive movement and HOLD transport; TELE retains its direct
update behavior. Scoped conditional evaluation and holder conversion gaps remain.

## M9.5K — fifteen colour filter backend

Named rules project canonical ordered palette-filter lists for units, EMPTY cells
and scoped LEVEL. Multiple colors coexist, same-color duplicates collapse, NOT and
retraction clear derived filters. Frontend blending remains deferred; see COLOURS.md.
3D is now explicitly excluded in the source catalog audit by user request.

## M9.5L — BROKEN status transaction prerequisite

Persisted binary status, ordered pure update planning, validated atomic changes
and installed-source parity (256 cases). Production rule gating/scheduling is
still pending; BROKEN is not marked implemented. See BROKEN.md.

## M9.5M — BROKEN saved-status query layer

Real-unit status gates unconditional/default effects, contextual queries,
conversions, HAS and predicate sources without removing physical Text or spatial
witnesses. Raw-declaration status refresh supports own-status bypass and negative
grants. Production status scheduling and public word registration remain pending;
see BROKEN.md. No native acceptance claim.

## M9.5N — before-input BROKEN status barrier

Native move/wait service prepends ordered status refresh to the same atomic turn,
recompiles only after actual status changes, and validates the combined plan.
Same-input disable/recovery, Undo, failure purity, terminal lockout and raw BROKEN
WORD gating are covered. Initialization/post-code/newborn/synthetic paths and
public registration remain pending; see BROKEN.md.

## M9.5O — pure post-code BROKEN plans

Compiler returns scoped Text/WORD status plans; movement/conversion barriers
apply them atomically before subsequent rules/contact queries. Covers Text blocking
its own conversion, SHIFT-driven retraction, conversion-created Text, WORD scope,
ordinary status latching, CRASH and Undo. Installed ordered/subset oracle expanded
to 512 cases. Initialization/late births/synthetic scope and exact WORD dependency
invalidation remain pending; BROKEN is not publicly registered. See BROKEN.md.

## M9.5P — creation-time BROKEN status

HAS/EAT/movement-death products, MORE and MAKE initialize BROKEN before later
phases against their raw/frozen source frame. Preserve pre-delete parent witnesses,
ordered products, per-death snapshots, allocator offsets, metadata and Undo.
Conversion-primary initialization, boundary boot, synthetic queries and recursive
creation-terminal preservation remain pending; BROKEN stays unregistered.

## M9.5Q — BROKEN conversion products

Native conversion adapter supplies raw declarations; primary, duplicate, BECOME
self and WRITE products initialize status before later phases. Query-only old
source witnesses preserve original create-before-remove ordering while keeping
persistent IDs/links and atomic Undo. Installed doconvert/brokenblock oracle covers
640 cases. Boot/boundary/synthetic and terminal-preservation gaps remain pending;
BROKEN stays unregistered. See BROKEN.md.

## M9.5R — BROKEN runtime boundary initialization

Boot, entry and return initialize only reloaded runtimes; selector placement receives
a final status refresh. No input/RNG/local history is consumed. Whole-tree Undo,
first-F gating and compile-limit terminal boundaries are tested. Synthetic scope,
late contact code invalidation and recursive birth-terminal preservation remain;
BROKEN stays unregistered. See BROKEN.md.

## M9.5S — final contact BROKEN code barrier

Contact/MAKE reading changes now apply final compiler status plans atomically.
Text releases before rendering/next queries; ordinary and disabled-WORD objects
retain saved status until input. Frozen contacts never rerun after release.
Regression covers delayed MELT, rollback, terminal trigger preservation and Undo.
BROKEN remains unregistered pending synthetic/lifecycle gaps. See BROKEN.md.

## M9.5T — virtual EMPTY BROKEN queries

EMPTY status is queried dynamically per cell from the current/frozen raw frame,
with the original ignorebroken bridge. Conditions, property cells and conversions
honor it without saved entities/IDs. Original query bridge and spatial/negative
regressions pass; LEVEL synthetic status and other BROKEN lifecycle gaps remain.

## M9.5U — unconditional scoped LEVEL BROKEN

Raw LEVEL BROKEN/NOT BROKEN gates scoped commands before outcome/conversion/HOLD
and POWER publication. Physical Level blocks keep independent saved status.
Compiler, installed virtual-query and tree Undo regressions cover this scope.
Conditional surroundings and remaining lifecycle gaps stay documented; see BROKEN.md.

## M9.5V — MORE/MAKE birth-status terminal preservation

Recursive status limits preserve products through the triggering newborn and stop
later phases. Atomic Commit/Undo retains allocator, input and planned RNG changes.
Real nested FEELING queries exercise the guard; HAS/conversion propagation remains
pending alongside other BROKEN gaps. See BROKEN.md.

## M9.5W — HAS status-limit trigger preservation

HAS preserves the triggering newborn and parent, earlier completed products/deaths,
and later unprocessed victims. All destruction slots stop and commit only-Undo
terminal plans; source frames, events, links and allocation restore with Undo.
Conversion status-limit propagation remains pending. See BROKEN.md.

## M9.5X — conversion status-limit trigger groups

Conversion returns a fifth terminal reason, preserving earlier sources and the
interrupted group's product prefix alongside its retained parent at fresh IDs.
Scheduler commits/locks before later phases; WRITE/BECOME/EMPTY, duplicate allocation,
source conditions and Undo are covered. Remaining BROKEN integration audit follows.

## M9.5Y — BROKEN public integration and orientation status

Registered default BROKEN and official documented-scope coverage after lifecycle,
terminal and navigation integration. Post-orientation code status now commits
atomically. Startup 1,926,000 instructions; remaining catalog properties: ANGRY,
AUTO, BACK, BEST, BONUS, CHILL, DONE, END, HAPPY, PARTY, PET, REVERT, SAD, WONDER,
YOU2. 3D is excluded; letters and frontend/level design remain deferred. Exact WORD
invalidation and conditional LEVEL scope remain documented semantic gaps.

## M9.5Z — YOU2 independent backend channel

Public YOU2 projects control2. Actions select player 1/2 with original secondary
fallback, including sleeping/EMPTY-list behavior; both channels count for contacts
and scoped WIN, remain separate from SELECT, and freeze on Defeat. Installed input
selection oracle: 256 cases. Simultaneous playerid=3 and native secondary bindings
remain deferred. Fourteen catalog properties remain pending; see YOU2.md.

## M9.6A — CHILL transactional random motion

Real-unit CHILL draws before displacement, shares MOVE counts/final facing,
reverses on blockage and respects sleep/locks. Random state survives scheduler
stages, Preview/Commit/Undo and RNG-only turns. Installed collection oracle: 384
cases. Virtual EMPTY/scoped LEVEL and exact original unitlist scheduling remain
recorded in CHILL.md. Thirteen official catalog properties remain pending.

## M9.6B — presentation-only property rule support

ANGRY/HAPPY/SAD/WONDER/BEST/PET/PARTY have real compiler/property capabilities and
an original-source-checked pure effect catalog. Conditions, FEELING, MIMIC, stacking,
NOT and BROKEN are exercised. Native particle playback and timing remain frontend
work, explicitly distinguished in the catalog audit. Remaining property backends:
AUTO, BACK, BONUS, DONE, END, REVERT; letters/3D/frontend/level design stay deferred.

## M9.6C — BONUS atomic collection and campaign total

Real-unit BONUS collects after MAKE before CRASH, retains YOU/BONUS multiplicity,
SAFE rewards, self/FLOAT behavior, HAS and pre-delete WIN evidence. Local counters
and persistent tree totals participate in Preview/Commit/whole-tree Undo and real
enter/return boundaries, including terminal HAS prefix commits. Installed contact
oracle: 72 cases. Scoped LEVEL/EMPTY and host reward presentation remain gaps.
Remaining property backends: AUTO, BACK, DONE, END, REVERT.

## M9.6D — DONE retirement and ALL completion

DONE retires real units without SAFE/HAS before MORE, preserves the frozen code
frame through MORE, and supports unconditional scoped LEVEL clearing. Literal ALL
DONE retains the original custom/editor target-count completion rule (including
duplicates), emitted as atomic win/event facts. PLAY preserves earlier DONE events.
112 installed oracle cases plus conversion/newborn/conditions/status/Undo routes.
Remaining property backends: AUTO, BACK, END, REVERT. See DONE.md for host/EMPTY gaps.

## M9.6E — END contacts and persistent ending facts

END supports ordinary/self/YOU2, scoped LEVEL/map FLOAT and virtual Empty contact
queries, including original Empty ordering/placeholder behavior. Capture before
BONUS removal; DONE/destruction and late CRASH retain priority. Record historical
ending facts with win/navigation in whole-tree transactions. Scoped YOU WIN also
uses real/Empty map-layer contacts. 337 installed source oracle cases; host credits/
base-game choreography and broader Empty lifecycle remain gaps. Remaining property
backends: AUTO, BACK, REVERT.

## M9.6F — AUTO unit motion and scoped count

Real AUTO now preserves original MOVE/AUTO/CHILL collection/reason precedence,
nonbouncing AUTO, duplicate impulses, common movement/destruction and atomic Undo.
576 installed collection/guard oracle cases plus native-pipeline simulations and
scoped AUTO_ON count checks. AUTO remains explicitly partial: next is LEVEL AUTO
queued input/pulses and simultaneous YOU/YOU2. BACK and REVERT also remain pending.


## M9.6G — dual-channel scheduled input

Added simultaneous player=3 per-channel cardinal/wait vectors, no fallback,
first-channel root precedence, virtual-cell intents, shared collision/death frame
planning, scoped LEVEL first-direction semantics and SELECT separation. Both
channels share one conversion/contact/creation transaction and one input/chance
advance/Undo. Both waits record IDLE. Installed movement.lua direction/seen-ID
collection oracle covers 400 combinations; phase tests cover blocked facing,
mutual contact, MORE once, invalid vector purity and Undo. Full original collision
scheduler and duplicate pre-collision facing writes remain shared parity gaps.
LEVEL AUTO command queuing/pulses remain next; no native timer is claimed.


## M9.6H — AUTO pure queue and pulse transactions

Implemented tree-owned channel queues with isolated queue-only validated commits,
original declaration-presence fallback, immediate non-AUTO commands and count-zero
clearing. Pure pulses use fixed initial scoped multiplicity and existing dual
turn plans, aggregate events and commit one whole-tree Undo transaction. Queueing
never advances input/chance/RNG/status or history. CRASH/complexity retain their
triggering prefix; ordinary late failure rejects the entire pulse. Added 60
installed syntax.lua command/command_auto adapter cases plus queue, weighted dual
movement, wait, stale/invalid commit, terminal and rollback tests. Native routing/
clock and exact deferred boundary/result ordering remain explicit AUTO gaps.


## M9.6I — conversion provenance and authored AUTO fallback

Added intrinsic optional original_name with implicit authored/newborn origins,
validation and immutable conversion preservation through primary/duplicate IS,
TEXT/WRITE/BECOME, virtual EMPTY and scoped LEVEL product/boundary paths. Normal
boot adds no initialization traversal. HAS/MORE/MAKE remain fresh lineages,
matching original addunit/create versus doconvert. REVERT is still pending;
see REVERT.md for exact source references and next steps. Also fixed AUTO input
fallback to inspect authored/default YOU2 declarations even with no matching unit.
Installed provenance assignment and new regressions verify source tracking,
creation resets, Preview/Commit/Undo and malformed/stale data rejection.


## M9.6J — REVERT ordinary conversion

Public REVERT now lowers indirect IS conversions plus queryable declarations.
Effective REVERT preempts ordinary/duplicate products, while unchanged origins
leave other conversions eligible. Preserved identity/NOT, contextual conditions,
Text origins, EMPTY deletion without HAS and allocator-free virtual EMPTY no-op;
GROUP/MIMIC/ALL and physical LEVEL blocks retain their usual identity/link behavior.
WRITE supports the REVERT literal; BECOME remains noun-only per original editor
argument typing. Installed convert() collection oracle covers 96 combinations;
public tests cover compiler, conversion, conditions, metadata and atomic Undo.
Scoped LEVEL reversion remains pending, explicitly partial in the official audit.


## M9.6K — scoped LEVEL REVERT

Unconditional scoped REVERT now restores the authored source entrance by removing
its saved conversion, rather than retyping a synthetic LEVEL unit. Retires the
whole previous product group (including copy entry), retains allocator tombstones,
rebases the child entry and returns via the existing parent boundary initializer.
Sibling persistence and scoped denial/identity/BROKEN survive; whole-tree Undo
restores the full pre-return transaction. Missing authored provenance rejects.
48 installed scoped selection-loop cases plus tree tests verify priority, shapes,
links, copy groups, reload/reset and Undo. Conditional/root scope and native save/
AUTO dispatch/general scoped >=50-product limits remain documented shared gaps.


## M9.6L — scoped conversion TOO COMPLEX boundary

Added original dolevelconversions() >=50 selected-product dispatch limit. Commit
the triggering child turn into TOO COMPLEX, leave parent products/progress intact,
and allow only whole-tree Undo. REVERT and identity protection apply before count;
earlier CRASH/terminal states remain authoritative. Preserved the project's
conversion-before-WIN order. Added 49/50/51 pipeline and AUTO prefix/queue tests,
plus six unchanged original dispatch branch cases. Native callback/WINTIMER timing
remains deferred with the previously recorded integration gaps.


## M9.6M — BACK operation-history prerequisite

RW_Commit now records owned phase operation journals beside local world snapshots,
including intra-turn net-zero motion, direction-only changes and lifecycle metadata.
RW_GetTurnRecord exposes cloned age-indexed data. Commit/Undo/tree checks preserve
alignment; rejection writes nothing, legacy frames stay unavailable, and the
128-turn cap/boundary reload/whole-tree Undo keep both histories synchronized.
An unchanged installed addundo() oracle verifies newest-first motion-row ordering.
BACK itself remains pending: activation clocks, playback and native index mapping
are not claimed by this prerequisite. See BACK.md for source details and limits.


## M9.6N — selected-frame BACK motion

Added a pure explicitly selected journal-frame motion planner: absolute historical
positions, direction-only updates, reconstructed implicit facing, paradox presence
and transient TELE suppression. Ordinary atomic Commit/Undo preserves identities
and links. Lifecycle history fails explicitly pending conversion playback. Added 72
unchanged installed BACK update-branch oracle cases. Public BACK registration,
activation clocks, native frame mapping and scheduler integration remain pending;
see BACK.md. No native-success claim or frontend changes.


## M9.6O — atomic BACK clock and native index primitives

Added stale-checked intrinsic back_init changes with Commit/journal/Undo, explicit
eligible-set status planning and native-buffer index calculation. 624 unchanged
installed status/index branch cases cover activation, loss, failed conditions,
retained clocks and dead units. Preserve the absent nonpositive-frame case.
Scheduler eligibility, native-count/journal mapping, pruning and lifecycle clock
inheritance remain pending; public BACK remains unregistered. See BACK.md.


## M9.6P — BACK native-frame mapping and historical motion selection

Added opt-in atomic native open-frame counts and explicit retain/prune decisions
beside user-facing command history. Native frame queries map current prefixes or
retained operation journals and paired snapshots; capped/legacy history is explicitly
unavailable, never silently retargeted. Added per-identity clock-driven motion
selection, absent-frame retention and transient scheduler hints. 1,260 unchanged
installed newundo() oracle queries plus staged playback, rejection, cap, local/tree
Undo and boundary tests pass. Public registration, production retain decisions,
status timing and lifecycle playback remain pending; see BACK.md.


## M9.6Q — BACK primary conversion restoration

Added exclusive stale-checked back_restore transactions and combined historical
playback for one primary transform/retype. Restore the preceding source shape,
facing/links/follow memory/BACK clock at the current position, with fresh origin,
BROKEN/holder and display defaults; no HAS. Clock-ledger motion selection now uses
this path. 54 unchanged installed create/remove branch oracle cases plus atomic
stale/conflict, motion-handle and source-clock/Undo tests pass. Branched/repeated
lifecycle history remains explicit pending provenance/identity work; production
BACK registration/scheduling and host disposal parity are not claimed. See BACK.md.


## M9.6R — ordered conversion provenance for BACK

Added source snapshots/EMPTY cells, ordered product IDs and source-removal facts
as owned conversion-phase journal metadata. Preserve duplicate branches, ALL
retention, no-op same-name BECOME/WRITE and interrupted allocated product prefixes.
Validate source/product preconditions atomically; route real scheduler events into
Commit/Undo. BACK primary playback now recognizes recorded same-name conversions.
48 installed convert() identity-order cases and pipeline/terminal/ownership tests
pass. Branch restoration/native duplicate logical identity and production BACK
scheduling remain pending; see BACK.md.


## M9.6S — full-frame BACK branch and repeated conversion playback

Added native logical history identities alongside unique instances, full-frame
update/create/remove normalization and clock-selected branch playback. Match every
create with every removal partner, preserving repeated restoration multiplicity,
source-base paradox guards and current-position source restoration. Ordinary births
without partners disappear without HAS. Extra products allocate atomically; aliases,
source facts, native create/back bases and allocators restore with Undo. Fresh
conversion/scoped copies do not inherit aliases. New-format journals distinguish
ordinary births; ambiguous legacy creation provenance rejects explicitly. Added 24
unchanged installed branch/repeated/birth oracle cases and alias/motion/clock/Undo
tests. Production scheduling/status timing, shared-ID FOLLOW/HOLD lookups and
TELE/reading integration remain pending. See BACK.md for scope and limits.


## M9.6T — FOLLOW/HOLD shared-identity memory

FOLLOW now remembers native history identity across restored aliases while
excluding only the physical source. HOLD acquires logical source IDs, checks HOLD
presence by logical ID and follows the first matching unit from the full list,
even a non-HOLD alias. Retain actual-instance locks/FLOAT checks and atomic stale
memory updates. Allow logical self-ID acquisition only with another matching
instance. Added 750 installed FOLLOW and 128 HOLD/getunitid oracle cases plus
Commit/Undo tests. Native creation/reinsertion list order remains separate work;
see BACK.md. BACK production scheduling remains pending.


## M9.6U — persistent unit-list order for BACK/FOLLOW/HOLD

Track optional physical unit_order through structural Preview/Commit, including
same-name conversion reorder without shape changes. Keep flat independent plans
permutation-invariant and preserve explicit native lifetime order via unit_sequence.
FOLLOW/HOLD, conversion sources and BACK selection/playback now consume that order.
Validate complete lists, persist phase metadata and restore order with local/tree
Undo or authored boundary reload. Added 80 installed append/remove/lookup structural
turns, 750 noncanonical FOLLOW and 128 HOLD cases, plus ordering/validation/boundary
tests. Existing BROKEN and other solver scheduling contracts stay unchanged;
production BACK status/scheduling/TELE/reading barriers remain pending.

## M9.6V — BACK-to-TELE solver handoff

TELE consumes validated transient physical-ID suppression from BACK, respects
runtime unit-list order and skips RNG for suppressed riders. Keep alias/retired
handle semantics and source transport independent from rider suppression. Expanded
the installed TELE oracle to 6,144 cases and added sequential BACK/TELE atomic
Commit/Undo tests. Production BACK activation/scheduling and transient routing
remain pending; no public BACK registration yet.

## M9.6W — isolated mapped BACK services

Remove BACK's reliance on world globals inside the separately mapped movement
script. Inject validated preview/frame/row/restore/identity services, bind native
Invoke adapters and forward suppression through the native TELE adapter. Separate
Lua environments verify status, native clocks, historical/current playback,
branches/repeated conversions, aliases, TELE handoff, diagnostics and Commit/Undo.
This fixes the host boundary before production scheduling; public BACK activation,
retain decisions, birth clocks and reading barriers remain pending.

## M9.6X — session-aware BACK production scheduler

Production level actions now supply the active session to RW_PlanTurn. Keep a
native retained-frame ledger separate from user Undo commands; refresh BACK clocks
after before-input BROKEN status and replay after FOLLOW. Include status/input/RNG
prefixes in current-frame history without flattening phases. Route transient tags
to TELE, discard tags of retired riders, and apply the post-BACK Text/WORD code-status
barrier. Compile limits commit the triggering board; errors reject atomically.
Added 392 installed retention/pruning oracle cases plus compiler/session tests for
conditions, current/past frames, FOLLOW/TELE, reading barriers, terminal states,
replay and local/tree/boundary Undo. Boot/birth/conversion clocks, restored newborn
status/grace, paradox and synthetic scope remain; public BACK stays pending.

## M9.6Y — BACK newborn clocks and saved-clock reset

Carry the session native count through conversion/HAS/MORE/MAKE/EAT/BONUS services
as explicit transient arguments. Newborns reset inherited clocks, initialize BROKEN,
then query BACK in the current raw/frozen source frame; primary-ID reuse and
same-name BECOME receive validated clock updates too. Keep source witnesses and
ordered duplicates. Recursive status limits preserve earlier clocks and zero on
the triggering product without speculative source replacement. Boot/boundaries
clear saved runtime clocks without creating an activation/history/input/RNG pass.
Added 648 installed reset/status oracle cases, scheduled lifecycle/terminal/Undo
tests and isolated Invoke count propagation. Native SHIFT no-op history rows,
restored WEAK grace, paradox and synthetic scope remain; BACK is still pending.

## M9.6Z — BACK restoration WEAK grace

Follow installed addunit(...,true) newborn handling: both back_restore and
allocated restoration products skip WEAK contact for their restoration turn.
Keep grace transient and preserve ordinary conversion behavior. Real-journal
tests cover primary/duplicate/repeated conversions, allocated cartesian products,
expiry on next input and Undo. Native SHIFT no-op history, paradox and synthetic
scope remain; public BACK is still pending.

## M9.7A — ordered SHIFT history for BACK

Keep an explicit phase-owned motion_history path, including every unchanged
SHIFT alignment and intermediate stacked-source facing. Validate its stale
preconditions and agreement with the atomic final summary; journal owned rows
without persisting them in world state. Honor unit-list source/rider order.
BACK consumes those rows once, preserving no-op TELE suppression and net-zero
motion retention. Direct alignment rows never independently set updateundo,
including changed facing. Added 384 installed alignment oracles, 32 inverse-path scenarios,
complete/isolated scheduler routing, ownership, rejection and Undo coverage.
Native phase-graph/conditional differences, paradox and synthetic scope remain;
public BACK is still pending.

## M9.7B — public BACK and source-confirmed special scope

Register BACK in the default property vocabulary and behavior registry. Preserve
the existing session-aware production path and history/Undo contracts. Public
tests cover activation, FEELING, NOT/BROKEN, WORD sentences, linked real LEVEL
blocks, inert synthetic LEVEL/EMPTY, production tree actions and reload/Undo.
32 unchanged installed selection oracle cases confirm that BACK ignores virtual
EMPTY and enumerates real LEVEL/Text through unitlists/codeunits. No synthetic
map-wide BACK branch exists in levelblock(). Vanilla Lua has no active paradox
writer; its sole indexed assignment is commented out. Explicit helper guards stay.
The official catalog marks public BACK partial, retaining native phase, duplicate
declaration/retired-handle, opaque lifetime and 128-frame integration limitations.
Startup remains below 2M; no frontend or authored-level changes are included.

## M9.7C — journal effective dispatched BACK paths

Preserve intermediate BACK updates that cancel in the final summary. Use installed
update/updatedir dispatch behavior: pure no-ops emit no new history, though matched
historical rows still suppress TELE. Retired handles discard queued paths/marks.
Validated per-row journal anchors represent native immediate create/remove before
the final queued movement dispatch, including mixed unrelated physical identities.
144 installed queue/dispatch history oracles, a retained-frame scheduler replay,
mixed restoration, anchor/stale rejection and Undo tests cover the change.
Duplicate declaration/native phase/lifetime gaps remain; BACK stays catalog-partial.

## M9.7D — repeated BACK declaration motion queues

Separate per-unit eligibility/clocks from ordered declaration instances. Forward
the optional instance list through production and isolated Invoke adapters; replay
each surviving handle's matched actions in declaration then unit-list order.
Keep one atomic final write per physical ID while journaling repeated intermediate
updates, preserving separate handles with shared logical identity. Validate list
coverage and filter inactive/absent-frame selections without fabricating history.
The installed dispatch-history oracle expands to 432 cases. Physical duplicate
sentences, ordering, aliases, malformed instances and Undo are covered. Repeated
retired MF_* handle behavior/native phase gaps remain; BACK stays catalog-partial.

## M9.7E — BACK zero-net Text code-status barrier

Use effective BACK motion history to detect physical Text reading invalidation
even when the final movement/facing summary is empty. Preserve the one-pass
compiler status barrier before contacts and exclude pure dispatched no-ops.
Real TEXT ON AVATAR IS BROKEN tests cover displacement/turn cancellation,
no-op latching, both terminal compile limits, atomic failure and Undo. The 432
installed dispatch oracles additionally verify native updatecode behavior.
Exact WORD dependency invalidation and other recorded native gaps remain.

## M9.7F — SHIFT zero-net Text code-status barrier

Observe effective validated SHIFT motion history at the existing movement
code-status barrier, so blocked Text turns cancelled by final alignment still
refresh reading status before conversion. Direct alignment-only rows do not
independently invalidate reading. Real solver/compiler tests cover the zero-net
path, one status pass, no-op alignment and Undo. No frontend/level changes.

## M9.7G — phase-aware movement reading events

Exclude direct SHIFT alignment from code-status invalidation even when its final
facing differs. Accumulate reading events per phase snapshot, taking journaled
dispatches instead of double-counting their final atomic summaries. Keep ordinary
movement, destruction/birth and unjournaled service changes on their existing
path. Real compiler/solver tests verify latching, direction/Undo and fallback;
384 installed alignment oracle cases verify no native updatecode assignment.

## M9.7H — remove history eviction from BACK and whole-tree Undo

Remove the early 128-command cap from both Commit surfaces, matching installed
undo.lua's uncapped retained-frame history. Preserve native pruning, absolute
clocks, aligned journals, legacy unavailable prefixes and boundary resets.
The 1,260 installed newundo frame queries now require all retained frames after
180 commands; actual BACK replays the first frame across the former cutoff.
Local full Undo and 165-turn whole-tree/reload restoration are covered. History
memory grows with accepted play; frontend/design and other BACK gaps stay open.

## M9.7I — scoped LEVEL BECOME

Connect unconditional LEVEL BECOME noun/Text/LEVEL to the existing boundary
transaction. Keep BECOME separate from IS identity protection and negative
property bans, preserve ordered duplicate products, suppress scoped BROKEN and
reuse the 50-product terminal limit. BECOME LEVEL selects original scoped REVERT.
Real compiler/tree tests, 32 installed selection oracle cases and physical
49/50/51-product boundaries cover the change. Conditional scope, ALL/EMPTY and
self-negative level destruction remain explicit gaps in BECOME.md.

## M9.7J — scoped LEVEL BECOME ALL / EMPTY

Expand scoped ALL to the authored ordinary palette with duplicate multiplicity
and explicit ALL-origin denial tracking. Keep literal products independent of
BECOME NOT ALL and honor per-noun bans. Recognize EMPTY as no scoped product while
retaining physical Level-block deletion. Compiler/tree/Undo tests plus unchanged
installed subrules/conversion queue oracles cover these paths. Conditional scoped
LEVEL and self-negative level destruction remain explicit BECOME gaps.

## M9.7K — scoped LEVEL BECOME NOT LEVEL destruction

Lower the self-negative conversion to the original error/destroylevel request,
then atomically clear real units at the end of ordinary turn phases. Ignore SAFE,
never run HAS, retain allocators and full Undo, and do not create a new terminal
lock. Suppress stale outcomes for destruction-only turns while preserving separate
conversion/revert requests and the existing boundary reset. Scope BROKEN and
prior-DEFEAT SELECT authorization remain effective. Compiler/tree/rollback tests
and installed total-delete/error-selection oracles cover the change; exact native
callback timing and conditional scoped surroundings stay documented gaps.

## M9.7L — scoped LEVEL input/chance prefixes

Introduce a shared scoped condition path for IDLE/OFTEN/SELDOM and their logical
combinations. Keep the synthetic map identity separate from physical level blocks
and preserve their original per-identity conditions, activation and pure chance
state. Existing scoped BROKEN, conversion/protection/outcome/destroy transactions
consume the selected commands unchanged. Tests cover real compiler/tree actions,
64 pure chance plans and expanded installed prefix oracles. Parent spatial/query
conditions remain explicitly deferred; see LEVEL_CONDITIONS.md.

## M9.7M — scoped LEVEL POWERED and dynamic query frame

Extend scoped conditions to all three POWERED channels. Preserve raw conditional
LEVEL property declarations in the transient query frame; evaluate synthetic
BROKEN with its nested bypass and remove stale aggregate power snapshots.
Compiler/tree tests cover grounding, input-dependent power/BROKEN, frozen source
deletion, channels and Undo. The installed POWERED oracle uses conditional scoped
declarations across 1,080 cases. Full regressions pass; startup stays 1,979,000.
Parent surroundings and FEELING instance semantics remain explicit gaps.

## M9.7N — scoped LEVEL LONELY

Installed conditions.lua lonely() explicitly sets failure=true for unitid=1.
Support scoped LONELY/NOT LONELY without inventing parent occupancy; preserve
ordinary physical Level per-identity queries. Compiler/tree/Undo tests and the
expanded 30-case installed oracle cover both paths. Parent-dependent spatial
conditions and FEELING instance counting remain deferred.
Full regressions and catalog/layout audits pass; startup is 1,980,000 instructions.

## M9.7O — scoped LEVEL FEELING

Adapt raw scoped properties to the existing condition-instance query, preserving
condition identities, failed consumption, duplicates/complements and denial/BROKEN
gating. Admit FEELING in scoped conditions without physical-block substitution.
Tree conversion/Undo and frozen-input queries pass; installed normalized FEELING
comparisons now include the map (5,760 cases). Full regressions and catalog/layout
audits pass; startup remains 1,980,000. Parent-dependent spatial conditions and
pathological recursion/postrules equivalence remain documented gaps.

## M9.7P — scoped LEVEL WITHOUT and real level count mapping

Admit global WITHOUT/NOT WITHOUT in scoped conditions. Normalize real level_block
names and synthetic source identity for original LEVEL quota/self adjustment.
Tree conversion/Undo cases cover ordinary/duplicate/complement/negative clauses;
the installed normalized oracle expands to 20,736 cases across map, real levels,
Text, Empty and ordinary observers. Preserve the documented stable complement
witness order instead of native table hash ordering. Parent spatial conditions
remain deferred; no frontend or authored layout changes.
Full regressions, catalog/layout audits and diff checks pass; startup remains
1,980,000 instructions. Native acceptance is not inferred from offline checks.

## M9.7Q — entry-time LEVEL surroundings snapshot

Capture the original nine-region name/direction record before parent reset, then
store validated semantic boundary metadata on the child runtime. Reload preserves
it; fresh entry replaces it; whole-tree Undo restores the pre-entry runtime.
Respect custom unit order, stacked names, Text/Level naming and native empty-cell
sentinels. Installed getlevelsurrounds oracle, malformed-data checks, reload and
Undo tests pass with full regressions; startup stays 1,980,000. This is transport
infrastructure: scoped parent-spatial consumers are the next integration step.

## M9.7R — scoped LEVEL ON / NEAR / NEXTTO

Consume entry surroundings and live/frozen child contents using the original
synthetic LEVEL branches: child quotas before reusable parent names, native Text
and Level special cases, EMPTY witnesses, NOT and diagonal synthetic NEXTTO.
Preserve physical-block semantics separately. Real compiler/tree conversion/Undo
checks and 9,216 installed normalized source cases pass. Remaining scoped spatial
branches are documented in LEVEL_CONDITIONS.md; frontend/layouts remain deferred.
Full regressions, catalog/layout audits and diff checks pass; startup remains
1,980,000 instructions. Frozen-frame child deletion is covered independently.

## M9.7S — scoped LEVEL directional spatial conditions

Add ABOVE/BELOW/BESIDELEFT/BESIDERIGHT using native global-child then single-parent-
side branches. Preserve ordinary physical rays separately, repeatable parent
names and Text/Level special cases. Record native ABOVE/BESIDELEFT EMPTY's missing
unitlists lookup; normalize absence to an empty list without startup errors.
Expanded installed comparisons cover 43,008 cases; tree conversions/Undo cover
all directions, wrong sides/diagonals, child witnesses and EMPTY asymmetry.
Full regressions and catalog/layout/diff audits pass; startup stays at 1,980,000
instructions. No native success claim is inferred from offline checks.

## M9.7T — scoped LEVEL FACING

Select the parent snapshot region using entry-time direction; match reusable
literal names with no child-grid search. Preserve native synthetic direction/EMPTY
argument quirks and none-direction behavior, separately from physical FACING.
Compiler/tree conversion/Undo and 1,040 installed source cases cover the change.
FACEDBY/SEEING remain explicit scoped gaps.
Full regressions and catalog/layout/diff audits pass; startup remains 1,980,000
instructions. Native acceptance is not inferred from offline checks.

## M9.7U — scoped LEVEL SEEING

Use native synthetic observer (0,0) ray-boundary behavior and saved entrance
name/direction matching. Keep physical ray/occlusion queries separate. Combined
FACING/SEEING original function comparisons cover 2,080 cases; compiler/tree
conversion and Undo tests run both conditions. FACEDBY remains the next scoped
spatial gap; frontend and authored layouts remain deferred.
Full regressions and catalog/layout/diff audits pass; startup remains 1,980,000
instructions. No native acceptance claim follows from offline checks.
