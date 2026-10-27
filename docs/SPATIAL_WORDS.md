# M9.3V：WRITE 语法词、主语 AND、ON / NEAR

## 依据与有意扩展

本机原作 Data/conditions.lua 的 on/near/testcond：逐对象检查几何位置；NEAR 包括中心和
八邻域，不把对象自身当作目标。相同条件内的多个参数消耗不同目标；具体参数先于否定参数
检查，具体参数倒序、否定参数保留原序。NOT ON A 是否定整个条件，ON NOT A 是寻找另一种
非 Text 对象，二者不同。参数 ALL 展开普通词表，NOT ALL 展开 Text、Empty。
普通对象 ON LEVEL/NEAR LEVEL 可使用当前关卡的隐式 Level 一次，再出现 LEVEL 要找实体。
原版 ON NOT EMPTY 会计数所有尚未占用的同格对象，单个参数遇到两个对象可能不成立；按原作保留。
独立运行原条件代码：`luatex --luaonly tests/reference_spatial_words.lua`。

原作 Editor/editor_objectlist.lua 的 text_write 默认 argtype={0,2}，只接名词与属性。
本轮按用户要求有意扩展 WRITE：已注册谓词 IS/HAS/WRITE、介词 ON/NEAR、连接词 AND
可直接写成对应词块。它们的 AST 类别是 literal，只有 WRITE 接受，不会变成 IS/HAS 的名词。
NOT 仍作为否定操作符，不作为这轮可写出的独立字面参数；任意未注册词和任意 Meta 深度仍未接入。

## 语法与求值

默认主谓宾语序支持：

- ROCK AND CRATE IS SAFE AND WORD：两主语 × 两宾语。
- ROCK ON CRATE IS WORD：只有与 Crate 重叠的 Rock 获得 WORD。
- ROCK NEAR FLAG IS SAFE：含同格、斜邻格，排除 Rock 自身。
- ROCK NOT ON CRATE IS SAFE / ROCK ON NOT CRATE IS SAFE。
- ROCK ON CRATE AND CRATE IS WORD：必须有两个不同 Crate。
- ROCK ON CRATE NEAR FLAG IS SAFE：多个条件同时满足。
- ROCK AND CRATE ON FLAG IS WORD：条件应用于所有列出的主语。
- ROCK ON CRATE WRITE AND / ROCK ON CRATE HAS FLAG：逐来源身份检查条件。

主语和条件参数的后缀不应再偷偷解析出无条件规则；真实重叠的文字路径仍保留重复结果。
RHS AND 继续保留整条物理句子的乘法重数。非默认的五种角色语序保留既有简单语法/RHS AND，
本轮不扩展它们的主语 AND 与介词位置。

属性效果在 ResolveEffects 中逐实体/空格坐标筛选。WORD 仍从实际 Text 冷启动求解。
转换、身份保护、否定转换按每个来源对象的转换前快照求值；WRITE NOT/HAS NOT 的条件以
exclusions 保留，不在编译时对整个类型一刀切。HAS 在冻结规则声明内，对当前销毁受害者
的位置重新求值，生成物与销毁属于同次 Commit/Undo。

## 仍有边界

- 作用域 LEVEL ON/NEAR … 尚缺父地图 surroundings 上下文，明确 deferred；不冒充全局真值。
- EMPTY 属性按当前投影中的空格坐标筛选，不能把带条件的属性提升为所有新空格的全局属性。
  同一步移动中刚空出的格子的条件重求值、EMPTY 销毁/HAS 生命周期仍待后续补齐。
- 条件之间使用连续 ON/NEAR；本轮不扩展 AND 连接不同谓词、其他介词或 GROUP/MIMIC。

## 真机测试

重新试玩根地图后：

- D、F → NAT：新增 ON、NEAR 和第二块 AND；WRITE/SAFE/CRASH/HAS/SINK 保留。
- D×5、W、D、F → COND（右上扩展的一格，不改变原重叠选关菜单）：
  左侧 Rock 初始在 Flag 下方，尚无 WORD；右侧 Rock 邻近 Crate，已有 WORD。
  第一次 W：把左侧 Rock 推到 Flag 上，获得 WORD。
  第二次 W：推离 Flag，WORD 撤回。
  连按 Z：分别恢复重叠时/拼接前状态。
  第三条可移动规则 CRATE AND FLAG IS SAFE 用于主语 AND；所有句子都可拆改。

离线 `tests/run.lua` 覆盖上述真实输入路线，以及逐实体条件、NOT/重复参数、ALL/NOT ALL、
WORD、条件转换/WRITE/HAS、条件否定、AND 物理重数与 Undo。原有 Too Complex、Infinite Loop、
方向、导航和接触词回归继续通过。正常启动不跑完整自测，约 938000 条离线 Lua 指令，
仍受 2000000 条预算约束。离线通过不代表已完成本轮真机验收。
