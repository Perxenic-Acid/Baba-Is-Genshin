# Sparse native backend test rooms

Restart the local level to load these Lua-authored rooms. No .gil edits are
required. From the initial root selector at (2,2), move right ten times to REF
and press F. From the REF selector's initial (2,2):

| Room | Route inside REF | Ready demonstration |
| --- | --- | --- |
| HAS | Right six times, F | Right twice: push Rock into Water; Flag then Crate are born together at (9,13), because later ON FLAG HAS sees the earlier Flag. |
| EAT | Right seven times, F | Right twice: Avatar eats the STOP Rock at (8,13); its HAS leaves Flag. Another Rock remains farther right for free tests. |
| EMPTY | Right eight times, F | Right once: the EMPTY YOU facing Rock eats it at (12,13), leaving Flag. Avatar remains available for moving words. |

All rooms are 32x30. Rules occupy rows3/6/9, play objects row13, and loose
words use a three-cell grid beginning at row20. There are no hidden Flag WIN
defaults. The room vocabulary includes its supplied words; unused property
catalog entries are omitted. Z restores whole-tree turns. After a rightward
input the selector is at the top-left PARENT block; F returns to REF.

tests/run.lua enters each room through the production input/F closures, executes
the demonstration and undoes back to the root. This validates host integration
under mocks, not success on the actual device. Normal startup stays under the
2M instruction limit (1,438,000 at this change).

Authored world builders use fresh default_world() data directly rather than
instantiating/validating a temporary session that is immediately discarded.
CreateLevelTree still validates the complete plain-data graph first and every
definition's structure; it avoids only a second recursive plain-data walk of
the same already checked graph. Public independent definition validation is
unchanged. These are temporary test fixtures, not the authored puzzle pack.

Native report 2026-11-02: the exported 18:15 log repeatedly records
`renderer:36: 字号超出限制` while tree movement/Undo continues to commit. The
renderer previously fitted long scaled words down to font4/5; the mock checked
integer type only. Fitting now starts at6, and font assignment catches a host
rejection, tries larger sizes through the existing known-size18 path and caches
the accepted replacement. Labels reflow and receive sufficient height for the
accepted size; failed sizes do not get retried on every frame. No single native
minimum is inferred from the log. Mocks cover both minimum6 and a stricter
minimum8 host, complete labels, repeated-frame caching and subsequent movement.
This repairs the observed render-abort path; native latency/success still needs
observation and is not inferred from those mocks.

The same EMPTY room input also exposed backend overhead independently of rendering.
Its first demonstration move fell from 71,536,000 to 32,922,000 instructions in
the same sampled offline input route (about 54% fewer). Fresh condition frames
index only the presence of an EMPTY BROKEN declaration, matching the original
conditions.lua featureindex guard; per-cell status/conditions are never cached.
FACING filters its one witness cell directly instead of dispatching every region
alternative per unit. A 32M unsampled first-input budget guards this route;
the separate 2M normal-startup budget remains unchanged. This remains a large
virtual-occupancy workload, so the measurement does not prove smooth native input.

Projection occupancy validation now builds one local numeric-coordinate index
instead of scanning all entities for every EMPTY effect cell. It is rebuilt on
each projection and never stored on the world. Stacked Object/Text occupancy,
integer/float coordinate equality, grant/deny validation and moved-unit freshness
are covered by tests/projection_occupancy.lua. With this change the same first
EMPTY input uses 29,279,000 instructions without sampling; startup remains 1,438,000.

2026-11-05 follow-up: the rightmost EMPTY room now starts with
`EMPTY NEAR ROCK IS RIGHT` and `EMPTY NEXTTO ROCK IS YOU`. Right once still
consumes the Rock and leaves its HAS Flag. Global direction/FACING words remain
available for free construction. The 32x30 workspace and loose-word spacing stay.

Query frames index declaration presence and lazily index numeric-coordinate
occupancy. ON/NEAR/NEXTTO/FACING reuse that local occupancy; positive ordinary-noun
local conditions prune impossible EMPTY cells before full evaluation. Negative
clauses and GROUP parameters retain the full scan. Only provably unconditional
EMPTY direction frames reuse a direction result; spatial/FOLLOW/status-dependent
frames remain per-cell. Indexes are transient, rebuilt for new frames, and never
stored in world/Undo. Brute-force comparison covers stacked/duplicate/negative/
BROKEN witnesses and changed positions. The native input route now requires <=6M
instructions, down from its former32M guard, and checks that the moved Avatar
reaches the display. Sampled first input: 4,271,000 versus29,822,000 before this
fix; startup remains below2M. Native watchdog involvement is an inference from
workload and symptoms; no new exported device log was available for this report.

2026-11-05 native follow-up: the user could not reproduce the stale board on a
fresh run. The newly exported 11:35 log still reports `renderer:40: 字号超出限制`.
Native range rejection can log without throwing a Lua error, so pcall-based
font probing alone cannot detect it. Scaled setter requests now use at least
the existing 12-point annotation size; full Text reflows at the actual font.
The stricter renderer mock rejects sizes below12 and separately tests a
throwing minimum14 fallback. This removes sub12 requests; exact device range
and elimination of the intermittent stale-board symptom remain unconfirmed.

Movement EAT batches now build the immutable declaration query context once per
relation rather than once per cell. Each source/destination still independently
evaluates conditions and virtual BROKEN, including occupied destination cells
as in installed movement.lua check() around980/1033/1123. Batch/full-query parity
covers changed positions and per-cell BROKEN. No query context enters world/Undo.

`luatex --luaonly tests/native_empty_room.lua` exercises production navigation
and the actual renderer with host controls mocked, then repeated input/Undo.
It checks native avatar-control positions and a 5M instruction guard including
first grid construction; measured3,969,000 instructions. Backend-only profiling
fell from4,714,000 to3,848,000 instructions on the same route (about18%). This
is offline evidence, not a native frame-time measurement.
