"""Fitted clothes with PixelLab edit-images-v2, per body type.

Every frame a garment needs (idle x8, walk x4 per direction, sitting x3 for SE/NE) is cut to the
64x64 window the garment lives in (top or bottom half of the body) and sent in groups of up to 16
frames per call; frames of the same direction share a call so idle and walk match. Walk and sit
frames of W/SW/NW are mirrors of E/SE/NE (the body frames are exact mirrors there); idle poses are
not, so all 8 idle frames are generated.

  python make_clothes.py --generate GARMENT BODY [--groups 0,1,2] [--seed N]   # -> clothes_gen/
  python make_clothes.py --build GARMENT BODY                                    # sprites in Avatar/
  python make_clothes.py --preview GARMENT
"""
import base64
import io
import json
import os
import sys
import time

import requests
from PIL import Image, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
AV = os.path.join(ROOT, "..", "frontend", "assets", "images", "OCTOPLAYER", "Avatar")
GEN = os.path.join(HERE, "clothes_gen")
API = "https://api.pixellab.ai/v2"
SKIN = (252, 213, 181)

# Crop windows (y0) of the 64x128 sprite per slot: 64 rows each.
WINDOW = {"top": 36, "bottom": 62}
CARDINAL = {1: "S", 2: "SE", 3: "E", 4: "NE", 5: "N", 6: "NW", 7: "W", 8: "SW"}
MIRROR_OF = {6: 4, 7: 3, 8: 2}

# Frame keys: ("idle", d), ("walk", d, n), ("sit", d, n). Groups = one PixelLab call each.
GROUPS = [
    [("idle", 1), ("idle", 2), ("idle", 8)] + [("walk", d, n) for d in (1, 2) for n in range(1, 5)]
    + [("sit", 2, n) for n in range(1, 4)],
    [("idle", 3), ("idle", 4), ("idle", 6), ("idle", 7)] + [("walk", d, n) for d in (3, 4) for n in range(1, 5)]
    + [("sit", 4, n) for n in range(1, 4)],
    [("idle", 5)] + [("walk", 5, n) for n in range(1, 5)],
]

GARMENTS = {
    "tshirt": dict(slot="top", label="Polera", audience="neutral",
                   prompt="a plain fitted short-sleeve crew-neck t-shirt, light blue"),
    "tank": dict(slot="top", label="Musculosa", audience="neutral",
                 prompt="a plain fitted sleeveless tank top with bare arms and shoulders, light blue"),
    "longsleeve": dict(slot="top", label="Manga Larga", audience="neutral",
                       prompt="a plain fitted long-sleeve knit sweater covering the arms down to the wrists, light blue"),
    "dress_shirt": dict(slot="top", label="Camisa", audience="neutral",
                        prompt="a collared button-up dress shirt with long sleeves and a button placket, light blue"),
    "sweatpants": dict(slot="bottom", label="Pantalón de Buzo", audience="neutral",
                       prompt="comfortable jogger sweatpants with an elastic waistband and cuffed ankles, light blue"),
    "leggings": dict(slot="bottom", label="Calzas", audience="neutral",
                     prompt="tight fitted leggings down to the ankles, light blue"),
    "shorts": dict(slot="bottom", label="Shorts", audience="neutral",
                   prompt="plain casual shorts ending above the knees with bare legs below, light blue"),
}


def _key():
    cwd = os.getcwd()
    os.chdir(ROOT)
    try:
        sys.path.insert(0, ROOT)
        from pixellab_service import load_pixellab_key
        return load_pixellab_key()
    finally:
        os.chdir(cwd)


def _b64(img):
    buf = io.BytesIO()
    img.convert("RGBA").save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def _decode(s):
    s = s["base64"] if isinstance(s, dict) else s
    s = s.split(",", 1)[-1]
    return Image.open(io.BytesIO(base64.b64decode(s + "=" * (-len(s) % 4)))).convert("RGBA")


def _load(path):
    p = os.path.join(AV, path)
    return Image.open(p).convert("RGBA") if os.path.exists(p) else None


def _tint(im, rgb):
    r, g, b, a = im.split()
    return Image.merge("RGBA", (r.point(lambda v: v * rgb[0] // 255), g.point(lambda v: v * rgb[1] // 255),
                                b.point(lambda v: v * rgb[2] // 255), a))


def body_paths(key, body):
    """Skin layers of a frame, back to front: [backleg], body, hands."""
    kind, d = key[0], key[1]
    if kind == "idle":
        return [f"body/{body}{d}.png", f"body/{body}_hands{d}.png"]
    if kind == "walk":
        return [f"body/{body}{d}_walk_f{key[2]}.png", f"body/{body}{d}_walk_hands_f{key[2]}.png"]
    n = key[2]
    back = [f"body/{body}{d}_sitting_f3_backleg.png"] if d in (4, 6) and n == 3 else []
    return back + [f"body/{body}{d}_sitting_f{n}.png", f"body/{body}{d}_sitting_hands_f{n}.png"]


def other_clothes(key, slot):
    """Neutral clothes on the other half so PixelLab only dresses the requested one: jeans under a
    top, the jacket over a bottom (both tinted far from the requested colours)."""
    kind, d = key[0], key[1]
    folder, style, rgb = ("bottoms", "jeans", (40, 40, 48)) if slot == "top" else ("tops", "jacket", (40, 40, 48))
    if kind == "sit":
        path = f"{folder}/{style}_{CARDINAL[d]}_sit{key[2]}.png"
    else:
        path = f"{folder}/{style}{d}{'' if kind == 'idle' else f'_walk_f{key[2]}'}.png"
    im = _load(path)
    return _tint(im, rgb) if im else None


def frame_input(key, body, slot):
    canvas = Image.new("RGBA", (64, 128))
    layers = [_load(p) for p in body_paths(key, body)]
    # draw order like the game: body, bottoms, hands, tops
    if len(layers) == 3:  # sitting back leg, behind everything
        canvas.alpha_composite(_tint(layers[0], SKIN))
    canvas.alpha_composite(_tint(layers[-2], SKIN))
    other = other_clothes(key, slot)
    if other and slot == "top":
        canvas.alpha_composite(other)
    if layers[-1]:
        canvas.alpha_composite(_tint(layers[-1], SKIN))
    if other and slot == "bottom":
        canvas.alpha_composite(other)
    y0 = WINDOW[slot]
    return canvas.crop((0, y0, 64, y0 + 64))


def _name(key):
    return "_".join(str(k) for k in key)


def wait_job(job, headers):
    """Polls a background job until done; network drops are retried (the job keeps running and is
    already paid for), so a flaky connection never loses a result."""
    failures = 0
    while True:
        time.sleep(8)
        try:
            j = requests.get(f"{API}/background-jobs/{job}", headers=headers, timeout=30).json()
            failures = 0
        except requests.RequestException as e:
            failures += 1
            if failures > 60:
                raise RuntimeError(f"job {job}: no connection for ~10 min ({e})")
            continue
        if j.get("status") == "completed":
            return (j.get("last_response") or {}).get("images") or []
        if j.get("status") == "failed":
            raise RuntimeError(json.dumps(j)[:500])


def recover(job, garment, body, group):
    """Saves the result of an already submitted job (e.g. after a dropped connection)."""
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    keys = GROUPS[group]
    images = wait_job(job, headers)
    print(f"{garment}/{body} group {group}: recovered {len(images)} of {len(keys)} frames")
    for k, s in zip(keys, images):
        _decode(s).save(os.path.join(GEN, f"{garment}_{body}_{_name(k)}.png"))


def generate(garment, body, groups=None, seed=None):
    spec = GARMENTS[garment]
    os.makedirs(GEN, exist_ok=True)
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    for gi in groups if groups is not None else range(len(GROUPS)):
        keys = GROUPS[gi]
        frames = [frame_input(k, body, spec["slot"]) for k in keys]
        for k, im in zip(keys, frames):
            im.save(os.path.join(GEN, f"_input_{garment}_{body}_{_name(k)}.png"))
        payload = {
            "method": "edit_with_text",
            "edit_images": [{"image": _b64(im), "width": 64, "height": 64} for im in frames],
            "image_size": {"width": 64, "height": 64},
            "description": f"dress the character in {spec['prompt']}; keep the body, pose and every other "
                           "piece of clothing exactly the same",
            "no_background": True,
            "seed": seed if seed is not None else 42,
        }
        r = requests.post(f"{API}/edit-images-v2", headers=headers, json=payload, timeout=60)
        if r.status_code not in (200, 202):
            raise RuntimeError(f"{r.status_code} {r.text[:500]}")
        job = r.json().get("background_job_id")
        print(f"{garment}/{body} group {gi}: job {job}", flush=True)
        images = wait_job(job, headers)
        print(f"{garment}/{body} group {gi}: got {len(images)} of {len(keys)} frames")
        for k, s in zip(keys, images):
            _decode(s).save(os.path.join(GEN, f"{garment}_{body}_{_name(k)}.png"))


def _lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def _shift(im, dx, dy):
    out = Image.new("RGBA", im.size)
    out.paste(im, (dx, dy))
    return out


def align(gen, inp):
    """PixelLab may move the figure a few pixels: match silhouettes (clothes barely change them)."""
    ga, ia = gen.split()[3].load(), inp.split()[3].load()
    w, h = gen.size
    best = None
    for dy in range(-3, 4):
        for dx in range(-6, 7):
            miss = 0
            for y in range(h):
                for x in range(w):
                    sx, sy = x - dx, y - dy
                    g = ga[sx, sy] > 128 if 0 <= sx < w and 0 <= sy < h else False
                    miss += g != (ia[x, y] > 128)
            if best is None or miss < best[0]:
                best = (miss, dx, dy)
    return _shift(gen, best[1], best[2])


def _warm_skin(p):
    r, g, b = p[:3]
    return r > g + 12 and g > b and r > 120


def isolate(gen, inp, slot="top"):
    """Garment = pixels PixelLab changed that are not skin (the new garment is never skin-toned). For
    bottoms, dark pixels where the input had the dark neutral jacket are that jacket redrawn, not the
    new garment (raise_waist covers that area afterwards)."""
    gen = align(gen, inp)
    gp, ip = gen.load(), inp.load()
    mask = set()
    for y in range(gen.height):
        for x in range(gen.width):
            g, i = gp[x, y], ip[x, y]
            if g[3] < 128 or _warm_skin(g):
                continue
            dist = max(abs(g[c] - i[c]) for c in range(3)) if i[3] else 255
            other = i[3] and _lum(i) < 60 and max(i[:3]) - min(i[:3]) < 15
            if slot == "bottom" and other and _lum(g) < 80:
                continue
            if dist >= 40:
                mask.add((x, y))
    # PixelLab sometimes adds neutral underwear under bottoms on the bare body: when the garment is
    # clearly coloured (as every prompt asks), drop its gray, unsaturated non-outline pixels.
    sat = lambda p: max(p[:3]) - min(p[:3])
    sats = sorted(sat(gp[p]) for p in mask)
    if slot == "bottom" and sats and sats[len(sats) // 2] > 60:
        mask = {p for p in mask if sat(gp[p]) >= 20 or _lum(gp[p]) < 25}
    # drop specks: a garment is one or a few big pieces
    comps, seen = [], set()
    for p in mask:
        if p in seen:
            continue
        stack, comp = [p], []
        seen.add(p)
        while stack:
            q = stack.pop()
            comp.append(q)
            for n in ((q[0] + 1, q[1]), (q[0] - 1, q[1]), (q[0], q[1] + 1), (q[0], q[1] - 1)):
                if n in mask and n not in seen:
                    seen.add(n)
                    stack.append(n)
        comps.append(comp)
    keep = set()
    for c in comps:
        if len(c) >= 8:
            keep |= set(c)
    return gen, keep


def to_gray(gen, mask, median=175):
    """Light grays (median ~175) so the chosen colour shows as itself under the modulate tint, with a
    selective outline: dark rim pixels become a darker shade of their neighbours."""
    gp = gen.load()
    lums = sorted(_lum(gp[p]) for p in mask)
    mid = max(lums[len(lums) // 2], 1) if lums else 1
    gray = {p: min(240, round(_lum(gp[p]) * median / mid)) for p in mask}
    rim = {p for p in mask if any(q not in mask for q in ((p[0] + 1, p[1]), (p[0] - 1, p[1]),
                                                          (p[0], p[1] + 1), (p[0], p[1] - 1)))}
    out = Image.new("RGBA", gen.size)
    op = out.load()
    for (x, y), v in gray.items():
        if (x, y) in rim and _lum(gp[x, y]) < 45:
            inner = [gray[q] for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)) if q in gray and q not in rim]
            v = max(45, round(0.45 * (sum(inner) / len(inner) if inner else median)))
        op[x, y] = (v, v, v, 255)
    return out


def _jeans_path(key):
    kind, d = key[0], key[1]
    if kind == "sit":
        return f"bottoms/jeans_{CARDINAL[d]}_sit{key[2]}.png"
    return f"bottoms/jeans{d}{'' if kind == 'idle' else f'_walk_f{key[2]}'}.png"


def raise_waist(full, key):
    """Bottoms were generated under the jacket, which is longer than the new tops, so PixelLab started
    them at the jacket's hem. The shipped jeans reach the real waist in every frame: fill the jeans'
    area above each column's top garment pixel with that pixel's gray (the waistband)."""
    jeans = _load(_jeans_path(key))
    if jeans is None:
        return full
    jp, fp = jeans.load(), full.load()
    lit_all = sorted(fp[x, y][0] for y in range(128) for x in range(64) if fp[x, y][3] and fp[x, y][0] >= 90)
    waist_tone = lit_all[len(lit_all) // 2] if lit_all else 175
    for x in range(64):
        tops = [y for y in range(128) if fp[x, y][3]]
        jeans_rows = [y for y in range(128) if jp[x, y][3]]
        if not tops or not jeans_rows:
            continue
        y_top = tops[0]
        # waistband tone: the column's first garment pixels, skipping outline and deep shadow
        lit = [fp[x, y][0] for y in tops[:5] if fp[x, y][0] >= 90]
        band = (sorted(lit)[len(lit) // 2] if lit else waist_tone,) * 3
        for y in range(jeans_rows[0], y_top):
            if jp[x, y][3]:
                outline = _lum(jp[x, y]) < 12
                v = max(45, round(band[0] * 0.45)) if outline else band[0]
                fp[x, y] = (v, v, v, 255)
    return full


def _out_names(garment, body, key):
    """Sprite paths for a frame, matching the loader in modular_avatar_component.dart."""
    kind, d = key[0], key[1]
    stem = f"{garment}_{body}"
    if kind == "idle":
        return f"{stem}{d}.png"
    if kind == "walk":
        return f"{stem}{d}_walk_f{key[2]}.png"
    return f"{stem}_{CARDINAL[d]}_sit{key[2]}.png"


def build(garment, body):
    spec = GARMENTS[garment]
    slot = spec["slot"]
    folder = {"top": "tops", "bottom": "bottoms"}[slot]
    y0 = WINDOW[slot]
    sprites, backlegs = {}, {}
    for group in GROUPS:
        for key in group:
            n = _name(key)
            gen = Image.open(os.path.join(GEN, f"{garment}_{body}_{n}.png")).convert("RGBA")
            inp = Image.open(os.path.join(GEN, f"_input_{garment}_{body}_{n}.png")).convert("RGBA")
            gen, mask = isolate(gen, inp, slot)
            crop = to_gray(gen, mask)
            full = Image.new("RGBA", (64, 128))
            full.alpha_composite(crop, (0, y0))
            if slot == "bottom":
                full = raise_waist(full, key)
            if slot == "bottom" and key[0] == "sit" and key[1] == 4 and key[2] == 3:
                # the back leg is drawn behind the furniture: split the garment over it
                backleg = _load(f"body/{body}4_sitting_f3_backleg.png")
                main = _load(f"body/{body}4_sitting_f3.png")
                bp, mp, fp = backleg.load(), main.load(), full.load()
                piece = Image.new("RGBA", full.size)
                pp = piece.load()
                for y in range(128):
                    for x in range(64):
                        if fp[x, y][3] and bp[x, y][3] and not mp[x, y][3]:
                            pp[x, y], fp[x, y] = fp[x, y], (0, 0, 0, 0)
                if piece.getbbox():
                    backlegs[4] = piece
            sprites[key] = full
    # W / SW / NW walk and sit frames mirror E / SE / NE
    for key in list(sprites):
        if key[0] in ("walk", "sit") and key[1] in (2, 3, 4):
            twin = {2: 8, 3: 7, 4: 6}[key[1]]
            sprites[(key[0], twin) + key[2:]] = ImageOps.mirror(sprites[key])
    if 4 in backlegs:
        backlegs[6] = ImageOps.mirror(backlegs[4])
    out_dir = os.path.join(AV, folder)
    for key, im in sprites.items():
        im.save(os.path.join(out_dir, _out_names(garment, body, key)))
    for d, im in backlegs.items():
        im.save(os.path.join(out_dir, f"{garment}_{body}_{CARDINAL[d]}_backleg_sit3.png"))
    print(f"{garment}/{body}: {len(sprites)} frames + {len(backlegs)} back legs -> {folder}/")


# Lying views: the 160x128 lying canvas cropped to 128x96 (the clothes never reach the head end),
# so the A/B views of both bodies fit one call (4 frames of up to 128px).
LYING_CROP = (16, 16, 144, 112)
LYING_FRAMES = [(b, v) for b in ("female", "male") for v in "AB"]


def lying_input(body, view, slot):
    canvas = Image.new("RGBA", (160, 128))
    canvas.alpha_composite(_tint(_load(f"lying/body/{body}_lie{view}.png"), SKIN))
    other = _load(f"lying/bottoms/jeans_{body}_lie{view}.png" if slot == "top" else
                  f"lying/tops/jacket_{body}_lie{view}.png")
    canvas.alpha_composite(_tint(other, (40, 40, 48)))
    return canvas.crop(LYING_CROP)


def generate_lying(garment, seed=42):
    spec = GARMENTS[garment]
    frames = [(b, v) for b, v in LYING_FRAMES if b in spec.get("fits", ("female", "male"))]
    images = [lying_input(b, v, spec["slot"]) for b, v in frames]
    for (b, v), im in zip(frames, images):
        im.save(os.path.join(GEN, f"_input_{garment}_{b}_lie{v}.png"))
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    payload = {
        "method": "edit_with_text",
        "edit_images": [{"image": _b64(im), "width": 128, "height": 96} for im in images],
        "image_size": {"width": 128, "height": 96},
        "description": f"the character is lying on their back; dress them in {spec['prompt']}; keep the body, "
                       "pose and every other piece of clothing exactly the same",
        "no_background": True,
        "seed": seed,
    }
    r = requests.post(f"{API}/edit-images-v2", headers=headers, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{r.status_code} {r.text[:500]}")
    out = wait_job(r.json().get("background_job_id"), headers)
    print(f"{garment} lying: got {len(out)} of {len(frames)}")
    for (b, v), s in zip(frames, out):
        _decode(s).save(os.path.join(GEN, f"{garment}_{b}_lie{v}.png"))


def build_lying(garment):
    spec = GARMENTS[garment]
    folder = {"top": "tops", "bottom": "bottoms"}[spec["slot"]]
    for b, v in LYING_FRAMES:
        path = os.path.join(GEN, f"{garment}_{b}_lie{v}.png")
        if not os.path.exists(path):
            continue
        gen = Image.open(path).convert("RGBA")
        inp = Image.open(os.path.join(GEN, f"_input_{garment}_{b}_lie{v}.png")).convert("RGBA")
        gen, mask = isolate(gen, inp, spec["slot"])
        full = Image.new("RGBA", (160, 128))
        full.alpha_composite(to_gray(gen, mask), LYING_CROP[:2])
        os.makedirs(os.path.join(AV, "lying", folder), exist_ok=True)
        full.save(os.path.join(AV, "lying", folder, f"{garment}_{b}_lie{v}.png"))
    print(f"{garment}: lying views built")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--generate" in args:
        i = args.index("--generate")
        groups = [int(g) for g in args[args.index("--groups") + 1].split(",")] if "--groups" in args else None
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        generate(args[i + 1], args[i + 2], groups, seed)
    if "--build" in args:
        i = args.index("--build")
        build(args[i + 1], args[i + 2])
    if "--generate-lying" in args:
        generate_lying(args[args.index("--generate-lying") + 1])
    if "--build-lying" in args:
        build_lying(args[args.index("--build-lying") + 1])
    if "--recover" in args:
        i = args.index("--recover")
        recover(args[i + 1], args[i + 2], args[i + 3], int(args[i + 4]))
