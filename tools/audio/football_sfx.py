"""Football Stars sound effects, all made here from sine waves and noise and
packed into one audio sprite (one upload to Roblox instead of 25).

    pip install numpy scipy            (and ffmpeg on the PATH)
    python3 football_sfx.py

Writes build/<name>.wav for every clip, build/Football_SFX.ogg (the file to
upload, the same as audio/Football_SFX.ogg) and build/regions.lua: the
start and length of every clip, which go into Sounds.Regions in
game/ReplicatedStorage/FootballSounds.lua. The random seed is fixed,
so the same script always makes the same sounds.

The building blocks (oscillators, filters, envelopes, reverb) are in
synth.py next to this file.
"""
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import synth as sfx  # noqa: E402
from synth import (SR, n, t, mix, exp_env, bell_env, sweep, osc, noise, lp, hp, bp, svf, drive, fm, bell, reverb,  # noqa: E402
                 fade, trim, level, norm, note, thump, click, whoosh, crackle, sparkle, arp, write_wav)

OUT = os.path.join(HERE, "build")
os.makedirs(OUT, exist_ok=True)
sfx.rng = np.random.default_rng(2026)

CLIPS = {}


def clip(fn):
    CLIPS[fn.__name__] = fn
    return fn


def crowd(dur, excited=1.0):
    """Lots of voices: band-passed noise that swells, with a wobble."""
    base = bp(noise(dur), 300, 2600, 2)
    wobble = 1 + 0.25 * np.sin(2 * np.pi * 3.1 * t(dur)) + 0.15 * np.sin(2 * np.pi * 5.3 * t(dur) + 1)
    voices = sum(osc(f * (1 + 0.01 * np.sin(2 * np.pi * (4 + k) * t(dur))), "saw", dur) * 0.05
                 for k, f in enumerate((310, 370, 450, 520, 610, 700)))
    body = (base * 0.8 + lp(voices, 2200)) * wobble
    return body * bell_env(dur, 0.25 if excited > 0.5 else 0.15, 1.0)


# ----------------------------------------------------------------------------- ball

@clip
def kick():
    return drive(mix((thump(190, 60, 0.3, 0.06), 0, 1.2), (click(0.02, 1200), 0, 0.9), (lp(noise(0.08), 3000) * exp_env(0.08, 0.02), 0, 0.5)), 2.0)


@clip
def net():
    d = 0.65
    swish = svf(noise(d), np.geomspace(5000, 1200, n(d)), 0.9, "bp") * exp_env(d, 0.18, 0.004)
    rattle = crackle(0.4, 160, 0.2, 2500)
    return reverb(mix((swish, 0, 1), (rattle, 0.02, 0.5), (thump(120, 60, 0.2, 0.05), 0, 0.5)), 0.6, 0.2)


@clip
def whistle():
    d = 0.85
    f = 2900 * (1 + 0.035 * np.sign(np.sin(2 * np.pi * 28 * t(d))))
    tone = osc(f, "sine") + osc(f * 2, "sine") * 0.15
    breath = bp(noise(d), 2500, 4500) * 0.25
    env = np.minimum(1, t(d) / 0.02) * np.clip((d - t(d)) / 0.1, 0, 1)
    return (tone + breath) * env * 0.7


@clip
def cheer():
    d = 2.5
    return reverb(mix((crowd(d, 1.0), 0, 1), (crackle(d, 60, 0.4, 3000) * bell_env(d, 0.3), 0, 0.5)), 1.2, 0.35)


@clip
def groan():
    d = 1.3
    f = sweep(260, 150, d)
    voices = sum(osc(f * r, "saw") * 0.2 for r in (1, 1.26, 1.5, 0.75))
    return reverb(lp(voices, 1200) * bell_env(d, 0.2, 1.2) + bp(noise(d), 200, 900) * bell_env(d, 0.2) * 0.4, 1.0, 0.3)


# ----------------------------------------------------------------------------- rewards

@clip
def chime():
    notes = ("C6", "E6", "G6", "C7")
    parts = [(bell(note(x), 1.0, 0.35, 2.0), i * 0.07, 0.6) for i, x in enumerate(notes)]
    return reverb(mix(*parts), 1.0, 0.3, 9000)


@clip
def pop():
    d = 0.3
    return osc(sweep(420, 1100, 0.08), "sine") * exp_env(0.08, 0.03) * 0.8 + mix((bell(1600, d, 0.06, 1.0), 0.02, 0.4))[: n(0.08)]


@clip
def ding():
    return reverb(mix((bell(note("E6"), 0.55, 0.2, 2.2), 0, 0.8), (bell(note("B6"), 0.5, 0.15, 1.5), 0.05, 0.4)), 0.5, 0.2, 9000)


@clip
def perfect():
    return reverb(mix((arp(("C6", "E6", "G6", "C7", "E7"), 0.05, 0.35, "tri", 0.15, 7000, 0.5), 0, 1), (sparkle(0.7, 10), 0.1, 0.4)), 0.8, 0.3, 9000)


@clip
def tier():
    fan = arp(("G4", "C5", "E5", "G5", "C6"), 0.09, 0.5, "saw", 0.3, 4500, 0.45)
    held = sum(osc(note(x), "saw", 1.1) for x in ("C5", "E5", "G5", "C6")) / 4
    held = lp(held, 3500) * bell_env(1.1, 0.12, 1.2)
    return reverb(mix((fan, 0, 1), (held, 0.45, 0.8), (sparkle(1.2, 18), 0.4, 0.5), (crowd(1.4), 0.3, 0.35)), 1.2, 0.3, 9000)


@clip
def legend():
    d = 2.8
    brass = sum(osc(note(x) * (1 + 0.003 * np.sin(2 * np.pi * 5 * t(d))), "saw", d) for x in ("C4", "G4", "C5", "E5", "G5")) / 5
    brass = svf(brass, np.geomspace(600, 5000, n(d)), 0.9) * bell_env(d, 0.3, 1.0)
    boom = thump(90, 35, 1.2, 0.5)
    fan = arp(("C5", "E5", "G5", "C6", "E6", "G6", "C7"), 0.08, 0.6, "saw", 0.35, 5000, 0.35)
    return reverb(mix((brass, 0, 0.9), (boom, 0, 0.9), (fan, 0.15, 0.8), (sparkle(2.0, 30), 0.5, 0.6), (crowd(2.4), 0.3, 0.5)), 1.6, 0.35, 9000)


@clip
def buy():
    coins = mix(*[(bell(rng_f(2600, 4200), 0.35, 0.08, 1.8), i * 0.06, 0.5) for i in range(7)])
    return reverb(mix((arp(("G5", "C6", "E6", "G6"), 0.06, 0.35, "square", 0.14, 5000, 0.4), 0, 1), (coins, 0.1, 0.6)), 0.7, 0.25, 9000)


@clip
def fire():
    d = 1.0
    roar = svf(noise(d), np.geomspace(400, 3000, n(d)), 0.9) * bell_env(d, 0.2, 1.2)
    rise = osc(sweep(300, 1400, 0.5), "saw") * exp_env(0.5, 0.25) * 0.3
    return reverb(drive(mix((roar, 0, 1), (crackle(d, 120, 0.5, 2000), 0, 0.6), (lp(rise, 3000), 0, 1)), 1.5), 0.8, 0.25)


# ----------------------------------------------------------------------------- drills

@clip
def clank():
    ring = fm(620, 0.45, ratio=1.41, index=4, decay=0.12) * 0.7 + fm(930, 0.45, ratio=2.3, index=2, decay=0.09) * 0.4
    return drive(mix((ring, 0, 1), (thump(140, 60, 0.2, 0.05), 0, 0.9), (click(0.015, 1500), 0, 0.8)), 1.6)


@clip
def beep():
    return osc(880, "square", 0.2) * exp_env(0.2, 0.08, 0.003) * 0.5


@clip
def go():
    return mix((osc(1320, "square", 0.5) * exp_env(0.5, 0.2, 0.003) * 0.5, 0, 1), (bell(2640, 0.5, 0.2, 1.0), 0, 0.3))


@clip
def cone():
    return mix((fm(500, 0.25, ratio=1.8, index=3, decay=0.06), 0, 0.7), (thump(260, 120, 0.12, 0.04), 0, 0.8), (click(0.01, 1800), 0, 0.6))


@clip
def tackle():
    body = thump(120, 45, 0.4, 0.1)
    scuff = bp(noise(0.3), 800, 4000) * exp_env(0.3, 0.08)
    return drive(mix((body, 0, 1.2), (scuff, 0.01, 0.7), (kick_raw(), 0.03, 0.6)), 2.0)


def kick_raw():
    return mix((thump(200, 70, 0.2, 0.05), 0, 1), (click(0.015, 1500), 0, 1))


@clip
def miss():
    return mix((whoosh(0.4, 400, 1800, 500, 1.2), 0, 1), (osc(sweep(500, 260, 0.35), "tri") * exp_env(0.35, 0.15) * 0.3, 0.05, 1))


# ----------------------------------------------------------------------------- menus

@clip
def click_():  # the menu click (click() is the noise tick)
    return mix((osc(1800, "sine", 0.06) * exp_env(0.06, 0.015, 0.001), 0, 0.7), (click(0.008, 3000), 0, 0.5))


@clip
def open_():
    return mix((whoosh(0.25, 600, 3000, 1500, 1.3), 0, 0.6), (osc(sweep(500, 900, 0.12), "sine") * exp_env(0.12, 0.05), 0.02, 0.5))


@clip
def close_():
    return mix((whoosh(0.22, 2500, 900, 500, 1.3), 0, 0.5), (osc(sweep(800, 450, 0.12), "sine") * exp_env(0.12, 0.05), 0.02, 0.5))


@clip
def error_():
    return mix((osc(220, "square", 0.14) * exp_env(0.14, 0.08), 0, 0.5), (osc(165, "square", 0.18) * exp_env(0.18, 0.1), 0.13, 0.5))


@clip
def tick():
    return osc(2400, "sine", 0.05) * exp_env(0.05, 0.012, 0.0005) * 0.8


@clip
def whoosh_():
    return whoosh(0.4, 300, 2400, 700, 1.4)


def rng_f(lo, hi):
    return sfx.rng.uniform(lo, hi)


def render_all():
    out = {}
    for name, fn in CLIPS.items():
        key = name.rstrip("_")
        x = fn()
        if key in ("whistle", "cheer", "groan", "legend"):
            out[key] = fade(norm(trim(hp(x, 28)), 0.75), 0.0005, 0.03)
        else:
            out[key] = fade(level(trim(hp(x, 28))), 0.0005, 0.015)
    return out


def build():
    clips = render_all()
    gap = n(0.3)
    parts, regions, cursor = [np.zeros(n(0.1))], {}, n(0.1)
    for name in sorted(clips):
        x = clips[name]
        write_wav(os.path.join(OUT, name + ".wav"), x)
        regions[name] = (round(cursor / SR, 3), round(len(x) / SR, 3))
        parts += [x, np.zeros(gap)]
        cursor += len(x) + gap
    sprite = np.concatenate(parts)
    wav = os.path.join(OUT, "Football_SFX.wav")
    write_wav(wav, sprite)
    import subprocess
    subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT, "Football_SFX.ogg")], check=True)
    with open(os.path.join(OUT, "regions.lua"), "w") as f:
        f.write("\t-- name = { start, length } in seconds inside the sprite\n")
        for k in sorted(regions):
            f.write(f"\t{k} = {{ {regions[k][0]}, {regions[k][1]} }},\n")
    print(f"{len(clips)} clips, sprite {len(sprite) / SR:.1f}s")
    return regions


if __name__ == "__main__":
    build()
