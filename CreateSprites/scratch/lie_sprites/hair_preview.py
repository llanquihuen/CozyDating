"""Preview every hair style on both lying views (hair_back -> body+face -> hair_front)."""
import sys
from PIL import Image, ImageDraw
import face_layers as fl
from face_preview import face
from build_layers import tint

HAIRC = (0x5A, 0x34, 0x22)
if __name__ == "__main__":
    S = 5; W, H = 72 * S, 60 * S
    styles = list(fl.HAIR)
    sheet = Image.new("RGBA", ((W + 10) * len(styles), (H + 16) * 2), (30, 30, 36, 255)); d = ImageDraw.Draw(sheet)
    for r, view in enumerate("AB"):
        face_l, hair_l = fl.build(view), fl.build_hair(view)
        for c, st in enumerate(styles):
            out = Image.new("RGBA", (128, 96))
            if ("back", st) in hair_l: out.alpha_composite(tint(hair_l[("back", st)], HAIRC))
            out.alpha_composite(face(view, face_l, "cateyes", "smile", "small"))
            out.alpha_composite(tint(hair_l[("front", st)], HAIRC))
            box = (56, 0, 128, 60) if view == "A" else (0, 36, 72, 96)
            im = out.crop(box)
            bg = Image.new("RGBA", im.size, (58, 56, 70, 255)); bg.alpha_composite(im)
            sheet.paste(bg.resize((im.width * S, im.height * S), Image.NEAREST), (c * (W + 10), r * (H + 16) + 14))
            d.text((c * (W + 10) + 4, r * (H + 16)), f"{view}: {st}", fill=(240, 240, 240))
    sheet.save(sys.argv[1] if len(sys.argv) > 1 else "_hair.png")
