"""Bed overlay sprites, drawn IN FRONT of a lying avatar (like the chair *_front.png backrests):
  {bed}_rot{r}_front.png    head/footboard frame that is in front of the sleeper (always drawn)
  {bed}_rot{r}_blanket.png  the blanket from its folded edge to the foot, redrawn by PixelLab
                            with the body's bulge (drawn only while someone is under the covers)
Beds for two (several heads) also get {bed}_rot{r}_blanket{side}.png: that side's half of the
both-sleepers blanket (one bulge per half), so whoever lies on top of the other half is not hidden.
Only the both-sleepers blanket is generated: asked for a single sleeper, PixelLab moved the head to
the other pillow or to the foot end.
Rotations 1/3 are mirrors of 0/2. Output: frontend/assets/images/furniture/sleep_overlays/.

  python make_bed_overlays.py guides   [bed...] -> blanket guides (bed + avatar(s) under the covers)
  python make_bed_overlays.py generate [bed...] -> PixelLab redraws the blanket with the body bulge(s)
  python make_bed_overlays.py build    [bed...] -> front + blanket overlays into the game assets
Keep heads/EDGES in sync with BedSleepConfig (baseHead/blanketEdge) in bed_sleep_config.dart."""
import os, sys
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))
FURN = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/furniture/established_furniture"
DST = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/furniture/sleep_overlays"
WORK = os.path.join(OUT, "overlays")

def lum(p): return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]

dark_wood = lambda p: lum(p) < 80
# light gray metal: low saturation, darker than the white sheets
light_metal = lambda p: max(p[:3]) - min(p[:3]) < 28 and lum(p) < 215

# base rotation -> view, head per side (bed px, = BedSleepConfig.baseHead), blanket edge point, which
# side is covered ("below" = toward the camera / feet in view A, "above" = toward the back in view B),
# the region of the frame standing in front of the sleeper, and what counts as frame there.
BEDS = {
    "single_bed": {
        0: dict(view="A", heads=[(156, 36)], edge=(145, 42), covered="below", occluder=None, frame=dark_wood),
        2: dict(view="B", heads=[(64, 90)], edge=(76, 84), covered="above", occluder=lambda x, y: x < 72 and y > 60, frame=dark_wood),
    },
    "single_high_bed": {
        0: dict(view="A", heads=[(140, 25)], edge=(138, 42), covered="below", occluder=lambda x, y: x < 62 and y > 72, frame=dark_wood),
        2: dict(view="B", heads=[(55, 85)], edge=(64, 70), covered="above", occluder=lambda x, y: x < 68 and y > 44, frame=dark_wood),
    },
    # 2x2, two sides; the footboard (rot 0) / headboard (rot 2) spans the whole front-left edge
    "king_bed": {
        0: dict(view="A", heads=[(140, 41), (204, 73)], edge=(138, 58), covered="below",
                occluder=lambda x, y: x <= 130 and (y - 92) - (x - 4) / 2 >= -10, frame=light_metal),
        2: dict(view="B", heads=[(55, 101), (119, 133)], edge=(64, 86), covered="above",
                occluder=lambda x, y: x <= 130 and (y - 64) - (x - 4) / 2 >= -3, frame=light_metal,
                # the folded sheets at the far (foot) end read as pillows and PixelLab draws extra heads
                # there whatever the prompt says (tried 3 seeds, even naming the front/foot ends), so
                # only the blue blanket pixels of the generation are kept
                blanket_only=lambda p: p[2] > p[0] + 8),
    },
}

def covered(cfg, x, y, lip=0):
    """True on the blanket side of the edge line (shifted `lip` px toward the head)."""
    (ex, ey) = cfg["edge"]
    s = (x - ex) - (y - ey) * 2
    return s < 2 * lip if cfg["covered"] == "below" else s > -2 * lip

def half(cfg, side, x, y):
    """True when (x, y) is on [side]'s half of a bed for two: the side of the line along the long
    axis (2, -1) halfway between the heads where that side's head is (BedSleepConfig.sideAt)."""
    (ax, ay), (bx, by) = cfg["heads"]
    mx, my = (ax + bx) / 2, (ay + by) / 2
    cross = lambda qx, qy: 2 * (qy - my) + (qx - mx)
    return (cross(x, y) * cross(bx, by) > 0) == (side == 1)

def bed_sprite(bed, rot): return Image.open(f"{FURN}/{bed}_rot{rot}.png").convert("RGBA")

def bed_size(bed): return bed_sprite(bed, 0).size

def is_front_frame(cfg, px, x, y):
    """Frame-coloured bed pixel inside the front occluder region (transparent ones included: the
    blanket never covers them either)."""
    occ = cfg["occluder"]
    return occ is not None and occ(x, y) and cfg["frame"](px[x, y])

def front_sprite(bed, rot, cfg):
    sp = bed_sprite(bed, rot); px = sp.load(); out = Image.new("RGBA", sp.size); op = out.load()
    for y in range(sp.height):
        for x in range(sp.width):
            if px[x, y][3] and is_front_frame(cfg, px, x, y):
                op[x, y] = px[x, y]
    return out

def variants(cfg):
    """Which sides are under the covers in each blanket variant: '' = everyone, '0'/'1' = one side
    (cut from the '' generation)."""
    n = len(cfg["heads"])
    out = {"": list(range(n))}
    if n > 1:
        out.update({str(s): [s] for s in range(n)})
    return out

def guide(bed, rot, cfg, sides):
    """Bed + male avatar(s) under the covers on [sides] (body cut at the blanket edge) + front frame."""
    sys.path.insert(0, OUT)
    import export_final as ef
    W, H = bed_size(bed)
    av = ef.avatar(cfg["view"], "comb_over", awake=False, body="male")
    hx, hy = ef.HEAD[cfg["view"]]
    out = bed_sprite(bed, rot)
    for side in sorted(sides):                 # side 1 is nearer the camera: drawn last
        head = cfg["heads"][side]
        layer = Image.new("RGBA", (W, H)); layer.alpha_composite(av, (head[0] - hx, head[1] - hy))
        lp = layer.load()
        for y in range(H):
            for x in range(W):
                if lp[x, y][3] and covered(cfg, x, y):
                    lp[x, y] = (0, 0, 0, 0)
        out.alpha_composite(layer)
    out.alpha_composite(front_sprite(bed, rot, cfg))
    return out

KEEP = ("Keep the heads, pillows, bed frame, headboard, footboard, colors, size, position and pixel art style "
        "exactly the same.")

def prompt(n_heads, sides):
    if n_heads == 1:
        return ("A person is sleeping in this bed under the blanket; only the head on the pillow is visible. "
                "Redraw ONLY the blanket so it clearly shows the shape of the body underneath: a soft rounded bulge "
                "over the chest, hips and legs running along the bed toward the foot end, with the top of the blanket "
                "and sheet neatly folded over just below the chin. " + KEEP)
    if len(sides) > 1:
        return ("Two people are sleeping side by side in this double bed under one shared blanket; only their heads "
                "on the pillows are visible. Redraw ONLY the blanket so it clearly shows both bodies underneath: two "
                "soft rounded bulges, one per person, over the chest, hips and legs running along the bed toward the "
                "foot end, with the top of the blanket neatly folded over just below their chins. " + KEEP)
    raise ValueError("only the both-sleepers blanket is generated for beds for two")

def generate(only=None):
    import pl
    for bed, rots in BEDS.items():
        if only and bed not in only:
            continue
        W, H = bed_size(bed)
        for rot, cfg in rots.items():
            g = f"{WORK}/guide_{bed}_rot{rot}.png"
            pl._run("edit-images-v2", {
                "method": "edit_with_text",
                "edit_images": [{"image": pl.b64(g), "width": W, "height": H}],
                "image_size": {"width": W, "height": H},
                "description": prompt(len(cfg["heads"]), variants(cfg)[""]),
                "no_background": True, "seed": 131,
            }, f"overlays/blanket_{bed}_rot{rot}")

def blanket_sprite(bed, rot, cfg, tag="", sides=None):
    """Edited pixels on the covered side (+3px lip for the fold) that belong to the bed itself;
    for a one-side variant of a bed for two, only that side's half."""
    gen = Image.open(f"{WORK}/blanket_{bed}_rot{rot}_0.png").convert("RGBA"); gp = gen.load()
    sp = bed_sprite(bed, rot).load()
    out = Image.new("RGBA", gen.size); op = out.load()
    one_side = sides[0] if sides is not None and len(sides) == 1 and len(cfg["heads"]) > 1 else None
    for y in range(gen.height):
        for x in range(gen.width):
            g = gp[x, y]
            if not g[3] or not covered(cfg, x, y, lip=3):
                continue
            if is_front_frame(cfg, sp, x, y):
                continue                                  # the frame in front stays in the _front sprite
            if not sp[x, y][3] and not covered(cfg, x, y):
                continue                                  # the lip only exists over the bed itself
            if one_side is not None and not half(cfg, one_side, x, y):
                continue                                  # the other half keeps the plain bed sprite
            if "blanket_only" in cfg and not cfg["blanket_only"](g):
                continue
            op[x, y] = g[:3] + (255,)
    return out

def build(only=None):
    os.makedirs(DST, exist_ok=True)
    for bed, rots in BEDS.items():
        if only and bed not in only:
            continue
        for rot, cfg in rots.items():
            sprites = [("front", front_sprite(bed, rot, cfg))]
            sprites += [(f"blanket{tag}", blanket_sprite(bed, rot, cfg, tag, sides)) for tag, sides in variants(cfg).items()]
            for kind, im in sprites:
                im.save(f"{DST}/{bed}_rot{rot}_{kind}.png")
                im.transpose(Image.FLIP_LEFT_RIGHT).save(f"{DST}/{bed}_rot{rot + 1}_{kind}.png")
    print(sorted(os.listdir(DST)))

if __name__ == "__main__":
    os.makedirs(WORK, exist_ok=True)
    step = sys.argv[1] if len(sys.argv) > 1 else "build"
    only = sys.argv[2:] or None              # optional bed ids, e.g. `generate king_bed`
    if step == "guides":
        for bed, rots in BEDS.items():
            if only and bed not in only:
                continue
            for rot, cfg in rots.items():
                guide(bed, rot, cfg, variants(cfg)[""]).save(f"{WORK}/guide_{bed}_rot{rot}.png")
        print("guides ok")
    elif step == "generate":
        generate(only)
    else:
        build(only)
