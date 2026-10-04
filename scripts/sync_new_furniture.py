"""
sync_new_furniture.py - Sincronizador de Muebles a 'established_furniture'

FUNCIONAMIENTO:
1. Lee los muebles desde 'frontend/assets/images/furniture/new_added/' (100% SOLO LECTURA, no modifica tus originales).
2. Copia y centraliza todos los PNGs en una carpeta plana: 'frontend/assets/images/furniture/established_furniture/'.
3. Actualiza 'furniture_catalog.json' con rutas directas a 'furniture/established_furniture/...'.
De esta forma Flutter Web encuentra siempre todos los muebles en un solo lugar sin errores 404 ni confusión de rutas.

ES NO DESTRUCTIVO:
- Nunca borra nada de 'established_furniture/': varios muebles (TV, cafetera, ventanas...) existen
  solo ahí y los referencia el catálogo escrito en código (furniture_catalog_service.dart).
- Solo copia lo que viene de 'new_added/', y omite los archivos que ya son idénticos.
- El catálogo JSON se FUSIONA: se conservan todas las entradas existentes; solo se agregan o
  actualizan las de los muebles encontrados en 'new_added/'.

USO:
  python scripts/sync_furniture_assets.py                 # sincroniza
  python scripts/sync_furniture_assets.py --dry-run       # muestra qué haría, sin escribir nada
  python scripts/sync_furniture_assets.py --list-orphans  # además lista archivos que nadie usa (solo informa)
"""

import os
import re
import json
import shutil
import filecmp
import argparse
from PIL import Image

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
FURNITURE_BASE = os.path.join(BASE_DIR, "frontend", "assets", "images", "furniture")
NEW_ADDED_DIR = os.path.join(FURNITURE_BASE, "new_added")
ESTABLISHED_DIR = os.path.join(FURNITURE_BASE, "established_furniture")
CATALOG_PATH = os.path.join(FURNITURE_BASE, "furniture_catalog.json")
PUBSPEC_PATH = os.path.join(BASE_DIR, "frontend", "pubspec.yaml")

# Diccionario de nombres en español para la UI
NAME_TRANSLATIONS = {
    "bookshelf": "Estantería de Libros",
    "tall_bookshelf": "Estantería Alta",
    "closet": "Armario Ropero Alto",
    "table": "Mesa Rústica",
    "single_bed": "Cama Individual (1x2)",
    "single_high_bed": "Cama Alta (1x2)",
    "king_bed": "Cama King Size (2x2)",
    "chair": "Silla",
    "simple_chair_sm": "Silla de Madera (0.5x0.5)",
    "plush_armchair": "Sillón Acolchado",
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
    "gaming_pc_desk": "Escritorio PC Gamer RGB",
    "fireplace": "Chimenea de Ladrillo",
    "lava_lamp": "Lámpara de Lava",
    "floor_lamp_sm": "Lámpara de Pie (0.5x0.5)",
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
    if is_tall and "Tall" not in name and "Alto" not in name:
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
    if "bookshelf" in item_id or "shelf" in item_id:
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

# Capas de sillas/sofás: '<id>_rot<N>_front|base|back.png'. Son partes de un mueble (el juego
# las carga como '<id>_rot<N>_<capa>.png'), no muebles separados.
LAYER_RE = re.compile(r"^(.*)_rot([0-3])_(front|base|back)$")
# Sprites de prueba en new_added/ que no deben llegar al catálogo.
IGNORED_PREFIXES = ("test_",)

CODE_CATALOG_PATH = os.path.join(BASE_DIR, "frontend", "lib", "core", "services", "furniture_catalog_service.dart")


def sync_new_furniture(furniture_base=FURNITURE_BASE, dry_run=False, list_orphans=False):
    """Sincroniza new_added/ -> established_furniture/ + catálogo. Devuelve un resumen (dict)."""
    NEW_ADDED_DIR = os.path.join(furniture_base, "new_added")
    ESTABLISHED_DIR = os.path.join(furniture_base, "established_furniture")
    CATALOG_PATH = os.path.join(furniture_base, "furniture_catalog.json")

    mode = " (SIMULACIÓN: no se escribe nada)" if dry_run else ""
    print(f"=== Sincronizador de Muebles -> established_furniture{mode} ===")
    if not os.path.exists(NEW_ADDED_DIR):
        print(f"Directorio origen no encontrado: {NEW_ADDED_DIR}")
        return None

    # Nunca se borra nada de ESTABLISHED_DIR (ver docstring del módulo).
    if not dry_run:
        os.makedirs(ESTABLISHED_DIR, exist_ok=True)

    produced = set()
    stats = {"new": [], "updated": [], "unchanged": 0}

    def copy_asset(src, dst):
        """Copia src -> dst solo si cambia algo; lleva la cuenta de lo producido."""
        name = os.path.basename(dst)
        produced.add(name)
        if os.path.exists(dst):
            if filecmp.cmp(src, dst, shallow=False):
                stats["unchanged"] += 1
                return
            stats["updated"].append(name)
        else:
            stats["new"].append(name)
        if not dry_run:
            shutil.copy2(src, dst)

    # Cargar catálogo existente para preservar ediciones personalizadas (surface_height, sprite_offset, etc.)
    existing_catalog = {}
    if os.path.exists(CATALOG_PATH):
        try:
            with open(CATALOG_PATH, "r", encoding="utf-8") as f:
                existing_catalog = json.load(f)
            print(f"Catálogo existente cargado: {len(existing_catalog)} muebles para preservar personalizaciones.")
        except Exception as e:
            print(f"Aviso: No se pudo cargar catálogo existente ({e}), se generará uno nuevo.")

    # Se parte del catálogo existente: las entradas que no vienen de new_added/ se conservan.
    catalog = dict(existing_catalog)
    discovered_items = {}
    layers_by_item = {}  # item_id -> {(rot, 'front'|'base'|'back'): path}
    ignored = set()

    # 1. Escaneo SOLO LECTURA de new_added
    for root, dirs, files in os.walk(NEW_ADDED_DIR):
        rel_path = os.path.relpath(root, NEW_ADDED_DIR).replace("\\", "/").lower()
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

            full_path = os.path.join(root, file)
            stem = os.path.splitext(file)[0]

            layer = LAYER_RE.match(stem.replace("-", "_").lower())
            if layer:
                layer_id = clean_id(layer.group(1), is_wall=is_wall)
                if footprint == "0.5x0.5" and not layer_id.endswith("_sm"):
                    layer_id = f"{layer_id}_sm"
                layers_by_item.setdefault(layer_id, {})[(int(layer.group(2)), layer.group(3))] = full_path
                continue

            item_id = clean_id(stem, is_wall=is_wall)

            if footprint == "0.5x0.5" and not item_id.endswith("_sm"):
                item_id = f"{item_id}_sm"

            if item_id.startswith(IGNORED_PREFIXES):
                ignored.add(item_id)
                continue

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
                    # Prioritize direct _n over _n_rotX
                    if "n" not in discovered_items[item_id]["wall_variants"] or not is_explicit_rot:
                        discovered_items[item_id]["wall_variants"]["n"] = full_path
                elif clean_wall_stem.endswith("_w") or clean_wall_stem.endswith("_wall_w"):
                    # Prioritize direct _w over _w_rotX
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

    print(f"Escaneados {len(discovered_items)} muebles en 'new_added/'.")
    if ignored:
        print(f"Ignorados (sprites de prueba): {', '.join(sorted(ignored))}")
    for layer_id in sorted(set(layers_by_item) - set(discovered_items)):
        print(f"Aviso: capas sin mueble principal para '{layer_id}' (no se copian).")

    # 2. Copia centralizada a 'established_furniture' y generación del catálogo JSON
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

        # Copiar base file
        base_target_name = f"{item_id}.png"
        copy_asset(base_fp, os.path.join(ESTABLISHED_DIR, base_target_name))

        # Preservar propiedades personalizadas del padre si existen
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
                copy_asset(w_src, os.path.join(ESTABLISHED_DIR, w_target_file))

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

                if r in data["rotations"]:
                    r_src = data["rotations"][r]
                    rot_target_file = f"{item_id}_rot{r}.png"
                    copy_asset(r_src, os.path.join(ESTABLISHED_DIR, rot_target_file))
                else:
                    # Copia archivo base como rotación si no se dibujó rot específica
                    rot_target_file = f"{item_id}_rot{r}.png"
                    copy_asset(base_fp, os.path.join(ESTABLISHED_DIR, rot_target_file))

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

                # Capas (base / back / front) con el nombre que carga el juego.
                for layer_name in ("base", "back", "front"):
                    layer_src = layers_by_item.get(item_id, {}).get((r, layer_name))
                    if layer_src:
                        copy_asset(layer_src, os.path.join(ESTABLISHED_DIR, f"{item_id}_rot{r}_{layer_name}.png"))

        # Conservar los campos que este script no calcula (surface_spots afinados a mano en el
        # inspector, bloque 'light', etc.): lo existente es la base y encima van los valores
        # calculados, que ya respetan las personalizaciones de los campos conocidos.
        merged_rotations = {}
        for rot_key, rot_entry in item_entry["rotations"].items():
            merged_rotations[rot_key] = {**old_rotations.get(rot_key, {}), **rot_entry}
        catalog[item_id] = {**old_item, **item_entry, "rotations": merged_rotations}

    # 3. Guardar el catálogo JSON (solo si cambió)
    added_items = sorted(k for k in discovered_items if k not in existing_catalog)
    changed_items = sorted(k for k in discovered_items if k in existing_catalog and existing_catalog[k] != catalog[k])
    preserved = len(existing_catalog) - len([k for k in discovered_items if k in existing_catalog])
    catalog_changed = catalog != existing_catalog

    print(f"PNG nuevos: {len(stats['new'])} | actualizados: {len(stats['updated'])} | idénticos (omitidos): {stats['unchanged']}")
    for name in stats["new"]:
        print(f"  + {name}")
    for name in stats["updated"]:
        print(f"  ~ {name}")
    print(f"Catálogo: {len(added_items)} muebles nuevos, {len(changed_items)} actualizados, "
          f"{preserved} conservados sin tocar (no están en new_added/).")
    for k in added_items:
        print(f"  + {k}")
    for k in changed_items:
        print(f"  ~ {k}")

    if catalog_changed and not dry_run:
        try:
            with open(CATALOG_PATH, "w", encoding="utf-8") as f:
                json.dump(catalog, f, indent=2, ensure_ascii=False)
            print(f"[OK] Catálogo guardado con {len(catalog)} muebles.")
        except Exception as e:
            print(f"Error al guardar {CATALOG_PATH}: {e}")
    elif not catalog_changed:
        print("[OK] Catálogo sin cambios.")

    orphans = find_orphans(ESTABLISHED_DIR, produced, catalog) if list_orphans else []
    if list_orphans:
        if orphans:
            print(f"Archivos en established_furniture/ que no vienen de new_added/ ni usa ningún catálogo "
                  f"({len(orphans)}). NO se borran; revísalos a mano:")
            for name in orphans:
                print(f"  ? {name}")
        else:
            print("Sin archivos huérfanos.")

    return {
        "new_files": stats["new"],
        "updated_files": stats["updated"],
        "unchanged_files": stats["unchanged"],
        "added_items": added_items,
        "changed_items": changed_items,
        "catalog_changed": catalog_changed,
        "orphans": orphans,
    }


def _code_catalog_ids():
    """Ids del catálogo de respaldo escrito en Dart (muebles que no están en el JSON)."""
    try:
        with open(CODE_CATALOG_PATH, encoding="utf-8") as f:
            return set(re.findall(r"FurnitureCatalogItem\(id: '([^']+)'", f.read()))
    except OSError:
        return set()


def find_orphans(established_dir, produced, catalog):
    """Archivos que ni produce new_added/ ni referencia el catálogo JSON ni el de código.
    Solo informativo: puede haber falsos positivos (p. ej. capas cargadas por convención)."""
    if not os.path.isdir(established_dir):
        return []
    referenced = set()
    for entry in catalog.values():
        for rot in (entry.get("rotations") or {}).values():
            path = rot.get("asset_path", "")
            if path:
                referenced.add(os.path.basename(path))
    code_ids = _code_catalog_ids() | set(catalog.keys())
    orphans = []
    for name in sorted(os.listdir(established_dir)):
        if name in produced or name in referenced:
            continue
        stem = os.path.splitext(name)[0]
        base = re.sub(r"(_rot\d)?(_base|_back|_front)?$", "", stem)
        base = re.sub(r"_(n|w)$", "", base)
        if base in code_ids or f"{base}_sm" in code_ids:
            continue
        orphans.append(name)
    return orphans


def main(argv=None):
    parser = argparse.ArgumentParser(description="Sincroniza new_added/ -> established_furniture/ sin borrar nada.")
    parser.add_argument("--dry-run", action="store_true", help="Muestra qué haría, sin escribir nada.")
    parser.add_argument("--list-orphans", action="store_true",
                        help="Lista archivos de established_furniture/ que nadie usa (solo informa, no borra).")
    parser.add_argument("--furniture-dir", default=FURNITURE_BASE,
                        help="Carpeta 'furniture' a sincronizar (por defecto la del frontend).")
    args = parser.parse_args(argv)
    sync_new_furniture(args.furniture_dir, dry_run=args.dry_run, list_orphans=args.list_orphans)


if __name__ == "__main__":
    main()
