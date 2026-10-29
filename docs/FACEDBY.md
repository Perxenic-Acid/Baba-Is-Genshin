# FACEDBY (M9.4O)

Primary reference: installed Data/conditions.lua, facedby() at lines 953-1061.
This is an incoming adjacency condition, not a synonym for FACING. It visits
Right/Up/Left/Down neighbors, then parameters, consuming distinct physical witnesses.
The subject's own direction is irrelevant. Only a cardinally adjacent unit whose
facing points at the subject satisfies a positive noun parameter; overlaps,
diagonals and more distant units do not.

Negative parameters preserve the original test: a non-Text neighbor can qualify
if its name differs OR it is not looking at the subject. Thus a wrong-facing ROCK
can witness FACEDBY NOT ROCK. TEXT is excluded from negative noun witnesses.
Repeated parameters need separate units; stacked identities remain separate.
A LEVEL parameter consumes the enclosing level once; repeated LEVEL may then seek
physical level shapes. Conditions do not filter FLOAT and do not change collisions.
NOT FACEDBY reverses the final condition, using the existing parser's NOT prefixes.
ALL parameters retain the authored palette expansion and existing complement rules.

The helper runs within the existing per-identity condition evaluator. It therefore
participates in WORD fixed points, independent conversion selection, frozen HAS
refresh and Undo, without persistent state or new phases. The physical source AST
continues to own text activation. Empty as subject can be watched by real units.

Scope: virtual Empty currently has no rule-derived facing. Empty neighbors use
None, so positive FACEDBY EMPTY cannot watch a subject; FACEDBY NOT EMPTY follows
the original default-None branch. Empty direction/lifecycle, scoped LEVEL subjects,
campaign surrounds and GROUP remain deferred. Mid/None real units do not look
at neighboring subjects. No full original postrules parity is claimed.

Validation: tests/facedby.lua covers physical parsing/activation, six-value facing
behavior, duplicate witnesses, negative/Text cases, conversion/HAS/WORD/FLOAT,
virtual subjects and whole-turn Undo. tests/reference_facedby.lua executes the
installed facedby() in 36,288 direction/position/name/stack/parameter/NOT cases,
with virtual Empty defaulting to None. It normalizes parameters and host unit data,
not the full original parser/game. Full regression and startup budget pass;
native acceptance remains waived and offline checks do not establish native parity.

A loose FACEDBY replaces one redundant IS in MOTION; dimensions and sparse spacing
remain unchanged. SEEING is next; its occlusion uses original simplecheck() and
requires careful rule-derived STOP/PUSH/PULL/HIDE/PHANTOM queries.
