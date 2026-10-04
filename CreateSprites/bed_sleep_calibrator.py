"""
bed_sleep_calibrator.py - Calibrador de camas (acostarse) para OctoStudio.

Lee y escribe el mapa `_spots` de frontend/lib/features/lobby/data/bed_sleep_config.dart y
renderiza una vista previa idéntica a la del juego: capas OCTOPLAYER/Avatar/lying (160x128),
espejo para rot 1/3, cuerpo cortado en el borde de la cobija cuando está debajo, y los sprites
delanteros de furniture/sleep_overlays (cabecera/respaldo siempre, cobija con bulto si está debajo).
"""
import os
import re
from PIL import Image, ImageDraw

BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DART = os.path.join(BASE, "frontend", "lib", "features", "lobby", "data", "bed_sleep_config.dart")
IMAGES = os.path.join(BASE, "frontend", "assets", "images")
LYING = os.path.join(IMAGES, "OCTOPLAYER", "Avatar", "lying")
OVERLAYS = os.path.join(IMAGES, "furniture", "sleep_overlays")
FURN = os.path.join(IMAGES, "furniture", "established_furniture")

# Debe coincidir con BedSleepConfig.headInCanvas
HEAD_IN_CANVAS = {"a": (114, 40), "b": (47, 91)}
HAIR_STYLES = ["bangs", "braids", "comb_over", "flow", "long_flow", "twintails"]
AVATAR = os.path.join(IMAGES, "OCTOPLAYER", "Avatar")


def available_styles():
    """Lying styles present on disk (so new lying art shows up by itself), plus the standing
    accessories with a flag telling whether they have a lying version yet."""
    def stems(folder):
        d = os.path.join(LYING, folder)
        if not os.path.isdir(d):
            return []
        names = set()
        for f in os.listdir(d):
            m = re.match(r"(.+?)(?:_(?:male|female))?_lie[AB]\.png$", f)
            if m:
                names.add(m.group(1))
        return sorted(names)
    hair_dir = os.path.join(LYING, "hair")
    acc_dir = os.path.join(AVATAR, "accessories")
    accessories = sorted({re.sub(r"\d.*$", "", f[:-4]) for f in os.listdir(acc_dir)
                          if f.endswith(".png") and re.match(r"[a-z_]+\d\.png$", f)}) if os.path.isdir(acc_dir) else []
    lying_acc = set(stems("accessories"))
    return {
        "eyes": stems("eyes"), "mouth": stems("mouth"), "nose": stems("nose"),
        "hair": sorted(os.listdir(hair_dir)) if os.path.isdir(hair_dir) else HAIR_STYLES,
        "tops": stems("tops"), "bottoms": stems("bottoms"),
        "accessories": [(a, a in lying_acc) for a in accessories],
    }


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


DEFAULT_LOOK = {
    "body": "male", "eyes": "cateyes", "mouth": "smile", "nose": "standard", "hair": "comb_over",
    "tops": "jacket", "bottoms": "jeans", "accessories": "none",
    "skin": (0xF2, 0xC8, 0xA8), "hair_rgb": (0x3A, 0x26, 0x18), "eye_rgb": (0x2B, 0xB3, 0xA3),
    "brow_rgb": (0x3A, 0x2A, 0x22), "top_rgb": (0x2E, 0x2E, 0x33), "bottom_rgb": (0x26, 0x26, 0x2C),
}

_SPOT_RE = re.compile(
    r"(\d):\s*SleepSpot\(view:\s*LieView\.(a|b),\s*mirror:\s*(true|false),\s*"
    r"baseHead:\s*Offset\(([-\d.]+),\s*([-\d.]+)\),\s*maskRotation:\s*(\d),\s*"
    r"blanketEdge:\s*Offset\(([-\d.]+),\s*([-\d.]+)\),\s*coveredBelow:\s*(true|false)\)")
_MAP_START = "static const Map<String, Map<int, SleepSpot>> _spots = {"


# --------------------------------------------------------------------------- Dart I/O
def load_spots():
    """{bed_id: {rot: {"view","mirror","head":[x,y],"mask_rot"}}} leído de bed_sleep_config.dart."""
    src = open(DART, encoding="utf-8").read()
    start = src.index(_MAP_START) + len(_MAP_START)
    end = src.index("\n  };", start)
    spots, current = {}, None
    for line in src[start:end].splitlines():
        m_bed = re.match(r"\s*'([\w-]+)':\s*\{", line)
        if m_bed:
            current = m_bed.group(1); spots[current] = {}
            continue
        m = _SPOT_RE.search(line)
        if m and current:
            spots[current][int(m.group(1))] = {
                "view": m.group(2), "mirror": m.group(3) == "true",
                "head": [float(m.group(4)), float(m.group(5))], "mask_rot": int(m.group(6)),
                "edge": [float(m.group(7)), float(m.group(8))], "covered_below": m.group(9) == "true",
            }
    return spots


def _num(v):
    return str(int(v)) if float(v).is_integer() else f"{v:.1f}"


def dart_map_code(spots):
    lines = []
    for bed, rots in spots.items():
        lines.append(f"    '{bed}': {{")
        for r in sorted(rots):
            s = rots[r]
            lines.append(
                f"      {r}: SleepSpot(view: LieView.{s['view']}, mirror: {'true' if s['mirror'] else 'false'}, "
                f"baseHead: Offset({_num(s['head'][0])}, {_num(s['head'][1])}), maskRotation: {s['mask_rot']}, "
                f"blanketEdge: Offset({_num(s['edge'][0])}, {_num(s['edge'][1])}), "
                f"coveredBelow: {'true' if s['covered_below'] else 'false'}),")
        lines.append("    },")
    return "\n".join(lines)


def save_spots(spots):
    """Reescribe solo el cuerpo del mapa `_spots` (conserva comentarios y el resto del archivo)."""
    src = open(DART, encoding="utf-8").read()
    start = src.index(_MAP_START) + len(_MAP_START)
    end = src.index("\n  };", start)
    new_src = src[:start] + "\n" + dart_map_code(spots) + src[end:]
    with open(DART, "w", encoding="utf-8", newline="\n") as f:
        f.write(new_src)


# --------------------------------------------------------------------------- render
def _load(path):
    return Image.open(path).convert("RGBA") if os.path.exists(path) else None


def _tint(im, rgb):
    if im is None or rgb is None:
        return im
    r, g, b, a = im.split()
    r = r.point(lambda v: v * rgb[0] // 255)
    g = g.point(lambda v: v * rgb[1] // 255)
    b = b.point(lambda v: v * rgb[2] // 255)
    return Image.merge("RGBA", (r, g, b, a))


def _eyes(im, eye=(0x2B, 0xB3, 0xA3), brow=(0x3A, 0x2A, 0x22), skin=(0xF2, 0xC8, 0xA8)):
    """Mismo tinte por marcadores que _loadOctoEyesFrame (iris rojo, cejas verde, sombra azul)."""
    if im is None:
        return None
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            if r > g + 15 and r > b + 15:
                f = r / 255; px[x, y] = (int(eye[0] * f), int(eye[1] * f), int(eye[2] * f), a)
            elif g > r + 15 and g > b + 15:
                f = g / 255; px[x, y] = (int(brow[0] * f), int(brow[1] * f), int(brow[2] * f), a)
            elif b > r + 15 and b > g + 15 and b >= 40:
                k = (0.82, 0.70, 0.65) if b >= 180 else (0.60, 0.46, 0.42) if b >= 120 else None
                px[x, y] = (int(skin[0] * k[0]), int(skin[1] * k[1]), int(skin[2] * k[2]), a) if k else (32, 24, 38, a)
    return im


def _garment(folder, style, body, v, fallback):
    for name in (f"{style}_{body}_lie{v}", f"{style}_lie{v}", f"{fallback}_lie{v}"):
        im = _load(os.path.join(LYING, folder, f"{name}.png"))
        if im is not None:
            return im
    return None


def render_preview(bed_id, rot, spot, under=False, look=None, guides=True, **overrides):
    """Bed sprite + lying avatar exactly as the game draws it, at bed-sprite resolution.
    `look` = DEFAULT_LOOK-shaped dict (styles + colours); keyword overrides win over it."""
    look = {**DEFAULT_LOOK, **(look or {}), **overrides}
    body, hair, skin = look["body"], look["hair"], look["skin"]
    bed = _load(os.path.join(FURN, f"{bed_id}_rot{rot}.png"))
    if bed is None:
        raise FileNotFoundError(f"{bed_id}_rot{rot}.png")
    W, H = bed.size
    v = spot["view"].upper()
    hx, hy = HEAD_IN_CANVAS[spot["view"]]
    ox, oy = round(spot["head"][0] - hx), round(spot["head"][1] - hy)

    def layer(path_or_img, tint=None):
        im = path_or_img if isinstance(path_or_img, Image.Image) or path_or_img is None else _load(path_or_img)
        return _tint(im, tint)

    def styled(folder, style, fallback):   # same fallback as the game loader
        p = os.path.join(LYING, folder, f"{style}_lie{v}.png")
        return p if os.path.exists(p) else os.path.join(LYING, folder, f"{fallback}_lie{v}.png")

    eye_style = "closedeyes" if under else look["eyes"]   # asleep under the covers: always closed
    body_parts = [
        layer(os.path.join(LYING, "body", f"{body}_lie{v}.png"), skin),
        layer(styled("nose", look["nose"], "standard"), skin),
        layer(styled("mouth", look["mouth"], "catmouth")),
        _eyes(_load(styled("eyes", eye_style, "cateyes")), eye=look["eye_rgb"], brow=look["brow_rgb"], skin=skin),
        layer(_garment("bottoms", look["bottoms"], body, v, "jeans"), look["bottom_rgb"]) if look["bottoms"] != "none" else None,
        layer(_garment("tops", look["tops"], body, v, "jacket"), look["top_rgb"]) if look["tops"] != "none" else None,
    ]
    # Accessories have no lying art yet and the game does not draw them while lying.
    hair_img = layer(os.path.join(LYING, "hair", hair, f"{hair}_lie{v}.png"), look["hair_rgb"]) if hair != "none" else None

    def place(parts):
        canvas = Image.new("RGBA", (W, H))
        for p in parts:
            if p is not None:
                _composite_clipped(canvas, p, ox, oy)
        return canvas.transpose(Image.FLIP_LEFT_RIGHT) if spot["mirror"] else canvas

    if under:  # the body is not drawn past the blanket's folded edge (base, unmirrored coords)
        (ex, ey), below = spot["edge"], spot["covered_below"]
        cut = []
        for p in body_parts:
            if p is None:
                cut.append(None); continue
            p = p.copy(); px = p.load()
            for y in range(p.height):
                for x in range(p.width):
                    s = (x + ox - ex) - (y + oy - ey) * 2
                    if px[x, y][3] and ((s < 0) if below else (s > 0)):
                        px[x, y] = (0, 0, 0, 0)
            cut.append(p)
        body_parts = cut

    out = bed.copy()
    out.alpha_composite(place(body_parts))
    if hair_img is not None:
        out.alpha_composite(place([hair_img]))
    r = spot["mask_rot"]
    for kind in (["blanket"] if under else []) + ["front"]:
        ov = _load(os.path.join(OVERLAYS, f"{bed_id}_rot{r}_{kind}.png"))
        if ov is not None:
            out.alpha_composite(ov)

    if guides:
        d = ImageDraw.Draw(out)
        x, y = spot["head"]
        if spot["mirror"]:
            x = W - x
        d.line([(x - 4, y), (x + 4, y)], fill=(255, 60, 60, 255))
        d.line([(x, y - 4), (x, y + 4)], fill=(255, 60, 60, 255))
        # body axis: from the head toward the feet along the bed's long axis (2:1 isometric)
        sign_x = -1 if spot["view"] == "a" else 1
        if spot["mirror"]:
            sign_x = -sign_x
        sign_y = 1 if spot["view"] == "a" else -1
        d.line([(x, y), (x + sign_x * 120, y + sign_y * 60)], fill=(255, 60, 60, 120))
    return out


def _composite_clipped(canvas, part, ox, oy):
    """alpha_composite that tolerates parts hanging off the bed canvas."""
    tmp = Image.new("RGBA", canvas.size)
    tmp.paste(part, (ox, oy), part)
    canvas.alpha_composite(tmp)


def screen_nudge_to_base(spot, dx, dy):
    """A nudge in screen pixels -> change of the unmirrored baseHead."""
    return (-dx if spot["mirror"] else dx), dy


if __name__ == "__main__":
    s = load_spots()
    print({k: {r: v["head"] for r, v in rots.items()} for k, rots in s.items()})
    out = render_preview("single_high_bed", 0, s["single_high_bed"][0])
    out.resize((out.width * 3, out.height * 3), Image.NEAREST).save(os.path.join(os.path.dirname(__file__), "scratch", "_calib_test.png"))
