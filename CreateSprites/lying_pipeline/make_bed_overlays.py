"""Bed overlay sprites, drawn IN FRONT of a lying avatar (like the chair *_front.png backrests):
  {bed}_rot{r}_front.png    head/footboard wood that is in front of the sleeper (always drawn)
  {bed}_rot{r}_blanket.png  the blanket from its folded edge to the foot, redrawn by PixelLab
                            with the body's bulge (drawn only while someone is under the covers)
Rotations 1/3 are mirrors of 0/2. Output: frontend/assets/images/furniture/sleep_overlays/.

  python make_bed_overlays.py guides    -> blanket guides (bed + avatar under the covers)
  python make_bed_overlays.py generate  -> PixelLab redraws the blanket with the body bulge
  python make_bed_overlays.py build     -> front + blanket overlays into the game assets
Keep EDGES in sync with BedSleepConfig (blanketEdge) in bed_sleep_config.dart."""
import os, sys
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))
FURN = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/furniture/established_furniture"
DST = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/furniture/sleep_overlays"
WORK = os.path.join(OUT, "overlays")

# base rotation -> view, head (bed px, = BedSleepConfig.baseHead), blanket edge point, which side is
# covered ("below" = toward the camera / feet in view A, "above" = toward the back in view B), and
# the dark frame wood standing in front of the sleeper.
BEDS = {
    "single_bed": {
        0: dict(view="A", head=(156, 36), edge=(145, 42), covered="below", occluder=None),
        2: dict(view="B", head=(64, 90), edge=(76, 84), covered="above", occluder=lambda x, y: x < 72 and y > 60),
    },
    "single_high_bed": {
        0: dict(view="A", head=(140, 25), edge=(138, 42), covered="below", occluder=lambda x, y: x < 62 and y > 72),
        2: dict(view="B", head=(55, 85), edge=(64, 70), covered="above", occluder=lambda x, y: x < 68 and y > 44),
    },
}

def lum(p): return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]

def covered(cfg, x, y, lip=0):
    """True on the blanket side of the edge line (shifted `lip` px toward the head)."""
    (ex, ey) = cfg["edge"]
    s = (x - ex) - (y - ey) * 2
    return s < 2 * lip if cfg["covered"] == "below" else s > -2 * lip

def bed_sprite(bed, rot): return Image.open(f"{FURN}/{bed}_rot{rot}.png").convert("RGBA")

def front_sprite(bed, rot, cfg):
    sp = bed_sprite(bed, rot); px = sp.load(); out = Image.new("RGBA", sp.size); op = out.load()
    occ = cfg["occluder"]
    if occ is None:
        return out
    for y in range(sp.height):
        for x in range(sp.width):
            p = px[x, y]
            if p[3] and occ(x, y) and lum(p) < 80:
                op[x, y] = p
    return out

def guide(bed, rot, cfg):
    """Bed + male avatar under the covers (body cut at the blanket edge) + front wood."""
    sys.path.insert(0, OUT)
    import export_final as ef
    av = ef.avatar(cfg["view"], "comb_over", awake=False, body="male")
    hx, hy = ef.HEAD[cfg["view"]]
    layer = Image.new("RGBA", (192, 144)); layer.alpha_composite(av, (cfg["head"][0] - hx, cfg["head"][1] - hy))
    lp = layer.load()
    for y in range(144):
        for x in range(192):
            if lp[x, y][3] and covered(cfg, x, y):
                lp[x, y] = (0, 0, 0, 0)
    out = bed_sprite(bed, rot); out.alpha_composite(layer); out.alpha_composite(front_sprite(bed, rot, cfg))
    return out

def generate():
    import pl
    for bed, rots in BEDS.items():
        for rot in rots:
            g = f"{WORK}/guide_{bed}_rot{rot}.png"
            pl._run("edit-images-v2", {
                "method": "edit_with_text",
                "edit_images": [{"image": pl.b64(g), "width": 192, "height": 144}],
                "image_size": {"width": 192, "height": 144},
                "description": (
                    "A person is sleeping in this bed under the blanket; only the head on the pillow is visible. "
                    "Redraw ONLY the blanket so it clearly shows the shape of the body underneath: a soft rounded bulge "
                    "over the chest, hips and legs running along the bed toward the foot end, with the top of the blanket "
                    "and sheet neatly folded over just below the chin. Keep the head, pillow, bed frame, headboard, "
                    "footboard, colors, size, position and pixel art style exactly the same."),
                "no_background": True, "seed": 131,
            }, f"overlays/blanket_{bed}_rot{rot}")

def blanket_sprite(bed, rot, cfg):
    """Edited pixels on the covered side (+3px lip for the fold) that belong to the bed itself."""
    gen = Image.open(f"{WORK}/blanket_{bed}_rot{rot}_0.png").convert("RGBA"); gp = gen.load()
    sp = bed_sprite(bed, rot).load()
    out = Image.new("RGBA", gen.size); op = out.load()
    occ = cfg["occluder"]
    for y in range(gen.height):
        for x in range(gen.width):
            g = gp[x, y]
            if not g[3] or not covered(cfg, x, y, lip=3):
                continue
            if occ is not None and occ(x, y) and lum(sp[x, y]) < 80:
                continue                                  # the wood in front stays in the _front sprite
            if not sp[x, y][3] and not covered(cfg, x, y):
                continue                                  # the lip only exists over the bed itself
            op[x, y] = g[:3] + (255,)
    return out

def build():
    os.makedirs(DST, exist_ok=True)
    for bed, rots in BEDS.items():
        for rot, cfg in rots.items():
            for kind, im in (("front", front_sprite(bed, rot, cfg)), ("blanket", blanket_sprite(bed, rot, cfg))):
                im.save(f"{DST}/{bed}_rot{rot}_{kind}.png")
                im.transpose(Image.FLIP_LEFT_RIGHT).save(f"{DST}/{bed}_rot{rot + 1}_{kind}.png")
    print(sorted(os.listdir(DST)))

if __name__ == "__main__":
    os.makedirs(WORK, exist_ok=True)
    step = sys.argv[1] if len(sys.argv) > 1 else "build"
    if step == "guides":
        for bed, rots in BEDS.items():
            for rot, cfg in rots.items():
                guide(bed, rot, cfg).save(f"{WORK}/guide_{bed}_rot{rot}.png")
        print("guides ok")
    elif step == "generate":
        generate()
    else:
        build()
