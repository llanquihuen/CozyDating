"""Wall panels for the lobby room, at the furniture's pixel density.

A wall panel is 32 x 70 world units drawn at 0.5 units per pixel: 64 x 140 px of wall, slanted like
the isometric wall (each pair of columns one pixel lower than the previous pair), so the sprite is
64 x 172 px. North-wall panels are stored; the west wall draws them mirrored, which keeps the corner
seamless (panel 0 touches the corner on both walls).

Each wallpaper is generated FLAT (front view) with PixelLab generate-image-v2, using a furniture
sprite as the style image so the pixel size matches, then sliced into 8 panels and slanted here by
whole-pixel column shifts (no resampling):

  - strip: one 512 x 140 image = the 8 panels of a wall, continuous across panels (1 image per call)
  - panel: one 64 x 140 image repeated on every panel, for panel-structured styles (4 per call)

  python make_walls.py --gen brick_stone [--seed 5]
  python make_walls.py --gen all
  python make_walls.py --sheet                       # flat generations + a slanted room corner
  python make_walls.py --build brick_stone=brick_stone_s5 [shoji=shoji_s5_2 ...]

Raw generations stay in gen_walls/ so --build never spends credits. Output:
frontend/assets/images/wallpaper/panels/<id>_p<n>.png and panels.json (panel count per id).
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
GEN = os.path.join(HERE, "gen_walls")
OUT = os.path.join(REPO, "frontend", "assets", "images", "wallpaper", "panels")
STYLE = os.path.join(REPO, "frontend", "assets", "images", "furniture", "established_furniture",
                     "closet_rot0.png")
API = "https://api.pixellab.ai/v2"
PW, PH = 64, 140          # one panel, flat
PANELS = 8                # a wall is 8 panels
SLANT = PW // 2           # rows the slant adds (1 per 2 columns)

COMMON = ("flat front view of an interior room wall, seen straight on, no perspective, fills the whole "
          "image edge to edge, no objects, no furniture, no windows, no people, no text, cozy pixel art, "
          "soft shading, a thin wooden baseboard along the bottom edge")

# id -> (kind, description). Ids match RoomThemes wallpaper ids and InteriorWallStyles ids
# (room_config.dart). solid_* are gray bases tinted in the app (BlendMode.modulate).
WALLS = {
    # perimeter wallpapers
    "rustic_wood": ("strip", "rustic warm wooden wall, vertical wooden planks of honey brown, wood grain"),
    "brick_stone": ("strip", "vintage white painted brick wall, light gray mortar lines, a few worn bricks"),
    "cozy_stripes": ("strip", "wallpaper with vertical stripes of sage green and cream, a white wainscot "
                              "panel on the lower quarter"),
    "starry_night": ("strip", "deep navy blue wallpaper with small golden stars and tiny crescent moons"),
    "pastel_floral": ("strip", "romantic pastel pink wallpaper with small white and rose flowers and green "
                               "leaves, repeating pattern"),
    "solid_plaster": ("strip", "plain smooth plaster wall, light neutral gray only, subtle texture, no color"),
    "solid_tiles": ("strip", "wall covered with square ceramic tiles, light neutral gray only, thin grout "
                             "lines, no color"),
    # interior wall styles
    "wood_slats": ("strip", "partition wall of dark walnut brown vertical wooden slats, a wooden top beam"),
    "rustic_brick": ("strip", "exposed red brick partition wall with light mortar lines"),
    "japanese_shoji": ("panel", "one japanese shoji screen panel, dark wooden frame and lattice of three "
                                "columns and five rows, translucent cream rice paper"),
    "modern_white": ("panel", "one minimalist white wall panel, a thin light gray vertical seam in the "
                              "middle, a black metal baseboard"),
}

# Gray bases keep the mean of the old textures (wallpaper_solid_*.png) so the tints stay the same.
GRAY_MEAN = {"solid_plaster": None, "solid_tiles": None}


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


def generate(wid, seed=None):
    os.makedirs(GEN, exist_ok=True)
    kind, desc = WALLS[wid]
    size = (PW * PANELS, PH) if kind == "strip" else (PW, PH)
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    style = Image.open(STYLE)
    payload = {
        "description": f"{desc}. {COMMON}",
        "image_size": {"width": size[0], "height": size[1]},
        "no_background": False,
        "style_image": {"image": _b64(style), "size": {"width": style.width, "height": style.height}},
        "style_options": {"color_palette": False, "outline": False, "detail": True, "shading": True},
    }
    if seed is not None:
        payload["seed"] = seed
    r = requests.post(f"{API}/generate-image-v2", headers=headers, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{r.status_code} {r.text[:500]}")
    job = r.json().get("background_job_id")
    for _ in range(90):
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
        raise RuntimeError(f"{wid}: job {job} still running; recover it later")
    images = data.get("images") or ([data["image"]] if data.get("image") else [])
    tag = f"s{seed}" if seed is not None else time.strftime("t%H%M%S")
    for i, s in enumerate(images):
        name = f"{wid}_{tag}" + (f"_{i}" if len(images) > 1 else "")
        im = _decode(s)
        im.save(os.path.join(GEN, name + ".png"))
        print("saved", name, im.size)


def flat_panels(wid, name):
    """The 8 flat 64x140 panels of a wall from a generation (a strip, or one panel repeated)."""
    im = Image.open(os.path.join(GEN, name + ".png")).convert("RGBA")
    kind = WALLS[wid][0]
    want = (PW * PANELS, PH) if kind == "strip" else (PW, PH)
    if im.size != want:
        im = im.resize(want, Image.NEAREST)
    if kind == "panel":
        return [im]
    return [im.crop((n * PW, 0, (n + 1) * PW, PH)) for n in range(PANELS)]


def slant(panel):
    """Flat 64x140 panel -> the north wall's slanted 64x172 panel (column c drops c // 2 rows)."""
    out = Image.new("RGBA", (PW, PH + SLANT), (0, 0, 0, 0))
    for c in range(PW):
        out.paste(panel.crop((c, 0, c + 1, PH)), (c, c // 2))
    return out


def flatten(im, radius=10):
    """Remove large blotches (a tinted base must be even) but keep the fine texture."""
    from PIL import ImageFilter, ImageChops
    gray = im.convert("L")
    blur = gray.filter(ImageFilter.GaussianBlur(radius))
    mean = sum(gray.getdata()) / (gray.width * gray.height)
    flat = ImageChops.add(ImageChops.subtract(gray, blur, offset=128), Image.new("L", gray.size, 0))
    flat = flat.point(lambda v: max(0, min(255, round(v - 128 + mean))))
    return Image.merge("RGBA", (flat, flat, flat, im.getchannel("A")))


def neutral(im, mean):
    gray, alpha = im.convert("L"), im.getchannel("A")
    vals = [g for g, a in zip(gray.getdata(), alpha.getdata()) if a]
    k = mean / (sum(vals) / len(vals))
    gray = gray.point(lambda g: max(0, min(255, round(g * k))))
    return Image.merge("RGBA", (gray, gray, gray, alpha))


def old_mean(wid):
    im = Image.open(os.path.join(OUT, "..", f"wallpaper_{wid}.png")).convert("L")
    vals = list(im.getdata())
    return sum(vals) / len(vals)


def corner(panels):
    """A room corner like the app draws it: west wall (mirrored) on the left, north on the right."""
    n = len(panels)
    w = PW * PANELS
    img = Image.new("RGBA", (2 * w, PH + SLANT * PANELS), (20, 22, 30, 255))
    for i in range(PANELS):
        p = slant(panels[i % n])
        img.alpha_composite(p, (w + i * PW, i * SLANT))
        img.alpha_composite(p.transpose(Image.FLIP_LEFT_RIGHT), (w - (i + 1) * PW, i * SLANT))
    return img


def sheet():
    files = sorted(f[:-4] for f in os.listdir(GEN) if f.endswith(".png") and not f.startswith("_"))
    rows = []
    for name in files:
        wid = next(w for w in sorted(WALLS, key=len, reverse=True) if name.startswith(w + "_"))
        c = corner(flat_panels(wid, name))
        row = Image.new("RGBA", (c.width, c.height + 14), (12, 14, 21, 255))
        ImageDraw.Draw(row).text((4, 1), name, fill=(230, 230, 230, 255))
        row.alpha_composite(c, (0, 14))
        rows.append(row)
    cols = 2
    w = max(r.width for r in rows)
    h = max(r.height for r in rows)
    out = Image.new("RGBA", (cols * w, ((len(rows) + cols - 1) // cols) * h), (12, 14, 21, 255))
    for i, r in enumerate(rows):
        out.alpha_composite(r, ((i % cols) * w, (i // cols) * h))
    out.save(os.path.join(GEN, "_sheet.png"))
    print("sheet:", len(rows), "generations")


def build(wid, name):
    panels = flat_panels(wid, name)
    if wid in GRAY_MEAN:
        strip = Image.new("RGBA", (PW * len(panels), PH))
        for n, p in enumerate(panels):
            strip.paste(p, (n * PW, 0))
        strip = flatten(strip)
        panels = [strip.crop((n * PW, 0, (n + 1) * PW, PH)) for n in range(len(panels))]
        mean = old_mean(wid)
        panels = [neutral(p, mean) for p in panels]
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.startswith(wid + "_p"):
            os.remove(os.path.join(OUT, old))
    for n, p in enumerate(panels):
        slant(p).save(os.path.join(OUT, f"{wid}_p{n}.png"))
    write_manifest()
    print("built", wid, "x", len(panels), "from", name)


def write_manifest():
    """panels.json: panel count per id, read by the app (WallPanels)."""
    counts = {}
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png") and "_p" in f:
            key = f.rsplit("_p", 1)[0]
            counts[key] = counts.get(key, 0) + 1
    with open(os.path.join(OUT, "panels.json"), "w", encoding="utf-8") as fh:
        json.dump(counts, fh, indent=2, sort_keys=True)
        fh.write("\n")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--gen" in args:
        which = args[args.index("--gen") + 1]
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        done = set()
        if os.path.isdir(GEN):
            for f in os.listdir(GEN):
                done |= {w for w in WALLS if f.startswith(w + "_")}
        ids = [w for w in WALLS if w not in done] if which == "all" else which.split(",")
        for w in ids:
            generate(w, seed)
    elif "--sheet" in args:
        sheet()
    elif "--build" in args:
        for pair in args[args.index("--build") + 1:]:
            wid, name = pair.split("=")
            build(wid, name)
    else:
        print(__doc__)
