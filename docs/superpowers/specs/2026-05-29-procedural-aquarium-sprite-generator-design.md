# Procedural Aquarium Sprite Generator Design

## Goal

Build a Godot 4.x MVP tool that creates simple primitive-based fish and ray rigs, previews them through orthographic aquarium camera presets, edits parameters in real time, and exports transparent PNG animation frames, a one-row sprite sheet, and metadata JSON for the current aquarium game.

## Scope

The generator outputs 2D PNG sprites, not game-ready 3D models. MVP includes fish and ray rigs, sine-loop animation, six bundled presets, transparent SubViewport preview, display-size preview, PNG sequence export, sprite sheet export, and metadata export.

Out of scope: Blender integration, AI images, skeletal rigs, automatic import into the game project, eight-direction export, physics fluid motion, atlas packing, and GIF/WebP previews.

## Architecture

`Main.tscn` hosts the UI and a transparent `SubViewport`. Creature scripts build meshes in code from primitives and lightweight custom triangle meshes. Camera presets are data-driven helper functions. Export scripts pose the active rig at evenly spaced loop phases, capture the viewport texture, save frames, assemble a one-row sheet, and write metadata.

## Verification

The project should be recognized by Godot, open `scenes/Main.tscn`, load all six JSON presets, and export identical-size transparent PNG frames plus sheet and metadata under `exports/<preset_name>/`.
