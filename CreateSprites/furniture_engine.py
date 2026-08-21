"""
furniture_engine.py - Motor de Renderizado y Grilla de Habitación Isométrica
Gestiona coordenadas de baldosas, orden de profundidad (Depth Sorting),
perspectiva diagonal de paredes, rotación en 4 ángulos y selección interactiva de muebles.
"""

import os
import json
from PIL import Image, ImageDraw
import color_engine
import furniture_generator

def get_tile_dimensions(resolution="64x128"):
    """
    Retorna (tile_w, tile_h, scale_factor):
    - Avatar 64x128 -> Muebles 128x256 (Baldosa 128x64, s=2.0)
    - Avatar 32x64  -> Muebles 64x128  (Baldosa 64x32, s=1.0)
    """
    if str(resolution) in ("32x64", "32", "mini"):
        return 64, 32, 1.0
    # Por defecto para Avatar 64x128
    return 128, 64, 2.0

def grid_to_screen(gx, gy, origin_x, origin_y, resolution="64x128"):
    """Convierte coordenadas de grilla (gx, gy) a coordenadas de pantalla (sx, sy)."""
    tile_w, tile_h, _ = get_tile_dimensions(resolution)
    sx = origin_x + (gx - gy) * (tile_w / 2.0)
    sy = origin_y + (gx + gy) * (tile_h / 2.0)
    return sx, sy

def screen_to_grid(sx, sy, origin_x, origin_y, resolution="64x128"):
    """Convierte coordenadas de pantalla (sx, sy) a coordenadas de baldosa (gx, gy)."""
    tile_w, tile_h, _ = get_tile_dimensions(resolution)
    dx = sx - origin_x
    dy = sy - origin_y
    gx = (dx / (tile_w / 2.0) + dy / (tile_h / 2.0)) / 2.0
    gy = (dy / (tile_h / 2.0) - dx / (tile_w / 2.0)) / 2.0
    return round(gx), round(gy)

def load_furniture_catalog(resolution="64x128"):
    """
    Carga el catálogo JSON de muebles correspondiente:
    - Para Avatar 64x128: Muebles 128x256 ('assets_128x256/furniture')
    - Para Avatar 32x64: Muebles 64x128 ('assets/furniture')
    """
    if str(resolution) in ("32x64", "32", "mini"):
        base_dir = "assets/furniture"
    else:
        base_dir = "assets_128x256/furniture"

    meta_path = os.path.join(base_dir, "furniture_catalog.json")
    if os.path.exists(meta_path):
        with open(meta_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def draw_isometric_floor_and_walls(d, grid_w, grid_h, origin_x, origin_y, resolution="64x128"):
    """Dibuja el suelo con baldosas de madera y las paredes Norte y Oeste."""
    tile_w, tile_h, s = get_tile_dimensions(resolution)
    wall_height = int(96 * s)

    # 1. Paredes de la habitación
    c0x, c0y = grid_to_screen(0, 0, origin_x, origin_y, resolution)
    cnx, cny = grid_to_screen(grid_w, 0, origin_x, origin_y, resolution)
    cwx, cwy = grid_to_screen(0, grid_h, origin_x, origin_y, resolution)

    # Pared Oeste (Lado Izquierdo)
    wall_west = [
        (c0x, c0y - wall_height),
        (cwx, cwy - wall_height),
        (cwx, cwy),
        (c0x, c0y)
    ]
    d.polygon(wall_west, fill=(195, 205, 215, 255), outline=(130, 140, 150, 255))

    # Pared Norte (Lado Derecho)
    wall_north = [
        (c0x, c0y - wall_height),
        (cnx, cny - wall_height),
        (cnx, cny),
        (c0x, c0y)
    ]
    d.polygon(wall_north, fill=(215, 225, 235, 255), outline=(140, 150, 160, 255))

    # Zócalos / Rodapiés
    skirt_h = int(8 * s)
    d.polygon([(c0x, c0y - skirt_h), (cwx, cwy - skirt_h), (cwx, cwy), (c0x, c0y)], fill=(120, 80, 50, 255), outline=(70, 45, 25, 255))
    d.polygon([(c0x, c0y - skirt_h), (cnx, cny - skirt_h), (cnx, cny), (c0x, c0y)], fill=(150, 100, 60, 255), outline=(80, 50, 30, 255))

    # 2. Baldosas del Suelo (Parquet)
    for gy in range(grid_h):
        for gx in range(grid_w):
            cx, cy = grid_to_screen(gx, gy, origin_x, origin_y, resolution)
            top_pt = (cx, cy - tile_h / 2.0)
            right_pt = (cx + tile_w / 2.0, cy)
            bottom_pt = (cx, cy + tile_h / 2.0)
            left_pt = (cx - tile_w / 2.0, cy)

            tile_color = (215, 175, 125, 255) if (gx + gy) % 2 == 0 else (205, 165, 115, 255)
            d.polygon([top_pt, right_pt, bottom_pt, left_pt], fill=tile_color, outline=(170, 130, 85, 255))


def render_isometric_room(placed_items, avatar_config=None, avatar_pos=(2, 2), avatar_dir="down", resolution="64x128", grid_size=(6, 6), selected_index=None):
    """
    Renderiza la escena completa de la habitación isométrica con soporte para rotación en 4 ángulos y selección interactiva.
    """
    tile_w, tile_h, s = get_tile_dimensions(resolution)
    grid_w, grid_h = grid_size

    canvas_w = int((grid_w + grid_h) * (tile_w / 2.0) + 120 * s)
    canvas_h = int((grid_w + grid_h) * (tile_h / 2.0) + 180 * s)

    room_img = Image.new("RGBA", (canvas_w, canvas_h), (24, 26, 38, 255))
    d = ImageDraw.Draw(room_img)

    origin_x = canvas_w // 2
    origin_y = int(120 * s)

    # 1. Dibujar estructura base (Paredes + Suelo)
    draw_isometric_floor_and_walls(d, grid_w, grid_h, origin_x, origin_y, resolution)

    # 2. Preparar cola de elementos a dibujar con orden de profundidad
    render_queue = []
    catalog = load_furniture_catalog(resolution)
    if str(resolution) in ("32x64", "32", "mini"):
        base_assets_dir = "assets/furniture"
    else:
        base_assets_dir = "assets_128x256/furniture"

    for idx, item in enumerate(placed_items):
        item_id = item.get("id")
        rot = item.get("rot", 0)
        gx = item.get("gx", 0)
        gy = item.get("gy", 0)
        nudge_x = item.get("nudge_x", 0)
        nudge_y = item.get("nudge_y", 0)
        parent_id = item.get("parent_id", None)

        base_meta = catalog.get(item_id, {})
        # Obtener metadata específica de la rotación
        rot_dict = base_meta.get("rotations", {})
        meta = rot_dict.get(str(rot), base_meta)

        # Buscar el archivo PNG de la rotación
        rot_png = os.path.join(base_assets_dir, f"{item_id}_rot{rot}.png")
        if not os.path.exists(rot_png):
            rot_png = os.path.join(base_assets_dir, f"{item_id}.png")

        if not os.path.exists(rot_png):
            continue

        item_img = Image.open(rot_png).convert("RGBA")
        footprint = meta.get("footprint", "1x1")
        offset = meta.get("sprite_offset", [-item_img.width // 2, int(16 * s) - item_img.height])

        # Anclaje automático en la pared según huella
        if footprint == "wall_n":
            sx, sy = grid_to_screen(gx, 0, origin_x, origin_y, resolution)
        elif footprint == "wall_w":
            sx, sy = grid_to_screen(0, gy, origin_x, origin_y, resolution)
        else:
            sx, sy = grid_to_screen(gx, gy, origin_x, origin_y, resolution)

        draw_x = int(sx + offset[0] + nudge_x)
        draw_y = int(sy + offset[1] + nudge_y)

        # Ajuste para objetos sobremesa y paredes
        if footprint == "surface" and parent_id:
            parent_meta = catalog.get(parent_id, {})
            p_surf_h = parent_meta.get("surface_height", int(16 * s))
            draw_y -= p_surf_h
            depth_key = (gx + gy) * 1000 + 50
        elif "wall" in footprint:
            depth_key = -100 + (gx if footprint == "wall_n" else gy) * 5
        else:
            depth_key = (gx + gy) * 1000 + 10

        is_selected = (idx == selected_index)

        render_queue.append({
            "type": "furniture",
            "img": item_img,
            "pos": (draw_x, draw_y),
            "depth_key": depth_key,
            "name": meta.get("name", item_id),
            "is_selected": is_selected,
            "gx": gx,
            "gy": gy
        })

    # 3. Insertar al Avatar en la cola de profundidad
    if avatar_config is not None:
        agx, agy = avatar_pos
        asx, asy = grid_to_screen(agx, agy, origin_x, origin_y, resolution)
        avatar_img = color_engine.composite_avatar(avatar_config, direction=avatar_dir, frame=0, resolution=resolution)

        foot_anchor_y = int(16 * s)
        avatar_x = int(asx - avatar_img.width // 2)
        avatar_y = int(asy + foot_anchor_y - avatar_img.height)
        avatar_depth_key = (agx + agy) * 1000 + 20

        render_queue.append({
            "type": "avatar",
            "img": avatar_img,
            "pos": (avatar_x, avatar_y),
            "depth_key": avatar_depth_key,
            "name": "Avatar",
            "is_selected": False,
            "gx": agx,
            "gy": agy
        })

    # 4. Ordenar y estampar por profundidad
    render_queue.sort(key=lambda item: item["depth_key"])

    for item in render_queue:
        room_img.alpha_composite(item["img"], item["pos"])

        # Si el elemento está seleccionado, dibujar un halo/borde brillante en la habitación
        if item.get("is_selected"):
            ix, iy = item["pos"]
            iw, ih = item["img"].size
            d.rectangle([ix - 1, iy - 1, ix + iw + 1, iy + ih + 1], outline=(56, 189, 248, 255), width=2)

    return room_img


def get_default_cozy_room_items():
    """Retorna una configuración de habitación predeterminada con rotaciones multi-ángulo."""
    return [
        {"id": "curtained_window_n", "gx": 1, "gy": 0, "rot": 0},
        {"id": "art_painting_w", "gx": 0, "gy": 1, "rot": 1},
        {"id": "king_bed", "gx": 0, "gy": 2, "rot": 0},
        {"id": "side_table", "gx": 0, "gy": 4, "rot": 0},
        {"id": "table_lamp", "gx": 0, "gy": 4, "parent_id": "side_table", "rot": 0},
        {"id": "front_sofa", "gx": 2, "gy": 4, "rot": 0},
        {"id": "cozy_rug_2x2", "gx": 2, "gy": 2, "rot": 0},
        {"id": "kitchen_counter", "gx": 4, "gy": 0, "rot": 0},
        {"id": "cooking_pot", "gx": 4, "gy": 0, "parent_id": "kitchen_counter", "rot": 0},
        {"id": "potted_plant", "gx": 5, "gy": 4, "rot": 0},
    ]
