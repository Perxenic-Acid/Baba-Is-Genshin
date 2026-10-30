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

- SHIFT collects same-layer non-self riders after YOU, before rule recompilation
  and conversion. Each distinct source adds an impulse, first source sets its
  direction; duplicate SHIFT grants do not multiply a source. Use the ordinary
  PUSH/STOP/WEAK/unlock solver, record deaths/HAS and blocked facing, then align
  surviving final co-occupants. Keep SHIFT and shift destruction as sequential
  atomic stages. Wait consumes a turn without moving YOU/SELECT; terminal states
  still reject it. See docs/SHIFT.md for timing boundaries and original references.

- Native UI fontSize requires a Lua integer. Round scaled font sizes with math.floor;
  renderer mocks must enforce integer setters, including repeated assignments.

- SHIFT resolves each impulse round against pre-update positions and queues updates
  until all riders have been processed. Converging PUSH Text riders may overlap;
  do not serialize arrival positions and push the first arrival away. Undo restores
  the stacked identities and facing. See tests/shift.lua convergence coverage.
- MORE is a creation phase after conversion, before frozen contact compilation.
  Grow cardinally once per source; EDGE, STOP/PUSH and same concrete unit name
  block growth regardless of FLOAT. New copies block later sources but do not
  recursively grow this turn. Preserve text/direction/links, allocate atomically,
  and give copies current-turn WEAK newborn grace. See docs/MORE.md.
- Renderer writes are cached per control, including stable Color values. Preserve
  same-size level switches, highlights, empty cells, visibility and board scrolling
  when skipping redundant native setter calls. Keep integer fontSize enforcement.

- Scoped LEVEL reconversion replaces its tracked source entrance's entire prior product
  group, including when entered through an allocated copy. Preserve separate SELECT
  candidates/entry slots, retire old products atomically, keep allocator tombstones,
  and return via the surviving source ID. See docs/LEVEL_SEMANTICS.md.

- Official catalog audit uses installed Data/Editor/editor_objectlist.lua, never mod
  catalogs. See docs/OFFICIAL_WORDS.md and tools/audit_official_words.py --check.
- MOVE/nudges run after YOU and before SHIFT; automatic deaths retain source-frame
  HAS and newborn WEAK grace. SLEEP only suppresses self-motion, not passive PUSH.
  STILL/directional locks block passive motion. Sleeping SHIFT sources still impart
  displacement; only final facing alignment checks source SLEEP. Weighted direction
  grants and TURN/DETURN use multiplicity, not Boolean capabilities. See MOTION_WORDS.md.
- NEXTTO is cardinal adjacency excluding overlap; ABOVE/BELOW/BESIDELEFT/BESIDERIGHT
  scan the aligned ray; FACING checks the next cell or cardinal direction arguments.
  Keep per-identity queries and frozen contact declarations; do not filter by FLOAT.

- PULL failures roll back only speculative trailing dependencies, never the successful
  leader; blocked pulled WEAK does not shatter. SWAP preserves displaced facing and
  distinct identities; STILL partners remain. PHANTOM skips collision, not contacts.
- FALL settles after conversion and before MORE, counts/cancels opposite directions,
  preserves facing and uses PUSH/PULL/STOP as support. SLEEP does not suppress FALL.
  FALL passes over SWAP without swapping; bare unsafe WEAK transit victims get HAS.
  Keep settling/destruction as atomic sequential stages, newborn grace and limit Undo.

- REVERSE uses physical rule-instance parity. Reverse active root intentions, not
  PUSH/PULL dependency displacement. Preserve intention facing except SELECT/LEVEL
  which face actual travel. Original cantmove reverses the lock query too; retain
  that mapping. FALL reverses before cancellation and settles all surviving axes
  down/right/up/left, repeating to stability; preserve its 6000-step terminal limit.

- FEAR is a noun predicate after MOVE/nudges, before SHIFT. Resolve conditions per
  source; collect intentions from one phase snapshot. Duplicate target parameters
  add strength, stacked same-noun witnesses do not. Preserve original findfears tie
  search and exact score==1 test. Destruction/HAS stages include WEAK newborn grace.
  Scoped LEVEL/virtual EMPTY FEAR sources remain deferred; see MOTION_WORDS.md.
- Native test rooms must leave ample working space. MOTION is 32x28; loose words
  use a three-cell grid (two empty cells between), with spare nouns/connectors and
  ready-made feature demonstrations. Preserve this spacing in later expansions.

- User priority is remaining verbs, conditions, prefixes, GROUP, then properties.
  Letter/digit/accidental composition is deferred. FOLLOW is implemented; continue
  MAKE/EAT/BECOME/MIMIC/PLAY before returning to TELE/HOLD or other properties.
- FOLLOW turns without moving and retains an intrinsic followed identity for
  adjacent targets. Keep memory/facing in atomic Plan/Commit/whole-tree Undo with
  stale-field validation. SLEEP suppresses it; STILL/locks/REVERSE do not. Its phase
  is post-conversion before FALL/MORE/contacts. See MOTION_WORDS.md for source/gaps.
- Scaled single Text labels must preserve the complete word using explicit line
  breaks and integer fonts fitted to width and height. Do not regress to first
  letters. Existing short labels for actual overlapping stacks are a tracked gap.

- MAKE runs after ordinary contact destruction (future EAT goes immediately before
  it), against surviving sources and frozen declarations. Only old non-converted
  matching occupants block; all current-turn create/transform/retype IDs are ignored.
  MAKE births do not suppress duplicate MAKE clauses or rerun earlier phases. Keep
  facing/Text/links, ALL multiplicity, source conditions and late CRASH/WORD checks.
  See docs/MAKE.md for original references and remaining LEVEL/EMPTY scope.
- Random direction draws are pure plan data, never host/global RNG side effects.
  world.random_state and stale-checked stage random_state={from,to} participate in
  Preview/Commit/whole-tree Undo, including RNG-only turns and atomic late failure.

- EAT runs after OPEN/SHUT, before MAKE; frozen per-source predicates select same-cell,
  same-FLOAT non-self unsafe victims simultaneously. Mutually eaten sources still eat.
  Each victim triggers HAS once; duplicate HAS still multiplies products. No recursive
  newborn EAT; surviving births may participate in MAKE/CRASH. See docs/EAT.md.
- The user waived routine real-device acceptance as a progress gate. Continue through
  the requested word families with simulation/source oracles, recording known gaps;
  do not wait for manual confirmation or claim native success from offline tests.

- BECOME bypasses IS identity protection; self-targets and duplicate products count.
  Negative noun targets are verb-specific. Same-name BECOME must enter the transient
  converted-ID set (RW_PlanConversions fourth result) for late MAKE occupancy even
  when no persistent transform op is needed. Scoped LEVEL BECOME remains deferred;
  see docs/BECOME.md.

- MIMIC copies only original non-MIMIC declarations once; never propagate copied
  copies along MIMIC chains. Evaluate combined target/source/negative conditions
  at the imitator identity. Keep duplicate products and the 250-copy TOO COMPLEX
  limit. Internal spatial requirements are conjunctions; see docs/MIMIC.md.

- PLAY emits one transient event per matching rule group before contact destruction,
  not one sound per unit. Duplicates remain distinct; EMPTY has no particles.
  Complete note tokens do not enable letter composition. Dispatch requests only
  after successful whole-tree Commit; current native output is diagnostic logs,
  with real sound/particle bindings explicitly deferred. See docs/PLAY.md.

- WITHOUT counts global shortages per repeated parameter and excludes the source.
  NOT WITHOUT requires every quota to be met; it is not a Boolean complement of
  positive WITHOUT with AND parameters. MIMIC condition inversion must toggle named
  clauses before OR grouping, matching invertconds(). See docs/WITHOUT.md.

- FACEDBY checks incoming cardinal neighbors in Right/Up/Left/Down order, independent
  of the subject facing. NOT noun parameters may use a wrong-facing same-name unit,
  but never physical Text. Preserve distinct stacked witnesses and FLOAT independence.
  Virtual Empty observer direction remains None until that subsystem exists.
  See docs/FACEDBY.md.

- SEEING includes the first opaque cell. STOP/PUSH/PULL occlude across FLOAT; HIDE
  is unseen/transparent, PHANTOM seen/transparent. Query current/frozen declarations
  with transient condition_rules, never inherited behaviors; keep recursion guards
  outside persisted state. Preserve original EMPTY placeholder quirks. HIDE only
  affects visibility, not reading/collision/SELECT. See docs/SEEING.md.

- FEELING queries property declarations for the current identity/cell. NOT property
  means another positive property, not absence. Repeated parameters consume distinct
  condition instances, including failed tests; do not reuse one declaration. Share
  transient condition_rules with SEEING, preserve frozen frames and keep checked
  conditions out of world/Undo. POWERED belongs to prefix syntax. See docs/FEELING.md.

- Canonical prefixes follow actual physical paths, share the subject condition group,
  preserve sentence multiplicity/activation and suppress unconditional interior
  suffixes. POWERED channels query global current-frame POWER sources, including
  eligible Text/Empty and unconditional scoped LEVEL declarations. Never persist
  result caches across phases; guard ungrounded channel recursion. See docs/POWERED.md.

- IDLE tests the current wait command before movement, not displacement failure.
  Persist last_input through validated first-phase input_state metadata; rejection
  must not change it, and whole-tree Undo restores it. Confirm is separate.
  See docs/IDLE.md for original references and boundary behavior.

- OFTEN/SELDOM sample by physical head/clause/identity (EMPTY by cell), using a
  pure keyed chance_seed. Advance only accepted move/wait through validated
  first-phase chance_state; compilation/render/query order cannot consume draws.
  Whole-tree Undo restores the seed. MAKE RNG stays separate. The original engine
  RNG sequence differs deliberately; see docs/CHANCE_PREFIXES.md.

- GROUP nouns are compiler-only typed terms, excluded from the ordinary ALL palette.
  Direct memberships expand declarations after MIMIC, preserving duplicate products
  and per-source membership/consumer conditions. Never turn GROUP into an archetype.
  Cross-group transfers use original consumed-edge order and cumulative member
  conditions, before exclusions; preserve duplicate members and bound positive/negative
  expansion. NOT GROUP ordinary consumers use strict all-declaration complement;
  cartesian negative sources use separate inverse member branches. Same-group IS
  identity/CRASH follows the original. Nonrecursive condition parameters use a
  transient compiled group_members frame: any qualifying real unit promotes its
  noun globally, duplicate declarations retain duplicate parameters. Preserve
  original mutable parameter insertion/removal and missing-name behavior. Recursive
  membership conditions use original previous-round substitution (all group names),
  ordered duplicate signatures and ten-change loop bound; stable lists append to
  the base. Commit command/movement/contact triggers before only-Undo locking.
  Negative-source cross-group IS iterates direct declaration presence before conditions,
  excludes positive-transfer products from its base, overwrites destination maps,
  and counts negative targets as presence. Preserve duplicate edges and the ten-change
  bound; malformed nested inversion remains a documented gap;
  see docs/GROUP.md.

- Ordinary NOT subjects in GROUP membership stay literal through group transfer and
  negative-source recursion; expand their ordinary-noun complement afterward.
  Membership exclusions stay keyed by literal subjects: NOT ROCK IS NOT GROUP does
  not exclude the concrete complement generated by NOT ROCK IS GROUP. Concrete
  AVATAR IS NOT GROUP still excludes that member. See docs/GROUP.md M9.5B.

- ALL IS GROUP preserves the literal ALL declaration plus ordinary noun copies;
  NOT ALL IS GROUP additionally declares EMPTY and TEXT and its raw NOT ALL emits
  no names. Raw ALL members remain literal sources in GROUP consumers but expand
  as ALL products on HAS's RHS. Never deduplicate those products; see GROUP.md.

- LEVEL membership in GROUP preserves its typed LEVEL term through consumers, so
  existing scoped IR, terminal order and identity-bound conversions still apply.
  Group condition parameters use @level and real level_block witnesses. Conditional
  scoped LEVEL consumers retain their existing deferred boundary; see GROUP.md.

- GROUP/LEVEL MIMIC endpoints copy raw declarations before GROUP expansion, even
  for an empty group. Normalize ALL membership before MIMIC exactly once. Never
  run MIMIC again on derived member rules; retain one-generation tags/limits and
  conditional protections. Other endpoint gaps remain documented in MIMIC.md.

- TELE runs after MORE before contact compilation, using same concrete-name source
  networks (all Text share one name). Riders must differ from source name, match
  source FLOAT and lack STILL; destination FLOAT/collision/locks/SLEEP do not block.
  Each identity travels once, preserving facing/links. Sources can themselves move
  before later processing. Commit destination RNG atomically; see docs/TELE.md.

- User scope update: skip 3D; color properties combine as stacked color filters.
  Defer frontend and authored level design as separate major workstreams. Continue
  remaining logic and documented semantic gaps without routine planning pauses.
- BOOM runs after SINK before WEAK, with multiplicity-scaled square range,
  independent SAFE victims and FLOAT matching. Destruction triggers HAS once per
  victim; see BOOM.md and tests/reference_boom.lua.

- Unconditional scoped LEVEL HOLD blocks real-unit displacement only on the map
  FLOAT layer, through common cantmove-style checks (including passive movement
  and HOLD following). Virtual EMPTY is excluded; TELE bypasses cantmove as in
  the original. Conditional scoped evaluation remains deferred; see HOLD.md.
