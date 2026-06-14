# Turn Clip Runtime Integration Handoff

This note is for the game-side worker consuming sprite exports from this tool.

## Export Contract

Enable these export settings when turn animations are needed:

```json
{
  "direction_count": 8,
  "include_turn_clips": true
}
```

The PNG sheet still uses `sheet_columns = frame_count`. With turn clips enabled, `sheet_rows` becomes 24:

- Rows 0-7: normal swim loops, one row per facing direction.
- Rows 8-15: `turn_left`, one 45-degree clip per start direction.
- Rows 16-23: `turn_right`, one 45-degree clip per start direction.

Right-turn rows are intentionally ordered by playback continuity, not by the base direction list:

```text
east -> south_east
south_east -> south
south -> south_west
south_west -> west
west -> north_west
north_west -> north
north -> north_east
north_east -> east
```

Do not hardcode row numbers if possible. Read `animation_rows` from the metadata JSON. Each row descriptor has the row index and the clip semantics:

```json
{
  "row": 8,
  "clip": "turn_left",
  "from_direction": "east",
  "to_direction": "north_east",
  "turn_direction": "left",
  "turn_step": 1,
  "delta_degrees": 45,
  "chainable": true
}
```

Frame folders follow the same metadata:

```text
frames/east/frame_000.png
frames/turn_left/from_east_to_north_east/frame_000.png
frames/turn_right/from_east_to_south_east/frame_000.png
```

## Direction Model

Direction order is fixed:

```text
0 east
1 north_east
2 north
3 north_west
4 west
5 south_west
6 south
7 south_east
```

`turn_left` advances by `+1` direction index. `turn_right` advances by `-1` direction index. Wrap with modulo 8.

## Runtime State Machine

Treat a 45-degree turn as the atomic unit.

Suggested state:

```text
current_direction_index: 0..7
target_direction_index: 0..7
state: swim | turning
queued_turn_steps: signed integer
active_turn_row
active_frame
```

When the entity wants a new target direction:

1. Compute the shortest signed delta from current direction to target direction.
2. If delta is positive, chain `turn_left` clips.
3. If delta is negative, chain `turn_right` clips.
4. If delta is 4 or -4 for a 180-degree turn, choose the side from player input, steering history, or the previous turn direction. Do not alternate randomly per frame.
5. Play one 45-degree turn clip.
6. On clip end, set `current_direction_index = to_direction_index`.
7. If more steps remain, immediately start the next 45-degree clip from the new direction.
8. When no steps remain, return to the swim row for `current_direction_index`.

Pseudo-code:

```text
delta = shortest_signed_step(current, target, 8)

while delta != 0:
    step = 1 if delta > 0 else -1
    clip = "turn_left" if step > 0 else "turn_right"
    next = (current + step + 8) % 8
    row = find animation_rows where clip/from_direction_index/to_direction_index match
    play row once
    current = next
    delta -= step

play swim row for current
```

## 90-Degree And 180-Degree Turns

Do not look for dedicated 90-degree or 180-degree clips in the export. Compose them:

```text
90 degrees  = two 45-degree clips
135 degrees = three 45-degree clips
180 degrees = four 45-degree clips
```

This keeps the atlas small and preserves the generated turn pose quality. Add a special U-turn clip later only if playtesting shows four chained 45-degree clips feel too slow or too soft.

## Timing And Blending

Turn clips are chainable. They start and end with `turn_amount = 0`, and peak around the middle frame. This makes them safe to enter from swim and return to swim.

For responsive controls, let gameplay movement rotate continuously if needed, but drive the displayed sprite through the nearest 8-way direction and the queued 45-degree clips. Do not rotate the sprite bitmap to fake missing directions unless the game art style accepts visible projection and lighting errors.

Recommended behavior:

- During `turning`, lock sprite row selection to the active turn clip.
- At the final frame, snap `current_direction_index` to the clip's `to_direction_index`.
- Preserve swim animation phase if possible, so returning to swim does not visibly restart the body wave.
- For rapid target changes, finish the current 45-degree clip or allow cancellation only near clip boundaries. Mid-clip cancellation can look jittery.

## GIF Preview Note

The export preview GIF may reorder right-turn rows so the preview rotates continuously. The sprite sheet and metadata row order do not change. Game integration should use `animation_rows`, not GIF frame order.
