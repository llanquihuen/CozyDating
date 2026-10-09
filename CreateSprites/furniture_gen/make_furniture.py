"""Furniture with the exact room geometry, finished by PixelLab.

Each piece starts as a BLOCKOUT drawn here: flat-shaded isometric boxes on the catalog canvas that
fill the footprint exactly (128 px per tile drawn at 0.5x, the same anchor and sprite offset the game
uses), with the main features marked (doors, basin, burners...). PixelLab edit-images-v2 turns the
blockouts into detailed pixel art in ONE call per piece (front view rot0 and back view rot2 edited
together, plus a finished catalog piece as a style anchor), so both views are the same object and the
footprint stays exact. rot1 / rot3 are mirrors of rot0 / rot2, as for the existing furniture.

  python make_furniture.py --blockout kitchen_sink      # preview the blockouts (no credits)
  python make_furniture.py --gen kitchen_sink [--seed 3]
  python make_furniture.py --sheet                      # every generation over its footprint
  python make_furniture.py --build kitchen_sink=kitchen_sink_s3
  python make_furniture.py --genimg tea_set_table [--seed 3]    # small pieces: candidates + sheet
  python make_furniture.py --place tea_set_table=tea_set_table_g3_5

Raw generations stay in gen/ so --build never spends credits. --build writes
frontend/assets/images/furniture/established_furniture/<id>_rot{0..3}.png (+ <id>.png = rot0).
"""
import base64
import io
import json
import os
import sys
import time

import requests
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # CreateSprites
REPO = os.path.dirname(ROOT)
GEN = os.path.join(HERE, "gen")
EST = os.path.join(REPO, "frontend", "assets", "images", "furniture", "established_furniture")
NEW_ADDED = os.path.join(REPO, "frontend", "assets", "images", "furniture", "new_added")
API = "https://api.pixellab.ai/v2"

# Canvas and sprite offset per footprint, as in the catalog (world units; the sprite is drawn at 0.5x).
GEOMETRY = {
    "1x1": {"canvas": (128, 128), "offset": (-32, -48), "tiles": (1, 1)},
    "2x2": {"canvas": (256, 192), "offset": (-64, -44), "tiles": (2, 2)},
}

STYLE_ANCHOR = "kitchen_fridge_sm_rot0.png"  # a finished piece: palette, outline and shading to match

PIECES = {
    "kitchen_sink": {
        "footprint": "1x1",
        "height": 20,  # counter top, world units (= catalog surface_height)
        "front": "kitchen sink base cabinet with two wooden doors with small metal handles",
        "top": "white stone counter top with a stainless steel sink basin and a curved chrome faucet "
               "at the back edge",
        "back": "plain wooden back panel of the cabinet",
        "features": ["doors", "basin", "faucet"],
    },
    "kitchen_stove": {
        "footprint": "1x1",
        "height": 22,
        "front": "stainless steel kitchen range with an oven door with a glass window and a handle, "
                 "control knobs above the door",
        "top": "black cooktop with four gas burners and cast iron grates, a low back splash panel",
        "back": "plain brushed steel back panel of the stove",
        "features": ["oven", "burners"],
    },
    "dining_table_2x2": {
        "footprint": "2x2",
        "kind": "table",
        "height": 22,       # table top (= catalog surface_height)
        "symmetric": True,  # rot2 = rot0
        "reference": "closet_rot0.png",  # wood grain; its own art is the weak one
        "front": "solid oak dining table",
        "top": "warm wooden table top with planks",
        "back": "",
        "features": [],
    },
}

# Small pieces with no footprint to fill (tabletop objects, plants, floor cushions): generated new
# with generate-image-v2 (a finished sprite as the style image, so the pixel size matches; several
# candidates per call) and placed with their base where the current art stands (anchor = bottom
# centre of the opaque art, in canvas pixels). Symmetric enough that rot2 = rot0.
IMG_PIECES = {
    "tea_set_table": {
        "size": (48, 48), "style": "coffee_mug_rot0.png", "canvas": (128, 128), "anchor": (64, 91),
        "desc": "japanese matcha tea set on a small round bamboo tray: a green ceramic teapot, two small "
                "tea cups and a bamboo whisk, isometric view from above at a 30 degree angle",
    },
    "vinyl_record_player": {
        "size": (48, 48), "style": "coffee_mug_rot0.png", "canvas": (128, 128), "anchor": (64, 89),
        "desc": "retro vinyl record player turntable in a wooden case with a black vinyl record and a "
                "silver tone arm, open lid, isometric view from above at a 30 degree angle",
    },
    "monstera_plant_pot": {
        "size": (96, 112), "style": "floor_plant_sm_rot0.png", "canvas": (128, 176), "anchor": (62, 168),
        "desc": "monstera deliciosa house plant with big split leaves in a terracotta pot, isometric view",
    },
    "pet_dog_bed": {
        "size": (80, 64), "style": "plush_armchair_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "round plush dog bed with a soft raised rim and a cushion, a small bone toy on it, "
                "isometric view from above at a 30 degree angle, lying on the floor",
    },
    "yoga_mat_floor": {
        "size": (80, 56), "style": "simple_sofa_rot0.png", "canvas": (128, 128), "anchor": (64, 116),
        "desc": "teal yoga mat unrolled flat on the floor with one end rolled up, a small pink water "
                "bottle beside it, isometric view from above at a 30 degree angle",
    },
}

def _key():
    cwd = os.getcwd()
    os.chdir(ROOT)  # pixellab_config.json is relative
    sys.path.insert(0, ROOT)
    try:
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


# ------------------------------------------------------------------ geometry
def to_px(geo, x, y, z=0.0):
    """Grid point (x, y) at height z (world units) -> sprite pixel, like the game's sprite offset."""
    ox, oy = geo["offset"]
    sx = (x - y) * 32
    sy = (x + y) * 16 - 16 - z
    return ((sx - ox) * 2, (sy - oy) * 2)


def footprint_poly(geo, z=0.0):
    w, h = geo["tiles"]
    return [to_px(geo, *p, z) for p in ((0, 0), (w, 0), (w, h), (0, h))]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def quad(a, b, c, d, u0, u1, v0, v1):
    """Sub-rectangle of the quad a-b-c-d (a-b along u, a-d along v)."""
    def at(u, v):
        return lerp(lerp(a, b, u), lerp(d, c, u), v)
    return [at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1)]


def blockout(pid, view):
    """Flat-shaded box filling the footprint; view 0 = front faces the viewer's left (rot0),
    view 2 = back view (front faces away)."""
    p = PIECES[pid]
    if p.get("kind") == "table":
        return blockout_table(pid)
    geo = GEOMETRY[p["footprint"]]
    w, h = geo["tiles"]
    z = p["height"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top = footprint_poly(geo, z)          # (0,0) (w,0) (w,h) (0,h) at counter height
    base = footprint_poly(geo, 0)
    # visible side faces: left = edge (0,h)-(w,h) ... the faces toward the viewer are y=h (left) and
    # x=w (right)
    left = [top[3], top[2], base[2], base[3]]
    right = [top[2], top[1], base[1], base[2]]
    steel = "stove" in pid
    body_l, body_r = ((150, 155, 165), (120, 125, 135)) if steel else ((150, 100, 60), (115, 75, 45))
    d.polygon(left, fill=body_l + (255,))
    d.polygon(right, fill=body_r + (255,))
    d.polygon(top, fill=((40, 40, 45, 255) if steel else (235, 235, 230, 255)))
    ink = (60, 40, 30, 255)
    feats = p["features"]
    if view == 0:
        if "doors" in feats:
            for u0, u1 in ((0.08, 0.48), (0.52, 0.92)):
                d.polygon(quad(*left, u0, u1, 0.15, 0.9), outline=ink)
                hx, hy = lerp(*quad(*left, u0, u1, 0.3, 0.3)[:2], 0.85 if u0 < 0.5 else 0.15)
                d.rectangle((hx - 1, hy - 3, hx, hy + 3), fill=(200, 200, 205, 255))
        if "oven" in feats:
            d.polygon(quad(*left, 0.1, 0.9, 0.3, 0.92), fill=(60, 60, 70, 255), outline=ink)
            d.polygon(quad(*left, 0.2, 0.8, 0.42, 0.8), fill=(25, 25, 35, 255))
            for u in (0.2, 0.4, 0.6, 0.8):
                x, y = quad(*left, u, u, 0.12, 0.12)[0]
                d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(30, 30, 30, 255))
    if "basin" in feats:
        d.polygon(quad(*top, 0.3, 0.75, 0.25, 0.75), fill=(170, 175, 185, 255), outline=(110, 115, 125, 255))
    if "faucet" in feats:
        # at the back edge: the front is the y = h face, so the back is the y = 0 edge
        bx, by = lerp(top[0], top[1], 0.5)
        bx, by = lerp((bx, by), lerp(top[3], top[2], 0.5), 0.15)
        d.line((bx, by, bx, by - 14), fill=(190, 195, 205, 255), width=2)
        d.line((bx, by - 14, bx + 8, by - 10), fill=(190, 195, 205, 255), width=2)
    if "burners" in feats:
        for u, v in ((0.3, 0.3), (0.7, 0.3), (0.3, 0.7), (0.7, 0.7)):
            x, y = quad(*top, u, u, v, v)[0]
            d.ellipse((x - 7, y - 4, x + 7, y + 4), outline=(120, 120, 125, 255), width=2)
        d.polygon([top[0], top[1], (top[1][0], top[1][1] - 10), (top[0][0], top[0][1] - 10)],
                  fill=(150, 155, 165, 255))
    if view == 2:
        # back view: the same object turned 180 degrees = rot0 mirrored through the centre, but
        # with the plain back panel where the front was. Draw rot0's top turned and plain sides.
        im = im.transpose(Image.ROTATE_180)
        im = blockout_back(pid, im)
    return im


def blockout_table(pid, inset=0.06, thick=4, leg=0.12):
    """Table: a top slab over the whole footprint (slightly inset) on four corner legs."""
    p = PIECES[pid]
    geo = GEOMETRY[p["footprint"]]
    w, h = geo["tiles"]
    z = p["height"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wood_l, wood_r, wood_t, ink = (140, 90, 50, 255), (110, 70, 40, 255), (175, 120, 70, 255), (70, 45, 25, 255)

    def box(x0, y0, x1, y1, z0, z1, fill_t=wood_t):
        t = [to_px(geo, x, y, z1) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        b = [to_px(geo, x, y, z0) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        d.polygon([t[3], t[2], b[2], b[3]], fill=wood_l)
        d.polygon([t[2], t[1], b[1], b[2]], fill=wood_r)
        d.polygon(t, fill=fill_t)

    i = inset
    # back legs first, then the front ones, then the top
    legs = [(i, i), (w - i - leg, i), (i, h - i - leg), (w - i - leg, h - i - leg)]
    for lx, ly in sorted(legs, key=lambda q: q[0] + q[1]):
        box(lx, ly, lx + leg, ly + leg, 0, z - thick)
    box(i, i, w - i, h - i, z - thick, z)
    # plank joints along the table
    for k in range(1, 5):
        y = i + (h - 2 * i) * k / 5
        d.line([to_px(geo, i, y, z), to_px(geo, w - i, y, z)], fill=(140, 92, 52, 255), width=1)
    return im


def blockout_back(pid, _unused):
    p = PIECES[pid]
    geo = GEOMETRY[p["footprint"]]
    z = p["height"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top = footprint_poly(geo, z)
    base = footprint_poly(geo, 0)
    left = [top[3], top[2], base[2], base[3]]
    right = [top[2], top[1], base[1], base[2]]
    steel = "stove" in pid
    body_l, body_r = ((150, 155, 165), (120, 125, 135)) if steel else ((150, 100, 60), (115, 75, 45))
    d.polygon(left, fill=body_l + (255,))
    d.polygon(right, fill=body_r + (255,))
    d.polygon(top, fill=((40, 40, 45, 255) if steel else (235, 235, 230, 255)))
    feats = p["features"]
    if "basin" in feats:
        d.polygon(quad(*top, 0.25, 0.7, 0.25, 0.75), fill=(170, 175, 185, 255), outline=(110, 115, 125, 255))
    if "faucet" in feats:
        # the back edge is now the near-left side (y = h)
        bx, by = lerp(top[3], top[2], 0.5)
        bx, by = lerp((bx, by), lerp(top[0], top[1], 0.5), 0.12)
        d.line((bx, by, bx, by - 14), fill=(190, 195, 205, 255), width=2)
        d.line((bx, by - 14, bx + 8, by - 18), fill=(190, 195, 205, 255), width=2)
    if "burners" in feats:
        for u, v in ((0.3, 0.3), (0.7, 0.3), (0.3, 0.7), (0.7, 0.7)):
            x, y = quad(*top, u, u, v, v)[0]
            d.ellipse((x - 7, y - 4, x + 7, y + 4), outline=(120, 120, 125, 255), width=2)
        d.polygon([top[3], top[2], (top[2][0], top[2][1] - 10), (top[3][0], top[3][1] - 10)],
                  fill=(150, 155, 165, 255))
    return im


# ------------------------------------------------------------------ generation
def prompt(pid):
    p = PIECES[pid]
    return (f"isometric pixel art furniture for a cozy room game. Frame 1: {p['front']}, {p['top']}, "
            f"seen from the front. Frame 2: the same piece seen from behind: {p['back']}, {p['top']}. "
            "Keep the exact box shape, size and position of each frame, fill the whole box, detailed "
            "shading and texture, selective outline, same palette and style as frame 3. Frame 3 stays "
            "the same.")


def generate_ref(pid, seed=None, ref=None):
    """edit_with_reference: the blockouts take the look of a finished sprite (by default the piece's
    current rot0), keeping their own shape."""
    os.makedirs(GEN, exist_ok=True)
    geo = GEOMETRY[PIECES[pid]["footprint"]]
    symmetric = PIECES[pid].get("symmetric")
    frames = [blockout(pid, 0)] if symmetric else [blockout(pid, 0), blockout(pid, 2)]
    ref = ref or PIECES[pid].get("reference") or f"{pid}_rot0.png"
    refim = Image.open(os.path.join(EST, ref)).convert("RGBA")
    w, h = geo["canvas"]
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    payload = {
        "method": "edit_with_reference",
        "edit_images": [{"image": _b64(f), "width": w, "height": h} for f in frames],
        "image_size": {"width": w, "height": h},
        "reference_image": {"image": _b64(refim), "width": refim.width, "height": refim.height},
        "no_background": True,
    }
    if seed is not None:
        payload["seed"] = seed
    data = _run(headers, "edit-images-v2", payload, pid)
    images = data.get("images") or []
    tag = "rs" + (str(seed) if seed is not None else time.strftime("%H%M%S"))
    for i, s in enumerate(images[:2]):
        _decode(s).save(os.path.join(GEN, f"{pid}_{tag}_r{2 * i}.png"))
    if symmetric and images:
        _decode(images[0]).save(os.path.join(GEN, f"{pid}_{tag}_r2.png"))
    print(pid, tag, "got", len(images), "images")


def _run(headers, endpoint, payload, label):
    r = requests.post(f"{API}/{endpoint}", headers=headers, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{r.status_code} {r.text[:500]}")
    job = r.json().get("background_job_id")
    for _ in range(100):
        time.sleep(6)
        try:
            j = requests.get(f"{API}/background-jobs/{job}", headers=headers, timeout=30).json()
        except requests.RequestException:
            continue
        if j.get("status") == "completed":
            return j.get("last_response", {})
        if j.get("status") == "failed":
            raise RuntimeError(json.dumps(j)[:500])
    raise RuntimeError(f"{label}: job {job} still running")


def generate(pid, seed=None):
    os.makedirs(GEN, exist_ok=True)
    geo = GEOMETRY[PIECES[pid]["footprint"]]
    frames = [blockout(pid, 0), blockout(pid, 2)]
    anchor = Image.open(os.path.join(EST, STYLE_ANCHOR)).convert("RGBA")
    if anchor.size != geo["canvas"]:
        c = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
        c.alpha_composite(anchor.crop((0, max(0, anchor.height - geo["canvas"][1]), anchor.width,
                                       anchor.height)), (0, 0))
        anchor = c
    frames.append(anchor)
    for i, f in enumerate(frames):
        f.save(os.path.join(GEN, f"_input_{pid}_{i}.png"))
    w, h = geo["canvas"]
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    payload = {
        "method": "edit_with_text",
        "edit_images": [{"image": _b64(f), "width": w, "height": h} for f in frames],
        "image_size": {"width": w, "height": h},
        "description": prompt(pid),
        "no_background": True,
    }
    if seed is not None:
        payload["seed"] = seed
    r = requests.post(f"{API}/edit-images-v2", headers=headers, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{r.status_code} {r.text[:500]}")
    job = r.json().get("background_job_id")
    for _ in range(100):
        time.sleep(6)
        try:
            j = requests.get(f"{API}/background-jobs/{job}", headers=headers, timeout=30).json()
        except requests.RequestException:
            continue
        if j.get("status") == "completed":
            data = j.get("last_response", {})
            break
        if j.get("status") == "failed":
            raise RuntimeError(json.dumps(j)[:500])
    else:
        raise RuntimeError(f"{pid}: job {job} still running")
    images = data.get("images") or []
    tag = f"s{seed}" if seed is not None else time.strftime("t%H%M%S")
    for i, s in enumerate(images[:2]):
        _decode(s).save(os.path.join(GEN, f"{pid}_{tag}_r{2 * i}.png"))
    print(pid, tag, "got", len(images), "images")


# ------------------------------------------------------------------ review / build
def on_footprint(pid, im, scale=3):
    geo = GEOMETRY[PIECES[pid]["footprint"]]
    bg = Image.new("RGBA", geo["canvas"], (34, 36, 48, 255))
    d = ImageDraw.Draw(bg)
    d.polygon(footprint_poly(geo), fill=(255, 45, 154, 90), outline=(255, 45, 154, 255))
    bg.alpha_composite(im)
    return bg.resize((bg.width * scale, bg.height * scale), Image.NEAREST)


def preview_blockout(pid):
    ims = [on_footprint(pid, blockout(pid, v)) for v in (0, 2)]
    out = Image.new("RGBA", (sum(i.width for i in ims) + 8, ims[0].height), (0, 0, 0, 255))
    x = 0
    for i in ims:
        out.alpha_composite(i, (x, 0))
        x += i.width + 8
    out.save(os.path.join(GEN, f"_blockout_{pid}.png"))
    print("saved", f"gen/_blockout_{pid}.png")


def sheet():
    names = sorted({f.rsplit("_r", 1)[0] for f in os.listdir(GEN) if not f.startswith("_") and f.endswith(".png")})
    rows = []
    for n in names:
        pid = next(p for p in sorted(PIECES, key=len, reverse=True) if n.startswith(p + "_"))
        cur = [Image.open(os.path.join(EST, f"{pid}_rot{r}.png")).convert("RGBA") for r in (0, 2)]
        new = [Image.open(os.path.join(GEN, f"{n}_r{r}.png")).convert("RGBA") for r in (0, 2)]
        cells = [on_footprint(pid, im, 2) for im in cur + new]
        row = Image.new("RGBA", (sum(c.width + 6 for c in cells), cells[0].height + 16), (12, 14, 21, 255))
        ImageDraw.Draw(row).text((4, 2), f"{n}: actual rot0, rot2 | nuevo rot0, rot2", fill=(255, 230, 120, 255))
        x = 0
        for c in cells:
            row.alpha_composite(c, (x, 16))
            x += c.width + 6
        rows.append(row)
    out = Image.new("RGBA", (max(r.width for r in rows), sum(r.height for r in rows)), (12, 14, 21, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    out.save(os.path.join(GEN, "_sheet.png"))
    print("sheet:", len(rows))


def build(pid, name):
    r0 = Image.open(os.path.join(GEN, f"{name}_r0.png")).convert("RGBA")
    r2 = Image.open(os.path.join(GEN, f"{name}_r2.png")).convert("RGBA")
    sys.path.insert(0, os.path.join(ROOT, "face_pipeline"))
    from convert_selout import convert_colour
    r0, r2 = convert_colour(r0), convert_colour(r2)
    views = {0: r0, 1: r0.transpose(Image.FLIP_LEFT_RIGHT), 2: r2, 3: r2.transpose(Image.FLIP_LEFT_RIGHT)}
    n = write_views(pid, views)
    print("built", pid, "from", name, f"(+{n} in new_added)")


def write_views(pid, views):
    """views: rot -> image. Writes established_furniture/<pid>_rot*.png (+ <pid>.png = rot0) and
    replaces the copies in new_added/ (the sync's sources), or the next sync_furniture_assets.py
    would copy the old art back. Returns how many new_added/ files were replaced."""
    files = {f"{pid}_rot{r}.png": im for r, im in views.items()}
    files[f"{pid}.png"] = views[0]
    sources = {}
    for root, _, names in os.walk(NEW_ADDED):
        for n in names:
            if n in files:
                sources[n] = os.path.join(root, n)
    for n, im in files.items():
        im.save(os.path.join(EST, n))
        if n in sources:
            im.save(sources[n])
    return len(sources)


# ------------------------------------------------------------------ small pieces / restyle
def generate_img(pid, seed=None):
    spec = IMG_PIECES[pid]
    os.makedirs(GEN, exist_ok=True)
    style = Image.open(os.path.join(EST, spec["style"])).convert("RGBA")
    style = style.crop(style.getchannel("A").getbbox())
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    payload = {
        "description": f"{spec['desc']}. Single object, pixel art game furniture sprite, selective "
                       "outline, detailed shading, no shadow on the ground, transparent background",
        "image_size": {"width": spec["size"][0], "height": spec["size"][1]},
        "no_background": True,
        "style_image": {"image": _b64(style), "size": {"width": style.width, "height": style.height}},
        "style_options": {"color_palette": False, "outline": True, "detail": True, "shading": True},
    }
    if seed is not None:
        payload["seed"] = seed
    data = _run(headers, "generate-image-v2", payload, pid)
    images = data.get("images") or ([data["image"]] if data.get("image") else [])
    tag = "g" + (str(seed) if seed is not None else time.strftime("%H%M%S"))
    for i, im in enumerate(images):
        _decode(im).save(os.path.join(GEN, f"{pid}_{tag}_{i}.png"))
    print(pid, tag, "got", len(images), "candidates")


def place(pid, art):
    """Art cropped to its opaque bbox, its bottom centre on the piece's anchor."""
    spec = IMG_PIECES[pid]
    art = art.crop(art.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox())
    canvas = Image.new("RGBA", spec["canvas"], (0, 0, 0, 0))
    ax, ay = spec["anchor"]
    canvas.alpha_composite(art, (round(ax - art.width / 2), ay - art.height))
    return canvas


def candidates_sheet(pid):
    files = sorted(f for f in os.listdir(GEN) if f.startswith(pid + "_g") and f.endswith(".png"))
    spec = IMG_PIECES[pid]
    cur = Image.open(os.path.join(EST, f"{pid}_rot0.png")).convert("RGBA")
    if cur.size != spec["canvas"]:
        c = Image.new("RGBA", spec["canvas"], (0, 0, 0, 0))
        c.alpha_composite(cur, ((c.width - cur.width) // 2, c.height - cur.height))
        cur = c
    cells = [("actual", cur)] + [(f[len(pid) + 1:-4], place(pid, Image.open(os.path.join(GEN, f)).convert("RGBA")))
                                 for f in files]
    sc = 3
    cw, ch = spec["canvas"][0] * sc, spec["canvas"][1] * sc
    cols = 6
    out = Image.new("RGBA", (cols * (cw + 4), ((len(cells) + cols - 1) // cols) * (ch + 16)), (12, 14, 21, 255))
    d = ImageDraw.Draw(out)
    for i, (name, im) in enumerate(cells):
        bg = Image.new("RGBA", im.size, (40, 42, 55, 255))
        bg.alpha_composite(im)
        x, y = (i % cols) * (cw + 4), (i // cols) * (ch + 16)
        out.alpha_composite(bg.resize((cw, ch), Image.NEAREST), (x, y + 16))
        d.text((x + 2, y + 2), name, fill=(255, 230, 120, 255))
    out.save(os.path.join(GEN, f"_cand_{pid}.png"))
    print("saved", f"gen/_cand_{pid}.png", len(cells) - 1, "candidates")


def build_placed(pid, name):
    sys.path.insert(0, os.path.join(ROOT, "face_pipeline"))
    from convert_selout import convert_colour
    im = convert_colour(place(pid, Image.open(os.path.join(GEN, name + ".png")).convert("RGBA")))
    m = im.transpose(Image.FLIP_LEFT_RIGHT)
    n = write_views(pid, {0: im, 1: m, 2: im, 3: m})
    print("built", pid, "from", name, f"(+{n} in new_added)")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--blockout" in args:
        for pid in args[args.index("--blockout") + 1].split(","):
            preview_blockout(pid)
    elif "--genimg" in args:
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        for pid in args[args.index("--genimg") + 1].split(","):
            generate_img(pid, seed)
            candidates_sheet(pid)
    elif "--cands" in args:
        for pid in args[args.index("--cands") + 1].split(","):
            candidates_sheet(pid)
    elif "--place" in args:
        for pair in args[args.index("--place") + 1:]:
            pid, name = pair.split("=")
            build_placed(pid, name)
    elif "--genref" in args:
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        for pid in args[args.index("--genref") + 1].split(","):
            generate_ref(pid, seed)
    elif "--gen" in args:
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        for pid in args[args.index("--gen") + 1].split(","):
            generate(pid, seed)
    elif "--sheet" in args:
        sheet()
    elif "--build" in args:
        for pair in args[args.index("--build") + 1:]:
            pid, name = pair.split("=")
            build(pid, name)
    else:
        print(__doc__)
