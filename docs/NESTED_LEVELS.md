# M9.3L：SELECT、确认与跨层原子撤销

M9.3N 的边界重置、地图移动和多目标菜单以 [LEVEL_BOUNDARIES.md](LEVEL_BOUNDARIES.md) 为准。

后续修订：关卡指向/转换和有序终局属性以 LEVEL_SEMANTICS.md（M9.3M）为准。

本文件取代 M9.3K 的局部撤销/自动踩格进入约定。用户真机测试指出其语义
错误，本步按用户修订和本地原版代码修正，不能将 K 视为玩法已验收。

## 对照原版

本地主要参考：`C:\Program Files (x86)\Steam\steamapps\common\Baba Is You\Data`。
`mapcursor.lua` 的 mapcursor_move / mapcursor_enter 独立读取 select 对象；
移动仅沿可用地图对象，进入有单独确认。`convert.lua` 的 dolevelconversions
处理当前关卡转换，并向上层传播转换结果。此处据其语义建立自己的小型实现，
并不声称已经复现路径解锁、全部 Meta、动画、持久存档和菜单系统。

## SELECT 与 YOU

行为注册增加 select、select_path、win 三种独立能力。默认属性 select/path/win
分别授予对应能力；you 仍只授予 control。任意 Object/Text 均可通过规则获得
SELECT，不根据 Avatar、实体 1、cursor 外观或 YOU 判断进入资格。

SELECT 的移动独立于 YOU：沿具有 select_path 的实体或有效关卡块移动，
不推动箱子。YOU 沿现有约束移动并推动。两种属性同时存在时，SELECT 能成功
移动则其定位优先；最终同一实体只写一个位置，不会移动两步。
当前未实现原版地图的完整解锁/可见性/路径限定符。

关卡块是实际实体，其 level_link 含 source_type、target=child/parent、
child 的 definition_id 与可选 label。M9.3M 修正：指向绑定实体 ID，
转换为别的外形后仍然可选；source_type 只用于显示原外形。父关卡块用 parent 指向当前栈顶父实例。
同一父实例内以关卡块 entity_id 作为 slot，反复进入复用子实例。

仅有 SELECT 与块重叠才产生候选，确认动作才进入。无候选拒绝；多个候选
打开选择界面，W/S 切换、F 确认，也可点击；Z 取消且不写历史。
候选按 ID 排序，同一关卡块不会因多个 SELECT 重复计数。

## 确认入口与键位

bootstrap.RW_ConfirmSelectedLevel() 是当前宿主确认入口，可由其他映射脚本
Invoke；调度器输入为 {type="confirm"}。它不依赖移动发生或某个固定角色。

用户最新澄清：直接使用 F 交互确认，不需要绑定物理 Enter。
KeyboardInteractKeyDown 调用同一确认入口，界面显示 F: Confirm。
踩块只选中，按 F 才进入；父关卡块也使用 F 确认返回。
公开键位声明排查来源：
https://github.com/DreamedWorker/miliastra-lua-types/blob/main/mihoyo_client_ui_api.d.lua
（这不是原生接口可用性的真机保证）。

## 原子事务与撤销

RW_PlanLevelAction 在现有纯 RW_PlanTurn 上组合完整树候选。
RW_CommitLevelTree 校验来源快照、候选实例身份、世界形状与导航结构，再一次
写入全局历史；RW_UndoLevelTree 恢复整步。旧 session Commit/Undo 仍是低层
世界工具，原生 Z 已完全切换到整树 Undo，不再从局部历史跨越导航断点。

快照包括全部实例、当前实例、导航栈、父槽绑定、进入块引用、分配器与结果。
确认进入/返回各是一条历史；有效移动与其导致的胜利/转换/退出合为一条历史。
拒绝动作不添加历史；新分支撤销后重放复用恢复后的实例分配器，未留下幽灵实例。
UI 显示 Undo steps，不把确认次数冒充世界回合数。历史仍最多保留 128 步。

三个退出路径：

1. SELECT 在父关卡块上确认：返回父实例，保留子实例状态。
2. YOU 与 WIN 同格：记录当前实例的 win 结果并返回父级；SELECT 单独接触 WIN
   不获胜。根关卡只记录结果，没有不存在的父级可返回。
3. LEVEL IS CRATE 等当前关卡转换：LEVEL 在语言中显式配置为 {tag="level"}，
   语义降低为 transform_level，不等同于普通 level_block 对象转换。
   整步转换进入时引用的父关卡块并返回；撤销恢复子关卡内动作前状态、父块、
   结果和当前层。LEVEL IS LEVEL 保护转换；多种不同目标暂拒绝，未实现一对多。
   根关卡没有父块时拒绝转换，整步不提交。转换与胜利同时产生时先处理转换。

## 测试样例和当前可测范围

RW_GetNavigationDefinitions 构造根地图和两份子关卡定义：
根中 SEL（实体 12）具有 SELECT，★（实体 1）只有 YOU，二者分开移动。
A=(2,1)、B=(1,2) 进入同一定义的两个独立实例；T=(3,1) 进入转换测试。
子关卡有父块 PARENT=(2,1)、独立 SELECT、Avatar YOU 和 WIN=(2,3)。
T 内从 (9,10) 向上推词可组成 LEVEL IS CRATE，退出并转换根地图中的 T。

当前真机手测（每组从重新启动试玩开始）：

1. 父块返回与撤销：W 选中 A，确认仍在 MAP；F 进入；D 推箱并让 SELECT
   移到 PARENT；F 返回 MAP；Z 应恢复到子关卡，箱子仍是推动后的位置。
   再 Z 撤销推动，再 Z 撤销进入，回 MAP。
2. 获胜退出：A、F 进入 B；S 让 YOU 接触 WIN，应自动返回 MAP；Z 恢复
   获胜前的子关卡状态。
3. 转换退出：W、D、F 进入 T；W 推词组成 LEVEL IS CRATE，应回 MAP，
   T 变成箱子；Z 回到转换前的子关卡，再 Z 回 MAP，T 恢复为关卡块。

新增启动日志：SELECT independent of YOU ...；pipeline SELECT confirm / parent /
win / level transform / tree Undo。版本标记见后续 M9.3M（LEVEL_SEMANTICS.md）。
离线 tests/level_transactions.lua 检查 SELECT/Text SELECT/撤回、YOU-only 拒绝、
三种退出、整树撤销/重放、坏计划/过期计划/投影失败整步拒绝。
原生输入测试通过 F 对应的已注册输入回调确认，覆盖上述三组手测流程。
