# PROGRESS

## 2026-10-31 — stages 0–6 (vertical slice), stages 7–10 not started

**Local verification actually run:** `gdlint scripts tests tools` → "Success:
no problems found"; `tools/validate_data.py` → OK (levels, entities, i18n,
jump feasibility, entity-on-ground rule); `tools/validate_audio.py` → OK
(82 events, 13 loops, 4.81 MiB, no silent files); `tools/check_refs.py` → OK
(243 `res://` references resolve); music seam check ≤0.015 amplitude; an
independent static review pass fixed 7 compile-level bugs (see `NOTES.md`).

**CI:** green — https://github.com/DarkPrince922/GameZZz/actions/runs/41260050271
(commit c920d54, run #25): GDScript lint, data/audio/reference checks, GUT
(10 suites), scene smoke test, bot playthrough of all four world-1 levels + boss
1, and the debug APK build with ABI/size verification.
APK artifact: Actions → run #25 → `nightmare-hunter-debug-apk`.

**CI link (legacy note):** none — no GitHub remote or token was available in this environment,
so `gh run watch` never ran. See `BLOCKERS.md`. Everything below was verified
locally with the tools that exist here (gdtoolkit lint, the Python validators,
audio analysis); Godot itself was not available, so GUT, smoke and bot runs are
**written but unexecuted**.

### Stage 0 — skeleton and CI
- Godot 4.5 project, landscape, autoloads, folder layout.
- `scenes/minimal.tscn` plus real scenes for menu, level, player, enemy, boss, HUD.
- `ci.yml`: lint → GUT → smoke → bot → audio/data checks → debug APK → artifact,
  plus a `stage-N-done` release job; `release.yml`: signed AAB + APK from secrets.
- GUT pinned at 9.5.0, fetched by `tools/fetch_gut.sh` (not committed).
- `AudioManager` skeleton + `data/sounds.json` + registry tests.

### Stage 1 — hero and controls
- Virtual stick and buttons with true multitouch (per-touch-index tracking),
  sizes/opacity from settings.
- Run, jump with coyote time and jump buffer, double jump (unlockable), dash
  (unlockable), crouch, ladders, camera smoothing.
- Light sword combo (3 hits), health, invincibility window, knockback, death
  and respawn at the last checkpoint.
- Hero sounds: steps (4 variants), jump, double jump, land, dash, crouch,
  climb, hurt, death, respawn, low-health cue.
- Tests: `test_player_movement.gd`, `test_player_damage.gd`.

### Stage 2 — enemies, traps, shards
- `enemy.gd` + six behaviours: shadow, flyer, jumper, shooter, bomber,
  shieldbearer. States: patrol, chase, attack (data-driven numbers).
- Traps: spikes, falling platform, laser, moving wall.
- Dream shards drop from kills, bob, are collected, feed the HUD counter,
  chain pitch rises; chests count as collectibles.
- Elite modifiers: fast, vampiric, reviving.
- Sounds for every enemy/trap/shard event, spatialised where it matters.
- Tests: `test_enemy.gd`, `test_combat.gd`.

### Stage 3 — world 1
- Four levels as JSON (`data/levels/world1_level1..4.json`) with checkpoints,
  secrets, chests, shards, traps and mixed enemy sets.
- Level builder merges ground runs into static bodies, builds one-way
  platforms, ladders, entity placement, camera limits.
- Star screen: cleared / all collectibles / no deaths, stars pop one by one
  with `ui_star`.
- World 1 music + ambience, chest/secret/star sounds.

### Stage 4 — boss 1
- Boss framework: phases by HP threshold, armour outside vulnerability windows,
  weak point multiplier, stun window after an attack streak, phase summons,
  death and victory line.
- Bed Monster: claws, thrown toys, tantrum shockwave, three phases.
- Boss music, telegraph before every attack, phase change, stun, weak-point
  break, death and victory sounds; HUD boss bar with phase pips.
- Tests: `test_boss.gd`.

### Stage 5 — menus, saves, shelter
- Main menu, level select (worlds, stars, locked worlds stated honestly),
  pause, settings (three volume sliders, button size/opacity, vibration,
  language RU/EN, difficulty), shelter, equipment.
- Versioned save (`version: 2`), migration from v1, backup file, corrupt-file
  quarantine (`user://save.corrupt.json`).
- Tests: `test_save_manager.gd`.

### Stage 6 — weapons and skills
- Five weapons with their own swing sounds and styles (melee combo, boomerang,
  projectile, heavy, fast).
- Twelve skills with twelve distinct sounds, cooldowns, readiness cue, and a
  three-slot loadout saved in the profile.
- Tests: `test_data_content.gd` (unique sounds, cooldowns, data completeness).

### What to check on a phone (stages 1, 4, 6 together, since they shipped in one run)
The APK exists now (CI run #25 artifact). Install with
`adb install -r nightmare-hunter-debug.apk` on an arm64 Android 7.0+ device.
Listen for:
1. **Hero loop** — are footsteps too loud/too frequent at run speed? Four
   variants and ±10 % pitch are in place, but the interval (0.28 s) is a guess.
2. **Combat** — swing, hit, miss and crit should be clearly distinguishable;
   combo cue must not be annoying when mashing.
3. **Low health** — the two-note cue repeats only on crossing the threshold,
   not every frame. Confirm it warns without panicking.
4. **Boss** — telegraph sound must arrive before the claw, not with it. Phase
   change roar should feel like a beat change.
5. **Music balance** — eight world loops + menu + boss exist; check that music
   does not bury effects, especially in world 1 (music box arpeggio).
6. **Skills** — twelve different cues; check that "ready" pips are audible but
   not intrusive when three skills recharge at once.

### Moved to BACKLOG
Worlds 2–8, secret bosses, credits sequence, skill tree, gear, game modes
(boss rush, survival, daily), achievements screen, bestiary screen, hero skins,
tutorial in level 1, particles/screen-shake pass, 60 FPS profiling, APK size
budget tuning, tilemap-based level authoring, signed release run.


## Bugs found and fixed while getting CI green (2026-11-01)

CI was the first real execution of this code, so it turned up real defects, not
just test noise. Each is fixed and covered by the green run above:

1. `Theme` used as a constant name shadowed Godot's native `Theme` class → every
   UI script failed to parse and `level.gd` failed to compile.
2. `push_warning()` counts as an engine error for GUT, so defensive warnings
   (unknown sound id, corrupt save, unknown enemy type) failed tests; they now
   print an explicit `WARNING:` line instead.
3. Autoloads were touched before nodes entered the tree (`configure()` before
   `add_child`), producing "Can't use get_node() with absolute paths".
4. `godot -s` scripts compile before autoloads exist as globals, so the smoke
   and bot runners must resolve them via `root.get_node(...)`.
5. Elite `hp_mult` was defined in data but never applied.
6. Weapon damage multiplier defaulted to 0 → a hit could deal zero damage.
7. The ultimate skill's slow never expired (`slow_timer` was not set).
8. Collectible counting mixed currency and stars, so "collect everything" was
   free and the victory screen could show `x > y`.
9. Boss arenas had a goal door, letting the player "finish" the boss level
   without killing the boss.
10. **Pits were not lethal**: with no floor, the hero fell forever at terminal
    velocity. The level now detects the drop, kills and respawns at the last
    checkpoint — the single most serious gameplay bug found by CI.
11. Android export refused `gradle_build/min_sdk="24"` with a non-Gradle build;
    the override is gone and the 4.5 template supplies minSdk 24.
12. The scripted bot jumped on step-downs (landing inside the next pit), counted
    one death per frame, and stopped short of the boss's melee reach.

Remaining manual step: create and push the `stage-6-done` tag (the tooling here
can push branches, not tags); `ci.yml` then publishes the APK to that release.

## Stage A — control & HUD fix (2026-11-01, v0.7.0)

Priority above all other tasks per the operator's supplement. Scope: make the
game playable on a 2376x1080 (20:9) phone, then beauty passes (stages B–E).

**Fixed**
- UI moved into a `CanvasLayer` (was under the `Level` Node2D → world-space,
  clipped by the camera, touches never hit). Anchors now follow the viewport.
- Added the missing `[input]` Input Map (WASD/arrows/space/J/K/Q/E/R/Ctrl/Esc/P).
- Touch buttons dispatch real actions; stick stays analog; per-finger multitouch
  with release-reset.
- Safe-area insets (notch/gesture bar) with a 24 px floor; sizes scale off
  screen height; 64 px minimum button diameter.
- Vector icons (sword / jump / dash / pause / heart / crystal / skill spark)
  instead of D/J/A debug letters; health label "ЗД 100%" removed (icon + bar).
- Shard counter moved left of pause (no overlap).
- New tests: `tests/unit/test_touch_controls.gd` (press/release per button,
  analog stick, multitouch, layout bounds + no-overlap across 6 resolutions).
- CI screenshots job (xvfb + llvmpipe) + `tools/screenshot.gd` +
  `tools/check_shots.py` (blank-frame rejection).

**Local checks run:** `gdlint` (clean), `tools/check_refs.py` (243 refs OK).

**Please verify on the phone (separate APK built first):**
1. Every button responds to a tap (attack, jump, dash, 3 skills, pause) and the
   stick moves the hero.
2. All buttons are fully on screen — nothing clipped at the bottom/edges.
3. Multitouch: hold the stick + tap jump + tap attack at the same time.
4. Releasing a finger never leaves the hero running/jumping.
5. Health shows a heart icon + bar (no "ЗД"), shards show a crystal icon + number.

**Remaining (backlog, next stages):** B fonts/theme, C backgrounds/light, D art/
animation/game-feel, E menu polish — see BACKLOG.md and the supplement.
