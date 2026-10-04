"""Transplants PixelLab's improved head (facefix_*.png) onto the original lying bodies (which the
garment layers are aligned to), then produces a faceless version of it.
Outputs (128x96, same coords as A_clean_0 / B_fix_0):
  {A,B}_v2_face.png    body with the improved head and its default face
  {A,B}_v2_noface.png  same, face features inpainted with skin"""
import os
from PIL import Image
from strip_face import lum, edge_dist

OUT = os.path.dirname(os.path.abspath(__file__))
VIEWS = {  # old body, fixed image, shift fixed->old, old head centre, radius
    "A": ("A_clean_0.png", "facefix_0.png", (0, 3), (98, 24), 20),
    "B": ("B_fix_0.png", "facefix_1.png", (3, 3), (31, 75), 20),
}

def transplant(v):
    old_f, new_f, (dx, dy), (cx, cy), r = VIEWS[v]
    old = Image.open(os.path.join(OUT, old_f)).convert("RGBA"); op = old.load()
    new = Image.open(os.path.join(OUT, new_f)).convert("RGBA"); np_ = new.load()
    W, H = old.size
    for y in range(H):
        for x in range(W):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            X, Y = x + dx, y + dy
            src_px = np_[X, Y] if 0 <= X < W and 0 <= Y < H else (0, 0, 0, 0)
            if d2 <= r * r:
                op[x, y] = src_px
            elif d2 <= (r + 3) ** 2 and not src_px[3]:
                op[x, y] = (0, 0, 0, 0)       # leftovers of the old (larger) head
    return old

def skin_like(p, ref):
    r, g, b, a = p
    return a and r > g > b and r - b > 20 and ref * 0.78 <= lum(p) <= ref * 1.15

def strip(im, center, rad):
    im = im.copy(); px = im.load(); W, H = im.size
    head = [(x, y) for y in range(H) for x in range(W)
            if px[x, y][3] and (x - center[0]) ** 2 + (y - center[1]) ** 2 <= rad * rad]
    interior = [p for p in head if edge_dist(px, W, H, *p) > 2]
    vals = sorted(lum(px[p]) for p in interior); ref = vals[len(vals) // 2]
    holes = {p for p in interior if not skin_like(px[p], ref)}
    # eye whites / iris pixels can sit right next to the outline: take them too (never the outline)
    holes |= {p for p in head if edge_dist(px, W, H, *p) == 2 and px[p][3]
              and (lum(px[p]) > ref * 1.15 or px[p][1] > px[p][0])}
    while holes:
        filled = {}
        for x, y in holes:
            nb = [px[x + i, y + j] for i in (-1, 0, 1) for j in (-1, 0, 1)
                  if (i or j) and (x + i, y + j) not in holes and px[x + i, y + j][3]]
            if len(nb) >= 3:
                filled[(x, y)] = tuple(round(sum(c[k] for c in nb) / len(nb)) for k in range(3)) + (255,)
        if not filled: break
        for p, c in filled.items(): px[p] = c
        holes -= filled.keys()
    return im

if __name__ == "__main__":
    for v, (_, _, _, c, r) in VIEWS.items():
        face = transplant(v); face.save(os.path.join(OUT, f"{v}_v2_face.png"))
        strip(face, c, r).save(os.path.join(OUT, f"{v}_v2_noface.png"))
    s = Image.new("RGBA", (136 * 2, 104 * 2), (58, 56, 70, 255))
    for i, v in enumerate("AB"):
        s.alpha_composite(Image.open(os.path.join(OUT, f"{v}_v2_face.png")), (i * 136, 0))
        s.alpha_composite(Image.open(os.path.join(OUT, f"{v}_v2_noface.png")), (i * 136, 104))
    s.resize((s.width * 4, s.height * 4), Image.NEAREST).save(os.path.join(OUT, "_newbase.png"))
