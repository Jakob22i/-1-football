#!/usr/bin/env python3
"""
analog_flash.py  --  found-photo / harsh compact-camera-flash look.

usage: python3 analog_flash.py INPUT.png OUTPUT.png [--set key=value ...]

Pipeline (order matters, it mimics the recording chain):
  1. SCENE / OPTICS   (1080p working res, supersampled from the 4K input)
       flash falloff + exposure, bloom/halation, lens-dirt veil, desaturate +
       split-tone, hard S-curve with crushed blacks, chromatic aberration,
       faint long-exposure ghost
  2. SENSOR           resolution loss FIRST: lens softness -> area downsample to
       the capture resolution -> dust -> Bayer mosaic -> shot+read noise ->
       cheap demosaic -> in-camera NR (chroma smear) -> in-camera sharpening
  3. CODEC            JPEG gen 1 at capture res (4:2:0) -> resample + JPEG gen 2
       -> (optional chroma corruption) -> upscale to 1920x1080 -> viewer
       over-sharpen halo -> scratches/dust flecks -> JPEG gen 3
All random draws use fixed seeds, so the output is reproducible.
"""
import sys, io, json
import numpy as np
import cv2
from PIL import Image

W, H = 1920, 1080

P = dict(
    seed=2004,
    # ---- scene / optics
    gain=1.55,            # flash exposure on the face (linear gain)
    flash_cx=0.505, flash_cy=0.40, flash_rx=0.34, flash_ry=0.62, flash_pow=1.35,
    bg_floor=0.30,        # how much of the flash still reaches the far background
    vignette=0.55,
    bloom_thr=0.55, bloom_w1=0.55, bloom_w2=0.45, bloom_w3=0.30, bloom_s1=7, bloom_s2=26, bloom_s3=90,
    eye_boost=1.0,        # extra white disc on the eyes (1 = on)
    eye_r=1.0,            # scale of that disc
    eye_soft=9, eye_amp=2.2,
    dirt=0.55,            # lens dirt veil strength
    smudge=0.0, smudge_blur=6.0, smudge_veil=0.035,   # thumb-smudge wipe: local softening + milky veil (kept off eyes/grin)
    smear=0.0, smear_len=140, smear_ang=-18,   # directional smudge streak on the hot spots
    keep_color=0.20,      # how much of the original chroma survives (0 = mono)
    red_keep=0.35,        # extra chroma kept for deep reds (blood / red rim light)
    tint_sh=(0.78, 0.97, 1.00),   # cold shadows
    tint_hi=(1.00, 1.00, 0.90),   # sickly highlights
    # local exposure blobs (cx, cy, sx, sy, amp): gain *= 1 + amp*gauss  -- fill the dark red-lit side, tame the rim flare
    blobs=[(1170, 450, 260, 330, 3.0), (1250, 580, 140, 220, 2.5), (1275, 235, 60, 120, -0.65)],
    haze=0.0, haze_s=140, haze_tint=(0.80, 1.0, 0.95),   # flash veiling glare around the head
    mono_w=(0.30, 0.52, 0.18),
    pre_gamma=0.80,       # <1 lifts the dark (red-lit) side of the face before the crush
    black=0.060, white=0.92, contrast=1.9, mid=0.46,
    ca=0.0045,            # lateral chromatic aberration (fraction of radius)
    ghost=0.10, ghost_dx=-34, ghost_dy=14, ghost_blur=9,
    # ---- sensor
    cap_w=960, cap_h=540,
    lens_soft=0.55,       # gaussian sigma in capture pixels, applied before sampling
    iso_a=0.0042, iso_read=0.0045,   # shot / read noise (linear light)
    pedestal=0.012,       # lifted black level of the cheap sensor
    chroma_nr=1.7, luma_nr=0.55,
    cam_sharp=1.15, cam_sharp_r=1.1,
    n_dust=26, n_hot=14, dust_a=0.38,
    # ---- codec
    q1=48, q2=42, q3=62,
    mid_w=1280, mid_h=720,
    view_sharp=0.85, view_sharp_r=1.5,
    grain=1.3,            # output-res dither grain (8-bit levels)
    n_scratch=3, n_fleck=40,
    corrupt=0.0,          # chroma-corruption band strength (0 = off)
)


# ---- the approved look (iteration 12). Everything above is the tunable default set;
# this block is what produces final.png. Override any key on the CLI with --set key=value.
P.update(dict(
    gain=1.0, flash_cx=0.50, flash_cy=0.46, flash_rx=0.42, flash_ry=0.72, bg_floor=0.35, vignette=0.40,
    bloom_thr=0.85, bloom_s1=5, bloom_s2=18, bloom_w1=0.28, bloom_w2=0.07, bloom_w3=0.03,
    eye_boost=1.0, eye_r=0.86, eye_soft=3, eye_amp=3.6,
    dirt=0.18, haze=0.10, smear=0.06, smear_len=160, smudge=1.0,
    keep_color=0.15, red_keep=0.12, mono_w=(0.24, 0.56, 0.20), pre_gamma=1.0,
    contrast=2.1, mid=0.56, black=0.07, white=0.97,
    ca=0.007, ghost=0.32, ghost_dx=-90, ghost_dy=34, ghost_blur=12,
    cap_w=1152, cap_h=648, mid_w=1440, mid_h=810,
    iso_a=0.0062, iso_read=0.0056, pedestal=0.004,
    n_dust=32, dust_a=0.5, q1=42, q2=38, q3=58,
))


# ------------------------------------------------------------------ helpers
def s2l(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4).astype(np.float32)


def l2s(x):
    x = np.clip(x, 0, 1)
    return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(x, 1 / 2.4) - 0.055).astype(np.float32)


def blur(img, s):
    if s <= 0:
        return img
    return cv2.GaussianBlur(img, (0, 0), s, borderType=cv2.BORDER_REFLECT)


def lowfreq(rng, shape, sigma):
    """smooth noise, unit std, built at reduced size for speed"""
    h, w = shape
    f = max(1, int(sigma / 2))
    sh, sw = max(4, h // f), max(4, w // f)
    n = rng.standard_normal((sh, sw)).astype(np.float32)
    n = cv2.GaussianBlur(n, (0, 0), max(1.0, sigma / f), borderType=cv2.BORDER_REFLECT)
    n = cv2.resize(n, (w, h), interpolation=cv2.INTER_CUBIC)
    return (n - n.mean()) / (n.std() + 1e-6)


def to8(x):
    return np.clip(np.rint(x * 255.0), 0, 255).astype(np.uint8)


def jpeg(a8, q, sub=2):
    buf = io.BytesIO()
    Image.fromarray(a8).save(buf, 'JPEG', quality=int(q), subsampling=sub, optimize=False)
    buf.seek(0)
    return np.array(Image.open(buf).convert('RGB'))


def unsharp_luma(rgb, amount, radius):
    """oversharpen the luma only (halo / ringing)"""
    if amount <= 0:
        return rgb
    y = rgb @ np.array([0.299, 0.587, 0.114], np.float32)
    d = y - blur(y, radius)
    return np.clip(rgb + amount * d[..., None], 0, 1)


def grids(w, h):
    X, Y = np.meshgrid(np.arange(w, dtype=np.float32), np.arange(h, dtype=np.float32))
    return X, Y


# --- protected zones (eyes + grin) in 1080p coordinates, used to keep glitches off them
def protect_mask(w=W, h=H):
    m = np.zeros((h, w), np.float32)
    for (cx, cy, rx, ry, ang) in [(795, 200, 190, 150, -12), (1120, 130, 190, 150, -12),
                                  (1000, 560, 370, 230, -8)]:
        cv2.ellipse(m, ((cx, cy), (rx * 2, ry * 2), ang), 1.0, -1)
    return blur(m, 25)


# ------------------------------------------------------------------ stage 1
def scene(img, P):
    rng = np.random.default_rng(P['seed'] + 11)
    X, Y = grids(W, H)
    lin = s2l(img)

    # flash falloff centred on the face + vignette
    r2 = ((X / W - P['flash_cx']) / P['flash_rx']) ** 2 + ((Y / H - P['flash_cy']) / P['flash_ry']) ** 2
    flash = P['bg_floor'] + (1 - P['bg_floor']) / (1 + r2 ** (P['flash_pow'] / 2) * 1.0)
    rv2 = ((X / W - 0.5) / 0.62) ** 2 + ((Y / H - 0.5) / 0.66) ** 2
    vig = np.clip(1 - P['vignette'] * rv2, 0.05, 1)
    fill = np.ones((H, W), np.float32)
    for (bx, by, bsx, bsy, bamp) in P['blobs']:
        fill = fill * (1 + bamp * np.exp(-(((X - bx) / bsx) ** 2 + ((Y - by) / bsy) ** 2)))
    lin = lin * (P['gain'] * flash * vig * fill)[..., None]

    # faint long-exposure ghost (ambient light while the thing moved) -- only dim, blurred
    if P['ghost'] > 0:
        M = np.float32([[1.03, 0, P['ghost_dx']], [0, 1.03, P['ghost_dy']]])
        g = cv2.warpAffine(lin, M, (W, H), borderMode=cv2.BORDER_REFLECT)
        g = blur(g, P['ghost_blur'])
        lin = lin + P['ghost'] * g * (1 - protect_mask()[..., None] * 0.85)

    # bloom / halation from the hot spots (eyes, teeth glints)
    lum = lin @ np.array([0.25, 0.6, 0.15], np.float32)
    hot = np.maximum(lum - P['bloom_thr'], 0)
    if P['eye_boost']:
        # make the eyes properly huge, round and white: glow centres from the source
        eyes = np.zeros((H, W), np.float32)
        for (cx, cy, rr) in [(797, 197, 62), (1122, 125, 60)]:
            cv2.circle(eyes, (cx, cy), int(rr * P['eye_r']), 1.0, -1)
        eyes = blur(eyes, P['eye_soft'])
        hot = hot + eyes * P['eye_amp']
        lin = lin + (eyes * 1.5 * P['eye_boost'])[..., None] * np.float32([1.0, 1.0, 0.96])
    bloom = (P['bloom_w1'] * blur(hot, P['bloom_s1']) + P['bloom_w2'] * blur(hot, P['bloom_s2'])
             + P['bloom_w3'] * blur(hot, P['bloom_s3']))
    # lens dirt: smudgy modulation of the big glare
    dirt = lowfreq(rng, (H, W), 55)
    streak = lowfreq(rng, (H // 3, W // 3), 24)
    streak = cv2.resize(streak, (W, H), interpolation=cv2.INTER_CUBIC)
    dirtmap = np.clip(0.55 + 0.45 * dirt + 0.25 * streak, 0, 2.2) ** 1.5
    wide = blur(hot, 150) * 0.55 * P['dirt'] * dirtmap
    big = blur(hot, P['bloom_s3'] * 1.5) * dirtmap * P['dirt']
    glare = bloom + wide + 0.6 * big
    if P['smear'] > 0:
        L = int(P['smear_len']) | 1
        k = np.zeros((L, L), np.float32)
        c = L // 2
        a = np.deg2rad(P['smear_ang'])
        cv2.line(k, (int(c - c * np.cos(a)), int(c - c * np.sin(a))), (int(c + c * np.cos(a)), int(c + c * np.sin(a))), 1.0, 1, cv2.LINE_AA)
        k = blur(k, 2.0)
        k /= k.sum()
        glare = glare + P['smear'] * cv2.filter2D(hot, -1, k, borderType=cv2.BORDER_REFLECT) * (0.5 + 0.5 * np.clip(dirtmap, 0, 1.5))
    lin = lin + glare[..., None] * np.float32([1.0, 1.0, 0.97])
    if P['haze'] > 0:
        body = blur(np.clip(lin @ np.array([0.25, 0.6, 0.15], np.float32), 0, 1), P['haze_s'])
        lin = lin + (P['haze'] * body)[..., None] * np.float32(P['haze_tint'])

    # desaturate toward mono, keep a little chroma (more for reds = blood)
    ylin = lin @ np.array(P['mono_w'], np.float32)
    redness = np.clip((lin[..., 0] - lin[..., 1] * 1.6) / (lin[..., 0] + 1e-4), 0, 1)
    keep = P['keep_color'] + P['red_keep'] * redness
    lin = ylin[..., None] + (lin - ylin[..., None]) * keep[..., None]

    # tone: hard S-curve on gamma-encoded values, crushed blacks, blown highlights
    g = l2s(lin) ** P['pre_gamma']
    gl = g @ np.array([0.3, 0.59, 0.11], np.float32)
    # split tone
    t = np.clip(gl, 0, 1)[..., None]
    tint = np.float32(P['tint_sh']) * (1 - t) + np.float32(P['tint_hi']) * t
    g = g * tint
    x = (g - P['black']) / (P['white'] - P['black'])
    x = np.clip(x, 0, 1)
    k, m = P['contrast'], P['mid']
    s = 1 / (1 + np.exp(-k * 4.0 * (x - m)))
    s0, s1 = 1 / (1 + np.exp(k * 4.0 * m)), 1 / (1 + np.exp(-k * 4.0 * (1 - m)))
    g = np.clip((s - s0) / (s1 - s0), 0, 1).astype(np.float32)

    # lens smudge: streaky patches that soften and fog the image (never over the eyes / grin)
    if P['smudge'] > 0:
        r2 = np.random.default_rng(P['seed'] + 44)
        n = r2.standard_normal((H // 4, W // 4)).astype(np.float32)
        n = cv2.GaussianBlur(n, (0, 0), sigmaX=34, sigmaY=5)           # long streaks at quarter res
        n = cv2.resize(n, (W, H), interpolation=cv2.INTER_CUBIC)
        Mr = cv2.getRotationMatrix2D((W / 2, H / 2), -28, 1.0)
        n = cv2.warpAffine(n, Mr, (W, H), borderMode=cv2.BORDER_REFLECT)
        n = (n - n.mean()) / (n.std() + 1e-6)
        m = np.clip((n - 0.35) * 1.4, 0, 1)
        m = blur(m, 12) * (1 - protect_mask())
        m = (m * P['smudge'])[..., None]
        soft = blur(g, P['smudge_blur'])
        g = g * (1 - m) + (soft + P['smudge_veil'] * np.float32([0.9, 1.0, 1.0])) * m
        g = np.clip(g, 0, 1)

    # lateral chromatic aberration (R grows, B shrinks, radial)
    ca = P['ca']
    if ca > 0:
        cx, cy = W / 2, H * 0.45
        out = np.empty_like(g)
        for ch, sc in ((0, 1 + ca), (1, 1.0), (2, 1 - ca)):
            mx = (X - cx) / sc + cx
            my = (Y - cy) / sc + cy
            out[..., ch] = cv2.remap(g[..., ch], mx, my, cv2.INTER_CUBIC, borderMode=cv2.BORDER_REFLECT)
        g = out
    return np.clip(g, 0, 1)


# ------------------------------------------------------------------ stage 2
def bayer_codes():
    """find the cv2 demosaic code that inverts my RGGB mosaic"""
    ref = np.zeros((16, 16, 3), np.uint16)
    ref[...] = (50000, 30000, 10000)  # R,G,B
    mos = np.zeros((16, 16), np.uint16)
    mos[0::2, 0::2] = ref[0::2, 0::2, 0]
    mos[0::2, 1::2] = ref[0::2, 1::2, 1]
    mos[1::2, 0::2] = ref[1::2, 0::2, 1]
    mos[1::2, 1::2] = ref[1::2, 1::2, 2]
    best, bc = 1e18, None
    for code in (cv2.COLOR_BayerRG2RGB, cv2.COLOR_BayerBG2RGB, cv2.COLOR_BayerGR2RGB, cv2.COLOR_BayerGB2RGB):
        d = cv2.cvtColor(mos, code).astype(np.float64)
        err = np.abs(d[4:-4, 4:-4] - ref[4:-4, 4:-4]).mean()
        if err < best:
            best, bc = err, code
    return bc


def sensor(g, P):
    rng = np.random.default_rng(P['seed'] + 22)
    cw, ch = P['cap_w'], P['cap_h']
    sc = W / cw
    # lens softness + area sampling  (resolution loss happens FIRST)
    g = blur(g, P['lens_soft'] * sc)
    small = cv2.resize(g, (cw, ch), interpolation=cv2.INTER_AREA)
    lin = s2l(small)

    # sensor dust: soft dark discs (optical, so before noise)
    Xc, Yc = grids(cw, ch)
    dust = np.ones((ch, cw), np.float32)
    for _ in range(P['n_dust']):
        x, y = rng.uniform(0, cw), rng.uniform(0, ch)
        rad = rng.uniform(1.2, 4.5)
        a = rng.uniform(0.12, P['dust_a'])
        dust *= 1 - a * np.exp(-(((Xc - x) ** 2 + (Yc - y) ** 2) / (2 * rad ** 2))) ** 1.5
    lin = lin * dust[..., None]

    # Bayer mosaic (RGGB) + shot/read noise in linear light
    code = bayer_codes()
    mos = np.zeros((ch, cw), np.float32)
    mos[0::2, 0::2] = lin[0::2, 0::2, 0]
    mos[0::2, 1::2] = lin[0::2, 1::2, 1]
    mos[1::2, 0::2] = lin[1::2, 0::2, 1]
    mos[1::2, 1::2] = lin[1::2, 1::2, 2]
    sig = np.sqrt(P['iso_a'] * np.maximum(mos, 0) + P['iso_read'] ** 2)
    mos = mos + rng.standard_normal(mos.shape).astype(np.float32) * sig
    # row banding of cheap readout (very faint)
    mos += (rng.standard_normal((ch, 1)).astype(np.float32) * 0.0012)
    # hot pixels
    for _ in range(P['n_hot']):
        y, x = rng.integers(0, ch), rng.integers(0, cw)
        mos[y, x] += rng.uniform(0.15, 0.7)
    mos = mos + P['pedestal']
    m16 = np.clip(mos * 65535, 0, 65535).astype(np.uint16)
    rgb = cv2.cvtColor(m16, code).astype(np.float32) / 65535.0
    g = l2s(np.clip(rgb, 0, 1))

    # in-camera NR: smears chroma into blotches, waxes luma a touch
    ycc = cv2.cvtColor(g, cv2.COLOR_RGB2YCrCb)
    ycc[..., 1] = blur(ycc[..., 1], P['chroma_nr'])
    ycc[..., 2] = blur(ycc[..., 2], P['chroma_nr'])
    ycc[..., 0] = blur(ycc[..., 0], P['luma_nr'])
    g = np.clip(cv2.cvtColor(ycc, cv2.COLOR_YCrCb2RGB), 0, 1)
    # in-camera sharpening (halo is baked in before compression)
    g = unsharp_luma(g, P['cam_sharp'], P['cam_sharp_r'])
    return g


# ------------------------------------------------------------------ stage 3
def codec(g, P):
    rng = np.random.default_rng(P['seed'] + 33)
    a = jpeg(to8(g), P['q1'])                                   # gen 1 at capture res
    # gen 2: re-uploaded at a different size (misaligned block grid)
    mid = cv2.resize(a, (P['mid_w'], P['mid_h']), interpolation=cv2.INTER_CUBIC)
    if P['corrupt'] > 0:
        mid = corrupt_band(mid, P, rng)
    a = jpeg(mid, P['q2'])
    # viewer: upscale to 1920x1080 + sharpen, then dust/scratch flecks, then gen 3
    f = cv2.resize(a, (W, H), interpolation=cv2.INTER_CUBIC).astype(np.float32) / 255
    f = unsharp_luma(f, P['view_sharp'], P['view_sharp_r'])
    f = flecks(f, P, rng)
    # dither grain (kills banding of the dark gradients) -- luma-ish, tiny
    n = rng.standard_normal((H, W, 1)).astype(np.float32) * (P['grain'] / 255.0)
    n = n + rng.standard_normal((H, W, 3)).astype(np.float32) * (0.5 * P['grain'] / 255.0)
    f = np.clip(f + n, 0, 1)
    return jpeg(to8(f), P['q3'])


def corrupt_band(img, P, rng):
    """one chroma-plane tear through the dark/side zones (kept off eyes & grin)"""
    h, w = img.shape[:2]
    out = img.copy()
    ycc = cv2.cvtColor(img, cv2.COLOR_RGB2YCrCb)
    y0 = int(h * 0.80)
    y1 = y0 + 22
    sh = int(w * 0.035)
    ycc[y0:y1, :, 1:] = np.roll(ycc[y0:y1, :, 1:], sh, axis=1)
    out = cv2.cvtColor(ycc, cv2.COLOR_YCrCb2RGB)
    return out


def flecks(f, P, rng):
    """dust flecks + a few hairline scratches (post-sensor, from the print/scan/viewer)"""
    img = (f * 255).astype(np.float32)
    layer = np.zeros((H, W), np.float32)
    for _ in range(P['n_fleck']):
        x, y = rng.integers(0, W), rng.integers(0, H)
        r = rng.uniform(0.7, 2.2)
        v = rng.uniform(40, 150) * (1 if rng.random() < 0.7 else -0.8)
        cv2.circle(layer, (int(x), int(y)), int(max(1, round(r))), float(v), -1, cv2.LINE_AA)
    for _ in range(P['n_scratch']):
        x = rng.uniform(0, W)
        y0 = rng.uniform(0, H * 0.4)
        L = rng.uniform(150, 520)
        dx = rng.uniform(-14, 14)
        cv2.line(layer, (int(x), int(y0)), (int(x + dx), int(y0 + L)), float(rng.uniform(25, 70)), 1, cv2.LINE_AA)
    layer = blur(layer, 0.6)
    pm = protect_mask()
    layer *= (1 - 0.9 * pm)
    img = img + layer[..., None]
    return np.clip(img / 255.0, 0, 1)


# ------------------------------------------------------------------ main
def run(inp, outp, P):
    im = np.array(Image.open(inp).convert('RGB'), np.float32) / 255.0
    if im.shape[1] != W:
        im = cv2.resize(im, (W, H), interpolation=cv2.INTER_AREA)
    g = scene(im, P)
    g = sensor(g, P)
    out = codec(g, P)
    Image.fromarray(out).save(outp)
    return out


def parse_set(args):
    P2 = dict(P)
    for a in args:
        k, v = a.split('=', 1)
        try:
            val = json.loads(v)
        except Exception:
            val = v
        if isinstance(P2.get(k), tuple) and isinstance(val, list):
            val = tuple(val)
        P2[k] = val
    return P2


if __name__ == '__main__':
    argv = sys.argv[1:]
    if len(argv) < 2:
        print(__doc__)
        sys.exit(1)
    inp, outp = argv[0], argv[1]
    sets = []
    if '--set' in argv:
        i = argv.index('--set')
        sets = argv[i + 1:]
    run(inp, outp, parse_set(sets))
    print('wrote', outp)
