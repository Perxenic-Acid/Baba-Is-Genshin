# M9.3W：HOT / MELT

## 原作依据与执行

本机 Data/blocks.lua:block 的处理顺序是 SINK、WEAK、MELT、DEFEAT、OPEN/SHUT。
MELT 分支遍历 MELT 对象，再查同格 HOT；没有排除同一 ID，所以 HOT+MELT 会自熔。
SAFE 只保护被熔化的对象，安全的 HOT 源仍可熔化其他对象。普通实体不需要 YOU。
一轮 MELT 先选择整批受害者，再 handledels(...,true) 同步销毁；一个即将熔化的 HOT
源仍会参与本阶段其他受害者的判断。

`tests/reference_hot_melt.lua` 从已安装原作 blocks.lua 读取并执行原 MELT 片段，只替换
引擎对象查询/粒子/声音接口，核对接触、自熔、SAFE 受害者/热源、分离和同步受害者。

项目在现有冻结接触声明帧中按 SINK → MELT → DEFEAT 调度；每阶段重新投影当前实体与
条件，不在删除 Text 时重编译声明。MELT 的销毁、HAS 产物和实体分配器都属于同一回合
事务；后续阶段失败不允许留下已完成的销毁或产物。Undo 一次恢复整个回合。
同阶段新 HAS 产物不再次递归熔化，但 SINK 阶段产生的实体可进入后续 MELT 阶段。

## 支持范围

- 实体 HOT/MELT、同 ID 自熔、SAFE/NOT 覆盖。
- Text 与非 YOU 对象，重复 HAS 产物，原有方向/身份/指向保留约定。
- ON/NEAR、AND、ALL/NOT 条件展开与逐对象否定；WRITE 可写出 HOT/MELT 词块。
- CRASH 在 MELT 等销毁阶段之后检查，已熔化的 CRASH 不触发锁局。

EMPTY 的销毁/HAS 生命周期、作用域 LEVEL 的全图热源/熔化交互尚未实现。
LEVEL 物块作为实际实体仍可参与普通接触；这不等于作用域 LEVEL 热行为。
FLOAT 尚未实现，当前实际实体都处于同一交互层。

WEAK 与 OPEN/SHUT 暂未加入：它们除了重叠接触，还涉及推链受阻、撞墙、
接触 STOP 的解锁销毁等移动阶段行为。下一批应把它们接到原子移动/销毁/HAS 调度，
而不是只做同格销毁并让实际玩法失真。

## 真机测试

重新试玩根地图后：**D×5、W、D、D、F → MELT**。

- 初始 Avatar 在 HOT Rock 下方；可见规则 ROCK IS HOT、AVATAR IS MELT、AVATAR HAS CRATE。
- **W**：Avatar 进入 Rock 所在格并熔化，Rock 留下，生成一个 Crate，方向 Up。
- **Z**：恢复 Avatar、Crate 消失、实体分配器还原。
- 提供额外 AND、SAFE、NOT，可把 AVATAR IS MELT 改成带 SAFE 的规则，再验证免疫/否定。
  Rock 没有隐藏 PUSH，确保 W 实际发生重叠；Text 仍按默认 PUSH。
- SELECT 和 PARENT 保留，可按 D、F 返回；失去 YOU 不会剥夺 SELECT。
- **D、F → NAT** 也新增 HOT/MELT，可自由组合。

离线 `luatex --luaonly tests/run.lua` 覆盖真实 MELT 关输入、HAS/方向/分配器与整树 Undo，
以及非 YOU、Text、同步受害者、条件热源、多 YOU、SAFE/NOT、阶段顺序、重复 HAS、
晚期失败原子回滚。正常启动不运行完整自测，约 983000 条离线 Lua 指令，仍在 2000000
预算内；离线通过不替代本轮真机验收。
