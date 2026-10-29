# FEELING (M9.4Q)

Primary source: installed Data/conditions.lua feeling() at lines 1997-2067,
including checkedconds, positive IS lookup, and the type-2 filter for NOT arguments.
Data/Editor/editor_objectlist.lua confirms FEELING type 7 / argtype {2}, while
POWERED/POWERED2/POWERED3 are type-3 prefixes. This completes the catalog's condition
category within the existing documented scopes; prefixes follow next.

FEELING accepts properties, not noun or syntax-word arguments. It queries applicable
IS property declarations for the same identity/cell and current declaration frame.
FEELING RIGHT observes the RIGHT property, not merely the entity's intrinsic facing.
FEELING NOT PUSH seeks another positive property, so it can succeed when PUSH is
also present and fails when no positive property exists. NOT FEELING is the normal
condition negation. Concrete parameters precede complements as in existing conditions.

Each parameter consumes a distinct rule condition instance, including failed tests.
Thus one PUSH declaration cannot satisfy FEELING PUSH AND PUSH; two independent
PUSH declarations can. Rules sharing the same condition table cannot be reused.
Authored multi-effect IR rules also share their one condition instance. Lowered
physical AST conditions retain the existing IR identity choices; exhaustive original
parser/condition-table alias parity is not claimed.

The transient frame-query infrastructure now serves SEEING and FEELING. It is
named condition_context / _condition_* internally; condition_rules on conversion,
HAS and other relations still carries the generated declaration frame. Conditions
refresh against current phase identities and occupancy, retaining frozen contact
rules. Default TEXT IS PUSH and authored property rules are available. Virtual
EMPTY can query matching cell declarations. Stale projected entity.behaviors are
never read. Query contexts/checked conditions do not enter world facts or Undo.

Self/mutual FEELING support cannot ground a property without an independent rule.
Checked condition instances prevent recursive reuse, with the existing depth-80
word_rule_limit fallback. This is bounded current-engine behavior, not a claim of
complete original checkedconds/postrules equivalence for pathological cycles.
Conditional denials use the engine's existing per-identity denial projection;
all original negative postrules/cache edge cases remain outside the source matrix.
Scoped LEVEL subjects, GROUP and not-yet-implemented properties retain their gaps.

Validation: tests/feeling.lua covers argument roles/activation, NOT/complements,
quantity/condition identity, conditional refresh per source, directions, Text/EMPTY,
conversion/HAS/WORD/SEEING, grounding and atomic Undo. tests/reference_feeling.lua
executes installed feeling() in 2,880 normalized declaration/condition/parameter
cases, including shared condition tables and disabled rules. The real compiler
regression suite passes and normal startup stays below 2M offline instructions.
Native acceptance is waived; offline checks do not establish native runtime parity.

A loose FEELING replaces one redundant NOT in MOTION, retaining spacing/dimensions.
Next: prefix infrastructure and POWERED/POWERED2/POWERED3 with their POWER properties,
then remaining prefixes, GROUP and properties. Letter composition remains deferred.
