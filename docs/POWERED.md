# Prefix syntax and POWERED families (M9.4R)

Primary installed references: Data/rules.lua code grouping (wtype 3 enters the
shared group_conds list), Data/conditions.lua powered() at 2082-2135, and the official
editor's type-3 POWERED entries paired with type-2 POWER properties. No mod copies.

Canonical prefix syntax supports POWERED, POWERED2, POWERED3 before nouns, continuous
prefixes, NOT prefixes, NOT nouns, subject AND, RHS AND and spatial conditions.
Prefix conditions are shared by the subject group and re-evaluated per identity;
a prefix after a subject or after subject AND enters the same condition group.
The full physical path is retained for activation and multiplicity, with interior
unconditional noun/IS/property suffixes suppressed. No synthetic prefix-count
combinations are enumerated. Existing parser traversal/output limits still apply.
Default prefix names are compiler-shared (language.prefixes can override them).
WRITE retains syntax-word literal support. Alternate role orders retain their
previous limited syntax; new prefix/AND combinations in those orders are deferred.

POWERED asks whether any applicable POWER source exists anywhere in the current
level, not on the same cell, layer or connected path. POWERED2/3 query POWER2/3
independently. Multiple sources do not multiply a property's grant; physical sentence
variants still do. SLEEP/HIDE/FLOAT do not stop a source. Conditions and negative
POWER declarations refresh using the current declaration frame, without stale
projected behavior facts. Physical Text, virtual Empty and ordinary units can supply
power. Empty requires an available cell whose source condition holds.

Unconditional scoped LEVEL IS POWER/POWER2/POWER3 supplies its channel. Denied scoped
POWER is suppressed. Lowering adds one effect-free scoped_power declaration to the
transient generated rule frame so conditional conversions/HAS can see it without
persisting cache state. Conditional scoped LEVEL rules retain their existing gap;
physical level shapes with ordinary archetype rules remain ordinary source units.

Global channel recursion guards prevent self/mutual ungrounded power. A separate
source can ground cross-channel dependencies. Depth exhaustion propagates the
existing word_rule_limit terminal mechanism. No poweredstatus result is cached
across phase changes: each phase sees current live sources and occupancy while
contacts retain frozen declarations. Full original checkedconds/poweredstatus cache
parity for pathological dependency cycles is not claimed. GROUP and unsupported
property/LEVEL condition combinations remain previously documented gaps.

The POWER properties are derived capabilities; they add no turn phase or persisted
world fields. Whole-tree Undo restores actual source/board changes. The normal
production boot still skips regressions and keeps the fixed 2M instruction limit.

Validation: tests/powered.lua uses the production compiler/planner for all channels,
prefix/NOT/AND/shadowing/activation, duplicate prefix products, spatial source
conditions, EMPTY/Text/LEVEL, conditional conversions/HAS/WORD, dependency grounding
and Undo. tests/reference_powered.lua executes installed powered() across 1,080
normalized source/channel/count/condition/full-board/NOT cases, with a fresh cache
per case. Existing condition/source oracles and full regressions pass. Normal
startup: 1,983,000 offline Lua instructions. Native acceptance is waived; offline
results do not establish native runtime parity.

COND (root x=8,y=1) expands to 32x28, preserving its original objects and test routes.
Fourteen loose prefix/property/utility blocks occupy x=15..27 with three-cell spacing.
Original motion and official reference layouts remain intact. Next: remaining
prefixes LONELY/IDLE/OFTEN/SELDOM, then GROUP and ordinary properties.
