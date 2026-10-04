"""Turns the PixelLab outputs into game-format layers (grayscale, tinted at runtime with modulate)
and previews them on single_bed in its 4 rotations (A, A mirrored, B, B mirrored), on top / under."""
import os, sys
from collections import deque
from PIL import Image
sys.path.insert(0, r"C:/Users/Asus/ProyectoJuegoDating/CreateSprites")
from pixellab_service import isolate_layer_from_base

OUT = os.path.dirname(os.path.abspath(__file__))
LAYERS = os.path.join(OUT, "layers")
BED = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/furniture/established_furniture/single_bed_rot{}.png"
os.makedirs(LAYERS, exist_ok=True)

def load(name): return Image.open(os.path.join(OUT, name)).convert("RGBA")

def drop_white_bg(im):
    """Flood-fill near-white background from the borders (edit-images-v2 sometimes ignores no_background)."""
    im = im.copy(); px = im.load(); w, h = im.size
    q = deque((x, y) for x in range(w) for y in (0, h - 1)); q.extend((x, y) for y in range(h) for x in (0, w - 1))
    seen = set()
    while q:
        x, y = q.popleft()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h): continue
        seen.add((x, y))
        r, g, b, a = px[x, y]
        if a == 0 or (r > 225 and g > 225 and b > 225):
            px[x, y] = (0, 0, 0, 0)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    for y in range(h):  # stray specks left by the background
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and r > 225 and g > 225 and b > 225: px[x, y] = (0, 0, 0, 0)
    return im

def to_raw(im, ref_lum):
    """Grayscale so that modulate(tint) reproduces the shading. ref_lum = luminance that should map to 255."""
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                v = min(255, round((0.299 * r + 0.587 * g + 0.114 * b) * 255 / ref_lum))
                px[x, y] = (v, v, v, a)
    return im

def tint(im, t):
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a: px[x, y] = (r * t[0] // 255, g * t[1] // 255, b * t[2] // 255, a)
    return im


def isolate_cloth(gen, base, head, r=20):
    """Garment pixels: a core of changed, non-skin, non-outline pixels outside the head,
    grown by 2px into changed dark pixels so the garment keeps its own outline."""
    g, b = gen.convert("RGBA"), base.convert("RGBA")
    gp, bp = g.load(), b.load(); W, H = g.size
    def changed(x, y):
        r_, g_, b_, a = gp[x, y]; br, bg, bb, ba = bp[x, y]
        return a and (not ba or ((r_ - br) ** 2 + (g_ - bg) ** 2 + (b_ - bb) ** 2) ** 0.5 > 35)
    def lum(x, y):
        r_, g_, b_, _ = gp[x, y]; return 0.299 * r_ + 0.587 * g_ + 0.114 * b_
    def skin(x, y):
        r_, g_, b_, _ = gp[x, y]; return r_ > g_ > b_ and r_ - b_ > 25 and lum(x, y) > 90
    in_head = lambda x, y: (x - head[0]) ** 2 + (y - head[1]) ** 2 < r * r
    keep = {(x, y) for y in range(H) for x in range(W)
            if changed(x, y) and not skin(x, y) and 22 <= lum(x, y) <= 200 and not in_head(x, y)}
    for _ in range(2):
        grow = {(x + dx, y + dy) for x, y in keep for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))}
        keep |= {(x, y) for x, y in grow if 0 <= x < W and 0 <= y < H and changed(x, y)
                 and lum(x, y) < 22 and not in_head(x, y)}
    # drop specks: connected components smaller than 6 px
    comps, seen = [], set()
    for p in keep:
        if p in seen: continue
        stack, comp = [p], []
        seen.add(p)
        while stack:
            x, y = stack.pop(); comp.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in keep and q not in seen: seen.add(q); stack.append(q)
        comps.append(comp)
    out = Image.new("RGBA", g.size); op = out.load()
    for comp in comps:
        if len(comp) >= 6:
            for x, y in comp: op[x, y] = gp[x, y]
    return out

def shear_to_iso(im, pivot, k):
    """Shift each column vertically by k*(x-pivot_x): turns the 45deg body axis into the bed's 2:1 axis."""
    out = Image.new("RGBA", im.size); sp, op = im.load(), out.load()
    for x in range(im.width):
        dy = round(k * (x - pivot[0]))
        for y in range(im.height):
            ny = y + dy
            if 0 <= ny < im.height and sp[x, y][3]: op[x, ny] = sp[x, y]
    return out

B_PIVOT, B_SHEAR = (31, 75), 0.43

HEAD = {"A": (98, 24), "B": (31, 75)}
SKIN_LUM = 0.299 * 252 + 0.587 * 213 + 0.114 * 181      # the FCD5B5 tint the mannequin was sent with
CLOTH_LUM = 255 * 0.9                                     # clothes keep their own darkness, slight lift

fixB = lambda im: shear_to_iso(im, B_PIVOT, B_SHEAR)
bases = {"A": load("A_clean_0.png"), "B": load("B_fix_0.png")}          # with face: reference for garment isolation
bodies = {"A": load("A_clean_0_noface.png"), "B": load("B_fix_0_noface.png")}  # faceless: what ships
opens = {"A": drop_white_bg(load("eyes_open_0.png")), "B": drop_white_bg(load("eyes_open_1.png"))}
jackets = {"A": load("jacket_0.png"), "B": load("jacket_1.png")}
jeans = {"A": load("jeans_0.png"), "B": load("jeans_1.png")}

for v in "AB":
    to_raw(bodies[v], SKIN_LUM).save(f"{LAYERS}/male_lie{v}.png")
    to_raw(isolate_cloth(jackets[v], bases[v], HEAD[v]), CLOTH_LUM).save(f"{LAYERS}/jacket_lie{v}.png")
    to_raw(isolate_cloth(jeans[v], bases[v], HEAD[v]), CLOTH_LUM).save(f"{LAYERS}/jeans_lie{v}.png")

# ---------- preview on the 4 bed rotations ----------
SKIN, TOP, BOTTOM = (0xF2, 0xC8, 0xA8), (0x8A, 0x8A, 0x95), (0x70, 0x78, 0x90)

def avatar(v, awake):
    L = lambda n: Image.open(f"{LAYERS}/{n}").convert("RGBA")
    from face_preview import eyes_tint  # lazy: face_preview imports this module
    out = tint(L(f"male_lie{v}.png"), SKIN)
    out.alpha_composite(tint(L(f"face/standard_lie{v}.png"), SKIN))
    out.alpha_composite(L(f"face/catmouth_lie{v}.png"))
    out.alpha_composite(eyes_tint(L(f"face/{'cateyes' if awake else 'closedeyes'}_lie{v}.png")))
    out.alpha_composite(tint(L(f"jeans_lie{v}.png"), BOTTOM))
    out.alpha_composite(tint(L(f"jacket_lie{v}.png"), TOP))
    return out

# head center inside the 128x96 lying sprite, and where it goes on the (unmirrored) bed
PILLOW = {0: (156, 36), 2: (64, 90)}
# blanket edge: point + which side is covered; headboard occluder for rot2 (front)
def covered(rot, x, y):
    if rot == 0:
        ex, ey = 145, 42
        return (x - ex) - (y - ey) * 2 < 0     # below the (2,1) line through the edge
    ex, ey = 76, 84
    return (x - ex) - (y - ey) * 2 > 0          # above it (feet are toward the back)

def headboard(bed, x, y):
    # rot2 headboard: the dark front panel on the left; it's in front of the head
    r, g, b, a = bed.getpixel((x, y))
    return a and x < 72 and y > 60 and (r + g + b) < 200

def scene(rot, under, awake):
    base_rot = 0 if rot in (0, 1) else 2
    v = "A" if base_rot == 0 else "B"
    bed = Image.open(BED.format(base_rot)).convert("RGBA")
    av = avatar(v, awake)
    ox, oy = PILLOW[base_rot][0] - HEAD[v][0], PILLOW[base_rot][1] - HEAD[v][1]
    layer = Image.new("RGBA", bed.size); layer.alpha_composite(av, (ox, oy))
    lp, bp = layer.load(), bed.load()
    for y in range(bed.height):
        for x in range(bed.width):
            if not lp[x, y][3]: continue
            if (under and covered(base_rot, x, y)) or (base_rot == 2 and headboard(bed, x, y)):
                lp[x, y] = (0, 0, 0, 0)
    out = bed.copy(); out.alpha_composite(layer)
    if rot in (1, 3):  # rot1 / rot3 are the horizontal mirror of rot0 / rot2
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
    return out

if __name__ == "__main__":
    rows = [("encima", False, True), ("debajo", True, False)]
    W, H = 192, 144
    sheet = Image.new("RGBA", (W * 4 + 30, H * 2 + 10), (58, 56, 70, 255))
    for r, (_, under, awake) in enumerate(rows):
        for rot in range(4):
            sheet.alpha_composite(scene(rot, under, awake), (rot * (W + 10), r * (H + 10)))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(f"{OUT}/preview_4_rotaciones.png")
    # layer sheet
    names = sorted(n for n in os.listdir(LAYERS) if n.endswith(".png"))
    ls = Image.new("RGBA", (136 * 4, 104 * 2), (58, 56, 70, 255))
    for i, n in enumerate(names):
        ls.alpha_composite(Image.open(f"{LAYERS}/{n}").convert("RGBA"), ((i % 4) * 136, (i // 4) * 104))
    ls.resize((ls.width * 3, ls.height * 3), Image.NEAREST).save(f"{OUT}/preview_capas.png")
    print(names)
