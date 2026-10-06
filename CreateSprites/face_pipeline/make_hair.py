"""New hairstyles with PixelLab edit-images-v2: the bald avatar in all 8 directions is edited in ONE
call ("add <hairstyle>"), so the same haircut comes out consistent across directions. The hair is
then the pixels PixelLab changed, turned to grayscale for the game's hairColor tint.

  python make_hair.py --generate STYLE [--seed N] [--dirs 1,2,3,8]   # PixelLab -> hair_gen/STYLE_*.png
  python make_hair.py --build STYLE                 # isolate + grayscale + front/back + walk + lying
  python make_hair.py --preview                     # sheet of every style in HAIRSTYLES

Short and medium styles fit the top 64x64 of the sprite (8 frames per call). Long styles need the
full 64x128 canvas, where PixelLab takes 4 frames per call (see LONG_SPLIT)."""
import base64
import io
import json
import os
import sys
import time

import requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
AV = os.path.join(ROOT, "..", "frontend", "assets", "images", "OCTOPLAYER", "Avatar")
GEN = os.path.join(HERE, "hair_gen")
sys.path.insert(0, ROOT)
sys.path.insert(0, HERE)
import octo_engine  # noqa: E402

API = "https://api.pixellab.ai/v2"
DIRS = list(range(1, 9))
HAIR_HINT = "dark brown hair"  # a colour far from skin and clothes makes the hair easy to isolate

# id -> label, audience, body used for generation, prompt, long (needs the full 64x128 canvas)
HAIRSTYLES = {
    "buzz": dict(label="Rapado", audience="neutral", body="male",
                 prompt="a very short buzz cut, hair cropped close to the scalp"),
    "afro": dict(label="Afro", audience="neutral", body="male",
                 prompt="a big round fluffy afro hairstyle"),
    # masculine
    "undercut": dict(label="Undercut", audience="masculine", body="male",
                     prompt="an undercut: very short shaved sides and a longer top swept back"),
    "messy": dict(label="Despeinado", audience="masculine", body="male",
                  prompt="short messy tousled textured hair with a few strands on the forehead"),
    "curly_short": dict(label="Rizos Cortos", audience="masculine", body="male",
                        prompt="short tight curly hair"),
    "spiky": dict(label="Puntas Anime", audience="masculine", body="male",
                  prompt="spiky anime style hair with pointed spikes"),
    "man_bun": dict(label="Moño Masculino", audience="masculine", body="male",
                    prompt="hair pulled back and tied in a small bun at the back of the head"),
    # feminine
    "bob": dict(label="Bob", audience="feminine", body="female",
                prompt="a sleek chin-length bob haircut with a side part"),
    "pixie": dict(label="Pixie", audience="feminine", body="female",
                  prompt="a short feminine pixie cut with side-swept bangs"),
    "space_buns": dict(label="Moños Dobles", audience="feminine", body="female",
                       prompt="two round space buns on top of the head, short bangs"),
    "ponytail": dict(label="Cola de Caballo", audience="feminine", body="female", long=True,
                     prompt="a high ponytail that hangs down to the middle of the back, bangs swept aside",
                     batches=[[1, 2, 3, 8], [4, 5, 6, 7]]),
    "wavy_long": dict(label="Ondas Largas", audience="feminine", body="female", long=True,
                      prompt="long wavy hair falling past the shoulders to the waist, parted in the middle",
                      batches=[[1, 2, 3, 8], [4, 5, 6, 7]]),
}


def _key():
    cwd = os.getcwd()
    os.chdir(ROOT)  # pixellab_config.json is relative
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


def bald(d, body, height):
    """The avatar without hair in direction d, cropped to the top `height` rows."""
    cfg = {"body": {"file": body, "color": "#FCD5B5"}, "head": {"file": "oval"}, "nose": {"file": "small"},
           "eyes": {"file": "cateyes", "color": "#059669"}, "mouth": {"file": "smile"},
           "hair": {"file": "none", "color": "#451A03"}, "tops": {"file": "jacket", "color": "#64748B"}}
    return octo_engine.compose_octo_avatar(cfg, direction=d).crop((0, 0, 64, height))


def generate(style, seed=None, only=None):
    """only: regenerate just the batch with these directions (e.g. one that came out wrong)."""
    spec = HAIRSTYLES[style]
    height = 128 if spec.get("long") else 64
    batches = spec.get("batches") or ([DIRS] if height == 64 else [[1, 2, 3, 4], [5, 6, 7, 8]])
    if only:
        batches = [only]
    os.makedirs(GEN, exist_ok=True)
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    for batch in batches:
        frames = [bald(d, spec["body"], height) for d in batch]
        for d, im in zip(batch, frames):
            im.save(os.path.join(GEN, f"_input_{style}_{d}.png"))
        payload = {
            "method": "edit_with_text",
            "edit_images": [{"image": _b64(im), "width": 64, "height": height} for im in frames],
            "image_size": {"width": 64, "height": height},
            "description": f"give the character {spec['prompt']}, {HAIR_HINT}; keep the face, body and "
                           "clothes exactly the same",
            "no_background": True,
        }
        if seed is not None:
            payload["seed"] = seed
        r = requests.post(f"{API}/edit-images-v2", headers=headers, json=payload, timeout=60)
        if r.status_code not in (200, 202):
            raise RuntimeError(f"{r.status_code} {r.text[:500]}")
        data = r.json()
        print("usage:", data.get("usage"))
        job = data.get("background_job_id")
        while job:
            time.sleep(8)
            j = requests.get(f"{API}/background-jobs/{job}", headers=headers, timeout=30).json()
            if j.get("status") == "completed":
                data = j.get("last_response", {})
                break
            if j.get("status") == "failed":
                raise RuntimeError(json.dumps(j)[:500])
        images = data.get("images") or []
        print(f"{style}: got {len(images)} images for dirs {batch}")
        for d, s in zip(batch, images):
            _decode(s).save(os.path.join(GEN, f"{style}_{d}.png"))


def _lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def _layer_mask(category, item, d, height):
    im = octo_engine.load_octo_layer(category, item, d)
    if im is None:
        return set()
    im = im.crop((0, 0, 64, height))
    return {(x, y) for y in range(height) for x in range(64) if im.getpixel((x, y))[3]}


def _components(pts):
    pts, out = set(pts), []
    while pts:
        stack = [pts.pop()]
        comp = list(stack)
        while stack:
            x, y = stack.pop()
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1),
                      (x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1)):
                if q in pts:
                    pts.remove(q)
                    stack.append(q)
                    comp.append(q)
        out.append(comp)
    return out


def align(gen, inp, top):
    """PixelLab may move the character a few pixels: shift gen so its silhouette below row `top`
    (body and clothes, no hair) matches the input best."""
    ga, ia = gen.split()[3].load(), inp.split()[3].load()
    w, h = gen.size
    best = None
    for dy in range(-4, 5):
        for dx in range(-8, 9):
            miss = 0
            for y in range(top, h):
                for x in range(w):
                    sx, sy = x - dx, y - dy
                    g = ga[sx, sy] > 128 if 0 <= sx < w and 0 <= sy < h else False
                    miss += g != (ia[x, y] > 128)
            if best is None or miss < best[0]:
                best = (miss, dx, dy)
    _, dx, dy = best
    return _shift(gen, dx, dy), (dx, dy)


def isolate(style, d, spec):
    """Hair pixels of PixelLab's output: changed vs the bald input, hair-coloured, on the head or
    outside the body (PixelLab also redraws the body and face a little), never over eyes/mouth/nose."""
    gen = Image.open(os.path.join(GEN, f"{style}_{d}.png")).convert("RGBA")
    inp = Image.open(os.path.join(GEN, f"_input_{style}_{d}.png")).convert("RGBA")
    h = gen.height
    gen, offset = align(gen, inp, top=46 if h == 64 else 90)
    if offset != (0, 0):
        print(f"  {style} dir {d}: aligned by {offset}")
    gp, ip = gen.load(), inp.load()
    head = _layer_mask("head", "oval", d, h)
    face = _layer_mask("eyes", "cateyes", d, h) | _layer_mask("mouth", "smile", d, h) | _layer_mask("nose", "small", d, h)
    long = spec.get("long")
    mask = set()
    for y in range(h):
        for x in range(64):
            g, i = gp[x, y], ip[x, y]
            if g[3] < 128 or (x, y) in face:
                continue
            dist = max(abs(g[c] - i[c]) for c in range(3)) if i[3] else 255
            skin_like = g[0] > 200 and g[1] > 150
            if skin_like or _lum(g) > 175:
                continue
            on_body = i[3] and (x, y) not in head
            if on_body:
                # over the body only long hair, told from the cool-toned jacket by its warm brown
                # (dark hair and the dark jacket differ little, so warmth decides, not distance)
                if not (long and g[0] - g[2] >= 12 and dist >= 15):
                    continue
            elif dist < 40:
                continue
            mask.add((x, y))
    # fill holes in long hair over the body: dark hair shadows can read as cool-toned
    for _ in range(3) if long else ():
        add = set()
        for y in range(h):
            for x in range(64):
                if (x, y) in mask or gp[x, y][3] < 128 or (x, y) in face:
                    continue
                around = sum((x + dx, y + dy) in mask for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                if around >= 5:
                    add.add((x, y))
        mask |= add
    # drop specks (repainted eyelashes, jacket seams): keep the big connected masses
    comps = sorted(_components(mask), key=len, reverse=True)
    keep = set()
    for c in comps:
        if len(c) >= 12 or (comps and c is comps[0]):
            keep |= set(c)
    return gen, keep


def to_gray(gen, mask):
    """Grayscale for the hairColor modulate tint, scaled so the median matches the shipped hair
    (~150), with a selective outline: dark rim pixels become a darker shade of their neighbours."""
    gp = gen.load()
    lums = sorted(_lum(gp[p]) for p in mask)
    mid = max(lums[len(lums) // 2], 1)
    gray = {p: min(205, round(_lum(gp[p]) * 150 / mid)) for p in mask}
    rim = {p for p in mask if any(q not in mask for q in ((p[0] + 1, p[1]), (p[0] - 1, p[1]),
                                                          (p[0], p[1] + 1), (p[0], p[1] - 1)))}
    out = Image.new("RGBA", gen.size)
    op = out.load()
    for (x, y), v in gray.items():
        if (x, y) in rim and _lum(gp[x, y]) < 40:
            inner = [gray[q] for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                     if q in gray and q not in rim]
            v = max(40, round(0.45 * (sum(inner) / len(inner) if inner else 150)))
        op[x, y] = (v, v, v, 255)
    return out


def split_front_back(hair, d, spec, height):
    """Back layer: long hair below the chin that lies outside the bald body silhouette, in the
    directions showing the face (the arms and body swing over it); everything else is front."""
    if not spec.get("long") or d in (4, 5, 6):
        return hair, None
    body = Image.open(os.path.join(GEN, f"_input_{spec['_style']}_{d}.png")).convert("RGBA").load()
    front, back = hair.copy(), Image.new("RGBA", hair.size)
    fp, bp = front.load(), back.load()
    for y in range(44, height):
        for x in range(64):
            if fp[x, y][3] and not body[x, y][3]:
                bp[x, y] = fp[x, y]
                fp[x, y] = (0, 0, 0, 0)
    return front, back if back.getbbox() else None


def _shift(im, dx, dy):
    out = Image.new("RGBA", im.size)
    out.paste(im, (dx, dy))
    return out


def build(style):
    from generate_face_walk_frames import HEAD_WALK_OFFSETS
    sys.path.insert(0, os.path.join(ROOT, "lying_pipeline"))
    import face_layers as fl
    spec = {**HAIRSTYLES[style], "_style": style}
    height = 128 if spec.get("long") else 64
    has_back = False
    layers = {}
    for d in DIRS:
        gen, mask = isolate(style, d, spec)
        front, back = split_front_back(to_gray(gen, mask), d, spec, height)
        for part, im in (("front", front), ("back", back)):
            canvas = Image.new("RGBA", (64, 128))
            if im is not None:
                canvas.alpha_composite(im, (0, 0))
                has_back |= part == "back"
            layers[(part, d)] = canvas
    for part in ("front", "back") if has_back else ("front",):
        folder = os.path.join(AV, "hair", style, part)
        os.makedirs(folder, exist_ok=True)
        for d in DIRS:
            im = layers[(part, d)]
            im.save(os.path.join(folder, f"{style}{d}.png"))
            for f, (dx, dy) in enumerate(HEAD_WALK_OFFSETS[d], start=1):
                _shift(im, dx, dy).save(os.path.join(folder, f"{style}{d}_walk_f{f}.png"))
    # Lying: the SW sprite mapped onto the lying head like the shipped short styles.
    os.makedirs(os.path.join(AV, "lying", "hair", style), exist_ok=True)
    for v, cfg in fl.VIEWS.items():
        # mapped straight onto the padded 160x128 lying canvas, so big styles (afro) are not clipped
        center = (cfg["center"][0] + 16, cfg["center"][1] + 16)
        place = lambda im: fl.map_feature(im, center, cfg["angle"], cfg["scale"], size=(160, 128))
        # Front layer only: the SW back layer is thin side strands, which mirrored onto the pillow
        # (fl.pillow_spread) stick out of the head like antennae.
        lying = Image.new("RGBA", (160, 128))
        lying.alpha_composite(place(layers[("front", fl.SRC_DIR)]))
        lying.save(os.path.join(AV, "lying", "hair", style, f"{style}_lie{v}.png"))
    print(f"{style}: built (back layer: {has_back})")


def preview(styles=None, out="_peinados.png"):
    from face_sheet import base_config
    styles = styles or list(HAIRSTYLES)
    Z = 3
    sheet = Image.new("RGB", (8 * 64 * Z, len(styles) * 2 * 64 * Z), (40, 42, 54))
    for r, st in enumerate(styles):
        for row, (body, skin, color) in enumerate(((HAIRSTYLES[st]["body"], "#FCD5B5", "#C85A2A"),
                                                   ("female" if HAIRSTYLES[st]["body"] == "male" else "male",
                                                    "#7A4522", "#1E293B"))):
            for c, d in enumerate(DIRS):
                cfg = base_config(body, skin, st)
                cfg["hair"]["color"] = color
                im = octo_engine.compose_octo_avatar(cfg, direction=d).crop((0, 0, 64, 64))
                im = im.resize((64 * Z, 64 * Z), Image.NEAREST)
                sheet.paste(im, (c * 64 * Z, (r * 2 + row) * 64 * Z), im)
    sheet.save(os.path.join(HERE, out))
    print("saved", out)


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--generate" in args:
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        only = [int(d) for d in args[args.index("--dirs") + 1].split(",")] if "--dirs" in args else None
        generate(args[args.index("--generate") + 1], seed, only)
    if "--build" in args:
        build(args[args.index("--build") + 1])
    if "--preview" in args:
        preview()
