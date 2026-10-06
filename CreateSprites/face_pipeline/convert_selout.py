"""Converts the original avatar art to the selective outline (sel-out) style of the new art.

- Black outer outline -> a darker shade of the pixels just inside it (0.45x), so after the game's
  modulate tint it reads as a darker tone of the same colour (darker skin, darker hair...).
- Black interior lines (seams, folds) -> a dark shade of their neighbours (0.40x).
- The old clothes (jacket, jeans, boots) were near-black "leather": their grays are remapped by
  percentiles to the brightness of the new clothes (median ~170) keeping their contrast, with one
  mapping per style for every frame so idle, walk, sit and lying match.

Every run starts from the originals as of SOURCE_REV (cached in selout_originals/), so the script can
be tuned and re-run without converting twice.

  python convert_selout.py            # convert in place
  python convert_selout.py --preview NAME.png   # sheet of the sprites currently on disk
  python convert_selout.py --scenery [--dry]    # furniture, bed overlays, dungeon objects (full colour)
"""
import glob
import os
import shutil
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
AV_REL = "frontend/assets/images/OCTOPLAYER/Avatar"
AV = os.path.join(REPO, AV_REL)
ORIG = os.path.join(HERE, "selout_originals")   # local cache, git-ignored
SOURCE_REV = "c06d6ab"   # last commit with the original (black outline) art

OLD_HAIR = ["bangs", "braids", "comb_over", "flow", "long_flow", "twintails"]
CLOTHES = {"jacket": "tops", "jeans": "bottoms", "boots": "shoes"}
LINE = 20            # lum below this = drawn line
OUTLINE_SHADE = 0.45
INNER_SHADE = 0.40
# percentile -> target gray for the old clothes (new clothes: median ~170-175)
TONE_POINTS = [(0.02, 40), (0.10, 75), (0.50, 165), (0.95, 225), (1.0, 240)]


def targets():
    """(relative path, tone style or None) of every sprite to convert."""
    out = []
    def add(pattern, style=None):
        for p in glob.glob(os.path.join(AV, pattern), recursive=True):
            out.append((os.path.relpath(p, AV).replace("\\", "/"), style))
    add("body/*.png")
    add("lying/body/*.png")
    for h in OLD_HAIR:
        add(f"hair/{h}/**/*.png")
        add(f"lying/hair/{h}/*.png")
    for style, folder in CLOTHES.items():
        for p in glob.glob(os.path.join(AV, folder, f"{style}*.png")) + \
                glob.glob(os.path.join(AV, "lying", folder, f"{style}*.png")):
            name = os.path.basename(p)
            # only the original style's files, not newer ones sharing the prefix
            if name.startswith(style) and not name[len(style):len(style) + 1].isalpha():
                out.append((os.path.relpath(p, AV).replace("\\", "/"), style))
    return sorted(set(out))


def original(rel):
    """The untouched sprite: cached copy, else SOURCE_REV, else the file on disk (new since then)."""
    cached = os.path.join(ORIG, rel)
    if not os.path.exists(cached):
        os.makedirs(os.path.dirname(cached), exist_ok=True)
        try:
            data = subprocess.run(["git", "show", f"{SOURCE_REV}:{AV_REL}/{rel}"], cwd=REPO,
                                  capture_output=True, check=True).stdout
            with open(cached, "wb") as f:
                f.write(data)
        except subprocess.CalledProcessError:
            shutil.copy(os.path.join(AV, rel), cached)
    return Image.open(cached).convert("RGBA")


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def tone_map(style, files):
    """Piecewise-linear lum -> gray mapping from the style's idle-frame percentiles."""
    lums = []
    for rel, st in files:
        if st == style and "walk" not in rel and "sit" not in rel and "lie" not in rel:
            im = original(rel)
            lums += [lum(p) for p in im.getdata() if p[3] and lum(p) >= LINE]
    lums.sort()
    src = [lums[min(len(lums) - 1, int(q * len(lums)))] for q, _ in TONE_POINTS]
    dst = [v for _, v in TONE_POINTS]

    def f(x):
        if x <= src[0]:
            return dst[0] * x / max(src[0], 1)
        for (a, b), (c, d) in zip(zip(src, src[1:]), zip(dst, dst[1:])):
            if x <= b:
                return c + (d - c) * (x - a) / max(b - a, 1e-6)
        return dst[-1]
    return f


def convert(im, mapping=None):
    w, h = im.size
    px = im.load()
    opaque = lambda x, y: 0 <= x < w and 0 <= y < h and px[x, y][3] > 0
    base, line, rim = {}, set(), set()
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if not p[3]:
                continue
            l = lum(p)
            if l < LINE:
                line.add((x, y))
            if any(not opaque(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                rim.add((x, y))
            base[(x, y)] = mapping(l) if mapping else l
    out = Image.new("RGBA", im.size)
    op = out.load()
    for (x, y), v in base.items():
        if (x, y) in line:
            shade = OUTLINE_SHADE if (x, y) in rim else INNER_SHADE
            near = []
            for r in (1, 2):
                near = [base[(x + dx, y + dy)] for dx in range(-r, r + 1) for dy in range(-r, r + 1)
                        if (x + dx, y + dy) in base and (x + dx, y + dy) not in line]
                if near:
                    break
            ref = sum(near) / len(near) if near else (150 if mapping is None else mapping(60))
            v = max(30, ref * shade)
        v = max(0, min(255, round(v)))
        op[x, y] = (v, v, v, px[x, y][3])
    return out


def run(write=True):
    files = targets()
    maps = {style: tone_map(style, files) for style in CLOTHES}
    done = 0
    for rel, style in files:
        im = convert(original(rel), maps.get(style))
        if write:
            im.save(os.path.join(AV, rel))
        done += 1
    print(f"{'converted' if write else 'checked'} {done} sprites")


def preview(out_name):
    """The composed avatar in a few looks, directions and poses, from the sprites currently on disk."""
    sys.path.insert(0, os.path.dirname(HERE))
    sys.path.insert(0, HERE)
    import octo_engine
    from face_sheet import base_config
    octo_engine._DISK_CACHE.clear()
    looks = [("female", "#FCD5B5", "bangs", "#C85A2A"), ("male", "#7A4522", "comb_over", "#1E293B"),
             ("female", "#A56635", "long_flow", "#DB2777")]
    cells = [("idle", 1, 0), ("idle", 2, 0), ("idle", 5, 0), ("walk", 3, 1), ("sit", 2, 1)]
    Z = 2
    sheet = Image.new("RGB", (len(cells) * 64 * Z, len(looks) * 128 * Z), (40, 42, 54))
    for r, (body, skin, hair, hc) in enumerate(looks):
        for c, (a, d, f) in enumerate(cells):
            cfg = base_config(body, skin, hair)
            cfg["hair"]["color"] = hc
            cfg["tops"] = {"file": "jacket", "color": "#DC2626"}
            cfg["bottoms"] = {"file": "jeans", "color": "#2563EB"}
            cfg["shoes"] = {"file": "boots", "color": "#78350F"}
            im = octo_engine.compose_octo_avatar(cfg, direction=d, action=a, frame=f)
            sheet.paste(im.resize((64 * Z, 128 * Z), Image.NEAREST), (c * 64 * Z, r * 128 * Z),
                        im.resize((64 * Z, 128 * Z), Image.NEAREST))
    sheet.save(os.path.join(HERE, out_name))
    print("saved", out_name)


# ---------------------------------------------------------------- scenery (full colour, untinted)
IMAGES = os.path.join(REPO, "frontend", "assets", "images")
SCENERY_DIRS = ["furniture/established_furniture", "furniture/sleep_overlays", "furniture/new_added", "dungeon", "."]
DARK = 28  # lum below this (and unsaturated) = black ink
SCENERY_REV = "c5c5d73"  # last commit with the original scenery art


def scenery_original(path):
    """The sprite as of SCENERY_REV (cached next to the avatar originals), else the file on disk (art
    added later). Converting from originals keeps re-runs stable: on already converted art a thick
    outline's converted pixels would count as fill and darken their neighbours again."""
    rel = os.path.relpath(path, REPO).replace("\\", "/")
    cached = os.path.join(ORIG, "_scenery", rel)
    if not os.path.exists(cached):
        os.makedirs(os.path.dirname(cached), exist_ok=True)
        try:
            data = subprocess.run(["git", "show", f"{SCENERY_REV}:{rel}"], cwd=REPO,
                                  capture_output=True, check=True).stdout
            with open(cached, "wb") as f:
                f.write(data)
        except subprocess.CalledProcessError:
            shutil.copy(path, cached)
    return Image.open(cached).convert("RGBA")


def scenery_targets():
    """Sprites with transparent edges (objects); fully opaque textures (floors, wallpaper, wall
    tiles) have no outline to convert and are skipped. New art added after SCENERY_REV is converted
    from disk the first time; run this once after adding furniture."""
    out = []
    for d in SCENERY_DIRS:
        root = os.path.join(IMAGES, d)
        files = glob.glob(os.path.join(root, "**", "*.png"), recursive=True) if d != "." else             glob.glob(os.path.join(root, "*.png"))
        for p in files:
            im = Image.open(p)
            if im.mode != "RGBA" and "transparency" not in im.info:
                continue
            if im.convert("RGBA").getextrema()[3][0] == 255:
                continue
            out.append(p)
    return sorted(out)


def convert_colour(im):
    """Selective outline on colour art: thin black lines take the colour of the fill next to them,
    darkened (0.45x on the outer edge, 0.40x inside). Large black areas (a TV screen) and lines with
    no fill beside them (floor cracks) are left alone, so running it twice changes nothing."""
    w, h = im.size
    src = im.load()
    out = im.copy()
    op = out.load()

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and src[x, y][3] >= 200

    def dark(x, y):
        p = src[x, y]
        return solid(x, y) and lum(p) < DARK and max(p[:3]) - min(p[:3]) < 30

    for y in range(h):
        for x in range(w):
            if not dark(x, y):
                continue
            n8 = [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy]
            rim = any(not (0 <= a < w and 0 <= b < h) or src[a, b][3] < 200
                      for a, b in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            if not rim and sum(dark(a, b) for a, b in n8) >= 6:
                continue  # part of a dark fill, not a line
            fill = []
            for r in (1, 2):
                fill = [src[a, b] for a in range(x - r, x + r + 1) for b in range(y - r, y + r + 1)
                        if 0 <= a < w and 0 <= b < h and solid(a, b) and not dark(a, b)]
                if fill:
                    break
            if not fill:
                continue
            k = OUTLINE_SHADE if rim else INNER_SHADE
            op[x, y] = tuple(round(sum(p[c] for p in fill) / len(fill) * k) for c in range(3)) + (src[x, y][3],)
    return out


def run_scenery(write=True):
    files = scenery_targets()
    changed = 0
    for p in files:
        im = Image.open(p).convert("RGBA")
        new = convert_colour(scenery_original(p))
        if new.tobytes() != im.tobytes():
            changed += 1
            if write:
                new.save(p)
    print(f"scenery: {len(files)} sprites checked, {changed} {'converted' if write else 'would change'}")


if __name__ == "__main__":
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
    elif "--scenery" in sys.argv:
        run_scenery(write="--dry" not in sys.argv)
    else:
        run()
