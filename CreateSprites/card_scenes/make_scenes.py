"""Stages for the fullscreen profile card's character face: one pixel-art scene per card theme.

Generated with PixelLab generate-image-v2 at the avatar's pixel scale (the avatar sprite is the style
reference), then given a selective outline and copied to frontend/assets/images/card_scenes/.

  python make_scenes.py --gen forest [--seed 7]   # one generation per call (~1 image at 160x288)
  python make_scenes.py --gen all                 # every theme without a generation yet
  python make_scenes.py --sheet                   # contact sheet of all generations -> gen/_sheet.png
  python make_scenes.py --build forest=forest_s7  # pick a generation: sel-out + copy to the app

Raw generations stay in gen/ so --build never spends credits. Scene geometry (the app relies on it):
160x288 px, the floor where the avatar stands at y=200, open space in the middle third.
"""
import base64
import io
import json
import os
import sys
import time

import requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # CreateSprites
REPO = os.path.dirname(ROOT)
GEN = os.path.join(HERE, "gen")
OUT = os.path.join(REPO, "frontend", "assets", "images", "card_scenes")
API = "https://api.pixellab.ai/v2"
SIZE = (160, 288)
FLOOR_Y = 200

COMMON = ("pixel art game background, front side view like a stage, no people, no characters, no text, "
          "no letters, the floor line runs across the image at about two thirds of the height, "
          "open empty space in the middle for a character to stand, objects on the left and right sides, "
          "cozy, detailed, selective outline")

SCENES = {
    "metal": "gothic castle hall at night, tall stained glass windows with deep purple glass and a red rose "
             "motif, dark stone brick walls, iron candelabras with lit candles, dark stone tile floor",
    "forest": "cozy forest clearing at night, tall dark pine trees on both sides, crescent moon and stars "
              "in a deep blue sky, glowing fireflies, mossy grass ground with small mushrooms",
    "coquette": "pastel pink cute bedroom, pink striped wallpaper, oval golden vanity mirror with a pink bow, "
                "little floating hearts, plush pink rug, mauve wooden floor",
    "cafe": "cozy specialty coffee shop interior at night, rainy window on the left, wooden shelves with "
            "cups, coffee bags and plants, warm hanging lamp, wooden counter with an espresso machine at the "
            "back, warm wooden floor",
    "arcade": "retro cyberpunk street at night, neon city skyline, glowing cyan and magenta signs, synthwave "
              "sun on the horizon, glowing neon grid floor",
    "mystic": "mystical witch study at night, huge golden full moon in an arched window, floating candles, "
              "crystals, potion bottles and tarot cards on shelves, starry deep blue walls, purple floor with "
              "a faint golden rune circle",
    "matcha": "calm japanese tea room in soft daylight, shoji paper sliding doors, bamboo by the window, low "
              "wooden table with a matcha tea set, light green tatami floor",
    "retro90s": "1990s teenager bedroom, memphis pattern wallpaper with teal squiggles and yellow triangles, "
                "CRT television on a stand, boombox, posters, cassette tapes, purple and teal checkered floor",
    "mono": "minimalist black and white photo studio, plain gray seamless backdrop, single soft spotlight "
            "from above, dust motes in the light, dark gray floor",
    "coast": "seaside at sunset, white and red lighthouse on a cliff on the left, calm sea, pink and orange "
             "sky, sandy beach with shells and a small boat",
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


def generate(theme, seed=None):
    os.makedirs(GEN, exist_ok=True)
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    style = Image.open(os.path.join(HERE, "style_ref.png"))
    payload = {
        "description": f"{SCENES[theme]}. {COMMON}",
        "image_size": {"width": SIZE[0], "height": SIZE[1]},
        "no_background": False,
        "style_image": {"image": _b64(style), "size": {"width": style.width, "height": style.height}},
        "style_options": {"color_palette": False, "outline": True, "detail": True, "shading": True},
    }
    if seed is not None:
        payload["seed"] = seed
    r = requests.post(f"{API}/generate-image-v2", headers=headers, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{r.status_code} {r.text[:500]}")
    data = r.json()
    print(theme, "usage:", data.get("usage"))
    job = data.get("background_job_id")
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
        raise RuntimeError(f"{theme}: job {job} still running; recover it later")
    images = data.get("images") or ([data["image"]] if data.get("image") else [])
    tag = f"s{seed}" if seed is not None else time.strftime("t%H%M%S")
    for i, s in enumerate(images):
        name = f"{theme}_{tag}" + (f"_{i}" if len(images) > 1 else "")
        _decode(s).save(os.path.join(GEN, name + ".png"))
        print("saved", name)


def sheet():
    files = sorted(f for f in os.listdir(GEN) if f.endswith(".png") and not f.startswith("_"))
    cols = 6
    w, h = SIZE[0] * 2, SIZE[1] * 2
    rows = (len(files) + cols - 1) // cols
    out = Image.new("RGBA", (cols * (w + 8) + 8, rows * (h + 24) + 8), (12, 14, 21, 255))
    from PIL import ImageDraw
    d = ImageDraw.Draw(out)
    for i, f in enumerate(files):
        im = Image.open(os.path.join(GEN, f)).convert("RGBA").resize((w, h), Image.NEAREST)
        x, y = 8 + (i % cols) * (w + 8), 8 + (i // cols) * (h + 24)
        out.paste(im, (x, y + 16))
        d.text((x, y), f[:-4], fill=(230, 230, 230, 255))
    out.save(os.path.join(GEN, "_sheet.png"))
    print("sheet:", len(files), "generations")


def build(theme, name):
    sys.path.insert(0, os.path.join(ROOT, "face_pipeline"))
    from convert_selout import convert_colour
    im = Image.open(os.path.join(GEN, name + ".png")).convert("RGBA")
    if im.size != SIZE:
        im = im.resize(SIZE, Image.NEAREST)
    os.makedirs(OUT, exist_ok=True)
    convert_colour(im).save(os.path.join(OUT, theme + ".png"))
    print("built", theme, "from", name)


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--gen" in args:
        which = args[args.index("--gen") + 1]
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        done = {f.split("_")[0] for f in os.listdir(GEN)} if os.path.isdir(GEN) else set()
        themes = [t for t in SCENES if t not in done] if which == "all" else which.split(",")
        for t in themes:
            generate(t, seed)
    elif "--sheet" in args:
        sheet()
    elif "--build" in args:
        for pair in args[args.index("--build") + 1:]:
            theme, name = pair.split("=")
            build(theme, name)
    else:
        print(__doc__)
