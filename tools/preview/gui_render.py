#!/usr/bin/env python3
"""Lay out and draw the exported Roblox GUI tree (G lines) over a background.

usage: gui_render.py ui.tsv out.png --size 1280x720 [--bg image.png] [--inset 58]

Supports UDim2 layout, AnchorPoint, UIScale, UIListLayout, UIGridLayout,
UIPadding, UIAspectRatioConstraint, UICorner, UIStroke, multi-stop
UIGradient colour and transparency, Rotation (children rotate with their
parent) and ClipsDescendants. Emoji are drawn as small word tags.
"""
import argparse, math, re
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
_font_cache = {}


def font(size):
    size = max(6, int(size))
    if size not in _font_cache:
        _font_cache[size] = ImageFont.truetype(FONT, size)
    return _font_cache[size]


def col(s):
    if not s:
        return None
    r, g, b = [float(x) for x in s.split(",")]
    return (r, g, b)


def udim(s):
    return [float(x) for x in s.split(",")]


EMOJI_WORDS = {
    "\U0001F3C6": "WIN", "\U0001F4AA": "PWR", "⚡": "SPD", "\U0001F381": "GIFT", "\U0001F3B0": "SPIN",
    "\U0001F98A": "PET", "\U0001F43E": "PET", "\U0001F95A": "EGG", "\U0001F465": "FRND", "\U0001F525": "FIRE",
    "⭐": "STAR", "\U0001F451": "KING", "\U0001F4B0": "$$", "\U0001F6D2": "SHOP", "\U0001F4D6": "BOOK",
    "⚙": "SET", "\U0001F977": "NINJ", "\U0001F392": "BAG", "⚔": "SWRD", "\U0001F4A8": "DASH",
    "⬆": "UP", "✨": "SPRK", "\U0001F512": "LOCK", "✔": "OK", "\U0001F5FB": "MTN", "\U0001F4DC": "SCRL",
    "\U0001F310": "WRLD", "\U0001F45F": "SHOE", "❤": "HP", "⏱": "TIME", "\U0001F340": "LUCK",
}
EMOJI = re.compile("[\U0001F000-\U0001FFFF☀-➿⬀-⯿⌀-⏿️]")


VIEWPORTS = {}


def viewport_image(node, w, h):
    """Ray traces what a ViewportFrame shows (see render.py)."""
    vp = VIEWPORTS.get(node.id)
    if not vp or w < 4 or h < 4:
        return None
    import render, types
    parts, _ = render.load(vp["tsv"], "vp%d" % node.id)
    if not parts:
        return None
    cam = vp["cam"]
    look = [cam[i] + vp["look"][i] * 10 for i in range(3)]
    args = types.SimpleNamespace(size="%dx%d" % (int(w), int(h)), top=None, cam=",".join(map(str, cam)),
                                 look=",".join(map(str, look)), fov=vp["fov"], shadows=False, signs=False, out=None,
                                 return_image=True, tag=None)
    return render.render(parts, ([], []), args)


def split_emoji(text):
    words = []
    for m in EMOJI.finditer(text):
        w = EMOJI_WORDS.get(m.group(0))
        if w:
            words.append(w)
    return EMOJI.sub("", text).strip(), words


class Node:
    def __init__(self, f):
        f = f + [""] * 30
        (self.tag, self.id, self.parent, self.cls, self.name, vis, pos, size, anchor, bg, bgt, text, ts, scaled, tc, tt, z, lo, rot,
         auto, ignore, disp, xalign, mods, clip, fontname) = f[:26]
        self.id, self.parent = int(self.id), int(self.parent)
        self.visible = vis == "true"
        self.pos, self.size = udim(pos), udim(size)
        self.anchor = [float(x) for x in anchor.split(",")]
        self.bg, self.bgt = col(bg), float(bgt or 0)
        self.text, self.ts, self.scaled = text, float(ts or 14), scaled == "true"
        self.tc, self.tt = col(tc), float(tt or 0)
        self.z, self.lo = float(z or 1), float(lo or 0)
        self.rot = float(rot or 0)
        self.auto = auto
        self.ignore, self.disp = ignore == "true", float(disp or 0)
        self.xalign = xalign or "Center"
        self.clip = clip == "true"
        self.mods = {}
        for m in (mods or "").split(";"):
            if "=" in m:
                k, v = m.split("=", 1)
                self.mods.setdefault(k, v)
        self.children = []


# ------------------------------------------------------------------ layout

def own_size(c, pw, ph, s):
    sw = c.size[0] * pw + c.size[1] * s
    sh = c.size[2] * ph + c.size[3] * s
    if "aspect" in c.mods:
        ratio = float(c.mods["aspect"]) or 1
        if sh > 0 and sw / sh > ratio:
            sw = sh * ratio
        elif sw > 0:
            sh = sw / ratio
    return sw, sh


TEXT_CLASSES = ("TextLabel", "TextButton", "TextBox")


def natural_w(c, s):
    """Width of a node with AutomaticSize X: its text, or its children."""
    w = c.size[1] * s
    pad = [0, 0, 0, 0]
    if "pad" in c.mods:
        pad = [float(v) * s for v in c.mods["pad"].split(",")]
    content = 0
    if c.cls in TEXT_CLASSES and c.text:
        txt = re.sub("<[^>]+>", "", c.text)
        plain, words = split_emoji(txt)
        f = font(c.ts * s)
        content = f.getlength(plain) + sum(f.getlength(wd) * 0.6 + 6 * s for wd in words)
    kids = [k for k in c.children if k.visible]
    widths = []
    for k in kids:
        kw = natural_w(k, s) if k.auto in ("X", "XY") else k.size[1] * s
        widths.append((k, kw * float(k.mods.get("scale", 1))))
    if "list" in c.mods and kids:
        d, padding = c.mods["list"].split(",")[0:2]
        if d == "Horizontal":
            content = max(content, sum(kw for _, kw in widths) + float(padding) * s * (len(kids) - 1))
        else:
            content = max(content, max(kw for _, kw in widths))
    elif kids:
        for k, kw in widths:
            if k.pos[0] == 0 and k.size[0] == 0:
                content = max(content, k.pos[1] * s + kw)
    return max(w, content + pad[0] + pad[1])


def auto_size(c, sw, sh, s):
    if c.auto in ("X", "XY"):
        sw = max(sw, natural_w(c, s))
    if c.auto in ("Y", "XY") and "list" in c.mods:
        kids = [k for k in c.children if k.visible]
        pad = float(c.mods["list"].split(",")[1]) * s
        tot = sum(k.size[3] * s * float(k.mods.get("scale", 1)) for k in kids) + pad * max(0, len(kids) - 1)
        sh = max(sh, tot)
    return sw, sh


def layout(node, x, y, w, h, s):
    node.rect = (x, y, w, h)
    node.s = s
    pad = [0, 0, 0, 0]
    if "pad" in node.mods:
        pad = [float(v) * s for v in node.mods["pad"].split(",")]
    cx, cy, cw, ch = x + pad[0], y + pad[2], w - pad[0] - pad[1], h - pad[2] - pad[3]
    kids = [c for c in node.children if c.visible]
    kids_sorted = sorted(kids, key=lambda c: (c.lo, c.id))
    if "grid" in node.mods:
        g = node.mods["grid"].split(",")
        cell = [float(v) for v in g[0:4]]
        padc = [float(v) for v in g[4:8]]
        align = g[8] if len(g) > 8 else "Left"
        cwid = cell[0] * cw + cell[1] * s
        chei = cell[2] * ch + cell[3] * s
        px_ = padc[0] * cw + padc[1] * s
        py_ = padc[2] * ch + padc[3] * s
        per = max(1, int((cw + px_ + 0.01) // (cwid + px_)))
        for i, c in enumerate(kids_sorted):
            row, colm = divmod(i, per)
            n_in_row = min(per, len(kids_sorted) - row * per)
            rowW = n_in_row * cwid + (n_in_row - 1) * px_
            ox = cx + (cw - rowW) / 2 if align == "Center" else cx
            k = float(c.mods.get("scale", 1))
            layout(c, ox + colm * (cwid + px_), cy + row * (chei + py_), cwid * k, chei * k, s * k)
        return
    if "list" in node.mods:
        d, padding, ha, va = node.mods["list"].split(",")
        padding = float(padding) * s
        sizes = []
        for c in kids_sorted:
            sw, sh = own_size(c, cw, ch, s)
            sw, sh = auto_size(c, sw, sh, s)
            sizes.append((sw, sh, float(c.mods.get("scale", 1))))
        if d == "Vertical":
            total = sum(sh * k for sw, sh, k in sizes) + padding * max(0, len(sizes) - 1)
            yy = cy + ((ch - total) / 2 if va == "Center" else (ch - total if va == "Bottom" else 0))
            for c, (sw, sh, k) in zip(kids_sorted, sizes):
                xx = cx + ((cw - sw * k) / 2 if ha == "Center" else (cw - sw * k if ha == "Right" else 0))
                layout(c, xx, yy, sw * k, sh * k, s * k)
                yy += sh * k + padding
        else:
            total = sum(sw * k for sw, sh, k in sizes) + padding * max(0, len(sizes) - 1)
            xx = cx + ((cw - total) / 2 if ha == "Center" else (cw - total if ha == "Right" else 0))
            for c, (sw, sh, k) in zip(kids_sorted, sizes):
                yy = cy + ((ch - sh * k) / 2 if va == "Center" else (ch - sh * k if va == "Bottom" else 0))
                layout(c, xx, yy, sw * k, sh * k, s * k)
                xx += sw * k + padding
        return
    for c in kids:
        sw, sh = own_size(c, cw, ch, s)
        sw, sh = auto_size(c, sw, sh, s)
        k = float(c.mods.get("scale", 1))
        px = cx + c.pos[0] * cw + c.pos[1] * s
        py = cy + c.pos[2] * ch + c.pos[3] * s
        layout(c, px - c.anchor[0] * sw * k, py - c.anchor[1] * sh * k, sw * k, sh * k, s * k)


# ------------------------------------------------------------------ drawing

def parse_grad(spec):
    parts = spec.split("/")
    stops = []
    for p in parts[0].split("|"):
        if ":" in p:
            t, c = p.split(":", 1)
            stops.append((float(t), [float(v) for v in c.split(",")]))
    rot = float(parts[1]) if len(parts) > 1 and parts[1] else 0
    tstops = []
    if len(parts) > 2 and parts[2]:
        for p in parts[2].split("|"):
            t, v = p.split(":")
            tstops.append((float(t), float(v)))
    return stops, rot, tstops


def interp(stops, t):
    ts = np.array([s[0] for s in stops])
    out = []
    for ch in range(len(stops[0][1]) if isinstance(stops[0][1], list) else 1):
        vs = np.array([s[1][ch] if isinstance(s[1], list) else s[1] for s in stops])
        out.append(np.interp(t, ts, vs))
    return out


IMAGE_FILES = {}  # "rbxassetid://1" -> local png (set with --image id=path)
_image_cache = {}


def load_image(key):
    path = IMAGE_FILES.get(key)
    if not path:
        return None
    if path not in _image_cache:
        _image_cache[path] = Image.open(path).convert("RGBA")
    return _image_cache[path]


def image_for(node, w, h, s):
    parts = node.mods["img"].split("|")
    src = load_image(parts[0])
    if src is None:
        return None
    ox, oy, sx, sy = [float(v) for v in parts[1].split(",")]
    color = [float(v) for v in parts[2].split(",")]
    transp = float(parts[3])
    scale_type = parts[4]
    tile = [float(v) for v in parts[5].split(",")]
    if sx > 0 and sy > 0:
        src = src.crop((int(ox), int(oy), int(ox + sx), int(oy + sy)))
    if scale_type == "Tile" and tile[0] > 0:
        tw, th = max(1, int(tile[0] * s)), max(1, int(tile[1] * s))
        t = src.resize((tw, th), Image.LANCZOS)
        pic = Image.new("RGBA", (w, h))
        for yy in range(0, h, th):
            for xx in range(0, w, tw):
                pic.paste(t, (xx, yy))
    else:
        pic = src.resize((w, h), Image.LANCZOS)
    a = np.array(pic).astype(float)
    a[..., 0:3] *= np.array(color)
    a[..., 3] *= (1 - transp)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def text_gradient(node, w, h):
    """RGB (h, w, 3) array of a text label's UIGradient, or None."""
    if "grad" not in node.mods:
        return None
    stops, rot, _ = parse_grad(node.mods["grad"])
    if not stops:
        return None
    ww, hh = max(1, int(round(w))), max(1, int(round(h)))
    ys, xs = np.mgrid[0:hh, 0:ww]
    a = math.radians(rot)
    dx, dy = math.cos(a), math.sin(a)
    ext = abs(ww * dx) + abs(hh * dy) or 1
    t = ((xs - ww / 2) * dx + (ys - hh / 2) * dy) / ext + 0.5
    return np.stack(interp(stops, t), -1)


def node_image(node, w, h, s):
    """The node's own look (no children) as an RGBA image of size w x h plus a margin."""
    margin = 0
    stroke = None
    if "stroke" in node.mods and node.cls != "TextLabel" and node.cls != "TextBox":
        st = node.mods["stroke"].split(",")
        th = float(st[0]) * s
        if float(st[4]) < 0.95 and th > 0.2:
            stroke = (th, tuple(int(float(v) * 255) for v in st[1:4]), float(st[4]))
            margin = int(math.ceil(th)) + 1
    W, H = int(round(w)) + 2 * margin, int(round(h)) + 2 * margin
    if W <= 0 or H <= 0 or W > 4000 or H > 4000:
        return None, 0
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = 0
    if "corner" in node.mods:
        cs, co = [float(v) for v in node.mods["corner"].split(",")]
        r = min(w, h) * cs + co * s
        r = max(0, min(r, min(w, h) / 2))
    is_text = node.cls in ("TextLabel", "TextButton", "TextBox")
    if node.bg and node.bgt < 0.999 and w >= 1 and h >= 1 and not (is_text and node.bgt >= 0.999):
        base = np.array(node.bg)
        ww, hh = int(round(w)), int(round(h))
        ys, xs = np.mgrid[0:hh, 0:ww]
        rgb = np.ones((hh, ww, 3)) * base
        alpha = np.ones((hh, ww)) * (1 - node.bgt)
        if "grad" in node.mods:
            stops, rot, tstops = parse_grad(node.mods["grad"])
            a = math.radians(rot)
            dx, dy = math.cos(a), math.sin(a)
            ext = abs(ww * dx) + abs(hh * dy) or 1
            t = ((xs - ww / 2) * dx + (ys - hh / 2) * dy) / ext + 0.5
            if stops:
                c = interp(stops, t)
                rgb = rgb * np.stack(c, -1)
            if tstops:
                ts = np.array([p[0] for p in tstops])
                vs = np.array([p[1] for p in tstops])
                alpha = alpha * (1 - np.interp(t, ts, vs))
        fill = Image.fromarray(np.dstack([np.clip(rgb * 255, 0, 255), np.clip(alpha * 255, 0, 255)]).astype(np.uint8), "RGBA")
        mask = Image.new("L", (ww * 2, hh * 2), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, ww * 2 - 1, hh * 2 - 1], radius=int(r * 2), fill=255)
        mask = mask.resize((ww, hh), Image.LANCZOS)
        fa = np.array(fill)
        fa[..., 3] = (fa[..., 3].astype(float) * np.array(mask) / 255).astype(np.uint8)
        img.alpha_composite(Image.fromarray(fa, "RGBA"), (margin, margin))
    if stroke:
        th, sc, stt = stroke
        d = ImageDraw.Draw(img)
        half = th / 2
        d.rounded_rectangle([margin - half, margin - half, margin + w + half - 1, margin + h + half - 1], radius=r + half,
                            outline=sc + (int(255 * (1 - stt)),), width=max(1, int(round(th))))
    if node.text and node.cls in ("TextLabel", "TextButton", "TextBox") and node.tt < 0.95:
        text, words = split_emoji(re.sub(r"<[^>]+>", "", node.text))  # RichText tags
        d = ImageDraw.Draw(img)
        if not text and words:
            size = min(h * 0.42, w * 0.9 / max(1, len(words[0])) * 1.6)
            f = font(size)
            d.text((margin + w / 2, margin + h / 2), words[0], font=f, fill=(40, 30, 20), anchor="mm")
        elif text:
            size = node.ts * s
            if node.scaled:
                size = h * 0.82
            f = font(size)
            while size > 6 and d.textlength(text, font=f) > w * 0.98:
                size -= 1
                f = font(size)
            tw = d.textlength(text, font=f)
            if node.xalign == "Left":
                tx = margin
            elif node.xalign == "Right":
                tx = margin + w - tw
            else:
                tx = margin + (w - tw) / 2
            sw_, sc = 0, (10, 8, 12)
            if "stroke" in node.mods:
                st = node.mods["stroke"].split(",")
                if float(st[4]) < 0.9:
                    sw_ = max(1, int(float(st[0]) * s * 0.9))
                    sc = tuple(int(float(v) * 255) for v in st[1:4])
            fill = tuple(int(v * 255) for v in (node.tc or (0, 0, 0))) + (int(255 * (1 - node.tt)),)
            grad = text_gradient(node, w, h) if node.bgt >= 0.999 else None
            if grad is None:
                d.text((tx, margin + h / 2), text, font=f, fill=fill, anchor="lm", stroke_width=sw_, stroke_fill=sc)
            else:
                # outline first, then the letters filled with the gradient
                d.text((tx, margin + h / 2), text, font=f, fill=sc + (255,), anchor="lm", stroke_width=sw_, stroke_fill=sc)
                mask = Image.new("L", img.size, 0)
                ImageDraw.Draw(mask).text((tx, margin + h / 2), text, font=f, fill=255, anchor="lm")
                gh, gw = grad.shape[0], grad.shape[1]
                rgb = np.zeros((img.height, img.width, 3))
                rgb[margin:margin + gh, margin:margin + gw] = grad
                rgb *= np.array(node.tc or (1, 1, 1))
                layer = np.dstack([np.clip(rgb * 255, 0, 255), np.array(mask).astype(float) * (1 - node.tt)]).astype(np.uint8)
                img.alpha_composite(Image.fromarray(layer, "RGBA"))
    if "img" in node.mods and w >= 1 and h >= 1:
        pic = image_for(node, int(round(w)), int(round(h)), s)
        if pic is not None:
            img.alpha_composite(pic, (margin, margin))
    if node.cls == "ViewportFrame":
        shown = viewport_image(node, w, h)
        if shown is not None:
            img.alpha_composite(shown, (margin, margin))
    return img, margin


def draw(canvas, node, parent_angle=0.0, parent_center=None, parent_origin=None, clip=None):
    """Children rotate with their parents: we track the parent's rotation and
    the point it rotates around."""
    if not node.visible:
        return
    x, y, w, h = node.rect
    cx, cy = x + w / 2, y + h / 2
    # position of this node's centre after the parents' rotation
    if parent_angle:
        px, py = parent_center
        a = math.radians(parent_angle)
        dx, dy = cx - px, cy - py
        cx, cy = px + dx * math.cos(a) - dy * math.sin(a), py + dx * math.sin(a) + dy * math.cos(a)
        # shift the layout so children follow
        ox, oy = cx - (x + w / 2), cy - (y + h / 2)
    else:
        ox = oy = 0
    angle = parent_angle + node.rot
    if node.cls != "ScreenGui":
        img, margin = node_image(node, w, h, node.s)
        if img is not None:
            if angle:
                img = img.rotate(-angle, resample=Image.BICUBIC, expand=True)
            px0 = int(round(cx - img.width / 2))
            py0 = int(round(cy - img.height / 2))
            if clip:
                cx0, cy0, cx1, cy1 = clip
                left, top = max(px0, int(cx0)), max(py0, int(cy0))
                right, bottom = min(px0 + img.width, int(cx1)), min(py0 + img.height, int(cy1))
                if right > left and bottom > top:
                    part = img.crop((left - px0, top - py0, right - px0, bottom - py0))
                    canvas.alpha_composite(part, (left, top))
            else:
                if px0 < canvas.width and py0 < canvas.height and px0 + img.width > 0 and py0 + img.height > 0:
                    tmp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
                    tmp.paste(img, (px0, py0))
                    canvas.alpha_composite(tmp)
    child_clip = clip
    if node.clip and not angle:
        r = (x + ox, y + oy, x + ox + w, y + oy + h)
        child_clip = r if not clip else (max(r[0], clip[0]), max(r[1], clip[1]), min(r[2], clip[2]), min(r[3], clip[3]))
    kids = sorted([c for c in node.children if c.visible], key=lambda c: (c.z, c.id))
    for c in kids:
        if ox or oy:
            shift(c, ox, oy)
        draw(canvas, c, angle, (cx, cy) if angle else None, None, child_clip)
        if ox or oy:
            shift(c, -ox, -oy)


def shift(node, dx, dy):
    x, y, w, h = node.rect
    node.rect = (x + dx, y + dy, w, h)
    for c in node.children:
        if hasattr(c, "rect"):
            shift(c, dx, dy)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv")
    ap.add_argument("out")
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--bg")
    ap.add_argument("--inset", type=float, default=58)
    ap.add_argument("--image", action="append", default=[], help="asset id=local png")
    a = ap.parse_args()
    for spec in a.image:
        k, v = spec.split("=", 1)
        IMAGE_FILES[k] = v
    W, H = [int(v) for v in a.size.split("x")]
    nodes = {}
    for line in open(a.tsv):
        f = line.rstrip("\n").split("\t")
        if f[0] == "VP":
            VIEWPORTS[int(f[1])] = dict(cam=[float(x) for x in f[2:5]], look=[float(x) for x in f[5:8]], fov=float(f[8]), tsv=a.tsv)
            continue
        if f[0] != "G":
            continue
        n = Node(f)
        nodes[n.id] = n
    roots = []
    for n in nodes.values():
        if n.parent and n.parent in nodes:
            nodes[n.parent].children.append(n)
        else:
            roots.append(n)
    if a.bg:
        img = Image.open(a.bg).convert("RGBA").resize((W, H))
    else:
        img = Image.new("RGBA", (W, H), (110, 160, 90, 255))
    ImageDraw.Draw(img).rectangle([0, 0, W, a.inset], fill=(0, 0, 0, 60))
    for root in sorted(roots, key=lambda r: r.disp):
        inset = 0 if root.ignore else a.inset
        layout(root, 0, inset, W, H - inset, 1)
        draw(img, root)
    img.convert("RGB").save(a.out)
    print("drew", a.out)


if __name__ == "__main__":
    main()
