# CREDITS

## Audio — 100 % original, CC0

Every sound effect and music loop in `assets/audio/` is synthesised by this
repository's own code. No samples, no third-party audio files.

- Generator: `tools/gen_audio.py`
- Synthesis engine: `tools/audio_synth.py`
- Per-event recipes: `tools/sfx_specs.py`, `tools/audio_recipes.py`
- Music loops: `tools/audio_music.py`
- Registry written by the generator: `data/sounds.json` (82 effects, 13 loops,
  ≈4.8 MiB)
- Regenerate with `python3 tools/gen_audio.py` (deterministic, seeded per
  filename) or `--force` to rebuild everything.

Licence: **CC0 1.0 (public domain dedication)** — authored for this project by
the project itself. You may copy, modify and redistribute the audio without
attribution; keeping this file is polite, not required.

## Graphics

- `assets/graphics/icon.svg` — hand-written SVG for this project, CC0.
- All in-game visuals are drawn at runtime with Godot primitives
  (`draw_rect`, `draw_circle`, `draw_colored_polygon`, `draw_line`,
  `draw_string`) from `_draw()` implementations in `scripts/`.
  No sprite or tileset assets are used yet (see `BACKLOG.md`).

## Fonts

Godot's built-in default font (`ThemeDB.fallback_font`) is used for all text.
No font files are bundled, so no font licence applies to this repository.

## Engines and tooling

- **Godot Engine 4.5** — MIT licence — https://godotengine.org
- **GUT (Godot Unit Test) 9.5.0** — MIT licence — https://github.com/bitwes/Gut
  Downloaded by `tools/fetch_gut.sh`, not vendored in this repository.
- **gdtoolkit 4.5.0** (`gdlint`) — MIT — https://github.com/Scony/godot-gdscript-toolkit
- **godot-ci** Docker image (`barichello/godot-ci:4.5`) — MIT —
  https://github.com/aBARICHELLO/godot-ci
- **Python**: `numpy`, `soundfile` (BSD/ISC style licences) — used only by the
  offline tooling, never shipped in the APK.

## Third-party services in the game

None. The game performs no network requests, has no accounts, no analytics, no
ads, and the Android preset explicitly disables the `internet` permission.
