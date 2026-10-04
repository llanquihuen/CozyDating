"""Shrinks the head of a lying sprite around the neck point (view A: head top-right)."""
import math, sys
from PIL import Image
src, dst, k = sys.argv[1], sys.argv[2], float(sys.argv[3])
NECK, HC, R = (86, 38), (101, 22), 23.5
im = Image.open(src).convert("RGBA"); px = im.load()
head = Image.new("RGBA", im.size); hp = head.load()
for y in range(im.height):
    for x in range(im.width):
        if px[x, y][3] and (x - NECK[0]) * 2 - (y - NECK[1]) > 0 and math.dist((x, y), HC) < R:
            hp[x, y] = px[x, y]; px[x, y] = (0, 0, 0, 0)
bb = head.getbbox(); h = head.crop(bb)
small = h.resize((round(h.width * k), round(h.height * k)), Image.NEAREST)
# keep the neck point fixed
nx, ny = (NECK[0] - bb[0]) * k, (NECK[1] - bb[1]) * k
im.alpha_composite(small, (round(NECK[0] - nx), round(NECK[1] - ny)))
im.save(dst)
