# BONUS (M9.6C)

Primary source: installed Data/blocks.lua post-HOLD YOU/BONUS/END/WIN loop,
then handledels before CRASH; Data/features.lua getunitswitheffect preserves
physical declaration multiplicity. Tests execute the original post-HOLD loops
unchanged with host callbacks in 72 cases. Host fixed IDs are adapted to 1001/1002,
separate from logical entity IDs and removal-array indices.

## Real-unit contacts and ordering

After MAKE, before CRASH, surviving real YOU/YOU2 touch same-FLOAT BONUS units.
Self-contact counts. SELECT never collects. Each applicable YOU property instance
and BONUS property instance contributes a pickup; duplicate declarations remain.
SAFE prevents deletion but not rewards, so a safe BONUS can be collected again on
later turns. Distinct pickups remain events; removal/HAS occurs once per victim.
HAS products use frozen declarations, direction, position and current birth-status
initialization, and do not recursively collect in this phase. Conditions/BROKEN/NOT
use the ordinary current-identity projection. Contact declarations are frozen as
for other contact phases; rendering does not query or issue awards.

Original WIN detection precedes the handledels barrier. The bonus service captures
pre-delete WIN contact so a collected BONUS/WIN (including a self-collector) still
wins even after removal. Ordered scoped LEVEL outcomes and conversion priority
retain precedence. Surviving late CRASH/compile limits still lock only after the
triggering BONUS stage has committed.

## Atomic counters and events

World bonus_count is local earned count since authored runtime reload; optional
bonus_state={from,to} is stale checked, nonnegative integer, monotone and bounded
by the normal ID/counter ceiling. Counter-only plans count as changes. It belongs
to flat stages, never the diagnostic top-level stage summary. Failed later stages
consume no rewards. Local Undo restores the world counter and removed units/IDs.

Level-tree bonus_count is the campaign total. RW_PlanLevelAction adds only the
accepted active turn's local delta before outcomes/returns. Navigation and authored
runtime reload preserve the campaign total while resetting ordinary runtime facts.
Whole-tree Undo restores the total along with level navigation and all instances.
Native reward diagnostics dispatch only after successful whole-tree Commit, like
PLAY; no host save, particle or sound side effect is performed while planning.

Creation-status recursion commits the already-issued pickups plus the actual
HAS prefix and retained triggering parent, then enters the existing Undo-only
state. Non-limit failures reject the entire transaction.

## Remaining scope

Synthetic scoped LEVEL/virtual EMPTY BONUS contacts and native campaign reward UI
are not implemented. Cross-platform persistent saving belongs to later host work.
The installed removal-array/fixed-ID aliasing accident is not mapped onto our small
persistent identity allocator. Physical unitlist ordering is sorted IDs here; the
ordinary engine's serial handledels condition-order differences remain documented
contact-system gaps. This does not claim full original board/event scheduling parity.
