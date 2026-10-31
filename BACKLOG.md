# BACKLOG

Ordered by what hurts the game most. Everything here is deliberately out of the
current build; nothing here is pretending to work.

## Worlds 2–8 and their bosses (stages 7–8)
- Dark Forest (Forest Raven: dive + summon flock), Abandoned House (Ghost
  Nanny: teleports, trap doors), Endless Corridor (Door Warden: gravity flips),
  Sunken City (Deep Leviathan + rising water), Mirror Hall (hero double copying
  skills), Clock Tower (Time Lord: combat rewind), Throne of Nightmares
  (Night King, 3 phases) + 2 secret bosses, credits sequence.
- Data hooks already exist: `data/worlds.json` lists all eight worlds with
  music/ambience ids and `implemented: false`; the level builder, boss framework
  and skill system are reused as-is. Missing: level JSON, boss data + subclass,
  new enemies per world, world-specific mechanics (water level, rewind, gravity
  flip, mirror copying).

## Stage 9 — meta progression
- Skill tree (defence / attack / mobility), gear (hats, capes, amulets),
  boss rush, survival waves, daily challenge seeded from the date (offline),
  achievements screen, bestiary screen, hero skins.
- Save format already versioned and has `achievements`, `bestiary`,
  `upgrade_levels` fields ready for migration step 3.

## Stage 10 — polish and release
- Full audio pass on device (balance, ducking under boss voices, no clicks at
  loop points), particles, screen shake everywhere, haptics tuning.
- 60 FPS profiling on a mid-range phone, APK size budget check, tutorial in
  level 1, app icon variants, splash art, signed release rehearsal.

## Spec items not implemented yet (explicit gaps)

1. **World 1 mini-boss** (stage 3 asks for one besides the main boss). The boss
   framework is ready, but no second shorter fight was authored; level 4 ends
   with a regular elite instead.
2. **Tutorial in level 1** (stage 10), hint strings already exist in i18n
   (`tutorial_*`) but nothing shows them in-game yet.
3. **Credits sequence, secret bosses, final boss, worlds 2–8** (stage 8).
4. **Achievements/bestiary screens** — data and sounds exist (`ui_achievement`,
   `SaveManager.unlock_achievement`, `register_bestiary`), the UI does not.
5. **Game modes** (boss rush, survival, daily seed) and the skill tree/gear.
6. **Stage/release tags** — no tags were created locally because tagging
   `stage-N-done` implies a green CI run, and CI has never run (BLOCKERS.md).

## Known shortcuts to revisit
1. **Levels are not TileMapLayer yet.** Geometry is built from JSON
   `ground_runs` into merged `StaticBody2D` rectangles with `ColorRect`
   visuals. It is fast, data-driven and testable, but a real tileset would allow
   art. Migration path: keep the JSON as the source of truth and swap
   `_add_solid()` for `TileMapLayer.set_cell()` calls.
2. **Visuals are primitives** (`_draw()` rectangles/circles). No sprite atlases
   yet; art is listed as future work in `CREDITS.md`.
3. **Boss attack patterns** are simple timed patterns without animation frames.
4. **`--headless --import`** is used with an `--editor --quit` fallback because
   the flag could not be confirmed against the (unreachable) 4.5 docs.
5. **Gradle build is off**, so `minSdk 24` comes from the Godot 4.5 template
   (verified in `config.gradle`). If a future export needs custom ABI/SDK
   handling, switch `gradle_build/use_gradle_build` to `true` and install the
   Android build template in CI.
6. **Menu music does not duck** when a boss telegraph plays; ducking is on the
   stage-10 list.
7. **Difficulty** changes damage/hp/shard multipliers only; no separate enemy
   attack sets.
