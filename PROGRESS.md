# PROGRESS

## 2026-10-31 — stages 0–6 (vertical slice), stages 7–10 not started

**Local verification actually run:** `gdlint scripts tests tools` → "Success:
no problems found"; `tools/validate_data.py` → OK (levels, entities, i18n,
jump feasibility, entity-on-ground rule); `tools/validate_audio.py` → OK
(82 events, 13 loops, 4.81 MiB, no silent files); `tools/check_refs.py` → OK
(243 `res://` references resolve); music seam check ≤0.015 amplitude; an
independent static review pass fixed 7 compile-level bugs (see `NOTES.md`).

**CI link:** none — no GitHub remote or token was available in this environment,
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
Not yet possible: there is no APK, because CI never ran. When the first build
appears, listen for:
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
