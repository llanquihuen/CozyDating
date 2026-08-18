import os
from PIL import Image, ImageDraw, ImageOps

BASE_ASSETS = os.path.join(os.path.dirname(__file__), "frontend", "assets", "images")
WALLPAPER_DIR = os.path.join(BASE_ASSETS, "wallpaper")
FLOORS_DIR = os.path.join(BASE_ASSETS, "floors")
FURNITURE_DIR = os.path.join(BASE_ASSETS, "furniture")

os.makedirs(WALLPAPER_DIR, exist_ok=True)
os.makedirs(FLOORS_DIR, exist_ok=True)
os.makedirs(FURNITURE_DIR, exist_ok=True)

# -------------------------------------------------------------
# 1. FLOORS & WALLPAPERS
# -------------------------------------------------------------
def make_square_floor(name, draw_fn):
    w, h = 256, 256
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_fn(draw, w, h)
    img.save(os.path.join(FLOORS_DIR, f"{name}.png"))
    print(f"Saved HD floor: {name}.png")

def draw_oak_parquet(draw, w, h):
    draw.rectangle([0, 0, w, h], fill=(130, 95, 80, 255))
    block_size = 32
    plank_w = 8
    for bx in range(0, w, block_size):
        for by in range(0, h, block_size):
            is_horizontal = ((bx // block_size) + (by // block_size)) % 2 == 0
            # Block background
            draw.rectangle([bx, by, bx + block_size - 1, by + block_size - 1], fill=(145, 112, 98, 255))
            
            if is_horizontal:
                # 4 horizontal planks per block
                for i, py in enumerate(range(by, by + block_size, plank_w)):
                    # Varied oak tones
                    shade_offset = ((bx * 7 + py * 13) % 4) * 6
                    p_col = (155 + shade_offset, 120 + shade_offset, 105 + shade_offset, 255)
                    draw.rectangle([bx + 1, py + 1, bx + block_size - 2, py + plank_w - 2], fill=p_col)
                    # Grain lines
                    draw.line([(bx + 3, py + 2), (bx + block_size - 4, py + 2)], fill=(185 + shade_offset, 145 + shade_offset, 130 + shade_offset, 200), width=1)
                    draw.line([(bx + 8, py + 5), (bx + block_size - 8, py + 5)], fill=(120, 85, 75, 180), width=1)
                    # Plank joint groove
                    draw.line([(bx, py), (bx + block_size - 1, py)], fill=(95, 65, 55, 255), width=1)
            else:
                # 4 vertical planks per block
                for i, px in enumerate(range(bx, bx + block_size, plank_w)):
                    shade_offset = ((px * 11 + by * 5) % 4) * 6
                    p_col = (145 + shade_offset, 110 + shade_offset, 98 + shade_offset, 255)
                    draw.rectangle([px + 1, by + 1, px + plank_w - 2, by + block_size - 2], fill=p_col)
                    draw.line([(px + 2, by + 3), (px + 2, by + block_size - 4)], fill=(175 + shade_offset, 138 + shade_offset, 122 + shade_offset, 200), width=1)
                    draw.line([(px + 5, by + 8), (px + 5, by + block_size - 8)], fill=(115, 80, 70, 180), width=1)
                    draw.line([(px, by), (px, by + block_size - 1)], fill=(95, 65, 55, 255), width=1)
            
            # Bevel frame around the whole 32x32 block
            draw.line([(bx, by), (bx + block_size - 1, by)], fill=(180, 145, 130, 150), width=1)
            draw.line([(bx, by), (bx, by + block_size - 1)], fill=(180, 145, 130, 150), width=1)
            draw.line([(bx + block_size - 1, by), (bx + block_size - 1, by + block_size - 1)], fill=(80, 50, 42, 200), width=1)
            draw.line([(bx, by + block_size - 1), (bx + block_size - 1, by + block_size - 1)], fill=(80, 50, 42, 200), width=1)

def draw_dark_walnut(draw, w, h):
    draw.rectangle([0, 0, w, h], fill=(38, 22, 18, 255))
    plank_h = 16
    for y in range(0, h, plank_h):
        shade = 8 if ((y // plank_h) % 2 == 0) else 0
        fill_col = (54 + shade, 34 + shade, 28 + shade, 255)
        draw.rectangle([0, y + 1, w, y + plank_h - 2], fill=fill_col)
        # Longitudinal Wood Grain waves
        draw.line([(0, y + 2), (w, y + 2)], fill=(85 + shade, 55 + shade, 46 + shade, 160), width=1)
        draw.line([(12, y + 7), (w - 20, y + 7)], fill=(75, 48, 40, 200), width=1)
        draw.line([(25, y + 11), (w - 10, y + 11)], fill=(35, 18, 14, 200), width=1)
        # Organic Wood Knots
        if (y // plank_h) % 3 == 1:
            kx = 45 + ((y * 17) % 150)
            draw.ellipse([kx, y + 5, kx + 8, y + 9], fill=(28, 14, 11, 255), outline=(75, 48, 40, 255))
        # Staggered Butt Joints with Brass Nails
        stagger = 80 if ((y // plank_h) % 2 == 0) else 40
        for x in range(stagger, w, 96):
            draw.line([(x, y + 1), (x, y + plank_h - 2)], fill=(25, 12, 10, 255), width=1)
            draw.point([(x - 2, y + 4), (x + 2, y + 4)], fill=(180, 140, 50, 255))
            draw.point([(x - 2, y + 11), (x + 2, y + 11)], fill=(180, 140, 50, 255))
        # Chamfer Groove between planks
        draw.line([(0, y), (w, y)], fill=(20, 10, 8, 255), width=1)

def draw_checker_marble(draw, w, h):
    tile_size = 32
    # Base lechada / grout
    draw.rectangle([0, 0, w, h], fill=(60, 65, 70, 255))
    for x in range(0, w, tile_size):
        for y in range(0, h, tile_size):
            is_white = ((x // tile_size) + (y // tile_size)) % 2 == 0
            if is_white:
                # Italian Carrara White Marble
                draw.rectangle([x + 1, y + 1, x + tile_size - 2, y + tile_size - 2], fill=(245, 247, 250, 255))
                # Soft Gray Marble Veining
                draw.line([(x + 3, y + 6), (x + 14, y + 18)], fill=(210, 218, 225, 220), width=1)
                draw.line([(x + 14, y + 18), (x + 22, y + 15)], fill=(218, 224, 230, 200), width=1)
                draw.line([(x + 22, y + 15), (x + 28, y + 26)], fill=(205, 214, 222, 180), width=1)
                # Subtle Gold Vein
                draw.line([(x + 10, y + 4), (x + 18, y + 12)], fill=(225, 215, 185, 160), width=1)
                # Specular Polished Highlight Top-Left
                draw.line([(x + 2, y + 2), (x + tile_size - 3, y + 2)], fill=(255, 255, 255, 255), width=1)
                draw.line([(x + 2, y + 2), (x + 2, y + tile_size - 3)], fill=(255, 255, 255, 255), width=1)
            else:
                # Nero Marquina Black Marble
                draw.rectangle([x + 1, y + 1, x + tile_size - 2, y + tile_size - 2], fill=(32, 36, 42, 255))
                # Delicate White Calcite Veins
                draw.line([(x + 5, y + 24), (x + 16, y + 10)], fill=(75, 85, 95, 200), width=1)
                draw.line([(x + 16, y + 10), (x + 26, y + 6)], fill=(90, 102, 114, 220), width=1)
                draw.line([(x + 12, y + 28), (x + 24, y + 18)], fill=(65, 75, 85, 180), width=1)
                # Soft Gloss Reflection
                draw.line([(x + 2, y + 2), (x + tile_size - 3, y + 2)], fill=(65, 75, 85, 180), width=1)
            # 3D Grout Edge Shadow
            draw.line([(x + 1, y + tile_size - 2), (x + tile_size - 2, y + tile_size - 2)], fill=(20, 22, 25, 180), width=1)
            draw.line([(x + tile_size - 2, y + 1), (x + tile_size - 2, y + tile_size - 2)], fill=(20, 22, 25, 180), width=1)

def draw_terracotta(draw, w, h):
    # Sandy Mortar Grout
    draw.rectangle([0, 0, w, h], fill=(215, 202, 188, 255))
    tile_size = 32
    for x in range(0, w, tile_size):
        for y in range(0, h, tile_size):
            # Handcrafted Clay Color Variation
            h_val = (x * 7 + y * 11) % 4
            if h_val == 0:
                col = (218, 72, 28, 255)
            elif h_val == 1:
                col = (205, 62, 20, 255)
            elif h_val == 2:
                col = (230, 85, 36, 255)
            else:
                col = (195, 55, 15, 255)
            draw.rectangle([x + 2, y + 2, x + tile_size - 3, y + tile_size - 3], fill=col)
            # Kiln Fire Gradient Center Halo
            draw.rectangle([x + 6, y + 6, x + tile_size - 7, y + tile_size - 7], fill=(238, 98, 48, 160))
            # Clay Texture Specks
            draw.point([(x + 8, y + 12), (x + 22, y + 18), (x + 14, y + 24)], fill=(160, 40, 10, 200))
            # Weathered Terracotta Edge Highlight & Shadow
            draw.line([(x + 3, y + 3), (x + tile_size - 4, y + 3)], fill=(250, 120, 65, 200), width=1)
            draw.line([(x + 3, y + 3), (x + 3, y + tile_size - 4)], fill=(250, 120, 65, 200), width=1)
            draw.line([(x + 3, y + tile_size - 3), (x + tile_size - 3, y + tile_size - 3)], fill=(145, 35, 10, 220), width=1)
            draw.line([(x + tile_size - 3, y + 3), (x + tile_size - 3, y + tile_size - 3)], fill=(145, 35, 10, 220), width=1)

def draw_tatami(draw, w, h):
    # Woven Rush Straw Mats (64x32)
    draw.rectangle([0, 0, w, h], fill=(195, 222, 160, 255))
    mat_w, mat_h = 64, 32
    for x in range(0, w, mat_w):
        for y in range(0, h, mat_h):
            is_alt = ((x // mat_w) + (y // mat_h)) % 2 == 0
            base_col = (198, 225, 162, 255) if is_alt else (186, 214, 150, 255)
            draw.rectangle([x, y, x + mat_w - 1, y + mat_h - 1], fill=base_col)
            # Fine Igusa Rush Weave Fibers
            for sy in range(y + 2, y + mat_h - 2, 2):
                draw.line([(x + 2, sy), (x + mat_w - 3, sy)], fill=(172, 200, 136, 220), width=1)
                draw.line([(x + 6, sy + 1), (x + mat_w - 6, sy + 1)], fill=(215, 238, 178, 140), width=1)
            # Black Silk Brocade Borders (Heri)
            draw.rectangle([x, y, x + mat_w - 1, y + 2], fill=(24, 24, 24, 255))
            draw.rectangle([x, y + mat_h - 3, x + mat_w - 1, y + mat_h - 1], fill=(24, 24, 24, 255))
            # Gold Brocade Stitching & Kamon Dots
            draw.line([(x + 2, y + 1), (x + mat_w - 3, y + 1)], fill=(212, 175, 55, 180), width=1)
            draw.line([(x + 2, y + mat_h - 2), (x + mat_w - 3, y + mat_h - 2)], fill=(212, 175, 55, 180), width=1)
            for cx in range(x + 12, x + mat_w - 8, 16):
                draw.point([(cx, y + 1), (cx, y + mat_h - 2)], fill=(255, 230, 120, 255))

def make_wallpaper(name, draw_fn):
    w, h = 256, 70
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_fn(draw, w, h)
    img.save(os.path.join(WALLPAPER_DIR, f"{name}.png"))
    print(f"Saved HD wallpaper: {name}.png")

def draw_wp_rustic_wood(draw, w, h):
    # Base dark wood
    draw.rectangle([0, 0, w, h], fill=(78, 52, 46, 255))
    # Vertical vertical planks (10px wide)
    plank_w = 10
    for x in range(0, w, plank_w):
        fill_col = (88, 58, 50, 255) if ((x // plank_w) % 2 == 0) else (74, 48, 42, 255)
        draw.rectangle([x, 0, x + plank_w - 1, h], fill=fill_col)
        # Wood grain texture lines
        draw.line([(x + 2, 6), (x + 2, h - 10)], fill=(108, 76, 65, 200), width=1)
        draw.line([(x + 5, 12), (x + 5, h - 14)], fill=(62, 39, 35, 200), width=1)
        draw.line([(x + 8, 4), (x + 8, h - 8)], fill=(102, 70, 60, 180), width=1)
        # Wood knots
        if (x // plank_w) % 3 == 1:
            ky = 18 + ((x * 7) % 32)
            draw.ellipse([x + 3, ky, x + 7, ky + 4], fill=(50, 30, 25, 255), outline=(108, 76, 65, 255))
        # Brass nails at top and bottom of each plank
        draw.ellipse([x + 4, 8, x + 6, 10], fill=(212, 175, 55, 255))
        draw.ellipse([x + 4, h - 14, x + 6, h - 12], fill=(212, 175, 55, 255))
        # Plank separator groove
        draw.line([(x + plank_w - 1, 0), (x + plank_w - 1, h)], fill=(40, 22, 18, 255), width=1)
    # Crown Moulding Top
    draw.rectangle([0, 0, w, 4], fill=(42, 24, 20, 255))
    draw.line([(0, 4), (w, 4)], fill=(125, 90, 78, 255), width=1)
    # Baseboard Bottom
    draw.rectangle([0, h - 8, w, h], fill=(42, 24, 20, 255))
    draw.line([(0, h - 8), (w, h - 8)], fill=(125, 90, 78, 255), width=1)

def draw_wp_brick_stone(draw, w, h):
    # Mortar base color
    draw.rectangle([0, 0, w, h], fill=(195, 185, 175, 255))
    brick_h = 7
    brick_w = 16
    for row, y in enumerate(range(4, h - 8, brick_h)):
        offset = (brick_w // 2) if (row % 2 == 1) else 0
        for x in range(-offset, w + brick_w, brick_w):
            # Varied natural brick color tones
            hash_val = (x * 13 + y * 7) % 5
            if hash_val == 0:
                col = (165, 82, 60, 255)
            elif hash_val == 1:
                col = (145, 68, 50, 255)
            elif hash_val == 2:
                col = (180, 95, 72, 255)
            elif hash_val == 3:
                col = (130, 58, 42, 255)
            else:
                col = (155, 75, 55, 255)
            # Brick Body
            draw.rectangle([x + 1, y + 1, x + brick_w - 1, y + brick_h - 1], fill=col)
            # 3D Highlight top-left and shadow bottom-right on each individual brick
            draw.line([(x + 1, y + 1), (x + brick_w - 1, y + 1)], fill=(210, 125, 100, 180), width=1)
            draw.line([(x + 1, y + 1), (x + 1, y + brick_h - 1)], fill=(210, 125, 100, 180), width=1)
            draw.line([(x + 1, y + brick_h - 1), (x + brick_w - 1, y + brick_h - 1)], fill=(85, 35, 25, 180), width=1)
            draw.line([(x + brick_w - 1, y + 1), (x + brick_w - 1, y + brick_h - 1)], fill=(85, 35, 25, 180), width=1)
    # Slate Top Trim & Baseboard
    draw.rectangle([0, 0, w, 4], fill=(100, 105, 110, 255))
    draw.line([(0, 4), (w, 4)], fill=(145, 150, 155, 255), width=1)
    draw.rectangle([0, h - 8, w, h], fill=(85, 90, 95, 255))
    draw.line([(0, h - 8), (w, h - 8)], fill=(125, 130, 135, 255), width=1)

def draw_wp_cozy_stripes(draw, w, h):
    # Victorian Green Silk with Cream & Gold Pinstripes + White Boiserie Wainscoting
    draw.rectangle([0, 0, w, h], fill=(85, 120, 100, 255))
    # Elegant Wallpaper Stripes (Upper 46px)
    for x in range(0, w, 16):
        # Cream Stripe
        draw.rectangle([x, 0, x + 6, h - 24], fill=(245, 240, 230, 255))
        # Gold Pinstripes
        draw.line([(x, 0), (x, h - 24)], fill=(212, 175, 55, 220), width=1)
        draw.line([(x + 6, 0), (x + 6, h - 24)], fill=(212, 175, 55, 220), width=1)
        # Subtle texture in the green panel
        draw.line([(x + 11, 0), (x + 11, h - 24)], fill=(75, 110, 90, 255), width=1)
    # Chair Rail Moulding (y=h-24)
    draw.rectangle([0, h - 24, w, h - 20], fill=(62, 39, 35, 255))
    draw.line([(0, h - 24), (w, h - 24)], fill=(212, 175, 55, 255), width=1)
    draw.line([(0, h - 20), (w, h - 20)], fill=(40, 22, 18, 255), width=1)
    # Lower Boiserie Wainscoting (Classic White Paneling)
    draw.rectangle([0, h - 20, w, h], fill=(248, 248, 245, 255))
    for x in range(0, w, 32):
        # Recessed Box Panel with Bevel & Shadow
        draw.rectangle([x + 3, h - 18, x + 29, h - 5], fill=(238, 238, 234, 255), outline=(215, 215, 210, 255), width=1)
        draw.line([(x + 4, h - 17), (x + 28, h - 17)], fill=(255, 255, 255, 255), width=1)
        draw.line([(x + 4, h - 17), (x + 4, h - 6)], fill=(255, 255, 255, 255), width=1)
        draw.line([(x + 4, h - 6), (x + 28, h - 6)], fill=(195, 195, 190, 255), width=1)
        draw.line([(x + 28, h - 17), (x + 28, h - 6)], fill=(195, 195, 190, 255), width=1)
    # Crown Moulding & Baseboard
    draw.rectangle([0, 0, w, 4], fill=(245, 240, 230, 255))
    draw.line([(0, 4), (w, 4)], fill=(212, 175, 55, 255), width=1)
    draw.rectangle([0, h - 4, w, h], fill=(225, 225, 220, 255))

def draw_wp_starry_night(draw, w, h):
    # Deep Midnight Navy Nebula Backdrop
    for y in range(h):
        ratio = y / float(h)
        r = int(14 + ratio * 8)
        g = int(20 + ratio * 15)
        b = int(45 + ratio * 35)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))
    # Soft Violet Nebula Clouds
    for x in range(0, w, 48):
        ny = 15 + ((x * 5) % 25)
        draw.ellipse([x - 10, ny - 6, x + 30, ny + 10], fill=(75, 45, 110, 70))
        draw.ellipse([x + 10, ny - 2, x + 45, ny + 8], fill=(45, 75, 130, 60))
    # Constellation Lines and Gold Stars
    for x in range(6, w, 24):
        sy = 10 + ((x * 7) % 36)
        # Twinkling 4-point Starburst
        draw.line([(x - 2, sy), (x + 2, sy)], fill=(255, 245, 160, 255), width=1)
        draw.line([(x, sy - 2), (x, sy + 2)], fill=(255, 245, 160, 255), width=1)
        draw.point([(x, sy)], fill=(255, 255, 255, 255))
        # Constellation Connections
        if (x // 24) % 2 == 0:
            tx = (x + 14) % w
            ty = sy + 8
            draw.line([(x, sy), (tx, ty)], fill=(255, 213, 79, 140), width=1)
            draw.rectangle([tx - 1, ty - 1, tx + 1, ty + 1], fill=(255, 213, 79, 255))
            draw.point([(tx, ty)], fill=(255, 255, 255, 255))
    # Gold Celestial Moon Phase Border at the Top
    draw.rectangle([0, 0, w, 5], fill=(30, 40, 65, 255))
    draw.line([(0, 5), (w, 5)], fill=(255, 213, 79, 200), width=1)
    for x in range(12, w, 32):
        # Golden Crescent Moons
        draw.ellipse([x - 2, 1, x + 3, 4], fill=(255, 213, 79, 255))
        draw.ellipse([x, 1, x + 4, 4], fill=(30, 40, 65, 255))
    draw.rectangle([0, h - 8, w, h], fill=(30, 40, 65, 255))
    draw.line([(0, h - 8), (w, h - 8)], fill=(255, 213, 79, 200), width=1)

def draw_wp_pastel_floral(draw, w, h):
    # Victorian Damask & English Tea Roses on Rose-Blush
    draw.rectangle([0, 0, w, h], fill=(245, 230, 230, 255))
    # Damask Arabesque Vines in background
    for y in range(8, h - 14, 20):
        for x in range(8, w, 24):
            draw.arc([x - 8, y - 8, x + 8, y + 8], 0, 180, fill=(230, 200, 200, 255), width=1)
            draw.arc([x, y, x + 16, y + 16], 180, 360, fill=(230, 200, 200, 255), width=1)
    # English Cottage Tea Roses
    for y in range(10, h - 14, 18):
        for x in range(10, w, 20):
            # Green leaves with stem
            draw.polygon([(x - 5, y + 2), (x - 8, y + 6), (x - 2, y + 4)], fill=(120, 180, 130, 255))
            draw.polygon([(x + 5, y - 2), (x + 8, y - 6), (x + 2, y - 4)], fill=(120, 180, 130, 255))
            # Multi-layered rose petals
            draw.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(235, 140, 150, 255))
            draw.ellipse([x - 2, y - 3, x + 3, y + 2], fill=(245, 175, 185, 255))
            draw.ellipse([x - 1, y - 1, x + 2, y + 1], fill=(255, 210, 215, 255))
            draw.point([(x, y)], fill=(195, 75, 90, 255))
    # Ornate White & Gold Crown Moulding
    draw.rectangle([0, 0, w, 5], fill=(255, 250, 245, 255))
    draw.line([(0, 5), (w, 5)], fill=(212, 175, 55, 255), width=1)
    draw.rectangle([0, h - 8, w, h], fill=(255, 250, 245, 255))
    draw.line([(0, h - 8), (w, h - 8)], fill=(212, 175, 55, 255), width=1)

# -------------------------------------------------------------
# 2. EXACT 2-TILE DETAILED SINGLE BED (96 x 72 px)
# -------------------------------------------------------------
def make_detailed_bed(rot):
    img = Image.new("RGBA", (96, 72), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Color Palette: Warm Polished Wood + White Sheet + Rich Red Quilt + Gold Embellishments
    c_wood_top = (141, 110, 99, 255)
    c_wood_left = (109, 76, 65, 255)
    c_wood_right = (78, 52, 46, 255)
    c_wood_dark = (54, 35, 30, 255)

    c_sheet_top = (252, 252, 248, 255)
    c_sheet_side = (225, 225, 220, 255)

    c_quilt_top = (229, 57, 53, 255)
    c_quilt_hi = (245, 85, 80, 255)
    c_quilt_side = (183, 28, 28, 255)
    c_quilt_dark = (136, 14, 79, 255)
    c_gold = (255, 213, 79, 255)

    c_pil_top = (255, 255, 255, 255)
    c_pil_side = (235, 235, 230, 255)

    if rot == 0:
        # Footprint 1x2 (extending Down-Left along Y):
        # Ground Diamond: N=(64, 20), E=(96, 36), S=(32, 68), W=(0, 52)
        draw.polygon([(64, 20), (96, 36), (32, 68), (0, 52)], fill=(0, 0, 0, 45))

        # Wooden Bed Frame (H=6px from z=0 to z=6)
        draw.polygon([(0, 52), (32, 68), (32, 62), (0, 46)], fill=c_wood_left, outline=c_wood_dark)
        draw.polygon([(32, 68), (96, 36), (96, 30), (32, 62)], fill=c_wood_right, outline=c_wood_dark)
        draw.polygon([(64, 14), (96, 30), (32, 62), (0, 46)], fill=c_wood_top)
        draw.line([(0, 46), (32, 62)], fill=(160, 130, 118, 255), width=1)

        # Mattress (H=6px from z=6 to z=12)
        draw.polygon([(2, 45), (32, 60), (32, 54), (2, 39)], fill=c_sheet_side)
        draw.polygon([(32, 60), (94, 29), (94, 23), (32, 54)], fill=c_sheet_side)
        draw.polygon([(64, 8), (94, 23), (32, 54), (2, 39)], fill=c_sheet_top)

        # Pillow with Soft Indentation
        draw.polygon([(46, 21), (64, 12), (76, 18), (58, 27)], fill=c_pil_top, outline=c_pil_side)
        draw.ellipse([54, 17, 66, 23], fill=(240, 240, 235, 255))

        # Red Quilt / Duvet
        draw.polygon([(1, 44), (32, 59.5), (32, 53), (1, 37.5)], fill=c_quilt_side, outline=c_quilt_dark)
        draw.polygon([(32, 59.5), (95, 28), (95, 21.5), (32, 53)], fill=c_quilt_dark, outline=c_quilt_dark)
        draw.polygon([(50, 15), (95, 21.5), (32, 53), (1, 37.5)], fill=c_quilt_top, outline=c_quilt_dark)
        # Quilted folds & Gold hem
        draw.polygon([(48, 14), (88, 19.5), (78, 24.5), (38, 19)], fill=c_sheet_top, outline=c_sheet_side)
        draw.line([(24, 45), (70, 31)], fill=c_gold, width=1) # Embroidered runner

        # Headboard with Carved Posts & Slat Panels
        draw.polygon([(64, 14), (96, 30), (96, 10), (64, -6)], fill=c_wood_right, outline=c_wood_dark)
        draw.polygon([(64, 14), (62, 13), (62, -7), (64, -6)], fill=c_wood_left, outline=c_wood_dark)
        draw.polygon([(64, -6), (96, 10), (94, 9), (62, -7)], fill=c_wood_top)
        draw.line([(68, -2), (92, 10)], fill=(175, 145, 130, 255), width=1)

    elif rot == 1:
        # Footprint 2x1 (extending Down-Right along X):
        # Ground Diamond: N=(32, 20), W=(0, 36), S=(64, 68), E=(96, 52)
        draw.polygon([(32, 20), (0, 36), (64, 68), (96, 52)], fill=(0, 0, 0, 45))

        draw.polygon([(0, 36), (64, 68), (64, 62), (0, 30)], fill=c_wood_left, outline=c_wood_dark)
        draw.polygon([(64, 68), (96, 52), (96, 46), (64, 62)], fill=c_wood_right, outline=c_wood_dark)
        draw.polygon([(32, 14), (0, 30), (64, 62), (96, 46)], fill=c_wood_top)
        draw.line([(0, 30), (64, 62)], fill=(160, 130, 118, 255), width=1)

        # Mattress
        draw.polygon([(2, 29), (64, 60), (64, 54), (2, 23)], fill=c_sheet_side)
        draw.polygon([(64, 60), (94, 45), (94, 39), (64, 54)], fill=c_sheet_side)
        draw.polygon([(32, 8), (2, 23), (64, 54), (94, 39)], fill=c_sheet_top)

        # Pillow
        draw.polygon([(20, 18), (32, 12), (50, 21), (38, 27)], fill=c_pil_top, outline=c_pil_side)
        draw.ellipse([30, 17, 42, 23], fill=(240, 240, 235, 255))

        # Red Quilt
        draw.polygon([(1, 28), (64, 59.5), (64, 53), (1, 21.5)], fill=c_quilt_side, outline=c_quilt_dark)
        draw.polygon([(64, 59.5), (95, 44), (95, 37.5), (64, 53)], fill=c_quilt_dark, outline=c_quilt_dark)
        draw.polygon([(46, 15), (1, 21.5), (64, 53), (95, 37.5)], fill=c_quilt_top, outline=c_quilt_dark)
        draw.polygon([(48, 14), (8, 19.5), (18, 24.5), (58, 19)], fill=c_sheet_top, outline=c_sheet_side)
        draw.line([(72, 45), (26, 31)], fill=c_gold, width=1)

        # Headboard
        draw.polygon([(32, 14), (0, 30), (0, 10), (32, -6)], fill=c_wood_left, outline=c_wood_dark)
        draw.polygon([(32, 14), (34, 13), (34, -7), (32, -6)], fill=c_wood_right, outline=c_wood_dark)
        draw.polygon([(32, -6), (0, 10), (2, 9), (34, -7)], fill=c_wood_top)
        draw.line([(28, -2), (4, 10)], fill=(175, 145, 130, 255), width=1)

    elif rot == 2:
        draw.polygon([(64, 20), (96, 36), (32, 68), (0, 52)], fill=(0, 0, 0, 45))
        draw.polygon([(0, 52), (32, 68), (32, 62), (0, 46)], fill=c_wood_left, outline=c_wood_dark)
        draw.polygon([(32, 68), (96, 36), (96, 30), (32, 62)], fill=c_wood_right, outline=c_wood_dark)
        draw.polygon([(64, 14), (96, 30), (32, 62), (0, 46)], fill=c_wood_top)
        draw.polygon([(64, 8), (94, 23), (32, 54), (2, 39)], fill=c_quilt_top)
        draw.polygon([(20, 38), (38, 29), (56, 38), (38, 47)], fill=c_pil_top, outline=c_pil_side)
        draw.polygon([(0, 46), (32, 62), (32, 42), (0, 26)], fill=c_wood_left, outline=c_wood_dark)
        draw.polygon([(32, 62), (34, 61), (34, 41), (32, 42)], fill=c_wood_right, outline=c_wood_dark)

    elif rot == 3:
        draw.polygon([(32, 20), (0, 36), (64, 68), (96, 52)], fill=(0, 0, 0, 45))
        draw.polygon([(0, 36), (64, 68), (64, 62), (0, 30)], fill=c_wood_left, outline=c_wood_dark)
        draw.polygon([(64, 68), (96, 52), (96, 46), (64, 62)], fill=c_wood_right, outline=c_wood_dark)
        draw.polygon([(32, 14), (0, 30), (64, 62), (96, 46)], fill=c_wood_top)
        draw.polygon([(32, 8), (2, 23), (64, 54), (94, 39)], fill=c_quilt_top)
        draw.polygon([(76, 38), (58, 29), (40, 38), (58, 47)], fill=c_pil_top, outline=c_pil_side)
        draw.polygon([(64, 62), (96, 46), (96, 26), (64, 42)], fill=c_wood_right, outline=c_wood_dark)
        draw.polygon([(64, 62), (62, 61), (62, 41), (64, 42)], fill=c_wood_left, outline=c_wood_dark)

    return img

# -------------------------------------------------------------
# 3. EXACT 2-TILE DETAILED SOFA (96 x 72 px)
# -------------------------------------------------------------
def make_detailed_sofa(rot):
    img = Image.new("RGBA", (96, 72), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Palette: Warm Burgundy Velvet & Gold Accent
    c_base_top = (215, 45, 45, 255)
    c_base_left = (183, 28, 28, 255)
    c_base_right = (136, 14, 79, 255)
    c_dark = (100, 10, 30, 255)
    c_cushion_top = (239, 83, 80, 255)
    c_cushion_side = (198, 40, 40, 255)
    c_wood = (62, 39, 35, 255)
    c_pillow = (255, 213, 79, 255)
    c_pillow_side = (230, 160, 0, 255)

    if rot == 0:
        # Footprint 2x1 (W=2, H=1): extends Down-Right along X
        # Ground Diamond: N=(32, 20), W=(0, 36), S=(64, 68), E=(96, 52)
        draw.polygon([(32, 20), (0, 36), (64, 68), (96, 52)], fill=(0, 0, 0, 50))

        # Wooden Base Frame
        draw.polygon([(0, 36), (64, 68), (64, 64), (0, 32)], fill=c_wood)
        draw.polygon([(64, 68), (96, 52), (96, 48), (64, 64)], fill=(42, 24, 20, 255))

        # Sofa Base Box
        draw.polygon([(0, 32), (64, 64), (64, 56), (0, 24)], fill=c_base_left, outline=c_dark)
        draw.polygon([(64, 64), (96, 48), (96, 40), (64, 56)], fill=c_base_right, outline=c_dark)
        draw.polygon([(32, 8), (0, 24), (64, 56), (96, 40)], fill=c_base_top)

        # Backrest with Tufted Button Details
        draw.polygon([(32, 8), (0, 24), (0, 6), (32, -10)], fill=c_base_left, outline=c_dark)
        draw.polygon([(32, 8), (96, 40), (96, 22), (32, -10)], fill=c_base_right, outline=c_dark)
        draw.polygon([(32, -10), (0, 6), (8, 10), (40, -6)], fill=c_cushion_top)
        # Tufted buttons
        for bx, by in [(8, 14), (18, 9), (28, 4)]:
            draw.ellipse([bx, by, bx + 2, by + 2], fill=c_dark)

        # Two Plump Seat Cushions
        # Cushion 1 (Left Tile):
        draw.polygon([(6, 23), (36, 38), (36, 44), (6, 29)], fill=c_cushion_side, outline=c_dark)
        draw.polygon([(36, 38), (50, 31), (50, 37), (36, 44)], fill=c_base_right, outline=c_dark)
        draw.polygon([(20, 16), (6, 23), (36, 38), (50, 31)], fill=c_cushion_top, outline=c_dark)

        # Cushion 2 (Right Tile):
        draw.polygon([(36, 38), (66, 53), (66, 59), (36, 44)], fill=c_cushion_side, outline=c_dark)
        draw.polygon([(66, 53), (90, 41), (90, 47), (66, 59)], fill=c_base_right, outline=c_dark)
        draw.polygon([(50, 31), (36, 38), (66, 53), (80, 46)], fill=c_cushion_top, outline=c_dark)

        # Left & Right Rolled Armrests
        draw.polygon([(0, 24), (12, 30), (12, 22), (0, 16)], fill=c_cushion_side, outline=c_dark)
        draw.polygon([(0, 16), (12, 22), (20, 18), (8, 12)], fill=c_cushion_top, outline=c_dark)
        draw.polygon([(84, 46), (96, 40), (96, 32), (84, 38)], fill=c_base_right, outline=c_dark)
        draw.polygon([(76, 36), (88, 42), (96, 32), (84, 26)], fill=c_cushion_top, outline=c_dark)

        # Cute Golden Accent Throw Pillow
        draw.polygon([(14, 24), (24, 19), (28, 23), (18, 28)], fill=c_pillow, outline=c_pillow_side)

    elif rot == 1:
        # Footprint 1x2 (W=1, H=2): extends Down-Left along Y
        # Ground Diamond: N=(64, 20), E=(96, 36), S=(32, 68), W=(0, 52)
        draw.polygon([(64, 20), (96, 36), (32, 68), (0, 52)], fill=(0, 0, 0, 50))

        draw.polygon([(0, 52), (32, 68), (32, 64), (0, 48)], fill=c_wood)
        draw.polygon([(32, 68), (96, 36), (96, 32), (32, 64)], fill=(42, 24, 20, 255))
        draw.polygon([(0, 48), (32, 64), (32, 56), (0, 40)], fill=c_base_left, outline=c_dark)
        draw.polygon([(32, 64), (96, 32), (96, 24), (32, 56)], fill=c_base_right, outline=c_dark)
        draw.polygon([(64, 8), (96, 24), (32, 56), (0, 40)], fill=c_base_top)

        # Backrest along Top-Right Edge ((64, 8) to (96, 24))
        draw.polygon([(64, 8), (96, 24), (96, 6), (64, -10)], fill=c_base_right, outline=c_dark)
        draw.polygon([(64, 8), (0, 40), (0, 22), (64, -10)], fill=c_base_left, outline=c_dark)
        draw.polygon([(64, -10), (96, 6), (88, 10), (56, -6)], fill=c_cushion_top)
        for bx, by in [(68, 4), (78, 9), (88, 14)]:
            draw.ellipse([bx, by, bx + 2, by + 2], fill=c_dark)

        # Two Cushions
        draw.polygon([(46, 31), (60, 38), (60, 44), (46, 37)], fill=c_cushion_side, outline=c_dark)
        draw.polygon([(60, 38), (90, 23), (90, 29), (60, 44)], fill=c_base_right, outline=c_dark)
        draw.polygon([(76, 16), (46, 31), (60, 38), (90, 23)], fill=c_cushion_top, outline=c_dark)

        draw.polygon([(16, 46), (30, 53), (30, 59), (16, 52)], fill=c_cushion_side, outline=c_dark)
        draw.polygon([(30, 53), (60, 38), (60, 44), (30, 59)], fill=c_base_right, outline=c_dark)
        draw.polygon([(46, 31), (16, 46), (30, 53), (60, 38)], fill=c_cushion_top, outline=c_dark)

        # Armrests
        draw.polygon([(96, 24), (84, 30), (84, 22), (96, 16)], fill=c_base_right, outline=c_dark)
        draw.polygon([(0, 40), (12, 46), (12, 38), (0, 32)], fill=c_cushion_side, outline=c_dark)

        # Throw pillow
        draw.polygon([(74, 24), (84, 19), (88, 23), (78, 28)], fill=c_pillow, outline=c_pillow_side)

    elif rot == 2:
        draw.polygon([(32, 20), (0, 36), (64, 68), (96, 52)], fill=(0, 0, 0, 50))
        draw.polygon([(0, 36), (64, 68), (64, 62), (0, 30)], fill=c_base_left, outline=c_dark)
        draw.polygon([(64, 68), (96, 52), (96, 46), (64, 62)], fill=c_base_right, outline=c_dark)
        draw.polygon([(32, 14), (0, 30), (64, 62), (96, 46)], fill=c_cushion_top)
        draw.polygon([(0, 30), (64, 62), (64, 44), (0, 12)], fill=c_base_left, outline=c_dark)
        draw.polygon([(64, 62), (96, 46), (96, 28), (64, 44)], fill=c_base_right, outline=c_dark)

    elif rot == 3:
        draw.polygon([(64, 20), (96, 36), (32, 68), (0, 52)], fill=(0, 0, 0, 50))
        draw.polygon([(0, 52), (32, 68), (32, 62), (0, 46)], fill=c_base_left, outline=c_dark)
        draw.polygon([(32, 68), (96, 36), (96, 30), (32, 62)], fill=c_base_right, outline=c_dark)
        draw.polygon([(64, 14), (96, 30), (32, 62), (0, 46)], fill=c_cushion_top)
        draw.polygon([(0, 46), (32, 62), (32, 44), (0, 28)], fill=c_base_left, outline=c_dark)
        draw.polygon([(32, 62), (96, 30), (96, 12), (32, 44)], fill=c_base_right, outline=c_dark)

    return img

# -------------------------------------------------------------
# 4. EXACT 2x2 DETAILED KING BED (128 x 96 px)
# -------------------------------------------------------------
def make_detailed_king_bed(rot):
    img = Image.new("RGBA", (128, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Ground Diamond for 2x2 tiles:
    # N=(64, 28), E=(128, 60), S=(64, 92), W=(0, 60)
    c_wood_top = (109, 76, 65, 255)
    c_wood_left = (78, 52, 46, 255)
    c_wood_right = (54, 35, 30, 255)
    c_wood_dark = (38, 20, 16, 255)

    c_mat_top = (252, 252, 248, 255)
    c_mat_side = (225, 225, 220, 255)
    c_duvet_top = (46, 125, 50, 255) # Emerald royal comforter
    c_duvet_side = (27, 94, 32, 255)
    c_gold = (255, 213, 79, 255)

    # 1. Base Ground Shadow
    draw.polygon([(64, 28), (128, 60), (64, 92), (0, 60)], fill=(0, 0, 0, 50))

    # 2. Frame Base Box (H=8px from z=0 to z=8)
    draw.polygon([(0, 60), (64, 92), (64, 84), (0, 52)], fill=c_wood_left, outline=c_wood_dark)
    draw.polygon([(64, 92), (128, 60), (128, 52), (64, 84)], fill=c_wood_right, outline=c_wood_dark)
    draw.polygon([(64, 20), (128, 52), (64, 84), (0, 52)], fill=c_wood_top)
    draw.line([(0, 52), (64, 84)], fill=(130, 95, 85, 255), width=1)

    # 3. King Mattress (H=6px from z=8 to z=14)
    draw.polygon([(2, 51), (64, 82), (64, 76), (2, 45)], fill=c_mat_side)
    draw.polygon([(64, 82), (126, 51), (126, 45), (64, 76)], fill=c_mat_side)
    draw.polygon([(64, 14), (126, 45), (64, 76), (2, 45)], fill=c_mat_top)

    # 4. Two Double Luxury Pillows
    draw.polygon([(28, 33), (48, 23), (62, 30), (42, 40)], fill=(255, 255, 255, 255), outline=(210, 210, 210, 255))
    draw.ellipse([40, 28, 52, 34], fill=(235, 235, 235, 255))
    draw.polygon([(66, 33), (86, 23), (100, 30), (80, 40)], fill=(255, 255, 255, 255), outline=(210, 210, 210, 255))
    draw.ellipse([78, 28, 90, 34], fill=(235, 235, 235, 255))

    # 5. Emerald Green Royal Quilt with Foldover & Gold Runner
    draw.polygon([(1, 50), (64, 81.5), (64, 75), (1, 43.5)], fill=c_duvet_side, outline=(20, 70, 25, 255))
    draw.polygon([(64, 81.5), (127, 50), (127, 43.5), (64, 75)], fill=c_duvet_side, outline=(20, 70, 25, 255))
    draw.polygon([(64, 30), (127, 43.5), (64, 75), (1, 43.5)], fill=c_duvet_top, outline=(20, 70, 25, 255))
    # Folded White Sheet Header
    draw.polygon([(64, 28), (114, 40), (100, 47), (50, 35)], fill=c_mat_top, outline=c_mat_side)
    draw.polygon([(64, 28), (14, 40), (28, 47), (78, 35)], fill=c_mat_top, outline=c_mat_side)
    # Gold Embroidered Runner
    draw.line([(24, 62), (64, 82), (104, 62)], fill=c_gold, width=2)

    # 6. Ornate Carved Wooden Headboard at NW and NE edges
    draw.polygon([(64, 20), (0, 52), (0, 26), (64, -6)], fill=c_wood_left, outline=c_wood_dark)
    draw.polygon([(64, 20), (128, 52), (128, 26), (64, -6)], fill=c_wood_right, outline=c_wood_dark)
    draw.polygon([(64, -6), (0, 26), (4, 24), (64, -8)], fill=c_wood_top)
    draw.polygon([(64, -6), (128, 26), (124, 24), (64, -8)], fill=c_wood_top)
    # Gold Crown Center Finial
    draw.polygon([(60, -6), (64, -12), (68, -6), (64, -4)], fill=c_gold, outline=(200, 160, 30, 255))

    return img

# -------------------------------------------------------------
# 5. 1x1 OTHER FURNITURE (Wardrobe, Plant, Table, Bookshelf)
# -------------------------------------------------------------
def make_wardrobe(rot):
    img = Image.new("RGBA", (64, 80), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.polygon([(32, 56), (58, 68), (32, 78), (6, 68)], fill=(0, 0, 0, 45))
    draw.polygon([(14, 28), (32, 18), (50, 28), (50, 70), (32, 76), (14, 70)], fill=(78, 52, 46, 255), outline=(46, 26, 20, 255))
    draw.polygon([(14, 28), (32, 18), (50, 28), (32, 34)], fill=(109, 76, 65, 255), outline=(46, 26, 20, 255))
    if rot in [0, 1]:
        draw.polygon([(18, 33), (32, 25), (46, 33), (46, 67), (32, 73), (18, 67)], fill=(179, 229, 252, 240), outline=(129, 212, 250, 255))
        draw.line([(22, 44), (42, 34)], fill=(255, 255, 255, 230), width=2)
        draw.ellipse([40, 48, 44, 52], fill=(255, 213, 79, 255))
    else:
        draw.line([(32, 34), (32, 76)], fill=(54, 35, 30, 255), width=2)
    draw.polygon([(12, 26), (32, 14), (52, 26), (32, 32)], fill=(255, 213, 79, 255), outline=(255, 179, 0, 255))
    return img if rot in [0, 2] else ImageOps.mirror(img)

def make_plant():
    img = Image.new("RGBA", (64, 54), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.polygon([(32, 28), (56, 40), (32, 52), (8, 40)], fill=(0, 0, 0, 45))
    draw.polygon([(22, 32), (32, 27), (42, 32), (38, 45), (32, 48), (26, 45)], fill=(216, 67, 21, 255), outline=(175, 45, 8, 255))
    draw.polygon([(20, 31), (32, 25), (44, 31), (42, 34), (32, 29), (22, 34)], fill=(230, 85, 35, 255))
    draw.ellipse([14, 10, 32, 28], fill=(38, 105, 42, 255), outline=(20, 75, 25, 255))
    draw.ellipse([32, 8, 50, 26], fill=(46, 125, 50, 255), outline=(27, 94, 32, 255))
    draw.ellipse([22, 2, 42, 22], fill=(67, 160, 71, 255), outline=(27, 94, 32, 255))
    draw.line([(32, 4), (32, 22)], fill=(129, 199, 132, 255), width=1)
    return img

def make_table():
    img = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.polygon([(32, 24), (58, 37), (32, 47), (6, 37)], fill=(0, 0, 0, 45))
    draw.rectangle([12, 30, 15, 38], fill=(62, 39, 35, 255))
    draw.rectangle([49, 30, 52, 38], fill=(62, 39, 35, 255))
    draw.rectangle([31, 38, 33, 44], fill=(62, 39, 35, 255))
    draw.ellipse([10, 16, 54, 34], fill=(109, 76, 65, 255), outline=(62, 39, 35, 255))
    draw.ellipse([12, 17, 52, 32], fill=(141, 110, 99, 255))
    draw.rectangle([30, 18, 34, 24], fill=(250, 250, 245, 255))
    draw.ellipse([30, 13, 34, 18], fill=(255, 179, 0, 255))
    draw.ellipse([38, 22, 48, 28], fill=(240, 242, 245, 255))
    return img

def make_bookshelf(rot):
    img = Image.new("RGBA", (64, 80), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.polygon([(32, 48), (62, 63), (32, 78), (2, 63)], fill=(0, 0, 0, 50))
    draw.polygon([(8, 36), (32, 24), (56, 36), (56, 70), (32, 78), (8, 70)], fill=(78, 52, 46, 255), outline=(46, 26, 20, 255))
    draw.polygon([(8, 8), (32, -4), (56, 8), (56, 36), (32, 24), (8, 36)], fill=(109, 76, 65, 255), outline=(46, 26, 20, 255))
    colors = [(229, 57, 53, 255), (30, 136, 229, 255), (67, 160, 71, 255), (255, 179, 0, 255)]
    for i, sy in enumerate([24, 42, 60]):
        draw.line([(12, sy + 6), (52, sy + 6)], fill=(54, 35, 30, 255), width=2)
        for j, bx in enumerate(range(14, 50, 5)):
            c = colors[(i * 3 + j) % len(colors)]
            draw.rectangle([bx, sy - 7, bx + 3, sy + 4], fill=c)
    return img if rot in [0, 2] else ImageOps.mirror(img)

def generate_all():
    make_square_floor("floor_oak_parquet", draw_oak_parquet)
    make_square_floor("floor_dark_walnut", draw_dark_walnut)
    make_square_floor("floor_checker_marble", draw_checker_marble)
    make_square_floor("floor_terracotta", draw_terracotta)
    make_square_floor("floor_tatami", draw_tatami)

    make_wallpaper("wallpaper_rustic_wood", draw_wp_rustic_wood)
    make_wallpaper("wallpaper_brick_stone", draw_wp_brick_stone)
    make_wallpaper("wallpaper_cozy_stripes", draw_wp_cozy_stripes)
    make_wallpaper("wallpaper_starry_night", draw_wp_starry_night)
    make_wallpaper("wallpaper_pastel_floral", draw_wp_pastel_floral)

    # Single Bed Rotations (1x2 and 2x1)
    for r in range(4):
        b = make_detailed_bed(r)
        b.save(os.path.join(FURNITURE_DIR, f"bed_single_rustic_{r}.png"))
        b.save(os.path.join(FURNITURE_DIR, f"bed_single_modern_{r}.png"))
        if r == 0:
            b.save(os.path.join(FURNITURE_DIR, "bed_single_rustic.png"))
            b.save(os.path.join(FURNITURE_DIR, "bed_single_modern.png"))
    print("Saved Detailed 2-tile Bed Sprites")

    # Sofa Rotations (2x1 and 1x2)
    for r in range(4):
        s = make_detailed_sofa(r)
        s.save(os.path.join(FURNITURE_DIR, f"sofa_cozy_{r}.png"))
        if r == 0:
            s.save(os.path.join(FURNITURE_DIR, "sofa_cozy.png"))
    print("Saved Detailed 2-tile Sofa Sprites")

    # King Bed (2x2)
    kb = make_detailed_king_bed(0)
    for r in range(4):
        kb.save(os.path.join(FURNITURE_DIR, f"bed_double_king_{r}.png"))
    kb.save(os.path.join(FURNITURE_DIR, "bed_double_king.png"))
    print("Saved Detailed 2x2 King Bed Sprites")

    # 1x1 Items
    for r in range(4):
        make_wardrobe(r).save(os.path.join(FURNITURE_DIR, f"wardrobe_mirror_{r}.png"))
        make_bookshelf(r).save(os.path.join(FURNITURE_DIR, f"bookshelf_wooden_{r}.png"))
        make_plant().save(os.path.join(FURNITURE_DIR, f"plant_monstera_{r}.png"))
        make_table().save(os.path.join(FURNITURE_DIR, f"table_tea_{r}.png"))
    make_wardrobe(0).save(os.path.join(FURNITURE_DIR, "wardrobe_mirror.png"))
    make_bookshelf(0).save(os.path.join(FURNITURE_DIR, "bookshelf_wooden.png"))
    make_plant().save(os.path.join(FURNITURE_DIR, "plant_monstera.png"))
    make_table().save(os.path.join(FURNITURE_DIR, "table_tea.png"))
    print("Saved 1x1 Furniture Items")

if __name__ == "__main__":
    generate_all()
