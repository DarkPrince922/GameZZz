#!/usr/bin/env python3
"""Static reference check (runs without Godot).

Godot resolves res:// paths at load time, so a single typo produces a runtime
error on a device. This script verifies that every path referenced from code,
scenes, the project file and data exists on disk.
"""

from __future__ import annotations

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES_RE = re.compile(r'res://[A-Za-z0-9_./\-]+')

problems: list[str] = []
checked = 0


def to_path(res_path: str) -> str:
    clean = res_path.rstrip('",;)]}')
    return os.path.join(ROOT, clean[len("res://"):])


def check_path(res_path: str, origin: str) -> None:
    global checked
    checked += 1
    path = to_path(res_path)
    if not os.path.exists(path):
        problems.append(f"{origin}: missing {res_path}")


def walk(extensions: tuple[str, ...]):
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in
                   {".git", ".godot", "addons", ".venv", "__pycache__", "build"}]
        for name in files:
            if name.endswith(extensions):
                yield os.path.join(base, name)


def check_references() -> None:
    for path in walk((".gd", ".tscn", ".tres", ".cfg", ".godot", ".json")):
        rel = os.path.relpath(path, ROOT)
        if rel.startswith("assets/audio/"):
            continue  # binary names are covered by validate_audio
        try:
            text = open(path, encoding="utf-8").read()
        except UnicodeDecodeError:
            continue
        for res_path in RES_RE.findall(text):
            if res_path.startswith("res://.godot") or res_path.startswith("res://build"):
                continue
            check_path(res_path, rel)


def check_autoloads() -> None:
    text = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
    section = text.split("[autoload]", 1)[1].split("[", 1)[0]
    for line in section.strip().splitlines():
        if "=" not in line:
            continue
        name, value = line.split("=", 1)
        value = value.strip().strip('"')
        if value.startswith("*"):
            value = value[1:]
        check_path(value, f"project.godot autoload {name}")


def check_scene_scripts() -> None:
    for path in walk((".tscn",)):
        rel = os.path.relpath(path, ROOT)
        text = open(path, encoding="utf-8").read()
        for match in re.finditer(r'\[ext_resource[^\]]*path="([^"]+)"', text):
            check_path(match.group(1), rel)
        if "type=\"Control\"" in text and "anchors_preset" not in text:
            problems.append(f"{rel}: Control root without anchors preset")


def check_level_links() -> None:
    worlds = json.load(open(os.path.join(ROOT, "data/worlds.json"), encoding="utf-8"))["worlds"]
    for number, world in worlds.items():
        for level_id in world.get("levels", []):
            path = os.path.join(ROOT, "data/levels", level_id + ".json")
            if not os.path.exists(path):
                problems.append(f"world {number}: listed level {level_id} has no file")
        boss_level = world.get("boss_level", "")
        if boss_level and not os.path.exists(
                os.path.join(ROOT, "data/levels", boss_level + ".json")):
            problems.append(f"world {number}: boss level {boss_level} has no file")


def check_workflows() -> None:
    for name in ("ci.yml", "release.yml"):
        path = os.path.join(ROOT, ".github/workflows", name)
        if not os.path.exists(path):
            problems.append(f"missing workflow {name}")
            continue
        text = open(path, encoding="utf-8").read()
        if "barichello/godot-ci:4.5" not in text:
            problems.append(f"{name}: image is not pinned to godot-ci:4.5")
        for script in ("tools/fetch_gut.sh", "tools/import_project.sh"):
            check_path("res://" + script, name)


def main() -> int:
    check_references()
    check_autoloads()
    check_scene_scripts()
    check_level_links()
    check_workflows()
    print(f"checked {checked} res:// references")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(" -", problem)
        return 1
    print("reference check OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
