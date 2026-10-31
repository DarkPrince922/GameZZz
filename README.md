# Nightmare Hunter

A 2D platformer for Android: a child with a light walks through nightmare worlds
and fights the monsters under the bed. Landscape, offline, no accounts, no ads,
no network calls in the game itself.

Engine: **Godot 4.5** (GDScript). Tests: **GUT 9.5.0** + headless smoke and bot
runs. Build: GitHub Actions, Android `arm64-v8a`, `minSdk 24`.

---

## Status in one line

Playable vertical slice: hero + multitouch controls, six enemies, four traps,
elite modifiers, world 1 (4 levels + stars), boss 1 with three phases, menus,
versioned saves, shelter upgrades, five weapons, twelve skills, procedural
audio for every event, CI for lint/tests/smoke/bot/APK.
Worlds 2–8 and stages 9–10 content are tracked in `BACKLOG.md`.
Read `BLOCKERS.md` **before trusting any green build** — CI has never run in
the environment where this code was written.

## Run it locally

1. Install Godot 4.5 (standard build, not .NET) and the 4.5 export templates.
2. Install GUT 9.5.0 into the project (it is not committed):

   ```bash
   bash tools/fetch_gut.sh
   ```

3. Open `project.godot` and press F5, or:

   ```bash
   godot --path .
   ```

Desktop controls (handy while developing): `A`/`D` or arrows to run, `Space`
jump, `J` attack, `1`–`3` skills, `Shift` dash, `Ctrl`/`S` crouch, `Esc` pause.
On the phone everything is on-screen: stick on the left, jump/attack/dash and
three skill buttons on the right, multitouch.

## Tests and checks

```bash
# GDScript lint (gdtoolkit, same version as CI)
pip install "gdtoolkit==4.5.0"
gdlint scripts tests tools

# Content + audio + reference checks (no Godot needed)
pip install soundfile numpy
python tools/validate_data.py
python tools/validate_audio.py
python tools/check_refs.py

# GUT unit tests (after tools/fetch_gut.sh)
godot --headless --audio-driver Dummy -s res://addons/gut/gut_cmdln.gd \
      -gdir=res://tests/unit -ginclude_subdirs -gexit

# Every scene, 60 frames each
godot --headless --audio-driver Dummy -s tools/smoke_test.gd

# Bot walks all world-1 levels and kills boss 1
godot --headless --audio-driver Dummy --fixed-fps 60 -s tools/bot_test.gd
```

## Build the APK

In CI (`Android` preset, debug keystore generated inside the image):

```bash
godot --headless --export-debug "Android" build/nightmare-hunter-debug.apk
```

Signed release (tag `v*`, secrets in GitHub):

```bash
godot --headless --export-release "Android Release" build/nightmare-hunter-release.aab
godot --headless --export-release "Android" build/nightmare-hunter-release.apk
```

Secrets used by `release.yml`:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER`, `ANDROID_KEYSTORE_PASSWORD`.
The keystore is decoded into `/tmp` on the runner; it is never committed.

Debug APK for a stage is attached to the `stage-N-done` release and uploaded as
the `nightmare-hunter-debug-apk` artifact.

## Gesture of the repository

```
project.godot            engine config, autoloads, landscape orientation
export_presets.cfg       Android debug (APK) + release (AAB)
scenes/                  thin .tscn wrappers; UI is built in code
scripts/autoload/        Settings, DataDB, Loc, SaveManager, AudioManager, Game
scripts/core/            combat maths (static, unit-tested)
scripts/player/          player controller + weapon controller
scripts/enemies/         enemy core + six behaviour scripts
scripts/bosses/          boss framework + Bed Monster
scripts/level/           level builder from JSON
scripts/traps/           spikes, falling platform, laser, moving wall
scripts/pickups/         shard, chest, checkpoint, goal door
scripts/skills/          skill manager, plush friend, fire zone
scripts/ui/              HUD, multitouch controls, menus, star screen
data/                    enemies, weapons, skills, upgrades, bosses, worlds, i18n
data/levels/*.json       level geometry and entity placement
assets/audio/            generated .wav effects + .ogg loops
assets/graphics/         icon (SVG, drawn for this project)
tools/                   audio generator, validators, smoke/bot runners
tests/unit/              GUT tests
.github/workflows/       ci.yml (push/PR), release.yml (tags v*)
```

## Content is data, not code

Enemies, elites, weapons, skills, upgrades, bosses, worlds, level layouts,
sound registry and translations are JSON under `data/`. Adding a new enemy is a
JSON entry plus a behaviour script; adding a level is a new
`data/levels/*.json` and an entry in `data/worlds.json`.

Level geometry is described by `ground_runs: [[ground_row, columns], …]`
(row `0` = a pit) plus platforms, ladders, traps, enemies, shards, chests,
checkpoints and secrets. `tools/validate_data.py` proves every level is inside
its own bounds and that no gap or climb exceeds what the jump can clear.

## Audio rules (spec section 4)

* One autoload (`AudioManager`); nothing else touches `AudioServer`.
* Buses: `Master`, `Music`, `SFX`, `UI` (created at runtime, volume follows the
  three sliders).
* `data/sounds.json` maps event id → files, volume, pitch variance, variants,
  spatial flag. It is generated by `tools/gen_audio.py` from `tools/sfx_specs.py`
  and `tools/audio_music.py`.
* 16-player pool, farthest/oldest slot reused, never more than the cap.
* Frequent sounds carry several variants and ±10 % random pitch.
* Enemies/traps/bosses use `AudioStreamPlayer2D`; hero and UI are flat.
* Pause mutes SFX, keeps UI audible, ducks music.
* Everything is synthesised from code, so all audio is original CC0 work
  (`CREDITS.md`), deterministic and small (≈4.8 MiB total).

See `PROGRESS.md` for what to listen to on a real phone, `NOTES.md` for the
engineering traps we hit, and `BACKLOG.md` for what is deliberately not done.
