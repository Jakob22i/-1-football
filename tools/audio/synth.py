"""Building blocks for synthesized sound effects: oscillators, noise,
filters, envelopes, bells, whooshes, reverb and loudness levelling. Used by
football_sfx.py.
"""
import os
import subprocess
import numpy as np
from scipy import signal

SR = 44100
rng = np.random.default_rng(1234)


# ----------------------------------------------------------------------------- basics

def n(dur):
    return int(round(SR * dur))


def t(dur):
    return np.arange(n(dur)) / SR


def pad(x, length):
    if len(x) >= length:
        return x[:length]
    return np.concatenate([x, np.zeros(length - len(x))])


def mix(*parts, dur=None):
    """parts: (signal, offset_seconds, gain)"""
    end = max(n(off) + len(sig) for sig, off, _ in parts)
    if dur:
        end = max(end, n(dur))
    out = np.zeros(end)
    for sig, off, gain in parts:
        i = n(off)
        out[i:i + len(sig)] += sig * gain
    return out


def exp_env(dur, decay, attack=0.002):
    tt = t(dur)
    e = np.exp(-tt / decay)
    a = n(attack)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def ad_env(dur, attack, release_curve=2.0):
    tt = t(dur)
    e = np.ones_like(tt)
    a = n(attack)
    e[:a] = np.linspace(0, 1, a) if a else 1
    rest = len(tt) - a
    e[a:] = (1 - np.linspace(0, 1, rest)) ** release_curve
    return e


def bell_env(dur, peak=0.4, curve=1.5):
    x = np.linspace(0, 1, n(dur))
    up = np.clip(x / peak, 0, 1)
    down = np.clip((1 - x) / (1 - peak), 0, 1)
    return (np.minimum(up, down)) ** curve


def phase_of(freq):
    return 2 * np.pi * np.cumsum(freq) / SR


def sweep(f0, f1, dur, curve="exp"):
    x = np.linspace(0, 1, n(dur))
    if curve == "exp":
        return f0 * (f1 / f0) ** x
    return f0 + (f1 - f0) * x


def osc(freq, shape="sine", dur=None):
    if np.isscalar(freq):
        freq = np.full(n(dur), float(freq))
    ph = phase_of(freq)
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    # band-limit-ish saw/square by summing harmonics under Nyquist
    out = np.zeros_like(ph)
    fmax = np.max(freq)
    k = 1
    while k * fmax < SR / 2.2 and k < 40:
        if shape == "saw":
            out += np.sin(k * ph) / k
        elif shape == "square" and k % 2 == 1:
            out += np.sin(k * ph) / k
        k += 1
    return out * (0.6 if shape == "saw" else 0.8)


def noise(dur):
    return rng.standard_normal(n(dur))


def sos(kind, f, order=2):
    if kind == "bp":
        return signal.butter(order, [f[0] / (SR / 2), f[1] / (SR / 2)], btype="band", output="sos")
    return signal.butter(order, f / (SR / 2), btype=kind, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(sos("low", f, order), x)


def hp(x, f, order=2):
    return signal.sosfilt(sos("high", f, order), x)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(sos("bp", (lo, hi), order), x)


def svf(x, fc, q=0.8, mode="lp"):
    """Time-varying state variable filter; fc can be an array."""
    fc = np.broadcast_to(np.asarray(fc, float), x.shape)
    low = band = 0.0
    out = np.empty_like(x)
    damp = 1.0 / q
    for i in range(len(x)):
        f = 2 * np.sin(np.pi * min(fc[i], SR / 6) / SR)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        out[i] = low if mode == "lp" else (band if mode == "bp" else high)
    return out


def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


def fm(freq, dur, ratio=1.4, index=3.0, decay=0.3, index_decay=None):
    tt = t(dur)
    idx = index * np.exp(-tt / (index_decay or decay))
    mod = np.sin(2 * np.pi * freq * ratio * tt) * idx
    return np.sin(2 * np.pi * freq * tt + mod) * exp_env(dur, decay)


def bell(freq, dur=0.6, decay=0.25, bright=2.5):
    return fm(freq, dur, ratio=3.5, index=bright, decay=decay, index_decay=decay * 0.4) * 0.8 + fm(freq * 2, dur, ratio=1.0, index=0.5, decay=decay * 0.5) * 0.2


def reverb(x, size=0.9, mix_amt=0.25, tone=5000):
    ir_len = size
    ir = noise(ir_len) * np.exp(-t(ir_len) / (size / 5))
    ir = lp(ir, tone)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)[: len(x) + n(ir_len)]
    dry = pad(x, len(wet))
    return dry * (1 - mix_amt) + wet * mix_amt * 0.6


def fade(x, fin=0.001, fout=0.02):
    x = x.copy()
    a, b = n(fin), n(fout)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def trim(x, thresh=0.0008):
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    return x[: idx[-1] + n(0.01)]


def short_loudness(x, win=0.1):
    w = n(win)
    if len(x) <= w:
        return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    return 20 * np.log10(max(np.sqrt(np.mean(x[i:i + w] ** 2)) for i in range(0, len(x) - w, w // 2)) + 1e-9)


def level(x, target=-9.0, max_boost=4.0):
    """Bring quiet, spiky clips up with a soft clipper so everything sits at a
    similar loudness; Volume in Sounds.lua then sets the real mix."""
    x = norm(x)
    gain = min(max_boost, 10 ** ((target - short_loudness(x)) / 20))
    if gain > 1.05:
        x = np.tanh(x * gain / 0.72 * 0.89) / np.tanh(gain * 0.89) * 0.72
    return norm(x)


def norm(x, peak=0.72):
    m = np.max(np.abs(x))
    return x / m * peak if m > 0 else x


def note(name):
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    key, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[key] + (octave - 4) * 12) / 12)


def thump(f0=160, f1=45, dur=0.35, decay=0.12):
    return osc(sweep(f0, f1, dur), "sine") * exp_env(dur, decay, 0.001)


def click(dur=0.012, lo=2500):
    return hp(noise(dur), lo) * exp_env(dur, dur / 3, 0.0003)


def whoosh(dur=0.25, f0=500, f1=2600, f2=900, q=1.4, peak=0.45):
    half = n(dur * peak)
    fc = np.concatenate([np.geomspace(f0, f1, half), np.geomspace(f1, f2, n(dur) - half)])
    return svf(noise(dur), fc, q=q, mode="bp") * bell_env(dur, peak, 1.3)


def crackle(dur, density=90, decay=0.35, lo=1500):
    out = np.zeros(n(dur))
    count = int(density * dur)
    for _ in range(count):
        i = rng.integers(0, len(out) - n(0.01))
        c = click(rng.uniform(0.002, 0.008), lo) * rng.uniform(0.3, 1)
        out[i:i + len(c)] += c
    return out * exp_env(dur, decay, 0.0)


def sparkle(dur=0.8, count=14, lo=2600, hi=6200, decay=0.5):
    out = np.zeros(n(dur))
    for k in range(count):
        f = rng.uniform(lo, hi)
        s = bell(f, 0.3, 0.06, 1.5) * rng.uniform(0.25, 0.6)
        i = int(rng.uniform(0, 0.75) * (len(out) - len(s)))
        out[i:i + len(s)] += s
    return out * exp_env(dur, decay, 0.0)


def coin(f=note("B5"), dur=0.35):
    a = osc(f, "square", 0.07) * exp_env(0.07, 0.2, 0.001)
    b = osc(f * 4 / 3, "square", dur - 0.07) * exp_env(dur - 0.07, 0.12, 0.001)
    return lp(np.concatenate([a, b]), 7000) * 0.5 + np.concatenate([bell(f * 2, 0.07, 0.05), bell(f * 8 / 3, dur - 0.07, 0.12)]) * 0.3


def arp(notes, step=0.075, dur_each=0.35, shape="square", decay=0.18, cutoff=5000, gain=0.5):
    parts = []
    for i, nn in enumerate(notes):
        f = note(nn) if isinstance(nn, str) else nn
        s = lp(osc(f, shape, dur_each) * exp_env(dur_each, decay, 0.002), cutoff) * gain
        s += bell(f * 2, dur_each, decay * 0.8, 1.2) * 0.25
        parts.append((s, i * step, 1.0))
    return mix(*parts)


def brass_chord(freqs, dur=1.0, attack=0.03, cutoff=2600, gain=0.3):
    out = np.zeros(n(dur))
    for f in freqs:
        for det in (-0.006, 0.0, 0.006):
            out += osc(f * (1 + det), "saw", dur)
    env = np.minimum(np.linspace(0, 1, n(dur)) / (attack / dur), 1) * exp_env(dur, dur * 0.55, 0)
    fc = 600 + cutoff * np.clip(np.linspace(0, 1, n(dur)) * 8, 0, 1) * np.exp(-t(dur) / (dur * 0.6))
    return svf(out * env, fc, q=0.9) * gain / len(freqs)


def taiko(f=95, dur=0.7):
    body = osc(sweep(f * 1.6, f, dur), "sine") * exp_env(dur, 0.18, 0.001)
    skin = lp(noise(dur), 900) * exp_env(dur, 0.03, 0.0005) * 0.6
    return drive(body + skin, 1.6)


# ----------------------------------------------------------------------------- recipes


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", path], input=pcm, check=True)
