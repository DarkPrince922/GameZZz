"""Loopable procedural music for Nightmare Hunter (13 tracks).

Each track is a 4-bar loop built from a scale, a chord progression and simple
parts (pad, bass, arpeggio, percussion). Loops are made seamless by wrapping the
release tail of the last bar into the beginning of the buffer, so Godot's
`loop = true` playback has no click.
"""

from __future__ import annotations

import numpy as np

from audio_synth import (
    SR,
    bandpass,
    env_adsr,
    env_exp,
    lowpass,
    midi_to_freq,
    mix,
    noise,
    normalize,
    tone,
)

SCALES = {
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "whole": [0, 2, 4, 6, 8, 10],
    "phrygian_dominant": [0, 1, 4, 5, 7, 8, 10],
}

TRACKS = {
    "music_menu": {
        "tempo": 84, "root": 57, "scale": "minor", "progression": [0, 5, 3, 4],
        "pad_wave": "tri", "arp_wave": "sine", "bass_wave": "sine",
        "drums": False, "arp_gain": 0.45, "pad_gain": 0.5, "bass_gain": 0.4,
        "reverb": 0.3,
    },
    "music_shelter": {
        "tempo": 76, "root": 60, "scale": "major", "progression": [0, 3, 4, 5],
        "pad_wave": "sine", "arp_wave": "tri", "bass_wave": "sine",
        "drums": False, "arp_gain": 0.4, "pad_gain": 0.55, "bass_gain": 0.35,
        "reverb": 0.25, "warm": True,
    },
    "music_world_1": {
        "tempo": 92, "root": 62, "scale": "minor", "progression": [0, 5, 3, 4],
        "pad_wave": "sine", "arp_wave": "sine", "bass_wave": "tri",
        "drums": True, "arp_gain": 0.55, "pad_gain": 0.4, "bass_gain": 0.4,
        "music_box": True,
    },
    "music_world_2": {
        "tempo": 80, "root": 55, "scale": "phrygian", "progression": [0, 1, 0, 5],
        "pad_wave": "saw", "arp_wave": "tri", "bass_wave": "tri",
        "drums": True, "arp_gain": 0.35, "pad_gain": 0.45, "bass_gain": 0.5,
        "reverb": 0.3,
    },
    "music_world_3": {
        "tempo": 70, "root": 53, "scale": "minor", "progression": [0, 6, 5, 4],
        "pad_wave": "tri", "arp_wave": "sine", "bass_wave": "sine",
        "drums": False, "arp_gain": 0.3, "pad_gain": 0.55, "bass_gain": 0.4,
        "detune": 0.004, "reverb": 0.35,
    },
    "music_world_4": {
        "tempo": 100, "root": 58, "scale": "whole", "progression": [0, 2, 4, 1],
        "pad_wave": "sine", "arp_wave": "square", "bass_wave": "tri",
        "drums": True, "arp_gain": 0.3, "pad_gain": 0.4, "bass_gain": 0.45,
        "clock": True,
    },
    "music_world_5": {
        "tempo": 72, "root": 50, "scale": "minor", "progression": [0, 4, 5, 3],
        "pad_wave": "tri", "arp_wave": "sine", "bass_wave": "sine",
        "drums": False, "arp_gain": 0.5, "pad_gain": 0.45, "bass_gain": 0.4,
        "reverb": 0.4, "water": True,
    },
    "music_world_6": {
        "tempo": 88, "root": 63, "scale": "lydian", "progression": [0, 4, 2, 5],
        "pad_wave": "sine", "arp_wave": "tri", "bass_wave": "sine",
        "drums": False, "arp_gain": 0.5, "pad_gain": 0.4, "bass_gain": 0.3,
        "reverb": 0.45, "glass": True,
    },
    "music_world_7": {
        "tempo": 112, "root": 60, "scale": "dorian", "progression": [0, 3, 5, 2],
        "pad_wave": "square", "arp_wave": "square", "bass_wave": "tri",
        "drums": True, "arp_gain": 0.3, "pad_gain": 0.35, "bass_gain": 0.45,
        "clock": True,
    },
    "music_world_8": {
        "tempo": 66, "root": 45, "scale": "phrygian", "progression": [0, 1, 5, 4],
        "pad_wave": "saw", "arp_wave": "tri", "bass_wave": "saw",
        "drums": True, "arp_gain": 0.25, "pad_gain": 0.55, "bass_gain": 0.55,
        "reverb": 0.4, "drive": 1.4,
    },
    "music_boss": {
        "tempo": 132, "root": 52, "scale": "minor", "progression": [0, 0, 5, 4],
        "pad_wave": "saw", "arp_wave": "square", "bass_wave": "square",
        "drums": True, "arp_gain": 0.35, "pad_gain": 0.4, "bass_gain": 0.55,
        "drive": 1.5, "bass_8th": True,
    },
    "music_final_boss": {
        "tempo": 144, "root": 48, "scale": "phrygian_dominant",
        "progression": [0, 1, 5, 4],
        "pad_wave": "saw", "arp_wave": "saw", "bass_wave": "square",
        "drums": True, "arp_gain": 0.4, "pad_gain": 0.45, "bass_gain": 0.6,
        "drive": 1.8, "bass_8th": True,
    },
    "music_victory": {
        "tempo": 108, "root": 60, "scale": "major", "progression": [0, 4, 5, 3],
        "pad_wave": "tri", "arp_wave": "tri", "bass_wave": "sine",
        "drums": True, "arp_gain": 0.55, "pad_gain": 0.5, "bass_gain": 0.4,
        "reverb": 0.25,
    },
}

SUBS_PER_STEP = 8


def _steps(cfg) -> int:
    return 32  # 4 bars of 4/4, in 1/8 notes


def _step_duration(cfg) -> float:
    return 60.0 / cfg["tempo"] / 2.0


def _chord_tones(cfg, degree: int, octave: int = 0) -> list[int]:
    scale = SCALES[cfg["scale"]]
    root = cfg["root"] + octave * 12
    out = []
    for k in (0, 2, 4):
        idx = degree + k
        out.append(root + scale[idx % len(scale)] + 12 * (idx // len(scale)))
    return out


def _note(freq_midi, dur, wave, rng, pluck=16.0, attack=0.005, detune=0.0):
    s = tone(midi_to_freq(freq_midi), None, dur, wave, 1.0)
    if detune:
        s = s + tone(midi_to_freq(freq_midi) * (1.0 + detune), None, dur, wave, 1.0) * 0.6
    s = s * env_exp(len(s), pluck, attack=attack)
    return s


def _place(buf, src, start_s, gain=1.0):
    start = int(round(start_s * SR))
    if start >= len(buf):
        return buf
    end = min(len(buf), start + len(src))
    buf[start:end] += src[: end - start] * gain
    return buf


def make_track(track_id: str, rng: np.random.Generator) -> np.ndarray:
    if track_id not in TRACKS:
        raise ValueError(f"unknown track {track_id}")
    cfg = TRACKS[track_id]
    steps = _steps(cfg)
    spb = _step_duration(cfg)
    total = steps * spb
    buf = np.zeros(int(round(total * SR)) + int(0.6 * SR))  # extra room for tails

    detune = cfg.get("detune", 0.0)

    # ---- pad (one sustained chord per bar) --------------------------------
    for bar in range(steps // 8):
        degree = cfg["progression"][bar % len(cfg["progression"])]
        tones = _chord_tones(cfg, degree)
        start = bar * 8 * spb
        dur = 8 * spb
        seg = np.zeros(int(dur * SR) + 1)
        env = env_adsr(len(seg), min(0.5, dur * 0.2), 0.2, 0.55, min(0.7, dur * 0.3))
        for tone_i, note in enumerate(tones):
            part = tone(midi_to_freq(note), None, dur, cfg["pad_wave"], 1.0)
            if detune:
                part = part + tone(midi_to_freq(note) * (1.0 + detune), None, dur,
                                   cfg["pad_wave"], 1.0) * 0.5
            n = min(len(part), len(env), len(seg))
            seg[:n] += part[:n] * env[:n] * (0.15 if tone_i else 0.2)
        buf = _place(buf, lowpass(seg, 2400.0), start, cfg.get("pad_gain", 0.4))

    # ---- bass ------------------------------------------------------------
    bass_wave = cfg["bass_wave"]
    for step in range(steps):
        beat = step % 8
        degree = cfg["progression"][(step // 8) % len(cfg["progression"])]
        play = beat in (0, 2, 4, 6) if not cfg.get("bass_8th") else True
        if not play:
            continue
        note = cfg["root"] - 12 + SCALES[cfg["scale"]][degree % len(SCALES[cfg["scale"]])]
        dur = spb * (1.6 if not cfg.get("bass_8th") else 0.85)
        s = _note(note, dur, bass_wave, rng, pluck=6.0 if cfg.get("bass_8th") else 4.0,
                  attack=0.008, detune=detune)
        buf = _place(buf, lowpass(s, 900.0), step * spb, cfg.get("bass_gain", 0.4) * 0.5)

    # ---- arpeggio / melody ----------------------------------------------
    pattern = [0, 1, 2, 1, 2, 0, 1, 2]
    for step in range(steps):
        degree = cfg["progression"][(step // 8) % len(cfg["progression"])]
        tones = _chord_tones(cfg, degree, octave=1)
        note = tones[pattern[step % len(pattern)] % len(tones)]
        if cfg.get("music_box"):
            note += 12
        if cfg.get("glass"):
            note += 12
        dur = spb * 0.9
        wave = cfg["arp_wave"]
        s = _note(note, dur, wave, rng, pluck=14.0, attack=0.003, detune=detune)
        gain = cfg.get("arp_gain", 0.4) * (0.75 if step % 2 else 1.0)
        buf = _place(buf, s, step * spb, gain * 0.5)

    # ---- percussion -------------------------------------------------------
    if cfg.get("drums"):
        for step in range(steps):
            at = step * spb
            if step % 4 == 0:  # kick
                k = tone(90.0, 42.0, 0.16, "sine", 0.4)
                k *= env_exp(len(k), 18.0, attack=0.001)
                buf = _place(buf, k, at, 0.55)
            if step % 8 == 4:  # snare
                sn = bandpass(noise(0.12, rng), 900.0, 6000.0)
                sn *= env_exp(len(sn), 26.0)
                buf = _place(buf, sn, at, 0.3)
            if step % 2 == 1:  # hat
                hat = bandpass(noise(0.05, rng), 5000.0, 10000.0)
                hat *= env_exp(len(hat), 70.0)
                buf = _place(buf, hat, at, 0.12)

    # ---- flavour ----------------------------------------------------------
    if cfg.get("clock"):
        for step in range(steps):
            tick = bandpass(noise(0.03, rng), 3000.0, 9000.0)
            tick *= env_exp(len(tick), 90.0)
            buf = _place(buf, tick, step * spb, 0.09)
    if cfg.get("water"):
        for i in range(6):
            at = (i * 4 + 1.5) * spb
            drop = tone(700.0 + 60.0 * i, 240.0, 0.22, "sine", 0.7)
            drop *= env_exp(len(drop), 12.0)
            buf = _place(buf, drop, at, 0.12)

    # ---- seamless loop: wrap the tail into the head -----------------------
    loop_len = int(round(steps * spb * SR))
    sound = buf[:loop_len]
    tail = buf[loop_len:]
    if len(tail):
        sound[: len(tail)] += tail

    if cfg.get("reverb"):
        sound = sound + _cheap_reverb(sound, cfg["reverb"])
    if cfg.get("drive"):
        sound = np.tanh(sound * cfg["drive"]) / np.tanh(cfg["drive"])
    sound = normalize(sound, 0.7)
    return sound


def _cheap_reverb(x: np.ndarray, amount: float) -> np.ndarray:
    out = np.zeros_like(x)
    for i, tap in enumerate((0.05, 0.11, 0.17, 0.23)):
        d = int(tap * SR)
        if d < len(x):
            wrapped = np.concatenate([x[-d:], x[:-d]])
            out += wrapped * amount * (0.5 ** i)
    return out
