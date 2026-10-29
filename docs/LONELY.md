# LONELY (M9.4S)

Primary reference: installed Data/conditions.lua lonely(), lines 2062-2080.
LONELY checks for another physical identity at the subject position. Text and
hidden/floating entities count; the subject itself does not. NOT negates the
result. Virtual EMPTY has no physical self and is lonely at an unoccupied cell.
Scoped LEVEL conditions remain deferred (the original LEVEL is never lonely).

Uses the existing actual-token prefix grammar, including subject AND, NOT,
stacked prefix multiplicity, spatial conditions and activation. Conditions are
re-evaluated in the current phase snapshot, preserving frozen contact rules.
No cached or persisted LONELY state is introduced. Conversion and whole-tree
Undo use the existing atomic pipeline.

Production compiler/planner regressions live in tests/powered.lua. The standalone
reference_lonely.lua executes the installed function for twenty occupancy/NOT
cases, including virtual EMPTY and stacked Text. COND has a loose LONELY block.
IDLE and OFTEN/SELDOM remain pending: input state and turn-stable random results
need explicit atomic handling. Offline results do not establish native parity.
