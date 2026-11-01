# NOTES

Problem → solution → source. Written so we never debug the same thing twice.

## Godot 4.5 / Android

**A non-empty `gradle_build/min_sdk` requires `use_gradle_build=true`.**
Godot 4.5 refuses to export with `Cannot export project ... "Min SDK" can only be
overridden when "Use Gradle Build" is enabled`. The preset therefore leaves
`gradle_build/min_sdk` empty and relies on the template default.

**minSdk 24 without a Gradle build.**
`gradle_build/use_gradle_build=false` uses the prebuilt 4.5 template, whose
`minSdk` already is 24 — exactly what the spec asks for.
Source: `godotengine/godot@4.5/platform/android/java/app/config.gradle`
(`minSdk: 24`, `targetSdk: 36`, `buildTools: 36.1.0`, Java 17).

**Export preset keys** (`export_presets.cfg`): `gradle_build/export_format=0`
for APK, `=1` for AAB; `architectures/arm64-v8a=true` with the other three
`false`; `package/unique_name`, `version/code`, `version/name`.
Keystore values (`keystore/release*`) stay empty in git and are injected by
`release.yml` into the CI checkout only.

**Landscape + immersive**, `arm64-v8a`, `minSdk 24`: project setting
`display/window/handheld/orientation=4` (sensor landscape) and
`screen/immersive_mode=true` in the preset. Verify on device — the enum value
could not be double-checked against 4.5 docs (site unreachable).

**`--headless` already implies `--audio-driver Dummy`.** Adding the flag
explicitly is harmless and documents intent for the audio tests.
Source: godot-docs `tutorials/editor/command_line_tutorial.rst` (4.5 branch),
row "``--headless`` … (``--display-driver headless --audio-driver Dummy``)".

**Asset import before headless runs.** `tools/import_project.sh` tries
`godot --headless --import` and falls back to `godot --headless --editor --quit`.
The `--import` flag could not be confirmed against the (unreachable) docs, so
the fallback keeps CI honest either way.

## CI / godot-ci

**Image version.** `barichello/godot-ci`'s Dockerfile pins
`GODOT_VERSION="4.5"` by default and installs Android SDK/build-tools,
`openjdk-17`, a debug keystore (`androiddebugkey`/`android`) plus editor
settings pointing at them. Hence `barichello/godot-ci:4.5` everywhere.
Source: `aBARICHELLO/godot-ci` `Dockerfile` and README.

**Setup step.** The image keeps Godot's config under `/root`; the job must move
`/root/.config/godot` to `~/.config/godot` and the
`export_templates/4.5.stable` folder into `~/.local/share/godot/export_templates/`.
Source: godot-ci workflow template.

**Do not vendor GUT.** The sandbox cannot download it; CI downloads the pinned
tag instead (`tools/fetch_gut.sh`, `v9.5.0`) and `.gitignore` keeps
`addons/gut/` out of the repo.

## GUT 9.5.0

**CLI options verified from source** (`addons/gut/cli/gut_cli.gd`, tag v9.5.0):
`-gdir`, `-ginclude_subdirs`, `-gexit`, `-glog`, `-gjunit_xml_file`, `-gconfig`,
`-gprefix` (default `test_`), `-gsuffix` (default `.gd`). Entry point:
`res://addons/gut/gut_cmdln.gd` run with `-s`.
**Version pairing:** GUT 9.5.0 ↔ Godot 4.5.x (bitwes/Gut README version table).

**`.gutconfig.json`** is picked up automatically; we keep `dirs`,
`include_subdirs`, `prefix`, `should_exit` and a JUnit path there, and still pass
the important flags on the command line so CI is explicit.

## gdtoolkit (lint)

**Config file is YAML, not TOML.** gdtoolkit 4.5.0 loads `.gdlintrc` with
`yaml.load` and expects *flat* keys matching its `DEFAULT_CONFIG`
(`max-line-length`, `function-name`, `disable`, `excluded_directories`, …).
A TOML/inid-style file fails with `ParserError: expected '<document start>'`.
Source: `.venv/.../gdtoolkit/linter/__main__.py`.

**Function names:** the default `function-name` regex rejects `_helper()` and
`_on_ready()`-style lowercase handlers, so `.gdlintrc` overrides it with
`_?(_on_[a-z0-9_]+|[a-z][a-z0-9]*(_[a-z0-9]+)*)`.

## GDScript typing traps hit while writing this project

1. **Dynamic methods on typed variables are a compile error.**
   `var e: CharacterBody2D = enemy_scene.instantiate(); e.configure()` fails
   because `configure()` is defined in our script, not in `CharacterBody2D`.
   Fixes used: leave the variable untyped (`var e`), or call
   `e.call("configure", …)`. Behaviour scripts therefore take an untyped
   `enemy` parameter, and `Enemy._behaviour` is untyped.
2. **`var x := our_script.new()` infers the base class** in some positions; use
   `var x = …` when you then call script-defined methods.
3. **A `Control` child of a `Node2D` (the boss) has no parent rect**, so anchor
   presets collapse to zero size. The boss bar is drawn by the HUD instead, and
   the `BossHealthBar` Control was removed.
4. **Signal on a Variant** (`node.died.connect(...)`) is resolved at runtime,
   which is fine, but only if the node is *not* statically typed.

## Audio decisions

**Buses are created at runtime** via `AudioServer.add_bus()` + `set_bus_send`,
instead of hand-writing `default_bus_layout.tres`. Fewer binary/resource
formats to get wrong, and `test_audio_manager.gd` can assert the buses exist.

**All audio is synthesised** (`tools/audio_synth.py`, `audio_recipes.py`,
`audio_music.py`). No downloads, no licence risk, deterministic per commit.
`.ogg` (Vorbis, via `soundfile`) for music loops, 16-bit `.wav` for effects.
Total ≈4.8 MiB, budget in `data/sound_events.json` = 12 MiB.

**Variant generation:** first variant is the base recipe, later variants are
linearly resampled (1.0 + 0.035·i) so they are audibly different rather than
byte-identical duplicates — the first run produced identical twins and
`test_sound_registry.gd` would not have caught it, the checksum diff did.

**Loop seam:** music loops wrap the release tail of the last bar into the start
of the buffer (`make_track()`), so `loop = true` has no click at the seam.

**Ambience lookup order matters:** `play_ambience()` checks `events` before
`music`, otherwise every ambience call logs a bogus "unknown music id" warning.

## Python validators run locally (no Godot needed)

```
python tools/validate_data.py    # levels, entities, i18n, jump feasibility
python tools/validate_audio.py   # registry <-> files, silence, size budget
python tools/check_refs.py      # every res:// reference exists on disk
python tools/gen_audio.py --check
gdlint scripts tests tools
```
All five are wired into `ci.yml` (`data-and-audio` and `lint` jobs).

## Bugs found by the last static review (all fixed)

1. **`StaticBody2D.one_way_collision` does not exist** — one-way platforms need
   `CollisionShape2D.one_way_collision`; the level builder set it on the body.
2. **`load(...).new()` and `dictionary.get(...)` cannot feed `:=`** (`Cannot
   infer the type ... doesn't have a set type`). Fixed with explicit types or
   plain `var x =`.
3. **Signals of a `Node`-typed parameter** (`player.health_changed.connect(...)`)
   do not compile; use `player.connect("health_changed", callable)`.
4. **`enemy.global_position` on a `Node`-typed loop variable** — cast to
   `Node2D` first (`enemy as Node2D`).
5. **Script methods on built-in typed parameters** (`_shoot(enemy: CharacterBody2D)`
   calling `enemy.player_position()`) — behaviour helpers must stay untyped.
6. **JSON numbers arrive as floats.** `SaveManager._normalise()` originally
   required `typeof(raw[key]) == typeof(default)`, so `shards: 45` (float) was
   dropped and the profile silently reset. Now ints are coerced back with
   `int(value)`.
7. **Level entity placement was verified in Python** and four levels had
   enemies, checkpoints, chests and shards floating over pits or buried in
   walls. They were snapped to the ground/platform row, and the rule is now
   enforced by `tools/validate_data.py` (CI job `data-and-audio`).

## Music loop seam measurements

`numpy` check of every `.ogg`: `abs(sample[0] - sample[-1])` is 0.0003–0.015
with peaks ≈0.7, i.e. below a click. The wrap of the last bar's release tail
into the buffer start is what keeps it clean.

## Assumptions to verify on the first CI run

1. `--headless --import` exists in 4.5 (fallback is in place).
2. `barichello/godot-ci:4.5` tag exists on Docker Hub (Docker Hub API was
   unreachable from the sandbox; the Dockerfile default is 4.5).
3. `screen/immersive_mode` and `display/window/handheld/orientation=4` give the
   expected landscape behaviour on a real device.
4. Godot 4.5's Android export in that image does not need extra `sdkmanager`
   packages for a non-Gradle APK export.
5. `Input.vibrate_handheld(ms, amplitude)` two-argument form (used only on
   mobile builds).
