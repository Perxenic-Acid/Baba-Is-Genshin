# OFTEN / SELDOM (M9.4U)

Installed primary sources (base Data files):
- conditions.lua often()/seldom() 2140-2195: roll 1..4, succeed >1; roll
  1..6, succeed ==1. condstatus keys use the condition list, clause index and
  unit identity; virtual EMPTY instead includes cell coordinates.
- blocks.lua startblock() 1951 resets the condition cache through diceblock()
  3618. Cached repeat queries retain their first result.
- syntax.lua fixedrandom() 757 and undo.lua fixedseed save/restore 14/114.

Canonical prefix syntax supports NOT, adjacent prefixes, subject AND, RHS AND,
spatial conditions and activation. Parser-generated chance_key identifies the
physical head token path plus axis and clause position, shared across the head's
subjects and RHS terms. Different condition positions and sentence heads have
separate samples. Identity distinguishes ordinary units/Text; EMPTY uses cells.
An ordinary identity retains its draw after moving, retyping or transforming.

RuleWorld implements cache-equivalent pure keyed samples from chance_seed.
Every accepted move/wait advances the seed via the existing portable LCG family
(48271 modulo 2147483647); normal initial/boundary seed is 1. Head/clause/identity
bytes mix with key-dependent multipliers before the final LCG and 4/6-sided roll.
Key-dependent mixing avoids adjacent clauses having identical or simply shifted
streams. Conditions query without writes: compiling, rendering, WORD iteration,
contact refresh and speculative planners cannot consume a random decision.
Contact declarations stay frozen while births receive their own identity sample.

The input snapshot carries the upcoming seed before movement/SELECT queries.
Accepted plans store validated chance_state {from,to} on the first atomic phase.
Commit checks stale seeds, terminal boards reject commits, invalid inputs do not
advance, and whole-tree Undo/replay restores identical decisions. Confirmation
is separate and does not reroll. MAKE retains its separate random_state stream.

Deliberate differences: seed values/sequences are not the engine math.random
stream; extra engine RNG calls even on cached queries are not reproduced. The
physical-head key replaces Lua table-address cache keys and remains stable across
recompilation. Thus rebuilding otherwise identical declarations does not reroll
mid-turn. No exact pathological original cache/allocation-order parity is claimed.
This avoids host-global RNG, query-order dependence and persistent cache tables.
Conditional scoped LEVEL rules retain their existing deferred status.

Validation: production compiler/planner tests cover shared RHS samples, distinct
clause keys, joint repeated-OFTEN frequency, pure repeat queries, conversion,
WORD, rejected/stale plans, repeat planning, seed advancement and whole-tree Undo.
The installed-source oracle normalizes RNG rolls, checks cached repeats and
NOT/Object/Text/EMPTY across 1,440 cases; it does not claim RNG stream parity.
COND retains three-cell loose-word spacing and includes OFTEN/SELDOM.
Normal startup stays below the fixed 2M instructions; native parity is not claimed.
Next: GROUP and then ordinary properties; letters remain deferred.
