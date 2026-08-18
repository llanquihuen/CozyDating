"""
sprite_generator_32x64.py - Generador de sprites base 32x64 multi-direccional y animado
Resolución Micro-Chibi (la mitad de ancho y alto de 64x128).
Estilo retro JRPG Overworld / GBA / Pokémon con proporciones compactas y nítidas.
"""

import os
from PIL import Image, ImageDraw

WIDTH = 32
HEIGHT = 64
ASSETS_DIR = "assets_32x64"

def create_canvas():
    return Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))

HL = (255, 255, 255, 255)
LGT = (215, 215, 215, 255)
MID = (165, 165, 165, 255)
SHD = (110, 110, 110, 255)
DEEP_SHD = (70, 70, 70, 255)
OUT = (35, 35, 35, 255)

# =============================================================
# 1. CUERPO BASE 32x64 (4 DIRECCIONES Y 4 CUADROS)
# =============================================================
def generate_body(direction="down", frame=0):
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

    # Sombra en el suelo
    d.ellipse([9, 58, 23, 62], fill=(0, 0, 0, 70))

    if direction == "down":
        # Cuello
        d.rectangle([15, 26 + bob, 17, 28 + bob], fill=MID)

        # Torso
        torso_pts = [
            (12, 28 + bob), (20, 28 + bob), (20, 42 + bob), (12, 42 + bob)
        ]
        d.polygon(torso_pts, fill=LGT, outline=OUT)
        d.point([(16, 38 + bob)], fill=SHD) # Ombligo

        # Balanceo de brazos
        l_arm_off = -1 if frame == 1 else (1 if frame == 3 else 0)
        r_arm_off = 1 if frame == 1 else (-1 if frame == 3 else 0)

        # Brazo Izquierdo
        d.polygon([(9 + l_arm_off, 29 + bob), (12, 28 + bob), (11 + l_arm_off, 38 + bob), (8 + l_arm_off, 38 + bob)], fill=LGT, outline=OUT)
        d.rectangle([8 + l_arm_off, 38 + bob, 10 + l_arm_off, 41 + bob], fill=MID, outline=OUT)

        # Brazo Derecho
        d.polygon([(20, 28 + bob), (23 + r_arm_off, 29 + bob), (24 + r_arm_off, 38 + bob), (21 + r_arm_off, 38 + bob)], fill=LGT, outline=OUT)
        d.rectangle([22 + r_arm_off, 38 + bob, 24 + r_arm_off, 41 + bob], fill=MID, outline=OUT)

        # Piernas
        l_step = 1 if frame == 1 else 0
        r_step = 1 if frame == 3 else 0
        l_foot_y = 60 if frame == 1 else 61
        r_foot_y = 60 if frame == 3 else 61

        # Pierna Izquierda
        d.polygon([(11, 42 + bob), (15, 42 + bob), (15, l_foot_y), (10, l_foot_y)], fill=LGT, outline=OUT)
        # Pierna Derecha
        d.polygon([(17, 42 + bob), (21, 42 + bob), (22, r_foot_y), (17, r_foot_y)], fill=LGT, outline=OUT)

    elif direction == "up":
        # Cuello dorsal
        d.rectangle([15, 26 + bob, 17, 28 + bob], fill=MID)

        # Torso dorsal
        d.polygon([(12, 28 + bob), (20, 28 + bob), (20, 42 + bob), (12, 42 + bob)], fill=LGT, outline=OUT)
        d.line([(16, 29 + bob), (16, 39 + bob)], fill=MID)

        # Balanceo dorsal de brazos
        l_arm_off = 1 if frame == 1 else (-1 if frame == 3 else 0)
        r_arm_off = -1 if frame == 1 else (1 if frame == 3 else 0)

        d.polygon([(9 + l_arm_off, 29 + bob), (12, 28 + bob), (11 + l_arm_off, 38 + bob), (8 + l_arm_off, 38 + bob)], fill=LGT, outline=OUT)
        d.rectangle([8 + l_arm_off, 38 + bob, 10 + l_arm_off, 41 + bob], fill=MID, outline=OUT)

        d.polygon([(20, 28 + bob), (23 + r_arm_off, 29 + bob), (24 + r_arm_off, 38 + bob), (21 + r_arm_off, 38 + bob)], fill=LGT, outline=OUT)
        d.rectangle([22 + r_arm_off, 38 + bob, 24 + r_arm_off, 41 + bob], fill=MID, outline=OUT)

        l_foot_y = 60 if frame == 1 else 61
        r_foot_y = 60 if frame == 3 else 61

        d.polygon([(11, 42 + bob), (15, 42 + bob), (15, l_foot_y), (10, l_foot_y)], fill=LGT, outline=OUT)
        d.polygon([(17, 42 + bob), (21, 42 + bob), (22, r_foot_y), (17, r_foot_y)], fill=LGT, outline=OUT)

    elif direction in ("left", "right"):
        d.rectangle([15, 26 + bob, 17, 28 + bob], fill=MID)
        # Torso lateral
        d.polygon([(13, 28 + bob), (19, 28 + bob), (19, 42 + bob), (13, 42 + bob)], fill=LGT, outline=OUT)

        # Cinemática de zancada en perfil
        f_stride = 2 if frame == 1 else (-2 if frame == 3 else 0)
        b_stride = -2 if frame == 1 else (2 if frame == 3 else 0)
        b_foot_y = 59 if frame == 1 else 61
        f_foot_y = 61

        # Pierna trasera
        d.polygon([(14 + b_stride, 42 + bob), (18 + b_stride, 42 + bob), (18 + b_stride, b_foot_y), (13 + b_stride, b_foot_y)], fill=MID, outline=OUT)
        # Pierna delantera
        d.polygon([(14 + f_stride, 42 + bob), (19 + f_stride, 42 + bob), (19 + f_stride, f_foot_y), (13 + f_stride, f_foot_y)], fill=LGT, outline=OUT)

        # Brazo con balanceo
        arm_swing = int(-f_stride * 0.8)
        d.polygon([(14, 28 + bob), (18, 28 + bob), (18 + arm_swing, 38 + bob), (14 + arm_swing, 38 + bob)], fill=LGT, outline=OUT)
        d.rectangle([14 + arm_swing, 38 + bob, 17 + arm_swing, 41 + bob], fill=MID, outline=OUT)

        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

    return img

# =============================================================
# 2. FORMAS DE LA CARA 32x64
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
            pts = [(8, 12 + bob), (11, 8 + bob), (16, 7 + bob), (21, 8 + bob), (24, 12 + bob), (25, 18 + bob), (23, 24 + bob), (20, 26 + bob), (16, 27 + bob), (12, 26 + bob), (9, 24 + bob), (7, 18 + bob)]
            d.polygon(pts, fill=LGT, outline=OUT)
            d.rectangle([10, 12 + bob, 22, 24 + bob], fill=LGT)
            d.rectangle([7, 17 + bob, 8, 21 + bob], fill=MID, outline=OUT)
            d.rectangle([24, 17 + bob, 25, 21 + bob], fill=MID, outline=OUT)
        elif "sharp" in shape_type:
            pts = [(9, 12 + bob), (12, 8 + bob), (16, 7 + bob), (20, 8 + bob), (23, 12 + bob), (23, 17 + bob), (21, 23 + bob), (16, 28 + bob), (11, 23 + bob), (9, 17 + bob)]
            d.polygon(pts, fill=LGT, outline=OUT)
            d.rectangle([11, 12 + bob, 21, 22 + bob], fill=LGT)
            d.rectangle([8, 16 + bob, 9, 20 + bob], fill=MID, outline=OUT)
            d.rectangle([23, 16 + bob, 24, 20 + bob], fill=MID, outline=OUT)
        elif "square" in shape_type:
            pts = [(9, 11 + bob), (12, 8 + bob), (16, 7 + bob), (20, 8 + bob), (23, 11 + bob), (24, 18 + bob), (23, 25 + bob), (16, 26 + bob), (9, 25 + bob), (8, 18 + bob)]
            d.polygon(pts, fill=LGT, outline=OUT)
            d.rectangle([10, 12 + bob, 22, 25 + bob], fill=LGT)
            d.rectangle([7, 17 + bob, 8, 21 + bob], fill=MID, outline=OUT)
            d.rectangle([24, 17 + bob, 25, 21 + bob], fill=MID, outline=OUT)
        else: # oval / heart
            pts = [(9, 12 + bob), (12, 8 + bob), (16, 7 + bob), (20, 8 + bob), (23, 12 + bob), (23, 18 + bob), (22, 24 + bob), (19, 26 + bob), (16, 27 + bob), (13, 26 + bob), (10, 24 + bob), (9, 18 + bob)]
            d.polygon(pts, fill=LGT, outline=OUT)
            d.rectangle([11, 13 + bob, 21, 24 + bob], fill=LGT)
            d.rectangle([8, 17 + bob, 9, 21 + bob], fill=MID, outline=OUT)
            d.rectangle([23, 17 + bob, 24, 21 + bob], fill=MID, outline=OUT)

        d.rectangle([14, 26 + bob, 18, 27 + bob], fill=SHD)

    elif direction == "up":
        pts = [(9, 12 + bob), (12, 8 + bob), (16, 7 + bob), (20, 8 + bob), (23, 12 + bob), (23, 22 + bob), (16, 27 + bob), (9, 22 + bob)]
        d.polygon(pts, fill=LGT, outline=OUT)
        d.rectangle([11, 13 + bob, 21, 25 + bob], fill=LGT)
        d.rectangle([8, 17 + bob, 9, 21 + bob], fill=MID, outline=OUT)
        d.rectangle([23, 17 + bob, 24, 21 + bob], fill=MID, outline=OUT)

    elif direction in ("left", "right"):
        pts = [(11, 12 + bob), (14, 8 + bob), (18, 7 + bob), (22, 10 + bob), (23, 18 + bob), (21, 24 + bob), (16, 27 + bob), (12, 23 + bob), (10, 17 + bob)]
        d.polygon(pts, fill=LGT, outline=OUT)
        d.rectangle([13, 13 + bob, 21, 24 + bob], fill=LGT)
        d.rectangle([17, 17 + bob, 19, 21 + bob], fill=MID, outline=OUT)
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

    return img

# =============================================================
# 3. RASGOS FACIALES 32x64
# =============================================================
def generate_eyes(style="jrpg_classic", direction="down", frame=0):
    if direction == "up":
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0

    DARK = (35, 30, 40, 255)
    IRIS_BRIGHT = (220, 0, 0, 255)
    IRIS_SHADOW = (150, 0, 0, 255)
    WHITE = (255, 255, 255, 255)

    if direction == "down":
        if "shoujo" in style or "sparkle" in style:
            # Ojos Shoujo / Gran Brillo Anime (4x4 detallados con doble reflejo)
            for lx in [10, 18]:
                d.line([(lx, 15 + bob), (lx + 3, 15 + bob)], fill=DARK) # Pestaña superior
                d.point([(lx + 4, 16 + bob)], fill=DARK) # Rabillo
                d.rectangle([lx, 16 + bob, lx + 3, 19 + bob], fill=IRIS_BRIGHT)
                d.line([(lx, 19 + bob), (lx + 3, 19 + bob)], fill=IRIS_SHADOW)
                d.point([(lx, 17 + bob)], fill=WHITE) # Reflejo primario
                d.point([(lx + 2, 18 + bob)], fill=WHITE) # Reflejo secundario
        elif "happy" in style or "closed" in style:
            # Ojos cerrados felices (^ ^)
            d.line([(10, 18 + bob), (12, 16 + bob)], fill=DARK, width=1)
            d.line([(12, 16 + bob), (14, 18 + bob)], fill=DARK, width=1)
            d.line([(17, 18 + bob), (19, 16 + bob)], fill=DARK, width=1)
            d.line([(19, 16 + bob), (21, 18 + bob)], fill=DARK, width=1)
        elif "wink" in style:
            # Guiño (Izquierdo cerrado ^, Derecho abierto clásico)
            d.line([(10, 18 + bob), (12, 16 + bob)], fill=DARK, width=1)
            d.line([(12, 16 + bob), (14, 18 + bob)], fill=DARK, width=1)
            # Derecho
            d.line([(18, 15 + bob), (21, 15 + bob)], fill=DARK)
            d.rectangle([18, 16 + bob, 20, 18 + bob], fill=IRIS_BRIGHT)
            d.line([(18, 18 + bob), (20, 18 + bob)], fill=IRIS_SHADOW)
            d.point([(21, 17 + bob)], fill=WHITE)
            d.point([(18, 16 + bob)], fill=WHITE)
        elif "dot" in style:
            # Ojos Dot Chibi (Retro 2x2 con reflejo sutil)
            for lx in [11, 18]:
                d.rectangle([lx, 16 + bob, lx + 2, 18 + bob], fill=IRIS_BRIGHT, outline=DARK)
                d.point([(lx, 16 + bob)], fill=WHITE)
        elif "sleepy" in style or "calm" in style:
            # Ojos Entreabiertos / Relajados
            for lx in [10, 18]:
                d.line([(lx, 16 + bob), (lx + 3, 16 + bob)], fill=DARK, width=1)
                d.line([(lx + 1, 17 + bob), (lx + 3, 17 + bob)], fill=IRIS_BRIGHT)
                d.point([(lx, 17 + bob)], fill=WHITE)
        elif "cateye" in style or "sly" in style:
            # Ojos Rasgados / Gatunos con rabillo alargado
            d.line([(9, 15 + bob), (13, 16 + bob)], fill=DARK)
            d.rectangle([10, 17 + bob, 12, 18 + bob], fill=IRIS_BRIGHT)
            d.point([(10, 17 + bob)], fill=WHITE)
            d.line([(18, 16 + bob), (22, 15 + bob)], fill=DARK)
            d.rectangle([19, 17 + bob, 21, 18 + bob], fill=IRIS_BRIGHT)
            d.point([(19, 17 + bob)], fill=WHITE)
        elif "mystic" in style:
            # Ojos Místicos / Brillantes
            for lx in [10, 18]:
                d.rectangle([lx, 16 + bob, lx + 3, 18 + bob], fill=IRIS_BRIGHT, outline=DARK)
                d.point([(lx + 1, 17 + bob)], fill=WHITE)
                d.point([(lx + 2, 17 + bob)], fill=WHITE)
        elif "serious" in style or "adventurer" in style:
            # Ojos Serios / Decididos JRPG
            for lx in [10, 18]:
                d.line([(lx, 15 + bob), (lx + 3, 16 + bob)], fill=DARK)
                d.rectangle([lx + 1, 17 + bob, lx + 3, 18 + bob], fill=IRIS_BRIGHT)
                d.point([(lx, 17 + bob)], fill=WHITE)
                d.point([(lx + 1, 17 + bob)], fill=WHITE)
        elif "stardew" in style or "cute" in style:
            # Ojos Tiernos Redondos Stardew Valley
            for lx in [11, 18]:
                d.line([(lx, 15 + bob), (lx + 2, 15 + bob)], fill=DARK)
                d.rectangle([lx, 16 + bob, lx + 2, 18 + bob], fill=IRIS_BRIGHT)
                d.line([(lx, 18 + bob), (lx + 2, 18 + bob)], fill=IRIS_SHADOW)
                d.point([(lx, 16 + bob)], fill=WHITE)
        else:
            # JRPG Clásico (3x3 Proporción de Oro para 32x64)
            # Ojo Izquierdo
            d.line([(10, 15 + bob), (13, 15 + bob)], fill=DARK) # Pestaña
            d.rectangle([11, 16 + bob, 13, 18 + bob], fill=IRIS_BRIGHT) # Iris
            d.line([(11, 18 + bob), (13, 18 + bob)], fill=IRIS_SHADOW) # Sombra iris
            d.point([(10, 17 + bob)], fill=WHITE) # Esclerótica blanca
            d.point([(11, 16 + bob)], fill=WHITE) # Reflejo de luz
            # Ojo Derecho
            d.line([(18, 15 + bob), (21, 15 + bob)], fill=DARK) # Pestaña
            d.rectangle([18, 16 + bob, 20, 18 + bob], fill=IRIS_BRIGHT) # Iris
            d.line([(18, 18 + bob), (20, 18 + bob)], fill=IRIS_SHADOW) # Sombra iris
            d.point([(21, 17 + bob)], fill=WHITE) # Esclerótica blanca
            d.point([(18, 16 + bob)], fill=WHITE) # Reflejo de luz

    elif direction in ("left", "right"):
        # Ojo de Perfil 32x64 (Limpio y estilizado lateral)
        d.line([(10, 15 + bob), (13, 15 + bob)], fill=DARK)
        d.rectangle([10, 16 + bob, 12, 18 + bob], fill=IRIS_BRIGHT)
        d.line([(10, 18 + bob), (12, 18 + bob)], fill=IRIS_SHADOW)
        d.point([(13, 17 + bob)], fill=WHITE)
        d.point([(10, 16 + bob)], fill=WHITE)
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
            d.line([(10, 13 + bob), (13, 13 + bob)], fill=(180, 180, 180, 255), width=2)
            d.line([(18, 13 + bob), (21, 13 + bob)], fill=(180, 180, 180, 255), width=2)
        elif "serious" in style:
            d.line([(10, 13 + bob), (13, 14 + bob)], fill=(180, 180, 180, 255), width=1)
            d.line([(18, 14 + bob), (21, 13 + bob)], fill=(180, 180, 180, 255), width=1)
        elif "arched" in style:
            d.line([(10, 14 + bob), (12, 13 + bob), (13, 14 + bob)], fill=(180, 180, 180, 255), width=1)
            d.line([(18, 14 + bob), (19, 13 + bob), (21, 14 + bob)], fill=(180, 180, 180, 255), width=1)
        else:
            d.line([(10, 14 + bob), (13, 14 + bob)], fill=(180, 180, 180, 255), width=1)
            d.line([(18, 14 + bob), (21, 14 + bob)], fill=(180, 180, 180, 255), width=1)
    elif direction in ("left", "right"):
        d.line([(10, 14 + bob), (13, 14 + bob)], fill=(180, 180, 180, 255), width=1)
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
        d.point([(16, 21 + bob)], fill=(130, 130, 130, 255))
    elif direction in ("left", "right"):
        d.point([(10, 21 + bob)], fill=(110, 110, 110, 255))
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
        d.line([(15, 23 + bob), (17, 23 + bob)], fill=(100, 100, 100, 255))
        d.point([(16, 24 + bob)], fill=(120, 120, 120, 255))
    elif direction in ("left", "right"):
        d.line([(11, 23 + bob), (13, 23 + bob)], fill=(100, 100, 100, 255))
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
            d.rectangle([10, 20 + bob, 12, 21 + bob], fill=(230, 110, 110, 170))
            d.rectangle([20, 20 + bob, 22, 21 + bob], fill=(230, 110, 110, 170))
    elif direction in ("left", "right"):
        if "blush" in style:
            d.rectangle([11, 20 + bob, 13, 21 + bob], fill=(230, 110, 110, 170))
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img

# =============================================================
# 4. PEINADOS 32x64
# =============================================================
def generate_hair(style="farm_braids", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0

    if direction == "down":
        d.polygon([(8, 11 + bob), (11, 7 + bob), (16, 5 + bob), (21, 7 + bob), (24, 11 + bob), (22, 10 + bob), (16, 8 + bob), (10, 10 + bob)], fill=LGT, outline=OUT)
        d.polygon([(9, 10 + bob), (14, 14 + bob), (15, 10 + bob)], fill=LGT, outline=OUT)
        d.polygon([(17, 10 + bob), (18, 14 + bob), (23, 10 + bob)], fill=LGT, outline=OUT)
        if "braids" in style or "flowing" in style or "twintails" in style:
            d.rectangle([7, 21 + bob, 9, 37 + bob], fill=MID, outline=OUT)
            d.rectangle([23, 21 + bob, 25, 37 + bob], fill=MID, outline=OUT)
    elif direction == "up":
        d.polygon([(8, 12 + bob), (12, 6 + bob), (20, 6 + bob), (24, 12 + bob), (24, 22 + bob), (16, 27 + bob), (8, 22 + bob)], fill=LGT, outline=OUT)
        if "braids" in style:
            d.rectangle([7, 18 + bob, 10, 38 + bob], fill=MID, outline=OUT)
            d.rectangle([22, 18 + bob, 25, 38 + bob], fill=MID, outline=OUT)
    elif direction in ("left", "right"):
        d.polygon([(10, 11 + bob), (13, 6 + bob), (20, 6 + bob), (24, 11 + bob), (24, 23 + bob), (16, 27 + bob), (10, 22 + bob)], fill=LGT, outline=OUT)
        if "braids" in style or "flowing" in style:
            d.rectangle([18, 18 + bob, 23, 38 + bob], fill=MID, outline=OUT)
        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

    return img

# =============================================================
# 5. ROPA SUPERIOR (TOPS) 32x64
# =============================================================
def generate_tops(style="flannel_shirt", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0

    if direction == "down":
        l_arm_off = -1 if frame == 1 else (1 if frame == 3 else 0)
        r_arm_off = 1 if frame == 1 else (-1 if frame == 3 else 0)

        d.polygon([(12, 28 + bob), (20, 28 + bob), (20, 38 + bob), (12, 38 + bob)], fill=LGT, outline=OUT)
        d.polygon([(9 + l_arm_off, 29 + bob), (12, 28 + bob), (11 + l_arm_off, 36 + bob), (8 + l_arm_off, 36 + bob)], fill=LGT, outline=OUT)
        d.polygon([(20, 28 + bob), (23 + r_arm_off, 29 + bob), (24 + r_arm_off, 36 + bob), (21 + r_arm_off, 36 + bob)], fill=LGT, outline=OUT)
        d.line([(16, 29 + bob), (16, 38 + bob)], fill=OUT)

    elif direction == "up":
        l_arm_off = 1 if frame == 1 else (-1 if frame == 3 else 0)
        r_arm_off = -1 if frame == 1 else (1 if frame == 3 else 0)

        d.polygon([(12, 28 + bob), (20, 28 + bob), (20, 38 + bob), (12, 38 + bob)], fill=LGT, outline=OUT)
        d.polygon([(9 + l_arm_off, 29 + bob), (12, 28 + bob), (11 + l_arm_off, 36 + bob), (8 + l_arm_off, 36 + bob)], fill=LGT, outline=OUT)
        d.polygon([(20, 28 + bob), (23 + r_arm_off, 29 + bob), (24 + r_arm_off, 36 + bob), (21 + r_arm_off, 36 + bob)], fill=LGT, outline=OUT)

    elif direction in ("left", "right"):
        f_stride = 2 if frame == 1 else (-2 if frame == 3 else 0)
        arm_swing = int(-f_stride * 0.8)

        d.polygon([(13, 28 + bob), (19, 28 + bob), (19, 38 + bob), (13, 38 + bob)], fill=LGT, outline=OUT)
        d.polygon([(14, 28 + bob), (18, 28 + bob), (18 + arm_swing, 36 + bob), (14 + arm_swing, 36 + bob)], fill=LGT, outline=OUT)

        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

    return img

# =============================================================
# 6. ROPA INFERIOR (BOTTOMS) 32x64
# =============================================================
def generate_bottoms(style="farmer_overalls", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0

    if direction == "down":
        l_foot_y = 57 if frame == 1 else 58
        r_foot_y = 57 if frame == 3 else 58

        d.polygon([(11, 38 + bob), (21, 38 + bob), (21, 42 + bob), (11, 42 + bob)], fill=LGT, outline=OUT)
        d.polygon([(11, 42 + bob), (15, 42 + bob), (15, l_foot_y), (10, l_foot_y)], fill=LGT, outline=OUT)
        d.polygon([(17, 42 + bob), (21, 42 + bob), (22, r_foot_y), (17, r_foot_y)], fill=LGT, outline=OUT)

    elif direction == "up":
        l_foot_y = 57 if frame == 1 else 58
        r_foot_y = 57 if frame == 3 else 58

        d.polygon([(11, 38 + bob), (21, 38 + bob), (21, 42 + bob), (11, 42 + bob)], fill=LGT, outline=OUT)
        d.polygon([(11, 42 + bob), (15, 42 + bob), (15, l_foot_y), (10, l_foot_y)], fill=LGT, outline=OUT)
        d.polygon([(17, 42 + bob), (21, 42 + bob), (22, r_foot_y), (17, r_foot_y)], fill=LGT, outline=OUT)

    elif direction in ("left", "right"):
        f_stride = 2 if frame == 1 else (-2 if frame == 3 else 0)
        b_stride = -2 if frame == 1 else (2 if frame == 3 else 0)
        b_foot_y = 56 if frame == 1 else 58
        f_foot_y = 58

        d.polygon([(13, 38 + bob), (19, 38 + bob), (19, 42 + bob), (13, 42 + bob)], fill=LGT, outline=OUT)
        d.polygon([(14 + b_stride, 42 + bob), (18 + b_stride, 42 + bob), (18 + b_stride, b_foot_y), (13 + b_stride, b_foot_y)], fill=MID, outline=OUT)
        d.polygon([(14 + f_stride, 42 + bob), (19 + f_stride, 42 + bob), (19 + f_stride, f_foot_y), (13 + f_stride, f_foot_y)], fill=LGT, outline=OUT)

        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

    return img

# =============================================================
# 7. CALZADO (SHOES) 32x64
# =============================================================
def generate_shoes(style="farmer_boots", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)

    if direction == "down":
        l_foot_y = 60 if frame == 1 else 61
        r_foot_y = 60 if frame == 3 else 61

        d.rectangle([(10, l_foot_y - 4), (15, l_foot_y)], fill=LGT, outline=OUT)
        d.rectangle([(17, r_foot_y - 4), (22, r_foot_y)], fill=LGT, outline=OUT)

    elif direction == "up":
        l_foot_y = 60 if frame == 1 else 61
        r_foot_y = 60 if frame == 3 else 61

        d.rectangle([(10, l_foot_y - 4), (15, l_foot_y)], fill=LGT, outline=OUT)
        d.rectangle([(17, r_foot_y - 4), (22, r_foot_y)], fill=LGT, outline=OUT)

    elif direction in ("left", "right"):
        f_stride = 2 if frame == 1 else (-2 if frame == 3 else 0)
        b_stride = -2 if frame == 1 else (2 if frame == 3 else 0)
        b_foot_y = 59 if frame == 1 else 61
        f_foot_y = 61

        d.rectangle([(13 + b_stride, b_foot_y - 4), (18 + b_stride, b_foot_y)], fill=MID, outline=OUT)
        d.rectangle([(13 + f_stride, f_foot_y - 4), (19 + f_stride, f_foot_y)], fill=LGT, outline=OUT)

        if direction == "right":
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

    return img

# =============================================================
# 8. ACCESORIOS 32x64
# =============================================================
def generate_accessories(style="straw_hat", direction="down", frame=0):
    if "none" in style:
        return create_canvas()
    img = create_canvas()
    d = ImageDraw.Draw(img)
    bob = 1 if frame in (1, 3) else 0

    if "straw_hat" in style:
        d.polygon([(4, 10 + bob), (28, 10 + bob), (26, 13 + bob), (6, 13 + bob)], fill=(245, 220, 120, 255), outline=OUT)
        d.polygon([(10, 4 + bob), (22, 4 + bob), (23, 10 + bob), (9, 10 + bob)], fill=(235, 200, 90, 255), outline=OUT)
        d.rectangle([(9, 9 + bob), (23, 10 + bob)], fill=(220, 40, 40, 255))
    elif "glasses" in style and direction != "up":
        d.rectangle([(10, 16 + bob), (14, 18 + bob)], outline=(240, 210, 60, 255))
        d.rectangle([(18, 16 + bob), (22, 18 + bob)], outline=(240, 210, 60, 255))
        d.line([(14, 17 + bob), (18, 17 + bob)], fill=(240, 210, 60, 255))

    if direction == "right":
        img = img.transpose(Image.FLIP_LEFT_RIGHT)

    return img

def export_all_layers_to_disk(base_dir="assets_32x64"):
    """Exporta todos los archivos PNG 32x64 a disco organizados en subcarpetas."""
    categories = {
        "body": [("base", generate_body)],
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
                    if cat == "body":
                        img = func(direction=d, frame=f)
                    else:
                        img = func(style=style_name, direction=d, frame=f)
                    filename = f"{d}_frame{f}.png"
                    img.save(os.path.join(item_folder, filename), "PNG")
                    exported_count += 1

    print(f"Exportadas {exported_count} imágenes 32x64 dentro de '{base_dir}/'.")
    return exported_count

if __name__ == "__main__":
    export_all_layers_to_disk("assets_32x64")
