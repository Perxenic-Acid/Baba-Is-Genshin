# RuleWorld workspace instructions

- This repository is the live Genshin UGC level directory. Preserve all user
  modifications to `1073741831.gil`; never overwrite or stage it with Lua changes.
- Before implementing Baba Is You semantics, inspect the relevant original files
  under `C:\Program Files (x86)\Steam\steamapps\common\Baba Is You\Data`.
  Use this local primary reference repeatedly, not recollection or prior assistant
  suggestions. User requirements take precedence. Record any deliberate gaps.
- SELECT and YOU are separate rule-derived capabilities. Only SELECT may select
  level blocks. Movement onto a block does not enter it; confirmation is separate.
- The user clarified that F interaction is the intended confirmation key. Bind
  KeyboardInteractKeyDown to the separate confirm action; physical Enter is not required.
- UI must not own navigation or progress facts. User-facing Undo restores whole
  tree transactions, including active level, parent/child state and allocators.
- Keep the eight existing mapped scripts unless a deployment change is necessary.
  Verify with `luatex --luaonly tests/run.lua`, inspect the actual repository diff,
  and stage explicit files. Do not infer in-game success from offline tests alone.
