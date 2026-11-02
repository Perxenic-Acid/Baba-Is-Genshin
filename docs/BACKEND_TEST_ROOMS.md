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
