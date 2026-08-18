"""
sprite_generator.py - Generador de sprites base 64x128 multi-direccional y animado
Adaptado para seguir con precisión quirúrgica el movimiento de extremidades,
brazos y piernas de los nuevos assets personalizados de base/body en las 4 direcciones.
"""

import os
from PIL import Image, ImageDraw

WIDTH = 64
HEIGHT = 128
ASSETS_DIR = "assets"

def create_canvas():
    return Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))

HL = (255, 255, 255, 255)
LGT = (215, 215, 215, 255)
MID = (165, 165, 165, 255)
SHD = (110, 110, 110, 255)
DEEP_SHD = (70, 70, 70, 255)
OUT = (35, 35, 35, 255)

# =============================================================
# 1. CUERPO BASE (Lectura directa si existe)
# =============================================================
def generate_body(direction="down", frame=0):
    # Si existe en disco el asset personalizado del usuario, cargarlo
    custom_path = os.path.join(ASSETS_DIR, "body", "base", f"{direction}_frame{frame}.png")
    if os.path.exists(custom_path):
        try:
            with Image.open(custom_path) as img:
                return img.convert("RGBA")
        except Exception:
            pass
            
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    d.ellipse([18, 118, 46, 125], fill=(0, 0, 0, 70))
    return img

# =============================================================
# 2. FORMAS DE LA CARA (4 DIRECCIONES)
# =============================================================
def generate_face_shape(style="oval", direction="down", frame=0, shape_type=None):
    if shape_type is not None:
        style = shape_type
    shape_type = style
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    
    if direction == "down":
        if "round" in shape_type:
            head_pts = [
                (17, 24 + bob), (22, 17 + bob), (32, 15 + bob), (42, 17 + bob), (47, 24 + bob),
                (49, 36 + bob), (47, 47 + bob), (41, 52 + bob), (32, 53 + bob), (23, 52 + bob),
                (17, 47 + bob), (15, 36 + bob)
            ]
            d.polygon(head_pts, fill=LGT, outline=OUT)
            d.rectangle([19, 24 + bob, 45, 48 + bob], fill=LGT)
            d.line([(21, 48 + bob), (32, 52 + bob), (43, 48 + bob)], fill=MID)
            d.rectangle([14, 34 + bob, 16, 42 + bob], fill=MID, outline=OUT)
            d.rectangle([48, 34 + bob, 50, 42 + bob], fill=MID, outline=OUT)
        elif "sharp" in shape_type:
            head_pts = [
                (19, 24 + bob), (24, 18 + bob), (32, 16 + bob), (40, 18 + bob), (45, 24 + bob),
                (46, 33 + bob), (43, 44 + bob), (37, 52 + bob), (32, 57 + bob), (27, 52 + bob),
                (21, 44 + bob), (18, 33 + bob)
            ]
            d.polygon(head_pts, fill=LGT, outline=OUT)
            d.rectangle([21, 24 + bob, 43, 44 + bob], fill=LGT)
            d.polygon([(22, 44 + bob), (42, 44 + bob), (32, 56 + bob)], fill=LGT)
            d.line([(23, 46 + bob), (32, 56 + bob), (41, 46 + bob)], fill=MID)
            d.rectangle([16, 32 + bob, 18, 40 + bob], fill=MID, outline=OUT)
            d.rectangle([46, 32 + bob, 48, 40 + bob], fill=MID, outline=OUT)
        elif "square" in shape_type:
            head_pts = [
                (18, 23 + bob), (23, 17 + bob), (32, 16 + bob), (41, 17 + bob), (46, 23 + bob),
                (47, 36 + bob), (46, 48 + bob), (43, 53 + bob), (32, 53 + bob), (21, 53 + bob),
                (18, 48 + bob), (17, 36 + bob)
            ]
            d.polygon(head_pts, fill=LGT, outline=OUT)
            d.rectangle([20, 24 + bob, 44, 51 + bob], fill=LGT)
            d.line([(20, 50 + bob), (44, 50 + bob)], fill=MID, width=2)
            d.rectangle([15, 34 + bob, 17, 43 + bob], fill=MID, outline=OUT)
            d.rectangle([47, 34 + bob, 49, 43 + bob], fill=MID, outline=OUT)
        elif "heart" in shape_type:
            head_pts = [
                (17, 23 + bob), (21, 16 + bob), (32, 15 + bob), (43, 16 + bob), (47, 23 + bob),
                (48, 33 + bob), (44, 44 + bob), (36, 52 + bob), (32, 54 + bob), (28, 52 + bob),
                (20, 44 + bob), (16, 33 + bob)
            ]
            d.polygon(head_pts, fill=LGT, outline=OUT)
            d.rectangle([20, 23 + bob, 44, 44 + bob], fill=LGT)
            d.polygon([(21, 44 + bob), (43, 44 + bob), (32, 53 + bob)], fill=LGT)
            d.line([(22, 45 + bob), (32, 53 + bob), (42, 45 + bob)], fill=MID)
            d.rectangle([15, 32 + bob, 17, 40 + bob], fill=MID, outline=OUT)
            d.rectangle([47, 32 + bob, 49, 40 + bob], fill=MID, outline=OUT)
        else:
            head_pts = [
                (20, 24 + bob), (24, 18 + bob), (32, 16 + bob), (40, 18 + bob), (44, 24 + bob),
                (46, 36 + bob), (44, 47 + bob), (38, 53 + bob), (32, 54 + bob), (26, 53 + bob),
                (20, 47 + bob), (18, 36 + bob)
            ]
            d.polygon(head_pts, fill=LGT, outline=OUT)
            d.rectangle([21, 26 + bob, 43, 48 + bob], fill=LGT)
            d.line([(23, 46 + bob), (32, 53 + bob), (41, 46 + bob)], fill=MID)
            d.rectangle([16, 35 + bob, 18, 42 + bob], fill=MID, outline=OUT)
            d.rectangle([46, 35 + bob, 48, 42 + bob], fill=MID, outline=OUT)
            
        d.rectangle([29, 52 + bob, 35, 55 + bob], fill=SHD)
        
    elif direction == "up":
        if "round" in shape_type:
            head_pts = [(17, 24 + bob), (22, 17 + bob), (32, 15 + bob), (42, 17 + bob), (47, 24 + bob), (49, 36 + bob), (47, 48 + bob), (32, 54 + bob), (17, 48 + bob), (15, 36 + bob)]
        elif "sharp" in shape_type:
            head_pts = [(19, 24 + bob), (24, 18 + bob), (32, 16 + bob), (40, 18 + bob), (45, 24 + bob), (46, 34 + bob), (42, 46 + bob), (32, 57 + bob), (22, 46 + bob), (18, 34 + bob)]
        elif "square" in shape_type:
            head_pts = [(18, 23 + bob), (23, 17 + bob), (32, 16 + bob), (41, 17 + bob), (46, 23 + bob), (47, 36 + bob), (46, 49 + bob), (32, 53 + bob), (18, 49 + bob), (17, 36 + bob)]
        else:
            head_pts = [(20, 24 + bob), (24, 18 + bob), (32, 16 + bob), (40, 18 + bob), (44, 24 + bob), (46, 36 + bob), (44, 48 + bob), (38, 54 + bob), (32, 55 + bob), (26, 54 + bob), (20, 48 + bob), (18, 36 + bob)]
        d.polygon(head_pts, fill=LGT, outline=OUT)
        d.rectangle([22, 28 + bob, 42, 50 + bob], fill=LGT)
        d.rectangle([16, 35 + bob, 18, 42 + bob], fill=MID, outline=OUT)
        d.rectangle([46, 35 + bob, 48, 42 + bob], fill=MID, outline=OUT)
        
    elif direction in ("left", "right"):
        if "round" in shape_type:
            pts = [(23, 24 + bob), (27, 17 + bob), (36, 15 + bob), (45, 18 + bob), (48, 34 + bob), (46, 47 + bob), (38, 52 + bob), (28, 52 + bob), (22, 46 + bob), (18, 40 + bob), (20, 32 + bob)]
        elif "sharp" in shape_type:
            pts = [(24, 24 + bob), (28, 18 + bob), (36, 16 + bob), (44, 20 + bob), (46, 34 + bob), (43, 46 + bob), (36, 56 + bob), (28, 53 + bob), (22, 46 + bob), (19, 41 + bob), (21, 32 + bob)]
        elif "square" in shape_type:
            pts = [(23, 23 + bob), (27, 17 + bob), (36, 16 + bob), (45, 19 + bob), (47, 35 + bob), (46, 49 + bob), (40, 53 + bob), (28, 53 + bob), (22, 48 + bob), (19, 41 + bob), (21, 32 + bob)]
        else:
            pts = [(24, 24 + bob), (28, 18 + bob), (36, 16 + bob), (44, 20 + bob), (46, 34 + bob), (44, 46 + bob), (38, 53 + bob), (30, 54 + bob), (24, 48 + bob), (20, 42 + bob), (22, 32 + bob)]
            
        d.polygon(pts, fill=LGT, outline=OUT)
        d.rectangle([26, 26 + bob, 42, 48 + bob], fill=LGT)
        d.rectangle([34, 35 + bob, 38, 43 + bob], fill=MID, outline=OUT)
        d.point([(36, 39 + bob)], fill=SHD)
        
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
            
    return img

# =============================================================
# 3. RASGOS FACIALES
# =============================================================
def generate_eyes(style="jrpg_classic", direction="down", frame=0):
    if direction == "up":
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    
    if direction == "down":
        if "shoujo" in style or "sparkle" in style:
            for (lx, rx) in [(20, 29), (35, 44)]:
                d.rectangle([lx, 29 + bob, rx, 31 + bob], fill=(30, 30, 30, 255))
                d.point([(lx - 1, 31 + bob), (rx + 1, 31 + bob)], fill=(50, 50, 50, 255))
                d.rectangle([lx + 1, 31 + bob, rx - 1, 39 + bob], fill=(255, 255, 255, 255))
                d.rectangle([lx + 2, 31 + bob, rx - 2, 39 + bob], fill=(220, 0, 0, 255))
                d.line([(lx + 2, 31 + bob), (rx - 2, 31 + bob)], fill=(120, 0, 0, 255))
                d.point([(lx + 3, 33 + bob), (lx + 2, 34 + bob)], fill=(255, 255, 255, 255))
                d.point([(rx - 3, 37 + bob)], fill=(255, 255, 255, 255))
                d.line([(lx + 1, 40 + bob), (rx - 1, 40 + bob)], fill=(40, 40, 40, 255))
        elif "sleepy" in style or "calm" in style:
            for (lx, rx) in [(21, 29), (35, 43)]:
                d.line([(lx, 34 + bob), (rx, 34 + bob)], fill=(30, 30, 30, 255), width=2)
                d.rectangle([lx + 1, 35 + bob, rx - 1, 38 + bob], fill=(255, 255, 255, 255))
                d.rectangle([lx + 2, 35 + bob, rx - 2, 38 + bob], fill=(220, 0, 0, 255))
                d.point([(lx + 3, 36 + bob)], fill=(255, 255, 255, 255))
                d.line([(lx + 1, 39 + bob), (rx - 1, 39 + bob)], fill=(50, 50, 50, 255))
        elif "happy" in style or "closed" in style:
            d.arc([21, 31 + bob, 29, 39 + bob], 190, 350, fill=(30, 30, 30, 255), width=2)
            d.arc([35, 31 + bob, 43, 39 + bob], 190, 350, fill=(30, 30, 30, 255), width=2)
        elif "mystic" in style or "glow" in style:
            for (lx, rx) in [(21, 29), (35, 43)]:
                d.rectangle([lx, 30 + bob, rx, 31 + bob], fill=(40, 40, 60, 255))
                d.rectangle([lx + 1, 32 + bob, rx - 1, 38 + bob], fill=(255, 255, 255, 255))
                d.rectangle([lx + 2, 32 + bob, rx - 2, 38 + bob], fill=(220, 0, 0, 255))
                d.rectangle([lx + 3, 34 + bob, rx - 3, 36 + bob], fill=(255, 255, 255, 255))
                d.line([(lx + 1, 39 + bob), (rx - 1, 39 + bob)], fill=(40, 40, 60, 255))
        elif "cateye" in style or "sly" in style:
            d.line([(21, 34 + bob), (28, 30 + bob), (30, 31 + bob)], fill=(30, 30, 30, 255), width=2)
            d.rectangle([23, 32 + bob, 29, 36 + bob], fill=(255, 255, 255, 255))
            d.rectangle([25, 32 + bob, 28, 36 + bob], fill=(220, 0, 0, 255))
            d.point([(25, 33 + bob)], fill=(255, 255, 255, 255))
            d.line([(22, 37 + bob), (28, 37 + bob)], fill=(40, 40, 40, 255))
            d.line([(34, 31 + bob), (36, 30 + bob), (43, 34 + bob)], fill=(30, 30, 30, 255), width=2)
            d.rectangle([35, 32 + bob, 41, 36 + bob], fill=(255, 255, 255, 255))
            d.rectangle([36, 32 + bob, 39, 36 + bob], fill=(220, 0, 0, 255))
            d.point([(36, 33 + bob)], fill=(255, 255, 255, 255))
            d.line([(36, 37 + bob), (42, 37 + bob)], fill=(40, 40, 40, 255))
        elif "dot" in style:
            d.rectangle([24, 32 + bob, 28, 37 + bob], fill=(220, 0, 0, 255), outline=(30, 30, 30, 255))
            d.point([(25, 33 + bob)], fill=(255, 255, 255, 255))
            d.rectangle([36, 32 + bob, 40, 37 + bob], fill=(220, 0, 0, 255), outline=(30, 30, 30, 255))
            d.point([(37, 33 + bob)], fill=(255, 255, 255, 255))
        elif "cute" in style or "stardew" in style:
            for (lx, rx) in [(21, 29), (35, 43)]:
                d.rectangle([lx, 30 + bob, rx, 31 + bob], fill=(30, 30, 30, 255))
                d.rectangle([lx + 1, 32 + bob, rx - 1, 39 + bob], fill=(255, 255, 255, 255))
                d.rectangle([lx + 2, 32 + bob, rx - 2, 39 + bob], fill=(220, 0, 0, 255))
                d.line([(lx + 2, 32 + bob), (rx - 2, 32 + bob)], fill=(120, 0, 0, 255))
                d.point([(lx + 3, 35 + bob)], fill=(20, 20, 20, 255))
                d.point([(lx + 2, 33 + bob), (rx - 2, 37 + bob)], fill=(255, 255, 255, 255))
                d.line([(lx + 1, 40 + bob), (rx - 1, 40 + bob)], fill=(50, 50, 50, 255))
        elif "serious" in style or "adventurer" in style:
            d.line([(21, 33 + bob), (29, 31 + bob)], fill=(30, 30, 30, 255), width=2)
            d.rectangle([22, 33 + bob, 29, 37 + bob], fill=(255, 255, 255, 255))
            d.rectangle([24, 33 + bob, 28, 37 + bob], fill=(220, 0, 0, 255))
            d.point([(26, 35 + bob)], fill=(20, 20, 20, 255))
            d.point([(24, 33 + bob)], fill=(255, 255, 255, 255))
            d.line([(22, 38 + bob), (29, 38 + bob)], fill=(40, 40, 40, 255))
            d.line([(35, 31 + bob), (43, 33 + bob)], fill=(30, 30, 30, 255), width=2)
            d.rectangle([35, 33 + bob, 42, 37 + bob], fill=(255, 255, 255, 255))
            d.rectangle([36, 33 + bob, 40, 37 + bob], fill=(220, 0, 0, 255))
            d.point([(38, 35 + bob)], fill=(20, 20, 20, 255))
            d.point([(36, 33 + bob)], fill=(255, 255, 255, 255))
            d.line([(35, 38 + bob), (42, 38 + bob)], fill=(40, 40, 40, 255))
        elif "wink" in style:
            d.rectangle([22, 31 + bob, 29, 32 + bob], fill=(30, 30, 30, 255))
            d.rectangle([23, 33 + bob, 29, 38 + bob], fill=(255, 255, 255, 255))
            d.rectangle([24, 33 + bob, 28, 38 + bob], fill=(220, 0, 0, 255))
            d.point([(26, 35 + bob)], fill=(25, 25, 25, 255))
            d.point([(24, 33 + bob)], fill=(255, 255, 255, 255))
            d.line([(35, 37 + bob), (39, 32 + bob), (43, 37 + bob)], fill=(30, 30, 30, 255), width=2)
        else:
            d.rectangle([22, 31 + bob, 29, 32 + bob], fill=(30, 30, 30, 255))
            d.point([(21, 32 + bob), (30, 32 + bob)], fill=(60, 60, 60, 255))
            d.rectangle([23, 33 + bob, 29, 38 + bob], fill=(255, 255, 255, 255))
            d.rectangle([24, 33 + bob, 28, 38 + bob], fill=(220, 0, 0, 255))
            d.line([(24, 33 + bob), (28, 33 + bob)], fill=(130, 0, 0, 255))
            d.point([(26, 35 + bob)], fill=(25, 25, 25, 255))
            d.point([(24, 33 + bob)], fill=(255, 255, 255, 255))
            d.line([(23, 39 + bob), (28, 39 + bob)], fill=(45, 45, 45, 255))
            d.rectangle([35, 31 + bob, 42, 32 + bob], fill=(30, 30, 30, 255))
            d.point([(34, 32 + bob), (43, 32 + bob)], fill=(60, 60, 60, 255))
            d.rectangle([35, 33 + bob, 41, 38 + bob], fill=(255, 255, 255, 255))
            d.rectangle([36, 33 + bob, 40, 38 + bob], fill=(220, 0, 0, 255))
            d.line([(36, 33 + bob), (40, 33 + bob)], fill=(130, 0, 0, 255))
            d.point([(38, 35 + bob)], fill=(25, 25, 25, 255))
            d.point([(36, 33 + bob)], fill=(255, 255, 255, 255))
            d.line([(36, 39 + bob), (41, 39 + bob)], fill=(45, 45, 45, 255))
            
    elif direction in ("left", "right"):
        if "happy" in style or "closed" in style:
            d.arc([22, 31 + bob, 28, 39 + bob], 190, 350, fill=(30, 30, 30, 255), width=2)
        elif "dot" in style:
            d.rectangle([23, 32 + bob, 27, 37 + bob], fill=(220, 0, 0, 255), outline=(30, 30, 30, 255))
            d.point([(24, 33 + bob)], fill=(255, 255, 255, 255))
        else:
            d.rectangle([22, 31 + bob, 28, 32 + bob], fill=(30, 30, 30, 255))
            d.rectangle([23, 33 + bob, 28, 38 + bob], fill=(255, 255, 255, 255))
            d.rectangle([23, 33 + bob, 26, 38 + bob], fill=(220, 0, 0, 255))
            d.point([(24, 35 + bob)], fill=(25, 25, 25, 255))
            d.point([(23, 33 + bob)], fill=(255, 255, 255, 255))
            d.line([(22, 39 + bob), (27, 39 + bob)], fill=(45, 45, 45, 255))
            
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
            
    return img

def generate_eyebrows(style="normal", direction="down", frame=0):
    if direction == "up":
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    if direction == "down":
        if "thick" in style:
            d.line([(21, 28 + bob), (29, 26 + bob)], fill=(200, 200, 200, 255), width=2)
            d.line([(35, 26 + bob), (43, 28 + bob)], fill=(200, 200, 200, 255), width=2)
        elif "serious" in style:
            d.line([(22, 26 + bob), (29, 29 + bob)], fill=(190, 190, 190, 255), width=2)
            d.line([(35, 29 + bob), (42, 26 + bob)], fill=(190, 190, 190, 255), width=2)
        elif "arched" in style:
            d.line([(22, 28 + bob), (26, 26 + bob), (29, 28 + bob)], fill=(180, 180, 180, 255), width=1)
            d.line([(35, 28 + bob), (38, 26 + bob), (42, 28 + bob)], fill=(180, 180, 180, 255), width=1)
        else:
            d.line([(22, 28 + bob), (29, 27 + bob)], fill=(180, 180, 180, 255), width=1)
            d.line([(35, 27 + bob), (42, 28 + bob)], fill=(180, 180, 180, 255), width=1)
    elif direction in ("left", "right"):
        d.line([(22, 28 + bob), (28, 27 + bob)], fill=(180, 180, 180, 255), width=2)
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img

def generate_nose(style="subtle", direction="down", frame=0):
    if direction == "up":
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    if direction == "down":
        d.point([(32, 42 + bob)], fill=(130, 130, 130, 255))
        d.point([(33, 42 + bob)], fill=(90, 90, 90, 255))
    elif direction in ("left", "right"):
        d.line([(20, 42 + bob), (22, 43 + bob)], fill=(110, 110, 110, 255))
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img

def generate_mouth(style="smile", direction="down", frame=0):
    if direction == "up":
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    if direction == "down":
        if "neutral" in style:
            d.line([(30, 47 + bob), (34, 47 + bob)], fill=(90, 90, 90, 255), width=1)
        elif "open" in style:
            d.polygon([(29, 46 + bob), (35, 46 + bob), (34, 49 + bob), (30, 49 + bob)], fill=(70, 70, 70, 255), outline=(40, 40, 40, 255))
            d.line([(30, 46 + bob), (34, 46 + bob)], fill=(240, 240, 240, 255))
        elif "smirk" in style:
            d.line([(29, 47 + bob), (33, 47 + bob), (36, 45 + bob)], fill=(80, 80, 80, 255), width=1)
        elif "lipstick" in style:
            d.polygon([(29, 46 + bob), (32, 45 + bob), (35, 46 + bob), (32, 49 + bob)], fill=(220, 0, 0, 255), outline=(130, 0, 0, 255))
        else:
            d.line([(29, 46 + bob), (32, 48 + bob), (35, 46 + bob)], fill=(100, 100, 100, 255), width=1)
            d.point([(32, 49 + bob)], fill=(130, 130, 130, 255))
    elif direction in ("left", "right"):
        d.line([(21, 47 + bob), (25, 47 + bob)], fill=(100, 100, 100, 255), width=1)
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img

def generate_face_detail(style="blush", direction="down", frame=0):
    if direction == "up" or "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    if direction == "down":
        if "blush" in style:
            d.rectangle([20, 40 + bob, 25, 43 + bob], fill=(230, 110, 110, 170))
            d.rectangle([39, 40 + bob, 44, 43 + bob], fill=(230, 110, 110, 170))
            d.line([(20, 41 + bob), (25, 41 + bob)], fill=(255, 140, 140, 220))
            d.line([(39, 41 + bob), (44, 41 + bob)], fill=(255, 140, 140, 220))
        elif "freckles" in style:
            pts = [(22, 40 + bob), (25, 41 + bob), (28, 40 + bob), (36, 40 + bob), (39, 41 + bob), (42, 40 + bob)]
            for pt in pts:
                d.point(pt, fill=(110, 80, 60, 220))
        elif "scar" in style:
            d.line([(27, 28 + bob), (24, 42 + bob)], fill=(180, 100, 100, 220), width=1)
    elif direction in ("left", "right"):
        if "blush" in style:
            d.rectangle([22, 40 + bob, 27, 43 + bob], fill=(230, 110, 110, 170))
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img

# =============================================================
# 4. PEINADOS (4 DIRECCIONES COMPLETAS)
# =============================================================
def generate_hair(style="farm_braids", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    
    if direction == "down":
        dome_pts = [(18, 23 + bob), (22, 16 + bob), (28, 11 + bob), (36, 11 + bob), (42, 16 + bob), (46, 23 + bob), (44, 21 + bob), (32, 17 + bob), (20, 21 + bob)]
        d.polygon(dome_pts, fill=LGT, outline=OUT)
        d.line([(26, 14 + bob), (38, 14 + bob)], fill=HL, width=1)
        
        if "spiky" in style:
            d.polygon([(17, 26 + bob), (14, 17 + bob), (20, 10 + bob), (27, 6 + bob), (37, 6 + bob), (44, 10 + bob), (50, 17 + bob), (47, 26 + bob), (44, 21 + bob), (39, 26 + bob), (34, 19 + bob), (30, 26 + bob), (25, 19 + bob), (20, 24 + bob)], fill=LGT, outline=OUT)
            d.polygon([(20, 20 + bob), (26, 28 + bob), (28, 20 + bob)], fill=MID, outline=OUT)
            d.polygon([(29, 20 + bob), (33, 29 + bob), (37, 20 + bob)], fill=LGT, outline=OUT)
            d.polygon([(38, 20 + bob), (44, 28 + bob), (46, 20 + bob)], fill=MID, outline=OUT)
        elif "bob" in style:
            d.rectangle([20, 20 + bob, 44, 27 + bob], fill=LGT, outline=OUT)
            d.line([(20, 27 + bob), (44, 27 + bob)], fill=SHD)
            d.polygon([(16, 23 + bob), (21, 23 + bob), (22, 46 + bob), (17, 46 + bob)], fill=LGT, outline=OUT)
            d.polygon([(43, 23 + bob), (48, 23 + bob), (47, 46 + bob), (42, 46 + bob)], fill=LGT, outline=OUT)
        elif "curly" in style:
            d.ellipse([16, 22 + bob, 22, 28 + bob], fill=MID, outline=OUT)
            d.ellipse([42, 22 + bob, 48, 28 + bob], fill=MID, outline=OUT)
            d.polygon([(19, 20 + bob), (28, 27 + bob), (32, 21 + bob), (36, 27 + bob), (45, 20 + bob)], fill=LGT, outline=OUT)
        else:
            d.polygon([(19, 20 + bob), (27, 27 + bob), (29, 20 + bob)], fill=LGT, outline=OUT)
            d.polygon([(35, 20 + bob), (37, 27 + bob), (45, 20 + bob)], fill=LGT, outline=OUT)
            d.polygon([(17, 23 + bob), (21, 23 + bob), (20, 42 + bob), (16, 42 + bob)], fill=LGT, outline=OUT)
            d.polygon([(43, 23 + bob), (47, 23 + bob), (48, 42 + bob), (44, 42 + bob)], fill=LGT, outline=OUT)
            
            if "braids" in style or "flowing" in style or "twintails" in style:
                d.polygon([(15, 42 + bob), (20, 42 + bob), (18, 74 + bob), (14, 74 + bob)], fill=MID, outline=OUT)
                d.polygon([(44, 42 + bob), (49, 42 + bob), (50, 74 + bob), (46, 74 + bob)], fill=MID, outline=OUT)
                
    elif direction == "up":
        dome_pts = [(18, 24 + bob), (22, 15 + bob), (28, 10 + bob), (36, 10 + bob), (42, 15 + bob), (46, 24 + bob), (47, 44 + bob), (42, 52 + bob), (32, 54 + bob), (22, 52 + bob), (17, 44 + bob)]
        d.polygon(dome_pts, fill=LGT, outline=OUT)
        d.line([(25, 14 + bob), (39, 14 + bob)], fill=HL)
        
        if "braids" in style:
            d.polygon([(16, 38 + bob), (24, 38 + bob), (21, 78 + bob), (14, 78 + bob)], fill=MID, outline=OUT)
            d.polygon([(40, 38 + bob), (48, 38 + bob), (50, 78 + bob), (43, 78 + bob)], fill=MID, outline=OUT)
            d.rectangle([14, 72 + bob, 21, 74 + bob], fill=(220, 50, 50, 255), outline=OUT)
            d.rectangle([43, 72 + bob, 50, 74 + bob], fill=(220, 50, 50, 255), outline=OUT)
        elif "flowing" in style:
            d.polygon([(18, 40 + bob), (46, 40 + bob), (48, 82 + bob), (16, 82 + bob)], fill=MID, outline=OUT)
            d.line([(26, 44 + bob), (26, 80 + bob)], fill=HL)
            d.line([(38, 44 + bob), (38, 80 + bob)], fill=HL)
        elif "twintails" in style:
            d.polygon([(12, 32 + bob), (20, 32 + bob), (18, 76 + bob), (10, 76 + bob)], fill=MID, outline=OUT)
            d.polygon([(44, 32 + bob), (52, 32 + bob), (54, 76 + bob), (46, 76 + bob)], fill=MID, outline=OUT)
        elif "ponytail" in style:
            d.rectangle([30, 24 + bob, 34, 27 + bob], fill=(220, 50, 50, 255), outline=OUT)
            d.polygon([(29, 27 + bob), (35, 27 + bob), (37, 72 + bob), (27, 72 + bob)], fill=MID, outline=OUT)
        elif "spiky" in style:
            d.polygon([(16, 32 + bob), (11, 26 + bob), (18, 20 + bob)], fill=LGT, outline=OUT)
            d.polygon([(48, 32 + bob), (53, 26 + bob), (46, 20 + bob)], fill=LGT, outline=OUT)
        elif "bob" in style:
            d.rectangle([18, 36 + bob, 46, 48 + bob], fill=MID, outline=OUT)
            
    elif direction in ("left", "right"):
        dome_pts = [(22, 24 + bob), (26, 15 + bob), (34, 10 + bob), (42, 12 + bob), (47, 20 + bob), (48, 44 + bob), (44, 52 + bob), (34, 54 + bob), (26, 46 + bob), (20, 34 + bob)]
        d.polygon(dome_pts, fill=LGT, outline=OUT)
        d.polygon([(20, 26 + bob), (26, 34 + bob), (27, 26 + bob)], fill=LGT, outline=OUT)
        
        if "braids" in style or "flowing" in style or "twintails" in style:
            d.polygon([(38, 38 + bob), (48, 36 + bob), (47, 78 + bob), (38, 76 + bob)], fill=MID, outline=OUT)
        elif "ponytail" in style:
            d.rectangle([44, 26 + bob, 48, 29 + bob], fill=(220, 50, 50, 255), outline=OUT)
            d.polygon([(46, 29 + bob), (54, 38 + bob), (51, 68 + bob), (44, 62 + bob)], fill=MID, outline=OUT)
        elif "spiky" in style:
            d.polygon([(46, 22 + bob), (54, 18 + bob), (48, 30 + bob)], fill=LGT, outline=OUT)
            
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
            
    return img

# =============================================================
# 5. ROPA SUPERIOR (TOPS) - AJUSTE PRECISO A LAS EXTREMIDADES
# =============================================================
def generate_tops(style="flannel_shirt", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    
    if direction == "down":
        l_arm_off = 1 if frame == 1 else (-1 if frame == 3 else 0)
        r_arm_off = 1 if frame == 1 else (-1 if frame == 3 else 0)
        
        if "bikini" in style:
            d.polygon([(24, 58 + bob), (30, 61 + bob), (26, 67 + bob), (23, 63 + bob)], fill=LGT, outline=OUT)
            d.polygon([(40, 58 + bob), (34, 61 + bob), (38, 67 + bob), (41, 63 + bob)], fill=LGT, outline=OUT)
            d.line([(26, 56 + bob), (26, 58 + bob)], fill=OUT)
            d.line([(38, 56 + bob), (38, 58 + bob)], fill=OUT)
            d.line([(30, 63 + bob), (34, 63 + bob)], fill=OUT)
        elif "crop" in style:
            d.polygon([(23, 56 + bob), (41, 56 + bob), (40, 68 + bob), (24, 68 + bob)], fill=LGT, outline=OUT)
            d.arc([27, 54 + bob, 37, 58 + bob], 0, 180, fill=OUT, width=1)
            d.line([(24, 68 + bob), (40, 68 + bob)], fill=SHD, width=2)
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (22 + l_arm_off, 65 + bob), (17 + l_arm_off, 65 + bob)], fill=LGT, outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (47 + r_arm_off, 65 + bob), (42 + r_arm_off, 65 + bob)], fill=LGT, outline=OUT)
        elif "hoodie" in style:
            d.polygon([(22, 54 + bob), (42, 54 + bob), (44, 62 + bob), (20, 62 + bob)], fill=MID, outline=OUT)
            d.polygon([(20, 60 + bob), (44, 60 + bob), (41, 78 + bob), (23, 78 + bob)], fill=LGT, outline=OUT)
            d.polygon([(17 + l_arm_off, 57 + bob), (22, 56 + bob), (21 + l_arm_off, 74 + bob), (16 + l_arm_off, 74 + bob)], fill=LGT, outline=OUT)
            d.polygon([(42, 56 + bob), (47 + r_arm_off, 57 + bob), (48 + r_arm_off, 74 + bob), (43 + r_arm_off, 74 + bob)], fill=LGT, outline=OUT)
            d.polygon([(25, 69 + bob), (39, 69 + bob), (40, 77 + bob), (24, 77 + bob)], fill=MID, outline=OUT)
            d.line([(28, 57 + bob), (28, 64 + bob)], fill=HL)
            d.line([(36, 57 + bob), (36, 64 + bob)], fill=HL)
        elif "tshirt" in style:
            d.polygon([(23, 56 + bob), (41, 56 + bob), (40, 76 + bob), (24, 76 + bob)], fill=LGT, outline=OUT)
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (21 + l_arm_off, 66 + bob), (16 + l_arm_off, 65 + bob)], fill=LGT, outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (48 + r_arm_off, 65 + bob), (43 + r_arm_off, 66 + bob)], fill=LGT, outline=OUT)
            d.arc([27, 54 + bob, 37, 59 + bob], 0, 180, fill=OUT, width=2)
            d.line([(24, 69 + bob), (40, 69 + bob)], fill=SHD)
        elif "coat" in style:
            d.polygon([(22, 54 + bob), (42, 54 + bob), (44, 64 + bob), (20, 64 + bob)], fill=(245, 245, 240, 255), outline=OUT)
            d.line([(22, 64 + bob), (42, 64 + bob)], fill=(180, 180, 180, 255))
            d.polygon([(21, 62 + bob), (43, 62 + bob), (44, 96 + bob), (20, 96 + bob)], fill=LGT, outline=OUT)
            d.polygon([(17 + l_arm_off, 57 + bob), (22, 56 + bob), (21 + l_arm_off, 74 + bob), (16 + l_arm_off, 74 + bob)], fill=LGT, outline=OUT)
            d.polygon([(42, 56 + bob), (47 + r_arm_off, 57 + bob), (48 + r_arm_off, 74 + bob), (43 + r_arm_off, 74 + bob)], fill=LGT, outline=OUT)
            for by in [68, 77, 86]:
                d.point([(29, by + bob), (35, by + bob)], fill=(240, 210, 60, 255))
            d.line([(32, 64 + bob), (32, 96 + bob)], fill=SHD)
        elif "tunic" in style:
            d.polygon([(23, 56 + bob), (41, 56 + bob), (43, 82 + bob), (21, 82 + bob)], fill=LGT, outline=OUT)
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (21 + l_arm_off, 72 + bob), (16 + l_arm_off, 71 + bob)], fill=LGT, outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (48 + r_arm_off, 71 + bob), (43 + r_arm_off, 72 + bob)], fill=LGT, outline=OUT)
            d.polygon([(27, 56 + bob), (32, 64 + bob), (37, 56 + bob)], fill=(120, 120, 120, 255), outline=OUT)
            d.rectangle([(22, 72 + bob), (42, 76 + bob)], fill=(90, 60, 40, 255), outline=OUT)
            d.rectangle([(30, 71 + bob), (34, 77 + bob)], fill=(240, 210, 60, 255), outline=OUT)
        elif "bib" in style or "overalls" in style:
            d.polygon([(23, 56 + bob), (41, 56 + bob), (40, 76 + bob), (24, 76 + bob)], fill=(220, 220, 220, 255))
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (21 + l_arm_off, 66 + bob), (16 + l_arm_off, 65 + bob)], fill=(220, 220, 220, 255), outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (48 + r_arm_off, 65 + bob), (43 + r_arm_off, 66 + bob)], fill=(220, 220, 220, 255), outline=OUT)
            d.rectangle([(25, 56 + bob), (28, 66 + bob)], fill=LGT, outline=OUT)
            d.rectangle([(36, 56 + bob), (39, 66 + bob)], fill=LGT, outline=OUT)
            d.point([(26, 66 + bob), (27, 66 + bob), (37, 66 + bob), (38, 66 + bob)], fill=(220, 180, 50, 255))
            d.polygon([(24, 66 + bob), (40, 66 + bob), (40, 76 + bob), (24, 76 + bob)], fill=LGT, outline=OUT)
            d.rectangle([(28, 68 + bob), (36, 74 + bob)], fill=MID, outline=OUT)
        else: # flannel shirt
            d.polygon([(23, 56 + bob), (41, 56 + bob), (40, 76 + bob), (24, 76 + bob)], fill=LGT, outline=OUT)
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (21 + l_arm_off, 73 + bob), (16 + l_arm_off, 72 + bob)], fill=LGT, outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (48 + r_arm_off, 72 + bob), (43 + r_arm_off, 73 + bob)], fill=LGT, outline=OUT)
            d.polygon([(27, 55 + bob), (32, 61 + bob), (29, 62 + bob)], fill=HL, outline=OUT)
            d.polygon([(37, 55 + bob), (32, 61 + bob), (35, 62 + bob)], fill=HL, outline=OUT)
            d.line([(24, 64 + bob), (40, 64 + bob)], fill=SHD)
            d.line([(24, 70 + bob), (40, 70 + bob)], fill=SHD)
            d.line([(27, 58 + bob), (27, 76 + bob)], fill=SHD)
            d.line([(37, 58 + bob), (37, 76 + bob)], fill=SHD)
            for by in [61, 67, 73]:
                d.point([(32, by + bob)], fill=OUT)
                
    elif direction == "up":
        l_arm_off = 1 if frame == 1 else (-1 if frame == 3 else 0)
        r_arm_off = 1 if frame == 1 else (-1 if frame == 3 else 0)
        
        if "bikini" in style:
            d.line([(24, 63 + bob), (40, 63 + bob)], fill=OUT, width=2)
            d.point([(32, 63 + bob)], fill=HL)
        elif "crop" in style:
            d.polygon([(24, 56 + bob), (40, 56 + bob), (39, 68 + bob), (25, 68 + bob)], fill=LGT, outline=OUT)
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (21 + l_arm_off, 64 + bob), (16 + l_arm_off, 64 + bob)], fill=LGT, outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (48 + r_arm_off, 64 + bob), (43 + r_arm_off, 64 + bob)], fill=LGT, outline=OUT)
        elif "coat" in style:
            d.polygon([(21, 54 + bob), (43, 54 + bob), (44, 96 + bob), (20, 96 + bob)], fill=LGT, outline=OUT)
            d.polygon([(17 + l_arm_off, 57 + bob), (22, 56 + bob), (21 + l_arm_off, 74 + bob), (16 + l_arm_off, 74 + bob)], fill=LGT, outline=OUT)
            d.polygon([(42, 56 + bob), (47 + r_arm_off, 57 + bob), (48 + r_arm_off, 74 + bob), (43 + r_arm_off, 74 + bob)], fill=LGT, outline=OUT)
            d.line([(32, 78 + bob), (32, 96 + bob)], fill=OUT, width=2)
        elif "hoodie" in style:
            d.polygon([(20, 60 + bob), (44, 60 + bob), (41, 78 + bob), (23, 78 + bob)], fill=LGT, outline=OUT)
            d.polygon([(23, 54 + bob), (41, 54 + bob), (43, 66 + bob), (21, 66 + bob)], fill=MID, outline=OUT)
            d.polygon([(17 + l_arm_off, 57 + bob), (22, 56 + bob), (21 + l_arm_off, 74 + bob), (16 + l_arm_off, 74 + bob)], fill=LGT, outline=OUT)
            d.polygon([(42, 56 + bob), (47 + r_arm_off, 57 + bob), (48 + r_arm_off, 74 + bob), (43 + r_arm_off, 74 + bob)], fill=LGT, outline=OUT)
        elif "tunic" in style:
            d.polygon([(23, 56 + bob), (41, 56 + bob), (43, 82 + bob), (21, 82 + bob)], fill=LGT, outline=OUT)
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (21 + l_arm_off, 72 + bob), (16 + l_arm_off, 71 + bob)], fill=LGT, outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (48 + r_arm_off, 71 + bob), (43 + r_arm_off, 72 + bob)], fill=LGT, outline=OUT)
            d.rectangle([(22, 72 + bob), (42, 76 + bob)], fill=(90, 60, 40, 255), outline=OUT)
            d.line([(32, 76 + bob), (32, 82 + bob)], fill=OUT)
        elif "bib" in style or "overalls" in style:
            d.polygon([(23, 56 + bob), (41, 56 + bob), (40, 76 + bob), (24, 76 + bob)], fill=(220, 220, 220, 255))
            d.line([(25, 56 + bob), (37, 76 + bob)], fill=LGT, width=3)
            d.line([(39, 56 + bob), (27, 76 + bob)], fill=LGT, width=3)
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (21 + l_arm_off, 66 + bob), (16 + l_arm_off, 65 + bob)], fill=(220, 220, 220, 255), outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (48 + r_arm_off, 65 + bob), (43 + r_arm_off, 66 + bob)], fill=(220, 220, 220, 255), outline=OUT)
        else: # flannel & tshirt
            d.polygon([(23, 56 + bob), (41, 56 + bob), (40, 76 + bob), (24, 76 + bob)], fill=LGT, outline=OUT)
            d.polygon([(18 + l_arm_off, 57 + bob), (23, 56 + bob), (21 + l_arm_off, 73 + bob), (16 + l_arm_off, 72 + bob)], fill=LGT, outline=OUT)
            d.polygon([(41, 56 + bob), (46 + r_arm_off, 57 + bob), (48 + r_arm_off, 72 + bob), (43 + r_arm_off, 73 + bob)], fill=LGT, outline=OUT)
            d.line([(32, 56 + bob), (32, 76 + bob)], fill=SHD)
            d.line([(24, 62 + bob), (40, 62 + bob)], fill=SHD)
            
    elif direction in ("left", "right"):
        # Cinemática de brazos en perfil (F1: atrás x: 19..28, F3: adelante x: 32..39)
        if frame == 1:
            arm_pts = [(28, 56 + bob), (34, 56 + bob), (28, 72 + bob), (22, 72 + bob)]
            arm_fore = [(22, 72 + bob), (28, 72 + bob), (24, 79 + bob), (19, 79 + bob)]
        elif frame == 3:
            arm_pts = [(28, 56 + bob), (34, 56 + bob), (38, 72 + bob), (32, 72 + bob)]
            arm_fore = [(32, 72 + bob), (38, 72 + bob), (38, 79 + bob), (33, 79 + bob)]
        else: # F0, F2
            arm_pts = [(28, 56 + bob), (34, 56 + bob), (34, 72 + bob), (28, 72 + bob)]
            arm_fore = [(28, 72 + bob), (34, 72 + bob), (33, 79 + bob), (28, 79 + bob)]
            
        if "bikini" in style:
            d.polygon([(27, 60 + bob), (33, 61 + bob), (30, 66 + bob)], fill=LGT, outline=OUT)
        elif "crop" in style:
            d.polygon([(26, 56 + bob), (38, 56 + bob), (37, 68 + bob), (26, 68 + bob)], fill=LGT, outline=OUT)
            d.polygon([(arm_pts[0][0], arm_pts[0][1]), (arm_pts[1][0], arm_pts[1][1]), (arm_pts[2][0]-1, arm_pts[2][1]-7), (arm_pts[3][0]-1, arm_pts[3][1]-7)], fill=LGT, outline=OUT)
        elif "coat" in style:
            d.polygon([(25, 56 + bob), (39, 56 + bob), (40, 96 + bob), (24, 96 + bob)], fill=LGT, outline=OUT)
            d.polygon(arm_pts, fill=LGT, outline=OUT)
            d.polygon(arm_fore, fill=LGT, outline=OUT)
        elif "tunic" in style:
            d.polygon([(26, 56 + bob), (38, 56 + bob), (39, 82 + bob), (25, 82 + bob)], fill=LGT, outline=OUT)
            d.rectangle([(25, 72 + bob), (39, 76 + bob)], fill=(90, 60, 40, 255), outline=OUT)
            d.polygon(arm_pts, fill=LGT, outline=OUT)
        elif "bib" in style or "overalls" in style:
            d.polygon([(26, 56 + bob), (38, 56 + bob), (37, 76 + bob), (25, 76 + bob)], fill=(220, 220, 220, 255), outline=OUT)
            d.polygon([(29, 56 + bob), (34, 56 + bob), (34, 76 + bob), (28, 76 + bob)], fill=LGT, outline=OUT)
            d.polygon([(arm_pts[0][0], arm_pts[0][1]), (arm_pts[1][0], arm_pts[1][1]), (arm_pts[2][0]-1, arm_pts[2][1]-7), (arm_pts[3][0]-1, arm_pts[3][1]-7)], fill=(220, 220, 220, 255), outline=OUT)
        else: # flannel, tshirt, hoodie
            d.polygon([(26, 56 + bob), (38, 56 + bob), (37, 76 + bob), (25, 76 + bob)], fill=LGT, outline=OUT)
            d.polygon(arm_pts, fill=LGT, outline=OUT)
            d.polygon(arm_fore, fill=LGT, outline=OUT)
            
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
            
    return img

# =============================================================
# 6. ROPA INFERIOR (BOTTOMS) - AJUSTE PRECISO A LAS PIERNAS
# =============================================================
def generate_bottoms(style="farmer_overalls", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    
    if direction == "down":
        l_foot_y = 124 if frame == 1 else 125
        r_foot_y = 124 if frame == 1 else 125
        
        if "bikini" in style:
            d.polygon([(24, 77 + bob), (40, 77 + bob), (34, 87 + bob), (30, 87 + bob)], fill=LGT, outline=OUT)
            d.point([(25, 78 + bob), (39, 78 + bob)], fill=HL)
        elif "underwear" in style:
            d.polygon([(24, 76 + bob), (40, 76 + bob), (40, 85 + bob), (34, 87 + bob), (30, 87 + bob), (24, 85 + bob)], fill=LGT, outline=OUT)
            d.line([(24, 78 + bob), (40, 78 + bob)], fill=SHD)
        elif "shorts" in style:
            d.polygon([(24, 76 + bob), (40, 76 + bob), (40, 85 + bob), (34, 87 + bob), (30, 87 + bob), (24, 85 + bob)], fill=LGT, outline=OUT)
            d.polygon([(23, 85 + bob), (31, 87 + bob), (30, 94), (22, 94)], fill=LGT, outline=OUT)
            d.polygon([(33, 87 + bob), (41, 85 + bob), (42, 94), (34, 94)], fill=LGT, outline=OUT)
            d.line([(22, 94), (30, 94)], fill=SHD, width=1)
            d.line([(34, 94), (42, 94)], fill=SHD, width=1)
        elif "pleated" in style:
            d.polygon([(24, 76 + bob), (40, 76 + bob), (44, 95 + bob), (20, 95 + bob)], fill=LGT, outline=OUT)
            for px in range(22, 42, 4):
                d.line([(px, 78 + bob), (px - 2, 95 + bob)], fill=SHD)
                d.line([(px + 1, 78 + bob), (px, 95 + bob)], fill=HL)
            d.line([(24, 78 + bob), (40, 78 + bob)], fill=OUT)
        elif "skirt" in style or "rustic" in style:
            d.polygon([(24, 76 + bob), (40, 76 + bob), (45, 112 + bob), (19, 112 + bob)], fill=LGT, outline=OUT)
            for px in range(22, 42, 5):
                d.line([(px, 78 + bob), (px - 2, 112 + bob)], fill=SHD)
                d.line([(px + 2, 78 + bob), (px + 1, 112 + bob)], fill=HL)
            d.line([(24, 78 + bob), (40, 78 + bob)], fill=OUT)
        else:
            d.polygon([(24, 76 + bob), (40, 76 + bob), (40, 85 + bob), (34, 87 + bob), (30, 87 + bob), (24, 85 + bob)], fill=LGT, outline=OUT)
            d.polygon([(23, 85 + bob), (31, 87 + bob), (29, 116), (21, 116)], fill=LGT, outline=OUT)
            d.polygon([(33, 87 + bob), (41, 85 + bob), (43, 116), (35, 116)], fill=LGT, outline=OUT)
            if "overalls" in style:
                d.rectangle([(23, 96 + bob), (27, 102 + bob)], fill=MID, outline=OUT)
                d.rectangle([(21, 112), (29, 116)], fill=HL, outline=OUT)
                d.rectangle([(35, 112), (43, 116)], fill=HL, outline=OUT)
            else:
                d.line([(24, 79 + bob), (40, 79 + bob)], fill=SHD)
                
    elif direction == "up":
        if "bikini" in style or "underwear" in style:
            d.polygon([(24, 77 + bob), (40, 77 + bob), (40, 85 + bob), (24, 85 + bob)], fill=LGT, outline=OUT)
        elif "shorts" in style:
            d.polygon([(24, 76 + bob), (40, 76 + bob), (41, 94 + bob), (23, 94 + bob)], fill=LGT, outline=OUT)
            d.rectangle([(25, 80 + bob), (30, 88 + bob)], fill=MID, outline=OUT)
            d.rectangle([(34, 80 + bob), (39, 88 + bob)], fill=MID, outline=OUT)
        elif "skirt" in style or "pleated" in style:
            d.polygon([(24, 76 + bob), (40, 76 + bob), (45, 105 + bob), (19, 105 + bob)], fill=LGT, outline=OUT)
            for px in range(22, 42, 5):
                d.line([(px, 78 + bob), (px - 2, 105 + bob)], fill=SHD)
        else:
            d.polygon([(24, 76 + bob), (40, 76 + bob), (40, 85 + bob), (24, 85 + bob)], fill=LGT, outline=OUT)
            d.rectangle([(25, 79 + bob), (30, 86 + bob)], fill=MID, outline=OUT)
            d.rectangle([(34, 79 + bob), (39, 86 + bob)], fill=MID, outline=OUT)
            d.polygon([(23, 85 + bob), (31, 87 + bob), (29, 116), (21, 116)], fill=LGT, outline=OUT)
            d.polygon([(33, 87 + bob), (41, 85 + bob), (43, 116), (35, 116)], fill=LGT, outline=OUT)
            
    elif direction in ("left", "right"):
        if frame == 1:
            # Stride Left Forward (Front leg x: 22..28, Rear leg x: 33..39)
            front_leg_pts = [(26, 86 + bob), (34, 86 + bob), (27, 114), (20, 114)]
            rear_leg_pts = [(33, 86 + bob), (38, 86 + bob), (39, 114), (32, 114)]
        elif frame == 3:
            # Stride Right Forward (Front leg x: 22..28, Rear leg x: 32..40)
            front_leg_pts = [(26, 86 + bob), (34, 86 + bob), (28, 114), (21, 114)]
            rear_leg_pts = [(33, 86 + bob), (38, 86 + bob), (39, 114), (32, 114)]
        else: # F0, F2
            front_leg_pts = [(27, 86 + bob), (34, 86 + bob), (34, 114), (27, 114)]
            rear_leg_pts = [(26, 86 + bob), (33, 86 + bob), (33, 114), (26, 114)]
            
        if "bikini" in style or "underwear" in style:
            d.polygon([(27, 78 + bob), (35, 78 + bob), (34, 87 + bob), (26, 87 + bob)], fill=LGT, outline=OUT)
        elif "shorts" in style:
            d.polygon([(front_leg_pts[0][0], front_leg_pts[0][1]-6), (front_leg_pts[1][0], front_leg_pts[1][1]-6), (front_leg_pts[1][0], 94), (front_leg_pts[0][0], 94)], fill=LGT, outline=OUT)
            d.polygon([(rear_leg_pts[0][0], rear_leg_pts[0][1]-6), (rear_leg_pts[1][0], rear_leg_pts[1][1]-6), (rear_leg_pts[1][0], 94), (rear_leg_pts[0][0], 94)], fill=MID, outline=OUT)
        elif "skirt" in style or "pleated" in style:
            d.polygon([(26, 76 + bob), (38, 76 + bob), (42, 105 + bob), (22, 105 + bob)], fill=LGT, outline=OUT)
        else:
            d.polygon(rear_leg_pts, fill=MID, outline=OUT)
            d.polygon(front_leg_pts, fill=LGT, outline=OUT)
            if "overalls" in style:
                d.line([(front_leg_pts[0][0]+3, 88 + bob), (front_leg_pts[0][0]+3, 100 + bob)], fill=OUT)
                
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
            
    return img

# =============================================================
# 7. CALZADO (SHOES) - AJUSTE A LOS PIES DEL CUERPO BASE
# =============================================================
def generate_shoes(style="farmer_boots", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    
    if direction == "down":
        l_foot_y = 124 if frame == 1 else 125
        r_foot_y = 124 if frame == 1 else 125
        
        if "sandals" in style:
            d.rectangle([(19, l_foot_y - 3), (29, l_foot_y)], fill=MID, outline=OUT)
            d.line([(21, l_foot_y - 6), (27, l_foot_y - 3)], fill=OUT)
            d.rectangle([(35, r_foot_y - 3), (45, r_foot_y)], fill=MID, outline=OUT)
            d.line([(37, r_foot_y - 6), (43, r_foot_y - 3)], fill=OUT)
        elif "sneakers" in style:
            d.polygon([(20, 112), (29, 112), (30, l_foot_y), (19, l_foot_y)], fill=LGT, outline=OUT)
            d.rectangle([(19, l_foot_y - 3), (30, l_foot_y)], fill=(255, 255, 255, 255), outline=OUT)
            d.polygon([(35, 112), (44, 112), (45, r_foot_y), (34, r_foot_y)], fill=LGT, outline=OUT)
            d.rectangle([(34, r_foot_y - 3), (45, r_foot_y)], fill=(255, 255, 255, 255), outline=OUT)
        elif "adventurer" in style:
            d.polygon([(20, 104), (29, 104), (30, l_foot_y), (19, l_foot_y)], fill=LGT, outline=OUT)
            d.rectangle([(19, l_foot_y - 3), (30, l_foot_y)], fill=DEEP_SHD, outline=OUT)
            d.rectangle([(20, 103), (30, 108)], fill=HL, outline=OUT)
            d.polygon([(35, 104), (44, 104), (45, r_foot_y), (34, r_foot_y)], fill=LGT, outline=OUT)
            d.rectangle([(34, r_foot_y - 3), (45, r_foot_y)], fill=DEEP_SHD, outline=OUT)
            d.rectangle([(34, 103), (44, 108)], fill=HL, outline=OUT)
        else:
            d.polygon([(20, 108), (29, 108), (30, l_foot_y), (19, l_foot_y)], fill=LGT, outline=OUT)
            d.rectangle([(19, l_foot_y - 3), (30, l_foot_y)], fill=OUT)
            d.polygon([(35, 108), (44, 108), (45, r_foot_y), (34, r_foot_y)], fill=LGT, outline=OUT)
            d.rectangle([(34, r_foot_y - 3), (45, r_foot_y)], fill=OUT)
            
    elif direction == "up":
        l_foot_y = 124 if frame == 1 else 125
        r_foot_y = 124 if frame == 1 else 125
        d.polygon([(20, 108), (29, 108), (30, l_foot_y), (19, l_foot_y)], fill=LGT, outline=OUT)
        d.polygon([(35, 108), (44, 108), (45, r_foot_y), (34, r_foot_y)], fill=LGT, outline=OUT)
        d.line([(24, 108), (24, l_foot_y - 3)], fill=MID)
        d.line([(40, 108), (40, r_foot_y - 3)], fill=MID)
        
    elif direction in ("left", "right"):
        if frame == 1:
            # Front foot x: 17..28, Rear foot x: 35..45 (y=120)
            d.polygon([(34, 114), (43, 114), (43, 120), (32, 120)], fill=SHD, outline=OUT) # Trasero
            d.polygon([(20, 114), (28, 114), (28, 124), (17, 124)], fill=LGT, outline=OUT) # Delantero
        elif frame == 3:
            # Front foot x: 18..28, Rear foot x: 30..40
            d.polygon([(31, 114), (39, 114), (39, 124), (29, 124)], fill=SHD, outline=OUT)
            d.polygon([(21, 114), (28, 114), (28, 124), (18, 124)], fill=LGT, outline=OUT)
        else: # F0, F2
            d.polygon([(26, 114), (34, 114), (34, 124), (22, 124)], fill=SHD, outline=OUT)
            d.polygon([(25, 114), (35, 114), (35, 124), (22, 124)], fill=LGT, outline=OUT)
            
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
            
    return img

# =============================================================
# 8. ACCESORIOS (ACCESSORIES)
# =============================================================
def generate_accessories(style="straw_hat", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0
    
    if "straw_hat" in style:
        if direction == "down":
            d.polygon([(7, 22 + bob), (57, 22 + bob), (53, 27 + bob), (11, 27 + bob)], fill=(245, 220, 120, 255), outline=OUT)
            d.line([(9, 24 + bob), (55, 24 + bob)], fill=(255, 240, 160, 255))
            d.polygon([(19, 9 + bob), (45, 9 + bob), (47, 22 + bob), (17, 22 + bob)], fill=(235, 200, 90, 255), outline=OUT)
            d.rectangle([(18, 19 + bob), (46, 22 + bob)], fill=(220, 40, 40, 255), outline=OUT)
        elif direction == "up":
            d.polygon([(7, 22 + bob), (57, 22 + bob), (53, 27 + bob), (11, 27 + bob)], fill=(235, 200, 90, 255), outline=OUT)
            d.polygon([(19, 9 + bob), (45, 9 + bob), (47, 22 + bob), (17, 22 + bob)], fill=(225, 190, 80, 255), outline=OUT)
            d.rectangle([(18, 19 + bob), (46, 22 + bob)], fill=(220, 40, 40, 255), outline=OUT)
            d.polygon([(29, 22 + bob), (35, 22 + bob), (33, 34 + bob), (31, 34 + bob)], fill=(220, 40, 40, 255))
        elif direction in ("left", "right"):
            d.polygon([(12, 22 + bob), (52, 22 + bob), (50, 27 + bob), (14, 27 + bob)], fill=(245, 220, 120, 255), outline=OUT)
            d.polygon([(22, 9 + bob), (44, 9 + bob), (46, 22 + bob), (20, 22 + bob)], fill=(235, 200, 90, 255), outline=OUT)
            d.rectangle([(21, 19 + bob), (45, 22 + bob)], fill=(220, 40, 40, 255), outline=OUT)
    elif "hood" in style:
        d.ellipse([13, 7 + bob, 51, 40 + bob], fill=LGT, outline=OUT)
        d.polygon([(17, 36 + bob), (47, 36 + bob), (45, 62 + bob), (19, 62 + bob)], fill=MID, outline=OUT)
    elif "glasses" in style and direction != "up":
        if direction == "down":
            d.ellipse([21, 31 + bob, 29, 39 + bob], outline=(240, 210, 60, 255), width=1)
            d.point([(23, 33 + bob)], fill=(255, 255, 255, 220))
            d.ellipse([35, 31 + bob, 43, 39 + bob], outline=(240, 210, 60, 255), width=1)
            d.point([(37, 33 + bob)], fill=(255, 255, 255, 220))
            d.line([(29, 34 + bob), (35, 34 + bob)], fill=(240, 210, 60, 255))
        else:
            d.ellipse([21, 31 + bob, 29, 39 + bob], outline=(240, 210, 60, 255), width=1)
            d.line([(29, 34 + bob), (37, 34 + bob)], fill=(240, 210, 60, 255))
    elif "flower" in style:
        d.ellipse([43, 19 + bob, 49, 25 + bob], fill=(255, 120, 160, 255), outline=OUT)
    elif "bandana" in style:
        d.polygon([(24, 53 + bob), (40, 53 + bob), (32, 63 + bob)], fill=LGT, outline=OUT)
    elif "satchel" in style:
        d.line([(20, 56 + bob), (46, 82 + bob)], fill=(80, 50, 30, 255), width=2)
        d.polygon([(43, 78 + bob), (51, 80 + bob), (49, 92 + bob), (41, 90 + bob)], fill=(110, 75, 45, 255), outline=OUT)
    elif "sunglasses" in style and direction != "up":
        d.polygon([(20, 31 + bob), (30, 31 + bob), (29, 39 + bob), (21, 38 + bob)], fill=SHD, outline=OUT)
        d.polygon([(34, 31 + bob), (44, 31 + bob), (43, 38 + bob), (35, 39 + bob)], fill=SHD, outline=OUT)
        d.line([(30, 32 + bob), (34, 32 + bob)], fill=OUT, width=2)
        
    if direction == "right":
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
        
    return img

def export_clothing_and_features_to_disk(base_dir="assets"):
    """Exporta las prendas y rasgos faciales a disco sin sobreescribir los assets base personalizados del usuario."""
    categories = {
        "face_shape": [("oval", generate_face_shape), ("round", generate_face_shape), ("sharp_v", generate_face_shape), ("square_jaw", generate_face_shape), ("heart", generate_face_shape)],
        "eyes": [
            ("shoujo_sparkle", generate_eyes), ("stardew_cute", generate_eyes), ("jrpg_classic", generate_eyes),
            ("adventurer_serious", generate_eyes), ("sleepy_calm", generate_eyes), ("cateye_sly", generate_eyes),
            ("mystic_glow", generate_eyes), ("happy_closed", generate_eyes), ("dot_chibi", generate_eyes), ("wink", generate_eyes)
        ],
        "eyebrows": [("normal", generate_eyebrows), ("thick", generate_eyebrows), ("serious", generate_eyebrows), ("arched", generate_eyebrows)],
        "nose": [("subtle", generate_nose), ("pointed", generate_nose), ("button", generate_nose)],
        "mouth": [("smile", generate_mouth), ("neutral", generate_mouth), ("open_smile", generate_mouth), ("smirk", generate_mouth), ("lipstick", generate_mouth)],
        "face_details": [("blush", generate_face_detail), ("freckles", generate_face_detail), ("scar", generate_face_detail), ("none", generate_face_detail)],
        "hair": [
            ("farm_braids", generate_hair), ("adventurer_spiky", generate_hair), ("long_flowing", generate_hair),
            ("bob_bangs", generate_hair), ("curly_locks", generate_hair), ("high_ponytail", generate_hair),
            ("twintails", generate_hair), ("messy_wanderer", generate_hair), ("none", generate_hair)
        ],
        "tops": [
            ("flannel_shirt", generate_tops), ("overalls_bib", generate_tops), ("traveler_tunic", generate_tops),
            ("adventurer_coat", generate_tops), ("tshirt", generate_tops), ("hoodie", generate_tops),
            ("crop_top", generate_tops), ("bikini", generate_tops), ("none", generate_tops)
        ],
        "bottoms": [
            ("farmer_overalls", generate_bottoms), ("adventurer_pants", generate_bottoms), ("rustic_skirt", generate_bottoms),
            ("skirt_pleated", generate_bottoms), ("shorts", generate_bottoms), ("underwear", generate_bottoms),
            ("bikini", generate_bottoms), ("none", generate_bottoms)
        ],
        "shoes": [
            ("adventurer_boots", generate_shoes), ("farmer_boots", generate_shoes), ("sneakers", generate_shoes),
            ("sandals", generate_shoes), ("none", generate_shoes)
        ],
        "accessories": [
            ("straw_hat", generate_accessories), ("traveler_hood", generate_accessories), ("hair_flower", generate_accessories),
            ("scholar_glasses", generate_accessories), ("neck_bandana", generate_accessories), ("satchel_bag", generate_accessories),
            ("headphones", generate_accessories), ("sunglasses_cool", generate_accessories), ("none", generate_accessories)
        ]
    }
    
    exported_count = 0
    for cat, items in categories.items():
        for style_name, func in items:
            item_folder = os.path.join(base_dir, cat, style_name)
            os.makedirs(item_folder, exist_ok=True)
            for d in ["down", "up", "left", "right"]:
                for f in range(4):
                    img = func(style=style_name, direction=d, frame=f)
                    filename = f"{d}_frame{f}.png"
                    img.save(os.path.join(item_folder, filename), "PNG")
                    exported_count += 1
                    
    print(f"Exportadas {exported_count} imágenes de ropa y accesorios respetando los assets base personalizados en '{base_dir}/'.")
    return exported_count

def export_all_layers_to_disk(base_dir="assets"):
    return export_clothing_and_features_to_disk(base_dir)

if __name__ == "__main__":
    export_clothing_and_features_to_disk("assets")
