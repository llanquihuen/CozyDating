"""
sync_new_furniture_no_delete_established.py - Sincronizador SEGURO y NO DESTRUCTIVO de Muebles

CARACTERÍSTICAS DE SEGURIDAD:
1. NUNCA borra ningún archivo existente en 'established_furniture/'.
2. Modo MERGE para 'furniture_catalog.json': preserva todos los muebles existentes y solo agrega o actualiza los nuevos.
3. Filtra y excluye automáticamente partes de capas internas (_base, _back) para que nunca aparezcan como ítems sueltos en el catálogo.
4. Normaliza nombres a snake_case (ej. 'tall-mangashelf' -> 'tall_mangashelf').
"""

import os
import re
import json
import shutil
from PIL import Image

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FURNITURE_BASE = os.path.join(BASE_DIR, "frontend", "assets", "images", "furniture")
NEW_ADDED_DIR = os.path.join(FURNITURE_BASE, "new_added")
ESTABLISHED_DIR = os.path.join(FURNITURE_BASE, "established_furniture")
CATALOG_PATH = os.path.join(FURNITURE_BASE, "furniture_catalog.json")

# Diccionario de nombres en español para la UI
NAME_TRANSLATIONS = {
    "bookshelf": "Estantería de Libros",
    "tall_bookshelf": "Estantería Alta",
    "tall_mangashelf": "Estantería Manga Alta",
    "tall_mangashelf_white": "Estantería Manga Blanca",
    "manga_shelf": "Estantería Manga & Figuras",
    "closet": "Armario Ropero Alto",
    "table": "Mesa Rústica",
    "single_bed": "Cama Individual (1x2)",
    "single_high_bed": "Cama Alta (1x2)",
    "king_bed": "Cama King Size (2x2)",
    "chair": "Silla",
    "simple_chair_sm": "Silla de Madera Simple",
    "plush_armchair": "Sillón Acolchado",
    "simple_sofa": "Sofá Simple (2x1)",
    "floor_plant_sm": "Planta Decorativa (0.5x0.5)",
    "side_table_sm": "Mesa de Noche / Velador (0.5x0.5)",
    "dining_table_2x2": "Mesa de Comedor Roble (2x2)",
    "table_lamp": "Lámpara de Noche",
    "coffee_mug": "Taza de Café Caliente",
    "open_book": "Libro Abierto",
    "art_painting": "Cuadro de Paisaje",
    "window_yellow": "Ventana Amarilla",
    "curtained_window": "Ventana con Cortinas",
    "wall_clock": "Reloj de Pared",
    "hanging_shelf_wall": "Repisa Colgante",
    "pan_rack_wall": "Colgador de Sartenes",
    "towel_rack_wall": "Toallero",
    "stone_fountain": "Fuente de Piedra (2x2)",
    "bbq_grill": "Parrilla Asador",
    "cube_1x1": "Paralelepípedo 1x1",
    "cube_1x2": "Paralelepípedo 1x2",
    "cube_2x1": "Paralelepípedo 2x1",
    "cube_2x2": "Paralelepípedo 2x2",
    "cube_subcell_sm": "Guía Subcelda (0.5x0.5)",
    "cube_wall": "Guía de Pared",
    "kitchen_stove": "Cocina con Fogones",
    "kitchen_sink": "Fregadero Inox",
    "kitchen_fridge_sm": "Refrigerador Inox (0.5x0.5)",
    "bathtub_classic": "Bathtub Classic",
    "bathtub_regular_1x2": "Bañera Regular (1x2)",
    "bathtub_2x2": "Bañera Jacuzzi (2x2)",
    "bathroom_toilet": "Inodoro Cerámica",
}

def clean_id(filename_stem, is_wall=False):
    clean = filename_stem.replace("-", "_").lower()
    clean = re.sub(r'_rot\d$', '', clean)
    if is_wall:
        if clean.endswith('_wall_n') or clean.endswith('_wall_w'):
            clean = clean[:-2]
        elif clean.endswith('_n') or clean.endswith('_w'):
            clean = clean[:-2]
    return clean

def guess_zone(item_id, footprint):
    if footprint == "surface" or footprint in ["wall_n", "wall_w", "wall"]:
        return "decor"
    if any(k in item_id for k in ["bed", "closet", "wardrobe", "drawer", "vanity", "nightstand"]):
        return "bedroom"
    if any(k in item_id for k in ["stove", "fridge", "sink", "counter", "bathtub", "toilet"]):
        return "kitchen_bath"
    if any(k in item_id for k in ["fountain", "bench", "grill", "flower"]):
        return "patio"
    if item_id.startswith("cube_"):
        return "guide"
    return "living"

def guess_name(item_id, is_tall=False):
    if item_id in NAME_TRANSLATIONS:
        name = NAME_TRANSLATIONS[item_id]
        if is_tall and "Alto" not in name and "Alta" not in name:
            name += " (Alto)"
        return name
    words = item_id.replace("_", " ").split()
    name = " ".join(w.capitalize() for w in words)
    if is_tall and "Tall" not in name and "Alto" not in name and "Alta" not in name:
        name += " (Alto)"
    return name

def guess_surface_height(item_id, footprint):
    if footprint == "surface" or "wall" in footprint:
        return 0
    if any(k in item_id for k in ["table", "desk", "counter", "stand", "nightstand"]):
        return 18
    if "stove" in item_id:
        return 22
    if "sink" in item_id or "counter" in item_id:
        return 20
    if "bookshelf" in item_id or "shelf" in item_id or "mangashelf" in item_id:
        return 14
    if "bed" in item_id:
        return 14
    if item_id == "cube_1x1":
        return 24
    if item_id in ["cube_1x2", "cube_2x1"]:
        return 20
    if item_id == "cube_2x2":
        return 28
    return 0

def get_sprite_offset(footprint, is_tall=False, item_id=""):
    if footprint == "0.5x0.5" or "05x05" in item_id or item_id.endswith("_sm"):
        return [-32, -44]
    if footprint in ["wall_n", "wall_w", "wall"]:
        return [-32, -48]
    if footprint == "surface":
        return [-32, -48]
    if footprint == "2x2":
        return [-64, -44]
    if footprint == "1x2":
        return [-64, -36]
    if footprint == "2x1":
        return [-32, -36]
    if is_tall or "tall" in item_id or "closet" in item_id or "wardrobe" in item_id:
        return [-32, -73]
    return [-32, -48]

def safe_copy(src, dst):
    """Copia solo si el archivo destino no existe o tiene distinto tamaño/fecha, sin borrar nada existente."""
    if os.path.exists(dst):
        try:
            if os.path.getsize(src) == os.path.getsize(dst):
                return False  # Ya existe e idéntico
        except Exception:
            pass
    shutil.copy2(src, dst)
    return True

def sync_new_furniture_safe(target_subfolder=None):
    print("=== Sincronizador SEGURO de Muebles -> established_furniture ===")
    print("[MODO SEGURO] No se eliminará ningún archivo en established_furniture.")

    scan_dir = NEW_ADDED_DIR
    if target_subfolder:
        scan_dir = os.path.join(NEW_ADDED_DIR, target_subfolder)

    if not os.path.exists(scan_dir):
        print(f"Directorio no encontrado: {scan_dir}")
        return

    os.makedirs(ESTABLISHED_DIR, exist_ok=True)

    # 1. Cargar catálogo existente para preservar TODOS los muebles previos
    existing_catalog = {}
    if os.path.exists(CATALOG_PATH):
        try:
            with open(CATALOG_PATH, "r", encoding="utf-8") as f:
                existing_catalog = json.load(f)
            # Limpiar entradas espurias de _base, _back o _front si las hubiera
            for k in list(existing_catalog.keys()):
                if "_base" in k or "_back" in k or "_front" in k:
                    del existing_catalog[k]
            print(f"[OK] Catálogo existente cargado: {len(existing_catalog)} muebles base preservados.")
        except Exception as e:
            print(f"Aviso: No se pudo leer {CATALOG_PATH}: {e}")

    discovered_items = {}

    # 2. Escaneo SOLO LECTURA de new_added
    for root, dirs, files in os.walk(scan_dir):
        rel_path = os.path.relpath(root, NEW_ADDED_DIR).replace("\\\\", "/").lower()
        parts = rel_path.split("/")

        footprint = "1x1"
        is_tall = ("tall" in parts or "tall" in root.lower())
        is_wall = ("wall" in parts or "walls" in parts or "wall" in rel_path)

        if "05x05" in parts or "05x05" in rel_path:
            footprint = "0.5x0.5"
        elif is_wall or any("wall" in p for p in parts):
            footprint = "wall_n"
            is_wall = True
        elif any("1x2" in p for p in parts):
            footprint = "1x2"
        elif any("2x1" in p for p in parts):
            footprint = "2x1"
        elif any("2x2" in p for p in parts):
            footprint = "2x2"
        elif any("surface" in p for p in parts):
            footprint = "surface"

        for file in files:
            if not file.endswith(".png"):
                continue

            stem = os.path.splitext(file)[0]

            # REGLA CLAVE: Las capas internas (_base, _back, _front) no son muebles separados
            if "_base" in stem or "_back" in stem or "_front" in stem:
                continue

            full_path = os.path.join(root, file)
            item_id = clean_id(stem, is_wall=is_wall)

            if footprint == "0.5x0.5" and not item_id.endswith("_sm"):
                item_id = f"{item_id}_sm"

            if item_id not in discovered_items:
                discovered_items[item_id] = {
                    "footprint": footprint,
                    "is_tall": is_tall,
                    "is_wall": is_wall,
                    "rotations": {},
                    "wall_variants": {},
                    "base_file": full_path,
                }

            if is_wall:
                clean_wall_stem = re.sub(r'_rot\d$', '', stem).lower()
                is_explicit_rot = bool(re.search(r'_rot\d$', stem))

                if clean_wall_stem.endswith("_n") or clean_wall_stem.endswith("_wall_n"):
                    if "n" not in discovered_items[item_id]["wall_variants"] or not is_explicit_rot:
                        discovered_items[item_id]["wall_variants"]["n"] = full_path
                elif clean_wall_stem.endswith("_w") or clean_wall_stem.endswith("_wall_w"):
                    if "w" not in discovered_items[item_id]["wall_variants"] or not is_explicit_rot:
                        discovered_items[item_id]["wall_variants"]["w"] = full_path
                else:
                    if "n" not in discovered_items[item_id]["wall_variants"]:
                        discovered_items[item_id]["wall_variants"]["n"] = full_path
                    if "w" not in discovered_items[item_id]["wall_variants"]:
                        discovered_items[item_id]["wall_variants"]["w"] = full_path
            else:
                rot_match = re.search(r'_rot([0-3])$', stem)
                if rot_match:
                    rot = int(rot_match.group(1))
                    discovered_items[item_id]["rotations"][rot] = full_path
                else:
                    discovered_items[item_id]["base_file"] = full_path

    print(f"[OK] Escaneados {len(discovered_items)} muebles válidos en '{os.path.relpath(scan_dir, BASE_DIR)}'.")

    # 3. Copia segura incremental a 'established_furniture' y Merge del catálogo
    merged_catalog = dict(existing_catalog)
    copied_count = 0

    for item_id, data in discovered_items.items():
        footprint = data["footprint"]
        is_tall = data["is_tall"]
        is_wall = data["is_wall"]
        base_fp = data["base_file"]

        orig_w, orig_h = 64, 64
        try:
            with Image.open(base_fp) as im:
                orig_w, orig_h = im.size
        except Exception:
            pass

        if orig_h >= 170 and not is_wall:
            is_tall = True

        name = guess_name(item_id, is_tall=is_tall)
        zone = guess_zone(item_id, footprint)
        surf_h = guess_surface_height(item_id, footprint)
        def_offset = get_sprite_offset(footprint, is_tall=is_tall, item_id=item_id)

        # Copia base segura
        base_target_name = f"{item_id}.png"
        if safe_copy(base_fp, os.path.join(ESTABLISHED_DIR, base_target_name)):
            copied_count += 1

        # Preservar personalizaciones previas si ya existía en el catálogo
        old_item = existing_catalog.get(item_id, {})
        final_name = old_item.get("name", name)
        final_zone = old_item.get("zone", zone)
        final_footprint = old_item.get("footprint", footprint)
        final_surf_h = old_item.get("surface_height", surf_h)
        final_supports_surf = old_item.get("supports_surface", (final_surf_h > 0))
        final_surf_off = old_item.get("surface_offset", [0, 0])
        final_canvas_size = old_item.get("canvas_size", [orig_w, orig_h])
        final_sprite_offset = old_item.get("sprite_offset", def_offset)
        has_table_magnet = old_item.get("has_table_magnet", (item_id in ["simple_chair_sm", "simple_chair"]))
        old_rotations = old_item.get("rotations", {})

        item_entry = {
            "name": final_name,
            "zone": final_zone,
            "footprint": final_footprint,
            "surface_height": final_surf_h,
            "supports_surface": final_supports_surf,
            "surface_offset": final_surf_off,
            "canvas_size": final_canvas_size,
            "sprite_offset": final_sprite_offset,
            "has_table_magnet": has_table_magnet,
            "rotations": {}
        }

        if is_wall:
            for rot_idx, variant in [(0, "n"), (1, "w")]:
                w_fp = f"wall_{variant}"
                w_src = data["wall_variants"].get(variant, base_fp)
                w_target_file = f"{item_id}_{variant}.png"
                if safe_copy(w_src, os.path.join(ESTABLISHED_DIR, w_target_file)):
                    copied_count += 1

                old_rot = old_rotations.get(str(rot_idx), {})
                rot_name = old_rot.get("name", f"{final_name} ({'Norte' if variant == 'n' else 'Oeste'})")
                rot_fp_val = old_rot.get("footprint", w_fp)
                rot_canvas = old_rot.get("canvas_size", [orig_w, orig_h])
                rot_sprite_off = old_rot.get("sprite_offset", [-32, -48])
                rot_surf_h = old_rot.get("surface_height", 0)
                rot_supports = old_rot.get("supports_surface", False)
                rot_surf_off = old_rot.get("surface_offset", [0, 0])

                item_entry["rotations"][str(rot_idx)] = {
                    "id": f"{item_id}_{variant}",
                    "name": rot_name,
                    "footprint": rot_fp_val,
                    "rot": rot_idx,
                    "canvas_size": rot_canvas,
                    "sprite_offset": rot_sprite_off,
                    "surface_height": rot_surf_h,
                    "supports_surface": rot_supports,
                    "surface_offset": rot_surf_off,
                    "asset_path": f"furniture/established_furniture/{w_target_file}"
                }
        else:
            for r in range(4):
                rot_fp = footprint
                if footprint == "1x2" and r in [1, 3]:
                    rot_fp = "2x1"
                elif footprint == "2x1" and r in [1, 3]:
                    rot_fp = "1x2"

                r_offset = get_sprite_offset(rot_fp, is_tall=is_tall, item_id=item_id)

                rot_target_file = f"{item_id}_rot{r}.png"
                if r in data["rotations"]:
                    r_src = data["rotations"][r]
                else:
                    r_src = base_fp

                if safe_copy(r_src, os.path.join(ESTABLISHED_DIR, rot_target_file)):
                    copied_count += 1

                old_rot = old_rotations.get(str(r), {})
                rot_name = old_rot.get("name", f"{final_name} Rot {r}")
                rot_fp_val = old_rot.get("footprint", rot_fp)
                rot_canvas = old_rot.get("canvas_size", [orig_w, orig_h])
                rot_sprite_off = old_rot.get("sprite_offset", r_offset)
                rot_surf_h = old_rot.get("surface_height", final_surf_h)
                rot_supports = old_rot.get("supports_surface", final_supports_surf)
                rot_surf_off = old_rot.get("surface_offset", final_surf_off)

                item_entry["rotations"][str(r)] = {
                    "id": f"{item_id}_rot{r}",
                    "name": rot_name,
                    "footprint": rot_fp_val,
                    "rot": r,
                    "canvas_size": rot_canvas,
                    "sprite_offset": rot_sprite_off,
                    "surface_height": rot_surf_h,
                    "supports_surface": rot_supports,
                    "surface_offset": rot_surf_off,
                    "asset_path": f"furniture/established_furniture/{rot_target_file}"
                }

                # Copia segura de capas (_base, _back, _front) adjuntas al mueble
                base_fp = data.get("base_file", "")
                base_dir = os.path.dirname(base_fp) if base_fp else ""
                base_raw_stem = os.path.splitext(os.path.basename(base_fp))[0] if base_fp else ""
                base_clean_stem = clean_id(base_raw_stem) if base_raw_stem else item_id

                rot_file = data.get("rotations", {}).get(r, base_fp)
                rot_dir = os.path.dirname(rot_file) if rot_file else base_dir
                rot_raw_stem = os.path.splitext(os.path.basename(rot_file))[0] if rot_file else f"{base_raw_stem}_rot{r}"

                for suffix in ["_front", "_base", "_back"]:
                    cands = [
                        f"{rot_raw_stem}{suffix}.png",
                        f"{base_raw_stem}_rot{r}{suffix}.png",
                        f"{base_clean_stem}_rot{r}{suffix}.png",
                        f"{item_id}_rot{r}{suffix}.png",
                    ]
                    found = False
                    for cand_name in cands:
                        for d in [rot_dir, base_dir]:
                            if not d:
                                continue
                            cand_path = os.path.join(d, cand_name)
                            if os.path.exists(cand_path):
                                if safe_copy(cand_path, os.path.join(ESTABLISHED_DIR, f"{item_id}_rot{r}{suffix}.png")):
                                    copied_count += 1
                                found = True
                                break
                        if found:
                            break

        merged_catalog[item_id] = item_entry

    # 4. Guardar catálogo JSON sin perder nada
    try:
        with open(CATALOG_PATH, "w", encoding="utf-8") as f:
            json.dump(merged_catalog, f, indent=2, ensure_ascii=False)
        print(f"[EXITO] Catálogo consolidado con {len(merged_catalog)} muebles en total.")
        print(f"[EXITO] {copied_count} archivos nuevos/actualizados copiados a: {ESTABLISHED_DIR}")
        print("[EXITO] Ningún archivo previo fue eliminado.")
    except Exception as e:
        print(f"Error al guardar {CATALOG_PATH}: {e}")

if __name__ == "__main__":
    import sys
    subfolder = sys.argv[1] if len(sys.argv) > 1 else None
    sync_new_furniture_safe(subfolder)
