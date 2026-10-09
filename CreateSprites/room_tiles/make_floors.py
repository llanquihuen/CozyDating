"""Isometric floor tiles for the lobby room, at the furniture's pixel density.

A floor tile is the 64x32-unit diamond drawn at 0.5 units per pixel: a 128x64 px sprite, the same
pixel size as the furniture (128 px per tile drawn at 0.5x). Generated with PixelLab create-tiles-pro
(tile_type isometric, flat top-down), several variants per material in one call; the room picks a
variant per tile with a fixed hash.

  python make_floors.py --gen oak_parquet [--seed 3]   # one call = several variants
  python make_floors.py --gen all                      # every material without a generation yet
  python make_floors.py --sheet                        # contact sheet (variants + a tiled 4x4 floor)
  python make_floors.py --build oak_parquet=oak_parquet_s3[:0,1,2,3]   # pick variants -> app

Raw generations stay in gen/ so --build never spends credits. Output:
frontend/assets/images/floors/tiles/<id>_v<n>.png (128x64, diamond, transparent outside), and
tiles.json with the variant count of each id.
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
OUT = os.path.join(REPO, "frontend", "assets", "images", "floors", "tiles")
API = "https://api.pixellab.ai/v2"
W, H = 128, 64

COMMON = ("seamless isometric floor tile for a cozy pixel art bedroom, the pattern continues across the "
          "tile edges so neighbouring tiles join without seams, flat, no objects, no border, soft shading")

# id -> material. Ids match RoomThemes floor ids (room_config.dart); solid_* are gray bases tinted
# in the app with BlendMode.modulate, so they must stay neutral light gray.
FLOORS = {
    "oak_parquet": "warm honey oak wooden parquet, long planks running diagonally, subtle wood grain",
    "dark_walnut": "dark walnut wooden floor, long dark brown planks, subtle grain",
    "checker_marble": "checkered floor of white and black marble squares, two by two squares per tile",
    "terracotta_tiles": "rustic terracotta clay floor tiles, warm orange red, thin light grout lines",
    "tatami_mat": "japanese tatami mat, light green woven straw with a dark green fabric border",
    "solid_tiles": "plain light gray ceramic floor tiles, four square tiles with thin grout lines, "
                   "neutral gray only, no color",
    "solid_carpet": "plain light gray soft carpet, fine fibre texture, neutral gray only, no color",
}


# Gray bases are tinted in the app (modulate), so every variant is made neutral gray with the same
# mean as the old stretched textures (floor_solid_*.png) to keep the tint colours unchanged.
GRAY_MEAN = {"solid_tiles": 208, "solid_carpet": 214}
# Materials without joints: the tile's edge line PixelLab draws would show the grid.
SEAMLESS = {"solid_carpet"}


def _key():
    cwd = os.getcwd()
    os.chdir(ROOT)  # pixellab_config.json is relative
    sys.path.insert(0, ROOT)
    try:
        from pixellab_service import load_pixellab_key
        return load_pixellab_key()
    finally:
        os.chdir(cwd)


def generate(fid, seed=None):
    os.makedirs(GEN, exist_ok=True)
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    payload = {
        "description": f"{FLOORS[fid]}. {COMMON}",
        "tile_type": "isometric",
        "tile_size": W,
        "tile_height": H,
        "tile_view_angle": 30.0,
        "tile_depth_ratio": 0.0,
        "outline_mode": "segmentation",
    }
    if seed is not None:
        payload["seed"] = seed
    r = requests.post(f"{API}/create-tiles-pro", headers=headers, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{r.status_code} {r.text[:500]}")
    data = r.json()
    print(fid, "usage:", data.get("usage"))
    tile_id = data.get("tile_id") or data.get("id")
    job = data.get("background_job_id")
    for _ in range(60):
        time.sleep(6)
        try:
            if tile_id:
                rr = requests.get(f"{API}/tiles-pro/{tile_id}", headers=headers, timeout=30)
                if rr.status_code == 423:
                    continue
                res = rr.json()
                if res.get("storage_urls"):
                    break
            else:
                j = requests.get(f"{API}/background-jobs/{job}", headers=headers, timeout=30).json()
                if j.get("status") == "completed":
                    res = j.get("last_response", {})
                    break
                if j.get("status") == "failed":
                    raise RuntimeError(json.dumps(j)[:500])
        except requests.RequestException:
            continue
    else:
        raise RuntimeError(f"{fid}: {tile_id or job} still running; recover it later")
    tag = f"s{seed}" if seed is not None else time.strftime("t%H%M%S")
    urls = res["storage_urls"]
    for i, (k, url) in enumerate(sorted(urls.items(), key=lambda kv: int(kv[0].split("_")[-1]))):
        im = Image.open(io.BytesIO(requests.get(url, timeout=60).content)).convert("RGBA")
        name = f"{fid}_{tag}_{i}"
        im.save(os.path.join(GEN, name + ".png"))
        print("saved", name, im.size)


def diamond_mask():
    """The room's tile diamond in a 128x64 sprite: corners at (0,32), (64,0), (128,32), (64,64)."""
    m = Image.new("L", (W, H), 0)
    px = m.load()
    for y in range(H):
        for x in range(W):
            # pixel centre inside |dx|/64 + |dy|/32 <= 1
            if abs(x + 0.5 - 64) / 64 + abs(y + 0.5 - 32) / 32 <= 1.0:
                px[x, y] = 255
    return m


def fit(im):
    """Crop a generation to its opaque diamond and fit it to the 128x64 tile."""
    bbox = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if bbox:
        im = im.crop(bbox)
    if im.size != (W, H):
        im = im.resize((W, H), Image.NEAREST)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(im, (0, 0), diamond_mask())
    # fill any transparent pixel left inside the diamond from its neighbour
    px, m = out.load(), diamond_mask().load()
    for y in range(H):
        for x in range(W):
            if m[x, y] and px[x, y][3] < 255:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] == 255:
                        px[x, y] = px[nx, ny]
                        break
    return out


def drop_edge(im, band=3):
    """Repaint the outer `band` rows of the diamond from just inside it (no edge line)."""
    src, out = im.load(), im.copy()
    px = out.load()
    r0 = 1 - band / (H / 2)
    for y in range(H):
        for x in range(W):
            dx, dy = x + 0.5 - W / 2, y + 0.5 - H / 2
            r = abs(dx) / (W / 2) + abs(dy) / (H / 2)
            if r0 < r <= 1:
                k = (r0 - 0.02) / r
                px[x, y] = src[int(W / 2 + dx * k), int(H / 2 + dy * k)]
    return out


def neutral(im, mean):
    """Neutral gray version of a tile whose opaque pixels average `mean`."""
    gray, alpha = im.convert("L"), im.getchannel("A")
    vals = [g for g, a in zip(gray.getdata(), alpha.getdata()) if a]
    k = mean / (sum(vals) / len(vals))
    gray = gray.point(lambda g: max(0, min(255, round(g * k))))
    out = Image.merge("RGBA", (gray, gray, gray, alpha))
    return out


def tiled(tiles, n=4):
    """A floor of n x n tiles laid like the room (variant by the same hash the app uses)."""
    img = Image.new("RGBA", (W * n, H * n), (20, 22, 30, 255))
    for gy in range(n):
        for gx in range(n):
            t = tiles[variant(gx, gy, len(tiles))]
            sx = (gx - gy) * W // 2 + (n - 1) * W // 2
            sy = (gx + gy) * H // 2
            img.alpha_composite(t, (sx, sy))
    return img


def variant(gx, gy, n):
    """Same hash as _floorVariant in cozy_room_game.dart."""
    h = (gx * 73856093) ^ (gy * 19349663)
    return (h & 0x7FFFFFFF) % n


def sheet():
    files = sorted(f for f in os.listdir(GEN) if f.endswith(".png") and not f.startswith("_"))
    groups = {}
    for f in files:
        groups.setdefault(f.rsplit("_", 1)[0], []).append(f)
    rows = []
    for g, fs in groups.items():
        tiles = [fit(Image.open(os.path.join(GEN, f)).convert("RGBA")) for f in fs]
        row = Image.new("RGBA", (len(tiles) * (W + 8) + W * 4 + 16, H * 4 + 20), (12, 14, 21, 255))
        d = ImageDraw.Draw(row)
        d.text((4, 2), g + f"  ({len(tiles)})", fill=(230, 230, 230, 255))
        for i, t in enumerate(tiles):
            row.alpha_composite(t, (8 + i * (W + 8), 20))
            d.text((8 + i * (W + 8), 20 + H + 2), str(i), fill=(200, 200, 200, 255))
        row.alpha_composite(tiled(tiles), (len(tiles) * (W + 8) + 8, 16))
        rows.append(row)
    w = max(r.width for r in rows)
    out = Image.new("RGBA", (w, sum(r.height for r in rows)), (12, 14, 21, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    out = out.resize((out.width * 2, out.height * 2), Image.NEAREST)
    out.save(os.path.join(GEN, "_sheet.png"))
    print("sheet:", len(groups), "generations")


def build(fid, spec):
    name, _, picks = spec.partition(":")
    files = sorted(f for f in os.listdir(GEN) if f.startswith(name + "_") and f.endswith(".png"))
    if picks:
        files = [f"{name}_{i}.png" for i in picks.split(",")]
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.startswith(fid + "_v"):
            os.remove(os.path.join(OUT, old))
    for n, f in enumerate(files):
        tile = fit(Image.open(os.path.join(GEN, f)).convert("RGBA"))
        if fid in SEAMLESS:
            tile = drop_edge(tile)
        if fid in GRAY_MEAN:
            tile = neutral(tile, GRAY_MEAN[fid])
        tile.save(os.path.join(OUT, f"{fid}_v{n}.png"))
    write_manifest()
    print("built", fid, "x", len(files), "from", name)


def write_manifest():
    """tiles.json: variant count per tile key, read by the app (FloorTiles.load)."""
    counts = {}
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png") and "_v" in f:
            key = f.rsplit("_v", 1)[0]
            counts[key] = counts.get(key, 0) + 1
    with open(os.path.join(OUT, "tiles.json"), "w", encoding="utf-8") as fh:
        json.dump(counts, fh, indent=2, sort_keys=True)
        fh.write("\n")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--gen" in args:
        which = args[args.index("--gen") + 1]
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        done = {f.rsplit("_", 2)[0] for f in os.listdir(GEN)} if os.path.isdir(GEN) else set()
        ids = [f for f in FLOORS if f not in done] if which == "all" else which.split(",")
        for f in ids:
            generate(f, seed)
    elif "--sheet" in args:
        sheet()
    elif "--build" in args:
        for pair in args[args.index("--build") + 1:]:
            fid, spec = pair.split("=")
            build(fid, spec)
    else:
        print(__doc__)
