# EMPTY conversion orientation

## M9.8E

Installed convert.lua:479-545 (emptyconvert) queries emptydir for each ordinary
product and uses fixedrandom(0,3) when it returns 4. Installed syntax.lua:402
(createall_single) queries once for an entire ALL group, even if every individual
noun is protected. This differs from repeated ordinary conversion products.

RW_PlanConversions now uses the shared current-frame EMPTY direction query for
IS/BECOME/WRITE products. Text and ordinary products keep original_name=@empty;
conversion still does not invoke HAS. Each ordinary product gets an independent
unset-direction draw. ALL products share their group's direction; a selected but
fully denied group can produce an RNG-only phase. Existing palette/multiplicity
and frozen vacancy selection remain unchanged.

The seventh planner result is optional random_state={from,to}. The conversion
stage includes it in Preview/Commit/stale validation/whole-tree Undo; later MAKE
continues that stream. Query/draw/creation failures cannot mutate host/global RNG
or the input world. The explicit diagnostic EMPTY TEXT Commit also carries it.
The first six planner results retain their existing positions. EMPTY relations
retain their generated frame so direction works for callers which supply only
compiled relations, without an explicit third raw-rule argument.

Tests/empty_conversion_direction.lua covers per-product draws, known direction,
FOLLOW, Text, SLEEP, target bans, repeated turns/replay, conversion-to-MAKE stream
continuity, stale metadata and late atomic failure. ALL tests cover shared facing,
mixed ordinary/group draw order and denied-group RNG-only Undo. The standalone
reference_empty_conversion_direction.lua executes installed emptyconvert across
180 normalized cases and createall_single across 30 group/denial cases.

The Park-Miller planning stream deliberately differs from the original host RNG
sequence; source oracles inject the same stream to compare draw count/order. The
existing phase uses frozen occupancy and declarations: native live unit-list
changes between individual created products are not reproduced by orientation
queries. Cell-based recursive emptydir invalidation remains the documented boundary
from M9.8D. EMPTY movement and destruction/HAS lifecycle remain separate work.
No native acceptance is inferred from offline tests.
