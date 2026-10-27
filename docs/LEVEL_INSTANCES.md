# M9.3J：关卡定义与运行实例

普通谜题与地图使用相同的定义/实例结构；当前不按用途增加类型分支。
接口位于现有 world 映射脚本，无需新增编辑器映射。

## 数据与所有权

- 定义：`{id="puzzle", initial_world={...}}`，只包含可复用初始数据。
- 实例：`{definition_id="puzzle", instance_id="map/door-a", world={...}, history={...}}`。
- 同一定义可创建多个独立实例。实体 ID 和 next_entity_id 均局限于实例；
  跨实例引用未来必须同时携带 instance_id 与 entity_id。
- instance_id 由调用方提供，当前不引入全局计数器或唯一性注册表。
  创建两个相同 ID 的独立对象本身不会自动合并；父级管理器下一步负责去重。
- 定义、实例不共享可变表。调用方仍须将返回的权威快照当作只读，
  Lua 表未冻结；改变定义只影响以后显式实例化的结果。

## 接口

`RW_GetDefaultLevelDefinition()` 每次返回独立的默认演示定义。

`RW_CreateLevelDefinition(id, initial_world)` 校验并深拷贝输入。
`RW_InstantiateLevel(definition, instance_id)` 校验后复制初始世界并创建空历史。
失败返回 nil 和 invalid_level_definition / invalid_instance_id。

`RW_CreateSession()` 保持无参兼容入口，实例化 ruleworld.demo / root。
现有 PlanTurn、Preview、Commit、Undo 不需要定义对象参与；Commit 与 Undo
保留 definition_id / instance_id，已有不带这些字段的测试 session 也继续兼容。
重新实例化是创建新运行状态，不是覆盖现有实例的操作，也不会自动迁移历史。

定义只允许 id / initial_world；初始世界允许尺寸、实体、分配器和现有规则、
语言、语义、选择器、行为注册配置。校验身份、边界、六值方向、分配器和
Object/Text 初始形状，拒绝派生 traits/behaviors、历史、回调、元表、循环及
非有限数值。各注册配置的语义合法性仍由对应模块验证，本接口不重复实现。
空世界、重叠实体、稀疏稳定 ID 与大于当前最大 ID 的分配器均合法。

## 验证与边界

启动新增 RW_LevelInstanceSelfTest；离线 tests/levels.lua 覆盖模板深拷贝、
实例隔离、真实规则/调度/PUSH 管线、创建分配器、撤销和非法定义。
原有默认 TEXT IS PUSH、对象转换、方向和自测保持通过。

本步只建立所有权和身份边界。下一步建立父级实例集合、进入/返回、重复进入
保留状态的规则，然后定义跨层事务和 Undo 范围；尚未加入门户、进度或可见性。
