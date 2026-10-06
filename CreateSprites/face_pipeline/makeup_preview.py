"""Python twin of frontend/lib/features/avatar/components/face_makeup.dart, for preview sheets.
Images here are straight (not premultiplied) RGBA."""


def _is_brow(p):
    r, g, b, a = p
    return g > r + 15 and g > b + 15


def eyeshadow_targets(raw, up, smoky):
    """{(x, y): alpha} above the eye outline of the raw colour-coded eye layer."""
    px, (w, h) = raw.load(), raw.size
    levels = (200, 110) if smoky else (130,)
    out = {}
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0 or _is_brow(px[x, y]):
                continue
            for step, alpha in enumerate(levels, start=1):
                tx, ty = x + up[0] * step, y + up[1] * step
                if not (0 <= tx < w and 0 <= ty < h):
                    break
                if px[tx, ty][3] != 0:
                    if step == 1 and _is_brow(px[tx, ty]):
                        out[(tx, ty)] = max(out.get((tx, ty), 0), alpha)
                    break
                out[(tx, ty)] = max(out.get((tx, ty), 0), alpha)
    return out


def paint(img, targets, rgb):
    """Source-over of rgb at each target alpha."""
    from PIL import Image
    layer = Image.new("RGBA", img.size)
    lp = layer.load()
    for (x, y), a in targets.items():
        lp[x, y] = rgb + (a,)
    img.alpha_composite(layer)


def paint_lipstick(img, up, rgb, bold):
    px, (w, h) = img.load(), img.size
    opaque, lips = [], []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a:
                continue
            opaque.append((x, y))
            if 0.299 * r + 0.587 * g + 0.114 * b < 95 and max(r, g, b) - min(r, g, b) < 35:
                lips.append((x, y))
    targets = lips or opaque
    mix = 0.85 if bold else 0.6
    shade = 0.75 if bold and lips else 1.0
    lower = []
    for x, y in targets:
        r, g, b, a = px[x, y]
        px[x, y] = tuple(round(o * (1 - mix) + c * shade * mix) for o, c in zip((r, g, b), rgb)) + (a,)
        if bold:
            tx, ty = x - up[0], y - up[1]
            if 0 <= tx < w and 0 <= ty < h and px[tx, ty][3] == 0:
                lower.append((tx, ty))
    for t in lower:
        px[t] = rgb + (255,)
