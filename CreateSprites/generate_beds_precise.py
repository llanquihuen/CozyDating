import os
from PIL import Image, ImageDraw

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "frontend", "assets", "images", "furniture")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. Single Bed Rustic (1x2 along Y, 96x72 px)
# Occupies (gx, gy) and (gx, gy + 1)
# Center of tile (gx, gy) is at (64, 40) in this PNG!
# -------------------------------------------------------------
def generate_bed_single_rustic():
    w, h = 96, 72
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Floor footprint vertices on the ground plane (z = 0):
    # P_top = (64, 24), P_tr = (96, 40), P_mr = (64, 56), P_bot = (32, 72), P_ml = (0, 56), P_tl = (32, 40)
    
    # 0. Floor Ambient Shadow
    shadow = [(64, 25), (94, 40), (64, 55), (32, 71), (2, 56), (32, 41)]
    draw.polygon(shadow, fill=(0, 0, 0, 55))

    # Bed height parameters
    leg_h = 4        # Height of wooden legs
    frame_h = 8      # Height of wooden side rails
    mattress_h = 8   # Mattress thickness
    headboard_h = 22 # Headboard height rising at back

    # Palette - Warm Oak & Deep Navy Blue
    wood_shadow = (45, 25, 18, 255)
    wood_dark = (68, 38, 28, 255)
    wood_mid = (102, 60, 44, 255)
    wood_light = (138, 86, 64, 255)
    wood_highlight = (168, 112, 86, 255)

    quilt_shadow = (15, 45, 80, 255)
    quilt_dark = (25, 75, 130, 255)
    quilt_mid = (35, 105, 175, 255)
    quilt_light = (50, 135, 215, 255)
    gold_trim = (235, 175, 45, 255)

    # 1. Wooden Legs touching ground vertices
    # Leg Top-Right (96, 40)
    draw.rectangle([92, 36, 95, 40], fill=wood_dark)
    # Leg Mid-Left (0, 56)
    draw.rectangle([1, 52, 4, 56], fill=wood_shadow)
    # Leg Bottom (32, 72)
    draw.rectangle([30, 68, 33, 72], fill=wood_mid)

    # 2. Wooden Frame Base (elevated by leg_h = 4)
    # Base level z = 4:
    # B_top = (64, 20), B_tr = (96, 36), B_mr = (64, 52), B_bot = (32, 68), B_ml = (0, 52), B_tl = (32, 36)
    # Top of frame z = 12:
    # F_top = (64, 12), F_tr = (96, 28), F_mr = (64, 44), F_bot = (32, 60), F_ml = (0, 44), F_tl = (32, 28)

    # Left-front side rail (From ml to bot)
    draw.polygon([(0, 52), (32, 68), (32, 60), (0, 44)], fill=wood_dark, outline=wood_shadow)
    # Right-front foot rail (From bot to mr)
    draw.polygon([(32, 68), (64, 52), (64, 44), (32, 60)], fill=wood_mid, outline=wood_shadow)

    # 3. Tall Wooden Headboard at Back (along tl -> top -> tr)
    # Headboard base z = 4, top z = 30
    hb_left = [(32, 36), (64, 20), (64, -2), (32, 14)]
    draw.polygon(hb_left, fill=wood_light, outline=wood_shadow)
    hb_right = [(64, 20), (96, 36), (96, 14), (64, -2)]
    draw.polygon(hb_right, fill=wood_mid, outline=wood_shadow)
    # Headboard top crown & wooden slats
    draw.line([(32, 14), (64, -2), (96, 14)], fill=wood_highlight, width=1)
    draw.line([(48, 28), (48, 6)], fill=wood_shadow, width=1)
    draw.line([(80, 28), (80, 6)], fill=wood_shadow, width=1)

    # 4. Mattress (White/Cream)
    # Top of mattress z = 18:
    # M_top = (64, 6), M_tr = (94, 22), M_mr = (64, 38), M_bot = (34, 54), M_ml = (4, 38), M_tl = (34, 22)
    draw.polygon([(4, 38), (34, 54), (64, 38), (94, 22), (64, 6), (34, 22)], fill=(245, 245, 240, 255), outline=(210, 210, 205, 255))
    # Mattress front thickness
    draw.polygon([(4, 38), (34, 54), (34, 58), (4, 42)], fill=(225, 225, 220, 255))
    draw.polygon([(34, 54), (64, 38), (64, 42), (34, 58)], fill=(235, 235, 230, 255))

    # 5. Soft Pillow at Head
    pillow = [(46, 15), (64, 6), (82, 15), (64, 24)]
    draw.polygon(pillow, fill=(255, 255, 255, 255), outline=(200, 210, 215, 255))
    draw.line([(58, 16), (70, 16)], fill=(210, 220, 225, 255), width=2)

    # 6. Cozy Blue Quilt / Blanket with Folds
    quilt_top = [(34, 24), (64, 18), (88, 30), (58, 46), (34, 54), (10, 42)]
    draw.polygon(quilt_top, fill=quilt_mid, outline=quilt_dark)
    # Quilt left overhang
    draw.polygon([(10, 42), (34, 54), (34, 58), (10, 46)], fill=quilt_dark, outline=quilt_shadow)
    # Quilt right overhang
    draw.polygon([(34, 54), (58, 46), (58, 50), (34, 58)], fill=quilt_mid, outline=quilt_dark)
    # Golden Trim folded collar
    collar = [(34, 24), (64, 18), (88, 30), (64, 26)]
    draw.polygon(collar, fill=gold_trim, outline=(200, 140, 30, 255))

    # Realistic diagonal blanket folds
    draw.line([(24, 42), (54, 28)], fill=quilt_light, width=1)
    draw.line([(32, 48), (68, 32)], fill=quilt_light, width=1)
    draw.line([(22, 44), (52, 30)], fill=quilt_dark, width=1)

    return img

# -------------------------------------------------------------
# 2. Single Bed Modern / Nordic (1x2 along Y, 96x72 px)
# -------------------------------------------------------------
def generate_bed_single_modern():
    w, h = 96, 72
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 0. Floor Shadow
    shadow = [(64, 25), (94, 40), (64, 55), (32, 71), (2, 56), (32, 41)]
    draw.polygon(shadow, fill=(0, 0, 0, 50))

    # Palette - Light Birch & Sage Green / Mustard
    birch_shadow = (140, 100, 65, 255)
    birch_dark = (175, 135, 95, 255)
    birch_mid = (210, 175, 135, 255)
    birch_light = (235, 205, 170, 255)

    sage_dark = (55, 90, 70, 255)
    sage_mid = (80, 125, 100, 255)
    sage_light = (110, 160, 130, 255)
    mustard = (225, 165, 35, 255)

    # 1. Round Birch Legs
    draw.rectangle([92, 36, 95, 40], fill=birch_dark)
    draw.rectangle([1, 52, 4, 56], fill=birch_shadow)
    draw.rectangle([30, 68, 33, 72], fill=birch_mid)

    # 2. Clean Platform Frame
    draw.polygon([(0, 52), (32, 68), (32, 62), (0, 46)], fill=birch_dark, outline=birch_shadow)
    draw.polygon([(32, 68), (64, 52), (64, 46), (32, 62)], fill=birch_mid, outline=birch_shadow)

    # 3. Minimalist Slat Headboard
    for i in range(3):
        yo = i * 6
        draw.polygon([(32, 28 - yo), (64, 12 - yo), (64, 9 - yo), (32, 25 - yo)], fill=birch_light)
        draw.polygon([(64, 12 - yo), (96, 28 - yo), (96, 25 - yo), (64, 9 - yo)], fill=birch_mid)
    # Headboard side posts
    draw.rectangle([30, 8, 33, 36], fill=birch_dark)
    draw.rectangle([93, 8, 96, 36], fill=birch_mid)

    # 4. Mattress (Pure White)
    draw.polygon([(4, 38), (34, 54), (64, 38), (94, 22), (64, 6), (34, 22)], fill=(250, 250, 250, 255), outline=(220, 220, 220, 255))
    draw.polygon([(4, 38), (34, 54), (34, 58), (4, 42)], fill=(230, 230, 230, 255))
    draw.polygon([(34, 54), (64, 38), (64, 42), (34, 58)], fill=(240, 240, 240, 255))

    # 5. Dual Modern Pillows
    draw.polygon([(44, 16), (64, 6), (84, 16), (64, 26)], fill=(255, 255, 255, 255), outline=(215, 220, 220, 255))
    draw.polygon([(48, 19), (64, 11), (80, 19), (64, 27)], fill=sage_light, outline=sage_dark)

    # 6. Sage Green Duvet
    draw.polygon([(10, 42), (34, 54), (58, 46), (88, 30), (64, 18), (34, 24)], fill=sage_mid, outline=sage_dark)
    draw.polygon([(10, 42), (34, 54), (34, 58), (10, 46)], fill=sage_dark)
    draw.polygon([(34, 54), (58, 46), (58, 50), (34, 58)], fill=sage_mid)

    # 7. Mustard Throw Blanket at foot
    draw.polygon([(16, 47), (34, 56), (46, 50), (66, 40), (48, 35), (28, 41)], fill=mustard, outline=(180, 125, 15, 255))

    return img

# -------------------------------------------------------------
# 3. King Size Double Bed (2x2 tiles, 128x96 px)
# Occupies (0,0), (1,0), (0,1), (1,1)
# Center of the 2x2 grid is at (64, 48) in this PNG!
# Base vertices on ground:
# P_top = (64, 16), P_right = (128, 48), P_bot = (64, 80), P_left = (0, 48)
# -------------------------------------------------------------
def generate_bed_double_king():
    w, h = 128, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 0. Floor Shadow
    shadow = [(64, 18), (126, 48), (64, 80), (2, 48)]
    draw.polygon(shadow, fill=(0, 0, 0, 60))

    # Palette - Mahogany & Royal Crimson / Gold
    wood_shadow = (35, 15, 12, 255)
    wood_dark = (60, 28, 22, 255)
    wood_mid = (95, 48, 38, 255)
    wood_light = (130, 68, 54, 255)
    wood_highlight = (165, 95, 78, 255)
    gold = (245, 195, 55, 255)

    crimson_dark = (125, 15, 15, 255)
    crimson_mid = (175, 25, 25, 255)
    crimson_light = (215, 45, 45, 255)

    # 1. Sturdy Carved Wooden Legs
    draw.rectangle([124, 44, 127, 48], fill=wood_dark)
    draw.rectangle([1, 44, 4, 48], fill=wood_shadow)
    draw.rectangle([62, 76, 66, 80], fill=wood_mid)

    # 2. King Wooden Side Rails & Footboard
    draw.polygon([(0, 44), (64, 76), (64, 66), (0, 34)], fill=wood_dark, outline=wood_shadow)
    draw.polygon([(64, 76), (128, 44), (128, 34), (64, 66)], fill=wood_mid, outline=wood_shadow)
    # Gold carving accents on footboard
    draw.line([(16, 44), (48, 60)], fill=gold, width=1)
    draw.line([(80, 60), (112, 44)], fill=gold, width=1)

    # 3. Grand Royal Headboard
    # Top center rises to (64, -2)
    hb_left = [(0, 34), (64, 2), (64, -8), (0, 24)]
    draw.polygon(hb_left, fill=wood_light, outline=wood_shadow)
    hb_right = [(64, 2), (128, 34), (128, 24), (64, -8)]
    draw.polygon(hb_right, fill=wood_mid, outline=wood_shadow)
    # Headboard Gold Crest
    draw.polygon([(64, -6), (72, -2), (64, 2), (56, -2)], fill=gold)
    draw.line([(10, 26), (64, -3), (118, 26)], fill=wood_highlight, width=1)

    # 4. King Size Mattress
    draw.polygon([(6, 32), (64, 61), (122, 32), (64, 3)], fill=(245, 242, 238, 255), outline=(210, 205, 200, 255))
    draw.polygon([(6, 32), (64, 61), (64, 66), (6, 37)], fill=(225, 220, 215, 255))
    draw.polygon([(64, 61), (122, 32), (122, 37), (64, 66)], fill=(235, 230, 225, 255))

    # 5. Dual Luxury Pillows + Accent Pillows
    # Left Main Pillow
    draw.polygon([(26, 22), (48, 11), (64, 19), (42, 30)], fill=(255, 255, 255, 255), outline=(210, 215, 220, 255))
    # Right Main Pillow
    draw.polygon([(64, 19), (80, 11), (102, 22), (86, 30)], fill=(255, 255, 255, 255), outline=(210, 215, 220, 255))
    # Left Gold Cushion
    draw.polygon([(36, 26), (48, 20), (56, 24), (44, 30)], fill=gold, outline=(190, 140, 20, 255))
    # Right Crimson Cushion
    draw.polygon([(72, 24), (80, 20), (92, 26), (84, 30)], fill=crimson_light, outline=crimson_dark)

    # 6. Royal Crimson Quilt
    draw.polygon([(10, 36), (64, 63), (118, 36), (88, 21), (64, 25), (40, 21)], fill=crimson_mid, outline=crimson_dark)
    # Left drape
    draw.polygon([(10, 36), (64, 63), (64, 68), (10, 41)], fill=crimson_dark, outline=wood_shadow)
    # Right drape
    draw.polygon([(64, 63), (118, 36), (118, 41), (64, 68)], fill=crimson_mid, outline=crimson_dark)

    # Gold Trimmed Collar
    draw.polygon([(40, 21), (64, 25), (88, 21), (64, 29)], fill=gold, outline=(190, 140, 20, 255))

    # 7. Satin Bed-Runner Blanket across foot
    draw.polygon([(24, 47), (64, 67), (104, 47), (88, 39), (64, 51), (40, 39)], fill=(45, 55, 65, 255), outline=(25, 35, 45, 255))

    return img

if __name__ == "__main__":
    rustic = generate_bed_single_rustic()
    rustic.save(os.path.join(OUTPUT_DIR, "bed_single_rustic.png"))
    rustic.save(os.path.join(OUTPUT_DIR, "bed.png"))
    print("Saved bed_single_rustic.png & bed.png (96x72)")

    modern = generate_bed_single_modern()
    modern.save(os.path.join(OUTPUT_DIR, "bed_single_modern.png"))
    print("Saved bed_single_modern.png (96x72)")

    king = generate_bed_double_king()
    king.save(os.path.join(OUTPUT_DIR, "bed_double_king.png"))
    print("Saved bed_double_king.png (128x96)")
