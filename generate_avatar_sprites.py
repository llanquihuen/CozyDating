import os
from PIL import Image, ImageDraw

def create_sprite_sheet(draw_frame_fn, filename, width=128, height=192):
    # 4 cols x 32px = 128px, 4 rows x 48px = 192px
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    frame_w = 32
    frame_h = 48
    
    # Rows: 0: Down, 1: Up, 2: Left, 3: Right
    # Cols: 0: Idle1, 1: Walk1, 2: Idle2, 3: Walk2
    for row in range(4):
        dir_name = ["down", "up", "left", "right"][row]
        for col in range(4):
            walk_step = [0, -1, 0, 1][col] # Bobbing/leg displacement
            ox = col * frame_w
            oy = row * frame_h
            draw_frame_fn(draw, ox, oy, dir_name, col, walk_step)
            
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    img.save(filename, "PNG")
    print(f"Generated: {filename}")

# 1. BODY BASE
def draw_body(d, ox, oy, direction, col, step):
    # Head: center (16, 14), r=7
    hx, hy = ox + 16, oy + 13 + (1 if col in (1, 3) else 0)
    
    # Shadow
    d.ellipse([ox + 8, oy + 42, ox + 24, oy + 47], fill=(0, 0, 0, 70))
    
    # Torso Base (grayscale shades: 220 light, 180 mid, 140 shadow)
    d.rectangle([ox + 12, oy + 21 + (1 if col in (1, 3) else 0), ox + 20, oy + 32 + (1 if col in (1, 3) else 0)], fill=(200, 200, 200, 255))
    
    # Head Base
    d.ellipse([hx - 7, hy - 7, hx + 7, hy + 7], fill=(220, 220, 220, 255), outline=(150, 150, 150, 255))
    
    # Face details (Eyes/brows depending on direction)
    if direction == "down":
        d.rectangle([hx - 4, hy, hx - 2, hy + 2], fill=(40, 40, 40, 255))
        d.rectangle([hx + 2, hy, hx + 4, hy + 2], fill=(40, 40, 40, 255))
        d.point([hx, hy + 4], fill=(160, 160, 160, 255)) # nose
    elif direction == "left":
        d.rectangle([hx - 5, hy, hx - 3, hy + 2], fill=(40, 40, 40, 255))
        d.point([hx - 6, hy + 3], fill=(160, 160, 160, 255))
    elif direction == "right":
        d.rectangle([hx + 3, hy, hx + 5, hy + 2], fill=(40, 40, 40, 255))
        d.point([hx + 6, hy + 3], fill=(160, 160, 160, 255))
    elif direction == "up":
        pass # back of head
        
    # Arms
    if direction in ("down", "up"):
        # Left arm & Right arm
        d.rectangle([ox + 9, oy + 22 - step * 2, ox + 11, oy + 30 - step * 2], fill=(190, 190, 190, 255))
        d.rectangle([ox + 21, oy + 22 + step * 2, ox + 23, oy + 30 + step * 2], fill=(190, 190, 190, 255))
    elif direction == "left":
        d.rectangle([ox + 14, oy + 22 + step * 2, ox + 17, oy + 30 + step * 2], fill=(190, 190, 190, 255))
    elif direction == "right":
        d.rectangle([ox + 15, oy + 22 - step * 2, ox + 18, oy + 30 - step * 2], fill=(190, 190, 190, 255))
        
    # Legs & Feet
    if direction in ("down", "up"):
        d.rectangle([ox + 12, oy + 33, ox + 15, oy + 42 + (step if col in (1, 3) else 0)], fill=(170, 170, 170, 255))
        d.rectangle([ox + 17, oy + 33, ox + 20, oy + 42 - (step if col in (1, 3) else 0)], fill=(170, 170, 170, 255))
    elif direction == "left":
        d.rectangle([ox + 14 + step * 3, oy + 33, ox + 18 + step * 3, oy + 43], fill=(170, 170, 170, 255))
    elif direction == "right":
        d.rectangle([ox + 14 - step * 3, oy + 33, ox + 18 - step * 3, oy + 43], fill=(170, 170, 170, 255))

# 2. HAIR STYLES
def draw_hair_short(d, ox, oy, direction, col, step):
    hx, hy = ox + 16, oy + 13 + (1 if col in (1, 3) else 0)
    if direction == "down":
        d.ellipse([hx - 8, hy - 9, hx + 8, hy + 1], fill=(220, 220, 220, 255))
        d.polygon([(hx - 7, hy - 3), (hx - 4, hy + 1), (hx - 1, hy - 2), (hx + 3, hy + 1), (hx + 7, hy - 3)], fill=(200, 200, 200, 255))
    elif direction == "up":
        d.ellipse([hx - 8, hy - 9, hx + 8, hy + 5], fill=(220, 220, 220, 255))
    elif direction == "left":
        d.ellipse([hx - 7, hy - 9, hx + 8, hy + 2], fill=(220, 220, 220, 255))
        d.polygon([(hx - 7, hy), (hx - 3, hy + 2), (hx - 1, hy - 1)], fill=(200, 200, 200, 255))
    elif direction == "right":
        d.ellipse([hx - 8, hy - 9, hx + 7, hy + 2], fill=(220, 220, 220, 255))
        d.polygon([(hx + 7, hy), (hx + 3, hy + 2), (hx + 1, hy - 1)], fill=(200, 200, 200, 255))

def draw_hair_long(d, ox, oy, direction, col, step):
    hx, hy = ox + 16, oy + 13 + (1 if col in (1, 3) else 0)
    if direction == "down":
        d.ellipse([hx - 8, hy - 9, hx + 8, hy + 1], fill=(220, 220, 220, 255))
        d.rectangle([hx - 8, hy - 2, hx - 5, hy + 10], fill=(200, 200, 200, 255))
        d.rectangle([hx + 5, hy - 2, hx + 8, hy + 10], fill=(200, 200, 200, 255))
    elif direction == "up":
        d.ellipse([hx - 8, hy - 9, hx + 8, hy + 12], fill=(220, 220, 220, 255))
    elif direction == "left":
        d.ellipse([hx - 7, hy - 9, hx + 8, hy + 2], fill=(220, 220, 220, 255))
        d.rectangle([hx + 2, hy, hx + 8, hy + 11], fill=(200, 200, 200, 255))
    elif direction == "right":
        d.ellipse([hx - 8, hy - 9, hx + 7, hy + 2], fill=(220, 220, 220, 255))
        d.rectangle([hx - 8, hy, hx - 2, hy + 11], fill=(200, 200, 200, 255))

def draw_hair_curly(d, ox, oy, direction, col, step):
    hx, hy = ox + 16, oy + 13 + (1 if col in (1, 3) else 0)
    d.ellipse([hx - 10, hy - 10, hx + 10, hy + 3], fill=(210, 210, 210, 255))
    d.ellipse([hx - 9, hy - 4, hx - 4, hy + 5], fill=(220, 220, 220, 255))
    d.ellipse([hx + 4, hy - 4, hx + 9, hy + 5], fill=(220, 220, 220, 255))

def draw_hair_cap(d, ox, oy, direction, col, step):
    hx, hy = ox + 16, oy + 13 + (1 if col in (1, 3) else 0)
    d.ellipse([hx - 9, hy - 9, hx + 9, hy - 1], fill=(200, 200, 200, 255))
    if direction == "down":
        d.rectangle([hx - 8, hy - 2, hx + 8, hy], fill=(170, 170, 170, 255))
    elif direction == "left":
        d.rectangle([hx - 11, hy - 2, hx + 7, hy], fill=(170, 170, 170, 255))
    elif direction == "right":
        d.rectangle([hx - 7, hy - 2, hx + 11, hy], fill=(170, 170, 170, 255))
    elif direction == "up":
        d.rectangle([hx - 8, hy - 2, hx + 8, hy], fill=(170, 170, 170, 255))

# 3. TOPS / CLOTHING
def draw_top_jacket(d, ox, oy, direction, col, step):
    y_off = 1 if col in (1, 3) else 0
    d.rectangle([ox + 11, oy + 21 + y_off, ox + 21, oy + 32 + y_off], fill=(210, 210, 210, 255))
    d.rectangle([ox + 10, oy + 22 - step * 2, ox + 12, oy + 29 - step * 2], fill=(190, 190, 190, 255))
    d.rectangle([ox + 20, oy + 22 + step * 2, ox + 22, oy + 29 + step * 2], fill=(190, 190, 190, 255))
    if direction == "down":
        d.line([ox + 16, oy + 21 + y_off, ox + 16, oy + 32 + y_off], fill=(140, 140, 140, 255), width=1)
        d.rectangle([ox + 12, oy + 31 + y_off, ox + 20, oy + 32 + y_off], fill=(160, 160, 160, 255)) # belt

def draw_top_hoodie(d, ox, oy, direction, col, step):
    y_off = 1 if col in (1, 3) else 0
    d.rectangle([ox + 10, oy + 21 + y_off, ox + 22, oy + 33 + y_off], fill=(220, 220, 220, 255))
    d.rectangle([ox + 9, oy + 22 - step * 2, ox + 12, oy + 30 - step * 2], fill=(200, 200, 200, 255))
    d.rectangle([ox + 20, oy + 22 + step * 2, ox + 23, oy + 30 + step * 2], fill=(200, 200, 200, 255))
    if direction == "down":
        d.rectangle([ox + 13, oy + 27 + y_off, ox + 19, oy + 31 + y_off], fill=(180, 180, 180, 255)) # pocket

def draw_top_shirt(d, ox, oy, direction, col, step):
    y_off = 1 if col in (1, 3) else 0
    d.rectangle([ox + 12, oy + 21 + y_off, ox + 20, oy + 31 + y_off], fill=(230, 230, 230, 255))
    d.rectangle([ox + 10, oy + 22 - step * 2, ox + 12, oy + 26 - step * 2], fill=(210, 210, 210, 255))
    d.rectangle([ox + 20, oy + 22 + step * 2, ox + 22, oy + 26 + step * 2], fill=(210, 210, 210, 255))

# 4. BOTTOMS / PANTS
def draw_bottom_cargo(d, ox, oy, direction, col, step):
    if direction in ("down", "up"):
        d.rectangle([ox + 11, oy + 32, ox + 15, oy + 42 + (step if col in (1, 3) else 0)], fill=(190, 190, 190, 255))
        d.rectangle([ox + 17, oy + 32, ox + 21, oy + 42 - (step if col in (1, 3) else 0)], fill=(190, 190, 190, 255))
        d.rectangle([ox + 10, oy + 35, ox + 12, oy + 38], fill=(160, 160, 160, 255)) # pockets
        d.rectangle([ox + 20, oy + 35, ox + 22, oy + 38], fill=(160, 160, 160, 255))
    elif direction == "left":
        d.rectangle([ox + 13 + step * 3, oy + 32, ox + 19 + step * 3, oy + 42], fill=(190, 190, 190, 255))
    elif direction == "right":
        d.rectangle([ox + 13 - step * 3, oy + 32, ox + 19 - step * 3, oy + 42], fill=(190, 190, 190, 255))

def draw_bottom_jeans(d, ox, oy, direction, col, step):
    if direction in ("down", "up"):
        d.rectangle([ox + 12, oy + 32, ox + 15, oy + 41 + (step if col in (1, 3) else 0)], fill=(200, 200, 200, 255))
        d.rectangle([ox + 17, oy + 32, ox + 20, oy + 41 - (step if col in (1, 3) else 0)], fill=(200, 200, 200, 255))
    elif direction == "left":
        d.rectangle([ox + 14 + step * 3, oy + 32, ox + 18 + step * 3, oy + 41], fill=(200, 200, 200, 255))
    elif direction == "right":
        d.rectangle([ox + 14 - step * 3, oy + 32, ox + 18 - step * 3, oy + 41], fill=(200, 200, 200, 255))

# 5. ACCESSORIES
def draw_acc_goggles(d, ox, oy, direction, col, step):
    hx, hy = ox + 16, oy + 13 + (1 if col in (1, 3) else 0)
    if direction == "down":
        d.rectangle([hx - 7, hy - 6, hx + 7, hy - 4], fill=(140, 140, 140, 255))
        d.rectangle([hx - 6, hy - 7, hx - 2, hy - 3], fill=(240, 240, 240, 255), outline=(100, 100, 100, 255))
        d.rectangle([hx + 2, hy - 7, hx + 6, hy - 3], fill=(240, 240, 240, 255), outline=(100, 100, 100, 255))
    elif direction == "left":
        d.rectangle([hx - 8, hy - 7, hx - 3, hy - 3], fill=(240, 240, 240, 255), outline=(100, 100, 100, 255))
        d.line([hx - 3, hy - 5, hx + 6, hy - 5], fill=(140, 140, 140, 255), width=2)
    elif direction == "right":
        d.rectangle([hx + 3, hy - 7, hx + 8, hy - 3], fill=(240, 240, 240, 255), outline=(100, 100, 100, 255))
        d.line([hx - 6, hy - 5, hx + 3, hy - 5], fill=(140, 140, 140, 255), width=2)
    elif direction == "up":
        d.line([hx - 7, hy - 5, hx + 7, hy - 5], fill=(140, 140, 140, 255), width=2)

def draw_acc_scarf(d, ox, oy, direction, col, step):
    y_off = 1 if col in (1, 3) else 0
    if direction == "down":
        d.rectangle([ox + 11, oy + 19 + y_off, ox + 21, oy + 23 + y_off], fill=(220, 220, 220, 255))
        d.rectangle([ox + 17, oy + 23 + y_off, ox + 20, oy + 28 + y_off], fill=(200, 200, 200, 255))
    elif direction == "up":
        d.rectangle([ox + 11, oy + 19 + y_off, ox + 21, oy + 23 + y_off], fill=(220, 220, 220, 255))
    elif direction == "left":
        d.rectangle([ox + 12, oy + 19 + y_off, ox + 20, oy + 23 + y_off], fill=(220, 220, 220, 255))
        d.rectangle([ox + 13, oy + 23 + y_off, ox + 16, oy + 28 + y_off], fill=(200, 200, 200, 255))
    elif direction == "right":
        d.rectangle([ox + 12, oy + 19 + y_off, ox + 20, oy + 23 + y_off], fill=(220, 220, 220, 255))
        d.rectangle([ox + 16, oy + 23 + y_off, ox + 19, oy + 28 + y_off], fill=(200, 200, 200, 255))

base_dir = "frontend/assets/images/avatar"

# Generate all sheets
create_sprite_sheet(draw_body, f"{base_dir}/bodies/body_base.png")

create_sprite_sheet(draw_hair_short, f"{base_dir}/hair/hair_short.png")
create_sprite_sheet(draw_hair_long, f"{base_dir}/hair/hair_long.png")
create_sprite_sheet(draw_hair_curly, f"{base_dir}/hair/hair_curly.png")
create_sprite_sheet(draw_hair_cap, f"{base_dir}/hair/hair_cap.png")

create_sprite_sheet(draw_top_jacket, f"{base_dir}/tops/top_jacket.png")
create_sprite_sheet(draw_top_hoodie, f"{base_dir}/tops/top_hoodie.png")
create_sprite_sheet(draw_top_shirt, f"{base_dir}/tops/top_shirt.png")

create_sprite_sheet(draw_bottom_cargo, f"{base_dir}/bottoms/bottom_cargo.png")
create_sprite_sheet(draw_bottom_jeans, f"{base_dir}/bottoms/bottom_jeans.png")

create_sprite_sheet(draw_acc_goggles, f"{base_dir}/accessories/acc_goggles.png")
create_sprite_sheet(draw_acc_scarf, f"{base_dir}/accessories/acc_scarf.png")

print("All avatar spritesheets generated successfully!")
