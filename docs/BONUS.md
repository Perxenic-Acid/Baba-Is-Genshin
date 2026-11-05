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

M9.8K adds virtual EMPTY BONUS through its separate native late-cell scan: one
reward per scan, cell-local HAS, SAFE suppressing the empty pickup, matching-layer
scoped LEVEL YOU, atomic counters/events, campaign reload and whole-tree Undo.
Real BONUS multiplicity/SAFE behavior is unchanged. Synthetic LEVEL BONUS remains
pending; see [EMPTY_LIFECYCLE.md](EMPTY_LIFECYCLE.md) for source evidence and tests.

## Scoped LEVEL BONUS

Installed blocks.lua2993-3080 processes all YOU declarations, then YOU2 (3D is
excluded by user scope). Matching real collectors use stored FLOAT against current
map FLOAT; scoped LEVEL collectors need no real witness or layer comparison.
EMPTY YOU/YOU2 uses its declared placeholder and global FLOAT even without eligible
vacant cells. Target SAFE is irrelevant. On a captured-SAFE map, one active BONUS
row awards exactly one bonus, regardless of collector/grant multiplicity; repeated
physical BONUS rows award separately. The map and collectors remain.

An unsafe map immediately calls destroylevel("bonus") and returns before MF_bonus.
tools.lua1533-1622 confirms that deferred destruction also does not issue a reward.
This path therefore clears the board without HAS or bonus increment and skips
later scoped motion/RNG. This deliberately differs from ordinary BONUS pickup.

RW_ResolveScopedBonus implements current raw collector queries; the ordered scoped
scheduler commits each reward as a stale-checked bonus_state child stage, with a
transient source="level" event dispatched only after outer Commit. Counter-only
stages consume the shared flat-stage budget. Prefix compile limits retain earlier
awards/events; ordinary errors reject everything. Existing campaign-delta accounting
and whole-tree Undo apply to the same local counter without special UI state.

tests/reference_level_bonus.lua executes the installed branch in1024 combinations
and compares production rewards/returns. Extra cases cover physical Text, BROKEN
and NOT collectors. Turn/mapped input cases cover duplicate rows, counter-only
stages, suffix motion, unsafe no-reward/no-HAS/no-RNG, EMPTY, limit/error prefixes,
stage budget and whole-tree Undo. Native saving/AV and broader scoped condition/
host-boundary timing gaps remain deferred; synthetic LEVEL BONUS is now supported.
Custom typed LEVEL block archetypes are recognized as synthetic collectors and
complementary OPEN/SHUT declarations even with no physical entrance present.

## LEVEL YOU collecting real BONUS: serial phase infrastructure

Installed blocks.lua2626-2666 differs from both ordinary pickup and LEVEL BONUS:
each BONUS declaration selects its current group, then queries victim SAFE before
map FLOAT for each identity, deleting immediately with HAS. Later victims see
earlier deaths/births, and later declarations may select newborns. A SAFE target
does not count as a pickup. The entire active LEVEL YOU/YOU2 row awards at most
one bonus, after all declaration groups complete, rather than one per victim.
Pre-delete WIN/END evidence is captured earlier in that original row.

RW_LevelContactDeclarations/Targets expose the same per-declaration selection
previously used by HOT, whose wrappers retain their behavior. The distinct
level_you_bonus destruction kind enables the existing serial SAFE/FLOAT/HAS
initializer and completed-victim filtering without mislabeling events as HOT.
tests/reference_level_you_bonus.lua executes the unchanged installed BONUS scan
and compares these production building blocks in3072 cases: duplicate clauses,
HAS newborns, independent SAFE/FLOAT and allocators/survivors.

This prepares the phase only; LEVEL YOU's real BONUS scan is not yet wired into
the scheduled whole-row execution. Integration must preserve its preceding DEFEAT
and WIN/END queries, one reward after all groups, and only completed prefixes on
creation/query limits. It must not silently substitute an ordinary batch pickup.
