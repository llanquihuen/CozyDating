import os
import re
import json
import shutil
from PIL import Image

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
NEW_ADDED_DIR = os.path.join(BASE_DIR, "frontend", "assets", "images", "furniture", "new_added")
FURNITURE_BASE = os.path.join(BASE_DIR, "frontend", "assets", "images", "furniture")
CATALOG_PATH = os.path.join(FURNITURE_BASE, "furniture_catalog.json")
PUBSPEC_PATH = os.path.join(BASE_DIR, "frontend", "pubspec.yaml")

# Spanish display names dictionary for common furniture terms
NAME_TRANSLATIONS = {
    "bookshelf": "Estantería de Libros",
    "tall_bookshelf": "Estantería Alta",
    "closet": "Armario Ropero Alto",
    "table": "Mesa Rústica",
    "single_bed": "Cama Individual (1x2)",
    "double_bed": "Cama Doble",
    "chair": "Silla",
    "sofa": "Sofá",
    "lamp": "Lámpara",
    "nightstand": "Mesa de Noche",
    "drawer": "Cajonera",
    "desk": "Escritorio",
    "plant": "Planta Decorativa",
    "mirror": "Espejo",
    "art_painting": "Cuadro de Paisaje",
    "window_yellow": "Window Yellow",
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
    "cube_wall": "Guía de Pared",
    "table_lamp": "Lámpara de Noche",
    "coffee_mug": "Taza de Café Caliente",
    "open_book": "Libro Abierto",
    "dining_table_2x2": "Mesa de Comedor Roble (2x2)",
    "side_table": "Mesa de Noche / Velador",
    "wooden_chair": "Silla de Madera",
    "plush_armchair": "Sillón Acolchado",
    "potted_plant": "Planta en Maceta",
    "king_bed": "Cama King Size (2x2)",
    "kitchen_counter": "Encimera de Cocina",
    "kitchen_stove": "Cocina con Fogones",
    "kitchen_sink": "Fregadero Inox",
    "kitchen_fridge": "Refrigerador Inox",
    "bathtub_1x2": "Bañera Clásica (1x2)",
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

def sync_new_furniture():
    print("=== Auto-Sync Furniture and Wall Items (new_added) ===")
    if not os.path.exists(NEW_ADDED_DIR):
        print(f"Directory {NEW_ADDED_DIR} not found.")
        return

    catalog = {}
    if os.path.exists(CATALOG_PATH):
        try:
            with open(CATALOG_PATH, "r", encoding="utf-8") as f:
                catalog = json.load(f)
        except Exception as e:
            print(f"Error loading {CATALOG_PATH}: {e}")

    dirs_to_copy = {
        "128x256": os.path.join(FURNITURE_BASE, "128x256"),
        "64x128": os.path.join(FURNITURE_BASE, "64x128"),
        "32x64": os.path.join(FURNITURE_BASE, "32x64"),
        "root": FURNITURE_BASE,
    }
    for d in dirs_to_copy.values():
        os.makedirs(d, exist_ok=True)

    discovered_items = {}

    for root, dirs, files in os.walk(NEW_ADDED_DIR):
        rel_path = os.path.relpath(root, NEW_ADDED_DIR).replace("\\", "/").lower()
        parts = rel_path.split("/")
        
        footprint = "1x1"
        is_tall = ("tall" in parts or "tall" in root.lower())
        is_wall = ("wall" in parts or "walls" in parts or "wall" in rel_path)
        
        if is_wall or any("wall" in p for p in parts):
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
            item_id = clean_id(stem, is_wall=is_wall)
            full_path = os.path.join(root, file)

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
                if stem.endswith("_n") or stem.endswith("_wall_n"):
                    discovered_items[item_id]["wall_variants"]["n"] = full_path
                elif stem.endswith("_w") or stem.endswith("_wall_w"):
                    discovered_items[item_id]["wall_variants"]["w"] = full_path
                else:
                    discovered_items[item_id]["wall_variants"]["n"] = full_path
                    discovered_items[item_id]["wall_variants"]["w"] = full_path
            else:
                rot_match = re.search(r'_rot([0-3])$', stem)
                if rot_match:
                    rot = int(rot_match.group(1))
                    discovered_items[item_id]["rotations"][rot] = full_path
                else:
                    discovered_items[item_id]["base_file"] = full_path

    print(f"Found {len(discovered_items)} distinct items in new_added.")

    added_count = 0
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

        # Copy & resize images to target resolutions
        if is_wall:
            variants = data["wall_variants"]
            src_n = variants.get("n", base_fp)
            src_w = variants.get("w", base_fp)

            for suffix, src_path in [("n", src_n), ("w", src_w)]:
                variant_name = f"{item_id}_{suffix}"
                try:
                    with Image.open(src_path) as im:
                        cur_w, cur_h = im.size
                        shutil.copy2(src_path, os.path.join(dirs_to_copy["128x256"], f"{variant_name}.png"))
                        im_64 = im.resize((max(1, cur_w // 2), max(1, cur_h // 2)), Image.Resampling.NEAREST)
                        im_64.save(os.path.join(dirs_to_copy["64x128"], f"{variant_name}.png"))
                        im_64.save(os.path.join(dirs_to_copy["root"], f"{variant_name}.png"))
                        im_32 = im.resize((max(1, cur_w // 4), max(1, cur_h // 4)), Image.Resampling.NEAREST)
                        im_32.save(os.path.join(dirs_to_copy["32x64"], f"{variant_name}.png"))
                except Exception as e:
                    print(f"Error processing wall image {src_path}: {e}")

        else:
            rot_files = {}
            for r in range(4):
                if r in data["rotations"]:
                    rot_files[r] = data["rotations"][r]
                else:
                    rot_files[r] = base_fp

            for rot, src_img_path in rot_files.items():
                try:
                    with Image.open(src_img_path) as im:
                        cur_w, cur_h = im.size
                        dst_hd = os.path.join(dirs_to_copy["128x256"], f"{item_id}_rot{rot}.png")
                        shutil.copy2(src_img_path, dst_hd)
                        if rot == 0:
                            shutil.copy2(src_img_path, os.path.join(dirs_to_copy["128x256"], f"{item_id}.png"))

                        im_64 = im.resize((max(1, cur_w // 2), max(1, cur_h // 2)), Image.Resampling.NEAREST)
                        dst_64 = os.path.join(dirs_to_copy["64x128"], f"{item_id}_rot{rot}.png")
                        im_64.save(dst_64)
                        if rot == 0:
                            im_64.save(os.path.join(dirs_to_copy["64x128"], f"{item_id}.png"))
                            im_64.save(os.path.join(dirs_to_copy["root"], f"{item_id}.png"))

                        im_32 = im.resize((max(1, cur_w // 4), max(1, cur_h // 4)), Image.Resampling.NEAREST)
                        dst_32 = os.path.join(dirs_to_copy["32x64"], f"{item_id}_rot{rot}.png")
                        im_32.save(dst_32)
                        if rot == 0:
                            im_32.save(os.path.join(dirs_to_copy["32x64"], f"{item_id}.png"))
                except Exception as e:
                    print(f"Error processing image {src_img_path}: {e}")

        # IMPORTANT: If the item is already registered in the catalog, PRESERVE all its offsets and customizations!
        if item_id in catalog:
            print(f"  [*] Preserved existing offsets & metadata for '{item_id}'")
            continue

        # ONLY for brand new items: initialize catalog entry
        zone = guess_zone(item_id, footprint)
        name = guess_name(item_id, is_tall=is_tall)
        surf_h = guess_surface_height(item_id, footprint)
        sup_surf = (surf_h > 0)
        surf_off = [0, 0]

        if is_wall:
            wall_offset = [-32, -48]
            rotations_dict = {}
            for r in range(4):
                rotations_dict[str(r)] = {
                    "id": item_id,
                    "name": name,
                    "zone": zone,
                    "footprint": "wall_n",
                    "rot": r,
                    "canvas_size": [orig_w, orig_h],
                    "sprite_offset": wall_offset,
                    "surface_height": surf_h,
                    "supports_surface": sup_surf,
                    "surface_offset": surf_off,
                }

            catalog[item_id] = {
                "rotations": rotations_dict,
                "id": item_id,
                "name": name,
                "zone": zone,
                "footprint": "wall_n",
                "surface_height": surf_h,
                "supports_surface": sup_surf,
                "surface_offset": surf_off,
                "sprite_offset": wall_offset,
            }
            catalog.pop(f"{item_id}_n", None)
            catalog.pop(f"{item_id}_w", None)

        else:
            rotations_dict = {}
            for r in range(4):
                r_footprint = footprint
                if footprint == "1x2" and (r == 1 or r == 3):
                    r_footprint = "2x1"
                elif footprint == "2x1" and (r == 1 or r == 3):
                    r_footprint = "1x2"

                offset = get_sprite_offset(r_footprint, is_tall=is_tall, item_id=item_id)
                rotations_dict[str(r)] = {
                    "id": item_id,
                    "name": name,
                    "zone": zone,
                    "footprint": r_footprint,
                    "rot": r,
                    "canvas_size": [orig_w, orig_h],
                    "sprite_offset": offset,
                    "surface_height": surf_h,
                    "supports_surface": sup_surf,
                    "surface_offset": surf_off,
                }

            base_offset = get_sprite_offset(footprint, is_tall=is_tall, item_id=item_id)
            catalog[item_id] = {
                "rotations": rotations_dict,
                "id": item_id,
                "name": name,
                "zone": zone,
                "footprint": footprint,
                "surface_height": surf_h,
                "supports_surface": sup_surf,
                "surface_offset": surf_off,
                "sprite_offset": base_offset,
            }

        added_count += 1
        print(f"  [+] Registered new item '{item_id}' ({name}) -> Footprint: {footprint}, SurfaceH: {surf_h}")

    for cat_dest in [
        CATALOG_PATH,
        os.path.join(FURNITURE_BASE, "128x256", "furniture_catalog.json"),
        os.path.join(FURNITURE_BASE, "64x128", "furniture_catalog.json"),
        os.path.join(FURNITURE_BASE, "32x64", "furniture_catalog.json"),
    ]:
        with open(cat_dest, "w", encoding="utf-8") as f:
            json.dump(catalog, f, indent=4, ensure_ascii=False)

    _update_pubspec()
    print(f"\nSuccessfully synchronized {added_count} items into catalog and all resolution folders!")

def _update_pubspec():
    if not os.path.exists(PUBSPEC_PATH):
        return
    with open(PUBSPEC_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    new_assets = [
        "    - assets/images/furniture/new_added/",
        "    - assets/images/furniture/new_added/1x1/",
        "    - assets/images/furniture/new_added/1x1/normal/",
        "    - assets/images/furniture/new_added/1x1/tall/",
        "    - assets/images/furniture/new_added/1x2/",
        "    - assets/images/furniture/new_added/2x1/",
        "    - assets/images/furniture/new_added/2x2/",
        "    - assets/images/furniture/new_added/surface/",
        "    - assets/images/furniture/new_added/walls/",
    ]
    modified = False
    for asset in new_assets:
        if asset.strip() not in content:
            if "assets:" in content:
                content = content.replace("assets:\n", f"assets:\n{asset}\n")
                modified = True

    if modified:
        with open(PUBSPEC_PATH, "w", encoding="utf-8") as f:
            f.write(content)
        print("Updated pubspec.yaml with new asset paths.")

if __name__ == "__main__":
    sync_new_furniture()
