"""Builds the lying-pose guide (view A: head toward back-right, feet toward front-left)
for the male mannequin, at 1:1 game resolution, to feed PixelLab."""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lie_prototype"))
from PIL import Image
import importlib.util
spec = importlib.util.spec_from_file_location("ps_helpers", os.path.join(os.path.dirname(__file__), "..", "lie_prototype", "proto_scene.py"))

A = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/OCTOPLAYER/Avatar"
OUT = os.path.dirname(os.path.abspath(__file__))
SKIN = (0xFC, 0xD5, 0xB5)

def tint(im, t):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a: px[x, y] = (r * t[0] // 255, g * t[1] // 255, b * t[2] // 255, a)
    return im

def mannequin(d=1, hair=None):
    out = Image.new("RGBA", (64, 128))
    for p, t in [(f"body/male{d}.png", SKIN), (f"body/male_hands{d}.png", SKIN), (f"head/oval{d}.png", SKIN),
                 (f"nose/standard{d}.png", SKIN), (f"mouth/catmouth{d}.png", None), (f"eyes/cateyes{d}.png", None)]:
        try:
            im = Image.open(f"{A}/{p}").convert("RGBA")
        except FileNotFoundError:
            continue
        out.alpha_composite(tint(im, t) if t else im)
    return out

W, H = 144, 96
def guide(sprite):
    bb = sprite.getbbox()
    hc = ((bb[0] + bb[2]) / 2, bb[1] + 20)          # head center
    s5 = math.sqrt(5)
    SHORT, LONG = (2 / s5, 1 / s5), (-2 / s5, 1 / s5)
    a, b, c, d = SHORT[0], LONG[0], SHORT[1], LONG[1]
    det = a * d - b * c
    ia, ib, ic, id_ = d / det, -b / det, -c / det, a / det
    ax, ay = W - 30, 22                              # head position in canvas
    coeffs = (ia, ib, hc[0] - ia * ax - ib * ay, ic, id_, hc[1] - ic * ax - id_ * ay)
    return sprite.transform((W, H), Image.AFFINE, coeffs, resample=Image.NEAREST)

if __name__ == "__main__":
    m = mannequin()
    m.save(f"{OUT}/ref_mannequin_standing.png")
    g = guide(m)
    print("guide bbox", g.getbbox())
    g.save(f"{OUT}/guide_lieA.png")
    prev = Image.new("RGBA", (64 + 10 + W, 128), (58, 56, 70, 255))
    prev.alpha_composite(m, (0, 0)); prev.alpha_composite(g, (74, 16))
    prev.resize((prev.width * 4, prev.height * 4), Image.NEAREST).save(f"{OUT}/_preview_guide.png")
