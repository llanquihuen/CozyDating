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
    out.paste(im, (dx, dy), im)
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


def write_lying(folder, name):
    import make_face_items as mfi
    for view in "AB":
        im, d, err = mfi.best("accessory", f"{folder}/{name}{{d}}.png", view)
        im.save(os.path.join(AV, "lying", folder, f"{name}_lie{view}.png"))
        print(f"  lying/{folder}/{name}_lie{view}: dir {d}, anchor error {err:.2f}px")


def export():
    for name, style in EYES.items():
        write("eyes", name, eye_sprites(style))
        write_lying("eyes", name)
    for name, style in MOUTHS.items():
        write("mouth", name, mouth_sprites(style))
        write_lying("mouth", name)


def preview():
    from face_sheet import sheet
    rows = [(n, {"eyes": n}) for n in EYES] + [(n, {"mouth": n}) for n in MOUTHS]
    sheet(rows, os.path.join(HERE, "_nuevos.png"))
    sheet(rows, os.path.join(HERE, "_nuevos_male_dark.png"), body="male", skin="#7A4522", hair="comb_over")


if __name__ == "__main__":
    if "--preview" not in sys.argv:
        export()
    preview()
