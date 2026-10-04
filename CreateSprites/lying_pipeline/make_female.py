"""Builds the female lying bodies from PixelLab's edit (female_{0=A,1=B}.png): aligns them to the male
base (best silhouette IoU shift), then swaps in the exact faceless male head so face/hair layers fit.
Output: {A,B}_female_noface.png (128x96, same coords as the male v2 bodies)."""
import os
from PIL import Image

OUT = os.path.dirname(os.path.abspath(__file__))
HEAD = {"A": ((98, 24), 21), "B": ((31, 75), 21)}

def best_shift(a, b):
    aa, bb = a.split()[3].load(), b.split()[3].load(); best = None
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            inter = uni = 0
            for y in range(96):
                for x in range(128):
                    pa = aa[x, y] > 0; X, Y = x + dx, y + dy
                    pb = 0 <= X < 128 and 0 <= Y < 96 and bb[X, Y] > 0
                    inter += pa and pb; uni += pa or pb
            if not best or inter / uni > best[0]: best = (inter / uni, dx, dy)
    return best

if __name__ == "__main__":
    for i, v in enumerate("AB"):
        male = Image.open(f"{OUT}/{v}_v2_noface.png").convert("RGBA")
        fem = Image.open(f"{OUT}/female_{i}.png").convert("RGBA")
        iou, dx, dy = best_shift(male, fem); print(v, "IoU", round(iou, 3), "shift", dx, dy)
        out = Image.new("RGBA", male.size); op, fp, mp = out.load(), fem.load(), male.load()
        (cx, cy), r = HEAD[v]
        for y in range(96):
            for x in range(128):
                d2 = (x - cx) ** 2 + (y - cy) ** 2
                if d2 <= r * r:
                    op[x, y] = mp[x, y]                       # exact male faceless head
                else:
                    X, Y = x + dx, y + dy
                    if 0 <= X < 128 and 0 <= Y < 96: op[x, y] = fp[X, Y]
        out.save(f"{OUT}/{v}_female_noface.png")
    s = Image.new("RGBA", (136 * 2, 104 * 2), (58, 56, 70, 255))
    for i, v in enumerate("AB"):
        s.alpha_composite(Image.open(f"{OUT}/{v}_v2_noface.png"), (i * 136, 0))
        s.alpha_composite(Image.open(f"{OUT}/{v}_female_noface.png"), (i * 136, 104))
    s.resize((s.width * 4, s.height * 4), Image.NEAREST).save(f"{OUT}/_female.png")
