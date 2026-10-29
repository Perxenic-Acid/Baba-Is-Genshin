# PLAY logic and presentation requests (M9.4M)

Primary installed sources (no mod directories):
- Data/Editor/editor_objectlist.lua: text_play argtype 8 and 79 custom note names.
- Data/features.lua: getunitswithverb() grouping, live units and conditions.
- Data/blocks.lua: PLAY section at 1225, before SINK (1329), EAT and MAKE.
- Data/values.lua: play_data.tunes; Data/syntax.lua: generatefreqs(); Data/load.lua:
  base_octave=4. Preserve the original frequency arithmetic and alias quirks.

PLAY accepts note terms, not ordinary nouns/properties. Complete note tokens
(C, CSHARP4, etc.) are supported as dedicated Text blocks; this does not implement
letter/number/accidental assembly. Default notes are a shared compiler table;
copying the table into every authored world's language exceeded startup budget.
An optional language.notes table replaces the default note vocabulary.
IS/HAS cannot consume note terms. AND/NOT, physical multiplicity, ALL/NOT noun
subject expansion and spatial conditions use the existing parser/lowering paths.
Matching PLAY NOT note clauses veto only the corresponding PLAY note.

Each positive rule instance emits one event if any source satisfies its condition.
Multiple matching objects produce one sound request and multiple particle positions;
duplicate clauses produce duplicate events. TEXT groups all physical Text. EMPTY
uses virtual cells and requests no particles. SAFE, FLOAT and SLEEP do not mute PLAY.
MIMIC can copy supported PLAY declarations. Scoped LEVEL PLAY remains deferred.

PLAY resolves against the frozen contact declarations after conversion/FALL/MORE,
before SINK/WEAK/MELT/DEFEAT/OPEN-SHUT/EAT/MAKE. Movement destruction is already
applied. A source destroyed later by contacts still plays; Contact HAS/MAKE births cannot
play in the earlier PLAY phase; births from movement destruction already exist. Existing phase timing boundaries remain in effect.

Events are transient plan metadata: kind, source_type, note, tune, frequency,
entity_ids, positions and particles. They do not enter world state or Undo history.
Whole-tree action planning forwards them; the native adapter consumes them only
after successful RW_CommitLevelTree. Undo does not dispatch old requests. Planning,
preview, failed Commit and ordinary startup perform no audio calls.

Frontend gap: actual sound and particle rendering is NOT implemented. The current
adapter prints [RuleWorld] PLAY diagnostics after Commit; it does not audibly play
Baba samples or pretend that a Genshin sound ID is configured. Native audio assets,
pitch-capable playback and particle bindings need a later frontend decision.
The sparse MOTION room contains loose PLAY and C4 blocks; one redundant loose IS
was removed to preserve the 50-slot, three-cell-spaced layout and board dimensions.

Validation: tests/play.lua covers grouping, duplicates, AND/NOT/conditions,
TEXT/EMPTY/MIMIC, ordering, activation, invalid argument roles, defaults and Undo.
tests/reference_play.lua executes installed grouping, emission and frequency
sections across 7,872 source/count/condition/note cases. It uses normalized feature
conditions and host sound/particle recorders, not the full original parser/game.
Full regression passes; normal startup is 1,932,000 offline instructions (<2M).
Routine native acceptance is waived; these checks do not establish native parity.
