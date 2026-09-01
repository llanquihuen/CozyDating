import os
from PIL import Image, ImageDraw

OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend", "assets", "images", "furniture", "established_furniture"))
os.makedirs(OUTPUT_DIR, exist_ok=True)

def create_base_canvas(width=128, height=128):
    return Image.new("RGBA", (width, height), (0, 0, 0, 0))

def draw_iso_box(draw, cx, cy, rx, ry, h, top_color, left_color, right_color, outline_color=(30, 30, 40, 255)):
    # Top diamond
    top_poly = [
        (cx, cy - h - ry),
        (cx + rx, cy - h),
        (cx, cy - h + ry),
        (cx - rx, cy - h)
    ]
    # Left face
    left_poly = [
        (cx - rx, cy - h),
        (cx, cy - h + ry),
        (cx, cy + ry),
        (cx - rx, cy)
    ]
    # Right face
    right_poly = [
        (cx, cy - h + ry),
        (cx + rx, cy - h),
        (cx + rx, cy),
        (cx, cy + ry)
    ]
    draw.polygon(left_poly, fill=left_color, outline=outline_color)
    draw.polygon(right_poly, fill=right_color, outline=outline_color)
    draw.polygon(top_poly, fill=top_color, outline=outline_color)

def generate_furniture():
    items = {}

    # 1. Gaming PC Desk (Desk + Glowing RGB PC Tower + Monitor)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Desk base
    draw_iso_box(d, 64, 88, 30, 15, 24, (45, 45, 55, 255), (35, 35, 42, 255), (28, 28, 35, 255))
    # PC Case (RGB Tower on right)
    draw_iso_box(d, 82, 60, 8, 4, 18, (20, 20, 25, 255), (10, 10, 15, 255), (0, 229, 255, 255)) # Cyan RGB strip
    # Monitor (Center)
    draw_iso_box(d, 56, 56, 16, 2, 14, (60, 60, 70, 255), (40, 40, 50, 255), (245, 0, 87, 255)) # Magenta Screen
    # Keyboard & Mouse
    draw_iso_box(d, 54, 66, 10, 5, 2, (180, 180, 200, 255), (100, 100, 120, 255), (80, 80, 100, 255))
    items['gaming_pc_desk'] = img

    # 2. Home Theater TV (Living TV Unit with Large Screen)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # TV Lowboard Cabinet
    draw_iso_box(d, 64, 90, 32, 16, 16, (120, 85, 60, 255), (95, 65, 45, 255), (75, 50, 35, 255))
    # Big Flat Screen TV
    draw_iso_box(d, 64, 68, 26, 3, 28, (30, 35, 45, 255), (20, 25, 35, 255), (50, 60, 80, 255))
    # Screen display glow
    d.polygon([(44, 42), (78, 25), (78, 48), (44, 65)], fill=(33, 150, 243, 255), outline=(100, 200, 255, 255))
    items['home_theater_tv'] = img

    # 3. Vinyl Record Player (Turntable + Speakers)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Wood base
    draw_iso_box(d, 64, 80, 16, 8, 8, (180, 120, 70, 255), (140, 90, 50, 255), (110, 70, 40, 255))
    # Black Vinyl Disc
    d.ellipse([54, 64, 74, 74], fill=(20, 20, 20, 255), outline=(255, 215, 0, 255)) # Gold center
    d.ellipse([62, 67, 66, 71], fill=(255, 215, 0, 255))
    # Tonearm
    d.line([(72, 65), (66, 68)], fill=(200, 200, 200, 255), width=2)
    items['vinyl_record_player'] = img

    # 4. Acoustic Guitar Stand
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Stand tripod
    draw_iso_box(d, 64, 95, 12, 6, 4, (40, 40, 40, 255), (30, 30, 30, 255), (20, 20, 20, 255))
    # Guitar Body
    draw_iso_box(d, 64, 72, 10, 6, 22, (210, 140, 70, 255), (170, 110, 50, 255), (140, 90, 40, 255))
    # Soundhole
    d.ellipse([60, 58, 68, 64], fill=(40, 25, 15, 255))
    # Neck & Headstock
    draw_iso_box(d, 64, 42, 3, 2, 26, (120, 80, 40, 255), (100, 65, 30, 255), (80, 50, 20, 255))
    items['acoustic_guitar_stand'] = img

    # 5. Manga & Collectibles Shelf
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Tall Bookcase
    draw_iso_box(d, 64, 92, 20, 10, 52, (230, 215, 195, 255), (200, 180, 160, 255), (170, 150, 130, 255))
    # Colorful manga spines on shelves
    colors = [(255, 87, 34), (33, 150, 243), (76, 175, 80), (233, 30, 99), (156, 39, 176), (255, 193, 7)]
    for i, c in enumerate(colors):
        x = 52 + (i % 3) * 6
        y = 55 + (i // 3) * 16
        draw_iso_box(d, x, y, 2, 2, 8, c, c, c)
    # Chibi anime figurine on top shelf
    d.ellipse([61, 35, 67, 41], fill=(255, 200, 180, 255)) # Head
    d.polygon([(64, 32), (68, 38), (60, 38)], fill=(0, 229, 255, 255)) # Cyan anime hair
    items['manga_shelf'] = img

    # 6. Espresso Machine
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Metallic Espresso Body
    draw_iso_box(d, 64, 80, 12, 6, 16, (200, 205, 210, 255), (160, 165, 170, 255), (130, 135, 140, 255))
    # Pressure Gauge & Drip Tray
    d.ellipse([60, 68, 66, 74], fill=(240, 240, 240, 255), outline=(100, 100, 100, 255))
    # Portafilter handle
    d.line([(54, 76), (46, 80)], fill=(30, 30, 30, 255), width=3)
    # Little Espresso Cup
    draw_iso_box(d, 62, 78, 4, 2, 4, (255, 255, 255, 255), (220, 220, 220, 255), (180, 180, 180, 255))
    items['espresso_machine'] = img

    # 7. Tea Set Tabletop (Ceramic Teapot & Matcha/Tea cups)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Bamboo Tray
    draw_iso_box(d, 64, 82, 16, 8, 3, (210, 180, 130, 255), (180, 150, 100, 255), (150, 120, 80, 255))
    # Green/Earthy Teapot
    draw_iso_box(d, 60, 76, 6, 4, 8, (120, 160, 120, 255), (90, 130, 90, 255), (70, 100, 70, 255))
    d.line([(65, 70), (70, 68)], fill=(120, 160, 120, 255), width=2) # Spout
    # 2 Little tea cups
    draw_iso_box(d, 70, 78, 3, 2, 3, (240, 240, 230, 255), (200, 200, 190, 255), (160, 160, 150, 255))
    items['tea_set_table'] = img

    # 8. Polaroid Camera Tabletop
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Vintage Cream/Rainbow Polaroid Body
    draw_iso_box(d, 64, 80, 10, 6, 7, (245, 240, 230, 255), (215, 210, 200, 255), (185, 180, 170, 255))
    # Big Lens
    d.ellipse([59, 70, 69, 78], fill=(30, 30, 30, 255), outline=(100, 100, 100, 255))
    d.ellipse([62, 72, 66, 76], fill=(0, 200, 255, 255))
    # Polaroid photo coming out
    d.polygon([(52, 80), (60, 84), (56, 88), (48, 84)], fill=(255, 255, 255, 255), outline=(180, 180, 180, 255))
    items['polaroid_camera_table'] = img

    # 9. Monstera Plant Pot
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Terracotta Ceramic Pot
    draw_iso_box(d, 64, 96, 14, 8, 16, (215, 110, 75, 255), (180, 85, 55, 255), (150, 65, 40, 255))
    # Lush Monstera Leaves
    leaf_color = (46, 125, 50, 255)
    leaf_highlight = (76, 175, 80, 255)
    d.ellipse([46, 50, 66, 75], fill=leaf_color, outline=leaf_highlight)
    d.ellipse([62, 42, 82, 68], fill=leaf_highlight, outline=leaf_color)
    d.ellipse([54, 30, 76, 58], fill=leaf_color, outline=leaf_highlight)
    items['monstera_plant_pot'] = img

    # 10. Cat Tree Tower (Scratching Post & Cozy Bed)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Heavy base
    draw_iso_box(d, 64, 96, 20, 10, 6, (220, 210, 195, 255), (190, 180, 165, 255), (160, 150, 135, 255))
    # Sisal scratching pillar
    draw_iso_box(d, 64, 75, 6, 4, 30, (210, 190, 150, 255), (180, 160, 120, 255), (150, 130, 90, 255))
    # Platform 1
    draw_iso_box(d, 52, 60, 14, 7, 4, (230, 220, 205, 255), (200, 190, 175, 255), (170, 160, 145, 255))
    # Top Cozy Perch Bed
    draw_iso_box(d, 68, 40, 16, 8, 8, (240, 230, 215, 255), (210, 200, 185, 255), (180, 170, 155, 255))
    # Hanging Pom Pom toy
    d.line([(56, 62), (56, 72)], fill=(200, 200, 200, 255), width=1)
    d.ellipse([53, 72, 59, 78], fill=(255, 105, 180, 255))
    items['cat_tree_tower'] = img

    # 11. Pet Dog Bed
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Plush oval bed
    draw_iso_box(d, 64, 88, 22, 12, 10, (140, 120, 180, 255), (110, 90, 150, 255), (90, 70, 120, 255))
    # Inner soft cushion with bone print
    draw_iso_box(d, 64, 84, 16, 8, 4, (240, 230, 210, 255), (210, 200, 180, 255), (180, 170, 150, 255))
    # Small red toy bone
    d.polygon([(60, 78), (68, 82), (66, 84), (58, 80)], fill=(230, 50, 50, 255))
    items['pet_dog_bed'] = img

    # 12. Yoga Mat Floor
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Rolled out pastel teal yoga mat
    draw_iso_box(d, 64, 88, 26, 14, 2, (77, 182, 172, 255), (38, 166, 154, 255), (0, 137, 123, 255))
    # Water bottle
    draw_iso_box(d, 82, 80, 3, 2, 8, (255, 138, 101, 255), (244, 81, 30, 255), (216, 67, 21, 255))
    items['yoga_mat_floor'] = img

    # 13. Boardgame Box Set (D&D / RPG Box on Table)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Big RPG Box (Dragon / Dice art)
    draw_iso_box(d, 64, 80, 14, 8, 6, (186, 24, 27, 255), (140, 15, 20, 255), (100, 10, 15, 255))
    # Gold dragon emblem on box top
    d.ellipse([60, 72, 68, 78], fill=(255, 215, 0, 255))
    # D20 icosahedron die on table
    d.polygon([(78, 82), (84, 79), (82, 86)], fill=(255, 215, 0, 255), outline=(0, 0, 0, 255))
    items['boardgame_box_set'] = img

    # 14. Wall World Map (Corkboard with photos & pins)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    # Wall Frame (North wall orientation)
    d.polygon([(36, 40), (92, 12), (92, 64), (36, 92)], fill=(210, 180, 140, 255), outline=(130, 90, 50, 255))
    # Map continents
    d.ellipse([46, 45, 62, 60], fill=(100, 180, 100, 255))
    d.ellipse([66, 32, 82, 48], fill=(100, 180, 100, 255))
    # Colorful pushpins
    d.ellipse([54, 48, 57, 51], fill=(255, 0, 0, 255))
    d.ellipse([72, 36, 75, 39], fill=(255, 215, 0, 255))
    items['wall_world_map'] = img

    # 15. Wall Poster Anime (Studio Ghibli / Cyberpunk style poster)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    d.polygon([(40, 36), (88, 12), (88, 66), (40, 90)], fill=(30, 25, 50, 255), outline=(255, 215, 0, 255))
    # Giant Red Moon / Glowing Sun
    d.ellipse([54, 34, 74, 54], fill=(255, 64, 129, 255))
    # City / Robot Silhouette
    d.polygon([(48, 68), (62, 54), (76, 68), (84, 58), (84, 74), (48, 86)], fill=(10, 10, 20, 255))
    items['wall_poster_anime'] = img

    # 16. Wall Poster Cinema (Classic Film Noir / Sci-Fi poster)
    img = create_base_canvas()
    d = ImageDraw.Draw(img)
    d.polygon([(40, 36), (88, 12), (88, 66), (40, 90)], fill=(20, 20, 25, 255), outline=(220, 220, 220, 255))
    # Retro Sci-Fi UFO / Spotlight
    d.polygon([(64, 25), (46, 75), (82, 65)], fill=(255, 235, 59, 180))
    d.ellipse([58, 22, 70, 28], fill=(0, 229, 255, 255))
    items['wall_poster_cinema'] = img

    # Save all items with default and 4 rotation variants
    for item_id, base_img in items.items():
        # Save base item
        base_path = os.path.join(OUTPUT_DIR, f"{item_id}.png")
        base_img.save(base_path)
        print(f"Saved {base_path}")

        # Wall items have _n and _w variants
        if item_id.startswith("wall_"):
            n_path = os.path.join(OUTPUT_DIR, f"{item_id}_n.png")
            w_path = os.path.join(OUTPUT_DIR, f"{item_id}_w.png")
            base_img.save(n_path)
            # Flipped horizontally for west wall
            w_img = base_img.transpose(Image.FLIP_LEFT_RIGHT)
            w_img.save(w_path)
        else:
            # Floor / surface items have _rot0 to _rot3
            for r in range(4):
                rot_path = os.path.join(OUTPUT_DIR, f"{item_id}_rot{r}.png")
                # Slightly mirror/transform to indicate rotation
                if r == 0:
                    base_img.save(rot_path)
                elif r == 1:
                    base_img.transpose(Image.FLIP_LEFT_RIGHT).save(rot_path)
                elif r == 2:
                    base_img.save(rot_path)
                elif r == 3:
                    base_img.transpose(Image.FLIP_LEFT_RIGHT).save(rot_path)

if __name__ == "__main__":
    generate_furniture()
    print("All starter furniture items generated successfully!")
