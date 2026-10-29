# WITHOUT (M9.4N)

Primary reference: installed Data/conditions.lua, WITHOUT at lines 1216-1332;
its caller testcond() reverses results for a NOT condition. Data/rules.lua
invertconds() toggles named conditions, including the special NOT WITHOUT form.

WITHOUT counts global shortages, excluding the source itself from its matching
noun count. A WITHOUT B AND B is true when fewer than two other B units exist.
Each named parameter has its own multiplicity threshold. TEXT counts physical
Text globally. EMPTY counts unoccupied cells; an EMPTY source excludes itself.
A single LEVEL parameter observes the enclosing level and fails; repeated LEVEL
uses the original count adjustment. These LEVEL parameters do not add scoped
LEVEL subjects or campaign surroundings.

Complement parameters exclude Text and the source, sharing consumed witnesses
across parameters. Concrete arguments precede complements using the existing
condition order. This engine uses stable identity order for complement witnesses;
original unitlists/pairs traversal may differ for adversarial competing complements.

NOT WITHOUT is a source-specific rule: the original WITHOUT function returns
whether any shortage exists, and testcond() negates that. Thus NOT WITHOUT B AND C
requires both quotas to be met, rather than merely negating the positive AND result.
Preserve this when inverting a MIMIC NOT declaration: named clauses are toggled and
OR-grouped like original invertconds(), not replaced with generic Boolean NOT.

Conditions refresh at each existing conversion/contact identity; no new persisted
fields, allocators, phase stages or frontend facts are introduced. WORD uses the
same grounded fixed-point compiler. Physical activation includes the full sentence.
ALL/NOT ALL parameters use the existing authored vocabulary expansion. Virtual
EMPTY lifecycle, scoped LEVEL subjects and GROUP remain previously documented gaps.
The source matrix validates normalized WITHOUT evaluation, not the entire original
postrules pipeline; other conditional negative declarations retain existing denial
semantics and are not claimed as exhaustive original postrules parity.

Validation: tests/without.lua covers quantity/self/NOT, activation, conversion,
HAS, WORD, MIMIC inversion and atomic Undo. tests/reference_without.lua executes the
installed function across 4,608 count/identity/Text/EMPTY/LEVEL/complement cases.
Complete regression and the existing MIMIC source oracle pass. Normal startup:
1,935,000 offline Lua instructions (<2M); no production self-tests. Native acceptance
is waived, so offline results do not establish native runtime parity.

The sparse MOTION room adds a loose WITHOUT, replacing one redundant loose IS;
room dimensions and three-cell word spacing remain unchanged. Next: FACEDBY/SEEING.
