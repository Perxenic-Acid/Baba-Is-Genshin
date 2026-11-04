# MIMIC (M9.4L)

Primary reference: installed Baba Is You Data/rules.lua, subrules(), MIMIC
protection collection and copy loop (lines 1209-1342). No mod source is used.

A MIMIC B copies B's non-MIMIC declarations once, replacing their subject with A.
Generated copies are not recursively copied; A MIMIC B plus B MIMIC C therefore
never grants C's declarations to A. A MIMIC A duplicates eligible declarations.
Both physical MIMIC duplicates and target declaration duplicates retain product
multiplicity. Copied IS identity statements change meaning with the new subject.

Target conditions, MIMIC conditions and inverted matching MIMIC NOT B conditions
are combined and evaluated at the imitator's identity. They are not tested at B's
location or reduced to a board-wide Boolean. A matching unconditional negative
MIMIC suppresses the copy. Existing IS/property denial then operates on the copied
rules normally. Internal spatial nodes may carry conjunctive requirements; these
are evaluated by the existing entity-condition evaluator, including frozen contact
refreshes. Physical activation still comes from original parsed sentences.

The compiler bounds generated copies to 250. A 251st copy returns the existing
rule_complexity_limit signal, which uses the established TOO COMPLEX transaction
and Undo path. Ordinary initialization retains its 2M-instruction budget and does
not run self-tests. MIMIC does not add persistent world fields.

Tests: tests/mimic.lua covers control movement and Undo, self/chain behavior,
duplicate conversions, source/target conditions, conditional/unconditional bans,
and exact limit boundary. tests/reference_mimic.lua executes the installed copy
section across 96 condition/multiplicity cases and the original limiter. It uses
normalized rules and simple condition adapters, not the original parser.

Scope: ordinary noun and TEXT subjects/targets are supported. MIMIC ALL and
ALL/NOT subject expansion, virtual EMPTY, scoped LEVEL and GROUP interactions
remain deferred; unsupported forms stay in compiler diagnostics. Other copied
verbs retain their own documented restrictions. PLAY remains the next verb.
A loose MIMIC word is present in the sparse MOTION room. Routine native acceptance
is waived; these offline checks do not establish native runtime parity.

## M9.5E GROUP / LEVEL integration

Positive GROUP channels and typed LEVEL endpoints now participate in the existing
raw one-generation copy pass. GROUP declarations are copied before membership is
expanded; an empty group does not disable copying its authored declarations. ALL
membership normalization precedes the copy pass. See GROUP.md M9.5E and the
1,152-case installed complete-pass oracle in tests/reference_group_mimic.lua.
ALL as a MIMIC endpoint, NOT sources and virtual EMPTY remain deferred. Existing
conditional scoped LEVEL restrictions still apply to copied consumers.

## M9.9M virtual EMPTY endpoints

EMPTY now participates as either endpoint in the same raw one-generation MIMIC
pass. Installed rules.lua subrules() (1209–1342) gates names with tools.lua
getmat(); neither routine excludes EMPTY. syntax.lua addunit() publishes authored
noun vocabulary through objectlist. The source oracle now executes the actual
getmat helper with an explicit authored EMPTY vocabulary entry, rather than a
Boolean stub. It covers 384 ordinary/EMPTY source/target combinations of physical
copy multiplicity, positive/negative conditions and bans, plus the 251-copy limit.

Copied declarations still run at their new subject: EMPTY conditions resolve per
vacancy, and a real noun copying EMPTY's HAS receives ordinary frozen destruction
semantics. EMPTY MIMIC EMPTY duplicates eligible raw declarations once; generated
copies cannot propagate through chains. Conditional MIMIC NOT EMPTY and EMPTY
MIMIC NOT noun protections use the existing per-imitator condition inversion.
No virtual identities or copied-rule caches enter world state or Undo.

tests/mimic.lua adds physical sentence coverage for copied/negative per-vacancy
conditions, self multiplicity and duplicate EMPTY HAS copied onto a real victim
with Undo. Existing GROUP/LEVEL copy ordering and the 250-copy limit are unchanged.
This supersedes the EMPTY endpoint deferral above. ALL/ordinary NOT endpoints,
full mutable scheduler parity and each copied verb's own restrictions remain
separate gaps; native success is not inferred from these simulations.

## M9.9N ordinary ALL declarations precede copying

Installed subrules() expands positive ALL subjects before entering its MIMIC
loop (rules.lua around1116–1207). Therefore ALL HAS FLAG plus ROCK MIMIC CRATE
gives ROCK both its own ALL-derived HAS and a copy of CRATE's ALL-derived HAS.
The previous lookup saw only the raw ALL statement and missed the second product.

The MIMIC lookup now includes those concrete declarations, preserving authored
palette multiplicity and per-imitator conditions. They are lookup-only records:
the original ALL statement remains the single source for ordinary runtime
lowering, avoiding doubled base effects. GROUP membership declarations already
normalized by the earlier pass are not expanded twice. Other GROUP consumers,
including HAS GROUP, still receive the ordinary ALL subject expansion. Native
positive-ALL nconds uses its literal featureindex["not all"] lookup; ordinary
negative-object declarations are not silently substituted for that index.

tests/reference_all_mimic.lua executes installed addoption(), subrules(),
copyrule() and invertconds() across 216 declaration/mimic multiplicity, negative
HAS, source condition, MIMIC condition and physical-overlap cases. Runtime HAS
counts are compared at both real identities, including original base rules.
Physical tests add two HAS births, HAS GROUP consumers and weighted property
counts with Undo, plus exact 5,000/5,001-entry lookup boundaries.
Existing EMPTY and GROUP MIMIC oracles remain separate checks. The transient
lookup is bounded to 5,000 declarations and uses the existing TOO COMPLEX path.
ALL as the actual MIMIC endpoint and NOT-source preprocessing remain unfinished;
this correction addresses declarations copied through ordinary endpoints.

## M9.9O NOT declarations and pre-copy insertion order

Installed addoption() (rules.lua around1081–1114) immediately expands ordinary
NOT subjects into the other authored ordinary names. NOT ALL instead adds EMPTY
and TEXT. MIMIC must see these declarations as copy candidates before its own
pass. The copy-only lookup now includes them without duplicating ordinary runtime
lowering. NOT GROUP remains literal. Ordinary NOT subjects whose object is a GROUP
term retain the original exception; NOT ALL HAS GROUP does expand, while NOT ROCK
HAS GROUP does not expand until the later GROUP pass. Already-normalized GROUP
membership records are not inserted twice.

The lookup also preserves stage order: immediate NOT derivatives follow their
original declaration, while positive ALL derivatives append after all original
declarations, as subrules() does. This matters for ordered HAS products copied
from a target that has both direct and ALL-derived declarations. A physical test
checks FLAG, ROCK, FLAG birth order, not just the final number of births.

The installed complete-pass oracle now covers 2,592 ALL/NOT ROCK/NOT CRATE/NOT ALL
cases, ordinary/EMPTY/TEXT MIMIC targets, conditions at the imitator, duplicate and
negative HAS declarations, plus mixed direct-target products. It compares ordered
births at the imitator and total birth counts at the original target. Physical
sentences cover NOT ALL's EMPTY/Text declarations, GROUP-consumer exceptions,
HAS and Undo. The 5,000-entry lookup bound includes both immediate and pending
ALL records, retaining the 5,000/5,001 tests.

This completes pre-copy NOT expansion for non-MIMIC declarations. NOT as the
MIMIC subject itself, ALL as an actual MIMIC endpoint, and shared mutable runtime
scheduler/ordinary declaration ordering gaps remain separate work. Native-device
success is not claimed by the source adapters.

## M9.9P NOT as the MIMIC subject

The immediate addoption() NOT-subject expansion now also applies to MIMIC
declarations themselves, before collecting mimicprotects. NOT ROCK MIMIC FLAG
therefore creates one MIMIC declaration for each other authored ordinary noun;
NOT ALL MIMIC FLAG creates EMPTY and TEXT declarations. Negative MIMIC targets
expand through the same path, so their conditions/protections meet each concrete
imitator rather than the raw literal NOT subject. Duplicate declarations remain
distinct and the existing one-generation/250-copy limiter still applies.

The source expansion preserves the native GROUP-object exception: ordinary NOT
subjects aimed at GROUP remain deferred, whereas NOT ALL may target GROUP and
copies raw declarations even for an empty group. NOT GROUP subjects remain
deferred. ALL endpoints, including NOT-source MIMIC ALL, are still unfinished.
Expansion uses the authored vocabulary contract already used for ALL/MIMIC;
the source adapters supply those explicit objectlist entries. Expanded MIMIC
records use the same 5,000-entry TOO COMPLEX bound, without persisted virtual IDs,
rule caches or extra startup passes when MIMIC is absent.

tests/reference_all_mimic.lua now executes 31,104 complete native addoption/
subrules cases, adding NOT ROCK/NOT CRATE/NOT ALL MIMIC subjects and unconditional/
conditional MIMIC NOT bans to the earlier declaration matrix. It queries actual
Text victims as well as ordinary units, evaluates loneliness per identity, and
checks ordered products at the ordinary imitator. Physical tests verify control
and excluded-noun movement, unconditional protection, NOT ALL's EMPTY/Text-only
projection (also with GROUP targets), and Undo. Earlier GROUP and direct MIMIC
oracles remain separate checks; native-device acceptance is not inferred.
