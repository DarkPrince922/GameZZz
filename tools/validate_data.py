#!/usr/bin/env python3
"""Content validator: the same rules as tests/unit/test_data_content.gd, but
runnable without Godot, so CI can fail fast on broken data.

Checks levels (geometry, entities, jump feasibility), enemies, weapons, skills,
upgrades, bosses, worlds, i18n parity and audio registry references.
"""

from __future__ import annotations

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
LEVELS = os.path.join(DATA, "levels")

MAX_GAP_TILES = 4
MAX_CLIMB_TILES = 2

problems: list[str] = []


def load(path: str, label: str):
    if not os.path.exists(path):
        problems.append(f"{label}: file missing ({os.path.relpath(path, ROOT)})")
        return {}
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except json.JSONDecodeError as exc:
        problems.append(f"{label}: invalid JSON ({exc})")
        return {}


def width_of(level: dict) -> int:
    return sum(int(run[1]) for run in level.get("ground_runs", []))


def heights_of(level: dict) -> list[int]:
    out: list[int] = []
    for ground, count in level.get("ground_runs", []):
        out.extend([int(ground)] * int(count))
    return out


def check_levels(db: dict) -> None:
    keys = ("name_key", "spawn", "goal", "ground_runs", "music", "ambient")
    ids = sorted(f[:-5] for f in os.listdir(LEVELS) if f.endswith(".json"))
    if not ids:
        problems.append("levels: none found")
    world1 = db["worlds"]["worlds"].get("1", {})
    if len(world1.get("levels", [])) != 4:
        problems.append("world 1 must list exactly 4 levels")

    for level_id in ids:
        level = load(os.path.join(LEVELS, level_id + ".json"), f"level {level_id}")
        if not level:
            continue
        is_boss = bool(level.get("boss", ""))
        for key in keys:
            if key == "goal" and is_boss:
                continue
            if key not in level:
                problems.append(f"{level_id}: missing key {key}")
        width = width_of(level)
        height = int(level.get("height", 14))
        if width < 20:
            problems.append(f"{level_id}: suspiciously narrow ({width} columns)")
        for field in ("spawn", "goal"):
            if field == "goal" and is_boss:
                continue
            value = level.get(field)
            if not (isinstance(value, list) and len(value) == 2):
                problems.append(f"{level_id}: {field} must be [x, y]")
                continue
            x, y = int(value[0]), int(value[1])
            if not (0 <= x < width):
                problems.append(f"{level_id}: {field} x={x} outside 0..{width - 1}")
            if not (0 <= y < height):
                problems.append(f"{level_id}: {field} y={y} outside 0..{height - 1}")
        for checkpoint in level.get("checkpoints", []):
            if not (0 <= int(checkpoint[0]) < width):
                problems.append(f"{level_id}: checkpoint outside the map")
        for enemy in level.get("enemies", []):
            if enemy.get("type") not in db["enemies"]["enemies"]:
                problems.append(f"{level_id}: unknown enemy {enemy.get('type')}")
            elite = enemy.get("elite", "")
            if elite and elite not in db["enemies"]["elites"]:
                problems.append(f"{level_id}: unknown elite {elite}")
            if not (0 <= int(enemy.get("x", -1)) < width):
                problems.append(f"{level_id}: enemy x outside the map")
        for trap in level.get("traps", []):
            if trap.get("type") not in ("falling_platform", "laser", "moving_wall", "spikes"):
                problems.append(f"{level_id}: unknown trap {trap.get('type')}")
        music = level.get("music", "")
        if music not in db["sounds"]["music"]:
            problems.append(f"{level_id}: music {music} not in registry")
        ambience = level.get("ambient", "")
        if ambience and ambience not in db["sounds"]["events"]:
            problems.append(f"{level_id}: ambience {ambience} not in registry")
        boss_id = level.get("boss", "")
        if boss_id and boss_id not in db["bosses"]["bosses"]:
            problems.append(f"{level_id}: unknown boss {boss_id}")

        def _platform_row(x_col: int):
            for platform in level.get("platforms", []):
                if platform.get("x", 0) <= x_col < platform.get("x", 0) + platform.get("w", 3):
                    return int(platform.get("y", 0))
            return None

        def _stands(pt) -> bool:
            x_col, y_row = int(pt[0]), int(pt[1])
            if not (0 <= x_col < width):
                return False
            if heights_of(level)[x_col] == y_row:
                return True
            row = _platform_row(x_col)
            return row is not None and abs(row - y_row) <= 1

        for field in ("spawn", "goal"):
            if field == "goal" and is_boss:
                continue
            if level.get(field) and not _stands(level[field]):
                problems.append(f"{level_id}: {field} {level[field]} is not on solid ground")
        for checkpoint in level.get("checkpoints", []):
            if not _stands(checkpoint):
                problems.append(f"{level_id}: checkpoint {checkpoint} is not on solid ground")
        for enemy in level.get("enemies", []):
            if enemy.get("type") == "flyer":
                continue
            if not _stands([enemy.get("x", -1), enemy.get("y", -1)]):
                problems.append(
                    f"{level_id}: enemy {enemy.get('type')} at "
                    f"{enemy.get('x')},{enemy.get('y')} is not on solid ground")
        for shard in level.get("shards", []):
            if not _stands(shard):
                problems.append(f"{level_id}: shard {shard} is unreachable")
        for chest in level.get("chests", []):
            if not _stands(chest):
                problems.append(f"{level_id}: chest {chest} is unreachable")

        previous = 0
        gap = 0
        for ground in heights_of(level):
            if ground == 0:
                gap += 1
                continue
            if gap > MAX_GAP_TILES:
                problems.append(f"{level_id}: {gap}-tile gap cannot be jumped")
            gap = 0
            if previous and ground < previous and previous - ground > MAX_CLIMB_TILES:
                problems.append(
                    f"{level_id}: {previous - ground}-tile climb is too high")
            previous = ground

    boss_level = world1.get("boss_level", "")
    if boss_level:
        boss_data = load(os.path.join(LEVELS, boss_level + ".json"), "boss level")
        if boss_data.get("boss") not in db["bosses"]["bosses"]:
            problems.append("boss level does not point at a known boss")


def check_entities(db: dict) -> None:
    enemies = db["enemies"]["enemies"]
    if len(enemies) != 6:
        problems.append(f"enemies: expected 6, found {len(enemies)}")
    if len(db["enemies"]["elites"]) != 3:
        problems.append("elites: expected 3 modifiers")
    for enemy_id, enemy in enemies.items():
        for key in ("hp", "damage", "speed", "behavior", "size", "shards"):
            if key not in enemy:
                problems.append(f"enemy {enemy_id}: missing {key}")
        if enemy.get("behavior") not in (
            "patrol_chase", "flyer", "jumper", "shooter", "bomber", "shieldbearer"):
            problems.append(f"enemy {enemy_id}: unknown behaviour {enemy.get('behavior')}")

    weapons = db["weapons"]["weapons"]
    if len(weapons) != 5:
        problems.append(f"weapons: expected 5, found {len(weapons)}")
    for weapon_id, weapon in weapons.items():
        for key in ("damage", "swing_sfx", "hit_sfx", "style"):
            if key not in weapon:
                problems.append(f"weapon {weapon_id}: missing {key}")
        if weapon.get("swing_sfx") not in db["sounds"]["events"]:
            problems.append(f"weapon {weapon_id}: swing_sfx not in registry")
        if weapon.get("hit_sfx") not in db["sounds"]["events"]:
            problems.append(f"weapon {weapon_id}: hit_sfx not in registry")

    skills = db["skills"]["skills"]
    if len(skills) != 12:
        problems.append(f"skills: expected 12, found {len(skills)}")
    used_sfx: dict[str, str] = {}
    for skill_id, skill in skills.items():
        if "sfx" not in skill:
            problems.append(f"skill {skill_id}: missing sfx")
            continue
        if skill["sfx"] not in db["sounds"]["events"]:
            problems.append(f"skill {skill_id}: sfx not in registry")
        if skill["sfx"] in used_sfx:
            problems.append(
                f"skill {skill_id}: same sound as {used_sfx[skill['sfx']]}")
        used_sfx[skill["sfx"]] = skill_id
        if float(skill.get("cooldown", 0)) <= 0:
            problems.append(f"skill {skill_id}: cooldown must be positive")

    for upgrade_id, upgrade in db["upgrades"]["upgrades"].items():
        if int(upgrade.get("price_base", 0)) <= 0:
            problems.append(f"upgrade {upgrade_id}: price must be positive")
        if int(upgrade.get("max_level", 0)) <= 0:
            problems.append(f"upgrade {upgrade_id}: max_level must be positive")

    for boss_id, boss in db["bosses"]["bosses"].items():
        phases = boss.get("phases", [])
        if not phases:
            problems.append(f"boss {boss_id}: no phases")
        attacks = boss.get("attacks", {})
        for phase in phases:
            for attack in phase.get("attacks", []):
                if attack not in attacks:
                    problems.append(f"boss {boss_id}: phase attack {attack} has no data")
        for attack_name, attack in attacks.items():
            for key in ("damage", "telegraph", "telegraph_sfx", "sfx"):
                if key not in attack:
                    problems.append(f"boss {boss_id}/{attack_name}: missing {key}")
            if attack.get("sfx") not in db["sounds"]["events"]:
                problems.append(f"boss {boss_id}/{attack_name}: sfx not in registry")
            if attack.get("telegraph_sfx") not in db["sounds"]["events"]:
                problems.append(f"boss {boss_id}/{attack_name}: telegraph_sfx missing")
        if not phases[-1].get("hp_to") == 0.0:
            problems.append(f"boss {boss_id}: last phase must end at hp_to = 0")


def check_i18n(db: dict) -> None:
    en = load(os.path.join(DATA, "i18n", "en.json"), "i18n en")
    ru = load(os.path.join(DATA, "i18n", "ru.json"), "i18n ru")
    missing_ru = [k for k in en if k not in ru]
    missing_en = [k for k in ru if k not in en]
    if missing_ru:
        problems.append(f"i18n: keys missing in ru.json: {missing_ru}")
    if missing_en:
        problems.append(f"i18n: keys missing in en.json: {missing_en}")

    needed: list[str] = []
    for section, key_names in (
        ("weapons", ("name_key", "desc_key")),
        ("skills", ("name_key", "desc_key")),
        ("upgrades", ("name_key", "desc_key")),
    ):
        for entry_id, entry in db[section][section].items():
            needed.extend(str(entry.get(k, "")) for k in key_names)
    for enemy in db["enemies"]["enemies"].values():
        needed.append(str(enemy.get("name_key", "")))
    for elite in db["enemies"]["elites"].values():
        needed.append(str(elite.get("name_key", "")))
    for world in db["worlds"]["worlds"].values():
        needed.append(str(world.get("name_key", "")))
        needed.append(str(world.get("subtitle_key", "")))
    for boss in db["bosses"]["bosses"].values():
        needed.append(str(boss.get("name_key", "")))
        needed.append(str(boss.get("title_key", "")))
    for level_file in sorted(os.listdir(LEVELS)):
        if level_file.endswith(".json"):
            level = load(os.path.join(LEVELS, level_file), f"level {level_file}")
            needed.append(str(level.get("name_key", "")))

    for key in sorted(set(needed)):
        if not key:
            continue
        if key not in en or key not in ru:
            problems.append(f"i18n: {key} is referenced but not translated")


def check_audio_links(db: dict) -> None:
    events = db["sounds"]["events"]
    music = db["sounds"]["music"]
    required = db["sound_events"]
    for event_id in required["required_events"]:
        if event_id not in events:
            problems.append(f"audio: required event {event_id} missing")
    for track_id in required["required_music"]:
        if track_id not in music:
            problems.append(f"audio: required music {track_id} missing")
    for world in db["worlds"]["worlds"].values():
        if world.get("music") not in music:
            problems.append(f"audio: world music {world.get('music')} missing")
        if world.get("ambient") not in events:
            problems.append(f"audio: world ambience {world.get('ambient')} missing")


def main() -> int:
    db = {
        "enemies": load(os.path.join(DATA, "enemies.json"), "enemies"),
        "weapons": load(os.path.join(DATA, "weapons.json"), "weapons"),
        "skills": load(os.path.join(DATA, "skills.json"), "skills"),
        "upgrades": load(os.path.join(DATA, "upgrades.json"), "upgrades"),
        "bosses": load(os.path.join(DATA, "bosses.json"), "bosses"),
        "worlds": load(os.path.join(DATA, "worlds.json"), "worlds"),
        "sounds": load(os.path.join(DATA, "sounds.json"), "sounds"),
        "sound_events": load(os.path.join(DATA, "sound_events.json"), "sound events"),
    }
    if any(not value for value in db.values()):
        for problem in problems:
            print(" -", problem)
        return 1

    check_levels(db)
    check_entities(db)
    check_i18n(db)
    check_audio_links(db)

    print(f"data check: {len(db['enemies']['enemies'])} enemies, "
          f"{len(db['weapons']['weapons'])} weapons, {len(db['skills']['skills'])} skills, "
          f"{len(os.listdir(LEVELS))} level files, "
          f"{len(db['sounds']['events'])} sound events, {len(db['sounds']['music'])} tracks")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(" -", problem)
        return 1
    print("data check OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
