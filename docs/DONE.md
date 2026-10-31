# DONE (M9.6D)

Installed original sources: Data/blocks.lua block() opening DONE loop (before MORE),
levelblock() action == done and literal ALL IS DONE completion branch;
Data/tools.lua delunit() versus delete(); Data/features.lua getunitswitheffect()
and findallfeature(). Tests execute original DONE and ALL completion code with host
callbacks, 112 cases. Animation-only random values do not consume simulation RNG.

## Logical retirement

Real DONE units retire after conversion/FOLLOW/FALL, before MORE/TELE/contact phases.
This is direct identity removal, not destruction: SAFE/FLOAT do not prevent it and
HAS never runs. Intrinsic facing/links and allocator state remain in the transaction
snapshot for Undo. Duplicate grants do not duplicate logical removals. Conditional,
negative, MIMIC/GROUP and BROKEN grants use the normal property projection.

Unconditional scoped LEVEL DONE retires every real unit, including physical Text,
independently of those units' SAFE/BROKEN status. Scoped NOT DONE or scoped BROKEN
can disable the LEVEL directive. It does not add a third Undo-only terminal state.
The resulting empty board can still receive ordinary commands.

Deleted physical Text does not cause a reparse halfway through original block()
logic: MORE uses the pre-DONE raw declarations, with current identities/conditions
re-evaluated after removal. After MORE, force normal recompilation rather than
reuse the old frame. Grounded WORD/complexity checks and terminal commits remain
in the existing later compilation barriers. Newborns produced after this DONE phase
are not retired until the next DONE phase. DONE+MORE sources cannot grow first.

## ALL completion

Lowering preserves a compiler-only all_done marker for literal positive ALL IS DONE
(after MIMIC/GROUP expansion), alongside normal ordinary-noun property expansion.
The marker never becomes a conversion or persisted world fact. As in original
custom/editor levelpack mode, completion requires a matching non-level unit and a
DONE target-instance count at least equal to non-Text/non-level unit count. Physical
Text can count as a found/matched target; duplicate property declarations count
repeatedly. Preserve this original threshold even when it does not mean unique
coverage. Literal ALL directive conditions affect grants through ordinary evaluation;
the completion branch itself checks raw directive presence, like the original.
Merely making each ordinary unit DONE without an ALL directive does not win.

The turn retains done_win plus an all_done event, and level action records normal
win/navigation with existing conversion/scoped terminal precedence. Events survive
PLAY aggregation; only successful whole-tree Commit dispatches native diagnostics.
Unit retirements, tree outcomes, navigation, history and IDs undo atomically.

## Deliberate remaining scope

Base-game-specific MF_allisdone/save/credits choreography and DONE falling animations
are deferred host/frontend work; our backend models the custom/editor levelpack
completion route. Conditional scoped LEVEL context remains deferred. Virtual EMPTY
DONE has no unit retirement: the original emptydone flag only requests a DONE
sound, which remains deferred frontend work. Exact original call order
between levelblock() host callbacks and unit block() is not claimed; synthetic scoped
retirement is integrated at the shared pre-MORE barrier. Existing authored ALL palette
rules still apply; this does not globally register all official noun types.
