"""File-level audit of the furniture sprites (no credits): which files each catalog item has, their sizes,
whether rotations are real or mirrors, pixel density and pure-black outlines.

  python audit_files.py [meta.tsv]     # meta.tsv = id/footprint list exported by the in-game audit

Prints one line per item. Flags: FALTA (missing rotation files), TAMAÑOS_DISTINTOS, ANCHO_x!=y (canvas
not the footprint's), SIN_VISTA_TRASERA (rot2 is rot0), rot1!=espejo / rot1=rot0, W=N / W!=espejo(N)
for wall items, PIXEL_2x (art drawn with 2x2 pixels), NEGRO_PURO (pure-black outline share).
"""
import json
import os
import sys

from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
EST = os.path.join(REPO, "frontend", "assets", "images", "furniture", "established_furniture")
CATALOG = os.path.join(REPO, "frontend", "assets", "images", "furniture", "furniture_catalog.json")

# Canvas the room expects per footprint (128 px per tile drawn at 0.5x).
EXPECTED_W = {"0.5x0.5": 128, "1x1": 128, "1x2": 192, "2x1": 192, "2x2": 256}


def load(name):
    p = os.path.join(EST, name)
    return Image.open(p).convert("RGBA") if os.path.exists(p) else None


def chunky(im):
    """True if the art is drawn with 2x2 pixels (half the furniture density)."""
    px = im.load()
    w, h = im.size
    best = 0.0
    for ox in (0, 1):
        for oy in (0, 1):
            same = total = 0
            for y in range(oy, h - 1, 2):
                for x in range(ox, w - 1, 2):
                    a = px[x, y]
                    if a[3] < 128:
                        continue
                    total += 1
                    if a == px[x + 1, y] == px[x, y + 1] == px[x + 1, y + 1]:
                        same += 1
            if total:
                best = max(best, same / total)
    return best


def black_ratio(im):
    vals = [p for p in im.getdata() if p[3] > 128]
    if not vals:
        return 0.0
    return sum(1 for p in vals if max(p[:3]) < 24) / len(vals)


def same(a, b):
    return a is not None and b is not None and a.size == b.size and ImageChops.difference(a, b).getbbox() is None


def mirror(a, b):
    return a is not None and b is not None and same(a.transpose(Image.FLIP_LEFT_RIGHT), b)


def audit(item_id, footprint):
    flags = []
    wall = footprint.startswith("wall")
    if wall:
        names = {k: f"{item_id}_{k}.png" for k in ("n", "w")}
    else:
        names = {r: f"{item_id}_rot{r}.png" for r in range(4)}
    ims = {k: load(n) for k, n in names.items()}
    base = load(f"{item_id}.png")
    missing = [str(k) for k, im in ims.items() if im is None]
    if missing:
        flags.append("FALTA:" + ",".join(missing))
    present = [im for im in ims.values() if im is not None] or ([base] if base else [])
    if not present:
        return "SIN ARCHIVOS", flags
    sizes = sorted({im.size for im in present})
    if len(sizes) > 1:
        flags.append("TAMAÑOS_DISTINTOS")
    w, h = sizes[0]
    exp = EXPECTED_W.get(footprint)
    if exp and w != exp:
        flags.append(f"ANCHO_{w}!={exp}")
    if not wall:
        r0, r1, r2, r3 = (ims[r] for r in range(4))
        if same(r0, r2) or (r0 is not None and r2 is None):
            flags.append("SIN_VISTA_TRASERA")
        if r0 is not None and r1 is not None and not mirror(r0, r1) and not same(r0, r1):
            flags.append("rot1!=espejo")
        if same(r0, r1):
            flags.append("rot1=rot0(sin_girar)")
    else:
        if same(ims["n"], ims["w"]):
            flags.append("W=N(sin_espejo)")
        elif not mirror(ims["n"], ims["w"]):
            flags.append("W!=espejo(N)")
    ch = max(chunky(im) for im in present)
    if ch > 0.85:
        flags.append(f"PIXEL_2x({ch:.2f})")
    br = max(black_ratio(im) for im in present)
    if br > 0.04:
        flags.append(f"NEGRO_PURO({br:.0%})")
    bbox = present[0].getchannel("A").getbbox()
    return f"{w}x{h} bbox={bbox}", flags


def main():
    meta = sys.argv[1] if len(sys.argv) > 1 else None
    items = []
    if meta:
        for line in open(meta, encoding="utf-8"):
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 4:
                items.append((parts[0], parts[3]))
    else:
        cat = json.load(open(CATALOG, encoding="utf-8"))
        items = [(k, v.get("footprint", "1x1")) for k, v in cat.items()]
    for item_id, fp in sorted(items):
        info, flags = audit(item_id, fp)
        print(f"{item_id:24s} {fp:8s} {info:42s} {' '.join(flags)}")


if __name__ == "__main__":
    main()
