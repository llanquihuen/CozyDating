"""Builds lying face layers (eyes / nose / mouth) by mapping the existing front-facing (dir 1)
feature sprites onto the lying head with a rotation + scale, so every current and future
style works automatically and matches what the player picked in the creator."""
import math, os
from PIL import Image

AV = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/OCTOPLAYER/Avatar"
OUT = os.path.dirname(os.path.abspath(__file__))
FACE_SRC = (32, 36)          # anchor on the standing 64x128 sprite: head-centred, so 3/4 offsets survive
SRC_DIR = 8                  # SW 3/4 view: face shifted left, ear on the right, like the lying head

# Per view: face center on the 128x96 lying canvas, rotation (deg, clockwise = face "down" turns
# toward +x), and scale. Tuned visually against the faceless bodies.
VIEWS = {
    "A": dict(center=(103, 28), angle=15, scale=0.85),
    "B": dict(center=(35.5, 70.5), angle=225, scale=0.85),
}

HAIR = {  # style -> has back layer (AvatarConfig.hairsWithBack)
    "bangs": False, "braids": False, "comb_over": False,
    "flow": True, "long_flow": True, "twintails": True,
}

STYLES = {
    "eyes": ["cateyes", "closedeyes", "relax"],
    "mouth": ["biglips", "catmouth", "smile", "smirk"],
    "nose": ["small", "standard"],
}

def map_feature(src, center, angle, scale, size=(128, 96), ss=4):
    """Rotate+scale with supersampling: map at ss x resolution, then each ss*ss block keeps its
    most common opaque colour if at least 3 of its sub-pixels are covered (keeps 1px lines whole)."""
    a = math.radians(angle)
    c, s = math.cos(a), math.sin(a)
    sp = src.load()
    out = Image.new("RGBA", size); op = out.load()
    for y in range(size[1]):
        for x in range(size[0]):
            hits = {}
            for sy in range(ss):
                for sx in range(ss):
                    dx = (x + (sx + 0.5) / ss - 0.5 - center[0]) / scale
                    dy = (y + (sy + 0.5) / ss - 0.5 - center[1]) / scale
                    u = c * dx + s * dy + FACE_SRC[0]
                    v = -s * dx + c * dy + FACE_SRC[1]
                    ui, vi = math.floor(u + 0.5), math.floor(v + 0.5)
                    if 0 <= ui < src.width and 0 <= vi < src.height and sp[ui, vi][3]:
                        hits[sp[ui, vi]] = hits.get(sp[ui, vi], 0) + 1
            if sum(hits.values()) >= 3:
                op[x, y] = max(hits, key=hits.get)
    return out

def build(view, cfg=None):
    cfg = cfg or VIEWS[view]
    layers = {}
    for cat, styles in STYLES.items():
        for st in styles:
            src = Image.open(f"{AV}/{cat}/{st}{SRC_DIR}.png").convert("RGBA")
            layers[(cat, st)] = map_feature(src, cfg["center"], cfg["angle"], cfg["scale"])
    return layers

HEAD_CY = 28                 # vertical centre of head/oval on the standing sprite

def pillow_spread(src):
    out = Image.new("RGBA", src.size); sp, op = src.load(), out.load()
    for y in range(src.height):
        ny = 2 * HEAD_CY - y
        if 0 <= ny < src.height:
            for x in range(src.width):
                if sp[x, y][3]: op[x, ny] = sp[x, y]
    return out

def build_hair(view, cfg=None):
    """Same transform as the face so hair, head and features stay aligned."""
    cfg = cfg or VIEWS[view]
    layers = {}
    for st, has_back in HAIR.items():
        for part in ("front", "back") if has_back else ("front",):
            src = Image.open(f"{AV}/hair/{st}/{part}/{st}{SRC_DIR}.png").convert("RGBA")
            if part == "back":
                # standing back hair hangs below the head; lying on the back it spreads on the
                # pillow beyond the crown -> mirror it vertically about the head centre
                src = pillow_spread(src)
            layers[(part, st)] = map_feature(src, cfg["center"], cfg["angle"], cfg["scale"])
    return layers

if __name__ == "__main__":
    os.makedirs(f"{OUT}/layers/face", exist_ok=True)
    for v in VIEWS:
        for (cat, st), im in build(v).items():
            im.save(f"{OUT}/layers/face/{st}_lie{v}.png")
        for (part, st), im in build_hair(v).items():
            os.makedirs(f"{OUT}/layers/hair/{st}/{part}", exist_ok=True)
            im.save(f"{OUT}/layers/hair/{st}/{part}/{st}_lie{v}.png")
    print("ok")
