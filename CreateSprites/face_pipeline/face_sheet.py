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

def sheet(rows, out, body="female", skin="#FCD5B5", hair="bangs"):
    """rows: list of (label, {layer: file}) overrides."""
    cw, ch = (CROP[2] - CROP[0]) * ZOOM, (CROP[3] - CROP[1]) * ZOOM
    img = Image.new("RGB", (120 + cw * len(DIRS), ch * len(rows)), (40, 42, 54))
    d = ImageDraw.Draw(img)
    for r, (label, over) in enumerate(rows):
        d.text((6, r * ch + ch // 2), label, fill=(230, 230, 230))
        for c, dr in enumerate(DIRS):
            cfg = base_config(body, skin, hair)
            for k, v in over.items():
                cfg[k] = {**cfg.get(k, {}), "file": v}
            av = octo_engine.compose_octo_avatar(cfg, direction=dr).crop(CROP)
            av = av.resize((cw, ch), Image.NEAREST)
            img.paste(av, (120 + c * cw, r * ch), av)
    img.save(out)
    print("saved", out)

if __name__ == "__main__":
    sheet([(s, {"eyes": s}) for s in ["cateyes", "relax", "closedeyes"]] +
          [(m, {"mouth": m}) for m in ["smile", "smirk", "catmouth", "biglips"]],
          "face_pipeline/_actuales.png")
