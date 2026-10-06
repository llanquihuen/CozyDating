"""Lying boots (for lying anywhere but a bed: floor, park...; on a bed the avatar takes its shoes off).

  python make_boots.py --generate   # PixelLab: boots drawn on each dressed lying body (4 edit calls)
  python make_boots.py              # isolate + export from boots/gen_*.png

Each PixelLab result is aligned to its input, then the boot is the pixels that changed within FOOT_R
of the bare feet (the skin left uncovered by jeans/jacket, farthest from the head), minus jeans-blue
pixels (rolled cuffs belong to the jeans, not the boot). Holes where the bare foot would peek through
are filled from neighbouring boot pixels. Output is grayscale with the luminance of the standing boots,
so shoeColor tints it with modulate like every other shoe sprite:
  lying/shoes/boots_{male,female}_lie{A,B}.png  + generic boots_lie{A,B}.png (= male)"""
import os, shutil, sys
from PIL import Image
from make_female import best_shift

AV = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/OCTOPLAYER/Avatar"
OUT = os.path.dirname(os.path.abspath(__file__))
PAD = 16
HEAD = {"A": (98, 24), "B": (31, 75)}        # unpadded lying canvas
FOOT_R = 6
BODIES = ("male", "female")
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
SKIN, BOT, TOP = (0xF2, 0xC8, 0xA8), (0x25, 0x63, 0xEB), (0xDC, 0x26, 0x26)
DESC = ("put dark brown leather ankle boots on both bare feet: each boot covers the whole foot and the ankle, "
        "the jeans hem tucked into the boot, boot soles pointing toward the feet direction, pixel art with dark outline; "
        "keep everything else exactly identical: same pose, body, head, jacket, jeans, outline, colors and position")


def lum(p): return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def _load(path):
    return Image.open(f"{AV}/{path}").convert("RGBA")


def _unpad(im):
    return im.crop((PAD, PAD, PAD + 128, PAD + 96))


def _components(pts):
    pts, out = set(pts), []
    while pts:
        st = [pts.pop()]; comp = list(st)
        while st:
            x, y = st.pop()
            for dx, dy in N4:
                q = (x + dx, y + dy)
                if q in pts: pts.remove(q); st.append(q); comp.append(q)
        out.append(comp)
    return out


def dressed(body, v):
    from build_layers import tint
    im = tint(_load(f"lying/body/{body}_lie{v}.png"), SKIN)
    im.alpha_composite(tint(_load(f"lying/bottoms/jeans_{body}_lie{v}.png"), BOT))
    im.alpha_composite(tint(_load(f"lying/tops/jacket_{body}_lie{v}.png"), TOP))
    return _unpad(im)


def feet(body, v):
    """Bare-foot pixels: body skin not covered by clothes, the two blobs farthest from the head."""
    bp = _unpad(_load(f"lying/body/{body}_lie{v}.png")).load()
    jp = _unpad(_load(f"lying/bottoms/jeans_{body}_lie{v}.png")).load()
    tp = _unpad(_load(f"lying/tops/jacket_{body}_lie{v}.png")).load()
    bare = [(x, y) for y in range(96) for x in range(128) if bp[x, y][3] and not jp[x, y][3] and not tp[x, y][3]]
    hx, hy = HEAD[v]
    blobs = [c for c in _components(bare) if len(c) >= 4]
    far = lambda c: min((x - hx) ** 2 + (y - hy) ** 2 for x, y in c)
    return [p for c in sorted(blobs, key=far, reverse=True)[:2] for p in c]


def isolate(gen, base, foot):
    gp, bp = gen.load(), base.load()
    near = {(x + dx, y + dy) for x, y in foot for dx in range(-FOOT_R, FOOT_R + 1) for dy in range(-FOOT_R, FOOT_R + 1)
            if dx * dx + dy * dy <= FOOT_R * FOOT_R}
    def changed(x, y):
        g, b = gp[x, y], bp[x, y]
        return g[3] and (not b[3] or sum((g[i] - b[i]) ** 2 for i in range(3)) ** 0.5 > 35)
    jeans_blue = lambda p: p[2] > p[0] + 20
    core = {(x, y) for x, y in near if 0 <= x < 128 and 0 <= y < 96 and changed(x, y) and not jeans_blue(gp[x, y])}
    core = {p for c in _components(core) if len(c) >= 6 for p in c}
    out = Image.new("RGBA", gen.size); op = out.load()
    for p in core: op[p] = gp[p]
    # the bare foot must never peek out from under the boot
    holes = [p for p in foot if not op[p][3]]
    while holes:
        done = {}
        for x, y in holes:
            nb = [op[x + dx, y + dy] for dx, dy in N4 if 0 <= x + dx < 128 and 0 <= y + dy < 96 and op[x + dx, y + dy][3]]
            if nb: done[(x, y)] = min(nb, key=lum)
        if not done: break
        for p, c in done.items(): op[p] = c
        holes = [p for p in holes if p not in done]
    return out


def to_raw(im):
    """Grayscale whose median luminance matches the standing boots (tinted later with shoeColor)."""
    ref = sorted(lum(p) for d in ("S", "SE", "SW") for p in _load(f"shoes/boots_{d}.png").getdata() if p[3])
    target = ref[len(ref) // 2]
    vals = sorted(lum(p) for p in im.getdata() if p[3])
    k = target / max(1, vals[len(vals) // 2])
    out = im.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a: v = min(255, round(lum((r, g, b)) * k)); px[x, y] = (v, v, v, a)
    return out


def generate():
    import pl
    os.makedirs(f"{OUT}/boots", exist_ok=True)
    for body in BODIES:
        for v in "AB":
            dressed(body, v).save(f"{OUT}/boots/in_{body}_{v}.png")
            pl.edit([Image.open(f"{OUT}/boots/in_{body}_{v}.png")], DESC, f"boots/gen_{body}_{v}")


def export():
    os.makedirs(f"{AV}/lying/shoes", exist_ok=True)
    for body in BODIES:
        for v in "AB":
            base = dressed(body, v)
            gen = Image.open(f"{OUT}/boots/gen_{body}_{v}_0.png").convert("RGBA")
            iou, dx, dy = best_shift(base, gen)
            aligned = Image.new("RGBA", gen.size); aligned.alpha_composite(gen, (-dx, -dy))
            boot = to_raw(isolate(aligned, base, feet(body, v)))
            padded = Image.new("RGBA", (128 + 2 * PAD, 96 + 2 * PAD)); padded.alpha_composite(boot, (PAD, PAD))
            padded.save(f"{AV}/lying/shoes/boots_{body}_lie{v}.png")
            print(f"  boots_{body}_lie{v}: shift {(dx, dy)}, iou {iou:.3f}, {sum(1 for p in boot.getdata() if p[3])} px")
    for v in "AB":
        shutil.copy(f"{AV}/lying/shoes/boots_male_lie{v}.png", f"{AV}/lying/shoes/boots_lie{v}.png")


if __name__ == "__main__":
    if "--generate" in sys.argv:
        generate()
    export()
