# IDLE (M9.4T)

Installed primary references: Data/conditions.lua idle() at 2137-2139 returns
last_key == 4; Data/syntax.lua command handling sets last_key before movement;
Data/undo.lua restores currentundo.key. Load/clear resets the original value.

IDLE means the current command is wait. A blocked direction or a direction with
no YOU is not idle. Before the first command it is false. Confirmation is a
separate navigation action and does not invent a movement/wait command.

The planner evaluates a shallow private input snapshot before projecting YOU,
SELECT and other rules. Accepted turns attach input_state {from,to} to their
first atomic phase when the input changes. Preview/Commit validates the previous
input; rejection cannot modify it. Whole-tree Undo restores the previous world,
including last_input. Authored boundary reloads reset this runtime field unless
explicitly present in authored data. No UI state owns this condition.

The world validates last_input as none/move/wait. Stage-sequence top-level input
metadata and non-consuming writes are rejected, like existing random metadata.
No new scheduled phase is introduced. Frozen contact declarations re-evaluate
IDLE against the same command. Existing prefix NOT/AND/activation syntax applies;
conditional scoped LEVEL rules retain the documented gap.

Regression coverage: current-input pre-movement YOU, wait-triggered conversion,
NOT IDLE conversion, blocked/no-YOU moves, repeat planning, stale metadata,
invalid inputs and Undo. The scheduler explicitly checks that an otherwise empty
first turn now changes the logical input while recording history. The installed
idle() oracle covers eighteen input/NOT/Object/Text/EMPTY cases.
Normal startup remains below the fixed 2M budget; no native acceptance claimed.
Next: OFTEN/SELDOM stable per-turn random decisions, then GROUP.
