"""Tiny deterministic synthesis engine for Nightmare Hunter.

Everything here is generated from code, so every audio asset in this project is
original work released as CC0 by the project author (see CREDITS.md).

No external samples are used: no licence risk, no download step, fully
reproducible from `python3 tools/gen_audio.py`.
"""

from __future__ import annotations

import math

import numpy as np

SR = 22050


# --------------------------------------------------------------------------- #
# building blocks
# --------------------------------------------------------------------------- #
def t_axis(duration: float, sr: int = SR) -> np.ndarray:
    n = max(1, int(round(duration * sr)))
    return np.arange(n, dtype=np.float64) / sr


def midi_to_freq(note: float) -> float:
    return 440.0 * math.pow(2.0, (note - 69.0) / 12.0)


def _osc(wave: str, phase: np.ndarray) -> np.ndarray:
    """phase in cycles (not radians)."""
    frac = np.mod(phase, 1.0)
    if wave == "sine":
        return np.sin(2.0 * np.pi * frac)
    if wave == "square":
        return np.where(frac < 0.5, 1.0, -1.0)
    if wave == "saw":
        return 2.0 * frac - 1.0
    if wave == "tri":
        return 4.0 * np.abs(frac - 0.5) - 1.0
    if wave == "pulse":
        return np.where(frac < 0.25, 1.0, -1.0)
    raise ValueError(f"unknown wave {wave}")


def tone(
    freq0: float,
    freq1: float | None,
    duration: float,
    wave: str = "sine",
    curve: float = 1.0,
    sr: int = SR,
) -> np.ndarray:
    """Glide from freq0 to freq1 (linear in log space when both > 0)."""
    n = max(1, int(round(duration * sr)))
    t = np.arange(n) / n
    if freq1 is None or abs(freq1 - freq0) < 1e-6:
        freq = np.full(n, float(freq0))
    else:
        shaped = np.power(t, curve)
        if freq0 > 0 and freq1 > 0:
            freq = np.exp(np.log(freq0) + (np.log(freq1) - np.log(freq0)) * shaped)
        else:
            freq = freq0 + (freq1 - freq0) * shaped
    phase = np.cumsum(freq) / sr
    return _osc(wave, phase)


def noise(duration: float, rng: np.random.Generator, sr: int = SR) -> np.ndarray:
    n = max(1, int(round(duration * sr)))
    return rng.uniform(-1.0, 1.0, n)


def env_exp(n: int, decay: float, attack: float = 0.004, sr: int = SR) -> np.ndarray:
    t = np.arange(n) / sr
    a = max(1, int(attack * sr))
    a = min(a, max(1, n // 4))
    attack_env = np.linspace(0.0, 1.0, a)
    rest = np.exp(-decay * t[: n - a]) if n - a > 0 else np.zeros(0)
    return np.concatenate([attack_env, rest])[:n]


def env_adsr(n: int, attack: float, decay: float, sustain: float, release: float,
             sr: int = SR) -> np.ndarray:
    a = max(1, int(attack * sr))
    d = max(1, int(decay * sr))
    r = max(1, int(release * sr))
    s = max(1, n - a - d - r)
    parts = [
        np.linspace(0.0, 1.0, a),
        np.linspace(1.0, sustain, d),
        np.full(s, sustain),
        np.linspace(sustain, 0.0, r),
    ]
    out = np.concatenate(parts)
    if len(out) < n:
        out = np.concatenate([out, np.zeros(n - len(out))])
    return out[:n]


def lowpass(x: np.ndarray, cutoff: float, sr: int = SR) -> np.ndarray:
    """One pole low pass; cheap, stable, good enough for SFX shaping."""
    if cutoff >= sr / 2:
        return x
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / sr)
    out = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        out[i] = acc
    return out


def highpass(x: np.ndarray, cutoff: float, sr: int = SR) -> np.ndarray:
    return x - lowpass(x, cutoff, sr)


def bandpass(x: np.ndarray, low: float, high: float, sr: int = SR) -> np.ndarray:
    return lowpass(highpass(x, low, sr), high, sr)


def reverb(x: np.ndarray, mix: float = 0.25, taps=(0.031, 0.057, 0.089, 0.127),
           sr: int = SR) -> np.ndarray:
    out = np.copy(x)
    for i, tap in enumerate(taps):
        delay = int(tap * sr)
        if delay <= 0 or delay >= len(x):
            continue
        gain = mix * (0.6 ** i)
        tail = np.zeros_like(x)
        tail[delay:] = x[:-delay] * gain
        out += tail
    return out


def soft_clip(x: np.ndarray, drive: float = 1.4) -> np.ndarray:
    return np.tanh(x * drive) / np.tanh(drive)


def normalize(x: np.ndarray, peak: float = 0.85) -> np.ndarray:
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    if m < 1e-9:
        return x
    return x * (peak / m)


def fade(x: np.ndarray, ms: float = 3.0, sr: int = SR) -> np.ndarray:
    n = min(len(x) // 2, max(1, int(ms * sr / 1000.0)))
    if n <= 0:
        return x
    out = np.copy(x)
    out[:n] *= np.linspace(0.0, 1.0, n)
    out[-n:] *= np.linspace(1.0, 0.0, n)
    return out


def mix(*parts: np.ndarray) -> np.ndarray:
    parts = tuple(p for p in parts if p is not None and len(p))
    if not parts:
        return np.zeros(1)
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def resample(x: np.ndarray, factor: float) -> np.ndarray:
    """Cheap linear resample: pitch/speed shift used to make variants distinct."""
    if abs(factor - 1.0) < 1e-6 or len(x) < 2:
        return x
    n = max(2, int(round(len(x) / factor)))
    src = np.linspace(0.0, len(x) - 1.0, n)
    return np.interp(src, np.arange(len(x)), x)


def pad_to(x: np.ndarray, duration: float, sr: int = SR) -> np.ndarray:
    n = int(round(duration * sr))
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def place(dst: np.ndarray, src: np.ndarray, at: float, gain: float = 1.0,
          sr: int = SR) -> np.ndarray:
    start = int(round(at * sr))
    end = min(len(dst), start + len(src))
    if start >= len(dst):
        return dst
    dst[start:end] += src[: end - start] * gain
    return dst
