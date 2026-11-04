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
