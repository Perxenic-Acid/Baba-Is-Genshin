# MIMIC (M9.4L)

Current scope includes positive ALL MIMIC sources and GROUP targets through the
existing endpoint rules; see the final implementation section. Earlier milestone
scope/deferred notes below describe historical states. NOT GROUP subjects are
recognized inert declarations, matching original pass timing; conditional scoped
LEVEL consumers retain their documented limitations.

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


## M9.9Q ALL as a MIMIC target

Installed rules.lua addoption() around1081–1114 and subrules() around1116–1207
retain a literal MIMIC ALL declaration and append one MIMIC target per authored
ordinary noun. The literal declaration can copy raw ALL-subject declarations;
it is not replaced by the concrete targets. MIMIC NOT ALL protects that literal
copy and contributes inverted conditions to each generated target. A separately
authored MIMIC ROCK remains independent of that ALL-target protection.

Negative MIMIC subjects retain their literal parent during this expansion.
NOT ROCK MIMIC ALL therefore has two ordinary-target expansion paths: the raw
NOT parent expands its target and then its subject, while its concrete-subject
children expand their own targets. Both paths count. NOT ALL similarly expands
its subject to EMPTY and TEXT. Raw supported negative parents are transient
compiler bookkeeping, never executable identities or deferred diagnostics.
GROUP MIMIC ALL also copies original declarations before GROUP expansion.
Existing 5,000-record and 250-copy limits remain TOO COMPLEX boundaries.

The complete installed-source oracle covers 41,472 ALL/NOT declarations, direct
and negative MIMIC subjects, ordinary/EMPTY/TEXT/ALL targets, duplicate clauses,
negative HAS/MIMIC protection and per-identity LONELY cases. Ordinary targets
retain ordered-product checks. ALL targets compare product multiplicities:
original pairs(objectlist) uses a host-dependent hash order, whereas this engine
uses authored palette order across distinct target nouns. This is a deliberate
ordering gap; within each copied target, declaration order remains preserved.
The GROUP complete-pass oracle adds ALL targets (1,440 cases). Physical tests
cover conditional protection, explicit-target independence, double negative-source
expansion and HAS births with whole-tree Undo.

This supersedes earlier RHS ALL endpoint deferrals, not all ALL-related gaps.
Positive ALL as the MIMIC subject remains deferred. Non-MIMIC RHS ALL expansion
inside the copy lookup is still incomplete; adapters above use concrete HAS
products and do not establish that behavior. Ordinary NOT-to-GROUP exceptions,
NOT GROUP endpoints and conditional scoped LEVEL limitations remain as recorded
above. No native-device success is inferred from these offline comparisons.

## M9.9R pre-copy RHS ALL products

The copy lookup now follows the growing installed subrules() ALL queue instead
of treating only ALL subjects. addoption() immediately appends concrete NOT
subjects; subrules() then expands both ALL axes, visiting appended declarations
that still contain literal ALL. This preserves the two paths of ALL HAS ALL and
NOT noun/NOT ALL HAS ALL. NOT ALL RHS protection is inverted at the appropriate
literal-subject expansion, while separately authored products remain independent.
The same base negative-subject duplication is restored for HAS and MAKE.

For HAS/MAKE/EAT/FEAR/FOLLOW, the raw positive RHS ALL declaration remains in the
copy count, but does not produce another runtime palette expansion. Concrete
pre-copy derivatives provide those products/targets. Native inside()/createall()
finds no physical unit named ALL; the MAKE block similarly has no ALL creation
branch. Each raw declaration still counts toward the 250-copy TOO COMPLEX limit.
Lookup records remain transient and bounded to 5,000. Normal runtime declarations
are not replaced by the copy-only table, and compilation without MIMIC skips it.

Physical tests compare every product noun and Undo for concrete, ALL, NOT noun
and NOT ALL source paths. The standalone reference_mimic_all_products.lua runs
installed addoption()/subrules() and compares concrete HAS product multisets at
each real identity, including conditional NOT ALL/NOT FLAG and native copy-limit
outcomes. It deliberately excludes literal HAS ALL from birth expectations:
installed inside() passes it to createall(), whose findtype({all},...) has no
matching ordinary identity. Existing complete-pass ALL and GROUP oracles remain
independent checks. Cross-name hash traversal order remains the documented gap.

WRITE/BECOME RHS ALL lookup expansion remains pending: their literal ALL records
have conversion behavior and must not use the inert-product shortcut above.
Positive ALL as a MIMIC subject, NOT GROUP and other previously recorded scoped
limitations remain pending. These tests do not establish native-device success.

Validation matrix: 27,648 native RHS ALL cases, including 1,456 TOO COMPLEX
outcomes. The adapter also executes installed inside(), createall() and findtype()
to prove that literal HAS ALL adds no births while a concrete HAS CRATE still
creates its product. It does not substitute a hand-written raw-ALL consumer.

## M9.9S WRITE ALL literal conversion

Installed convert.lua conversion() preserves WRITE's literal ALL output as
text_ALL. subrules() also supplies concrete noun WRITE declarations. Thus ordinary
WRITE ALL has K+1 products; ALL/NOT-subject WRITE ALL has 2K+1 per eligible source.
Earlier tests counted only ordinary target names and missed the literal product.
The compiler now retains it once, including scoped LEVEL WRITE. MIMIC's lookup
expands WRITE ALL, copies the raw record as a literal token and preserves all
concrete derivatives without expanding the raw record a second time. Existing
WRITE NOT ALL, IS NOT TEXT and identity protections still apply.

reference_terminal_words.lua now asserts literal ALL outputs from installed
conversion(), alongside its previous concrete-product count. The new standalone
reference_mimic_write_all.lua compares converted multisets against installed
addoption/subrules declarations across duplicate, NOT-subject, conditional and
copy-limit cases, including overlapping Text sources. Full regression and the 27,648-case matrix passed, including 1,456 native-limit cases.
BECOME ALL and positive ALL MIMIC subjects remain separate unfinished work.

The full tests/run.lua regression has passed with normal startup at 1,438,000
instructions. The WRITE conversion-multiset matrix has passed before
commit. BECOME needs separate handling: installed createall_single() excludes
the source's own noun and skips existing same-cell target names, unlike explicit
BECOME noun products appended by subrules(). Reusing the WRITE literal-token
path would be incorrect; that behavior is not claimed by this change.

## Positive ALL MIMIC subject: installed baseline

reference_terminal_words.lua now executes addoption/subrules/postrules/conversion
for one/two ALL MIMIC CRATE declarations plus CRATE WRITE ROCK, with and without
ALL MIMIC NOT CRATE. Every ordinary source receives each copied declaration;
CRATE also retains its original declaration. A separate raw ALL-source copied
record survives. It must contribute to native copy limits without being lowered
again as an ordinary ALL-subject palette, which would double runtime products.
The current project positive-ALL MIMIC subject remains deferred. The new baseline
establishes raw/concrete multiplicity, self-copy and unconditional protection;
conditional bans, GROUP consumers and both-ALL axis ordering still require tests.

## Positive ALL MIMIC subjects: implementation

The baseline above is now implemented, including ordinary, Text, Empty, LEVEL
and GROUP target declarations through the existing endpoint scopes. MIMIC's ALL
preprocessing follows a growing queue: original declarations stay first, RHS ALL
expands before the subject, and generated declarations containing ALL are visited
later. Thus ALL MIMIC ALL keeps both paths, duplicate products and native copy
counts. Palette traversal uses authored order rather than the native hash order.
Raw ALL-source copies count toward the250 limit without receiving a second
ordinary-subject expansion. Literal IS GROUP/IS NOT GROUP copies are retained for
post-MIMIC membership processing. Already normalized ALL/NOT ALL memberships must
not be expanded again in the copy lookup. Other documented conditional/scoped
endpoint gaps are unchanged; this does not implement NOT GROUP subjects.

Validation includes:
- reference_all_mimic.lua:51,840 installed addoption/subrules cases, including72
  native TOO COMPLEX outcomes, per-imitator conditions and NOT protections.
- reference_all_mimic_order.lua:240 mixed original/derived declaration cases,
  including36 limits, plus exact249/250/251 raw/concrete copy thresholds.
- reference_group_mimic.lua:2,304 installed addoption/subrules/grouprules cases,
  including ALL source targets, copied membership and conditional protection.
- Physical rule compilation, scheduled movement/destruction/HAS, allocated
  product order and whole-session Undo in tests/mimic.lua.

HAS ALL and WRITE ALL source-ALL matrices each passed41,472 cases, including
3,184 native-limit outcomes each. Full tests/run.lua passed with normal startup
at1,440,000 instructions; the added typed LEVEL target movement/Undo probe also
passed. These checks establish source/simulation parity within the described
matrix; they do not claim native-device acceptance.

Next endpoint baseline: reference_negative_group_mimic.lua executes the installed
subrules/grouprules passes over288 cases, with positive GROUP controls. NOT GROUP
MIMIC produces no tagged copies before or after membership expansion, even for
ALL targets and duplicate/conditional declarations. This baseline does not yet
remove the project's deferred diagnostic for those subjects; the next change
must preserve the one-pass copy timing instead of treating NOT GROUP as an
ordinary-noun complement at MIMIC time.

## Negative GROUP endpoints: native timing

NOT GROUP/GROUP2/GROUP3 MIMIC is now a recognized inert declaration rather than
an unsupported diagnostic. Installed subrules checks getmat on the literal
negative source, which cannot match the authored objectlist. grouprules later
emits ordinary MIMIC clauses, but the copy pass has already finished and is not
repeated. Negative targets/protections with this subject are likewise inert;
they never become bans for ordinary imitators. The original physical sentence
still participates in activation, WORD parsing and compile budgets.

Ordinary NOT subjects targeting a GROUP follow the related addoption exception:
NOT ROCK/TEXT/EMPTY/LEVEL MIMIC GROUP (and NOT GROUP targets) are not expanded
immediately, so they also cannot copy in that pass. NOT ALL is explicitly exempt:
it still generates EMPTY and TEXT sources before copying, including group targets.
Keep raw declarations through preprocessing/budget checks; suppress only the
already-finished inert copies. No new persistent fields or runtime phases exist.

reference_negative_group_mimic.lua now compares native and project per-identity
HAS results across its288 cases, retaining positive GROUP controls. The separate
reference_negative_mimic_group_targets.lua compares576 cases across ordinary,
Text, Empty, LEVEL, ALL and negative GROUP subjects, three group channels,
positive/negative group targets, duplicate/conditional declarations and an
independent ordinary MIMIC source. It also checks native tagged-copy counts before
grouprules. Physical tests cover complete sentence activation, both sides of
membership, independent NOT protections, scheduled destruction/HAS and Undo.
These results supersede the earlier negative-GROUP deferral/baseline notes.

## Repeated NOT parity

Installed rules.lua parser prefix handling (around772-779) toggles each physical
NOT before addoption. MIMIC now unwraps even NOT prefixes when resolving source
and target declaration keys. Odd prefixes keep their existing complement, ban
or inert-GROUP behavior. The raw copied declaration lookup uses the same keys,
so NOT NOT CRATE HAS FLAG remains available to an imitator. Copied positive
subjects use their unwrapped term: otherwise a wrapped ALL group member could
be mistaken for a fresh ALL expansion by later group consumers. Physical AST
paths/NOT activation and rule multiplicity stay intact.

reference_mimic_not_parity.lua executes the unchanged native parser toggle and
then addoption/subrules/grouprules across3,456 cases. Declaration heads, imitator
subjects and targets each vary over0-3 NOT tokens, ordinary/ALL/GROUP names and
conditional clauses. Runtime HAS counts are compared per real/Text identity.
Physical tests additionally use0-4 NOT tokens, validate activation and Undo,
and retain NOT ALL's EMPTY PUSH blocking rather than treating it as no effect.
The original NOT NOT ROCK MIMIC FLAG fixture now compiles without a deferred
entry and grants PUSH, matching the zero-NOT form.

Full tests/run.lua regression, installed GROUP/MIMIC order checks and layout/word
catalog audits passed. Normal startup remains1,440,000 instructions. Native
acceptance remains separate and is not inferred from these tests.
