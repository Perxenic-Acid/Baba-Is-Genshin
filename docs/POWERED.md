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

Scoped LEVEL IS POWER/POWER2/POWER3 supplies its channel through raw scoped_conditions
in the transient generated frame; supported conditions use the synthetic LEVEL
query context described in LEVEL_CONDITIONS.md. Denied or BROKEN scoped POWER is
suppressed. Conditional conversion/HAS queries receive these declarations without
persisting cache state. A typed LEVEL clause is a synthetic source for POWERED;
its physical entrance property projection does not provide an extra source when
the scoped condition fails.

Global channel recursion guards prevent self/mutual ungrounded power. A separate
source can ground cross-channel dependencies. Depth exhaustion propagates the
existing word_rule_limit terminal mechanism. No poweredstatus result is cached
across phase changes: each phase sees current live sources and occupancy while
contacts retain frozen declarations. Full original checkedconds/poweredstatus cache
parity for pathological dependency cycles is not claimed. Shared LEVEL condition
and recursive invalidation limits remain documented in LEVEL_CONDITIONS.md.

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

M9.7M: conditional scoped LEVEL POWER channels and dynamic synthetic BROKEN now
use raw current/frozen declarations; see LEVEL_CONDITIONS.md. No saved synthetic
status or persistent query cache is introduced.

POWERED now traverses positive declarations first, then matching identities in
native per-name creation order; virtual EMPTY uses installed findempty's
column-before-row scan and returns on the first eligible cell. LEVEL is queried
at its declaration's position rather than ahead of all ordinary sources. A
selected positive clause is evaluated once before raw negative declarations may
veto it; BROKEN and existing recursion guards still apply. An inactive earlier
clause cannot be satisfied by a different later positive clause.

Lowering attaches transient power_order to POWER rows/scoped declarations because
scoped_conditions are published together at the end of the compiled frame.
power_scoped prevents a typed LEVEL declaration from searching concrete entrance
shapes after its virtual condition fails. These fields are compiler/query data,
not saved world state or poweredstatus caches. Physical LEVEL shapes still
receive their ordinary property projection.

The installed powered/findempty trace oracle covers 2,400 paired source/type,
three-channel, condition-mask and unit-order cases twice: authored raw frames and
lowered AST frames with scoped rows moved by publication. It compares every
condition query and verifies skipped versus required limit failures. Production
compiler/planner tests retain dynamic ordinary/scoped NOT POWER, failed synthetic
versus active concrete LEVEL conditions, cross-channel grounding and whole-turn
Undo. Predicate answers and host BROKEN/cancellation are normalized in the source
oracle; full original checkedconds/poweredstatus invalidation remains deferred.
