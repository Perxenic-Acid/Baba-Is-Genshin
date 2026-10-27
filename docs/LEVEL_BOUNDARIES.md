# M9.3N：关卡边界与 SELECT

## 契约

进入/退出时，从定义重新加载离开和目标实例的运行态。位置、朝向、文字移动、
普通名词转换、创建/删除、实体分配器、局部历史与地图偏移均重置。
仅关卡作用域转换形成的父块外形及结果持续保留；实例身份与入口绑定不改变。
返回时，把重新投影得到的 SELECT 放回对应父块。整树 Undo 仍恢复边界前的完整运行态。

预设规则为 Text IS Push、Cursor IS Select、Line IS Path、Level IS Stop。
它们参与正常规则投影。Line/Path 是本项目抽象，原版路径来自地图数据。
LEVEL IS YOU 将整张地图偏移纳入原子 Plan/Preview/Commit/Undo；渲染同时移动底格与实体。

SELECT 不作为 YOU 参与 WIN 接触。LEVEL IS WIN 也必须有对象或关卡作用域 YOU
才获胜；仅有 SELECT 不会退出。DEFEAT 后 YOU 停止，SELECT 仍可移动/确认；
没有 SELECT 时只允许撤销。重载清除当前失败锁，但保留结果记录。
有 YOU 时原有有序终局矩阵继续成立，LEVEL 转换仍先于终局属性。

多关卡重叠时 F 打开菜单，不消耗回合；W/S 切换，F 或点击选项确认，Z/取消行取消。
最终确认由规划器重新检查候选实体 ID，不由 UI 修改关卡。菜单翻页每页最多八项。

## 原版依据

本机 `C:\Program Files (x86)\Steam\steamapps\common\Baba Is You\Data`：
load.lua 初始化世界、规则、撤销及地图偏移；mapcursor.lua 的 enter 与
enterlevel_multiple 分支负责多入口选择及返回光标定位；movement.lua 的
movecommand 开头用 LEVEL IS YOU 调用 MF_scrollroom 并记 levelupdate 撤销。
blocks.lua 约 3045–3113 行的 WIN 分支先找 YOU/关卡 YOU，再调用 MF_win；
SELECT 不在该检测中。原版完整浮空、解锁与失败销毁机制尚未复刻。

## 真机路线

每组从重新启动试玩开始，根 SELECT 初始 (2,2)。字母表示 WASD 键，F 交互。

| 验证 | 操作 | 预期 |
| --- | --- | --- |
| SELECT-only WIN | D 五次、W、F 进入 SW，再 D | 保持子关卡，SELECT 到父块；F 正常返回 |
| 有 YOU 的 WIN | A、S、F 进入 W，再 W | 正常获胜回父关卡，Z 恢复形成规则前 |
| DEFEAT | S、F 进入 D，再 W、D、F | YOU 停止，SELECT 可右移并返回 |
| 多目标菜单 | D 五次、S、F | YOU/P 两项；W/S/F 或点击；Z 只取消菜单 |
| 地图移动 | 上一组选择 YOU，W 形成 LEVEL IS YOU，再 D | 底格与物块一起右移；Z 撤销偏移 |
| 边界重置 | W、F 进 A，D 推箱；D、F 经父块返回，再 F 进 A | 箱子恢复初始位置；跨层 Z 恢复边界前状态 |

离线测试覆盖完整 bootstrap、菜单目标检查、原生渲染适配器、边界重置、
持久关卡转换、地图偏移验证与整树撤销。平台 UI 的实际事件仍需真机确认。
