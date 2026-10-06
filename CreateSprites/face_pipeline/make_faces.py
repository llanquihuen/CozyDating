"""New eye and mouth styles drawn from small pixel grids.

Eyes use the colour-coded format the game tints at load time (modular_avatar_component
_loadOctoEyesFrame): red = iris (eyeColor), green = brows (eyebrowColor), blue = skin shadow / liner,
black and white stay as drawn. Mouths keep their colours.

Each eye style is the grid of the eye on the LEFT of the screen (inner corner on its right side); the
other eye is its mirror unless the style gives its own ('wink'). The face shows in directions
S(1), SE(2), E(3), W(7), SW(8); W and SW are mirrors of E and SE like the shipped styles. Eyes are
placed by their inner corner and bottom row, where every shipped style lines up.

  python make_faces.py            # writes standing sprites + walk frames + lying views, then a preview
  python make_faces.py --preview  # only the preview sheet (face_pipeline/_nuevos.png)
"""
import os
import sys
from PIL import Image, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
AV = os.path.join(ROOT, "..", "frontend", "assets", "images", "OCTOPLAYER", "Avatar")
sys.path.insert(0, ROOT)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "lying_pipeline"))

SIZE = (64, 128)

EYE_PALETTE = {
    "K": (12, 10, 14),      # lash / lid line
    "d": (87, 87, 84),      # sclera shade
    "g": (170, 170, 168),   # sclera mid
    "W": (245, 245, 240),   # sclera / highlight
    "R": (235, 50, 50),     # iris light
    "r": (170, 35, 35),     # iris mid
    "x": (95, 20, 20),      # iris dark (pupil, top shade)
    "G": (40, 215, 40),     # brow
    "h": (25, 140, 25),     # brow shade
    "S": (70, 70, 210),     # soft skin shadow
    "s": (60, 60, 150),     # deep crease
    "L": (30, 30, 90),      # charcoal liner
}
MOUTH_PALETTE = {
    "K": (45, 36, 40),      # line
    "M": (110, 40, 50),     # mouth inside
    "P": (226, 120, 128),   # tongue
    "T": (250, 248, 244),   # teeth / fang
    "l": (205, 120, 112),   # soft lip tint
}

# Eye anchors (from the shipped styles): x of the inner corner, y of the bottom row.
EYE_BOTTOM = 35
LEFT_INNER = {1: 28, 2: 36, 3: 47}   # right edge of the left/near eye
RIGHT_INNER = {1: 36, 2: 43}         # left edge of the right/far eye
FAR_EYE_SCALE = 0.7                  # SE: the far eye is foreshortened to ~70% of its width
MIRROR_SHIFT = {7: 0, 8: -1}         # W = mirror(E), SW = mirror(SE), nudged like the shipped styles

# Mouth anchors: left x and top y per drawn direction (W/SW are mirrors).
MOUTH_AT = {1: (31.5, 40), 2: (36, 41), 3: (44, 41)}  # dir 1 is centred on x

EYES = {
    "sparkle": dict(label="Ojos Kawaii ✨", left=[
        "..hGGGG...",
        ".GGhhhGG..",
        "..KKKKKK..",
        ".KxxxxxxK.",
        "KxRWWrrxK.",
        "KrRWRrRrK.",
        "KrRRRRWrK.",
        ".KrRRRRK..",
        "..KKKKK...",
    ]),
    "anime": dict(label="Ojos Anime 🌟", left=[
        ".hGGGG...",
        "GGhhhhG..",
        "KKKKKKK..",
        ".KxxxxK..",
        ".WxWrrK..",
        ".grRrrK..",
        ".gRRWRK..",
        "..RRRRK..",
        "..KKKK...",
    ]),
    "serious": dict(label="Ojos Serios 😐", left=[
        "hGGGGGGG..",
        ".hhhhhhhh.",
        ".KKKKKKKK.",
        "..dWxrWg..",
        "..KWrRWK..",
    ]),
    "sleepy": dict(label="Ojos Somnolientos 😪", left=[
        ".hGGGG....",
        "GGhhhGGG..",
        "..sssss...",
        ".KKKKKKK..",
        ".KWrRrWK..",
        "..KKKKK...",
    ]),
    "winged": dict(label="Ojos Delineados 💅", left=[
        "..hGGGG...",
        ".GGhhhGG..",
        "LL........",
        ".LKKKKKK..",
        "..KgxxrK..",
        "..dWrRRK..",
        "...WRRWK..",
        "....KKK...",
    ]),
    "puppy": dict(label="Ojos de Cachorrito 🥺", left=[
        ".....hGG..",
        "..GGGGh...",
        "..KKKKKK..",
        ".KxxxxxxK.",
        "KxWWxxxrK.",
        "KxWWxxRrK.",
        "KrxxxxWrK.",
        ".KrRRRRK..",
        "..KKKKK...",
    ]),
    "hearts": dict(label="Ojos Enamorados 😍", left=[
        "...hGGGG...",
        "..GGhhhGG..",
        "..KKKKKKK..",
        ".KWxxWxxWK.",
        "KWxRRxRWxWK",
        "KWxRRRRRxWK",
        ".KWxRRRxWK.",
        "..KWxRxWK..",
        "...KKxKK...",
    ]),
    "wink": dict(label="Guiño 😉", left=[
        ".hGGGG...",
        "GGhhhGG..",
        "..KKKKK..",
        ".KdxxxK..",
        ".KWrRrK..",
        ".KWRRWK..",
        "..KKKK...",
    ], right=[
        "...GGGGh.",
        "..GGhhhGG",
        ".........",
        ".........",
        "..KKKKK..",
        ".K.....K.",
        ".........",
    ]),
}

MOUTHS = {
    "grin": dict(label="Sonrisa Abierta 😄", grids={
        1: ["KKKKKKKK", ".KTTTTK.", ".KMPPMK.", "..KKKK.."],
        2: ["KKKKKKK", ".KTTTK.", ".KMPMK.", "..KKK.."],
        3: ["KKK", "MK.", "KK."],
    }),
    "neutral": dict(label="Boca Neutral 😐", grids={
        1: ["KKKKKK"],
        2: ["KKKKK"],
        3: ["KK"],
    }),
    "fang": dict(label="Sonrisa con Colmillo 😺", grids={
        1: ["K......K", ".KKKKKK.", "..KT...."],
        2: ["K.....K", ".KKKKK.", "..KT..."],
        3: ["K..", ".KK"],
    }),
    "pout": dict(label="Boquita de Beso 😗", grids={
        1: [".KK.", "KMMK", ".KK."],
        2: [".KK.", "KMMK", ".KK."],
        3: ["KK", "MK", "K."],
    }),
}


MARK_PALETTE = {
    "C": (226, 150, 138),   # scar
    "c": (184, 108, 100),   # scar shade
    "N": (92, 58, 44),      # mole
    "n": (92, 58, 44, 110), # mole soft edge
    "T": (42, 48, 92),      # tattoo ink
    "H": (196, 46, 70),     # red tattoo ink
}
# Blush is white with alpha: the game tints it with the chosen blush colour.
BLUSH_PALETTE = {"B": (255, 255, 255, 150), "b": (255, 255, 255, 75), "L": (255, 255, 255, 210)}

# Face marks and blush are lists of (x, y, grid) in front-view (S) canvas coordinates; the other
# directions are derived from where eyes and mouth move (see face_items_sprites).
FACE_MARKS = {
    "scar_eye": dict(label="Cicatriz en el Ojo ⚔️", items=[(22, 25, [
        "...cC",
        "...C.",
        "..cC.",
        "..C..",
        "..C..",
        "..C..",
        "..C..",
        ".cC..",
        ".C...",
        ".C...",
        ".C...",
        "cC...",
        "C....",
        "C....",
    ])]),
    "mole_mouth": dict(label="Lunar junto a la Boca", dots=True, items=[(37, 39, ["N"])]),
    "mole_eye": dict(label="Lunar bajo el Ojo", dots=True, items=[(21, 37, ["N"])]),
    "tattoo_tear": dict(label="Lágrima Tatuada 💧", items=[(21, 37, [".T", "TT", "TT"])]),
    "tattoo_star": dict(label="Estrella en la Mejilla ⭐", items=[(40, 37, [".T.", "TTT", ".T."])]),
    "tattoo_heart": dict(label="Corazón en la Mejilla ❤️", items=[(18, 37, ["H.H", "HHH", ".H."])]),
}
BLUSH = {
    "blush_soft": dict(label="Rubor Suave", items=[(18, 37, ["bBBb", "bBBb"]), (42, 37, ["bBBb", "bBBb"])]),
    "blush_anime": dict(label="Rubor Anime ///", items=[(17, 37, [".L.L.L", "L.L.L."]), (41, 37, [".L.L.L", "L.L.L."])]),
    "blush_strong": dict(label="Rubor Intenso", items=[(16, 36, [".bBBBb.", "bBBBBBb", ".bBBBb."]),
                                                 (41, 36, [".bBBBb.", "bBBBBBb", ".bBBBb."])]),
}


def render_grid(grid, palette):
    """Like render() but keeps the grid's own origin (leading '.' columns/rows count)."""
    im = Image.new("RGBA", (max(len(r) for r in grid), len(grid)))
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c != ".":
                col = palette[c]
                im.putpixel((x, y), col if len(col) == 4 else col + (255,))
    return im


def face_items_sprites(items, palette):
    """Places front-view items in every face direction: eye-level items follow the eyes, items at
    mouth level follow the mouth; in profile (E) only the near side shows. W/SW mirror E/SE."""
    def layout(spec, d):
        c = Image.new("RGBA", SIZE)
        for x, y, grid in spec:
            im = render_grid(grid, palette)
            near = x + im.width / 2 < 32                 # left half of the front view
            mouth_level = y + im.height / 2 >= 38
            if d == 1:
                nx, ny = x, y
            elif d == 2:
                if near or mouth_level:
                    nx = x + (LEFT_INNER[2] - LEFT_INNER[1])
                else:
                    nx = RIGHT_INNER[2] + round((x - RIGHT_INNER[1]) * FAR_EYE_SCALE)
                ny = y + (1 if mouth_level else 0)
            else:  # 3: profile, far side hidden
                if not near:
                    continue
                nx = x + (MOUTH_AT[3][0] - 28 if mouth_level else LEFT_INNER[3] - LEFT_INNER[1])
                ny = y + (1 if mouth_level else 0)
            c.alpha_composite(im, (int(nx), int(ny)))
        return c

    mirrored_spec = [(SIZE[0] - x - len(grid[0]), y, [row[::-1] for row in grid]) for x, y, grid in items]
    out = {d: layout(items, d) for d in (1, 2, 3)}
    out[7] = shift(ImageOps.mirror(layout(mirrored_spec, 3)), MIRROR_SHIFT[7])
    out[8] = shift(ImageOps.mirror(layout(mirrored_spec, 2)), MIRROR_SHIFT[8])
    return {d: on_face(im, d) for d, im in out.items()}


def on_face(im, d):
    """Drops pixels off the head skin (background or its dark outline)."""
    head = Image.open(os.path.join(AV, "head", f"oval{d}.png")).convert("RGBA")
    hp, op = head.load(), im.load()
    for y in range(im.height):
        for x in range(im.width):
            h = hp[x, y]
            if op[x, y][3] and not (h[3] and 0.299 * h[0] + 0.587 * h[1] + 0.114 * h[2] > 100):
                op[x, y] = (0, 0, 0, 0)
    return im


def render(grid, palette):
    w, h = max(len(r) for r in grid), len(grid)
    im = Image.new("RGBA", (w, h))
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c != ".":
                im.putpixel((x, y), palette[c] + (255,))
    return im.crop(im.getbbox()) if im.getbbox() else im


def compress(im, width):
    """Foreshortens an eye by dropping evenly spaced inner columns (never the outer edges)."""
    w = im.width
    if w <= width:
        return im
    drop = w - width
    cols = [round(1 + (i + 0.5) * (w - 2) / drop) for i in range(drop)]
    keep = [x for x in range(w) if x not in cols]
    out = Image.new("RGBA", (len(keep), im.height))
    for nx, x in enumerate(keep):
        out.paste(im.crop((x, 0, x + 1, im.height)), (nx, 0))
    return out


def place(canvas, im, x, bottom):
    canvas.alpha_composite(im, (x, bottom - im.height + 1))


def eye_sprites(style):
    left = render(style["left"], EYE_PALETTE)
    right = render(style["right"], EYE_PALETTE) if "right" in style else ImageOps.mirror(left)

    def front(near, far):          # S: near on the left, far on the right
        c = Image.new("RGBA", SIZE)
        place(c, near, LEFT_INNER[1] - near.width + 1, EYE_BOTTOM)
        place(c, far, RIGHT_INNER[1], EYE_BOTTOM)
        return c

    def three_quarter(near, far):  # SE: near full, far foreshortened
        c = Image.new("RGBA", SIZE)
        place(c, near, LEFT_INNER[2] - near.width + 1, EYE_BOTTOM)
        place(c, compress(far, max(1, round(far.width * FAR_EYE_SCALE))), RIGHT_INNER[2], EYE_BOTTOM)
        return c

    def profile(near):             # E: only the near eye
        c = Image.new("RGBA", SIZE)
        place(c, near, LEFT_INNER[3] - near.width + 1, EYE_BOTTOM)
        return c

    mirrored = lambda im, d: shift(ImageOps.mirror(im), MIRROR_SHIFT[d])
    # Seen from the other side the character's other eye is the near one.
    left_as_near, right_as_near = left, ImageOps.mirror(right)
    return {
        1: front(left, right),
        2: three_quarter(left, right),
        3: profile(left_as_near),
        7: mirrored(profile(right_as_near), 7),
        8: mirrored(three_quarter(right_as_near, ImageOps.mirror(left)), 8),
    }


def mouth_sprites(style):
    out = {}
    for d, grid in style["grids"].items():
        im = render(grid, MOUTH_PALETTE)
        x, y = MOUTH_AT[d]
        if d == 1:
            x = round(x - im.width / 2 + 0.5)
        c = Image.new("RGBA", SIZE)
        c.alpha_composite(im, (int(x), y))
        out[d] = c
    out[7] = ImageOps.mirror(out[3])
    out[8] = ImageOps.mirror(out[2])
    return out


def shift(im, dx, dy=0):
    out = Image.new("RGBA", im.size)
    out.paste(im, (dx, dy))  # no mask: a self-mask would square the alpha
    return out


def write(folder, name, sprites):
    from generate_face_walk_frames import HEAD_WALK_OFFSETS
    for d, im in sprites.items():
        im.save(os.path.join(AV, folder, f"{name}{d}.png"))
        for f, (dx, dy) in enumerate(HEAD_WALK_OFFSETS[d], start=1):
            shift(im, dx, dy).save(os.path.join(AV, folder, f"{name}{d}_walk_f{f}.png"))
    for d in (4, 5, 6):  # back views: face hidden
        empty = Image.new("RGBA", SIZE)
        empty.save(os.path.join(AV, folder, f"{name}{d}.png"))
        for f in range(1, 5):
            empty.save(os.path.join(AV, folder, f"{name}{d}_walk_f{f}.png"))


def write_lying(folder, name, kind="accessory"):
    """kind 'accessory' resamples shapes; 'mark' moves single dots one by one."""
    import make_face_items as mfi
    os.makedirs(os.path.join(AV, "lying", folder), exist_ok=True)
    for view in "AB":
        im, d, err = mfi.best(kind, f"{folder}/{name}{{d}}.png", view)
        im.save(os.path.join(AV, "lying", folder, f"{name}_lie{view}.png"))
        print(f"  lying/{folder}/{name}_lie{view}: dir {d}, anchor error {err:.2f}px")


def export():
    for name, style in EYES.items():
        write("eyes", name, eye_sprites(style))
        write_lying("eyes", name)
    for name, style in MOUTHS.items():
        write("mouth", name, mouth_sprites(style))
        write_lying("mouth", name)
    for name, style in FACE_MARKS.items():
        write("marks", name, face_items_sprites(style["items"], MARK_PALETTE))
        write_lying("marks", name, "mark" if style.get("dots") else "accessory")
    os.makedirs(os.path.join(AV, "makeup", "blush"), exist_ok=True)
    for name, style in BLUSH.items():
        write("makeup/blush", name, face_items_sprites(style["items"], BLUSH_PALETTE))
        write_lying("makeup/blush", name)


def preview():
    from face_sheet import sheet
    rows = [(n, {"eyes": n}) for n in EYES] + [(n, {"mouth": n}) for n in MOUTHS]
    sheet(rows, os.path.join(HERE, "_nuevos.png"))
    sheet(rows, os.path.join(HERE, "_nuevos_male_dark.png"), body="male", skin="#7A4522", hair="comb_over")
    pink = (236, 112, 140)
    extra = [(n, {"overlays": [(f"marks/{n}{{d}}.png", None)]}) for n in FACE_MARKS] +             [(n, {"overlays": [(f"makeup/blush/{n}{{d}}.png", pink)]}) for n in BLUSH]
    sheet(extra, os.path.join(HERE, "_marcas.png"))
    sheet(extra, os.path.join(HERE, "_marcas_dark.png"), body="male", skin="#7A4522", hair="comb_over")


def makeup_preview():
    """Eyeshadow and lipstick (painted at load time in the game) on several eye and mouth styles."""
    from face_sheet import sheet
    shadow, lip = (157, 92, 143), (192, 48, 74)
    rows = []
    for eye in ["cateyes", "relax", "sparkle", "anime", "serious", "winged", "hearts"]:
        for st in ["shadow_soft", "shadow_smoky"]:
            rows.append((f"{eye} {st[7:]}", {"eyes": eye, "makeup": {"eyeshadow": (st, shadow)}}))
    for mouth in ["smile", "catmouth", "biglips", "grin", "neutral", "pout"]:
        for st in ["lip_natural", "lip_bold"]:
            rows.append((f"{mouth} {st[4:]}", {"mouth": mouth, "makeup": {"lipstick": (st, lip)}}))
    sheet(rows, os.path.join(HERE, "_maquillaje.png"))


if __name__ == "__main__":
    if "--makeup" in sys.argv:
        makeup_preview()
        sys.exit()
    if "--preview" not in sys.argv:
        export()
    preview()

