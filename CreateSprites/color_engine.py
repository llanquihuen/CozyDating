"""
color_engine.py - Motor de colorización, animación y generación multi-direccional 16-bit
Soporta 4 direcciones ('down', 'up', 'left', 'right'), ciclo de caminata (frames 0..3),
generación de Spritesheets (matriz 4x4) y exportación a GIF animado fluido.
"""

import os
from PIL import Image
import sprite_generator

ASSETS_DIR = "assets"

def hex_to_rgb(hex_str):
    hex_str = hex_str.lstrip('#')
    if len(hex_str) == 3:
        hex_str = ''.join([c*2 for c in hex_str])
    return tuple(int(hex_str[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}".upper()

def clamp(val, low=0, high=255):
    return max(low, min(high, int(val)))

def generate_snes_palette_ramp(base_rgb, category="clothing"):
    r, g, b = base_rgb
    if category in ("skin", "face_shape"):
        hl = (clamp(r * 1.12 + 30), clamp(g * 1.10 + 24), clamp(b * 1.08 + 18))
        light = (clamp(r * 1.04 + 12), clamp(g * 1.03 + 8), clamp(b * 1.02 + 4))
        mid = (r, g, b)
        shadow = (clamp(r * 0.82), clamp(g * 0.70), clamp(b * 0.65))
        deep_shadow = (clamp(r * 0.60), clamp(g * 0.46), clamp(b * 0.42))
        outline = (clamp(r * 0.42 + 10), clamp(g * 0.26 + 5), clamp(b * 0.24 + 5))
    elif category == "hair":
        hl = (clamp(r * 1.30 + 35), clamp(g * 1.30 + 35), clamp(b * 1.30 + 35))
        light = (clamp(r * 1.15 + 15), clamp(g * 1.15 + 15), clamp(b * 1.15 + 15))
        mid = (r, g, b)
        shadow = (clamp(r * 0.65), clamp(g * 0.60), clamp(b * 0.66))
        deep_shadow = (clamp(r * 0.42), clamp(g * 0.36), clamp(b * 0.44))
        outline = (clamp(r * 0.25 + 5), clamp(g * 0.20 + 5), clamp(b * 0.28 + 5))
    else: # Ropa y accesorios
        hl = (clamp(r * 1.28 + 28), clamp(g * 1.28 + 28), clamp(b * 1.28 + 28))
        light = (clamp(r * 1.12 + 12), clamp(g * 1.12 + 12), clamp(b * 1.12 + 12))
        mid = (r, g, b)
        shadow = (clamp(r * 0.70), clamp(g * 0.66), clamp(b * 0.72))
        deep_shadow = (clamp(r * 0.48), clamp(g * 0.42), clamp(b * 0.50))
        outline = (clamp(r * 0.24 + 5), clamp(g * 0.20 + 5), clamp(b * 0.26 + 5))
        
    return {
        "hl": hl,
        "light": light,
        "mid": mid,
        "shadow": shadow,
        "deep_shadow": deep_shadow,
        "outline": outline
    }

def interpolate_color(c1, c2, factor):
    return (
        clamp(c1[0] + (c2[0] - c1[0]) * factor),
        clamp(c1[1] + (c2[1] - c1[1]) * factor),
        clamp(c1[2] + (c2[2] - c1[2]) * factor)
    )

def colorize_sprite(img, base_rgb, category="clothing", preserve_whites=False):
    if img is None:
        return None
    
    img = img.convert("RGBA")
    w, h = img.size
    pixels = img.load()
    
    ramp = generate_snes_palette_ramp(base_rgb, category)
    out_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out_pixels = out_img.load()
    
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            
            # Tratamiento especial de ojos
            if category == "eyes":
                if r > 120 and g < 45 and b < 45:
                    lum = r
                    if lum >= 200:
                        cr, cg, cb = ramp["hl"]
                    elif lum >= 150:
                        cr, cg, cb = ramp["mid"]
                    else:
                        cr, cg, cb = ramp["shadow"]
                    out_pixels[x, y] = (cr, cg, cb, a)
                    continue
                elif r > 240 and g > 240 and b > 240:
                    out_pixels[x, y] = (255, 255, 255, a)
                    continue
                elif r < 60 and g < 60 and b < 60:
                    out_pixels[x, y] = (30, 25, 35, a)
                    continue
            
            if preserve_whites and r > 240 and g > 240 and b > 240:
                out_pixels[x, y] = (r, g, b, a)
                continue
                
            if abs(r - g) > 20 or abs(g - b) > 20:
                out_pixels[x, y] = (r, g, b, a)
                continue

            if r < 40 and g < 40 and b < 40:
                cr, cg, cb = ramp["outline"]
                out_pixels[x, y] = (cr, cg, cb, a)
                continue
                
            lum = (r + g + b) // 3
            
            if lum >= 240:
                cr, cg, cb = ramp["hl"]
            elif lum >= 195:
                factor = (lum - 195) / (240 - 195)
                cr, cg, cb = interpolate_color(ramp["light"], ramp["hl"], factor)
            elif lum >= 140:
                factor = (lum - 140) / (195 - 140)
                cr, cg, cb = interpolate_color(ramp["mid"], ramp["light"], factor)
            elif lum >= 85:
                factor = (lum - 85) / (140 - 85)
                cr, cg, cb = interpolate_color(ramp["shadow"], ramp["mid"], factor)
            elif lum >= 40:
                factor = (lum - 40) / (85 - 40)
                cr, cg, cb = interpolate_color(ramp["deep_shadow"], ramp["shadow"], factor)
            else:
                cr, cg, cb = ramp["outline"]
                
            out_pixels[x, y] = (cr, cg, cb, a)
            
    return out_img

import sprite_generator_32x64

ASSETS_DIR_64x128 = "assets"
ASSETS_DIR_32x64 = "assets_32x64"

# =============================================================
# CARGADOR DE CAPAS PNG DESDE DISCO (CON ASSET CACHING MULTI-RESOLUCIÓN)
# =============================================================
_DISK_CACHE = {}

def clear_disk_cache():
    """Limpia la memoria caché para forzar la recarga de archivos PNG modificados en disco."""
    global _DISK_CACHE
    _DISK_CACHE.clear()

def get_layer_image(category, item_name, direction="down", frame=0, fallback_func=None, resolution="64x128"):
    """
    Carga el sprite PNG directamente desde la carpeta en disco correspondiente a la resolución:
    - 64x128: 'assets/<category>/<item_name>/<direction>_frame<frame>.png'
    - 32x64:  'assets_32x64/<category>/<item_name>/<direction>_frame<frame>.png'
    """
    cache_key = (resolution, category, item_name, direction, frame)
    if cache_key in _DISK_CACHE:
        return _DISK_CACHE[cache_key].copy()

    assets_dir = ASSETS_DIR_32x64 if resolution == "32x64" else ASSETS_DIR_64x128

    # Rutas posibles en disco
    possible_paths = [
        os.path.join(assets_dir, category, item_name, f"{direction}_frame{frame}.png"),
        os.path.join(assets_dir, category, item_name, f"{direction}_f{frame}.png"),
        os.path.join(assets_dir, category, f"{item_name}_{direction}_f{frame}.png"),
        os.path.join(assets_dir, category, f"{item_name}.png")
    ]

    loaded_img = None
    for p in possible_paths:
        if os.path.exists(p):
            try:
                with Image.open(p) as img_file:
                    loaded_img = img_file.convert("RGBA")
                    break
            except Exception as e:
                print(f"Aviso: Error al leer {p} desde disco: {e}")

    if loaded_img is None and fallback_func is not None:
        try:
            if category == "body":
                loaded_img = fallback_func(direction=direction, frame=frame)
            else:
                loaded_img = fallback_func(style=item_name, direction=direction, frame=frame)
        except Exception as e:
            print(f"Aviso: Error en generador de respaldo para {category}/{item_name}: {e}")

    if loaded_img is not None:
        _DISK_CACHE[cache_key] = loaded_img.copy()
        return loaded_img.copy()

    return None

# =============================================================
# GENERADOR Y COMPOSITOR DE CUADRO MULTI-DIRECCIONAL Y MULTI-RESOLUCIÓN
# =============================================================
def composite_avatar(layers_config, direction="down", frame=0, resolution="64x128"):
    """
    Renderiza y compone un cuadro específico leyendo las capas de la resolución indicada ('64x128' o '32x64').
    """
    cw, ch = (32, 64) if resolution == "32x64" else (64, 128)
    gen = sprite_generator_32x64 if resolution == "32x64" else sprite_generator

    final_img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    skin_color = layers_config.get("body", {}).get("color", "#FCD5B5")

    # Extraer identificadores de estilo
    f_shape_file = layers_config.get("face_shape", {}).get("file", "face_oval.png")
    shape_type = f_shape_file.replace("face_", "").replace(".png", "")
    
    hair_file = layers_config.get("hair", {}).get("file", "hair_farm_braids.png")
    hair_style = hair_file.replace("hair_", "").replace(".png", "")
    
    eyes_file = layers_config.get("eyes", {}).get("file", "eyes_jrpg_classic.png")
    eyes_style = eyes_file.replace("eyes_", "").replace(".png", "")
    
    brows_file = layers_config.get("eyebrows", {}).get("file", "brows_normal.png")
    brows_style = brows_file.replace("brows_", "").replace(".png", "")
    
    nose_file = layers_config.get("nose", {}).get("file", "nose_subtle.png")
    nose_style = nose_file.replace("nose_", "").replace(".png", "")
    
    mouth_file = layers_config.get("mouth", {}).get("file", "mouth_smile.png")
    mouth_style = mouth_file.replace("mouth_", "").replace(".png", "")
    
    detail_file = layers_config.get("face_detail", {}).get("file", "detail_none.png")
    detail_style = detail_file.replace("detail_", "").replace(".png", "")
    
    top_file = layers_config.get("tops", {}).get("file", "top_flannel_shirt.png")
    top_style = top_file.replace("top_", "").replace(".png", "")
    
    bottom_file = layers_config.get("bottoms", {}).get("file", "bottom_farmer_overalls.png")
    bottom_style = bottom_file.replace("bottom_", "").replace(".png", "")
    
    shoes_file = layers_config.get("shoes", {}).get("file", "shoes_farmer_boots.png")
    shoes_style = shoes_file.replace("shoes_", "").replace(".png", "")
    
    acc_file = layers_config.get("accessories", {}).get("file", "acc_none.png")
    acc_style = acc_file.replace("acc_", "").replace(".png", "")

    # Carga de imágenes PNG desde disco según resolución
    body_img = get_layer_image("body", "base", direction, frame, gen.generate_body, resolution=resolution)
    face_img = get_layer_image("face_shape", shape_type, direction, frame, gen.generate_face_shape, resolution=resolution)
    detail_img = get_layer_image("face_details", detail_style, direction, frame, gen.generate_face_detail, resolution=resolution) if detail_style != "none" else None
    nose_img = get_layer_image("nose", nose_style, direction, frame, gen.generate_nose, resolution=resolution)
    mouth_img = get_layer_image("mouth", mouth_style, direction, frame, gen.generate_mouth, resolution=resolution)
    eyes_img = get_layer_image("eyes", eyes_style, direction, frame, gen.generate_eyes, resolution=resolution)
    bottom_img = get_layer_image("bottoms", bottom_style, direction, frame, gen.generate_bottoms, resolution=resolution) if bottom_style != "none" else None
    shoes_img = get_layer_image("shoes", shoes_style, direction, frame, gen.generate_shoes, resolution=resolution) if shoes_style != "none" else None
    top_img = get_layer_image("tops", top_style, direction, frame, gen.generate_tops, resolution=resolution) if top_style != "none" else None
    hair_img = get_layer_image("hair", hair_style, direction, frame, gen.generate_hair, resolution=resolution) if hair_style != "none" else None
    brows_img = get_layer_image("eyebrows", brows_style, direction, frame, gen.generate_eyebrows, resolution=resolution)
    acc_img = get_layer_image("accessories", acc_style, direction, frame, gen.generate_accessories, resolution=resolution) if acc_style != "none" else None

    # Orden de renderizado según dirección
    if direction == "up":
        # Vista de Espalda: Capas frontales quedan ocultas, el pelo cubre la espalda
        layers_to_draw = [
            ("body", body_img, "skin", False),
            ("bottoms", bottom_img, "clothing", False),
            ("shoes", shoes_img, "clothing", True),
            ("tops", top_img, "clothing", False),
            ("face_shape", face_img, "skin", False),
            ("hair", hair_img, "hair", False),
            ("accessories", acc_img, "clothing", False),
        ]
    else:
        # Vistas Down (Frente), Left y Right
        layers_to_draw = [
            ("body", body_img, "skin", False),
            ("face_shape", face_img, "skin", False),
            ("face_detail", detail_img, "skin", False),
            ("nose", nose_img, "skin", False),
            ("mouth", mouth_img, "clothing", False),
            ("eyes", eyes_img, "eyes", False),
            ("bottoms", bottom_img, "clothing", False),
            ("shoes", shoes_img, "clothing", True),
            ("tops", top_img, "clothing", False),
            ("hair", hair_img, "hair", False),
            ("eyebrows", brows_img, "hair", False),
            ("accessories", acc_img, "clothing", False),
        ]

    for cat_name, raw_img, cat_type, preserve_w in layers_to_draw:
        if raw_img is None:
            continue
        cfg = layers_config.get(cat_name, {})
        color_hex = cfg.get("color", skin_color if cat_type == "skin" else "#FFFFFF")
        rgb = hex_to_rgb(color_hex)
        colorized = colorize_sprite(raw_img, rgb, category=cat_type, preserve_whites=preserve_w)
        final_img.alpha_composite(colorized)

    return final_img

# =============================================================
# GENERACIÓN DE SPRITESHEET (MATRIZ 4x4 PARA VIDEOJUEGOS)
# =============================================================
def generate_spritesheet(layers_config, scale=1, resolution="64x128"):
    """
    Genera una hoja de sprites (Spritesheet) estándar para videojuegos (4 filas x 4 columnas):
    - 64x128: 256x512 px (1x)
    - 32x64:  128x256 px (1x)
    """
    cw, ch = (32, 64) if resolution == "32x64" else (64, 128)
    directions = ["down", "left", "right", "up"]
    sheet_w = cw * 4
    sheet_h = ch * 4
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    for row, d in enumerate(directions):
        for col in range(4):
            frame_img = composite_avatar(layers_config, direction=d, frame=col, resolution=resolution)
            sheet.alpha_composite(frame_img, (col * cw, row * ch))

    if scale > 1:
        sheet = sheet.resize((sheet_w * scale, sheet_h * scale), Image.NEAREST)
        
    return sheet

# =============================================================
# GENERACIÓN DE GIF ANIMADO
# =============================================================
def generate_walk_gif(layers_config, direction="down", scale=4, duration_ms=160, resolution="64x128"):
    """
    Genera y retorna una lista de cuadros escalados lista para guardar como GIF animado con bucle infinito.
    """
    cw, ch = (32, 64) if resolution == "32x64" else (64, 128)
    frames = []
    for f in [0, 1, 2, 3]:
        img = composite_avatar(layers_config, direction=direction, frame=f, resolution=resolution)
        if scale > 1:
            img = img.resize((cw * scale, ch * scale), Image.NEAREST)
        frames.append(img)
    return frames

# -------------------------------------------------------------
# PALETAS RETRO
# -------------------------------------------------------------
RETRO_PALETTES = {
    "skin": [
        ("Durazno Cálido", "#FCD5B5"),
        ("Porcelana Suave", "#FDE8D8"),
        ("Pálido Élfico", "#FFF0E6"),
        ("Bronceado Campestre", "#EBB68C"),
        ("Trigueño Cálido", "#D28E61"),
        ("Caramelo Dulce", "#B76F38"),
        ("Café Canela", "#8A4C22"),
        ("Ébano Profundo", "#542D15"),
        ("Hada del Bosque (Verde)", "#99D8A6"),
        ("Súcubo / Amatista", "#C4B0E8"),
        ("Espíritu de Cristal", "#A4E4F4"),
    ],
    "hair": [
        ("Castaño Avellana", "#6A452D"),
        ("Pelirrojo Leah (Stardew)", "#C85A2A"),
        ("Rubio Cosecha", "#F5CE62"),
        ("Rubio Platino", "#F8EED1"),
        ("Negro Cuervo", "#26232E"),
        ("Castaño Claro", "#8D5B3A"),
        ("Rosa Sakura", "#F587B8"),
        ("Púrpura Abigail (Stardew)", "#8C4FE0"),
        ("Azul Marino Profundo", "#2C467E"),
        ("Verde Esmeralda", "#2EA86E"),
        ("Cyan Turquesa", "#36D1DC"),
        ("Blanco Plateado", "#D8E2EC"),
    ],
    "eyes": [
        ("Azul Zafiro", "#2563EB"),
        ("Verde Pradera", "#059669"),
        ("Ámbar Miel", "#D97706"),
        ("Café Chocolate", "#593319"),
        ("Rubí Granate", "#DC2626"),
        ("Violeta Místico", "#7C3AED"),
        ("Cyan Lago", "#06B6D4"),
        ("Gris Tormenta", "#64748B"),
    ],
    "clothing": [
        ("Azul Mezclilla / Peto", "#2563EB"),
        ("Rojo Franela", "#DC2626"),
        ("Verde Bosque", "#16A34A"),
        ("Ocre de Viajero", "#D97706"),
        ("Marrón Cuero Rústico", "#78350F"),
        ("Blanco Lino", "#F8FAFC"),
        ("Gris Carbón", "#334155"),
        ("Púrpura Brujo", "#9333EA"),
        ("Rosa Campestre", "#F472B6"),
        ("Mostaza Otoño", "#EAB308"),
        ("Naranja Teja", "#EA580C"),
        ("Azul Cielo", "#38BDF8"),
    ]
}
