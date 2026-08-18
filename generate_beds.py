import os
from PIL import Image, ImageDraw

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "frontend", "assets", "images", "furniture")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def draw_iso_polygon(draw, points, fill, outline=None, width=1):
    draw.polygon(points, fill=fill, outline=outline)

def create_bed_single_rustic():
    # 1x2 footprint: Base width 96, base height 48. Total canvas 96x72.
    img = Image.new("RGBA", (96, 72), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Footprint center base at bottom: (48, 70)
    # Diamond base: Top(48, 22), Right(94, 46), Bottom(48, 70), Left(2, 46)
    
    # 1. Floor Shadow
    shadow_pts = [(48, 26), (92, 48), (48, 70), (4, 48)]
    draw.polygon(shadow_pts, fill=(0, 0, 0, 60))

    # 2. Wooden Bed Frame (Base thickness 8px)
    # Bottom wooden sides
    wood_dark = (78, 52, 46, 255)
    wood_mid = (109, 76, 65, 255)
    wood_light = (141, 110, 99, 255)
    wood_highlight = (161, 136, 127, 255)

    # Left-front wooden board
    draw.polygon([(4, 44), (48, 66), (48, 58), (4, 36)], fill=wood_dark, outline=(46, 26, 20, 255))
    # Right-front wooden board
    draw.polygon([(48, 66), (92, 44), (92, 36), (48, 58)], fill=wood_mid, outline=(46, 26, 20, 255))

    # 3. Tall Wooden Headboard at Back-Top (48, 14)
    headboard_pts = [(48, 4), (74, 17), (74, 34), (48, 21), (22, 34), (22, 17)]
    draw.polygon([(22, 17), (48, 4), (48, 21), (22, 34)], fill=wood_light, outline=(46, 26, 20, 255))
    draw.polygon([(48, 4), (74, 17), (74, 34), (48, 21)], fill=wood_mid, outline=(46, 26, 20, 255))
    # Headboard decorative crown & carving
    draw.line([(48, 7), (26, 18)], fill=wood_highlight, width=1)
    draw.line([(48, 7), (70, 18)], fill=wood_highlight, width=1)

    # 4. Mattress (White/Cream base)
    mattress_pts = [(48, 18), (88, 38), (48, 58), (8, 38)]
    draw.polygon(mattress_pts, fill=(245, 245, 240, 255), outline=(189, 189, 189, 255))

    # 5. Fluffy Pillow at top
    pillow_pts = [(48, 16), (64, 24), (48, 32), (32, 24)]
    draw.polygon(pillow_pts, fill=(255, 255, 255, 255), outline=(207, 216, 220, 255))
    # Pillow dent / shadow
    draw.line([(44, 24), (52, 24)], fill=(200, 210, 215, 255), width=2)

    # 6. Cozy Blue Quilt / Blanket (Cobalt Blue with gold trim)
    quilt_top = [(48, 28), (86, 47), (48, 66), (10, 47)]
    draw.polygon(quilt_top, fill=(25, 118, 210, 255), outline=(13, 71, 161, 255))
    # Quilt left drop
    draw.polygon([(10, 47), (48, 66), (48, 62), (10, 43)], fill=(21, 101, 192, 255))
    # Quilt right drop
    draw.polygon([(48, 66), (86, 47), (86, 43), (48, 62)], fill=(30, 136, 229, 255))

    # Folded Quilt Trim (Warm Golden Amber)
    trim_pts = [(48, 28), (70, 39), (48, 33), (26, 39)]
    draw.polygon(trim_pts, fill=(255, 193, 7, 255), outline=(255, 160, 0, 255))

    # Blanket folds & pattern
    draw.line([(48, 38), (76, 52)], fill=(30, 136, 229, 255), width=1)
    draw.line([(48, 48), (68, 58)], fill=(30, 136, 229, 255), width=1)
    draw.line([(48, 38), (20, 52)], fill=(13, 71, 161, 255), width=1)
    draw.line([(48, 48), (28, 58)], fill=(13, 71, 161, 255), width=1)

    return img

def create_bed_single_modern():
    # 1x2 footprint: Base width 96, base height 48. Total canvas 96x72.
    img = Image.new("RGBA", (96, 72), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Floor Shadow
    shadow_pts = [(48, 26), (92, 48), (48, 70), (4, 48)]
    draw.polygon(shadow_pts, fill=(0, 0, 0, 55))

    # 2. Modern Birch / Light Wood Frame
    birch_light = (222, 184, 135, 255)
    birch_mid = (198, 156, 109, 255)
    birch_dark = (160, 120, 80, 255)

    # Wooden Legs & platform
    draw.polygon([(4, 46), (48, 68), (48, 60), (4, 38)], fill=birch_dark, outline=(120, 85, 50, 255))
    draw.polygon([(48, 68), (92, 46), (92, 38), (48, 60)], fill=birch_mid, outline=(120, 85, 50, 255))

    # 3. Minimalist Slat Headboard
    for i, offset_y in enumerate([8, 14, 20]):
        draw.polygon([(26, 18 - offset_y), (48, 7 - offset_y), (48, 10 - offset_y), (26, 21 - offset_y)], fill=birch_light)
        draw.polygon([(48, 7 - offset_y), (70, 18 - offset_y), (70, 21 - offset_y), (48, 10 - offset_y)], fill=birch_mid)

    # Headboard posts
    draw.polygon([(24, 0), (28, 2), (28, 28), (24, 26)], fill=birch_dark)
    draw.polygon([(68, 2), (72, 0), (72, 26), (68, 28)], fill=birch_mid)

    # 4. Mattress (Clean White)
    mattress_pts = [(48, 18), (88, 38), (48, 58), (8, 38)]
    draw.polygon(mattress_pts, fill=(250, 250, 250, 255), outline=(220, 220, 220, 255))

    # 5. Sage Green / Mint Quilt
    sage_main = (92, 138, 110, 255)
    sage_dark = (68, 108, 84, 255)
    sage_light = (118, 166, 136, 255)

    quilt_top = [(48, 26), (86, 45), (48, 64), (10, 45)]
    draw.polygon(quilt_top, fill=sage_main, outline=sage_dark)
    draw.polygon([(10, 45), (48, 64), (48, 60), (10, 41)], fill=sage_dark)
    draw.polygon([(48, 64), (86, 45), (86, 41), (48, 60)], fill=sage_light)

    # 6. Mustard Yellow End-Blanket
    mustard = (230, 168, 34, 255)
    mustard_dark = (190, 130, 18, 255)
    mustard_light = (248, 192, 60, 255)
    draw.polygon([(48, 50), (78, 65), (48, 65), (18, 50)], fill=mustard, outline=mustard_dark)

    # 7. Modern Double Pillows (White + Sage Accent)
    draw.polygon([(48, 15), (66, 24), (48, 33), (30, 24)], fill=(255, 255, 255, 255), outline=(210, 215, 215, 255))
    draw.polygon([(48, 20), (60, 26), (48, 32), (36, 26)], fill=sage_light, outline=sage_dark)

    return img

def create_bed_double_king():
    # 2x2 footprint: Base width 128, base height 64. Total canvas 128x96.
    img = Image.new("RGBA", (128, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Floor Shadow
    shadow_pts = [(64, 30), (124, 60), (64, 92), (4, 60)]
    draw.polygon(shadow_pts, fill=(0, 0, 0, 60))

    # 2. Rich Mahogany / Dark Walnut Bed Frame
    mahogany_dark = (58, 28, 24, 255)
    mahogany_mid = (87, 42, 36, 255)
    mahogany_light = (118, 59, 50, 255)
    gold_trim = (245, 197, 66, 255)

    # Base boards
    draw.polygon([(4, 58), (64, 88), (64, 78), (4, 48)], fill=mahogany_dark, outline=(35, 15, 12, 255))
    draw.polygon([(64, 88), (124, 58), (124, 48), (64, 78)], fill=mahogany_mid, outline=(35, 15, 12, 255))

    # 3. Grand Carved Headboard
    # Left wing
    draw.polygon([(14, 42), (64, 17), (64, 36), (14, 61)], fill=mahogany_light, outline=(35, 15, 12, 255))
    # Right wing
    draw.polygon([(64, 17), (114, 42), (114, 61), (64, 36)], fill=mahogany_mid, outline=(35, 15, 12, 255))

    # Headboard Gold Carvings / Arch
    draw.polygon([(64, 8), (76, 14), (64, 20), (52, 14)], fill=gold_trim)
    draw.line([(52, 14), (20, 30)], fill=gold_trim, width=1)
    draw.line([(76, 14), (108, 30)], fill=gold_trim, width=1)

    # 4. King Mattress
    mattress_pts = [(64, 24), (118, 51), (64, 78), (10, 51)]
    draw.polygon(mattress_pts, fill=(248, 246, 242, 255), outline=(210, 205, 195, 255))

    # 5. Dual King Pillows
    # Left Pillow
    draw.polygon([(44, 25), (60, 33), (44, 41), (28, 33)], fill=(255, 255, 255, 255), outline=(215, 215, 215, 255))
    draw.line([(40, 33), (48, 33)], fill=(200, 200, 200, 255), width=2)
    # Right Pillow
    draw.polygon([(84, 25), (100, 33), (84, 41), (68, 33)], fill=(255, 255, 255, 255), outline=(215, 215, 215, 255))
    draw.line([(80, 33), (88, 33)], fill=(200, 200, 200, 255), width=2)

    # Decorative Throw Pillows (Gold + Crimson)
    draw.polygon([(48, 32), (58, 37), (48, 42), (38, 37)], fill=gold_trim, outline=(190, 140, 30, 255))
    draw.polygon([(80, 32), (90, 37), (80, 42), (70, 37)], fill=(183, 28, 28, 255), outline=(120, 15, 15, 255))

    # 6. Royal Crimson / Ruby Quilt
    crimson_main = (198, 40, 40, 255)
    crimson_dark = (142, 18, 18, 255)
    crimson_light = (229, 57, 53, 255)

    quilt_top = [(64, 38), (116, 64), (64, 88), (12, 64)]
    draw.polygon(quilt_top, fill=crimson_main, outline=crimson_dark)
    # Left drape
    draw.polygon([(12, 64), (64, 88), (64, 84), (12, 60)], fill=crimson_dark)
    # Right drape
    draw.polygon([(64, 88), (116, 64), (116, 60), (64, 84)], fill=crimson_light)

    # Folded Quilt Collar with Embroidered Gold Trimming
    draw.polygon([(64, 38), (96, 54), (64, 46), (32, 54)], fill=gold_trim, outline=(200, 150, 20, 255))
    draw.polygon([(64, 40), (92, 54), (64, 47), (36, 54)], fill=(255, 248, 225, 255))

    # 7. Satin Foot-Runner Blanket across the bottom
    draw.polygon([(64, 68), (102, 85), (64, 88), (26, 68)], fill=(55, 71, 79, 255), outline=(38, 50, 56, 255))
    draw.line([(64, 70), (98, 86)], fill=(84, 110, 122, 255), width=1)

    return img

def create_tileset(rustic, modern, king):
    # Combined tileset sheet with all 3 beds
    sheet = Image.new("RGBA", (128 * 3 + 32, 110), (0, 0, 0, 0))
    sheet.paste(rustic, (16, 20))
    sheet.paste(modern, (128 + 16, 20))
    sheet.paste(king, (128 * 2 + 16, 0))
    return sheet

if __name__ == "__main__":
    rustic = create_bed_single_rustic()
    rustic.save(os.path.join(OUTPUT_DIR, "bed_single_rustic.png"))
    print("Saved bed_single_rustic.png (96x72)")

    modern = create_bed_single_modern()
    modern.save(os.path.join(OUTPUT_DIR, "bed_single_modern.png"))
    print("Saved bed_single_modern.png (96x72)")

    king = create_bed_double_king()
    king.save(os.path.join(OUTPUT_DIR, "bed_double_king.png"))
    print("Saved bed_double_king.png (128x96)")

    # Also update bed.png with the cozy single rustic bed
    rustic.save(os.path.join(OUTPUT_DIR, "bed.png"))

    # Combined sheet
    tileset = create_tileset(rustic, modern, king)
    tileset.save(os.path.join(OUTPUT_DIR, "beds_tileset.png"))
    print("Saved beds_tileset.png")
