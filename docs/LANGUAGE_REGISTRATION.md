# M9.3H：可配置语序与关系语义注册

本轮落实语言与语义边界的一部分，不新增实际关卡词汇。Reader 仍负责横向/
纵向空间读取，Parser 将文字角色规范为 subject/verb/object AST；语义层将
关系 ID 降低为既有属性 IR 或转换声明，随后交给原有行为系统和原子回合。

## 三个独立配置

1. `world.language`：词汇映射、物理语序和关系词的可解析类别。
2. `world.semantics`：规范化关系 ID 对应哪些已实现的语义能力。
3. 世界内核与行为系统：按 IR 投影与求解，保持和具体单词、排列无关。

`language.order` 是 subject、verb、object 的一个三元素排列，支持全部六种
排列，省略时仍为 subject/verb/object。NOT 紧邻其修饰的主语或宾语之前；
来源 entity_ids 始终保持物理读取顺序。只有真正的前置 NOT 长句可以抑制
共享同一物理词块后缀的短句，不能误执行一个去掉否定的正句。

## 不可变式注册接口

```lua
local verbs = RW_RegisterVerb(RW_GetVerbRegistry(), "bind", {
    phase = "relation", rhs = {property = true, noun = true}
})
local semantics = RW_RegisterSemantics(RW_GetSemanticRegistry(), "bind", {
    property = "grant_trait", noun = "transform"
})
world.language = {
    nouns = {BOX = "crate", HERO = "avatar"},
    verbs = {LINK = "bind"},
    properties = {SHOVE = "pushable", DRIVE = "you"},
    order = {"object", "verb", "subject"},
    verb_registry = verbs
}
world.semantics = semantics
```

这是逻辑接口示例；游戏内 grammar/rules 分属映射脚本，宿主通过对应
`Invoke` 调用这些方法，传递纯数据表，不假定跨脚本全局函数共享。

- Get 方法返回副本；Register 方法返回新表，不修改输入或模块默认注册表。
  重复关系 ID 与无效规格拒绝，不支持隐式覆盖。
- `language.verb_registry` 省略时使用既有 AST_VERBS。规格仅含 phase 和 rhs，
  rhs 支持 noun/property/special 类别；phase 是关系描述元数据，不是新阶段
  或该行为已经实现的保证。
- `world.semantics` 省略时使用默认 IS 规格；显式空表表示不赋予任何关系
  可执行语义。注册解析能力与注册可执行语义彼此独立。
- 目前可注册能力限于 property=grant_trait、noun=transform，可只启用其中
  一项。转换沿用身份保护和冲突策略。未注册或超出已实现范围的 AST 原样
  deferred，不因语法认可它而偷偷执行。
- Registry 是配置数据；本轮不接收插件回调，也不声称能随意添加操作码。
  当前未实现的 NOT/special/nested Text 等语义继续保留在 deferred。
- 旧 RW_CompileRules 保留为默认语言的迁移校验路径；新配置用于实际 AST
  管线，不扩展旧编译器。没有新增脚本映射。

## 验证闭环

`CRATE IS PUSH` 与 `SHOVE LINK BOX` 使用不同的词汇、语序和关系 ID，得到
相同的规范化属性 IR（来源信息另计）、实际效果和移动计划。启动管线另
比较多 YOU、对象转换、方向、Commit/Undo，并确保测试不改动实际关卡。
离线 tests/registration.lua 检查六种排列与四种否定组合、物理来源 ID、
注册隔离、身份保护、按 RHS 能力 deferred，以及非法配置拒绝。

后续仍需统一选择器与行为注册边界；本轮不能作为这两部分已完成的依据。
