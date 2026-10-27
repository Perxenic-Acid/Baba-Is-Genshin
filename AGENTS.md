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

- Ordinary contacts use a frozen post-conversion rule frame: SINK then WEAK then MELT then DEFEAT then OPEN/SHUT,
  re-evaluating conditions and resolving targets for births/deletions. Do not recompile deleted
  Text halfway through these phases. HAS is triggered by destruction, not IS
  conversion; duplicate HAS instances must generate duplicate products.
  See docs/CONTACT_WORDS.md for source references, limits and manual routes.

- YOU + DEFEAT on the same entity causes destruction and HAS births. Original
  blocks.lua explicitly sets doit=true in the self-ID else branch; do not omit it.

- WORD readability is derived by RW_CompileWorld from grounded physical Text,
  never inherited from last-frame entity behaviors. Reader receives an explicit
  word_tokens overlay. Contact phases still reuse the frozen compiled frame.
- NOUN IS TEXT uses identity-preserving retype, not destroy/HAS. Text may retain
  level_link metadata. RHS NOT overrides grants/selected conversions.
  See docs/TEXT_WORD.md and docs/SPECIAL_NOUNS.md for current scope/test routes.

- WORD compilation is bounded to 200 iterations; loops commit the triggering board
  into world.infinite_loop and permit ONLY Undo (including SELECT/F lockout).
  Check after movement, conversion and contact deletion; render terminal boards
  without compiling them again. Do not regress this to rejecting the triggering move.
- ALL uses the authored ordinary noun vocabulary, excluding TEXT/EMPTY/LEVEL;
  NOT ALL expands to TEXT plus EMPTY. Ordinary A IS ALL retains A. A IS NOT A
  deletes via conversion without HAS. EMPTY is virtual occupancy, not persistent
  entities/IDs; current EMPTY lifecycle/HAS remains deferred. Preserve cell-based
  effects and never commit the negative-ID movement proxies.

- Parse actual token/role paths and real NOT prefixes. Never enumerate all possible
  prefix counts across the full grid: native startup hit the Lua time watchdog.
  Keep tests/run.lua's startup instruction budget. Optional UI event methods must
  be checked before binding; native controls can omit AddCursorEventListener.

- Normal OnStart must never run regression self-tests. RW_StartWithSelfTests is
  an explicit offline/fresh-host diagnostic entry only; never bind it to normal
  boot or a gameplay event. Keep the production startup budget (2M offline Lua
  instructions), and test real input/navigation with diagnostics disabled.
  Player-constructed in-level undefined/extreme behavior is not a reason to
  expand normal-startup defensive work. Preserve the agreed Infinite Loop rule.

- TOO COMPLEX is separate from INFINITE LOOP: physical sentence variants >=5000,
  parser traversal/output limits produce world.too_complex; WORD recursion and
  surviving CRASH produce world.infinite_loop. Both commit the triggering phases,
  block movement/SELECT/F/direct Commit and permit only Undo; render without recompile.
- WRITE uses explicit text products, preserves conversion multiplicity/identity/direction/links,
  respects IS identity protection and IS NOT TEXT plus WRITE NOT targets. SAFE protects
  each SINK/DEFEAT victim independently, never conversions or CRASH. Check CRASH on
  surviving real units after destruction using the frozen rule frame (EMPTY excluded).
  See docs/TERMINAL_WORDS.md for source references, tests and manual routes.

- ON/NEAR are per-identity spatial conditions, never one board-global Boolean.
  NEAR includes the same cell and eight neighbors, excludes the source identity;
  parameters joined by AND require distinct witnesses. Preserve original concrete-before-
  complement evaluation and ON NOT EMPTY counting. Relation conditions/exclusions must
  re-evaluate per conversion source and per HAS victim in the frozen contact frame.
- Canonical syntax supports subject AND and ON/NEAR clauses; keep complete physical
  sentence multiplicity and suppress interior subject/condition suffix parses.
  Existing alternate role orders keep their prior simple/RHS-AND behavior.
  WRITE syntax-word literals are an intentional extension requested by the user;
  do not accidentally accept them as IS/HAS noun arguments. See docs/SPATIAL_WORDS.md.

- HOT/MELT contact uses simultaneous victim selection within the MELT phase:
  only unsafe MELT entities die, self-HOT counts, HOT sources need not be YOU and
  may be SAFE. HAS runs once per victim using frozen declarations; keep MELT after
  SINK and before DEFEAT. Newly born products do not recursively melt in that phase.
  See docs/HOT_MELT.md.

- OPEN/SHUT unlock during movement before conversion and again after DEFEAT for
  overlaps. At least one unsafe participant bypasses partner PUSH/STOP; unrelated
  blockers still cancel the movement. Delete target before mover; HAS uses the
  death frame and source position, not the final movement snapshot. Keep these
  deletions/births in sequential atomic stages and whole-tree Undo. Both SAFE
  participants retain normal collision rules. See docs/OPEN_SHUT.md.

- WEAK has both blocked-movement destruction and contact destruction (after SINK,
  before MELT). Unsafe blocked YOU/PUSH shatters at its source with HAS; discard
  speculative dependency moves when that weak subtree fails. Free PUSH still moves.
  Bare WEAK STOP is permeable even when SAFE (original check excludes WEAK from
  STOP solidity independently of SAFE). HAS newborns skip WEAK contact for the
  current turn; conversions do not receive that grace. Keep the transient newborn
  set outside persisted world state. See docs/WEAK.md.

- FLOAT is a binary rule-derived contact layer. SINK/WEAK/MELT/DEFEAT/OPEN-SHUT
  contacts and ordinary WIN require matching layers, including movement unlock.
  STOP/PUSH remain solid across layers. WEAK STOP bypasses solidity only on the
  mover's layer. FLOAT does not filter ON/NEAR, text reading, SELECT or CRASH.
  See docs/FLOAT.md for the current projection timing and scope boundaries.

- Text activation is compiler-derived complete sentence membership, including
  AND/NOT/conditions, not the presence of a live target or successful condition.
  Only physical Text gets this highlight, not WORD objects. Pass the final WORD
  fixed-point AST activation IDs to the display projection; never persist them
  as world facts or reparse inside the renderer. See docs/REFERENCE_LEVELS.md.
- Reference layouts are generated by tools/import_baba_reference.py from the
  installed official MAIN/DATA layers. Keep provenance/hashes and --check parity.
  Preserve play-area coordinates/directions; adaptations are documented. Large
  boards scale within the existing renderer footprint. Keep native start <=2M.
