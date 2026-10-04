"""Final export of every lying layer on a 160x128 canvas (16px margin so long hair fits),
plus previews. Layout of layers_final/ mirrors OCTOPLAYER/Avatar categories:
  body/male_lie{A,B}.png  tops/jacket_lie{A,B}.png  bottoms/jeans_lie{A,B}.png
  eyes|mouth|nose/{style}_lie{A,B}.png  hair/{style}/{style}_lie{A,B}.png
All grayscale (eyes keep their red/green/blue tint markers), tinted at runtime with modulate."""
import os, shutil
from PIL import Image, ImageDraw
import face_layers as fl
from build_layers import tint, to_raw, SKIN_LUM, BED, covered, headboard
from face_preview import eyes_tint

OUT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(OUT, "layers")
DST = os.path.join(OUT, "layers_final")
PAD = 16
SIZE = (128 + 2 * PAD, 96 + 2 * PAD)
HEAD = {"A": (98 + PAD, 24 + PAD), "B": (31 + PAD, 75 + PAD)}
# eyes midpoint (padded coords) and face "up" unit vector (mouth -> eyes) per view
CROWN = {"A": ((111.75, 39.75), (0.63, -0.78)), "B": ((51.0, 89.0), (-0.707, 0.707))}
SHORT_HAIR = ["bangs", "comb_over", "braids"]
LONG_HAIR = ["flow", "long_flow", "twintails"]
AV = fl.AV

def pad(im):
    c = Image.new("RGBA", SIZE); c.alpha_composite(im.convert("RGBA"), (PAD, PAD)); return c

def lum(p): return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]

def components(pts):
    pts, out = set(pts), []
    while pts:
        st = [pts.pop()]; comp = list(st)
        while st:
            x, y = st.pop()
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in pts: pts.remove(q); st.append(q); comp.append(q)
        out.append(comp)
    return out

def isolate_hair(gen, base, head, r=22):
    """Hair = changed vs the hairless guide, dark-ish, not eye-teal, not pillow-white, away from the
    original facial features; grown into its dark outline; specks dropped."""
    g, b = gen.convert("RGBA"), base.convert("RGBA"); gp, bp = g.load(), b.load(); W, H = g.size
    feat = set()
    for y in range(H):
        for x in range(W):
            if bp[x, y][3] and lum(bp[x, y]) < 120:  # base outline + facial features
                feat |= {(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    def changed(x, y):
        a, c = gp[x, y], bp[x, y]
        return a[3] and (not c[3] or sum((a[i] - c[i]) ** 2 for i in range(3)) ** 0.5 > 35)
    def hairish(x, y):
        pr, pg, pb, _ = gp[x, y]
        return lum(gp[x, y]) < 140 and not (pg > pr + 10) and pr >= pb
    # hair may only live outside the body silhouette or on the head (PixelLab redraws the body
    # ~1px off, and skin shadows are hair-coloured, so anything else is body leakage)
    near_body = set()
    for y in range(H):
        for x in range(W):
            if bp[x, y][3]:
                near_body |= {(x + dx, y + dy) for dx in range(-3, 4) for dy in range(-3, 4)}
    in_head = lambda x, y, rr=r: (x - head[0]) ** 2 + (y - head[1]) ** 2 <= rr * rr
    # outside the silhouette is fine, except a 3px rim along the body away from the head
    # (that rim is the redrawn body outline/shadow shifted by PixelLab)
    allowed = lambda x, y: bp[x, y][3] == 0 and ((x, y) not in near_body or in_head(x, y, r + 8))
    core = {(x, y) for y in range(H) for x in range(W)
            if changed(x, y) and hairish(x, y) and lum(gp[x, y]) >= 25 and allowed(x, y)}
    # flood from the core through connected dark hair shadows/outline (no distance limit)
    stack = list(core)
    while stack:
        x, y = stack.pop()
        for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            qx, qy = q
            if 0 <= qx < W and 0 <= qy < H and q not in core and changed(qx, qy)                     and lum(gp[q]) < 140 and allowed(qx, qy):
                core.add(q); stack.append(q)
    # only hair masses attached to the head survive (drops the body drop-shadow strokes)
    keep = [p for c in components(core) if len(c) >= 6 and any(in_head(x, y, r + 10) for x, y in c) for p in c]
    out = Image.new("RGBA", g.size); op = out.load()
    for p in keep: op[p] = gp[p]
    return out

def to_hair_raw(im, ref_style):
    """Map hair luminance so its median matches the median of the standing raw hair sprite."""
    ref = Image.open(f"{AV}/hair/{ref_style}/front/{ref_style}{fl.SRC_DIR}.png").convert("RGBA")
    rv = sorted(lum(p) for p in ref.getdata() if p[3]); target = rv[len(rv) // 2]
    hv = sorted(lum(p) for p in im.getdata() if p[3]); k = target / max(1, hv[len(hv) // 2])
    out = im.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a: v = min(255, round(lum((r, g, b)) * k)); px[x, y] = (v, v, v, a)
    return out

def export():
    if os.path.isdir(DST): shutil.rmtree(DST)
    for d in ("body", "tops", "bottoms", "eyes", "mouth", "nose", "hair"):
        os.makedirs(f"{DST}/{d}", exist_ok=True)
    for v in "AB":
        pad(to_raw(Image.open(f"{OUT}/{v}_v2_noface.png").convert("RGBA"), SKIN_LUM)).save(f"{DST}/body/male_lie{v}.png")
        pad(to_raw(Image.open(f"{OUT}/{v}_female_noface.png").convert("RGBA"), SKIN_LUM)).save(f"{DST}/body/female_lie{v}.png")
        jk = f"{OUT}/jacket_lieA_fixed.png" if v == "A" else f"{SRC}/jacket_lie{v}.png"  # A: sleeve fixed by PixelLab
        pad(Image.open(jk)).save(f"{DST}/tops/jacket_lie{v}.png")
        pad(Image.open(f"{SRC}/jeans_lie{v}.png")).save(f"{DST}/bottoms/jeans_lie{v}.png")
        for cat, styles in fl.STYLES.items():
            for st in styles:
                pad(Image.open(f"{OUT}/layers_v2/face/{st}_lie{v}.png")).save(f"{DST}/{cat}/{st}_lie{v}.png")
        hair_short = hair_short_all = fl.build_hair(v)
        for st in SHORT_HAIR:
            os.makedirs(f"{DST}/hair/{st}", exist_ok=True)
            pad(hair_short[("front", st)]).save(f"{DST}/hair/{st}/{st}_lie{v}.png")
        base = pad(Image.open(f"{OUT}/hairbase_{v}.png"))
        for st in LONG_HAIR:
            os.makedirs(f"{DST}/hair/{st}", exist_ok=True)
            hair = to_hair_raw(isolate_hair(Image.open(f"{OUT}/hair1_{st}_{v}_0.png"), base, HEAD[v]), st)
            # on the head itself use the player's real hair sprite (transformed), clipped to the head
            top = pad(hair_short_all[("front", st)]); tp, bp_ = top.load(), base.load()
            hx, hy = HEAD[v]
            (ex, ey), (ux, uy) = CROWN[v]
            for y in range(SIZE[1]):
                for x in range(SIZE[0]):
                    on_crown = (x - ex) * ux + (y - ey) * uy >= 2.5   # beyond the brows, never over the face
                    if tp[x, y][3] and bp_[x, y][3] and on_crown and (x - hx) ** 2 + (y - hy) ** 2 <= 22 ** 2:
                        hair.putpixel((x, y), tp[x, y])
            hair.save(f"{DST}/hair/{st}/{st}_lie{v}.png")

# ---------------- previews ----------------
SKIN, TOP, BOTTOM, HAIRC = (0xF2, 0xC8, 0xA8), (0x8A, 0x8A, 0x95), (0x70, 0x78, 0x90), (0x5A, 0x34, 0x22)
PILLOW = {0: (156, 36), 2: (64, 90)}

def bed_fabric(bed, x, y):
    """Mattress / blanket / pillow pixels of the bed sprite (not the wood frame, not the floor)."""
    r, g, b, a = bed.getpixel((x, y))
    return a and (b > r + 15 or lum((r, g, b)) > 150)

def avatar(v, hair, awake=True, clothes=True, with_hair=True, body="male"):
    L = lambda p: Image.open(f"{DST}/{p}").convert("RGBA")
    out = tint(L(f"body/{body}_lie{v}.png"), SKIN)
    out.alpha_composite(tint(L(f"nose/small_lie{v}.png"), SKIN))
    out.alpha_composite(L(f"mouth/smile_lie{v}.png"))
    out.alpha_composite(eyes_tint(L(f"eyes/{'cateyes' if awake else 'closedeyes'}_lie{v}.png")))
    if clothes:
        out.alpha_composite(tint(L(f"bottoms/jeans_lie{v}.png"), BOTTOM))
        out.alpha_composite(tint(L(f"tops/jacket_lie{v}.png"), TOP))
    if with_hair:
        out.alpha_composite(tint(L(f"hair/{hair}/{hair}_lie{v}.png"), HAIRC))
    return out

def scene(rot, under, hair):
    base_rot = 0 if rot in (0, 1) else 2
    v = "A" if base_rot == 0 else "B"
    bed = Image.open(BED.format(base_rot)).convert("RGBA")
    av = avatar(v, hair, awake=not under, with_hair=False)
    ox, oy = PILLOW[base_rot][0] - HEAD[v][0], PILLOW[base_rot][1] - HEAD[v][1]
    layer = Image.new("RGBA", bed.size); layer.alpha_composite(av, (ox, oy))
    # hair is clipped to the bed fabric so long hair never spills onto the frame/floor
    hl = Image.new("RGBA", bed.size)
    hl.alpha_composite(tint(Image.open(f"{DST}/hair/{hair}/{hair}_lie{v}.png").convert("RGBA"), HAIRC), (ox, oy))
    hp, al = hl.load(), layer.load()
    for y in range(bed.height):
        for x in range(bed.width):
            if hp[x, y][3] and (al[x, y][3] or bed_fabric(bed, x, y)):
                al[x, y] = hp[x, y]
    lp = layer.load()
    for y in range(bed.height):
        for x in range(bed.width):
            if lp[x, y][3] and ((under and covered(base_rot, x, y)) or (base_rot == 2 and headboard(bed, x, y))):
                lp[x, y] = (0, 0, 0, 0)
    out = bed.copy(); out.alpha_composite(layer)
    return out.transpose(Image.FLIP_LEFT_RIGHT) if rot in (1, 3) else out

if __name__ == "__main__":
    export()
    import fit_clothes
    fit_clothes.run()            # per-body jacket/jeans (+ generic fallbacks)
    styles = SHORT_HAIR + LONG_HAIR
    # hair sheet: every style, both views, no clothes
    S = 3; cw, ch = SIZE
    sh = Image.new("RGBA", ((cw + 6) * len(styles), (ch + 14) * 2), (30, 30, 36, 255)); d = ImageDraw.Draw(sh)
    for r, v in enumerate("AB"):
        for c, st in enumerate(styles):
            bg = Image.new("RGBA", SIZE, (58, 56, 70, 255)); bg.alpha_composite(avatar(v, st, clothes=False))
            sh.alpha_composite(bg, (c * (cw + 6), r * (ch + 14) + 12))
            d.text((c * (cw + 6) + 3, r * (ch + 14)), f"{v}: {st}", fill=(240, 240, 240))
    sh.resize((sh.width * S, sh.height * S), Image.NEAREST).save(f"{OUT}/pelo_estilos.png")
    # beds: every style on rot0..3, on top and under
    W, H = 192, 144
    bs = Image.new("RGBA", ((W + 6) * 4, (H + 6) * len(styles) * 2), (58, 56, 70, 255))
    for i, st in enumerate(styles):
        for j, under in enumerate((False, True)):
            for rot in range(4):
                bs.alpha_composite(scene(rot, under, st), (rot * (W + 6), (i * 2 + j) * (H + 6)))
    bs.resize((bs.width * 2, bs.height * 2), Image.NEAREST).save(f"{OUT}/pelo_camas.png")
    print("ok", sorted(os.listdir(f"{DST}/hair")))
