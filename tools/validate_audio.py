#!/usr/bin/env python3
"""Structural audio check (runs in CI without Godot, and in the sound job).

Verifies:
  * every required event/music id from data/sound_events.json exists in data/sounds.json
  * every registry file exists on disk and is a readable, non-silent audio file
  * frequent events have >= min_variants_for_frequent files
  * pitch variance and pool size stay inside the documented limits
  * assets/audio stays below the size budget (`max_audio_dir_bytes`)
"""

from __future__ import annotations

import json
import os

import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVENTS = os.path.join(ROOT, "data", "sound_events.json")
REGISTRY = os.path.join(ROOT, "data", "sounds.json")
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")


def _res_to_path(res_path: str) -> str:
    if not res_path.startswith("res://"):
        raise ValueError(f"not a res:// path: {res_path}")
    return os.path.join(ROOT, res_path[len("res://"):])


def main() -> int:
    problems: list[str] = []
    with open(EVENTS, encoding="utf-8") as fh:
        events = json.load(fh)
    with open(REGISTRY, encoding="utf-8") as fh:
        registry = json.load(fh)

    reg_events = registry.get("events", {})
    reg_music = registry.get("music", {})

    for event_id in events["required_events"]:
        if event_id not in reg_events:
            problems.append(f"missing event in registry: {event_id}")

    for track_id in events["required_music"]:
        if track_id not in reg_music:
            problems.append(f"missing music in registry: {track_id}")

    for event_id, entry in reg_events.items():
        files = entry.get("files") or []
        if not files:
            problems.append(f"{event_id}: no files")
        for path_res in files:
            path = _res_to_path(path_res)
            if not os.path.exists(path):
                problems.append(f"{event_id}: missing file {path_res}")
                continue
            try:
                info = sf.info(path)
            except Exception as exc:  # noqa: BLE001
                problems.append(f"{event_id}: unreadable audio {path_res} ({exc})")
                continue
            if info.frames < int(0.02 * info.samplerate):
                problems.append(f"{event_id}: suspiciously short {path_res}")
            data, _ = sf.read(path, frames=min(4096, info.frames))
            peak = float(abs(data).max()) if len(data) else 0.0
            if peak < 1e-4:
                problems.append(f"{event_id}: silent file {path_res}")
        variance = float(entry.get("pitch_variance", 0.0))
        if variance > events["max_pitch_variance"]:
            problems.append(f"{event_id}: pitch variance {variance} too high")

    for event_id in events["frequent_events"]:
        min_variants = int(events["min_variants_for_frequent"])
        got = len(reg_events.get(event_id, {}).get("files", []))
        if got < min_variants:
            problems.append(f"{event_id}: needs >= {min_variants} variants, has {got}")

    for track_id, music in reg_music.items():
        path = _res_to_path(music["file"])
        if not os.path.exists(path):
            problems.append(f"{track_id}: missing file {music['file']}")
            continue
        info = sf.info(path)
        if info.frames < info.samplerate:  # at least 1 second
            problems.append(f"{track_id}: music too short ({info.frames} frames)")
        if music.get("loop") is not True:
            problems.append(f"{track_id}: music must be marked loop=true")

    if int(registry.get("max_concurrent", 99)) > 16:
        problems.append("max_concurrent above the documented pool limit of 16")

    total = 0
    for base, _dirs, files in os.walk(AUDIO_DIR):
        for name in files:
            total += os.path.getsize(os.path.join(base, name))
    budget = int(events["max_audio_dir_bytes"])
    if total > budget:
        problems.append(f"audio dir {total} bytes exceeds budget {budget}")

    print(f"events: {len(reg_events)}, music: {len(reg_music)}")
    print(f"audio size: {total / 1024 / 1024:.2f} MiB "
          f"(budget {budget / 1024 / 1024:.1f} MiB)")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(" -", problem)
        return 1
    print("audio check OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
