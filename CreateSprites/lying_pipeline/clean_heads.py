"""Second pass on the faceless bodies: A -> remove small dark residue specks; B -> flatten the
round crown highlight into the surrounding skin tone. Edges/ears (<=2px from silhouette) untouched."""
import os
from PIL import Image
from strip_face import lum, edge_dist, HEADS

OUT = os.path.dirname(os.path.abspath(__file__))

def components(pts):
    pts, comps = set(pts), []
    while pts:
        stack = [pts.pop()]; comp = list(stack)
        while stack:
            x, y = stack.pop()
            for q in ((x+1, y), (x-1, y), (x, y+1), (x, y-1), (x+1, y+1), (x-1, y-1), (x+1, y-1), (x-1, y+1)):
                if q in pts: pts.remove(q); stack.append(q); comp.append(q)
        comps.append(comp)
    return comps

def inpaint(px, holes):
    holes = set(holes)
    while holes:
        filled = {}
        for x, y in holes:
            nb = [px[x+dx, y+dy] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                  if (dx or dy) and (x+dx, y+dy) not in holes and px[x+dx, y+dy][3]]
            if len(nb) >= 3:
                filled[(x, y)] = tuple(round(sum(c[i] for c in nb) / len(nb)) for i in range(3)) + (255,)
        if not filled: break
        for p, c in filled.items(): px[p] = c
        holes -= filled.keys()

if __name__ == "__main__":
    for src, ((cx, cy), r) in HEADS.items():
        name = src.replace(".png", "_noface.png")
        im = Image.open(os.path.join(OUT, name)).convert("RGBA"); px = im.load(); w, h = im.size
        interior = [(x, y) for y in range(h) for x in range(w)
                    if px[x, y][3] and (x-cx)**2 + (y-cy)**2 <= r*r and edge_dist(px, w, h, x, y) > 2]
        vals = sorted(lum(px[p]) for p in interior); ref = vals[len(vals) // 2]
        if src.startswith("A"):
            inner = [(x, y) for y in range(h) for x in range(w)
                     if px[x, y][3] and (x-cx)**2 + (y-cy)**2 <= r*r and edge_dist(px, w, h, x, y) > 1]
            dark = [p for p in inner if lum(px[p]) < ref * 0.93]
            touches_outline = lambda c: any(edge_dist(px, w, h, x+dx, y+dy) == 1
                                            for x, y in c for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                                            if 0 <= x+dx < w and 0 <= y+dy < h and px[x+dx, y+dy][3])
            # ear sits on the lower-right of head A; specks are on the forehead side (x < center)
            specks = [p for c in components([q for q in dark if q[0] < cx]) if len(c) <= 4 for p in c]
            inpaint(px, specks); print(name, "specks removed:", len(specks))
        else:
            med = sorted((px[p] for p in interior), key=lum)[len(interior) // 2]
            bright = [p for p in interior if lum(px[p]) > ref * 1.04]
            for p in bright: px[p] = med
            print(name, "highlight px flattened:", len(bright))
        im.save(os.path.join(OUT, name))
    