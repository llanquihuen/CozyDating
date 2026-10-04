"""Preview face variants on the faceless lying heads, tinted like the game."""
import sys
from PIL import Image, ImageDraw
import face_layers as fl
from build_layers import tint

SKIN, EYE, BROW = (0xF2, 0xC8, 0xA8), (0x2B, 0xB3, 0xA3), (0x3A, 0x2A, 0x22)

def eyes_tint(im):
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if not a: continue
            if r > g + 15 and r > b + 15: f = r / 255; px[x, y] = (int(EYE[0]*f), int(EYE[1]*f), int(EYE[2]*f), a)
            elif g > r + 15 and g > b + 15: f = g / 255; px[x, y] = (int(BROW[0]*f), int(BROW[1]*f), int(BROW[2]*f), a)
            elif b > r + 15 and b > g + 15 and b >= 40:
                k = (0.82, 0.70, 0.65) if b >= 180 else (0.60, 0.46, 0.42) if b >= 120 else None
                px[x, y] = (int(SKIN[0]*k[0]), int(SKIN[1]*k[1]), int(SKIN[2]*k[2]), a) if k else (32, 24, 38, a)
    return im

def face(view, layers, eye="cateyes", mouth="catmouth", nose="standard"):
    body = tint(Image.open(f"layers/male_lie{view}.png").convert("RGBA"), SKIN)
    body.alpha_composite(tint(layers[("nose", nose)], SKIN))
    body.alpha_composite(layers[("mouth", mouth)])
    body.alpha_composite(eyes_tint(layers[("eyes", eye)]))
    return body

def crop(view, im):
    return im.crop((72, 0, 124, 50) if view == "A" else (4, 48, 56, 96))

if __name__ == "__main__":
    combos = [("cateyes", "catmouth", "standard"), ("relax", "smile", "small"),
              ("closedeyes", "biglips", "standard"), ("cateyes", "smirk", "small")]
    S = 6; W, H = 52 * S, 50 * S
    sheet = Image.new("RGBA", ((W + 10) * 4, (H + 16) * 2), (30, 30, 36, 255)); d = ImageDraw.Draw(sheet)
    for r, view in enumerate("AB"):
        layers = fl.build(view)
        for c, (e, m, n) in enumerate(combos):
            im = crop(view, face(view, layers, e, m, n))
            bg = Image.new("RGBA", im.size, (58, 56, 70, 255)); bg.alpha_composite(im)
            sheet.paste(bg.resize((im.width * S, im.height * S), Image.NEAREST), (c * (W + 10), r * (H + 16) + 14))
            d.text((c * (W + 10) + 4, r * (H + 16)), f"{view}: {e} / {m} / {n}", fill=(240, 240, 240))
    sheet.save(sys.argv[1] if len(sys.argv) > 1 else "_face_styles.png")
