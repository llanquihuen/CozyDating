"""Places lying candidates on the real lobby screenshot (right bed), on top and under the blanket."""
import sys
from PIL import Image
sys.path.insert(0, "../lie_prototype")
SCENE = Image.open("../lie_prototype/lobby_camas.png").convert("RGBA")
SCALE = 2.7
PILLOW, EDGE = (676, 291), (646, 309)

def foot_side(x, y):
    return (x - EDGE[0]) - (y - EDGE[1]) * 2 < 0

def place(path, head, under=False, edge_shift=0):
    im = Image.open(path).convert("RGBA")
    big = im.resize((round(im.width * SCALE), round(im.height * SCALE)), Image.NEAREST)
    ox, oy = round(PILLOW[0] - head[0] * SCALE), round(PILLOW[1] - head[1] * SCALE)
    out = SCENE.copy(); out.alpha_composite(big, (ox, oy))
    if under:
        op, sp, bp = out.load(), SCENE.load(), big.load()
        for y in range(big.height):
            for x in range(big.width):
                X, Y = x + ox, y + oy
                if bp[x, y][3] and 0 <= X < out.width and 0 <= Y < out.height and foot_side(X, Y - edge_shift):
                    op[X, Y] = sp[X, Y]
    return out.crop((470, 190, 852, 470))

cands = [("gen_0.png", (103, 22)), ("gen_2.png", (102, 28)), ("edit_0.png", (113, 23))]
tiles = [place(p, h) for p, h in cands] + [place(p, h, under=True) for p, h in cands]
w, h = tiles[0].size
sheet = Image.new("RGBA", (w * 3 + 20, h * 2 + 10), (20, 20, 20, 255))
for i, t in enumerate(tiles):
    sheet.alpha_composite(t, ((i % 3) * (w + 10), (i // 3) * (h + 10)))
sheet.save("_preview_scene.png")
