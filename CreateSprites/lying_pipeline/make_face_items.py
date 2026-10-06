"""Builds the lying versions of everything anchored to the face:
  - body marks (freckles, moles...)       marks/{mark}N.png              -> lying/marks/{mark}_lie{A,B}.png
  - face accessories (FACE_SLOTS: glasses) accessories/{slot}/{style}N.png -> lying/accessories/{slot}/{style}_lie{A,B}.png

The lying faces are their own art per view, so a plain rotation of the standing sprite does not land
on them. Instead each view gets an affine transform fitted (least squares) from facial anchors of the
standing sprite (both irises, mouth, nose when present) to the same anchors of the shipped lying face
layers. Marks are single-pixel dots, so each dot is moved on its own (resampling would blur or drop
them) and dots on the eyes or off the skin are dropped. Accessories are lines, so they are resampled
(inverse mapping with supersampling keeps 1px frames whole). Colours are kept as in the source sprite.

Usage: python make_face_items.py [--preview]"""
import math, os, sys
from PIL import Image

AV = r"C:/Users/Asus/ProyectoJuegoDating/frontend/assets/images/OCTOPLAYER/Avatar"
OUT = os.path.dirname(os.path.abspath(__file__))
FACING_DIRS = (1, 2, 8)   # standing directions showing both eyes, nose and mouth
FACE_SLOTS = ("glasses",)  # accessory slots worn on the face (hats/bags need their own lying art)
EYE_STYLES = sorted({f.rsplit("_lie", 1)[0] for f in os.listdir(f"{AV}/lying/eyes")})
REF = dict(eyes="cateyes", nose="standard", mouth="catmouth")   # styles used to locate the anchors


def _load(path):
    return Image.open(f"{AV}/{path}").convert("RGBA")


def _components(pts):
    pts, out = set(pts), []
    while pts:
        st = [pts.pop()]; comp = list(st)
        while st:
            x, y = st.pop()
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1), (x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1)):
                if q in pts: pts.remove(q); st.append(q); comp.append(q)
        out.append(comp)
    return out


def _centroid(pts):
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def anchors(eyes, nose, mouth):
    """[eye_a, eye_b, mouth, nose?] centres; the eyes are the two largest iris (red marker) blobs,
    ordered by handedness around the mouth (preserved by rotation and foreshortening, unlike their
    distance to the mouth, which ties on a front-facing face) so both faces pair them alike. The nose is
    left out when its layer is empty (some lying views carry the nose in the body shading)."""
    ep = eyes.load()
    iris = [(x, y) for y in range(eyes.height) for x in range(eyes.width)
            if ep[x, y][3] and ep[x, y][0] > ep[x, y][1] + 15 and ep[x, y][0] > ep[x, y][2] + 15]
    blobs = sorted(_components(iris), key=len, reverse=True)[:2]
    assert len(blobs) == 2, "expected two irises"
    solid = lambda im: [(x, y) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3]]
    m = _centroid(solid(mouth))
    e = [_centroid(b) for b in blobs]
    if (e[0][0] - m[0]) * (e[1][1] - m[1]) - (e[0][1] - m[1]) * (e[1][0] - m[0]) < 0:
        e.reverse()
    n = solid(nose)
    return [e[0], e[1], m] + ([_centroid(n)] if n else [])


def fit_affine(src, dst):
    """Least-squares 2x3 affine mapping src points onto dst points (normal equations, no numpy)."""
    def solve(rows, rhs):
        # 3x3 normal equations
        A = [[sum(r[i] * r[j] for r in rows) for j in range(3)] for i in range(3)]
        b = [sum(r[i] * v for r, v in zip(rows, rhs)) for i in range(3)]
        for c in range(3):
            p = max(range(c, 3), key=lambda r: abs(A[r][c])); A[c], A[p] = A[p], A[c]; b[c], b[p] = b[p], b[c]
            for r in range(3):
                if r != c:
                    f = A[r][c] / A[c][c]
                    A[r] = [a - f * ac for a, ac in zip(A[r], A[c])]; b[r] -= f * b[c]
        return [b[i] / A[i][i] for i in range(3)]
    rows = [(x, y, 1.0) for x, y in src]
    return solve(rows, [p[0] for p in dst]), solve(rows, [p[1] for p in dst])


def apply(t, x, y):
    (a, b, c), (d, e, f) = t
    return a * x + b * y + c, d * x + e * y + f


def invert(t):
    (a, b, c), (d, e, f) = t
    det = a * e - b * d
    return (e / det, -b / det, (b * f - c * e) / det), (-d / det, a / det, (c * d - a * f) / det)


def face_transform(view, src_dir):
    """Standing dir -> lying view affine, and its worst anchor residual in pixels."""
    lying = anchors(_load(f"lying/eyes/{REF['eyes']}_lie{view}.png"), _load(f"lying/nose/{REF['nose']}_lie{view}.png"),
                    _load(f"lying/mouth/{REF['mouth']}_lie{view}.png"))
    standing = anchors(_load(f"eyes/{REF['eyes']}{src_dir}.png"), _load(f"nose/{REF['nose']}{src_dir}.png"),
                       _load(f"mouth/{REF['mouth']}{src_dir}.png"))
    k = min(len(standing), len(lying))   # eyes + mouth always; nose only when both faces have one
    standing, lying = standing[:k], lying[:k]
    t = fit_affine(standing, lying)
    err = max(((apply(t, *s)[0] - l[0]) ** 2 + (apply(t, *s)[1] - l[1]) ** 2) ** 0.5 for s, l in zip(standing, lying))
    return t, err


def build_mark(src, view, t):
    body = _load(f"lying/body/female_lie{view}.png")
    sp = src.load()
    # a dot never covers an eye, whatever eye style the player picked
    eye_px = set()
    for st in EYE_STYLES:
        ep = _load(f"lying/eyes/{st}_lie{view}.png").load()
        eye_px |= {(x, y) for y in range(body.height) for x in range(body.width) if ep[x, y][3]}
    # ...and only lands on skin: not past the head silhouette nor on its dark outline
    bp = body.load()
    on_skin = lambda x, y: bp[x, y][3] and 0.299 * bp[x, y][0] + 0.587 * bp[x, y][1] + 0.114 * bp[x, y][2] > 120
    out = Image.new("RGBA", body.size); op = out.load()
    for y in range(src.height):
        for x in range(src.width):
            if sp[x, y][3]:
                ui, vi = (round(c) for c in apply(t, x, y))
                if (ui, vi) in eye_px or not (0 <= ui < out.width and 0 <= vi < out.height) or not on_skin(ui, vi):
                    continue
                if not op[ui, vi][3] or op[ui, vi][3] < sp[x, y][3]:
                    op[ui, vi] = sp[x, y]
    return out


def build_accessory(src, view, t, ss=4):
    """Inverse mapping: each lying pixel takes the most common opaque source colour among its ss*ss
    sub-samples when at least 3 hit (keeps 1px frame lines whole)."""
    size = _load(f"lying/body/female_lie{view}.png").size
    ti = invert(t)
    sp = src.load()
    out = Image.new("RGBA", size); op = out.load()
    for y in range(size[1]):
        for x in range(size[0]):
            hits = {}
            for sy in range(ss):
                for sx in range(ss):
                    u, v = apply(ti, x + (sx + 0.5) / ss - 0.5, y + (sy + 0.5) / ss - 0.5)
                    ui, vi = math.floor(u + 0.5), math.floor(v + 0.5)
                    if 0 <= ui < src.width and 0 <= vi < src.height and sp[ui, vi][3]:
                        hits[sp[ui, vi]] = hits.get(sp[ui, vi], 0) + 1
            if sum(hits.values()) >= 3:
                op[x, y] = max(hits, key=hits.get)
    return out


def _off_head(im, view):
    bp = _load(f"lying/body/female_lie{view}.png").load()
    return sum(1 for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3] and not bp[x, y][3])


def best(kind, src_path, view):
    """Builds from every facing dir and keeps the best fit: smallest anchor residual; on a tie
    (3 anchors always fit exactly) marks keep the most dots, accessories stick out of the head least."""
    results = []
    for d in FACING_DIRS:
        t, err = face_transform(view, d)
        src = _load(src_path.format(d=d))
        if kind == "mark":
            im = build_mark(src, view, t)
            tie = -sum(1 for p in im.getdata() if p[3])
        else:
            im = build_accessory(src, view, t)
            tie = _off_head(im, view)
        results.append(((round(err, 2), tie, FACING_DIRS.index(d)), im, d, err))
    _, im, d, err = min(results, key=lambda r: r[0])
    return im, d, err


def _styles(folder):
    return sorted({f[:-5] for f in os.listdir(f"{AV}/{folder}") if f.endswith("1.png") and "_walk" not in f})


def items():
    """(kind, label, source path pattern, output folder)"""
    out = [("mark", m, f"marks/{m}{{d}}.png", "lying/marks") for m in _styles("marks")]
    for slot in FACE_SLOTS:
        if os.path.isdir(f"{AV}/accessories/{slot}"):
            out += [("accessory", st, f"accessories/{slot}/{st}{{d}}.png", f"lying/accessories/{slot}")
                    for st in _styles(f"accessories/{slot}")]
    return out


def export():
    for kind, name, src, dst in items():
        os.makedirs(f"{AV}/{dst}", exist_ok=True)
        for view in "AB":
            im, d, err = best(kind, src, view)
            im.save(f"{AV}/{dst}/{name}_lie{view}.png")
            print(f"  {dst}/{name}_lie{view}: dir {d}, anchor error {err:.2f}px")


def preview(path):
    sys.path.insert(0, OUT)
    from build_layers import tint
    from face_preview import eyes_tint
    SKIN, ACC, S = (0xF2, 0xC8, 0xA8), (0xEA, 0xB3, 0x08), 8
    crops = {"A": (86, 8, 142, 64), "B": (19, 59, 75, 115)}
    rows = [[]] + [[(kind, name, dst)] for kind, name, _, dst in items()]
    sheet = Image.new("RGBA", (2 * 58 * S, len(rows) * 58 * S), (40, 40, 50, 255))
    for r, row in enumerate(rows):
        for c, view in enumerate("AB"):
            im = tint(_load(f"lying/body/female_lie{view}.png"), SKIN)
            im.alpha_composite(tint(_load(f"lying/nose/standard_lie{view}.png"), SKIN))
            im.alpha_composite(_load(f"lying/mouth/catmouth_lie{view}.png"))
            im.alpha_composite(eyes_tint(_load(f"lying/eyes/cateyes_lie{view}.png")))
            for kind, name, dst in row:
                layer = _load(f"{dst}/{name}_lie{view}.png")
                im.alpha_composite(layer if kind == "mark" else tint(layer, ACC))
            sheet.alpha_composite(im.crop(crops[view]).resize((56 * S, 56 * S), Image.NEAREST), (c * 58 * S, r * 58 * S))
    sheet.save(path)


if __name__ == "__main__":
    export()
    if "--preview" in sys.argv:
        preview(os.path.join(OUT, "cara_acostado.png"))
        print("preview: cara_acostado.png (first row: bare face)")
