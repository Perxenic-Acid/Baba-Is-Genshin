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

Native campaign reward UI and cross-platform persistent saving belong to later
host work. Synthetic LEVEL and virtual EMPTY routes are described below.
The installed removal-array/fixed-ID aliasing accident is not mapped onto our small
persistent identity allocator. Ordinary engine condition-dispatch differences remain
documented contact-system gaps. This does not claim full original board/event scheduling parity.

M9.8K adds virtual EMPTY BONUS through its separate native late-cell scan: one
reward per scan, cell-local HAS, SAFE suppressing the empty pickup, matching-layer
scoped LEVEL YOU, atomic counters/events, campaign reload and whole-tree Undo.
Real BONUS multiplicity/SAFE behavior is unchanged. See
[EMPTY_LIFECYCLE.md](EMPTY_LIFECYCLE.md) for source evidence and tests.

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

## Ordered LEVEL YOU/YOU2 row integration

The phase above is now wired into RW_PlanScopedLevelSequence for each active
YOU/YOU2 declaration. Motion is flushed first. RW_LevelYouPreflight checks real
DEFEAT declarations with current raw map SAFE before FLOAT; victim SAFE is
irrelevant. EMPTY DEFEAT uses its placeholder/global FLOAT and captured map SAFE.
An eligible unsafe map is retired immediately, without pickup/HAS or later RNG.
Preflight then captures real WIN and END witnesses before BONUS deletion.

Each BONUS declaration is selected at the current child snapshot, then deleted
serially using level_you_bonus. Survivors retain the phase's stored FLOAT, while
newborns receive projected status before later groups. After all groups, EMPTY
WIN/END placeholders are queried at the post-delete snapshot. Only then does a
completed scan with an actual death emit one atomic bonus_state reward/event.
Remembered real WIN/END evidence and the late EMPTY result resolve WIN before
END, stopping suffix motion. SAFE victims never issue rewards. A compile limit
before the reward retains completed deaths/births but issues no reward; ordinary
errors reject the whole transaction. Stage-budget failure follows the same rule.
END retains the source/target identity evidence, not just a Boolean, so a deleted
END+BONUS target still creates the campaign ending record/event after Commit.
Mapped production tests inspect that committed record and campaign bonus total.

Deliberate user precedence: synthetic scoped LEVEL WIN/DEFEAT/END declarations
continue at their own ordered rows, rather than being pulled forward as self
contacts of YOU. This preserves LEVEL IS DEFEAT AND WIN failure/frozen-YOU and
SELECT behavior. Real/EMPTY external DEFEAT witnesses keep the native retirement
path above. Conversion-before-terminal priority is unchanged.

tests/reference_level_you_preflight.lua compares the unchanged installed pre-BONUS
branch in512 real/EMPTY DEFEAT, WIN/END and layer/SAFE combinations, excluding the
deliberate synthetic terminal override. Transaction tests cover both control
channels, duplicate groups/HAS newborns, single rewards, pre-delete WIN/END,
SAFE protection, defeat priority, suffix RNG, late-query terminal/error prefixes
and mapped production wait/whole-tree Undo. Existing scoped condition dispatch,
saved surroundings, grouped earlier contacts and native host-boundary timing
remain shared limits; no complete native scheduler parity is claimed.

## Ordinary BONUS declaration and unit order

Installed features.lua319-383 getunitswitheffect returns one collector per physical
declaration/unit instance; blocks.lua1788-1830 concatenates YOU then YOU2, then
queries each BONUS declaration separately through tools.lua236-269 findtype.
handledels (blocks.lua1927+) deletes the first occurrence of each queued identity.
The former count-only implementation preserved totals but grouped events by sorted
identity and also sorted victims, losing declaration order before HAS allocation.

RW_ProjectWorld now publishes transient bonus_contact_groups with control/control2/
bonus declaration lists, filtering denied grants and retaining duplicates. Each
group uses world.unit_order, then sorted missing IDs for diagnostic compatibility.
RW_ResolveBonusContacts traverses both channels and target groups in that order;
unsafe victims retain first encounter order. Manual diagnostic worlds without the
projection metadata keep their capability/count fallback. No dispatch metadata is
committed to raw worlds, allocators, boundaries or Undo.

tests/reference_bonus_order.lua executes unchanged installed getunitswitheffect,
findtype, pickup loops and handledels in2048 cases, comparing the complete reward
event sequence and unique deletion order. Cases include same-noun stacks, reversed
unit/declaration order, both control channels, duplicates and SAFE/FLOAT. A production
bonus plan verifies resulting HAS allocation order, rewards and Undo. Existing
72-case ordinary BONUS tests retain their multiplicity/self-contact coverage.

Per-cell arrival order now lives in sparse world.cell_order, independently of the
global unit_order. Preview/Commit replay displacement and intermediate motion
history, retain ordered replacement/create dispatch, remove deleted IDs and omit
canonical stacks. Whole-tree snapshots restore it with Undo. BONUS filters each
target declaration through the collector's tile order. Direction-only operations
do not reorder; explicit changed move updates do. tests/cell_order.lua executes
the installed tools.lua addunitmap/updateunitmap and checks arrival order, BONUS,
zero-net round trips, sparse normalization, validation and Undo.
Boundary selector placement uses that same arrival application path. Reload
filters authored tile lists against persistent entrance retirements/replacements
and appends restored identities in global order, retaining immutable snapshots.
Boundary tests validate the reloaded world and selector arrival stacks.
Tile keys normalize integral floats and integers to the same coordinates,
including collector lookups; numeric representation cannot split one stack.

History map_update distinguishes native update from updatedir/direct alignment.
SHIFT tags impulse turns, queued movement and final alignment separately; TELE
tags displacement, and BACK follows the original moved-versus-updatedir branch.
Validation rejects nonboolean tags and direction-only tags with displacement.
Legacy untagged rows retain spatial-arrival behavior. Installed update/updatedir
functions verify both same-cell direction paths and Undo in tests/cell_order.lua.

Scope: other contact consumers still retain their prior ordering. Raw condition query timing
remains projected rather than repeated per collector; no full parity is claimed.
