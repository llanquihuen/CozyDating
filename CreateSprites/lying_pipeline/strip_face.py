"""Removes the baked-in facial features from the lying bodies: inside the head, dark interior
pixels (eyes, brows, nose, mouth lines) are inpainted from the surrounding skin. The head
outline and the ears (within 2px of the silhouette edge) are left untouched."""
import os
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))
HEADS = {"A_clean_0.png": ((98, 24), 21), "B_fix_0.png": ((31, 75), 21)}

def lum(p): return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]

def edge_dist(px, w, h, x, y, maxd=3):
    for d in range(1, maxd + 1):
        for dx in range(-d, d + 1):
            for dy in range(-d, d + 1):
                X, Y = x + dx, y + dy
                if not (0 <= X < w and 0 <= Y < h) or px[X, Y][3] == 0:
                    return d
    return maxd + 1

def strip(name, center, r):
    im = Image.open(os.path.join(OUT, name)).convert("RGBA"); px = im.load(); w, h = im.size
    head = [(x, y) for y in range(h) for x in range(w)
            if px[x, y][3] and (x - center[0]) ** 2 + (y - center[1]) ** 2 <= r * r]
    interior = [p for p in head if edge_dist(px, w, h, *p) > 2]
    skin = sorted(lum(px[p]) for p in interior)
    ref = skin[len(skin) // 2]                      # median skin luminance of the face
    holes = {p for p in interior if lum(px[p]) < ref * 0.80}
    # inpaint from the outside in, averaging already-valid neighbours
    while holes:
        filled = {}
        for x, y in holes:
            nb = [px[x + dx, y + dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                  if (dx or dy) and (x + dx, y + dy) not in holes and px[x + dx, y + dy][3]]
            if len(nb) >= 3:
                filled[(x, y)] = tuple(round(sum(c[i] for c in nb) / len(nb)) for i in range(3)) + (255,)
        if not filled:
            break
        for p, c in filled.items():
            px[p] = c
        holes -= filled.keys()
    return im

if __name__ == "__main__":
    for name, (c, r) in HEADS.items():
        out = strip(name, c, r)
        out.save(os.path.join(OUT, name.replace(".png", "_noface.png")))
    a = Image.open(os.path.join(OUT, "A_clean_0_noface.png")); b = Image.open(os.path.join(OUT, "B_fix_0_noface.png"))
    s = Image.new("RGBA", (128 * 2 + 10, 96), (58, 56, 70, 255))
    s.alpha_composite(a, (0, 0)); s.alpha_composite(b, (138, 0))
    s.resize((s.width * 4, s.height * 4), Image.NEAREST).save(os.path.join(OUT, "_noface.png"))
