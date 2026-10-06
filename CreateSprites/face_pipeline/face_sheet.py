"""Contact sheet of face styles on the in-game head: rows = styles, columns = visible directions."""
import sys
from PIL import Image, ImageDraw
sys.path.insert(0, r"C:/Users/Asus/ProyectoJuegoDating/CreateSprites")
import octo_engine

DIRS = [1, 2, 3, 7, 8]          # directions where the face is visible
CROP = (8, 4, 56, 52)            # head area of the 64x128 canvas
ZOOM = 6

def base_config(body="female", skin="#FCD5B5", hair="bangs"):
    return {"body": {"file": body, "color": skin}, "head": {"file": "oval"}, "nose": {"file": "small"},
            "eyes": {"file": "cateyes", "color": "#059669"}, "mouth": {"file": "smile"},
            "hair": {"file": hair, "color": "#451A03"}, "tops": {"file": "jacket", "color": "#DC2626"}}

AV = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/OCTOPLAYER/Avatar"


def tint(im, rgb):
    """Modulate like the game's ColorFilter (keeps alpha)."""
    r, g, b, a = im.split()
    return Image.merge("RGBA", (r.point(lambda v: v * rgb[0] // 255), g.point(lambda v: v * rgb[1] // 255),
                                b.point(lambda v: v * rgb[2] // 255), a))


def compose(cfg, d, overlays=(), makeup=None):
    """Avatar drawn in the game's face order: skin and clothes, then overlays (marks, blush:
    (path pattern, rgb or None)), mouth (+ lipstick), eyes (+ eyeshadow), front hair.
    makeup: {"eyeshadow": (style, rgb), "lipstick": (style, rgb)} painted like face_makeup.dart."""
    from color_engine import colorize_sprite, hex_to_rgb
    import makeup_preview as mk
    makeup = makeup or {}
    if not overlays and not makeup:
        return octo_engine.compose_octo_avatar(cfg, direction=d)
    bare_cfg = {**cfg, "eyes": {**cfg["eyes"], "file": "none"}, "mouth": {"file": "none"},
                "hair": {**cfg["hair"], "file": "none"}}
    out = octo_engine.compose_octo_avatar(bare_cfg, direction=d)
    for pattern, rgb in overlays:
        layer = Image.open(f"{AV}/{pattern.format(d=d)}").convert("RGBA")
        out.alpha_composite(tint(layer, rgb) if rgb else layer)
    mouth = octo_engine.load_octo_layer("mouth", cfg["mouth"]["file"], d)
    if mouth:
        mouth = mouth.copy()
        if "lipstick" in makeup:
            style, rgb = makeup["lipstick"]
            mk.paint_lipstick(mouth, (0, -1), rgb, bold=style == "lip_bold")
        out.alpha_composite(mouth)
    hair_rgb, skin_rgb = hex_to_rgb(cfg["hair"]["color"]), hex_to_rgb(cfg["body"]["color"])
    raw = octo_engine.load_octo_layer("eyes", cfg["eyes"]["file"], d)
    if raw:
        eyes = colorize_sprite(raw.copy(), hex_to_rgb(cfg["eyes"]["color"]), category="eyes",
                               eyebrow_rgb=hair_rgb, skin_rgb=skin_rgb)
        if "eyeshadow" in makeup:
            style, rgb = makeup["eyeshadow"]
            mk.paint(eyes, mk.eyeshadow_targets(raw, (0, -1), smoky=style == "shadow_smoky"), rgb)
        out.alpha_composite(eyes)
    front = octo_engine.load_octo_layer("hair", cfg["hair"]["file"], d, sub_type="front")
    if front:
        out.alpha_composite(colorize_sprite(front.copy(), hair_rgb, category="hair"))
    return out


def sheet(rows, out, body="female", skin="#FCD5B5", hair="bangs"):
    """rows: list of (label, {layer: file}) overrides; an "overlays" key holds compose() overlays."""
    cw, ch = (CROP[2] - CROP[0]) * ZOOM, (CROP[3] - CROP[1]) * ZOOM
    img = Image.new("RGB", (120 + cw * len(DIRS), ch * len(rows)), (40, 42, 54))
    d = ImageDraw.Draw(img)
    for r, (label, over) in enumerate(rows):
        d.text((6, r * ch + ch // 2), label, fill=(230, 230, 230))
        for c, dr in enumerate(DIRS):
            cfg = base_config(body, skin, hair)
            for k, v in over.items():
                if k not in ("overlays", "makeup"):
                    cfg[k] = {**cfg.get(k, {}), "file": v}
            av = compose(cfg, dr, over.get("overlays", ()), over.get("makeup")).crop(CROP)
            av = av.resize((cw, ch), Image.NEAREST)
            img.paste(av, (120 + c * cw, r * ch), av)
    img.save(out)
    print("saved", out)

if __name__ == "__main__":
    sheet([(s, {"eyes": s}) for s in ["cateyes", "relax", "closedeyes"]] +
          [(m, {"mouth": m}) for m in ["smile", "smirk", "catmouth", "biglips"]],
          "face_pipeline/_actuales.png")
