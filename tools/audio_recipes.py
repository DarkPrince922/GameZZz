"""Per-event recipes for Nightmare Hunter audio.

Each entry describes how to synthesise one game event. The registry
data/sounds.json is generated from this table, so a new sound can never be
added to the game without a file behind it (and the audio tests verify the
reverse direction as well).
"""

from __future__ import annotations

import numpy as np

from audio_synth import (
    SR,
    bandpass,
    env_adsr,
    env_exp,
    fade,
    lowpass,
    midi_to_freq,
    mix,
    noise,
    normalize,
    pad_to,
    place,
    soft_clip,
    tone,
)


def _n(duration: float) -> int:
    return max(1, int(round(duration * SR)))


def env_env(dur: float, spec):
    n = _n(dur)
    return env_adsr(n, spec.get("attack", 0.01), spec.get("d_attack", 0.08),
                    spec.get("sustain", 0.45), spec.get("release", 0.25))


def _thump(spec, rng):
    dur = spec.get("dur", 0.12)
    body = tone(spec.get("f0", 160), spec.get("f1", 70), dur, "sine", 0.7)
    body *= env_exp(len(body), spec.get("decay", 26.0), attack=0.002)
    nz = bandpass(noise(dur, rng), spec.get("low", 240), spec.get("cut", 3200))
    nz *= env_exp(len(nz), spec.get("noise_decay", 60.0), attack=0.0005)
    return mix(body, nz * spec.get("noise", 0.35))


def _blip(spec, rng):
    dur = spec.get("dur", 0.14)
    sig = tone(spec.get("f0", 600), spec.get("f1", spec.get("f0", 600)), dur,
               spec.get("wave", "square"), spec.get("curve", 1.0))
    sig *= env_exp(len(sig), spec.get("decay", 14.0), attack=spec.get("attack", 0.003))
    sig = lowpass(sig, spec.get("cut", 5200))
    if spec.get("noise", 0.0):
        nz = noise(dur, rng) * env_exp(_n(dur), spec.get("noise_decay", 40.0))
        sig = mix(sig, nz * spec["noise"])
    return sig


def _chirp(spec, rng):
    dur = spec.get("dur", 0.22)
    s = tone(spec.get("f0", 300), spec.get("f1", 900), dur,
             spec.get("wave", "tri"), spec.get("curve", 0.8))
    if spec.get("vibrato", 0.0):
        vib = 1.0 + spec["vibrato"] * np.sin(
            2 * np.pi * spec.get("vib_rate", 22.0) * np.arange(len(s)) / SR)
        s = s * vib
    s *= env_exp(len(s), spec.get("decay", 11.0), attack=spec.get("attack", 0.006))
    return s


def _noiseburst(spec, rng):
    dur = spec.get("dur", 0.3)
    nz = bandpass(noise(dur, rng), spec.get("low", 400), spec.get("cut", 6000))
    nz *= env_exp(len(nz), spec.get("decay", 12.0), attack=spec.get("attack", 0.001))
    if spec.get("body_f0"):
        body = tone(spec["body_f0"], spec.get("body_f1", spec["body_f0"]), dur,
                    spec.get("wave", "sine"), 1.0)
        body *= env_exp(len(body), spec.get("decay", 12.0) * 0.7)
        nz = mix(nz, body * spec.get("body", 0.5))
    return nz


def _chord(spec, rng):
    dur = spec.get("dur", 0.7)
    notes = spec.get("notes", [60, 64, 67])
    out = np.zeros(_n(dur))
    env = env_env(dur, spec)
    for i, note in enumerate(notes):
        s = tone(midi_to_freq(note), None, dur, spec.get("wave", "tri"), 1.0)
        s = s[: len(env)] * env
        out = mix(out, s * (spec.get("spread", 1.0) ** i))
    if spec.get("shimmer"):
        sh = tone(midi_to_freq(notes[-1] + 12), None, dur, "sine", 1.0)
        sh *= env_exp(len(sh), spec.get("shimmer_decay", 9.0))
        out = mix(out, sh * spec["shimmer"])
    return out


def _pattern(spec, rng):
    notes = spec.get("notes", [72])
    step = spec.get("step", 0.08)
    dur = step * len(notes) + spec.get("tail", 0.12)
    out = np.zeros(_n(dur))
    for i, note in enumerate(notes):
        if note is None:
            continue
        length = step * spec.get("note_len", 0.9)
        s = tone(midi_to_freq(note), None, length, spec.get("wave", "square"), 1.0)
        s *= env_exp(len(s), spec.get("decay", 18.0), attack=0.003)
        out = place(out, s, i * step, spec.get("gain", 0.8)
                    * (spec.get("decay_per_step", 1.0) ** i))
    return out


def _hum(spec, rng):
    dur = spec.get("dur", 2.4)
    base = spec.get("f0", 110.0)
    s = tone(base, base * spec.get("drift", 1.002), dur, spec.get("wave", "sine"), 1.0)
    s = mix(s, tone(base * spec.get("harmonic", 2.0), None, dur, "tri", 1.0) * 0.35)
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * spec.get("lfo", 0.3) * np.arange(len(s)) / SR)
    s = s * mod
    s *= env_adsr(len(s), 0.4, 0.2, 0.7, 0.4)
    if spec.get("air", 0.0):
        air = bandpass(noise(dur, rng), 1200, 6000) * 0.25 * mod
        s = mix(s, air * spec["air"])
    return s


def _zap(spec, rng):
    dur = spec.get("dur", 0.18)
    s = tone(spec.get("f0", 2400), spec.get("f1", 180), dur, spec.get("wave", "saw"),
             spec.get("curve", 0.5))
    s *= env_exp(len(s), spec.get("decay", 22.0), attack=0.001)
    if spec.get("crackle", 0.4):
        s = mix(s, noise(dur, rng) * env_exp(_n(dur), 30.0) * spec["crackle"])
    return lowpass(s, spec.get("cut", 7000))


def _rattle(spec, rng):
    dur = spec.get("dur", 0.45)
    out = np.zeros(_n(dur))
    for i in range(spec.get("hits", 4)):
        at = spec.get("start", 0.02) + i * spec.get("spacing", 0.09)
        if at >= dur:
            break
        s = bandpass(noise(0.06, rng), spec.get("low", 500), spec.get("cut", 5000))
        s *= env_exp(len(s), 55.0)
        out = place(out, s, at, 0.7 * (0.9 ** i))
    return out


def _sweep(spec, rng):
    dur = spec.get("dur", 0.5)
    s = tone(spec.get("f0", 200), spec.get("f1", 1800), dur,
             spec.get("wave", "tri"), spec.get("curve", 0.5))
    s *= env_adsr(len(s), spec.get("attack", 0.05), 0.1, spec.get("sustain", 0.6), 0.2)
    nz = bandpass(noise(dur, rng), 300, 3000) * 0.12
    nz *= env_adsr(len(nz), 0.05, 0.1, 0.5, 0.2)
    return mix(s, nz)


ARCHES = {
    "thump": _thump,
    "blip": _blip,
    "chirp": _chirp,
    "noiseburst": _noiseburst,
    "chord": _chord,
    "pattern": _pattern,
    "hum": _hum,
    "zap": _zap,
    "rattle": _rattle,
    "sweep": _sweep,
}


def _reverb_tail(x: np.ndarray, amount: float) -> np.ndarray:
    tail = np.zeros_like(x)
    for i, tap in enumerate((0.045, 0.091, 0.145)):
        delay = int(tap * SR)
        if delay < len(x):
            tail[delay:] += x[:-delay] * amount * (0.55 ** i)
    return tail


def render(spec: dict, rng: np.random.Generator) -> np.ndarray:
    """Render one sound. `layers` may hold extra specs mixed on top."""
    arch = spec.get("arch", "blip")
    if arch not in ARCHES:
        raise ValueError(f"unknown arch {arch}")
    out = ARCHES[arch](spec, rng)
    for layer in spec.get("layers", []):
        sub = ARCHES[layer.get("arch", "blip")](layer, rng)
        sub = pad_to(sub, len(out) / SR) if len(sub) < len(out) else sub[: len(out)]
        out = mix(out, sub)
    if spec.get("dur"):
        out = pad_to(out, spec["dur"])
    out = normalize(out, spec.get("peak", 0.8))
    out = soft_clip(out, spec.get("drive", 1.1))
    if spec.get("reverb"):
        out = normalize(out + _reverb_tail(out, spec["reverb"]), spec.get("peak", 0.8))
    return fade(out, spec.get("fade_ms", 3.0))
