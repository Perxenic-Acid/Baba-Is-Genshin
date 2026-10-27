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

- Level destinations are identity-bound metadata, preserved across transformations.
  Never disable SELECT entry just because a linked object has a different archetype.
  Noun IS Level may create unusable level shapes without configured destinations.
- Preserve ordered LEVEL terminal properties: WIN then DEFEAT wins, the reverse
  defeats; conversion precedes terminal properties. Scoped WIN requires YOU, never SELECT.
  Defeat freezes YOU; SELECT can still move/confirm. Without SELECT only Undo.
  See docs/LEVEL_SEMANTICS.md for source locations and the exact test matrix.

- Boundaries reload authored runtime plus persistent scoped LEVEL transformations
  and results. Whole-tree Undo restores the pre-boundary runtime snapshot.
- Defaults: Text IS Push, Cursor IS Select, Line IS Path, Level IS Stop.
  Line/Path is our explicit abstraction over the original authored map paths.
- See docs/LEVEL_BOUNDARIES.md for M9.3N menus, scroll and test routes.

- Scheduled turns use sequential stages. Top-level changes is a checked diagnostic
  summary, never flatten it into a simultaneous plan. Child preconditions refer
  to the previous phase snapshot. See docs/PHASE_TRANSACTIONS.md.

- Ordinary contacts use a frozen post-conversion rule frame: SINK then DEFEAT,
  re-evaluating conditions and resolving targets for births/deletions. Do not recompile deleted
  Text halfway through these phases. HAS is triggered by destruction, not IS
  conversion; duplicate HAS instances must generate duplicate products.
  See docs/CONTACT_WORDS.md for source references, limits and manual routes.

- YOU + DEFEAT on the same entity causes destruction and HAS births. Original
  blocks.lua explicitly sets doit=true in the self-ID else branch; do not omit it.
