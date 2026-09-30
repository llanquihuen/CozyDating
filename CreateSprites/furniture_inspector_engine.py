"""
furniture_inspector_engine.py - Motor de Inspección y Calibración Isométrica de Muebles
Carga EXCLUSIVAMENTE los muebles de 'frontend/assets/images/furniture/new_added/',
permite visualizar baldosas isométricas, calibrar el sprite_offset, calibrar puntos de asiento (SeatSpot)
con avatar sentado en tiempo real, y calibrar objetos sobre superficie (surface_height / surface_offset).
"""

import os
import re
import json
from PIL import Image, ImageDraw

import octo_engine

# Directorio exclusivo de muebles
NEW_ADDED_DIR = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "frontend", "assets", "images", "furniture", "new_added"
))

# Dimensiones base de baldosa isométrica estándar HD (Avatar 64x128 / Muebles HD)
TILE_W = 128
TILE_H = 64
SUB_W = 64
SUB_H = 32

# Presets iniciales de asientos desde chair_seat_config.dart
DEFAULT_SEAT_CONFIGS = {
    "simple_chair": {
        0: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [-2.0, 0.0], "tap_offset": [0.0, -18.0]}],
        1: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [5.0, 2.0], "tap_offset": [0.0, -18.0]}],
        2: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [5.0, 2.0], "tap_offset": [0.0, -18.0]}],
        3: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [-5.0, 2.0], "tap_offset": [0.0, -18.0]}],
    },
    "gamer_chair": {
        0: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [-2.0, 0.0], "tap_offset": [0.0, -18.0]}],
        1: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [5.0, 2.0], "tap_offset": [0.0, -18.0]}],
        2: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [5.0, 2.0], "tap_offset": [0.0, -18.0]}],
        3: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [-5.0, 2.0], "tap_offset": [0.0, -18.0]}],
    },
    "plush_armchair": {
        0: [{"slot": 0, "sub_cell": [0, 1], "visual_offset": [11.0, 6.0], "tap_offset": [0.0, -20.0]}],
        1: [{"slot": 0, "sub_cell": [1, 0], "visual_offset": [-11.0, 6.0], "tap_offset": [0.0, -20.0]}],
        2: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [5.0, 14.0], "tap_offset": [0.0, -20.0]}],
        3: [{"slot": 0, "sub_cell": [0, 0], "visual_offset": [0.0, 14.0], "tap_offset": [0.0, -20.0]}],
    },
    "simple_sofa": {
        0: [
            {"slot": 0, "sub_cell": [0, 1], "visual_offset": [4.0, 4.0], "tap_offset": [0.0, -18.0]},
            {"slot": 1, "sub_cell": [1, 1], "visual_offset": [10.0, 5.0], "tap_offset": [0.0, -18.0]},
            {"slot": 2, "sub_cell": [2, 1], "visual_offset": [14.0, 5.0], "tap_offset": [0.0, -18.0]},
        ],
        1: [
            {"slot": 0, "sub_cell": [1, 0], "visual_offset": [-4.0, 4.0], "tap_offset": [0.0, -18.0]},
            {"slot": 1, "sub_cell": [1, 1], "visual_offset": [-10.0, 5.0], "tap_offset": [0.0, -18.0]},
            {"slot": 2, "sub_cell": [1, 2], "visual_offset": [-14.0, 5.0], "tap_offset": [0.0, -18.0]},
        ],
        2: [
            {"slot": 0, "sub_cell": [0, 0], "visual_offset": [8.0, 6.0], "tap_offset": [0.0, -18.0]},
            {"slot": 1, "sub_cell": [1, 0], "visual_offset": [11.0, 6.0], "tap_offset": [0.0, -18.0]},
            {"slot": 2, "sub_cell": [2, 0], "visual_offset": [14.0, 6.0], "tap_offset": [0.0, -18.0]},
        ],
        3: [
            {"slot": 0, "sub_cell": [0, 0], "visual_offset": [-8.0, 6.0], "tap_offset": [0.0, -18.0]},
            {"slot": 1, "sub_cell": [0, 1], "visual_offset": [-11.0, 6.0], "tap_offset": [0.0, -18.0]},
            {"slot": 2, "sub_cell": [0, 2], "visual_offset": [-14.0, 6.0], "tap_offset": [0.0, -18.0]},
        ],
    },
}

# Presets de lugares sobre superficies (Surface Spots) para mesas, escritorios y muebles que soportan superficie
DEFAULT_SURFACE_SPOTS = {
    "table": {
        r: [
            {"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"},
            {"spot": 1, "sub_cell": [1, 0], "offset": [0, 0], "item": "coffee_mug"},
            {"spot": 2, "sub_cell": [0, 1], "offset": [0, 0], "item": "open_book"},
            {"spot": 3, "sub_cell": [1, 1], "offset": [0, 0], "item": "none"},
        ] for r in range(4)
    },
    "dining_table_2x2": {
        0: [
            {"spot": 0, "sub_cell": [1, 1], "offset": [0, 0], "item": "table_lamp"},
            {"spot": 1, "sub_cell": [2, 1], "offset": [0, 0], "item": "coffee_mug"},
            {"spot": 2, "sub_cell": [1, 2], "offset": [0, 0], "item": "open_book"},
            {"spot": 3, "sub_cell": [2, 2], "offset": [0, 0], "item": "table_lamp"},
        ],
        1: [
            {"spot": 0, "sub_cell": [1, 1], "offset": [0, 0], "item": "table_lamp"},
            {"spot": 1, "sub_cell": [2, 1], "offset": [0, 0], "item": "coffee_mug"},
            {"spot": 2, "sub_cell": [1, 2], "offset": [0, 0], "item": "open_book"},
            {"spot": 3, "sub_cell": [2, 2], "offset": [0, 0], "item": "table_lamp"},
        ],
        2: [
            {"spot": 0, "sub_cell": [1, 1], "offset": [0, 0], "item": "table_lamp"},
            {"spot": 1, "sub_cell": [2, 1], "offset": [0, 0], "item": "coffee_mug"},
            {"spot": 2, "sub_cell": [1, 2], "offset": [0, 0], "item": "open_book"},
            {"spot": 3, "sub_cell": [2, 2], "offset": [0, 0], "item": "table_lamp"},
        ],
        3: [
            {"spot": 0, "sub_cell": [1, 1], "offset": [0, 0], "item": "table_lamp"},
            {"spot": 1, "sub_cell": [2, 1], "offset": [0, 0], "item": "coffee_mug"},
            {"spot": 2, "sub_cell": [1, 2], "offset": [0, 0], "item": "open_book"},
            {"spot": 3, "sub_cell": [2, 2], "offset": [0, 0], "item": "table_lamp"},
        ],
    },
    "gaming_pc_desk": {
        r: [
            {"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"},
            {"spot": 1, "sub_cell": [1, 0], "offset": [0, 0], "item": "coffee_mug"},
            {"spot": 2, "sub_cell": [0, 1], "offset": [0, 0], "item": "open_book"},
            {"spot": 3, "sub_cell": [1, 1], "offset": [0, 0], "item": "none"},
        ] for r in range(4)
    },
    "side_table": {
        0: [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}],
        1: [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}],
        2: [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}],
        3: [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}],
    },
    "side_table_sm": {
        0: [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}],
        1: [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}],
        2: [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}],
        3: [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}],
    },
}


# Nombres en español amigables
NAMES_MAP = {
    "simple_chair": "Silla Simple de Madera",
    "gamer_chair": "Silla Gamer Pro",
    "plush_armchair": "Sillón Acolchado Cómodo",
    "simple_sofa": "Sofá Simple",
    "side_table": "Mesa de Noche / Velador",
    "table": "Mesa Rústica",
    "gaming_pc_desk": "Escritorio PC Gamer",
    "kitchen_fridge": "Refrigerador Inox",
    "floor_plant": "Planta Decorativa en Maceta",
    "bookshelf": "Estantería de Libros",
    "kitchen_sink": "Fregadero Inox",
    "kitchen_stove": "Cocina con Fogones",
    "bathroom_toilet": "Inodoro Cerámica",
    "single_bed": "Cama Individual (1x2)",
    "king_bed": "Cama King Size (2x2)",
    "coffee_mug": "Taza de Café Caliente",
    "table_lamp": "Lámpara de Noche",
    "open_book": "Libro Abierto",
    "cube_subcell": "Cubo Guía Subcelda (0.5x0.5)",
    "cube_1x1": "Cubo Guía 1x1",
    "cube_2x1": "Cubo Guía 2x1",
    "cube_2x2": "Cubo Guía 2x2",
    "art_painting": "Cuadro de Pared",
    "window_yellow": "Ventana Amarilla",
}

def scan_new_added_furniture():
    """
    Escanea recursivamente SOLO la carpeta 'furniture/new_added/' y retorna
    un diccionario indexado por item_id con sus rotaciones, imágenes, huella y metadatos.
    """
    # Cargar catálogo establecido para usar offsets y alturas reales ya calibradas
    established_catalog = {}
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    established_path = os.path.join(base_dir, "frontend", "assets", "images", "furniture", "furniture_catalog.json")
    if os.path.exists(established_path):
        try:
            with open(established_path, "r", encoding="utf-8") as ef:
                established_catalog = json.load(ef)
        except Exception:
            pass

    catalog = {}
    for root, dirs, files in os.walk(NEW_ADDED_DIR):
        rel_folder = os.path.relpath(root, NEW_ADDED_DIR).replace("\\", "/")
        category = rel_folder.split("/")[0] if rel_folder != "." else "general"

        footprint = "1x1"
        if "05x05" in rel_folder: footprint = "0.5x0.5"
        elif "1x2" in rel_folder: footprint = "1x2"
        elif "2x1" in rel_folder: footprint = "2x1"
        elif "2x2" in rel_folder: footprint = "2x2"
        elif "surface" in rel_folder: footprint = "surface"
        elif "walls" in rel_folder: footprint = "wall"

        for f in files:
            if not f.endswith(".png") or f.endswith("_front.png"):
                continue

            stem = f[:-4]
            # Normalizar guiones
            clean_stem = stem.replace("-", "_")

            # Detectar rotación
            rot_match = re.search(r'_rot(\d)$', clean_stem)
            if rot_match:
                rot_idx = int(rot_match.group(1))
                item_id = clean_stem[:rot_match.start()]
            else:
                rot_idx = 0
                item_id = clean_stem

            full_path = os.path.join(root, f)

            # Buscar en catálogo establecido por item_id o item_id_sm
            est_item = established_catalog.get(item_id) or established_catalog.get(f"{item_id}_sm")

            if item_id not in catalog:
                eff_footprint = est_item.get("footprint", footprint) if est_item else footprint
                eff_s_height = est_item.get("surface_height", (22 if "table" in item_id or "desk" in item_id or "side_table" in item_id else 0)) if est_item else (22 if "table" in item_id or "desk" in item_id or "side_table" in item_id else 0)
                eff_s_offset = est_item.get("surface_offset", [0, 0]) if est_item else [0, 0]
                eff_supports = est_item.get("supports_surface", any(k in item_id for k in ["table", "desk", "counter", "nightstand", "fridge"]) and eff_footprint != "surface") if est_item else (any(k in item_id for k in ["table", "desk", "counter", "nightstand", "fridge"]) and eff_footprint != "surface")

                eff_spots = est_item.get("surface_spots") if est_item else None
                if not eff_spots:
                    eff_spots = DEFAULT_SURFACE_SPOTS.get(item_id)
                if not eff_spots and eff_supports:
                    if eff_footprint == "0.5x0.5":
                        def_s = [{"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"}]
                    elif eff_footprint in ("2x1", "1x2"):
                        def_s = [
                            {"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"},
                            {"spot": 1, "sub_cell": [1, 0] if eff_footprint == "2x1" else [0, 1], "offset": [0, 0], "item": "coffee_mug"}
                        ]
                    elif eff_footprint == "2x2":
                        def_s = [
                            {"spot": 0, "sub_cell": [1, 1], "offset": [0, 0], "item": "table_lamp"},
                            {"spot": 1, "sub_cell": [2, 1], "offset": [0, 0], "item": "coffee_mug"},
                            {"spot": 2, "sub_cell": [1, 2], "offset": [0, 0], "item": "open_book"},
                            {"spot": 3, "sub_cell": [2, 2], "offset": [0, 0], "item": "table_lamp"},
                        ]
                    else: # 1x1
                        def_s = [
                            {"spot": 0, "sub_cell": [0, 0], "offset": [0, 0], "item": "table_lamp"},
                            {"spot": 1, "sub_cell": [1, 0], "offset": [0, 0], "item": "coffee_mug"},
                            {"spot": 2, "sub_cell": [0, 1], "offset": [0, 0], "item": "open_book"},
                            {"spot": 3, "sub_cell": [1, 1], "offset": [0, 0], "item": "none"},
                        ]
                    eff_spots = {r: [dict(x) for x in def_s] for r in range(4)}

                catalog[item_id] = {
                    "id": item_id,
                    "name": NAMES_MAP.get(item_id, item_id.replace("_", " ").title()),
                    "footprint": eff_footprint,
                    "folder": rel_folder,
                    "rotations": {},
                    "is_chair": item_id in DEFAULT_SEAT_CONFIGS or "chair" in item_id or "sofa" in item_id or "armchair" in item_id,
                    "supports_surface": eff_supports,
                    "surface_height": eff_s_height,
                    "surface_offset": eff_s_offset,
                    "surface_spots": eff_spots or {},
                }

            # Buscar si existe imagen frontal _front.png
            front_file = f.replace(".png", "_front.png")
            front_path = os.path.join(root, front_file)
            has_front = os.path.exists(front_path)

            try:
                with Image.open(full_path) as im:
                    cw, ch = im.size
            except Exception:
                cw, ch = 64, 64

            # Offset real: si existe en catálogo establecido y no es placeholder genérico, respetarlo
            est_rot = est_item.get("rotations", {}).get(str(rot_idx), {}) if est_item else {}
            saved_off = est_rot.get("sprite_offset") or (est_item.get("sprite_offset") if est_item else None)
            if saved_off and list(saved_off) not in ([-32, -44], [-32, -32]):
                final_off = list(saved_off)
            elif catalog[item_id]["footprint"] == "0.5x0.5":
                final_off = [-cw // 4, 8 - (ch // 2)]
            elif catalog[item_id]["footprint"] == "surface":
                final_off = [-32, -48]
            else:
                final_off = [-cw // 4, 16 - (ch // 2)]

            eff_spots_dict = catalog[item_id].get("surface_spots", {})
            rot_spots = est_rot.get("surface_spots") if est_rot else None
            if not rot_spots and eff_spots_dict:
                rot_spots = eff_spots_dict.get(rot_idx, eff_spots_dict.get(str(rot_idx), eff_spots_dict.get(0, [])))

            catalog[item_id]["rotations"][rot_idx] = {
                "image_path": full_path,
                "front_path": front_path if has_front else None,
                "canvas_size": [cw, ch],
                "sprite_offset": final_off,
                "surface_spots": [dict(s) for s in rot_spots] if rot_spots else [],
            }


    # Si hay muebles con solo rot0, replicar para 1..3
    for it in catalog.values():
        if 0 in it["rotations"] and len(it["rotations"]) < 4:
            base_rot = it["rotations"][0]
            for r in range(1, 4):
                if r not in it["rotations"]:
                    it["rotations"][r] = dict(base_rot)

    return catalog

def get_footprint_tiles(footprint, rot=0):
    """
    Retorna el tamaño en baldosas (tiles_w, tiles_h) y subcuadros (subs_u, subs_v)
    según la huella y rotación del mueble.
    """
    if footprint == "0.5x0.5":
        return 0.5, 0.5, 1, 1
    elif footprint == "1x1":
        return 1.0, 1.0, 2, 2
    elif footprint in ("2x1", "1x2"):
        # En rot 0 y 2: 2x1; en rot 1 y 3: 1x2 (o viceversa según el sprite)
        if footprint == "2x1":
            return (2.0, 1.0, 4, 2) if rot in (0, 2) else (1.0, 2.0, 2, 4)
        else:
            return (1.0, 2.0, 2, 4) if rot in (0, 2) else (2.0, 1.0, 4, 2)
    elif footprint == "2x2":
        return 2.0, 2.0, 4, 4
    elif footprint == "surface":
        return 0.5, 0.5, 1, 1
    return 1.0, 1.0, 2, 2

def subcell_to_screen(u, v, origin_x, origin_y, footprint="1x1"):
    """
    Convierte coordenadas de subcuadro (u, v) a coordenadas de pantalla (sx, sy).
    - Para 0.5x0.5: el único subcuadro (0, 0) está centrado en (origin_x, origin_y).
    - Para 1x1, 2x1, 1x2, 2x2: reproduce exactamente IsometricCoords.subGridToScreen de Flame:
      sx = origin_x + (u - v) * 32.0
      sy = origin_y + (u + v) * 16.0 - 16.0
    """
    if footprint == "0.5x0.5":
        sx = origin_x + (u - v) * 32.0
        sy = origin_y + (u + v) * 16.0
        return sx, sy
    sx = origin_x + (u - v) * (SUB_W / 2.0)
    sy = origin_y + (u + v) * (SUB_H / 2.0) - (SUB_H / 2.0)
    return sx, sy

def draw_isometric_tiles(draw, origin_x, origin_y, footprint="1x1", rot=0, show_subcells=True, highlight_subcell=None):
    """
    Dibuja los rombos isométricos del suelo correspondientes a la huella del mueble
    reproduciendo exactamente la geometría de Flame (isometric_furniture_component.dart).
    """
    if footprint == "0.5x0.5":
        cx, cy = origin_x, origin_y
        top_pt = (cx, cy - SUB_H / 2.0)
        right_pt = (cx + SUB_W / 2.0, cy)
        bottom_pt = (cx, cy + SUB_H / 2.0)
        left_pt = (cx - SUB_W / 2.0, cy)
        fill_col = (56, 189, 248, 140) if highlight_subcell is not None else (45, 55, 75, 100)
        outline_col = (56, 189, 248, 220)
        draw.polygon([top_pt, right_pt, bottom_pt, left_pt], fill=fill_col, outline=outline_col, width=2)
        if highlight_subcell is not None:
            draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 255, 255, 255), outline=(14, 165, 233, 255))
        return

    # Huella de baldosas completas (1x1, 2x1, 1x2, 2x2)
    gw, gh = 1, 1
    if footprint == "2x1":
        gw, gh = (2, 1) if rot in (0, 2) else (1, 2)
    elif footprint == "1x2":
        gw, gh = (1, 2) if rot in (0, 2) else (2, 1)
    elif footprint == "2x2":
        gw, gh = (2, 2)

    # 1. Dibujar subcuadros individuales dentro de cada baldosa
    for u in range(gw * 2):
        for v in range(gh * 2):
            cx, cy = subcell_to_screen(u, v, origin_x, origin_y, footprint=footprint)
            top_pt = (cx, cy - SUB_H / 2.0)
            right_pt = (cx + SUB_W / 2.0, cy)
            bottom_pt = (cx, cy + SUB_H / 2.0)
            left_pt = (cx - SUB_W / 2.0, cy)

            is_hl = (highlight_subcell is not None and highlight_subcell[0] == u and highlight_subcell[1] == v)
            if is_hl:
                fill_col = (56, 189, 248, 140)
                outline_col = (255, 255, 255, 240)
            else:
                alt = (u + v) % 2 == 0
                fill_col = (45, 55, 75, 100) if alt else (35, 45, 65, 100)
                outline_col = (100, 120, 150, 180) if show_subcells else (70, 85, 110, 80)

            draw.polygon([top_pt, right_pt, bottom_pt, left_pt], fill=fill_col, outline=outline_col)
            if is_hl:
                draw.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 255, 255, 255), outline=(14, 165, 233, 255))

    # 2. Contorno perimetral de cada baldosa completa (como Flame)
    for i in range(gw):
        for j in range(gh):
            tcx = origin_x + (i - j) * (TILE_W / 2.0)
            tcy = origin_y + (i + j) * (TILE_H / 2.0)
            t_top = (tcx, tcy - TILE_H / 2.0)
            t_right = (tcx + TILE_W / 2.0, tcy)
            t_bottom = (tcx, tcy + TILE_H / 2.0)
            t_left = (tcx - TILE_W / 2.0, tcy)
            draw.polygon([t_top, t_right, t_bottom, t_left], fill=None, outline=(56, 189, 248, 220), width=2)

def render_furniture_scene(
    furniture_item: dict,
    rot: int = 0,
    sprite_offset: tuple = None,
    show_tiles: bool = True,
    show_subcells: bool = True,
    show_bounding_box: bool = False,
    show_origin: bool = True,
    show_avatar: bool = False,
    avatar_config: dict = None,
    seat_spot: dict = None,
    surface_support_item: dict = None,
    surface_height: int = 0,
    surface_offset: tuple = (0, 0),
    surface_spots: list = None,
    active_surface_spot_idx: int = 0,
    show_all_surface_items: bool = True,
    show_surface_markers: bool = True,
    catalog_lookup: dict = None,
    zoom: int = 2
):

    """
    Renderiza la escena completa de inspección y calibración en resolución escalada (zoom 1x..4x).
    Permite:
    - Ver baldosa y sub-baldosas
    - Ajustar sprite_offset del mueble
    - Probar avatar sentado con orden de capas estricto
    - Probar objeto sobre superficie con línea guía y elevación
    """
    base_w, base_h = 360, 320
    canvas_img = Image.new("RGBA", (base_w, base_h), (18, 19, 28, 255))
    draw = ImageDraw.Draw(canvas_img)

    origin_x = base_w // 2
    origin_y = int(base_h * 0.62)

    footprint = furniture_item.get("footprint", "1x1") if furniture_item else "1x1"
    rot_data = furniture_item.get("rotations", {}).get(rot, {}) if furniture_item else {}

    off_x, off_y = sprite_offset if sprite_offset is not None else rot_data.get("sprite_offset", [-32, -48])

    hl_subcell = None
    if seat_spot and show_avatar:
        hl_subcell = seat_spot.get("sub_cell", [0, 0])

    # 1. Dibujar baldosas isométricas del suelo
    if show_tiles and footprint != "surface":
        draw_isometric_tiles(draw, origin_x, origin_y, footprint=footprint, rot=rot, show_subcells=show_subcells, highlight_subcell=hl_subcell)

    # 2. Si se está calibrando un objeto de superficie sobre una mesa de soporte
    support_canvas_pos = None
    if footprint == "surface" and surface_support_item:
        sup_rot_data = surface_support_item.get("rotations", {}).get(rot, {})
        sup_path = sup_rot_data.get("image_path")
        sup_fp = surface_support_item.get("footprint", "1x1")
        if sup_path and os.path.exists(sup_path):
            with Image.open(sup_path) as s_im:
                s_img = s_im.convert("RGBA")
                # Posición del soporte idéntica a Flame
                if sup_fp == "0.5x0.5":
                    sup_flame_x = -s_img.width / 4.0
                    sup_flame_y = 8.0 - (s_img.height / 2.0)
                else:
                    sup_rot_off = sup_rot_data.get("sprite_offset", [-32, -48])
                    sup_flame_x = sup_rot_off[0]
                    sup_flame_y = sup_rot_off[1]
                # Dibujar baldosas del soporte
                draw_isometric_tiles(draw, origin_x, origin_y, footprint=sup_fp, rot=rot, show_subcells=False)
                canvas_img.alpha_composite(s_img, (int(origin_x + sup_flame_x * 2), int(origin_y + sup_flame_y * 2)))

            # Línea guía de altura de superficie (en Flame la superficie en (0,0) está a origin_y - surface_height * 2)
            surf_y = int(origin_y - surface_height * 2)
            draw.line([(origin_x - 50, surf_y), (origin_x + 50, surf_y)], fill=(245, 158, 11, 200), width=1)
            draw.text((origin_x + 54, surf_y - 6), f"h = {surface_height}px", fill=(245, 158, 11, 255))


    # Cargar imagen base del mueble en resolución nativa HD 1:1
    furn_img = None
    furn_path = rot_data.get("image_path")
    if furn_path and os.path.exists(furn_path):
        with Image.open(furn_path) as im:
            furn_img = im.convert("RGBA")

    # Cargar imagen frontal si existe (_front.png) en resolución nativa HD 1:1
    front_img = None
    front_path = rot_data.get("front_path")
    if front_path and os.path.exists(front_path):
        with Image.open(front_path) as fim:
            front_img = fim.convert("RGBA")

    # 3. COMPOSICIÓN DE CAPAS (Base -> Backleg -> Avatar -> Frente -> Manos)
    cw = furn_img.width if furn_img else 128
    ch = furn_img.height if furn_img else 128
    r_w = cw / 2.0
    r_h = ch / 2.0

    if footprint == "0.5x0.5":
        if (off_x, off_y) in ((-32, -44), (-32, -32)):
            # Fórmula exacta de Flame para 0.5x0.5 (ground level a +8px Flame = +16px HD):
            flame_off_x = -cw / 4.0
            flame_off_y = 8.0 - (ch / 2.0)
        else:
            flame_off_x = off_x
            flame_off_y = off_y
        furn_x = int(origin_x + flame_off_x * 2)
        furn_y = int(origin_y + flame_off_y * 2)
    elif footprint == "surface":
        # Fórmula exacta de Flame para objetos de superficie en isometric_furniture_component.dart
        base_x = -r_w / 2.0
        eff_h = surface_height if surface_height > 0 else 18.0

        manual_adj_x = off_x + 32.0
        manual_adj_y = off_y + 48.0

        parent_dx = surface_offset[0] if len(surface_offset) > 0 else 0.0
        parent_dy = surface_offset[1] if len(surface_offset) > 1 else 0.0

        sup_fp = surface_support_item.get("footprint", "1x1") if surface_support_item else "1x1"

        # Si se especifica un spot del soporte (sub_cell y offset del spot):
        active_spot = None
        if surface_spots and 0 <= active_surface_spot_idx < len(surface_spots):
            active_spot = surface_spots[active_surface_spot_idx]
        elif surface_spots:
            active_spot = surface_spots[0]

        u, v = active_spot.get("sub_cell", [0, 0]) if active_spot else [0, 0]
        spot_soff = active_spot.get("offset", [0, 0]) if active_spot else [0, 0]

        eff_surf_dx = spot_soff[0] if active_spot else parent_dx
        eff_surf_dy = spot_soff[1] if active_spot else parent_dy

        # Total Flame 1x coords:
        # subGridToScreen(u, v): pos_x = (u - v)*16.0, pos_y = (u + v)*8.0 - 8.0
        # spriteOffset: sp_x = -r_w/2.0 + manual_adj_x + eff_surf_dx
        #               sp_y = 8.0 - r_h - eff_h + manual_adj_y + eff_surf_dy
        # flame_x = pos_x + sp_x = (u - v)*16.0 - r_w/2.0 + manual_adj_x + eff_surf_dx
        # flame_y = pos_y + sp_y = (u + v)*8.0 - r_h - eff_h + manual_adj_y + eff_surf_dy
        flame_x = (u - v) * 16.0 - r_w / 2.0 + manual_adj_x + eff_surf_dx
        flame_y = (u + v) * 8.0 - r_h - eff_h + manual_adj_y + eff_surf_dy
        furn_x = int(origin_x + flame_x * 2)
        furn_y = int(origin_y + flame_y * 2)

        # Si show_surface_markers, dibujar también los marcadores de los spots en el soporte
        if show_surface_markers and surface_spots:
            for s in surface_spots:
                s_idx = s.get("spot", 0)
                su, sv = s.get("sub_cell", [0, 0])
                ssoff = s.get("offset", [0, 0])
                stx = int(origin_x + (su - sv) * 32.0 + ssoff[0] * 2)
                sty = int(origin_y + (su + sv) * 16.0 - eff_h * 2 + ssoff[1] * 2)
                is_act = (s_idx == active_surface_spot_idx)
                f_c = (14, 165, 233, 230) if is_act else (245, 158, 11, 200)
                r_c = (255, 255, 255, 255) if is_act else (30, 41, 59, 220)
                rad = 7 if is_act else 6
                draw.ellipse([stx - rad, sty - rad, stx + rad, sty + rad], fill=f_c, outline=r_c, width=2 if is_act else 1)
                draw.text((stx - 3, sty - 6), str(s_idx), fill=(255, 255, 255, 255))

    else:
        # Items de suelo estándar (1x1, 1x2, 2x1, 2x2):
        furn_x = int(origin_x + off_x * 2)
        furn_y = int(origin_y + off_y * 2)

    # Capa 1: Base del mueble
    if furn_img:
        canvas_img.alpha_composite(furn_img, (furn_x, furn_y))

    # Capa 1.5: Puntos de Superficie y Objetos Colocados (si el mueble actual soporta superficie)
    if footprint != "surface" and furniture_item and furniture_item.get("supports_surface") and surface_spots:
        eff_table_h = surface_height if surface_height > 0 else furniture_item.get("surface_height", 18)
        # Ordenar de atrás hacia adelante para profundidad isométrica
        sorted_spots = sorted(
            surface_spots,
            key=lambda s: (
                s.get("sub_cell", [0, 0])[0] + s.get("sub_cell", [0, 0])[1],
                s.get("sub_cell", [0, 0])[1]
            )
        )

        for s in sorted_spots:
            s_idx = s.get("spot", 0)
            u, v = s.get("sub_cell", [0, 0])
            soff = s.get("offset", [0, 0])
            item_id = s.get("item", "table_lamp")

            it_dict = (catalog_lookup or {}).get(item_id) if item_id and item_id != "none" else None
            it_rot_data = (it_dict.get("rotations", {}).get(rot) or it_dict.get("rotations", {}).get(0, {})) if it_dict else {}
            it_off = it_rot_data.get("sprite_offset") or (it_dict.get("sprite_offset") if it_dict else [-32, -48])
            manual_adj_x = (it_off[0] + 32.0)
            manual_adj_y = (it_off[1] + 48.0)

            # Posición base en pantalla 100% idéntica a Flame (en coordenadas HD 2x):
            tx = int(origin_x + (u - v) * 32.0 + manual_adj_x * 2 + soff[0] * 2)
            ty = int(origin_y + (u + v) * 16.0 - eff_table_h * 2 + manual_adj_y * 2 + soff[1] * 2)

            # Dibujar el objeto sobre el spot si corresponde
            if (show_all_surface_items or s_idx == active_surface_spot_idx) and item_id and item_id != "none":
                if it_dict:
                    it_path = it_rot_data.get("image_path")
                    if it_path and os.path.exists(it_path):
                        with Image.open(it_path) as sim:
                            s_rgba = sim.convert("RGBA")
                            # El objeto de superficie apoya su base inferior centrada en el spot
                            ix = int(tx - s_rgba.width // 2)
                            iy = int(ty - s_rgba.height)
                            canvas_img.alpha_composite(s_rgba, (ix, iy))

            # Dibujar marcador visual del spot (punto de contacto exacto sobre la superficie de la mesa)
            if show_surface_markers:
                stx = int(origin_x + (u - v) * 32.0 + soff[0] * 2)
                sty = int(origin_y + (u + v) * 16.0 - eff_table_h * 2 + soff[1] * 2)
                is_active = (s_idx == active_surface_spot_idx)
                fill_c = (14, 165, 233, 230) if is_active else (245, 158, 11, 200)
                ring_c = (255, 255, 255, 255) if is_active else (30, 41, 59, 220)
                r = 7 if is_active else 6
                draw.ellipse([stx - r, sty - r, stx + r, sty + r], fill=fill_c, outline=ring_c, width=2 if is_active else 1)
                draw.text((stx - 3, sty - 6), str(s_idx), fill=(255, 255, 255, 255))


    # Capas de Avatar Sentado
    if show_avatar and avatar_config is not None:
        # Dirección diagonal del avatar según rotación del mueble
        rot_to_sit_dir = {0: 8, 1: 2, 2: 4, 3: 6}
        sit_dir = rot_to_sit_dir.get(rot, 2)

        u, v = seat_spot.get("sub_cell", [0, 0]) if seat_spot else [0, 0]
        v_off = seat_spot.get("visual_offset", [0.0, 0.0]) if seat_spot else [0.0, 0.0]

        # Posición del asiento en pantalla
        spot_sx, spot_sy = subcell_to_screen(u, v, origin_x, origin_y, footprint=footprint)

        # Avatar 64x128 anclado en los pies (Flame: centerTile.x - avatarWidth/2 = -15 Flame units = -30 px HD)
        av_x = int(spot_sx - 30 + v_off[0] * 2)
        av_y = int(spot_sy - 112 + v_off[1] * 2)


        # Obtener capas separadas del avatar sentado (full 64x128 HD, sin reescalar)
        av_layers = octo_engine.compose_octo_avatar(
            avatar_config, direction=sit_dir, action="sit", frame=2, separate_sitting_layers=True
        )

        # Capa 2: Pierna trasera (Backleg) para NE y NW
        if sit_dir in (4, 6) and av_layers.get("backleg"):
            canvas_img.alpha_composite(av_layers["backleg"], (av_x, av_y))

        # Capa 3: Avatar Sentado (Cuerpo, ropa, cabeza)
        if av_layers.get("main"):
            canvas_img.alpha_composite(av_layers["main"], (av_x, av_y))

        # Capa 4: Frente del mueble (_front.png) por encima del avatar
        if front_img:
            canvas_img.alpha_composite(front_img, (furn_x, furn_y))

        # Capa 5: Manos del avatar sobre el frente/apoyabrazos
        if av_layers.get("hands"):
            canvas_img.alpha_composite(av_layers["hands"], (av_x, av_y))

        # Dibujar punto del SeatSpot
        draw.ellipse([spot_sx - 3, spot_sy - 3, spot_sx + 3, spot_sy + 3], fill=(239, 68, 68, 255))
        draw.line([(spot_sx, spot_sy), (av_x + 32, av_y + 112)], fill=(239, 68, 68, 180), width=1)

    elif front_img:
        # Si no hay avatar, estampar el front directamente
        canvas_img.alpha_composite(front_img, (furn_x, furn_y))

    # 4. Guías visuales auxiliares
    if show_bounding_box and furn_img:
        draw.rectangle(
            [furn_x, furn_y, furn_x + furn_img.width, furn_y + furn_img.height],
            outline=(234, 179, 8, 180), width=1
        )

    if show_origin:
        # Punto de origen (0, 0)
        draw.ellipse([origin_x - 3, origin_y - 3, origin_x + 3, origin_y + 3], fill=(244, 63, 94, 255), outline=(255, 255, 255, 255))
        draw.line([(origin_x - 6, origin_y), (origin_x + 6, origin_y)], fill=(255, 255, 255, 200))
        draw.line([(origin_x, origin_y - 6), (origin_x, origin_y + 6)], fill=(255, 255, 255, 200))

    # Escalar según zoom con filtro NEAREST para pixel-art nítido
    if zoom > 1:
        target_w = base_w * zoom
        target_h = base_h * zoom
        canvas_img = canvas_img.resize((target_w, target_h), resample=Image.Resampling.NEAREST)

    return canvas_img

def generate_chair_seat_dart_code(item_id, seat_data_by_rot):
    """
    Genera el bloque de código Dart listo para pegar en chair_seat_config.dart.
    """
    lines = [f"    '{item_id}': {{"]
    for rot in range(4):
        spots = seat_data_by_rot.get(rot, [])
        lines.append(f"      {rot}: [")
        for s in spots:
            sub = s.get("sub_cell", [0, 0])
            vo = s.get("visual_offset", [0.0, 0.0])
            to = s.get("tap_offset", [0.0, -18.0])
            lines.append(
                f"        SeatSpot(slotIndex: {s.get('slot', 0)}, "
                f"subCell: const Point({sub[0]}, {sub[1]}), "
                f"visualOffset: Vector2({vo[0]:.1f}, {vo[1]:.1f}), "
                f"tapOffset: Vector2({to[0]:.1f}, {to[1]:.1f})),"
            )
        lines.append("      ],")
    lines.append("    },")
    return "\n".join(lines)

def generate_surface_json_code(item_id, surface_height, surface_offset):
    """
    Genera el fragmento de configuración JSON para un mueble que soporta superficie o un objeto surface.
    """
    data = {
        item_id: {
            "surface_height": surface_height,
            "surface_offset": list(surface_offset)
        }
    }
    return json.dumps(data, indent=2)

def generate_surface_spots_json_code(item_id, surface_height, surface_spots_by_rot):
    """
    Genera el fragmento de configuración JSON con múltiples surface_spots para un mueble que soporta superficie.
    """
    first_off = [0, 0]
    if isinstance(surface_spots_by_rot, list) and surface_spots_by_rot:
        first_off = surface_spots_by_rot[0].get("offset", [0, 0])
    elif isinstance(surface_spots_by_rot, dict):
        rot0 = surface_spots_by_rot.get(0, surface_spots_by_rot.get("0", []))
        if rot0:
            first_off = rot0[0].get("offset", [0, 0])

    data = {
        item_id: {
            "surface_height": surface_height,
            "surface_offset": list(first_off),
            "supports_surface": True,
            "surface_spots": surface_spots_by_rot
        }
    }
    return json.dumps(data, indent=2, ensure_ascii=False)

