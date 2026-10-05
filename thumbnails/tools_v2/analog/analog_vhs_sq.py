#!/usr/bin/env python3
"""VHS camcorder / found-footage degradation of a clean render.

usage: analog_vhs.py INPUT OUTPUT [--seed N] [--stages DIR]

The picture is first pushed through the *medium* (resolution loss at NTSC
D1-ish sampling, luma/chroma band limiting, chroma smear + misregistration,
edge ringing, field weave) and only then do tape faults (tracking bands,
head-switch strip, dropouts, line jitter) and playback noise get added on top
at the tape resolution.  The result is bilinearly upscaled to 1920x1080.
Everything is seeded so a given input always gives the same output.
"""
import os
import sys
import argparse
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
from scipy.signal import lfilter

HERE = os.path.dirname(os.path.abspath('/tmp/claude-0/-home-user--1-football/68bac485-aa9b-58fa-9136-959e989c4159/scratchpad/work_face2/analog_vhs/x.py'))
VT323 = os.path.join(HERE, '..', '..', 'node_modules', '@fontsource', 'vt323',
                     'files', 'vt323-latin-400-normal.woff')
FALLBACK_FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'

OUT_W, OUT_H = 1080, 1080
TW, TH = 480, 480          # "tape domain" (anamorphic 16:9 NTSC)

P = dict(
    # ---- camera side
    pre_bloom=0.05,
    pre_detail=0.45,
    pre_fine=0.75,          # small-scale boost so blood speckle survives the resolution loss
    cam_gamma=0.88,        # local-contrast boost before tape (keeps detail alive)
    # ---- tape bandwidth (sigma in tape-domain pixels)
    luma_sigma=0.80,
    luma_ring=0.75,         # horizontal edge-enhance amount (halos)
    luma_ring_sigma=1.9,
    hi_smear=0.30,
    chroma_sigma=4.2,
    chroma_smear_tau=5.5,
    chroma_shift_x=2.4,
    chroma_shift_y=1.0,
    sat=0.96,
    red_boost=1.22,
    # ---- noise
    luma_noise=0.020,
    chroma_noise=0.012,
    # ---- grade
    black=0.018,
    gamma=1.04,
    s_curve=0.20,
)


# ----------------------------------------------------------------- helpers
def rgb2yiq(a):
    m = np.array([[0.299, 0.587, 0.114],
                  [0.596, -0.274, -0.322],
                  [0.211, -0.523, 0.312]], np.float32)
    return a @ m.T


def yiq2rgb(a):
    m = np.array([[1.0, 0.956, 0.621],
                  [1.0, -0.272, -0.647],
                  [1.0, -1.106, 1.703]], np.float32)
    return a @ m.T


def gblur_h(a, s):
    return ndi.gaussian_filter1d(a, s, axis=1, mode='nearest') if s > 0 else a


def gblur_v(a, s):
    return ndi.gaussian_filter1d(a, s, axis=0, mode='nearest') if s > 0 else a


def smear_right(a, tau):
    """one-sided exponential tail along x (colour / luma bleeding to the right)"""
    k = float(np.exp(-1.0 / tau))
    return lfilter([1 - k], [1, -k], a, axis=1).astype(np.float32)


def shift_img(a, dx, dy):
    m = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(a, m, (a.shape[1], a.shape[0]), flags=cv2.INTER_LINEAR,
                          borderMode=cv2.BORDER_REPLICATE)


def remap_rows(img, dx_rows):
    """horizontal per-row displacement (tape-domain pixels)"""
    h, w = img.shape[:2]
    xs = (np.arange(w, dtype=np.float32)[None, :] - dx_rows[:, None].astype(np.float32))
    xs = np.repeat(xs, 1, axis=0)
    ys = np.repeat(np.arange(h, dtype=np.float32)[:, None], w, axis=1)
    return cv2.remap(img, xs, ys, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ----------------------------------------------------------------- OSD
def font(size):
    for p in (VT323, FALLBACK_FONT):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()


def osd_layer(w, h):
    """text layer in tape domain: returns (rgb float, alpha float)"""
    im = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(im)
    f = font(32)
    # PLAY + triangle, top-left
    x0, y0 = 30, 22
    d.text((x0 + 26, y0), 'PLAY', font=f, fill=255)
    d.polygon([(x0, y0 + 6), (x0, y0 + 24), (x0 + 15, y0 + 15)], fill=255)
    # date stamp bottom-right (above the head-switch strip)
    f2 = font(28)
    txt1 = 'OCT 04 1998'
    txt2 = '02:13 AM'
    tw1 = d.textlength(txt1, font=f2)
    tw2 = d.textlength(txt2, font=f2)
    d.text((w - 30 - tw1, h - 76), txt1, font=f2, fill=255)
    d.text((w - 30 - tw2, h - 51), txt2, font=f2, fill=255)
    a = np.asarray(im, np.float32) / 255.0
    return a


# ----------------------------------------------------------------- stages
def camera_stage(src, rng):
    """src: float rgb 1080p. lens/CCD behaviour before the tape sees it."""
    img = src.copy()
    # local-contrast so blood speckle / teeth detail survives the downscale
    if P['pre_detail'] > 0:
        base = cv2.GaussianBlur(img, (0, 0), 14)
        img = img + P['pre_detail'] * (img - base)
        img = np.clip(img, 0, 1)
        fine = cv2.GaussianBlur(img, (0, 0), 3.5)
        img = np.clip(img + P['pre_fine'] * (img - fine), 0, 1)
    # camcorder AGC lifts the shadows a little (reveals ribbing / blood speckle in the mouth)
    img = np.clip(img, 0, 1)
    w_sh = 1 - smoothstep(0.30, 0.75, img)
    img = img * (1 - w_sh) + (img ** P['cam_gamma']) * w_sh
    # CCD / lens bloom around blown highlights
    lum = img.max(axis=2)
    hi = np.clip((lum - 0.62) / 0.38, 0, 1)[..., None] * img
    b = cv2.GaussianBlur(hi, (0, 0), 10) * 0.6 + cv2.GaussianBlur(hi, (0, 0), 38) * 0.7
    img = 1 - (1 - img) * (1 - np.clip(b * P['pre_bloom'] * 2.0, 0, 1))
    return np.clip(img, 0, 1).astype(np.float32)


def tape_record(dom, rng):
    """dom: tape-domain rgb float. band-limit luma / chroma, smear, ring."""
    yiq = rgb2yiq(dom)
    Y, I, Q = yiq[..., 0], yiq[..., 1], yiq[..., 2]

    # luma: soft lowpass, a bit of rightward trail, then edge-enhance (ringing)
    Yl = gblur_h(Y, P['luma_sigma'])
    Yl = 0.78 * Yl + 0.22 * smear_right(Yl, 1.6)
    Yl = gblur_v(Yl, 0.45)
    ring = Yl - gblur_h(Yl, P['luma_ring_sigma'])
    Yl = Yl + P['luma_ring'] * ring
    # blown highlights overshoot and smear to the right (head amp saturation)
    hi = np.clip((Y - 0.88) / 0.12, 0, 1)
    Yl = Yl + P['hi_smear'] * smear_right(gblur_h(hi, 1.5), 16.0)

    # chroma: heavy horizontal lowpass + rightward smear + vertical lowpass,
    # mis-registered against luma
    def chroma(c):
        c = gblur_h(c, P['chroma_sigma'])
        c = 0.55 * c + 0.45 * smear_right(c, P['chroma_smear_tau'])
        c = gblur_v(c, 1.5)
        c = shift_img(c, P['chroma_shift_x'], P['chroma_shift_y'])
        return c * P['sat']
    Il, Ql = chroma(I), chroma(Q)
    Il = np.where(Il > 0, Il * P['red_boost'], Il)
    return np.stack([Yl, Il, Ql], -1)


def add_record_noise(yiq, rng):
    h, w = yiq.shape[:2]
    # luma noise: per field, horizontally correlated (tape noise is streaky)
    n = rng.standard_normal((h, w)).astype(np.float32)
    n = gblur_h(n, 1.1)
    n /= n.std() + 1e-6
    # noisier in mid-tones/shadows than highlights (AGC/pedestal), keep blacks clean
    Y = yiq[..., 0]
    gain = 0.55 + 0.9 * np.clip(Y * 3.0, 0, 1) * (1 - 0.5 * np.clip((Y - 0.7) / 0.3, 0, 1))
    yiq[..., 0] = Y + n * P['luma_noise'] * gain
    # chroma noise: blotchy
    for ch in (1, 2):
        c = rng.standard_normal((h, w)).astype(np.float32)
        c = gblur_h(c, 3.0)
        c = gblur_v(c, 0.8)
        c /= c.std() + 1e-6
        yiq[..., ch] += c * P['chroma_noise']
    # slow hum bars (low-frequency vertical brightness ripple)
    yy = np.arange(h, dtype=np.float32)
    hum = 0.016 * np.sin(2 * np.pi * yy / 150.0 + 1.3) + 0.006 * np.sin(2 * np.pi * yy / 47.0)
    yiq[..., 0] += hum[:, None]
    return yiq


def line_wobble(img, rng, h):
    yy = np.arange(h, dtype=np.float32)
    dx = 0.55 * np.sin(2 * np.pi * yy / 130.0 + 0.7) + 0.3 * np.sin(2 * np.pi * yy / 43.0 + 2.0)
    # correlated random walk jitter
    j = ndi.gaussian_filter1d(rng.standard_normal(h).astype(np.float32), 2.0)
    dx += 0.9 * j / (j.std() + 1e-6) * 0.35
    # field jitter (even / odd lines slightly different)
    dx[1::2] += 0.18
    # top-of-frame flagging
    top = np.exp(-yy / 9.0)
    dx += top * 2.2
    return remap_rows(img, dx)


def head_switch(img, rng):
    """bottom strip: horizontal tear + noise, like the VHS head-switch point"""
    h, w = img.shape[:2]
    n = 9                       # lines in tape domain (~20 px at 1080p)
    y0 = h - n
    dx = np.zeros(h, np.float32)
    t = np.arange(n, dtype=np.float32) / n
    dx[y0:] = 6.0 * t ** 2 * 3.0 + rng.standard_normal(n) * 0.8 * t
    img = remap_rows(img, dx)
    strip = img[y0:].copy()
    nz = gblur_h(rng.standard_normal((n, w)).astype(np.float32), 1.6)
    nz = nz / nz.std() * 0.16
    fade = smoothstep(0.0, 0.8, t)[:, None, None]
    gray = strip.mean(axis=2, keepdims=True)
    strip = strip * (1 - 0.5 * fade) + gray * 0.5 * fade
    strip = strip + nz[..., None] * (0.3 + 0.9 * fade) + 0.04 * fade
    img[y0:] = np.clip(strip, 0, 1)
    return img


def tracking_band(img, rng, y0, y1, shift, snow=0.5, streaks=4):
    """band of tape misreading: bending horizontal displacement + noise bed + streaks"""
    h, w = img.shape[:2]
    yy = np.arange(h, dtype=np.float32)
    t = np.clip((yy - y0) / max(1, (y1 - y0)), 0, 1)
    inside = ((yy >= y0) & (yy <= y1)).astype(np.float32)
    prof = np.clip(np.sin(np.pi * t), 0, None) ** 1.2 * inside
    # tear: displacement grows then snaps back
    dx = shift * (0.35 * prof + 0.65 * (t ** 1.6) * inside)
    dx += rng.standard_normal(h).astype(np.float32) * 0.25 * shift * 0.12 * inside
    img = remap_rows(img, dx)

    # noise bed, strongest at the lower edge of the band
    win = (smoothstep(0.0, 0.25, t) * (0.35 + 0.65 * t)) * inside
    # lower edge bright seam
    seam = np.exp(-((yy - y1) ** 2) / (2 * 1.1 ** 2))
    nz = gblur_h(rng.standard_normal((h, w)).astype(np.float32), 2.6)
    nz = nz / nz.std()
    base = img.mean(axis=2, keepdims=True)
    g = np.clip(0.28 + 0.22 * nz, 0, 1)[..., None] * np.array([1.0, 0.98, 1.04], np.float32)
    a = np.clip(snow * win + 0.5 * seam, 0, 0.9)[:, None, None]
    img = img * (1 - a) + (0.55 * g + 0.45 * base) * a + (seam[:, None, None] * 0.12)

    # white noise streaks inside the band
    for _ in range(streaks):
        yk = int(rng.integers(max(0, int(y0)), max(int(y0) + 1, int(y1))))
        L = int(rng.integers(60, 360))
        xk = int(rng.integers(0, max(1, w - L)))
        prof_x = np.zeros(w, np.float32)
        prof_x[xk:xk + L] = rng.uniform(0.35, 0.8)
        prof_x = gblur_h(prof_x[None, :], 3.0)[0]
        prof_x = smear_right(prof_x[None, :], 8.0)[0]
        prof_x *= (0.7 + 0.5 * gblur_h(rng.standard_normal(w).astype(np.float32)[None], 1.5)[0])
        img[yk] = img[yk] * (1 - np.clip(prof_x, 0, 1)[:, None]) + np.clip(prof_x, 0, 1)[:, None] * 0.95
    return np.clip(img, 0, 1)


def line_glitches(img, rng, specs):
    """thin single-line tears: [(y, height, shift)]"""
    for y, hgt, s in specs:
        seg = img[y:y + hgt].copy()
        k = np.arange(hgt, dtype=np.float32)
        dxs = np.full(hgt, s, np.float32) * (1 - 0.3 * k / max(1, hgt))
        full = np.zeros(img.shape[0], np.float32)
        full[y:y + hgt] = dxs
        tmp = remap_rows(img, full)
        img[y:y + hgt] = tmp[y:y + hgt]
    return img


def dropouts(img, rng, n, avoid):
    h, w = img.shape[:2]
    cnt = 0
    tries = 0
    while cnt < n and tries < n * 30:
        tries += 1
        y = int(rng.integers(2, h - 14))
        x = int(rng.integers(8, w - 80))
        L = int(rng.integers(7, 44))
        if any(ax0 <= x + L and x <= ax1 and ay0 <= y <= ay1 for ax0, ax1, ay0, ay1 in avoid):
            continue
        prof = np.zeros(w, np.float32)
        prof[x:x + L] = 1.0
        prof = gblur_h(prof[None], 1.3)[0]
        prof = 0.55 * prof + 0.45 * smear_right(prof[None], 2.5)[0]
        amp = rng.uniform(0.55, 1.0)
        tint = np.array([1.0, 0.97, 0.92], np.float32) * np.float32([1.0, rng.uniform(0.9, 1.0), rng.uniform(0.9, 1.05)])
        a = (prof * amp)[:, None]
        img[y] = img[y] * (1 - a) + a * tint[None, :]
        # second field often catches the tail
        if rng.random() < 0.35:
            a2 = np.roll(a, int(rng.integers(3, 12)), axis=0) * 0.35
            img[y + 1] = img[y + 1] * (1 - a2) + a2
        cnt += 1
    return img


def tone(img):
    black, gamma = P['black'], P['gamma']
    x = np.clip((img - black) / (1 - black), 0, 1) ** gamma
    # S curve for punch
    x = x + P['s_curve'] * (x - 0.5) * (1 - np.abs(2 * x - 1))
    return np.clip(x, 0, 1)


def color_cast(img):
    """washed VHS colour: green shadows, slightly magenta mids/highs"""
    lum = img.mean(axis=2, keepdims=True)
    sh = (1 - np.clip(lum * 3.0, 0, 1))
    hi = smoothstep(0.25, 0.7, lum) * (1 - smoothstep(0.78, 1.0, lum))
    img = img + sh * np.array([-0.004, 0.012, 0.004], np.float32)
    img = img * (1 + hi * np.array([0.035, -0.03, 0.02], np.float32))
    return np.clip(img, 0, 1)


# ----------------------------------------------------------------- main
def process(inp, outp, seed=1998, stages=None):
    rng = np.random.default_rng(seed)
    src = Image.open(inp).convert('RGB')
    src = np.asarray(src, np.float32) / 255.0
    src1080 = cv2.resize(src, (OUT_W, OUT_H), interpolation=cv2.INTER_AREA)

    def dump(name, a):
        if stages:
            os.makedirs(stages, exist_ok=True)
            cv2.imwrite(os.path.join(stages, name + '.png'),
                        (np.clip(a, 0, 1)[..., ::-1] * 255 + 0.5).astype(np.uint8))

    cam = camera_stage(src1080, rng)
    dom = cv2.resize(cam, (TW, TH), interpolation=cv2.INTER_AREA)

    # on-screen display is overlaid in-camera, i.e. BEFORE the tape degradation
    osd = osd_layer(TW, TH)
    dom = dom * (1 - 0.72 * osd[..., None]) + 0.72 * osd[..., None] * np.array([0.93, 0.95, 0.93], np.float32)
    dump('1_domain', cv2.resize(dom, (OUT_W, OUT_H), interpolation=cv2.INTER_NEAREST))

    # interlace field alternation (static scene -> only a trace of combing)
    f = dom.copy()
    f[1::2] = shift_img(dom, 0.55, 0.0)[1::2]
    f[0::2] *= 1.045
    f[1::2] *= 0.96
    dom = f

    yiq = tape_record(dom, rng)
    yiq = add_record_noise(yiq, rng)
    rgb = np.clip(yiq2rgb(yiq), 0, 1).astype(np.float32)
    dump('2_recorded', cv2.resize(rgb, (OUT_W, OUT_H), interpolation=cv2.INTER_LINEAR))

    # ---------------- tape faults (in tape domain, on top of the recording)
    rgb = line_wobble(rgb, rng, TH)
    # y positions in tape domain (480 lines <-> 1080 px: x0.444)
    rgb = tracking_band(rgb, rng, 343, 363, shift=-19, snow=0.55, streaks=5)     # jaw / chin
    rgb = tracking_band(rgb, rng, 9, 13, shift=6, snow=0.30, streaks=2)         # forehead cap
    rgb = line_glitches(rgb, rng, [(318, 2, -5), (430, 3, 9), (205, 1, 4)])
    # dropouts keep clear of the eyes and teeth
    avoid = [(110, 480, 40, 140)]            # eyes in tape domain
    rgb = dropouts(rgb, rng, 11, avoid)
    rgb = head_switch(rgb, rng)
    dump('3_faults', cv2.resize(rgb, (OUT_W, OUT_H), interpolation=cv2.INTER_LINEAR))

    # ---------------- playback grade, upscale
    rgb = color_cast(tone(rgb))
    up = cv2.resize(rgb, (OUT_W, OUT_H), interpolation=cv2.INTER_LINEAR)

    # faint RF ghost (reflection) + gentle bloom from the display chain
    ghost = shift_img(up, 15, 0)
    up = np.clip(up + 0.05 * np.clip(ghost - up, 0, 1), 0, 1)
    hi = np.clip(up - 0.72, 0, 1)
    bl = cv2.GaussianBlur(hi, (0, 0), 14) * 0.55 + cv2.GaussianBlur(hi, (0, 0), 46) * 0.45
    up = 1 - (1 - up) * (1 - np.clip(bl * 0.08, 0, 1))
    # capture-chain sharpening (restores perceived edge crispness, adds a touch of halo)
    bl_s = cv2.GaussianBlur(up, (0, 0), 2.2)
    up = np.clip(up + 0.55 * (up - bl_s), 0, 1)
    # lens vignette
    yy, xx = np.mgrid[0:OUT_H, 0:OUT_W].astype(np.float32)
    r = np.sqrt(((xx - OUT_W / 2) / (OUT_W / 2)) ** 2 + ((yy - OUT_H * 0.45) / (OUT_H / 2)) ** 2)
    up *= (1 - 0.22 * np.clip(r - 0.55, 0, 1) ** 1.5)[..., None]
    out = (np.clip(up, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(out).save(outp)
    return out


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('inp')
    ap.add_argument('outp')
    ap.add_argument('--seed', type=int, default=1998)
    ap.add_argument('--stages', default=None)
    a = ap.parse_args()
    process(a.inp, a.outp, a.seed, a.stages)
