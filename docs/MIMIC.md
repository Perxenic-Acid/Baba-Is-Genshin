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
