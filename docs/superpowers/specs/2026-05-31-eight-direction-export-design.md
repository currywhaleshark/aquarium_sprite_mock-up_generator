# Eight Direction Sprite Export Design

## Goal

Support exporting generated creature animation sprites in eight view directions while preserving the current one-direction export path.

## Output Contract

- Existing presets without `export_settings.direction_count` keep exporting a one-row sheet.
- Presets with `export_settings.direction_count = 8` export a sheet where rows are directions and columns are animation frames.
- Direction order is:
  - `east`
  - `north_east`
  - `north`
  - `north_west`
  - `west`
  - `south_west`
  - `south`
  - `south_east`
- Frame files are written under `exports/<preset>/frames/<direction>/frame_000.png`.
- Metadata records `direction_count`, `directions`, `sheet_columns`, and `sheet_rows`.

## Rendering Approach

The exporter keeps the active camera and viewport setup, then rotates the rig around the Y axis for each direction before capturing the existing swim animation phases. This avoids changing camera controller behavior and keeps preview/export framing consistent with the current tool.

The rig rotation is restored after export, and `auto_animate` is restored to its previous value.

## Scope

In scope:

- One-row export compatibility.
- Eight-row sprite sheet export.
- Direction subfolders.
- Metadata fields for direction-aware consumers.
- Focused unit-style tests for sheet layout and metadata.

Out of scope:

- Direction-specific turn poses.
- Mirroring optimizations.
- Separate per-direction sprite sheets.
- UI toggle beyond using export settings already surfaced through the parameter panel.
