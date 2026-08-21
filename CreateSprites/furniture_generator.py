"""
furniture_generator.py - Generador de Muebles y Decoración Isométrica de Alta Definición Pixel Art
Incluye texturizado de maderas, acolchados capitoné, vetas, reflejos cerámicos, metales pulidos,
grabados ornamentales, agua con ondas, pliegues de telas y rotación en 4 ángulos.
"""

import os
import json
from PIL import Image, ImageDraw

# =============================================================
# PALETAS DE COLOR PROFESIONALES DE PIXEL ART
# =============================================================
# Madera de Roble / Nogal
WOOD_HL = (245, 205, 155, 255)
WOOD_LIGHT = (215, 165, 115, 255)
WOOD_MID = (165, 115, 70, 255)
WOOD_SHD = (115, 75, 45, 255)
WOOD_DEEP = (75, 45, 25, 255)
WOOD_OUT = (45, 28, 15, 255)

# Cerámica / Mármol / Blanco
WHITE_HL = (255, 255, 255, 255)
WHITE_LGT = (245, 248, 252, 255)
WHITE_MID = (205, 212, 222, 255)
WHITE_SHD = (155, 165, 180, 255)
WHITE_DEEP = (110, 120, 135, 255)

# Metales y Acero Inoxidable
METAL_HL = (245, 250, 255, 255)
METAL_LGT = (210, 218, 228, 255)
METAL_MID = (145, 155, 170, 255)
METAL_SHD = (90, 100, 115, 255)
METAL_DEEP = (50, 55, 65, 255)

# Oro / Latón Pulido
GOLD_HL = (255, 245, 160, 255)
GOLD_LGT = (255, 220, 95, 255)
GOLD_MID = (215, 165, 45, 255)
GOLD_SHD = (145, 100, 25, 255)
GOLD_DEEP = (95, 65, 15, 255)

# Telas & Acolchados
FABRIC_RED_LGT = (235, 90, 90, 255)
FABRIC_RED_MID = (195, 55, 55, 255)
FABRIC_RED_SHD = (140, 35, 35, 255)

FABRIC_BLUE_LGT = (100, 160, 235, 255)
FABRIC_BLUE_MID = (65, 120, 195, 255)
FABRIC_BLUE_SHD = (40, 75, 140, 255)

FABRIC_GOLD_LGT = (245, 215, 100, 255)
FABRIC_GOLD_MID = (220, 175, 50, 255)
FABRIC_GOLD_SHD = (165, 125, 30, 255)

FABRIC_TEAL_LGT = (100, 210, 190, 255)
FABRIC_TEAL_MID = (50, 160, 140, 255)
FABRIC_TEAL_SHD = (30, 110, 95, 255)

# Vidrio y Agua
GLASS_HL = (230, 250, 255, 240)
GLASS_LGT = (180, 230, 255, 200)
GLASS_MID = (120, 185, 225, 190)
GLASS_SHD = (70, 135, 185, 210)

# Vegetación y Hojas
PLANT_HL = (160, 240, 140, 255)
PLANT_LGT = (95, 205, 85, 255)
PLANT_MID = (50, 145, 45, 255)
PLANT_SHD = (30, 95, 30, 255)
PLANT_DEEP = (15, 55, 15, 255)

# Piedra y Adoquines
STONE_HL = (225, 230, 235, 255)
STONE_LGT = (185, 190, 195, 255)
STONE_MID = (135, 140, 145, 255)
STONE_SHD = (90, 95, 100, 255)
STONE_DEEP = (55, 60, 65, 255)

OUTLINE = (35, 30, 35, 255)


# =============================================================
# UTILIDADES GEOMÉTRICAS DE DIBUJADO DETALLADO
# =============================================================

def draw_iso_box(d, cx, cy, w, d_len, h, fill_top, fill_left, fill_right, outline=OUTLINE, bevel_top=True):
    """Dibuja un prisma rectangular isométrico con biselados y aristas de luz."""
    p_n = (cx, cy - h - (w + d_len) // 4)
    p_s = (cx, cy - h + (w + d_len) // 4)
    p_w = (cx - w, cy - h)
    p_e = (cx + d_len, cy - h)

    # Cara Izquierda (Sombreado medio)
    face_l = [(p_w[0], p_w[1]), (p_s[0], p_s[1]), (p_s[0], p_s[1] + h), (p_w[0], p_w[1] + h)]
    d.polygon(face_l, fill=fill_left, outline=outline)

    # Cara Derecha (Sombreado profundo)
    face_r = [(p_s[0], p_s[1]), (p_e[0], p_e[1]), (p_e[0], p_e[1] + h), (p_s[0], p_s[1] + h)]
    d.polygon(face_r, fill=fill_right, outline=outline)

    # Cara Superior (Iluminada)
    face_t = [(p_n[0], p_n[1]), (p_e[0], p_e[1]), (p_s[0], p_s[1]), (p_w[0], p_w[1])]
    d.polygon(face_t, fill=fill_top, outline=outline)

    # Bisel / Resalte de luz en arista superior
    if bevel_top:
        d.line([(p_w[0] + 1, p_w[1]), (p_s[0], p_s[1] - 1), (p_e[0] - 1, p_e[1])], fill=WHITE_HL if fill_top == WHITE_LGT else WOOD_HL)


def draw_wall_diagonal_panel(d, cx, cy, w, h, wall_type="wall_n", fill=WOOD_MID, outline=OUTLINE):
    """Dibuja un panel en perspectiva diagonal isométrica para pared Norte o pared Oeste."""
    if wall_type == "wall_n":
        pts = [
            (cx - w, cy - h - w // 2),
            (cx + w, cy - h + w // 2),
            (cx + w, cy + w // 2),
            (cx - w, cy - w // 2)
        ]
    else: # wall_w
        pts = [
            (cx - w, cy - h + w // 2),
            (cx + w, cy - h - w // 2),
            (cx + w, cy - w // 2),
            (cx - w, cy + w // 2)
        ]
    d.polygon(pts, fill=fill, outline=outline)
    return pts


# =============================================================
# GENERACIÓN DE MUEBLES DETALLADOS EN 4 ROTACIONES
# =============================================================

def generate_furniture(item_id, rot=0, scale_mode="64"):
    if str(scale_mode) == "128":
        s = 2.0
    elif str(scale_mode) == "32":
        s = 0.5
    else:
        s = 1.0

    w64, h64 = int(64 * s), int(64 * s)
    rot = int(rot) % 4

    # ---------------------------------------------------------
    # 📦 PARALELEPÍPEDOS DE DELIMITACIÓN Y GUÍA ISOMÉTRICA (1x1, 1x2, 2x1, 2x2)
    # ---------------------------------------------------------
    if item_id == "cube_1x1":
        # Huella 1x1: 1 baldosa exacta (Rombo 64x32 en base, altura H=32px)
        w, h = (int(64 * s), int(64 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        # Vértices Top (Tapa superior a Y-32)
        p_top_n = (int(32 * s), 0)
        p_top_e = (int(63 * s), int(16 * s))
        p_top_s = (int(32 * s), int(32 * s))
        p_top_w = (0, int(16 * s))

        # Vértices Base (Apoyo en baldosa)
        p_bot_s = (int(32 * s), int(63 * s))
        p_bot_w = (0, int(47 * s))
        p_bot_e = (int(63 * s), int(47 * s))

        # Cara Izquierda
        d.polygon([p_top_w, p_top_s, p_bot_s, p_bot_w], fill=(14, 116, 144, 210), outline=(186, 230, 253, 255))
        # Cara Derecha
        d.polygon([p_top_s, p_top_e, p_bot_e, p_bot_s], fill=(3, 105, 161, 210), outline=(186, 230, 253, 255))
        # Tapa Superior
        d.polygon([p_top_n, p_top_e, p_top_s, p_top_w], fill=(56, 189, 248, 220), outline=(255, 255, 255, 255))

        # Vértices destacados (Puntos de referencia)
        for pt in [p_top_n, p_top_e, p_top_s, p_top_w, p_bot_s, p_bot_w, p_bot_e]:
            d.rectangle([pt[0] - 1, pt[1] - 1, pt[0] + 1, pt[1] + 1], fill=(255, 255, 255, 255))

        return img, {"id": item_id, "name": "Paralelepípedo 1x1", "zone": "guide", "footprint": "1x1", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": int(32*s)}

    elif item_id == "cube_1x2":
        # Huella 1x2: 2 baldosas a lo largo de Y (Abajo-Izquierda). Canvas 96x72, Offset (-64, -36)
        is_x = (rot in (1, 3))
        footprint = "2x1" if is_x else "1x2"
        w, h = (int(96 * s), int(72 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        if not is_x: # 1x2 (Alargado en Y)
            offset = [-int(64*s), -int(36*s)]
            # Vértices Top (H=20px)
            t_n = (int(64 * s), 0)
            t_e = (int(95 * s), int(16 * s))
            t_s = (int(32 * s), int(48 * s))
            t_w = (0, int(32 * s))

            # Vértices Base
            b_w = (0, int(52 * s))
            b_s = (int(32 * s), int(68 * s))
            b_e = (int(95 * s), int(36 * s))

            # Cara Izquierda
            d.polygon([t_w, t_s, b_s, b_w], fill=(126, 34, 206, 210), outline=(233, 213, 255, 255))
            # Cara Derecha
            d.polygon([t_s, t_e, b_e, b_s], fill=(88, 28, 135, 210), outline=(233, 213, 255, 255))
            # Tapa Superior
            d.polygon([t_n, t_e, t_s, t_w], fill=(168, 85, 247, 220), outline=(255, 255, 255, 255))

            # Línea divisoria de las 2 baldosas en la tapa superior
            d.line([(int(32 * s), int(16 * s)), (int(64 * s), int(32 * s))], fill=(255, 255, 255, 255), width=2)
            d.line([(int(64 * s), int(32 * s)), (int(64 * s), int(52 * s))], fill=(255, 255, 255, 180), width=1)

            for pt in [t_n, t_e, t_s, t_w, b_w, b_s, b_e, (int(32 * s), int(16 * s)), (int(64 * s), int(32 * s))]:
                d.rectangle([pt[0] - 1, pt[1] - 1, pt[0] + 1, pt[1] + 1], fill=(255, 255, 255, 255))
        else: # 2x1 (Alargado en X)
            offset = [-int(32*s), -int(36*s)]
            t_n = (int(32 * s), 0)
            t_e = (int(95 * s), int(32 * s))
            t_s = (int(64 * s), int(48 * s))
            t_w = (0, int(16 * s))

            b_w = (0, int(36 * s))
            b_s = (int(64 * s), int(68 * s))
            b_e = (int(95 * s), int(52 * s))

            d.polygon([t_w, t_s, b_s, b_w], fill=(126, 34, 206, 210), outline=(233, 213, 255, 255))
            d.polygon([t_s, t_e, b_e, b_s], fill=(88, 28, 135, 210), outline=(233, 213, 255, 255))
            d.polygon([t_n, t_e, t_s, t_w], fill=(168, 85, 247, 220), outline=(255, 255, 255, 255))

            d.line([(int(64 * s), int(16 * s)), (int(32 * s), int(32 * s))], fill=(255, 255, 255, 255), width=2)
            d.line([(int(32 * s), int(32 * s)), (int(32 * s), int(52 * s))], fill=(255, 255, 255, 180), width=1)

            for pt in [t_n, t_e, t_s, t_w, b_w, b_s, b_e, (int(64 * s), int(16 * s)), (int(32 * s), int(32 * s))]:
                d.rectangle([pt[0] - 1, pt[1] - 1, pt[0] + 1, pt[1] + 1], fill=(255, 255, 255, 255))

        return img, {"id": item_id, "name": f"Paralelepípedo {footprint}", "zone": "guide", "footprint": footprint, "rot": rot, "canvas_size": [w, h], "sprite_offset": offset, "surface_height": int(20*s)}

    elif item_id == "cube_2x1":
        # Huella 2x1: 2 baldosas a lo largo de X (Abajo-Derecha). Canvas 96x72, Offset (-32, -36)
        is_x = (rot in (0, 2))
        footprint = "2x1" if is_x else "1x2"
        w, h = (int(96 * s), int(72 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        if is_x: # 2x1
            offset = [-int(32*s), -int(36*s)]
            t_n = (int(32 * s), 0)
            t_e = (int(95 * s), int(32 * s))
            t_s = (int(64 * s), int(48 * s))
            t_w = (0, int(16 * s))

            b_w = (0, int(36 * s))
            b_s = (int(64 * s), int(68 * s))
            b_e = (int(95 * s), int(52 * s))

            d.polygon([t_w, t_s, b_s, b_w], fill=(21, 128, 61, 210), outline=(187, 247, 208, 255))
            d.polygon([t_s, t_e, b_e, b_s], fill=(22, 101, 52, 210), outline=(187, 247, 208, 255))
            d.polygon([t_n, t_e, t_s, t_w], fill=(34, 197, 94, 220), outline=(255, 255, 255, 255))

            d.line([(int(64 * s), int(16 * s)), (int(32 * s), int(32 * s))], fill=(255, 255, 255, 255), width=2)
            d.line([(int(32 * s), int(32 * s)), (int(32 * s), int(52 * s))], fill=(255, 255, 255, 180), width=1)

            for pt in [t_n, t_e, t_s, t_w, b_w, b_s, b_e, (int(64 * s), int(16 * s)), (int(32 * s), int(32 * s))]:
                d.rectangle([pt[0] - 1, pt[1] - 1, pt[0] + 1, pt[1] + 1], fill=(255, 255, 255, 255))
        else: # 1x2
            offset = [-int(64*s), -int(36*s)]
            t_n = (int(64 * s), 0)
            t_e = (int(95 * s), int(16 * s))
            t_s = (int(32 * s), int(48 * s))
            t_w = (0, int(32 * s))

            b_w = (0, int(52 * s))
            b_s = (int(32 * s), int(68 * s))
            b_e = (int(95 * s), int(36 * s))

            d.polygon([t_w, t_s, b_s, b_w], fill=(21, 128, 61, 210), outline=(187, 247, 208, 255))
            d.polygon([t_s, t_e, b_e, b_s], fill=(22, 101, 52, 210), outline=(187, 247, 208, 255))
            d.polygon([t_n, t_e, t_s, t_w], fill=(34, 197, 94, 220), outline=(255, 255, 255, 255))

            d.line([(int(32 * s), int(16 * s)), (int(64 * s), int(32 * s))], fill=(255, 255, 255, 255), width=2)
            d.line([(int(64 * s), int(32 * s)), (int(64 * s), int(52 * s))], fill=(255, 255, 255, 180), width=1)

            for pt in [t_n, t_e, t_s, t_w, b_w, b_s, b_e, (int(32 * s), int(16 * s)), (int(64 * s), int(32 * s))]:
                d.rectangle([pt[0] - 1, pt[1] - 1, pt[0] + 1, pt[1] + 1], fill=(255, 255, 255, 255))

        return img, {"id": item_id, "name": f"Paralelepípedo {footprint}", "zone": "guide", "footprint": footprint, "rot": rot, "canvas_size": [w, h], "sprite_offset": offset, "surface_height": int(20*s)}

    elif item_id == "cube_2x2":
        # Huella 2x2: 4 baldosas exactas. Canvas 128x96, Offset (-64, -44)
        w, h = (int(128 * s), int(96 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        # Vértices Top (H=28px)
        t_n = (int(64 * s), 0)
        t_e = (int(127 * s), int(32 * s))
        t_s = (int(64 * s), int(64 * s))
        t_w = (0, int(32 * s))

        # Vértices Base
        b_w = (0, int(60 * s))
        b_s = (int(64 * s), int(92 * s))
        b_e = (int(127 * s), int(60 * s))

        # Caras Laterales
        d.polygon([t_w, t_s, b_s, b_w], fill=(161, 98, 7, 210), outline=(254, 240, 138, 255))
        d.polygon([t_s, t_e, b_e, b_s], fill=(113, 63, 18, 210), outline=(254, 240, 138, 255))
        # Tapa Superior
        d.polygon([t_n, t_e, t_s, t_w], fill=(234, 179, 8, 220), outline=(255, 255, 255, 255))

        # Cruz divisoria de las 4 baldosas en la tapa superior
        d.line([(int(32 * s), int(16 * s)), (int(96 * s), int(48 * s))], fill=(255, 255, 255, 255), width=2)
        d.line([(int(96 * s), int(16 * s)), (int(32 * s), int(48 * s))], fill=(255, 255, 255, 255), width=2)

        # Líneas divisorias en las caras verticales
        d.line([(int(32 * s), int(48 * s)), (int(32 * s), int(76 * s))], fill=(255, 255, 255, 180), width=1)
        d.line([(int(96 * s), int(48 * s)), (int(96 * s), int(76 * s))], fill=(255, 255, 255, 180), width=1)

        # Puntos de vértice de referencia
        for pt in [t_n, t_e, t_s, t_w, b_w, b_s, b_e, (int(64 * s), int(32 * s)), (int(32 * s), int(16 * s)), (int(96 * s), int(16 * s)), (int(32 * s), int(48 * s)), (int(96 * s), int(48 * s))]:
            d.rectangle([pt[0] - 1, pt[1] - 1, pt[0] + 1, pt[1] + 1], fill=(255, 255, 255, 255))

        return img, {"id": item_id, "name": "Paralelepípedo 2x2", "zone": "guide", "footprint": "2x2", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-int(64*s), -int(44*s)], "surface_height": int(28*s)}

    # ---------------------------------------------------------
    # 🪑 SILLAS & SILLONES CAPITONÉ (1x1)
    # ---------------------------------------------------------
    if item_id == "wooden_chair":
        w, h = w64, h64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.72)

        # 4 Patas torneadas con remates
        for px, py in [(-12*s, -4*s), (12*s, -4*s), (-8*s, 8*s), (8*s, 8*s)]:
            d.rectangle([cx + px - 1, cy + py, cx + px + 1, cy + py + int(14*s)], fill=WOOD_SHD, outline=OUTLINE)
            d.point([(cx + px, cy + py + int(13*s))], fill=GOLD_LGT)

        # Asiento con cojín biselado
        draw_iso_box(d, cx, cy, int(15*s), int(15*s), int(4*s), WOOD_LIGHT, WOOD_MID, WOOD_SHD)
        d.polygon([(cx - int(10*s), cy - int(4*s)), (cx + int(4*s), cy + int(2*s)), (cx - int(2*s), cy + int(4*s)), (cx - int(12*s), cy)], fill=WOOD_HL)

        # Respaldo con barrotes detallados
        if rot == 0:
            d.rectangle([cx - int(12*s), cy - int(26*s), cx - int(9*s), cy - int(4*s)], fill=WOOD_MID, outline=OUTLINE)
            d.rectangle([cx + int(9*s), cy - int(26*s), cx + int(12*s), cy - int(4*s)], fill=WOOD_MID, outline=OUTLINE)
            d.rectangle([cx - int(3*s), cy - int(24*s), cx - int(1*s), cy - int(4*s)], fill=WOOD_SHD)
            d.rectangle([cx + int(1*s), cy - int(24*s), cx + int(3*s), cy - int(4*s)], fill=WOOD_SHD)
            d.polygon([(cx - int(13*s), cy - int(26*s)), (cx + int(13*s), cy - int(26*s)), (cx + int(12*s), cy - int(20*s)), (cx - int(12*s), cy - int(20*s))], fill=WOOD_LIGHT, outline=OUTLINE)
        elif rot == 1:
            d.rectangle([cx - int(12*s), cy - int(26*s), cx - int(9*s), cy - int(4*s)], fill=WOOD_MID, outline=OUTLINE)
            d.rectangle([cx + int(9*s), cy - int(26*s), cx + int(12*s), cy - int(4*s)], fill=WOOD_MID, outline=OUTLINE)
            d.polygon([(cx - int(13*s), cy - int(26*s)), (cx + int(13*s), cy - int(26*s)), (cx + int(12*s), cy - int(20*s)), (cx - int(12*s), cy - int(20*s))], fill=WOOD_LIGHT, outline=OUTLINE)
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        elif rot == 2:
            d.rectangle([cx - int(12*s), cy - int(16*s), cx + int(6*s), cy + int(4*s)], fill=WOOD_MID, outline=OUTLINE)
            d.line([(cx - int(4*s), cy - int(14*s)), (cx - int(4*s), cy + int(2*s))], fill=WOOD_DEEP)
        else:
            d.rectangle([cx - int(6*s), cy - int(16*s), cx + int(12*s), cy + int(4*s)], fill=WOOD_MID, outline=OUTLINE)

        return img, {"id": item_id, "name": "Silla de Madera Torneada", "zone": "living", "footprint": "1x1", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": int(14*s)}

    elif item_id == "plush_armchair":
        w, h = w64, h64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.72)

        # Base acolchada
        draw_iso_box(d, cx, cy, int(18*s), int(18*s), int(14*s), FABRIC_RED_LGT, FABRIC_RED_MID, FABRIC_RED_SHD)

        if rot in (0, 1):
            # Respaldo capitoné con botones dorados
            d.rectangle([cx - int(16*s), cy - int(26*s), cx + int(16*s), cy - int(10*s)], fill=FABRIC_RED_MID, outline=OUTLINE)
            d.polygon([(cx - int(16*s), cy - int(26*s)), (cx + int(16*s), cy - int(26*s)), (cx + int(14*s), cy - int(20*s)), (cx - int(14*s), cy - int(20*s))], fill=FABRIC_RED_LGT)
            # Botones capitoné
            for bx, by in [(-8*s, -20*s), (0, -22*s), (8*s, -20*s), (-4*s, -15*s), (4*s, -15*s)]:
                d.point([(cx + int(bx), cy + int(by))], fill=GOLD_LGT)
            # Brazos redondeados
            d.ellipse([cx - int(18*s), cy - int(12*s), cx - int(12*s), cy + int(2*s)], fill=FABRIC_RED_LGT, outline=OUTLINE)
            d.ellipse([cx + int(12*s), cy - int(12*s), cx + int(18*s), cy + int(2*s)], fill=FABRIC_RED_LGT, outline=OUTLINE)
            if rot == 1:
                img = img.transpose(Image.FLIP_LEFT_RIGHT)
        else:
            # Respaldo trasero con pliegues
            d.rectangle([cx - int(16*s), cy - int(20*s), cx + int(16*s), cy + int(2*s)], fill=FABRIC_RED_SHD, outline=OUTLINE)
            d.line([(cx, cy - int(18*s)), (cx, cy)], fill=OUTLINE)

        return img, {"id": item_id, "name": "Sillón Orejero Capitoné", "zone": "living", "footprint": "1x1", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": int(16*s)}

    # ---------------------------------------------------------
    # 🛏️ CAMA INDIVIDUAL Y CAMA KING MATRIMONIAL
    # ---------------------------------------------------------
    elif item_id == "single_bed":
        is_x = (rot in (1, 3))
        footprint = "2x1" if is_x else "1x2"
        w, h = (int(96 * s), int(72 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        if not is_x: # 1x2
            cx, cy = int(64 * s), int(36 * s)
            offset = [-int(64*s), -int(36*s)]
            # Cabecero de madera noble
            d.polygon([(cx - int(16*s), cy - int(26*s)), (cx + int(16*s), cy - int(10*s)), (cx + int(16*s), cy), (cx - int(16*s), cy - int(16*s))], fill=WOOD_MID, outline=OUTLINE)
            d.line([(cx - int(14*s), cy - int(24*s)), (cx + int(14*s), cy - int(10*s))], fill=WOOD_HL)
            # Colchón
            draw_iso_box(d, cx - int(16*s), cy + int(8*s), int(22*s), int(34*s), int(12*s), WHITE_LGT, WHITE_MID, WHITE_SHD)
            # Almohada mullida
            d.polygon([(cx - int(14*s), cy - int(10*s)), (cx + int(6*s), cy), (cx - int(2*s), cy + int(4*s)), (cx - int(22*s), cy - int(6*s))], fill=WHITE_HL, outline=OUTLINE)
            d.point([(cx - int(8*s), cy - int(3*s))], fill=WHITE_SHD)
            # Edredón con pliegues y embozo
            d.polygon([(cx - int(32*s), cy), (cx + int(4*s), cy + int(18*s)), (cx - int(6*s), cy + int(24*s)), (cx - int(42*s), cy + int(6*s))], fill=FABRIC_BLUE_MID, outline=OUTLINE)
            d.line([(cx - int(32*s), cy), (cx + int(4*s), cy + int(18*s))], fill=WHITE_HL, width=2)
            d.line([(cx - int(24*s), cy + int(8*s)), (cx - int(10*s), cy + int(16*s))], fill=FABRIC_BLUE_LGT)
        else: # 2x1
            cx, cy = int(32 * s), int(36 * s)
            offset = [-int(32*s), -int(36*s)]
            d.polygon([(cx - int(8*s), cy - int(26*s)), (cx + int(24*s), cy - int(10*s)), (cx + int(24*s), cy), (cx - int(8*s), cy - int(16*s))], fill=WOOD_MID, outline=OUTLINE)
            draw_iso_box(d, cx + int(16*s), cy + int(8*s), int(34*s), int(22*s), int(12*s), WHITE_LGT, WHITE_MID, WHITE_SHD)
            d.polygon([(cx + int(10*s), cy - int(10*s)), (cx + int(30*s), cy), (cx + int(22*s), cy + int(4*s)), (cx + int(2*s), cy - int(6*s))], fill=WHITE_HL, outline=OUTLINE)
            d.polygon([(cx - int(10*s), cy), (cx + int(26*s), cy + int(18*s)), (cx + int(16*s), cy + int(24*s)), (cx - int(20*s), cy + int(6*s))], fill=FABRIC_BLUE_MID, outline=OUTLINE)
            d.line([(cx - int(10*s), cy), (cx + int(26*s), cy + int(18*s))], fill=WHITE_HL, width=2)

        return img, {"id": item_id, "name": f"Cama Individual ({footprint})", "zone": "bedroom", "footprint": footprint, "rot": rot, "canvas_size": [w, h], "sprite_offset": offset, "surface_height": int(14*s)}

    elif item_id == "king_bed":
        w, h = (int(128 * s), int(96 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = int(64 * s), int(44 * s)

        # Gran Cabecero con pilastras torneadas
        d.polygon([(cx - int(26*s), cy - int(26*s)), (cx + int(34*s), cy + int(4*s)), (cx + int(34*s), cy + int(16*s)), (cx - int(26*s), cy - int(14*s))], fill=WOOD_SHD, outline=OUTLINE)
        # Remates dorados de las pilastras
        d.ellipse([cx - int(28*s), cy - int(30*s), cx - int(22*s), cy - int(24*s)], fill=GOLD_LGT, outline=OUTLINE)
        d.ellipse([cx + int(30*s), cy - int(2*s), cx + int(36*s), cy + int(4*s)], fill=GOLD_LGT, outline=OUTLINE)

        # Colchón King 2x2
        draw_iso_box(d, cx, cy + int(16*s), int(36*s), int(36*s), int(14*s), WHITE_LGT, WHITE_MID, WHITE_SHD)

        # 2 Almohadas con relieve y sombra
        d.polygon([(cx - int(18*s), cy - int(8*s)), (cx, cy + int(2*s)), (cx - int(8*s), cy + int(6*s)), (cx - int(26*s), cy - int(4*s))], fill=WHITE_HL, outline=OUTLINE)
        d.polygon([(cx + int(2*s), cy + int(2*s)), (cx + int(20*s), cy + int(12*s)), (cx + int(12*s), cy + int(16*s)), (cx - int(6*s), cy + int(6*s))], fill=WHITE_HL, outline=OUTLINE)
        d.point([(cx - int(12*s), cy - int(2*s))], fill=WHITE_SHD)
        d.point([(cx + int(8*s), cy + int(8*s))], fill=WHITE_SHD)

        # Edredón Borgoña con guarda dorada
        d.polygon([(cx - int(32*s), cy + int(12*s)), (cx + int(16*s), cy + int(36*s)), (cx + int(2*s), cy + int(44*s)), (cx - int(46*s), cy + int(20*s))], fill=FABRIC_RED_MID, outline=OUTLINE)
        # Embozo blanco y guarda
        d.line([(cx - int(32*s), cy + int(12*s)), (cx + int(16*s), cy + int(36*s))], fill=WHITE_HL, width=2)
        d.line([(cx - int(30*s), cy + int(16*s)), (cx + int(14*s), cy + int(40*s))], fill=GOLD_LGT, width=1)

        return img, {"id": item_id, "name": "Cama King Matrimonial (2x2)", "zone": "bedroom", "footprint": "2x2", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-int(64*s), -int(44*s)], "surface_height": int(16*s)}

    # ---------------------------------------------------------
    # 🍳 COCINA DE ALTO DETALLE (Nevera, Estufa, Fregadero)
    # ---------------------------------------------------------
    elif item_id == "kitchen_fridge":
        w, h = (int(64 * s), int(80 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.78)

        # Cuerpo metálico con degradado
        draw_iso_box(d, cx, cy, int(18 * s), int(18 * s), int(42 * s), METAL_LGT, METAL_MID, METAL_SHD)
        # Reflejo especular en el lateral
        d.line([(cx - int(16*s), cy - int(38*s)), (cx - int(16*s), cy - int(2*s))], fill=METAL_HL)

        # División Congelador / Nevera
        d.line([(cx - int(18*s), cy - int(24*s)), (cx, cy - int(15*s))], fill=OUTLINE, width=2)
        # Manillas plateadas con relieve
        d.rectangle([cx - int(14*s), cy - int(34*s), cx - int(12*s), cy - int(26*s)], fill=GOLD_LGT, outline=OUTLINE)
        d.rectangle([cx - int(14*s), cy - int(20*s), cx - int(12*s), cy - int(8*s)], fill=GOLD_LGT, outline=OUTLINE)
        # Notas adhesivas magnéticas en la puerta
        d.rectangle([cx - int(8*s), cy - int(32*s), cx - int(4*s), cy - int(28*s)], fill=FABRIC_GOLD_LGT)
        d.rectangle([cx - int(7*s), cy - int(18*s), cx - int(3*s), cy - int(14*s)], fill=FABRIC_BLUE_LGT)

        if rot == 1:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

        return img, {"id": item_id, "name": "Refrigerador Inox Detallado", "zone": "kitchen", "footprint": "1x1", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": 0}

    elif item_id == "kitchen_stove":
        w, h = w64, h64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.75)

        draw_iso_box(d, cx, cy, int(18 * s), int(18 * s), int(22 * s), METAL_LGT, METAL_MID, METAL_SHD)

        # 4 Fogones con quemadores incandescentes
        fogones = [(-8*s, -26*s), (4*s, -20*s), (-2*s, -30*s), (-2*s, -16*s)]
        for fx, fy in fogones:
            d.ellipse([cx + fx - int(4*s), cy + fy - int(2*s), cx + fx + int(4*s), cy + fy + int(2*s)], fill=(35, 35, 40, 255), outline=OUTLINE)
            d.ellipse([cx + fx - int(2*s), cy + fy - int(1*s), cx + fx + int(2*s), cy + fy + int(1*s)], fill=(235, 80, 40, 255)) # Brasa viva

        # Puerta del horno de cristal templado con rejilla interior
        d.rectangle([cx - int(15*s), cy - int(16*s), cx - int(3*s), cy - int(4*s)], fill=(30, 30, 35, 255), outline=OUTLINE)
        d.rectangle([cx - int(13*s), cy - int(14*s), cx - int(5*s), cy - int(6*s)], fill=(60, 65, 75, 255))
        d.line([(cx - int(12*s), cy - int(10*s)), (cx - int(6*s), cy - int(10*s))], fill=METAL_LGT) # Rejilla
        d.line([(cx - int(14*s), cy - int(17*s)), (cx - int(4*s), cy - int(17*s))], fill=GOLD_LGT, width=2) # Tirador horno

        # Perillas de control
        for kx in range(4):
            d.point([(cx - int(14*s) + int(kx * 3.5 * s), cy - int(19*s))], fill=WHITE_HL)

        if rot == 1:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

        return img, {"id": item_id, "name": "Cocina Profesional con Fogones", "zone": "kitchen", "footprint": "1x1", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": int(22*s)}

    elif item_id == "kitchen_sink":
        w, h = w64, h64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.75)

        # Mueble bajo con encimera de cuarzo
        draw_iso_box(d, cx, cy, int(18 * s), int(18 * s), int(20 * s), WHITE_LGT, WOOD_MID, WOOD_SHD)
        # Cubeta doble de acero inox con agua brillante
        d.polygon([(cx - int(12*s), cy - int(22*s)), (cx + int(4*s), cy - int(14*s)), (cx - int(2*s), cy - int(11*s)), (cx - int(18*s), cy - int(19*s))], fill=METAL_SHD, outline=OUTLINE)
        d.polygon([(cx - int(11*s), cy - int(21*s)), (cx + int(3*s), cy - int(14*s)), (cx - int(2*s), cy - int(12*s)), (cx - int(16*s), cy - int(19*s))], fill=GLASS_MID)
        # Grifo de caño alto con monomando
        d.line([(cx - int(4*s), cy - int(28*s)), (cx - int(4*s), cy - int(20*s))], fill=METAL_LGT, width=2)
        d.line([(cx - int(4*s), cy - int(28*s)), (cx - int(8*s), cy - int(26*s))], fill=METAL_LGT, width=2)
        d.point([(cx - int(4*s), cy - int(29*s))], fill=WHITE_HL)
        # Pastilla de jabón en jabonera
        d.rectangle([cx + int(6*s), cy - int(18*s), cx + int(10*s), cy - int(15*s)], fill=FABRIC_TEAL_LGT)

        if rot == 1:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

        return img, {"id": item_id, "name": "Fregadero con Encimera", "zone": "kitchen", "footprint": "1x1", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": int(20*s)}

    # ---------------------------------------------------------
    # 🚿 BAÑO DE LUJO (Bañera con patas de león, WC, Lavabo)
    # ---------------------------------------------------------
    elif item_id == "bathtub_1x2":
        is_x = (rot in (1, 3))
        footprint = "2x1" if is_x else "1x2"
        w, h = (int(96 * s), int(72 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        if not is_x:
            cx, cy = int(64 * s), int(36 * s)
            offset = [-int(64*s), -int(36*s)]
            # 4 Patas de garra de león doradas
            for px, py in [(-36*s, 6*s), (0, 24*s), (14*s, 16*s), (-22*s, -2*s)]:
                d.ellipse([cx + px - int(2*s), cy + py, cx + px + int(2*s), cy + py + int(4*s)], fill=GOLD_MID, outline=OUTLINE)
            # Bañera esmaltada
            draw_iso_box(d, cx - int(16*s), cy + int(8*s), int(22*s), int(36*s), int(16*s), WHITE_LGT, WHITE_MID, WHITE_SHD)
            # Interior con agua cristalina y espuma
            d.polygon([(cx - int(28*s), cy), (cx + int(2*s), cy + int(15*s)), (cx - int(8*s), cy + int(20*s)), (cx - int(38*s), cy + int(5*s))], fill=GLASS_MID)
            # Burbujas de espuma blanca
            d.ellipse([cx - int(26*s), cy + int(1*s), cx - int(20*s), cy + int(4*s)], fill=WHITE_HL)
            d.ellipse([cx - int(14*s), cy + int(12*s), cx - int(8*s), cy + int(16*s)], fill=WHITE_HL)
            # Grifería victoriana dorada
            d.line([(cx - int(2*s), cy - int(12*s)), (cx - int(2*s), cy - int(2*s))], fill=GOLD_LGT, width=2)
            d.line([(cx - int(5*s), cy - int(10*s)), (cx + int(1*s), cy - int(10*s))], fill=GOLD_LGT, width=2)
        else:
            cx, cy = int(32 * s), int(36 * s)
            offset = [-int(32*s), -int(36*s)]
            for px, py in [(-18*s, 8*s), (20*s, 24*s), (32*s, 14*s), (-6*s, -2*s)]:
                d.ellipse([cx + px - int(2*s), cy + py, cx + px + int(2*s), cy + py + int(4*s)], fill=GOLD_MID, outline=OUTLINE)
            draw_iso_box(d, cx + int(16*s), cy + int(8*s), int(36*s), int(22*s), int(16*s), WHITE_LGT, WHITE_MID, WHITE_SHD)
            d.polygon([(cx - int(10*s), cy), (cx + int(30*s), cy + int(12*s)), (cx + int(20*s), cy + int(18*s)), (cx - int(20*s), cy + int(6*s))], fill=GLASS_MID)
            d.ellipse([cx + int(8*s), cy + int(4*s), cx + int(16*s), cy + int(8*s)], fill=WHITE_HL)
            d.line([(cx + int(24*s), cy - int(12*s)), (cx + int(24*s), cy - int(2*s))], fill=GOLD_LGT, width=2)

        return img, {"id": item_id, "name": f"Bañera Victoriana ({footprint})", "zone": "bathroom", "footprint": footprint, "rot": rot, "canvas_size": [w, h], "sprite_offset": offset, "surface_height": 0}

    elif item_id == "bathroom_toilet":
        w, h = w64, h64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.75)

        # Cisterna con tapa biselada
        draw_iso_box(d, cx + int(4*s), cy - int(12*s), int(10*s), int(14*s), int(22*s), WHITE_LGT, WHITE_MID, WHITE_SHD)
        # Palanca de descarga cromada
        d.line([(cx + int(14*s), cy - int(28*s)), (cx + int(18*s), cy - int(26*s))], fill=METAL_HL, width=2)

        # Taza y tapa del asiento
        draw_iso_box(d, cx - int(4*s), cy + int(4*s), int(14*s), int(14*s), int(12*s), WHITE_LGT, WHITE_MID, WHITE_SHD)
        d.ellipse([cx - int(10*s), cy - int(10*s), cx + int(4*s), cy - int(2*s)], fill=WHITE_HL, outline=OUTLINE)
        d.ellipse([cx - int(8*s), cy - int(8*s), cx + int(2*s), cy - int(4*s)], fill=GLASS_MID)

        if rot == 1:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)

        return img, {"id": item_id, "name": "Inodoro Cerámico", "zone": "bathroom", "footprint": "1x1", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": 0}

    # ---------------------------------------------------------
    # 🌳 PATIO & JARDÍN (Fuente de piedra, BBQ, Jardinera)
    # ---------------------------------------------------------
    elif item_id == "stone_fountain":
        w, h = (int(128 * s), int(96 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = int(64 * s), int(44 * s)

        # Gran pilón octogonal de piedra tallada
        draw_iso_box(d, cx, cy + int(14*s), int(38*s), int(38*s), int(12*s), STONE_LGT, STONE_MID, STONE_SHD)
        # Borde biselado
        d.polygon([(cx, cy - int(14*s)), (cx + int(36*s), cy + int(4*s)), (cx, cy + int(22*s)), (cx - int(36*s), cy + int(4*s))], outline=STONE_HL)

        # Agua con ondas concéntricas de colores
        d.polygon([(cx, cy - int(10*s)), (cx + int(30*s), cy + int(6*s)), (cx, cy + int(22*s)), (cx - int(30*s), cy + int(6*s))], fill=GLASS_MID)
        d.ellipse([cx - int(18*s), cy + int(2*s), cx + int(18*s), cy + int(14*s)], outline=GLASS_HL)

        # Columna central y plato superior con gárgola
        draw_iso_box(d, cx, cy - int(2*s), int(12*s), int(12*s), int(18*s), STONE_LGT, STONE_MID, STONE_SHD)
        d.ellipse([cx - int(14*s), cy - int(24*s), cx + int(14*s), cy - int(16*s)], fill=STONE_LGT, outline=OUTLINE)
        d.ellipse([cx - int(10*s), cy - int(23*s), cx + int(10*s), cy - int(17*s)], fill=GLASS_LGT)

        # Chorro de agua central y gotas
        d.line([(cx, cy - int(34*s)), (cx, cy - int(22*s))], fill=GLASS_HL, width=2)
        d.point([(cx - int(3*s), cy - int(28*s)), (cx + int(3*s), cy - int(28*s))], fill=WHITE_HL)

        # Manchas de musgo en la base
        d.point([(cx - int(24*s), cy + int(18*s)), (cx - int(20*s), cy + int(20*s)), (cx + int(22*s), cy + int(16*s))], fill=PLANT_MID)

        return img, {"id": item_id, "name": "Fuente de Piedra Monumental (2x2)", "zone": "patio", "footprint": "2x2", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-int(64*s), -int(44*s)], "surface_height": 0}

    elif item_id == "bbq_grill":
        w, h = w64, h64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.75)

        # Patas tubulares con ruedas
        d.line([(cx, cy - int(10*s)), (cx - int(10*s), cy + int(8*s))], fill=METAL_SHD, width=2)
        d.line([(cx, cy - int(10*s)), (cx + int(10*s), cy + int(8*s))], fill=METAL_SHD, width=2)
        d.line([(cx, cy - int(10*s)), (cx, cy + int(10*s))], fill=METAL_SHD, width=2)
        d.ellipse([cx - int(12*s), cy + int(7*s), cx - int(8*s), cy + int(11*s)], fill=(30, 30, 30, 255))
        d.ellipse([cx + int(8*s), cy + int(7*s), cx + int(12*s), cy + int(11*s)], fill=(30, 30, 30, 255))

        # Caldera esmaltada roja/negra con brasa y parrilla
        d.ellipse([cx - int(14*s), cy - int(24*s), cx + int(14*s), cy - int(8*s)], fill=FABRIC_RED_MID, outline=OUTLINE)
        d.ellipse([cx - int(11*s), cy - int(20*s), cx + int(11*s), cy - int(12*s)], fill=(30, 30, 35, 255))
        d.ellipse([cx - int(8*s), cy - int(18*s), cx + int(8*s), cy - int(14*s)], fill=(235, 75, 30, 255))

        # Varillas de la parrilla
        for gx in range(-6, 7, 3):
            d.line([(cx + int(gx * s), cy - int(19*s)), (cx + int(gx * s), cy - int(13*s))], fill=METAL_HL)

        # Pinzas de asado colgantes
        d.line([(cx + int(14*s), cy - int(16*s)), (cx + int(16*s), cy - int(6*s))], fill=METAL_HL, width=1)

        return img, {"id": item_id, "name": "Barbacoa BBQ con Brasas", "zone": "patio", "footprint": "1x1", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": int(16*s)}

    # ---------------------------------------------------------
    # 🍵 OBJETOS DE SOBREMESA DE ALTO DETALLE
    # ---------------------------------------------------------
    elif item_id == "table_lamp":
        w, h = (int(32 * s), int(32 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.8)

        # Base de bronce torneada
        d.ellipse([cx - int(4*s), cy - int(2*s), cx + int(4*s), cy], fill=GOLD_MID, outline=OUTLINE)
        d.rectangle([cx - 1, cy - int(10*s), cx + 1, cy - int(2*s)], fill=GOLD_LGT)
        # Pantalla plisada color crema con flecos
        d.polygon([(cx - int(7*s), cy - int(10*s)), (cx + int(7*s), cy - int(10*s)), (cx + int(4*s), cy - int(18*s)), (cx - int(4*s), cy - int(18*s))], fill=(255, 248, 200, 255), outline=OUTLINE)
        d.line([(cx - int(7*s), cy - int(10*s)), (cx + int(7*s), cy - int(10*s))], fill=GOLD_MID)
        # Pliegues de luz
        d.line([(cx - int(2*s), cy - int(18*s)), (cx - int(3*s), cy - int(10*s))], fill=WHITE_HL)
        d.line([(cx + int(2*s), cy - int(18*s)), (cx + int(3*s), cy - int(10*s))], fill=WHITE_HL)

        return img, {"id": item_id, "name": "Lámpara de Noche Plisada", "zone": "decor", "footprint": "surface", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -h], "surface_height": 0}

    elif item_id == "coffee_mug":
        w, h = (int(32 * s), int(32 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.8)

        # Taza de cerámica esmaltada
        d.rectangle([cx - int(4*s), cy - int(7*s), cx + int(4*s), cy], fill=WHITE_LGT, outline=OUTLINE)
        d.ellipse([cx - int(4*s), cy - int(9*s), cx + int(4*s), cy - int(6*s)], fill=(85, 45, 25, 255), outline=OUTLINE)
        # Arte latte corazón
        d.point([(cx, cy - int(8*s))], fill=WHITE_HL)
        # Asa
        d.line([(cx + int(4*s), cy - int(6*s)), (cx + int(7*s), cy - int(4*s)), (cx + int(4*s), cy - int(1*s))], fill=OUTLINE, width=1)
        # Vapor aromático
        d.line([(cx - 1, cy - int(11*s)), (cx, cy - int(13*s)), (cx - 1, cy - int(16*s))], fill=(225, 225, 235, 180))

        return img, {"id": item_id, "name": "Taza de Café con Latte Art", "zone": "decor", "footprint": "surface", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -h], "surface_height": 0}

    elif item_id == "open_book":
        w, h = (int(32 * s), int(32 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.8)

        # Tapas de cuero y esquinas doradas
        d.polygon([(cx - int(9*s), cy - int(3*s)), (cx, cy + int(1*s)), (cx + int(9*s), cy - int(3*s)), (cx + int(8*s), cy + int(4*s)), (cx, cy + int(7*s)), (cx - int(8*s), cy + int(4*s))], fill=(115, 45, 25, 255), outline=OUTLINE)
        # Páginas abiertas de pergamino
        d.polygon([(cx - int(8*s), cy - int(3*s)), (cx, cy), (cx + int(8*s), cy - int(3*s)), (cx + int(7*s), cy + int(3*s)), (cx, cy + int(5*s)), (cx - int(7*s), cy + int(3*s))], fill=(250, 240, 210, 255))
        # Líneas de runas / texto mágico
        d.line([(cx - int(6*s), cy), (cx - int(2*s), cy + int(2*s))], fill=(90, 70, 60, 255))
        d.line([(cx + int(2*s), cy + int(2*s)), (cx + int(6*s), cy)], fill=(90, 70, 60, 255))
        # Cinta marcapáginas roja
        d.line([(cx, cy), (cx, cy + int(8*s))], fill=FABRIC_RED_MID, width=2)

        return img, {"id": item_id, "name": "Grimorio / Libro con Runas", "zone": "decor", "footprint": "surface", "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -h], "surface_height": 0}

    # ---------------------------------------------------------
    # 🖼️ OBJETOS Y GUÍAS DE PARED EN DIAGONAL (PARED NORTE Y OESTE)
    # ---------------------------------------------------------
    # 1. PARALELEPÍPEDOS GUÍA DE PARED
    if item_id.startswith("cube_wall_") or item_id in ("cube_wall_n", "cube_wall_w"):
        wall_dir = "wall_w" if (item_id.endswith("_w") or rot in (1, 3)) else "wall_n"
        w, h = (int(64 * s), int(80 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.6)

        # Panel guía que delimita el plano exacto de 1 baldosa de pared
        pts = draw_wall_diagonal_panel(d, cx, cy, int(24*s), int(36*s), wall_type=wall_dir, fill=(236, 72, 153, 200), outline=(251, 207, 232, 255))
        # Líneas de cuadrícula interna
        d.line([((pts[0][0] + pts[1][0])//2, (pts[0][1] + pts[1][1])//2), ((pts[3][0] + pts[2][0])//2, (pts[3][1] + pts[2][1])//2)], fill=(255, 255, 255, 200), width=1)
        d.line([((pts[0][0] + pts[3][0])//2, (pts[0][1] + pts[3][1])//2), ((pts[1][0] + pts[2][0])//2, (pts[1][1] + pts[2][1])//2)], fill=(255, 255, 255, 200), width=1)
        for pt in pts:
            d.rectangle([pt[0] - 1, pt[1] - 1, pt[0] + 1, pt[1] + 1], fill=(255, 255, 255, 255))

        return img, {"id": item_id, "name": f"Guía de Pared ({wall_dir.upper()})", "zone": "wall", "footprint": wall_dir, "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -int(48*s)], "surface_height": 0}

    # 2. VENTANA CON CORTINAS EN DIAGONAL
    elif item_id.startswith("curtained_window_"):
        wall_dir = "wall_w" if (item_id.endswith("_w") or rot in (1, 3)) else "wall_n"
        w, h = (int(64 * s), int(64 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2

        # Marco de madera exterior
        draw_wall_diagonal_panel(d, cx, cy, int(20*s), int(26*s), wall_type=wall_dir, fill=WOOD_MID, outline=WOOD_OUT)
        # Cristal con degradado de cielo y horizonte
        pts_glass = draw_wall_diagonal_panel(d, cx, cy, int(16*s), int(22*s), wall_type=wall_dir, fill=GLASS_MID, outline=OUTLINE)
        # Nube / reflejo en el cristal
        d.line([(cx - int(8*s), cy - int(4*s)), (cx + int(8*s), cy)], fill=GLASS_HL, width=2)

        # Parteluces / Cruces de la ventana
        if wall_dir == "wall_n":
            d.line([(cx, cy - int(22*s)), (cx, cy + int(22*s))], fill=WOOD_DEEP, width=2)
            d.line([(cx - int(16*s), cy - int(8*s)), (cx + int(16*s), cy + int(8*s))], fill=WOOD_DEEP, width=2)
            # Cortinas de terciopelo rojo recogidas con lazo dorado
            d.polygon([(cx - int(20*s), cy - int(34*s)), (cx - int(12*s), cy - int(30*s)), (cx - int(15*s), cy + int(4*s)), (cx - int(20*s), cy - int(6*s))], fill=FABRIC_RED_MID, outline=OUTLINE)
            d.polygon([(cx + int(20*s), cy - int(14*s)), (cx + int(12*s), cy - int(18*s)), (cx + int(15*s), cy + int(16*s)), (cx + int(20*s), cy + int(6*s))], fill=FABRIC_RED_MID, outline=OUTLINE)
            # Lazos dorados
            d.line([(cx - int(19*s), cy - int(12*s)), (cx - int(13*s), cy - int(9*s))], fill=GOLD_LGT, width=2)
            d.line([(cx + int(13*s), cy + int(1*s)), (cx + int(19*s), cy + int(4*s))], fill=GOLD_LGT, width=2)
        else: # wall_w
            d.line([(cx, cy - int(22*s)), (cx, cy + int(22*s))], fill=WOOD_DEEP, width=2)
            d.line([(cx - int(16*s), cy + int(8*s)), (cx + int(16*s), cy - int(8*s))], fill=WOOD_DEEP, width=2)
            d.polygon([(cx - int(20*s), cy - int(14*s)), (cx - int(12*s), cy - int(18*s)), (cx - int(15*s), cy + int(16*s)), (cx - int(20*s), cy + int(6*s))], fill=FABRIC_RED_MID, outline=OUTLINE)
            d.polygon([(cx + int(20*s), cy - int(34*s)), (cx + int(12*s), cy - int(30*s)), (cx + int(15*s), cy + int(4*s)), (cx + int(20*s), cy - int(6*s))], fill=FABRIC_RED_MID, outline=OUTLINE)
            d.line([(cx - int(19*s), cy + int(4*s)), (cx - int(13*s), cy + int(1*s))], fill=GOLD_LGT, width=2)
            d.line([(cx + int(13*s), cy - int(9*s)), (cx + int(19*s), cy - int(12*s))], fill=GOLD_LGT, width=2)

        return img, {"id": item_id, "name": f"Ventana con Cortinas ({wall_dir.upper()})", "zone": "wall", "footprint": wall_dir, "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -int(48*s)], "surface_height": 0}

    # 3. CUADRO ARTÍSTICO EN DIAGONAL
    elif item_id.startswith("art_painting_"):
        wall_dir = "wall_w" if (item_id.endswith("_w") or rot in (1, 3)) else "wall_n"
        w, h = (int(64 * s), int(64 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2

        # Marco dorado barroco
        draw_wall_diagonal_panel(d, cx, cy, int(16*s), int(20*s), wall_type=wall_dir, fill=GOLD_MID, outline=GOLD_DEEP)
        # Lienzo con paisaje alpino (cielo, montaña nevada, pinos)
        draw_wall_diagonal_panel(d, cx, cy, int(13*s), int(16*s), wall_type=wall_dir, fill=(70, 130, 200, 255))
        # Silueta de montaña y sol
        d.ellipse([cx - int(3*s), cy - int(8*s), cx + int(3*s), cy - int(2*s)], fill=GOLD_HL)
        draw_wall_diagonal_panel(d, cx, cy + int(6*s), int(13*s), int(6*s), wall_type=wall_dir, fill=PLANT_SHD)

        return img, {"id": item_id, "name": f"Cuadro de Paisaje ({wall_dir.upper()})", "zone": "wall", "footprint": wall_dir, "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -int(48*s)], "surface_height": 0}

    # 4. SARTENES COLGANTES DE COCINA EN PARED
    elif item_id.startswith("pan_rack_wall_"):
        wall_dir = "wall_w" if (item_id.endswith("_w") or rot in (1, 3)) else "wall_n"
        w, h = (int(64 * s), int(64 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2

        # Riel de acero inoxidable diagonal
        draw_wall_diagonal_panel(d, cx, cy, int(18*s), int(4*s), wall_type=wall_dir, fill=METAL_LGT, outline=OUTLINE)
        # Pernos de anclaje
        d.point([(cx - int(16*s), cy), (cx + int(16*s), cy)], fill=GOLD_LGT)

        # 3 Sartenes y cazos colgantes
        for ox, col in [(-10*s, (50, 50, 55, 255)), (0, (190, 95, 45, 255)), (10*s, (70, 75, 85, 255))]:
            sy_offset = int(ox * (0.5 if wall_dir == "wall_n" else -0.5))
            d.line([(cx + int(ox), cy + sy_offset + int(2*s)), (cx + int(ox), cy + sy_offset + int(8*s))], fill=METAL_LGT, width=2)
            d.ellipse([cx + int(ox) - int(5*s), cy + sy_offset + int(8*s), cx + int(ox) + int(5*s), cy + sy_offset + int(18*s)], fill=col, outline=OUTLINE)
            d.point([(cx + int(ox) - int(2*s), cy + sy_offset + int(12*s))], fill=WHITE_HL)

        return img, {"id": item_id, "name": f"Sartenes de Pared ({wall_dir.upper()})", "zone": "kitchen", "footprint": wall_dir, "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -int(48*s)], "surface_height": 0}

    # 5. TOALLERO COLGANTE DE BAÑO EN PARED
    elif item_id.startswith("towel_rack_wall_"):
        wall_dir = "wall_w" if (item_id.endswith("_w") or rot in (1, 3)) else "wall_n"
        w, h = (int(64 * s), int(64 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2

        # Barra cromada
        draw_wall_diagonal_panel(d, cx, cy, int(16*s), int(4*s), wall_type=wall_dir, fill=METAL_HL, outline=OUTLINE)
        # Toalla blanca esponjosa doblada
        draw_wall_diagonal_panel(d, cx, cy + int(10*s), int(12*s), int(16*s), wall_type=wall_dir, fill=WHITE_LGT, outline=OUTLINE)
        # Raya decorativa azul en la toalla
        draw_wall_diagonal_panel(d, cx, cy + int(18*s), int(12*s), int(2*s), wall_type=wall_dir, fill=FABRIC_BLUE_MID)

        return img, {"id": item_id, "name": f"Toallero de Pared ({wall_dir.upper()})", "zone": "bathroom", "footprint": wall_dir, "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -int(48*s)], "surface_height": 0}

    # 6. ESTANTERÍA FLOTANTE DE PARED CON POCIONES
    elif item_id.startswith("hanging_shelf_wall_"):
        wall_dir = "wall_w" if (item_id.endswith("_w") or rot in (1, 3)) else "wall_n"
        w, h = (int(64 * s), int(64 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2

        # Balda de madera flotante
        draw_wall_diagonal_panel(d, cx, cy + int(6*s), int(18*s), int(4*s), wall_type=wall_dir, fill=WOOD_LIGHT, outline=WOOD_OUT)
        # Escuadras de hierro forjado
        for sx_pos in [-12*s, 12*s]:
            sy_pos = int(sx_pos * (0.5 if wall_dir == "wall_n" else -0.5))
            d.line([(cx + int(sx_pos), cy + sy_pos + int(8*s)), (cx + int(sx_pos), cy + sy_pos + int(18*s))], fill=METAL_SHD, width=2)

        # Frasco de poción roja y libro sobre la balda
        d.ellipse([cx - int(8*s), cy - int(4*s), cx - int(2*s), cy + int(4*s)], fill=FABRIC_RED_LGT, outline=OUTLINE)
        d.rectangle([cx + int(2*s), cy - int(6*s), cx + int(10*s), cy + int(4*s)], fill=FABRIC_TEAL_MID, outline=OUTLINE)

        return img, {"id": item_id, "name": f"Estante de Pared ({wall_dir.upper()})", "zone": "wall", "footprint": wall_dir, "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -int(48*s)], "surface_height": 0}

    # 7. RELOJ DE PARED CON PÉNDULO
    elif item_id.startswith("wall_clock_"):
        wall_dir = "wall_w" if (item_id.endswith("_w") or rot in (1, 3)) else "wall_n"
        w, h = (int(64 * s), int(64 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, h // 2

        # Caja de caoba
        draw_wall_diagonal_panel(d, cx, cy, int(10*s), int(22*s), wall_type=wall_dir, fill=WOOD_SHD, outline=WOOD_OUT)
        # Esfera redonda del reloj
        d.ellipse([cx - int(7*s), cy - int(16*s), cx + int(7*s), cy - int(2*s)], fill=WHITE_LGT, outline=GOLD_MID)
        # Agujas
        d.line([(cx, cy - int(9*s)), (cx, cy - int(14*s))], fill=OUTLINE, width=1)
        d.line([(cx, cy - int(9*s)), (cx + int(3*s), cy - int(8*s))], fill=OUTLINE, width=1)
        # Ventana del péndulo dorado
        d.ellipse([cx - int(3*s), cy + int(6*s), cx + int(3*s), cy + int(12*s)], fill=GOLD_LGT, outline=OUTLINE)

        return img, {"id": item_id, "name": f"Reloj de Pared ({wall_dir.upper()})", "zone": "wall", "footprint": wall_dir, "rot": rot, "canvas_size": [w, h], "sprite_offset": [-w//2, -int(48*s)], "surface_height": 0}

    # ---------------------------------------------------------
    # RESTO DE PIEZAS (Cocina, Baño, Decoración, Sobremesa)
    # ---------------------------------------------------------
    img_raw, meta = generate_furniture_base(item_id, scale_mode=scale_mode)
    meta["rot"] = rot
    if rot in (1, 3):
        img_raw = img_raw.transpose(Image.FLIP_LEFT_RIGHT)
    return img_raw, meta


def generate_furniture_base(item_id, scale_mode="64"):
    """Generación base de fallback para piezas restantes."""
    if str(scale_mode) == "128":
        s = 2.0
    elif str(scale_mode) == "32":
        s = 0.5
    else:
        s = 1.0
    w64, h64 = int(64 * s), int(64 * s)

    if item_id == "dining_table_2x2":
        w, h = (int(128 * s), int(96 * s))
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = int(64 * s), int(44 * s)
        for px, py in [(-24*s, 0), (24*s, 24*s), (0, -12*s), (0, 36*s)]:
            d.rectangle([cx + px - 2, cy + py, cx + px + 2, cy + py + int(18*s)], fill=WOOD_SHD, outline=OUTLINE)
            d.point([(cx + px, cy + py + int(17*s))], fill=GOLD_LGT)
        draw_iso_box(d, cx, cy + int(12*s), int(36*s), int(36*s), int(6*s), WOOD_LIGHT, WOOD_MID, WOOD_SHD)
        d.polygon([(cx - int(10*s), cy - int(4*s)), (cx + int(26*s), cy + int(12*s)), (cx + int(14*s), cy + int(18*s)), (cx - int(22*s), cy + int(2*s))], fill=WHITE_LGT, outline=OUTLINE)
        return img, {"id": item_id, "name": "Mesa de Comedor Noble (2x2)", "zone": "living", "footprint": "2x2", "canvas_size": [w, h], "sprite_offset": [-int(64*s), -int(44*s)], "surface_height": int(22*s)}

    elif item_id == "side_table":
        w, h = w64, h64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.72)
        for px, py in [(-12*s, -4*s), (12*s, -4*s), (-8*s, 8*s), (8*s, 8*s)]:
            d.rectangle([cx + px - 1, cy + py, cx + px + 1, cy + py + int(14*s)], fill=WOOD_SHD, outline=OUTLINE)
        draw_iso_box(d, cx, cy, int(18*s), int(18*s), int(5*s), WOOD_LIGHT, WOOD_MID, WOOD_SHD)
        return img, {"id": item_id, "name": "Mesita Auxiliar", "zone": "living", "footprint": "1x1", "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": int(18*s)}

    elif item_id == "potted_plant":
        w, h = w64, h64
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy = w // 2, int(h * 0.75)
        # Maceta vidriada con relieve geométrico
        d.polygon([(cx - int(10*s), cy), (cx + int(10*s), cy), (cx + int(7*s), cy + int(12*s)), (cx - int(7*s), cy + int(12*s))], fill=(195, 105, 65, 255), outline=OUTLINE)
        d.line([(cx - int(9*s), cy + int(4*s)), (cx + int(9*s), cy + int(4*s))], fill=GOLD_LGT)
        # Hojas de Monstera / Helecho en capas
        for ox, oy, rad in [(0, -int(12*s), int(10*s)), (-int(8*s), -int(6*s), int(8*s)), (int(8*s), -int(6*s), int(8*s)), (0, -int(22*s), int(10*s))]:
            d.ellipse([cx + ox - rad, cy + oy - rad, cx + ox + rad, cy + oy + rad], fill=PLANT_MID, outline=OUTLINE)
            d.ellipse([cx + ox - rad + 2, cy + oy - rad + 2, cx + ox, cy + oy], fill=PLANT_LGT)
            d.line([(cx + ox, cy + oy - rad + 2), (cx + ox, cy + oy + rad - 2)], fill=PLANT_HL)

        return img, {"id": item_id, "name": "Planta Monstera en Maceta", "zone": "living", "footprint": "1x1", "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": 0}

    # Fallback genérico
    w, h = w64, h64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, {"id": item_id, "name": item_id, "zone": "decor", "footprint": "1x1", "canvas_size": [w, h], "sprite_offset": [-w//2, int(16*s) - h], "surface_height": 0}


# =============================================================
# LISTA TOTAL Y EXPORTACIÓN COMPLETA
# =============================================================

FURNITURE_LIST = [
    # Cubos y Guías de Delimitación Isométrica
    "cube_1x1", "cube_1x2", "cube_2x1", "cube_2x2", "cube_wall_n", "cube_wall_w",
    # Objetos de Pared (Pared Norte y Pared Oeste)
    "curtained_window_n", "curtained_window_w", "art_painting_n", "art_painting_w",
    "hanging_shelf_wall_n", "hanging_shelf_wall_w", "wall_clock_n", "wall_clock_w",
    "pan_rack_wall_n", "pan_rack_wall_w", "towel_rack_wall_n", "towel_rack_wall_w",
    # Cocina
    "kitchen_fridge", "kitchen_stove", "kitchen_sink", "cooking_pot", "cutting_board",
    # Dormitorio
    "single_bed", "king_bed", "wardrobe_closet", "nightstand_drawer", "vanity_table", "cozy_rug_2x2", "plush_teddy",
    # Baño
    "bathtub_1x2", "bathroom_toilet", "bathroom_sink", "soap_bottles",
    # Patio
    "garden_bench", "bbq_grill", "stone_fountain", "flower_bed_2x1", "street_lamp", "watering_can",
    # Sala y Decoración
    "wooden_chair", "plush_armchair", "side_table", "front_sofa", "dining_table_2x2", "potted_plant", "table_lamp", "coffee_mug", "open_book"
]

def export_all_furniture_to_disk():
    """
    Exporta todos los muebles con sus 4 ángulos de rotación:
    - Escala 128 (assets_128x256/furniture): Para usar con Avatar 64x128.
    - Escala 64 (assets/furniture): Para usar con Avatar 32x64.
    """
    for scale_mode in ["128", "64"]:
        base_dir = "assets_128x256/furniture" if scale_mode == "128" else "assets/furniture"
        os.makedirs(base_dir, exist_ok=True)
        catalog = {}

        for item_id in FURNITURE_LIST:
            catalog[item_id] = {"rotations": {}}
            for rot in range(4):
                img, meta = generate_furniture(item_id, rot=rot, scale_mode=scale_mode)
                rot_filename = f"{item_id}_rot{rot}.png"
                img.save(os.path.join(base_dir, rot_filename), "PNG")
                catalog[item_id]["rotations"][str(rot)] = meta

                if rot == 0:
                    img.save(os.path.join(base_dir, f"{item_id}.png"), "PNG")
                    for k, v in meta.items():
                        catalog[item_id][k] = v

        meta_path = os.path.join(base_dir, "furniture_catalog.json")
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(catalog, f, indent=4, ensure_ascii=False)

        print(f"Exportados {len(FURNITURE_LIST) * 4} sprites en '{base_dir}/'.")

if __name__ == "__main__":
    export_all_furniture_to_disk()
