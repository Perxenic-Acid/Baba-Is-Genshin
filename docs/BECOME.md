# BECOME (M9.7J)

Primary reference: installed Baba Is You `Data/convert.lua`, conversion() and
convert(), and `Data/rules.lua` identity-protection and negative-rule processing.
BECOME is a noun conversion predicate. IS identity protection excludes BECOME;
BECOME self-targets remain actual conversion products and duplicate declarations
produce duplicate products. Negative targets veto the corresponding verb, so
IS NOT FLAG does not veto BECOME FLAG, nor the reverse.

Conversions preserve facing and identity-bound links. The first product retains
our stable entity ID; siblings allocate fresh IDs. Conversion never triggers HAS.
TEXT targets promote nouns to Text, including TEXT BECOME TEXT -> text_TEXT.
Conditions resolve independently for each source. EMPTY and ALL reuse the existing
virtual occupancy/authored palette conversion scope.

Even a same-name BECOME counts as converted for late MAKE occupancy. The converter
returns a transient converted-ID set as its fourth result; it is not persisted.
Plans, allocation and whole-tree Undo remain atomic.

Validation: tests/become.lua covers protection, negative isolation, duplicates,
conditions, TEXT/EMPTY/ALL, linked products, MAKE interaction and Undo.
tests/reference_become.lua executes installed conversion()/convert() across 432
cases using normalized negative/protection conditions; it also executes the exact
installed identity-protection predicate. This is not full original-parser parity.
Native acceptance is waived by the user; offline results do not establish native
runtime parity. BECOME is available as a loose full-name word in the sparse MOTION
room.

Deliberate gaps: conditional scoped LEVEL BECOME and synthetic self-negative
destruction remain deferred (see M9.7I/J below). Existing IS self-negation
precedence is preserved; mixed negative self-conversions beyond the tested matrix
are not claimed as exhaustive original parity. EMPTY lifecycle/HAS limitations and
ALL authored-vocabulary boundaries remain as documented in SPECIAL_NOUNS.md.

## Scoped LEVEL integration (M9.7I)

REVERT metadata now permits unconditional scoped LEVEL BECOME ordinary noun,
TEXT and LEVEL. Installed convert.lua conversion()/convert() queues BECOME
alongside IS, while dolevelconversions() rewrites BECOME LEVEL to REVERT before
product selection. This indirect restore retains priority over other selected
products. Physical BECOME REVERT remains invalid syntax (property argument).

Typed become_level/forbid_become_level commands stay separate from real-unit
BECOME relations. IS LEVEL identity protection suppresses IS products only;
BECOME products preserve declaration order and multiplicity. Ordinary noun/Text
BECOME bans affect only that verb; IS NOT REVERT does not block BECOME LEVEL.
Scoped BROKEN suppresses these commands using the existing declaration gate.
Real level blocks additionally use the existing identity-preserving BECOME path,
with direction/original-name/links and no HAS conversions.

The existing boundary transaction handles source-group replacement, return,
allocator tombstones, persistent reload and Undo. The >=50 selected product
TOO COMPLEX gate applies to BECOME too, retaining the triggering child turn.
Tests cover scoped noun/Text/self restore, duplicate/mixed IS products, identity
protection, own negative noun, BROKEN, parent persistence and whole-tree Undo.
32 cases execute unchanged installed dolevelconversions selection, with IS
protection and verb-specific negative conditions normalized; 49/50/51 physical
BECOME rules exercise actual terminal boundary handling. No native success is
inferred from these offline checks.

Remaining scoped gaps: conditional LEVEL surroundings; ALL/EMPTY target handling;
LEVEL BECOME NOT LEVEL's original error/destroylevel path. That self-negative
form is explicitly deferred instead of being misrepresented as a ban on REVERT.
The earlier blanket scoped LEVEL deferral is superseded by this section.

## Scoped ALL and EMPTY targets (M9.7J)

Installed rules.lua subrules() expands RHS ALL for verbs other than IS into
ordinary objectlist targets. conversion(true) retains the raw ALL/createall
marker in its queue, but dolevelconversions() has no material for that marker;
only the ordinary expansion products become parent entrances. Our authored ALL
palette deliberately excludes TEXT/EMPTY/LEVEL, as for existing ordinary ALL.

LEVEL BECOME ALL now emits scoped products for each ordinary palette member,
with full duplicate clause multiplicity. Retain origin=@all on these commands:
BECOME NOT ALL suppresses only ALL-derived products, leaving a literal BECOME
FLAG intact. BECOME NOT FLAG suppresses matching expanded products too. The
real-unit LEVEL BECOME ALL relation still uses the ordinary conversion subsystem.
IS identity protection does not suppress these scoped BECOME products.

LEVEL BECOME EMPTY is recognized without a synthetic map conversion: installed
conversion(true) emits no conversion material for EMPTY. It still lowers the
real level-block conversion relation, which deletes those units without HAS.
There is no synthetic EMPTY entity, allocation or parent-entry transform.

Real compiler/tree tests cover one/two ALL clauses, per-noun and ALL-origin bans,
literal products beside a banned expansion, inert scoped EMPTY, real Level EMPTY
deletion and Undo. Six source oracles execute unchanged installed RHS ALL expansion
plus conversion(true), preserving duplicate/NOT ALL behavior; a native EMPTY
queue assertion verifies its lack of scoped products. Conditional scoped LEVEL
and self-negative destroylevel remain open. Broader ordinary ALL conversion
lifecycle differences remain in their existing subsystem scope; this batch does
not claim native objectlist iteration order or frontend acceptance.
