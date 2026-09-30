"""
generate_light_emitters.py - Sprites de muebles que emiten luz (chimenea y lámpara de lava).

Dibuja pixel art isométrico con PIL (sin antialias) en la misma convención que los muebles
de 'established_furniture':
  - Mueble de piso 1x1: lienzo 128x128, se dibuja a 0.5x en el juego. La baldosa ocupa el
    rombo top(64,64) right(128,96) bottom(64,128) left(0,96).
  - Objeto de superficie: lienzo 64x64 (como table_lamp), apoyado en y≈60.
  - rot0/rot2: frente en la cara izquierda (mira a +y). rot1/rot3: espejo (frente a +x).

  - Mueble 0.5x0.5 (sub-celda): lienzo 128x176 (como floor_plant_sm), base en (64, ~172).

Escribe SOLO los archivos de estos muebles (no toca ni borra nada más):
  - frontend/assets/images/furniture/established_furniture/  (lo que carga el juego)
  - frontend/assets/images/furniture/new_added/               (fuente para el sincronizador)

Uso (desde la raíz del repo):  python CreateSprites/generate_light_emitters.py
"""

import os
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FURN = os.path.join(ROOT, "frontend", "assets", "images", "furniture")
ESTABLISHED = os.path.join(FURN, "established_furniture")
NEW_ADDED = os.path.join(FURN, "new_added")

OUTLINE = (35, 28, 32, 255)

# Ladrillo
BRICK_TOP = (196, 112, 86, 255)
BRICK_FRONT = (170, 84, 62, 255)
BRICK_SIDE = (122, 58, 46, 255)
MORTAR_FRONT = (214, 170, 140, 255)
MORTAR_SIDE = (150, 104, 88, 255)
# Madera de la repisa
WOOD_TOP = (178, 122, 76, 255)
WOOD_FRONT = (140, 90, 52, 255)
WOOD_SIDE = (98, 60, 34, 255)
# Piedra del hogar
STONE_TOP = (168, 164, 170, 255)
STONE_FRONT = (128, 124, 132, 255)
STONE_SIDE = (96, 92, 100, 255)
# Fuego
SOOT = (28, 20, 24, 255)
EMBER = (120, 36, 20, 255)
FIRE_RED = (228, 72, 32, 255)
FIRE_ORANGE = (255, 146, 40, 255)
FIRE_YELLOW = (255, 214, 92, 255)
FIRE_CORE = (255, 246, 196, 255)
LOG = (86, 52, 30, 255)
LOG_HL = (132, 86, 50, 255)


def P(x, y, z):
    """Punto de la baldosa (x, y en 0..1, z en px hacia arriba) → píxel del lienzo 128x128."""
    return (64 + (x - y) * 64, 64 + (x + y) * 32 - z)


def poly(d, pts, fill, outline=OUTLINE):
    d.polygon([(round(px), round(py)) for px, py in pts], fill=fill, outline=outline)


def iso_box(d, x0, x1, y0, y1, z0, z1, top, front, side):
    """Prisma: cara superior, frontal (+y, izquierda en pantalla) y lateral (+x, derecha)."""
    poly(d, [P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)], front)
    poly(d, [P(x1, y1, z0), P(x1, y0, z0), P(x1, y0, z1), P(x1, y1, z1)], side)
    poly(d, [P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)], top)


def fireplace_rot0():
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Losa de piedra del hogar, delante de la boca.
    iso_box(d, 0.16, 0.84, 0.50, 0.74, 0, 4, STONE_TOP, STONE_FRONT, STONE_SIDE)

    # Cuerpo de ladrillo, apoyado atrás (y pequeño) para quedar contra la pared.
    x0, x1, y0, y1, h = 0.08, 0.92, 0.10, 0.50, 62
    iso_box(d, x0, x1, y0, y1, 0, h, BRICK_TOP, BRICK_FRONT, BRICK_SIDE)

    # Juntas de mortero: hiladas horizontales con llagas trabadas.
    for row, z in enumerate(range(7, h, 7)):
        d.line([P(x0, y1, z), P(x1, y1, z)], fill=MORTAR_FRONT)
        d.line([P(x1, y1, z), P(x1, y0, z)], fill=MORTAR_SIDE)
        offset = 0.0 if row % 2 == 0 else 0.06
        xs = x0 + 0.06 + offset
        while xs < x1 - 0.02:
            d.line([P(xs, y1, z), P(xs, y1, min(z + 7, h))], fill=MORTAR_FRONT)
            xs += 0.12
        ys = y0 + 0.07 + (0.0 if row % 2 == 0 else 0.06)
        while ys < y1 - 0.02:
            d.line([P(x1, ys, z), P(x1, ys, min(z + 7, h))], fill=MORTAR_SIDE)
            ys += 0.13
    # Volver a marcar el contorno sobre las juntas.
    poly(d, [P(x0, y1, 0), P(x1, y1, 0), P(x1, y1, h), P(x0, y1, h)], None)
    poly(d, [P(x1, y1, 0), P(x1, y0, 0), P(x1, y0, h), P(x1, y1, h)], None)

    # Boca: arco oscuro en la cara frontal.
    bx0, bx1, bz1 = 0.28, 0.72, 34
    mouth = [P(bx0, y1, 0), P(bx1, y1, 0), P(bx1, y1, bz1 - 6), P(bx1 - 0.05, y1, bz1 - 1),
             P(0.5, y1, bz1 + 2), P(bx0 + 0.05, y1, bz1 - 1), P(bx0, y1, bz1 - 6)]
    poly(d, mouth, SOOT)
    # Brasas al fondo.
    poly(d, [P(bx0 + 0.04, y1, 0), P(bx1 - 0.04, y1, 0), P(bx1 - 0.06, y1, 4), P(bx0 + 0.06, y1, 4)], EMBER, outline=None)

    # Troncos cruzados.
    d.line([P(bx0 + 0.07, y1, 3), P(bx1 - 0.10, y1, 7)], fill=LOG, width=3)
    d.line([P(bx0 + 0.10, y1, 7), P(bx1 - 0.07, y1, 3)], fill=LOG, width=3)
    d.line([P(bx0 + 0.10, y1, 8), P(bx1 - 0.12, y1, 8)], fill=LOG_HL)

    # Llamas en capas: roja, naranja, amarilla y núcleo.
    def flame(cx, width, height, color):
        base_l = P(cx - width, y1, 6)
        base_r = P(cx + width, y1, 6)
        tip = P(cx, y1, 6 + height)
        mid_l = P(cx - width * 0.7, y1, 6 + height * 0.55)
        mid_r = P(cx + width * 0.6, y1, 6 + height * 0.45)
        poly(d, [base_l, mid_l, tip, mid_r, base_r], color, outline=None)

    flame(0.42, 0.09, 20, FIRE_RED)
    flame(0.58, 0.08, 17, FIRE_RED)
    flame(0.50, 0.12, 24, FIRE_ORANGE)
    flame(0.44, 0.06, 15, FIRE_ORANGE)
    flame(0.50, 0.07, 16, FIRE_YELLOW)
    flame(0.50, 0.03, 9, FIRE_CORE)

    # Repisa de madera sobre el cuerpo.
    iso_box(d, 0.04, 0.96, 0.07, 0.56, h, h + 6, WOOD_TOP, WOOD_FRONT, WOOD_SIDE)
    d.line([P(0.05, 0.55, h + 6), P(0.95, 0.55, h + 6)], fill=(214, 160, 108, 255))

    # Velas y un marco pequeño sobre la repisa.
    for cx in (0.22, 0.30):
        base = P(cx, 0.35, h + 6)
        d.rectangle([base[0] - 1, base[1] - 7, base[0] + 1, base[1]], fill=(246, 238, 220, 255), outline=OUTLINE)
        d.point([(base[0], base[1] - 9)], fill=FIRE_YELLOW)
        d.point([(base[0], base[1] - 8)], fill=FIRE_ORANGE)
    frame = P(0.70, 0.30, h + 6)
    d.rectangle([frame[0] - 6, frame[1] - 13, frame[0] + 5, frame[1] - 1], fill=(92, 60, 40, 255), outline=OUTLINE)
    d.rectangle([frame[0] - 4, frame[1] - 11, frame[0] + 3, frame[1] - 3], fill=(120, 170, 200, 255))
    return img


# Lámpara de lava (superficie, 64x64)
METAL_HL = (236, 236, 244, 255)
METAL_MID = (170, 172, 186, 255)
METAL_SHD = (104, 106, 122, 255)
LIQUID = (182, 58, 150, 255)
LIQUID_LIGHT = (224, 92, 178, 255)
BLOB = (255, 148, 96, 255)
BLOB_HL = (255, 214, 150, 255)
GLASS_HL = (255, 236, 250, 255)


def lava_lamp():
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = 32

    # Base cónica metálica (ancha abajo).
    base = [(cx - 9, 60), (cx + 9, 60), (cx + 5, 44), (cx - 5, 44)]
    d.polygon(base, fill=METAL_MID, outline=OUTLINE)
    d.polygon([(cx - 8, 59), (cx - 3, 59), (cx - 2, 45), (cx - 4, 45)], fill=METAL_HL)
    d.polygon([(cx + 4, 59), (cx + 8, 59), (cx + 5, 45), (cx + 4, 45)], fill=METAL_SHD)
    d.line([(cx - 9, 60), (cx + 9, 60)], fill=OUTLINE)

    # Cápsula de vidrio: ancha en el medio, angosta arriba y abajo.
    glass = [(cx - 5, 44), (cx - 7, 36), (cx - 6, 24), (cx - 3, 14), (cx + 3, 14), (cx + 6, 24), (cx + 7, 36), (cx + 5, 44)]
    d.polygon(glass, fill=LIQUID, outline=OUTLINE)
    d.polygon([(cx - 4, 42), (cx - 5, 36), (cx - 4, 25), (cx - 2, 17), (cx, 17), (cx, 42)], fill=LIQUID_LIGHT)

    # Burbujas de "lava".
    for (bx, by, r) in [(cx - 1, 38, 3), (cx + 2, 28, 2), (cx - 2, 21, 2), (cx + 1, 33, 1)]:
        d.ellipse([bx - r, by - r, bx + r, by + r], fill=BLOB)
        d.point([(bx - r + 1, by - r + 1)], fill=BLOB_HL)
    # Brillo del vidrio.
    d.line([(cx - 4, 34), (cx - 4, 26)], fill=GLASS_HL)

    # Tapa metálica.
    d.polygon([(cx - 3, 14), (cx + 3, 14), (cx + 2, 10), (cx - 2, 10)], fill=METAL_MID, outline=OUTLINE)
    d.point([(cx - 1, 12)], fill=METAL_HL)
    return img


# Lámpara de pie (0.5x0.5, 128x176) — mismos tonos que table_lamp.
SHADE_HL = (255, 250, 222, 255)
SHADE_MID = (250, 234, 176, 255)
SHADE_SHD = (222, 196, 132, 255)
BRASS_HL = (255, 232, 140, 255)
BRASS_MID = (222, 168, 52, 255)
BRASS_SHD = (156, 108, 28, 255)


def floor_lamp():
    img = Image.new("RGBA", (128, 176), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = 64

    # Base: disco de latón visto en isométrico.
    d.ellipse([cx - 15, 162, cx + 15, 174], fill=BRASS_SHD, outline=OUTLINE)
    d.ellipse([cx - 15, 159, cx + 15, 171], fill=BRASS_MID, outline=OUTLINE)
    d.arc([cx - 11, 161, cx + 7, 168], 190, 290, fill=BRASS_HL)

    # Poste con un nudo a media altura.
    d.rectangle([cx - 2, 62, cx + 2, 164], fill=BRASS_MID, outline=OUTLINE)
    d.line([(cx - 1, 64), (cx - 1, 162)], fill=BRASS_HL)
    d.ellipse([cx - 4, 110, cx + 4, 118], fill=BRASS_MID, outline=OUTLINE)
    d.point([(cx - 2, 112)], fill=BRASS_HL)
    # Cadenita del interruptor.
    d.line([(cx + 8, 60), (cx + 8, 76)], fill=BRASS_SHD)
    d.point([(cx + 8, 77)], fill=BRASS_HL)

    # Pantalla troncocónica: tapa elíptica, cuerpo, borde inferior.
    shade = [(cx - 13, 26), (cx + 13, 26), (cx + 22, 60), (cx - 22, 60)]
    d.polygon(shade, fill=SHADE_MID, outline=OUTLINE)
    d.polygon([(cx - 12, 28), (cx - 4, 28), (cx - 7, 58), (cx - 20, 58)], fill=SHADE_HL)
    d.polygon([(cx + 8, 28), (cx + 12, 28), (cx + 20, 58), (cx + 13, 58)], fill=SHADE_SHD)
    d.ellipse([cx - 13, 22, cx + 13, 30], fill=SHADE_HL, outline=OUTLINE)
    d.ellipse([cx - 22, 56, cx + 22, 64], fill=SHADE_SHD, outline=OUTLINE)
    d.ellipse([cx - 19, 57, cx + 19, 62], fill=(255, 238, 170, 255))  # boca iluminada
    d.line([(cx - 22, 60), (cx + 22, 60)], fill=BRASS_MID)
    return img


def save_all(item_id, rot0, subdir, source_stem=None):
    """rot0/rot2 = frente a la izquierda; rot1/rot3 = espejo. Mismo esquema de nombres
    que el resto de 'established_furniture' (id.png + id_rot{0..3}.png). [source_stem] es
    el nombre en new_added cuando difiere (en 05x05/ el sincronizador agrega '_sm')."""
    rot1 = rot0.transpose(Image.FLIP_LEFT_RIGHT)
    frames = {0: rot0, 1: rot1, 2: rot0, 3: rot1}
    new_dir = os.path.join(NEW_ADDED, subdir)
    for target, stem in ((ESTABLISHED, item_id), (new_dir, source_stem or item_id)):
        os.makedirs(target, exist_ok=True)
        rot0.save(os.path.join(target, f"{stem}.png"))
        for r, im in frames.items():
            im.save(os.path.join(target, f"{stem}_rot{r}.png"))
    print(f"{item_id}: 5 PNG en established_furniture/ y new_added/{subdir}/")


if __name__ == "__main__":
    save_all("fireplace", fireplace_rot0(), os.path.join("1x1", "normal"))
    save_all("lava_lamp", lava_lamp(), "surface")
    save_all("floor_lamp_sm", floor_lamp(), "05x05", source_stem="floor_lamp")
