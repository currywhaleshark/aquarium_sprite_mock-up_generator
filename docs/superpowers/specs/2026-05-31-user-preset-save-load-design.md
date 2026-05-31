# User Preset Save/Load Design

## Goal

Allow users to save the currently edited fish setup as a reusable preset and load it later. The saved preset must include both body shape settings and motion settings, including `swim_mode` and fine-tuned motion values.

## Scope

In scope:

- Save the current edited preset to `user://presets`.
- Load built-in presets from `res://presets` and user presets from `user://presets`.
- Show both built-in and user presets in the existing preset dropdown.
- Add a compact name field and save button near the preset dropdown.
- Preserve body, head, fin, tail, motion, visual, camera, display, export, and reference settings already carried by `current_preset`.

Out of scope:

- Cloud sync.
- Delete/rename preset UI.
- Import/export file browser.
- Version migration beyond existing preset normalization.

## Data Model

User presets use the existing JSON preset schema. `PresetStore.normalize_preset()` remains the read path. `BodyProfile.split_parameters_into_profiles()` remains the write path for structured profile sections.

Saved user preset names become filesystem-safe slugs:

- lower-case not required;
- spaces become underscores;
- ASCII letters, digits, Hangul, underscore, and hyphen are preserved;
- other punctuation and emoji are dropped;
- empty names fall back to `user_preset`.

If a filename already exists, saving overwrites it intentionally. This keeps the first pass simple and predictable.

## UI

The side panel gets a compact row below the preset dropdown:

- `LineEdit` for the preset name.
- `Button` labeled `현재 설정 저장`.

On save:

1. Copy `current_preset`.
2. Set the preset name from the field.
3. Split current parameters into structured profiles.
4. Save to `user://presets/<slug>.json`.
5. Reload preset list.
6. Select the saved preset in the dropdown.
7. Show success or failure text through the existing export/status panel.

## Testing

Automated tests should verify:

- User preset filenames are sanitized.
- Saving a user preset writes valid JSON.
- Loading all presets includes user presets.
- Saved presets preserve body profile and motion profile values.
- Main UI save flow updates the preset dropdown and current preset.
