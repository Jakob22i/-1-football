#!/usr/bin/env python3
"""Tiny ray tracer for the parts dumped by the mock engine.

usage:
  render.py parts.tsv out.png --cam x,y,z --look x,y,z [--fov 50] [--size 800x600]
  render.py parts.tsv out.png --top cx,cz,width [--size 900x900]
Options: --tag NAME (only parts with this tag), --shadows, --signs
"""
import argparse, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

EPS = 1e-4
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def load(path, tag=None):
    parts, signs = [], []
    surfaces, surface_nodes = [], {}
    for line in open(path):
        f = line.rstrip("\n").split("\t")
        if f and f[0].startswith("g") and f[0][1:].isdigit():
            surface_nodes.setdefault(f[0][1:], []).append(["G"] + f[1:])
            continue
        if f and f[0] == "S":
            if tag and f[1] != tag:
                continue
            v = [float(x) for x in f[3:18]]
            surfaces.append(dict(id=f[2], p=np.array(v[0:3]), M=np.array(v[3:12]).reshape(3, 3), size=np.array(v[12:15]),
                                 face=f[18], pps=float(f[19])))
            continue
        if not f or f[0] not in ("P", "B"):
            continue
        if tag and f[1] != tag:
            continue
        if f[0] == "P":
            v = [float(x) for x in f[3:18]]
            col = [float(x) for x in f[18].split(",")]
            ms = [float(x) for x in f[23].split(",")]
            parts.append(dict(name=f[2], p=np.array(v[0:3]), M=np.array(v[3:12]).reshape(3, 3), size=np.array(v[12:15]),
                              color=np.array(col), transp=float(f[19]), mat=f[20], shape=f[21], mesh=f[22],
                              mscale=np.array(ms), light=float(f[24]), refl=float(f[25]),
                              surf=f[26] if len(f) > 26 else "------",
                              sscale=float(f[27]) if len(f) > 27 and f[27] else 1.0))
        else:
            signs.append(dict(name=f[2], pos=np.array([float(x) for x in f[3:6]]), sx=float(f[6]), sy=float(f[7]),
                              ox=float(f[8]), oy=float(f[9]), maxd=float(f[10]),
                              bg=[float(x) for x in f[11].split(",")], text=f[12] if len(f) > 12 else ""))
    for sf in surfaces:
        sf["lines"] = surface_nodes.get(sf["id"], [])
    return parts, (signs, surfaces)


def surface_texture(sf):
    """Draws a SurfaceGui with gui_render; returns (RGBA array, face width, face height)."""
    import gui_render
    sx, sy, sz = sf["size"]
    fw, fh = {"Front": (sx, sy), "Back": (sx, sy), "Left": (sz, sy), "Right": (sz, sy), "Top": (sx, sz), "Bottom": (sx, sz)}[sf["face"]]
    tw, th = max(4, int(fw * sf["pps"])), max(4, int(fh * sf["pps"]))
    nodes = {}
    for f in sf["lines"]:
        n = gui_render.Node(f)
        nodes[n.id] = n
    roots = []
    for n in nodes.values():
        if n.parent and n.parent in nodes:
            nodes[n.parent].children.append(n)
        else:
            roots.append(n)
    img = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    # the SurfaceGui itself: a full-size frame holding the top-level items,
    # so each one keeps its own position and size
    gui = gui_render.Node(["G", "0", "-1", "Frame", "SurfaceGui", "true", "0,0,0,0", "1,0,1,0", "0,0", "0,0,0", "1"])
    gui.children = roots
    gui_render.layout(gui, 0, 0, tw, th, 1)
    gui_render.draw(img, gui)
    return np.asarray(img).astype(float) / 255.0


def geom(part):
    """Returns (kind, params) in local space."""
    s = part["size"] / 2
    mesh, shape = part["mesh"], part["shape"]
    if mesh == "Sphere":
        return "ellipsoid", s * part["mscale"]
    if mesh == "Head":
        return "ycyl", np.array([min(s[0], s[2]) * part["mscale"][0], s[1] * part["mscale"][1]])
    if mesh == "Cylinder":
        return "xcyl", np.array([s[0] * part["mscale"][0], min(s[1], s[2]) * part["mscale"][1]])
    if mesh == "Brick":
        return "box", s * part["mscale"]
    if shape == "Ball":
        r = min(s)
        return "ellipsoid", np.array([r, r, r])
    if shape == "Cylinder":
        return "xcyl", np.array([s[0], min(s[1], s[2])])
    if shape == "Wedge":
        return "wedge", s
    if shape == "CornerWedge":
        return "cwedge", s
    return "box", s


def bound_radius(kind, g):
    if kind in ("box", "wedge", "cwedge", "ellipsoid"):
        return float(np.linalg.norm(g))
    if kind == "xcyl" or kind == "ycyl":
        return float(math.hypot(g[0], g[1]))
    return float(np.linalg.norm(g))


def intersect(kind, g, o, d):
    """o, d: (N,3) local. Returns t (N,), normal (N,3)."""
    n = o.shape[0]
    t = np.full(n, np.inf)
    nrm = np.zeros((n, 3))
    with np.errstate(divide="ignore", invalid="ignore"):
        if kind in ("box", "wedge"):
            inv = 1.0 / np.where(np.abs(d) < 1e-12, 1e-12, d)
            t1 = (-g - o) * inv
            t2 = (g - o) * inv
            tn = np.minimum(t1, t2)
            tf = np.maximum(t1, t2)
            axis = np.argmax(tn, axis=1)
            tmin = tn[np.arange(n), axis]
            tmax = tf.min(axis=1)
            nl = np.zeros((n, 3))
            nl[np.arange(n), axis] = -np.sign(d[np.arange(n), axis])
            if kind == "wedge":
                hy, hz = g[1], g[2]
                pn = np.array([0.0, hz, -hy])
                pn = pn / np.linalg.norm(pn)
                f0 = o @ pn
                den = d @ pn
                tp = -f0 / np.where(np.abs(den) < 1e-12, 1e-12, den)
                enter = den < 0
                upd = enter & (tp > tmin)
                tmin = np.where(upd, tp, tmin)
                nl[upd] = pn
                ex = den > 0
                tmax = np.where(ex, np.minimum(tmax, tp), tmax)
                miss = (np.abs(den) < 1e-12) & (f0 > 0)
                tmax = np.where(miss, -np.inf, tmax)
            hit = (tmax >= tmin) & (tmin > EPS)
            t = np.where(hit, tmin, np.inf)
            nrm = nl
        elif kind == "cwedge":
            # Roblox CornerWedgePart: the tall corner is at (+x, +y, -z).
            a, h, c = g
            planes = [(np.array([0.0, -1, 0]), h), (np.array([1.0, 0, 0]), a), (np.array([0.0, 0, -1]), c),
                      (np.array([-h, a, 0.0]), 0.0), (np.array([0.0, c, h]), 0.0)]
            tmin = np.full(n, -np.inf)
            tmax = np.full(n, np.inf)
            nl = np.zeros((n, 3))
            for pn, b in planes:
                ln = np.linalg.norm(pn)
                pn, b = pn / ln, b / ln
                den = d @ pn
                num = b - o @ pn
                tp = num / np.where(np.abs(den) < 1e-12, 1e-12, den)
                enter = den < 0
                upd = enter & (tp > tmin)
                tmin = np.where(upd, tp, tmin)
                nl[upd] = pn
                tmax = np.where(den > 0, np.minimum(tmax, tp), tmax)
                tmax = np.where((np.abs(den) < 1e-12) & (num < 0), -np.inf, tmax)
            hit = (tmax >= tmin) & (tmin > EPS)
            t = np.where(hit, tmin, np.inf)
            nrm = nl
        elif kind == "ellipsoid":
            a = np.maximum(g, 1e-6)
            os_ = o / a
            ds = d / a
            A = (ds * ds).sum(1)
            B = 2 * (os_ * ds).sum(1)
            C = (os_ * os_).sum(1) - 1
            disc = B * B - 4 * A * C
            sq = np.sqrt(np.maximum(disc, 0))
            t0 = (-B - sq) / (2 * A)
            hit = (disc >= 0) & (t0 > EPS)
            t = np.where(hit, t0, np.inf)
            pt = o + d * t0[:, None]
            nrm = pt / (a * a)
        elif kind in ("xcyl", "ycyl"):
            hx, r = g[0], g[1]
            if kind == "xcyl":
                ax, p1, p2 = 0, 1, 2
            else:
                ax, p1, p2 = 1, 0, 2
                hx, r = g[1], g[0]
            A = d[:, p1] ** 2 + d[:, p2] ** 2
            B = 2 * (o[:, p1] * d[:, p1] + o[:, p2] * d[:, p2])
            C = o[:, p1] ** 2 + o[:, p2] ** 2 - r * r
            disc = B * B - 4 * A * C
            sq = np.sqrt(np.maximum(disc, 0))
            Az = np.where(A < 1e-12, 1e-12, A)
            ta = (-B - sq) / (2 * Az)
            tb = (-B + sq) / (2 * Az)
            par = A < 1e-12
            ta = np.where(par, np.where(C <= 0, -np.inf, np.inf), ta)
            tb = np.where(par, np.where(C <= 0, np.inf, -np.inf), tb)
            dax = np.where(np.abs(d[:, ax]) < 1e-12, 1e-12, d[:, ax])
            tx1 = (-hx - o[:, ax]) / dax
            tx2 = (hx - o[:, ax]) / dax
            txn = np.minimum(tx1, tx2)
            txf = np.maximum(tx1, tx2)
            tmin = np.maximum(ta, txn)
            tmax = np.minimum(tb, txf)
            hit = (disc >= 0) & (tmax >= tmin) & (tmin > EPS)
            t = np.where(hit, tmin, np.inf)
            pt = o + d * np.where(np.isfinite(tmin), tmin, 0)[:, None]
            capn = np.zeros((n, 3))
            capn[:, ax] = -np.sign(d[:, ax])
            sid = np.zeros((n, 3))
            sid[:, p1] = pt[:, p1]
            sid[:, p2] = pt[:, p2]
            nrm = np.where((txn > ta)[:, None], capn, sid)
    return t, nrm


FACES = {  # local normal axis/sign -> (surface index, u axis, v axis)
    (1, 1): (0, 0, 2), (1, -1): (1, 0, 2), (2, -1): (2, 0, 1), (2, 1): (3, 0, 1), (0, -1): (4, 2, 1), (0, 1): (5, 2, 1),
}


STUD_TILE = None       # RGBA float array of the stud texture tile (see --studs-tile)
STUD_TILE_STUDS = 4.0  # how many studs one tile covers
STUD_MULTIPLY = False  # True for an opaque tile, which multiplies the part colour
PX_SCALE = None        # pixels per stud at distance 1 (set by render)


def stud_texture(parts, pid, O, D, depth, shaded):
    """Roblox's Studs (and Inlet) surfaces: a round stud every stud, lit from
    the top left, with a soft shadow to the bottom right."""
    hitidx = np.nonzero(pid >= 0)[0]
    order = hitidx[np.argsort(pid[hitidx], kind="stable")]
    cuts = np.flatnonzero(np.diff(pid[order])) + 1
    for sel in np.split(order, cuts):
        if len(sel) == 0:
            continue
        part = parts[pid[sel[0]]]
        if "S" not in part["surf"] and "I" not in part["surf"]:
            continue
        hit = O[sel] + D[sel] * depth[sel][:, None]
        lp = (hit - part["p"]) @ part["M"]
        half = part["size"] / 2
        rel = np.abs(lp) / np.maximum(half, 1e-6)
        axis = np.argmax(rel, 1)
        sign = np.sign(lp[np.arange(len(lp)), axis])
        for (ax, sg), (fi, ua, va) in FACES.items():
            kind = part["surf"][fi]
            if kind not in "SI":
                continue
            on = (axis == ax) & (sign == sg)
            if part["shape"] != "Block" and fi != 0:
                pass
            if not on.any():
                continue
            u = lp[on, ua] + half[ua]
            v = lp[on, va] + half[va]
            if STUD_TILE is not None:
                th, tw = STUD_TILE.shape[:2]
                span = STUD_TILE_STUDS * part.get("sscale", 1.0)
                tx = ((u / span) % 1 * tw).astype(int) % tw
                ty = ((v / span) % 1 * th).astype(int) % th
                px = STUD_TILE[ty, tx]
                a = px[:, 3:4]
                # fade out far away and at grazing angles, like Roblox's mipmaps
                if PX_SCALE:
                    nw = part["M"][:, ax] * sg
                    graze = np.abs(D[sel[on]] @ nw)
                    per_stud = PX_SCALE * part.get("sscale", 1.0) / np.maximum(depth[sel[on]], 1e-3) * np.sqrt(np.maximum(graze, 0.02))
                    a = a * np.clip((per_stud - 3.0) / 5.0, 0, 1)[:, None]
                base_c = shaded[sel[on]]
                if STUD_MULTIPLY:
                    # an opaque colour map (images/FightRoad_Studs.png): the part's colour times the map
                    shaded[sel[on]] = base_c * (1 - a) + base_c * px[:, :3] * a
                    continue
                lum = np.clip(base_c.max(1, keepdims=True), 0.25, 1)
                shaded[sel[on]] = base_c * (1 - a) + px[:, :3] * lum * a
                continue
            fu = u - np.floor(u) - 0.5
            fv = v - np.floor(v) - 0.5
            r = np.sqrt(fu * fu + fv * fv) + 1e-9
            R = 0.29
            k = np.ones_like(r)
            light = -(fu + fv) / (r * 1.414)  # +1 on the top-left rim
            if kind == "I":
                light = -light
            ring = (r > R - 0.06) & (r < R + 0.02)
            k[ring] = 1 + 0.22 * light[ring]
            k[r < R - 0.06] = 1.05 if kind == "S" else 0.93
            sx, sy = fu - 0.07, fv - 0.07
            shadow = (np.sqrt(sx * sx + sy * sy) < R + 0.03) & (r >= R + 0.02)
            k[shadow] = 0.86 if kind == "S" else 1.0
            shaded[sel[on]] *= k[:, None]


def render(parts, signs, args):
    signs, surfaces = signs
    W, H = [int(x) for x in args.size.split("x")]
    if args.top:
        cx, cz, width = [float(x) for x in args.top.split(",")]
        scale = width / W
        xs = (np.arange(W) + 0.5 - W / 2) * scale
        ys = (np.arange(H) + 0.5 - H / 2) * scale
        # top view: screen right = -Z? we use screen right = +X world? choose: up = -X (so the road at +X is at the bottom)
        gx, gy = np.meshgrid(xs, ys)
        O = np.stack([cx + gy, np.full_like(gx, 500.0), cz - gx], -1).reshape(-1, 3)
        D = np.tile(np.array([0.0, -1.0, 0.0]), (W * H, 1))
        cam = None
    else:
        cam = np.array([float(x) for x in args.cam.split(",")])
        look = np.array([float(x) for x in args.look.split(",")])
        fwd = look - cam
        fwd /= np.linalg.norm(fwd)
        right = np.cross(fwd, [0, 1, 0])
        right /= np.linalg.norm(right)
        up = np.cross(right, fwd)
        f = 1 / math.tan(math.radians(args.fov) / 2)
        xs = (np.arange(W) + 0.5 - W / 2) / (H / 2)
        ys = -(np.arange(H) + 0.5 - H / 2) / (H / 2)
        gx, gy = np.meshgrid(xs, ys)
        D = (fwd[None, None] * f + right[None, None] * gx[..., None] + up[None, None] * gy[..., None]).reshape(-1, 3)
        D /= np.linalg.norm(D, axis=1)[:, None]
        O = np.tile(cam, (W * H, 1))
    N = W * H
    depth = np.full(N, np.inf)
    col = np.zeros((N, 3))
    pid = np.full(N, -1)
    sun = np.array([0.35, 1.0, 0.45])
    sun /= np.linalg.norm(sun)

    opaque, trans = [], []
    for i, part in enumerate(parts):
        if part["transp"] >= 0.97:
            continue
        kind, g = geom(part)
        part["kind"], part["g"], part["r"] = kind, g, bound_radius(kind, g)
        (trans if part["transp"] > 0.05 or part["mat"] == "ForceField" else opaque).append(i)

    def pixel_rect(part):
        c, r = part["p"], part["r"]
        if args.top:
            px = (-(c[2] - cz)) / scale + W / 2
            py = (c[0] - cx) / scale + H / 2
            rp = r / scale
        else:
            v = c - cam
            z = v @ fwd
            if z < -r:
                return None
            if z < 0.5:
                return (0, W, 0, H)
            px = (v @ right) / z * (H / 2) * f + W / 2
            py = -(v @ up) / z * (H / 2) * f + H / 2
            rp = r / z * (H / 2) * f * 1.3 + 2
        x0, x1 = int(max(0, px - rp)), int(min(W, px + rp + 1))
        y0, y1 = int(max(0, py - rp)), int(min(H, py + rp + 1))
        if x0 >= x1 or y0 >= y1:
            return None
        return (x0, x1, y0, y1)

    def trace(part, idx):
        rect = pixel_rect(part)
        if rect is None:
            return None, None, None
        x0, x1, y0, y1 = rect
        yy, xx = np.mgrid[y0:y1, x0:x1]
        sel = (yy * W + xx).ravel()
        M = part["M"]
        o = (O[sel] - part["p"]) @ M
        d = D[sel] @ M
        t, nl = intersect(part["kind"], part["g"], o, d)
        return sel, t, nl

    normals = np.zeros((N, 3))
    for i in opaque:
        part = parts[i]
        sel, t, nl = trace(part, i)
        if sel is None:
            continue
        closer = t < depth[sel]
        if not closer.any():
            continue
        s = sel[closer]
        depth[s] = t[closer]
        pid[s] = i
        nw = nl[closer] @ part["M"].T
        nw /= np.maximum(np.linalg.norm(nw, axis=1)[:, None], 1e-9)
        normals[s] = nw

    # sky
    skytop = np.array([0.45, 0.68, 0.95])
    skybot = np.array([0.82, 0.9, 0.98])
    if cam is not None:
        tsky = np.clip(D[:, 1] * 2 + 0.3, 0, 1)[:, None]
        col[:] = skybot * (1 - tsky) + skytop * tsky
    else:
        col[:] = np.array([0.25, 0.45, 0.25])

    hitm = pid >= 0
    base = np.array([parts[i]["color"] if i >= 0 else [0, 0, 0] for i in pid])
    mats = np.array([parts[i]["mat"] if i >= 0 else "" for i in pid])
    nw = normals
    if cam is not None:
        facing = (nw * -D).sum(1) < 0
        nw = np.where(facing[:, None], -nw, nw)
    diff = np.clip(nw @ sun, 0, 1)
    shade = 0.52 + 0.55 * diff
    if args.shadows:
        P = O + D * np.where(hitm, depth, 0)[:, None] + nw * 0.02
        lit = np.ones(N, bool)
        idxs = np.nonzero(hitm)[0]
        for i in opaque:
            part = parts[i]
            if part["mat"] in ("Glass", "ForceField") or part["transp"] > 0.3:
                continue
            c, r = part["p"], part["r"]
            v = c - P[idxs]
            proj = v @ sun
            dist2 = (v * v).sum(1) - proj * proj
            cand = (proj > -r) & (dist2 < r * r) & lit[idxs]
            if not cand.any():
                continue
            ci = idxs[cand]
            o = (P[ci] - part["p"]) @ part["M"]
            d = np.tile(sun, (len(ci), 1)) @ part["M"]
            t, _ = intersect(part["kind"], part["g"], o, d)
            blocked = np.isfinite(t)
            lit[ci[blocked]] = False
        shade = np.where(lit, shade, 0.5)
    shaded = base * shade[:, None]
    global PX_SCALE
    PX_SCALE = (H / 2) * f if cam is not None else None
    stud_texture(parts, pid, O, D, depth, shaded)
    # SurfaceGuis painted onto their faces.
    for sf in surfaces:
        match = [i for i in opaque if np.allclose(parts[i]["p"], sf["p"], atol=1e-3) and np.allclose(parts[i]["size"], sf["size"], atol=1e-3)]
        if not match:
            continue
        sel = np.nonzero(pid == match[0])[0]
        if len(sel) == 0:
            continue
        tex = surface_texture(sf)
        th, tw = tex.shape[0], tex.shape[1]
        hit = O[sel] + D[sel] * depth[sel][:, None]
        lx, ly, lz = ((hit - sf["p"]) @ sf["M"]).T
        sx, sy, sz = sf["size"]
        face = sf["face"]
        if face == "Front":
            on, u, v = lz < -sz / 2 + 0.03, (sx / 2 - lx) / sx, (sy / 2 - ly) / sy
        elif face == "Back":
            on, u, v = lz > sz / 2 - 0.03, (lx + sx / 2) / sx, (sy / 2 - ly) / sy
        elif face == "Right":
            on, u, v = lx > sx / 2 - 0.03, (sz / 2 - lz) / sz, (sy / 2 - ly) / sy
        elif face == "Left":
            on, u, v = lx < -sx / 2 + 0.03, (lz + sz / 2) / sz, (sy / 2 - ly) / sy
        else:
            on, u, v = ly > sy / 2 - 0.03, (lx + sx / 2) / sx, (lz + sz / 2) / sz
        if not on.any():
            continue
        s2 = sel[on]
        tx = np.clip((u[on] * tw).astype(int), 0, tw - 1)
        ty = np.clip((v[on] * th).astype(int), 0, th - 1)
        px = tex[ty, tx]
        a = px[:, 3:4]
        light = 0.85 + 0.15 * shade[s2][:, None]
        shaded[s2] = shaded[s2] * (1 - a) + px[:, :3] * light * a
    neon = mats == "Neon"
    shaded[neon] = np.clip(base[neon] * 1.25 + 0.1, 0, 1)
    glass = mats == "Glass"
    shaded[glass] = shaded[glass] * 0.7 + 0.3 * np.array([0.8, 0.9, 1.0])
    col[hitm] = shaded[hitm]

    # outlines where the part changes
    idimg = pid.reshape(H, W)
    dimg = depth.reshape(H, W)
    edge = np.zeros((H, W), bool)
    edge[:, :-1] |= (idimg[:, :-1] != idimg[:, 1:]) & (np.abs(dimg[:, :-1] - dimg[:, 1:]) > 0.05)
    edge[:-1, :] |= (idimg[:-1, :] != idimg[1:, :]) & (np.abs(dimg[:-1, :] - dimg[1:, :]) > 0.05)
    img = col.reshape(H, W, 3)
    img[edge] *= 0.72

    # transparent parts, far to near
    if trans:
        def dist(i):
            return np.linalg.norm(parts[i]["p"] - (cam if cam is not None else parts[i]["p"] + [0, 500, 0]))
        flat = img.reshape(-1, 3)
        for i in sorted(trans, key=dist, reverse=True):
            part = parts[i]
            sel, t, nl = trace(part, i)
            if sel is None:
                continue
            ok = t < depth[sel]
            if not ok.any():
                continue
            s = sel[ok]
            a = 1 - part["transp"]
            if part["mat"] == "ForceField":
                a = 0.25
            if part["mat"] == "Neon":
                a = min(1, a * 1.2)
            flat[s] = flat[s] * (1 - a) + part["color"] * a
        img = flat.reshape(H, W, 3)

    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    if getattr(args, "return_image", False):
        # for viewports inside the screen GUI: transparent where nothing was hit
        alpha = (pid >= 0).reshape(H, W).astype(np.uint8) * 255
        rgba = out.convert("RGBA")
        rgba.putalpha(Image.fromarray(alpha))
        return rgba
    if args.signs and signs:
        draw = ImageDraw.Draw(out)
        for sg in signs:
            if cam is None:
                px = (-(sg["pos"][2] - cz)) / scale + W / 2
                py = (sg["pos"][0] - cx) / scale + H / 2
                pw = max(sg["sx"] / scale, 6)
                ph = max(sg["sy"] / scale, 4)
            else:
                v = sg["pos"] - cam
                z = v @ fwd
                if z < 1 or np.linalg.norm(v) > sg["maxd"]:
                    continue
                px = (v @ right) / z * (H / 2) * f + W / 2
                py = -(v @ up) / z * (H / 2) * f + H / 2
                pw = sg["sx"] / z * (H / 2) * f + sg["ox"]
                ph = sg["sy"] / z * (H / 2) * f + sg["oy"]
            if pw < 3:
                continue
            bg = tuple(int(c * 255) for c in sg["bg"])
            draw.rounded_rectangle([px - pw / 2, py - ph / 2, px + pw / 2, py + ph / 2], radius=max(2, ph * 0.15), fill=bg,
                                   outline=(30, 35, 80), width=max(1, int(ph * 0.04)))
            text = sg["text"].split(" | ")[0][:40]
            fs = max(6, int(ph * 0.28))
            try:
                font = ImageFont.truetype(FONT, fs)
            except Exception:
                font = None
            draw.text((px, py - ph * 0.18), text, fill=(255, 255, 255), font=font, anchor="mm", stroke_width=max(1, fs // 8),
                      stroke_fill=(30, 35, 80))
    out.save(args.out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv")
    ap.add_argument("out")
    ap.add_argument("--cam")
    ap.add_argument("--look")
    ap.add_argument("--fov", type=float, default=50)
    ap.add_argument("--size", default="800x600")
    ap.add_argument("--top")
    ap.add_argument("--tag")
    ap.add_argument("--shadows", action="store_true")
    ap.add_argument("--signs", action="store_true")
    ap.add_argument("--ss", type=int, default=1, help="supersample (2 = render 2x and scale down)")
    ap.add_argument("--studs-tile", help="PNG tile for Studs faces (4 studs wide) instead of round studs")
    args = ap.parse_args()
    if args.studs_tile:
        global STUD_TILE, STUD_MULTIPLY
        STUD_TILE = np.asarray(Image.open(args.studs_tile).convert("RGBA"), float) / 255
        STUD_MULTIPLY = bool(STUD_TILE[..., 3].min() > 0.99)
    if args.ss > 1:
        w, h = [int(x) for x in args.size.split("x")]
        final, args.size = args.out, f"{w * args.ss}x{h * args.ss}"
        args.out = final + ".big.png"
        parts, signs = load(args.tsv, args.tag)
        render(parts, signs, args)
        Image.open(args.out).resize((w, h), Image.LANCZOS).save(final)
        import os
        os.remove(args.out)
        print("rendered", final, len(parts), "parts")
        return
    parts, signs = load(args.tsv, args.tag)
    render(parts, signs, args)
    print("rendered", args.out, len(parts), "parts")


if __name__ == "__main__":
    main()
