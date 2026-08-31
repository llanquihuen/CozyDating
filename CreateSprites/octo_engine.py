"""
octo_engine.py - Motor de ensamblado y colorización 8-Direcciones (OCTOPLAYER)
Soporta:
- Estado Detenido (Idle): female1.png .. female8.png
- Estado Caminando (Walk): female1_walk_f1.png .. female1_walk_f4.png
- Integración modular de capas (body, head, eyes, nose, mouth, hair_back, hair_front, tops, bottoms, shoes, accessories).
- Mapeo en sentido horario: 1: Sur, 2: SE, 3: Este, 4: NE, 5: Norte, 6: NW, 7: Oeste, 8: SW.
"""

import os
import glob
from PIL import Image

import color_engine
from color_engine import hex_to_rgb, rgb_to_hex, colorize_sprite, RETRO_PALETTES

OCTO_AVATAR_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend", "assets", "images", "OCTOPLAYER", "Avatar"))

# Mapeo exacto en sentido horario
DIRECTIONS = {
    1: {"name": "1: Sur / Frente (S)", "key": "down", "short": "S", "angle": 180},
    2: {"name": "2: Sureste (SE)", "key": "down_right", "short": "SE", "angle": 135},
    3: {"name": "3: Este / Der (E)", "key": "right", "short": "E", "angle": 90},
    4: {"name": "4: Noreste (NE)", "key": "up_right", "short": "NE", "angle": 45},
    5: {"name": "5: Norte / Espalda (N)", "key": "up", "short": "N", "angle": 0},
    6: {"name": "6: Noroeste (NW)", "key": "up_left", "short": "NW", "angle": 315},
    7: {"name": "7: Oeste / Izq (W)", "key": "left", "short": "W", "angle": 270},
    8: {"name": "8: Suroeste (SW)", "key": "down_left", "short": "SW", "angle": 225},
}

_DISK_CACHE = {}

ASEPRITE_SOURCE_DIR = r"C:\Users\Asus\Downloads\ASEPRITE ITEMS\OCTOPLAYER\Avatar"

def sync_from_aseprite() -> int:
    """
    Sincroniza automáticamente los sprites exportados desde la carpeta de Aseprite
    hacia la estructura de OCTOPLAYER/Avatar en el proyecto.
    """
    if not os.path.exists(ASEPRITE_SOURCE_DIR):
        return 0

    import shutil
    dir_map = {'S': 1, 'SE': 2, 'E': 3, 'NE': 4, 'N': 5, 'NW': 6, 'W': 7, 'SW': 8}
    cat_aliases = {'top': 'tops', 'bottom': 'bottoms', 'shoe': 'shoes', 'glasses': 'accessories'}
    count = 0

    for root, dirs, files in os.walk(ASEPRITE_SOURCE_DIR):
        rel = os.path.relpath(root, ASEPRITE_SOURCE_DIR)
        if rel == ".":
            dest_dir = OCTO_AVATAR_DIR
        else:
            parts = rel.split(os.sep)
            parts[0] = cat_aliases.get(parts[0], parts[0])
            dest_dir = os.path.join(OCTO_AVATAR_DIR, *parts)

        os.makedirs(dest_dir, exist_ok=True)
        for f in files:
            if not f.endswith(".png"):
                continue

            src_f = os.path.join(root, f)
            dst_f = os.path.join(dest_dir, f)
            shutil.copy2(src_f, dst_f)
            count += 1

            for d_str, d_num in dir_map.items():
                if f.endswith(f"_{d_str}.png"):
                    base = f[:-len(f"_{d_str}.png")]
                    shutil.copy2(src_f, os.path.join(dest_dir, f"{base}{d_num}.png"))
                for f_idx in range(1, 5):
                    if f.endswith(f"_{d_str}_walk{f_idx}.png") or f.endswith(f"_{d_str}_walk_f{f_idx}.png"):
                        base = f.split(f"_{d_str}")[0]
                        shutil.copy2(src_f, os.path.join(dest_dir, f"{base}{d_num}_walk_f{f_idx}.png"))

    return count

def clear_cache():
    global _DISK_CACHE
    _DISK_CACHE.clear()

def get_octo_catalog():
    catalog = {
        "body": [], "head": [], "eyes": [], "nose": [], "mouth": [],
        "hair": [], "tops": [], "bottoms": [], "shoes": [], "accessories": []
    }
    if not os.path.exists(OCTO_AVATAR_DIR):
        return catalog

    dir_initials = {1: "S", 2: "SE", 3: "E", 4: "NE", 5: "N", 6: "NW", 7: "W", 8: "SW"}

    for cat in ("body", "head", "eyes", "nose", "mouth", "tops", "bottoms", "shoes", "accessories"):
        c_dir = os.path.join(OCTO_AVATAR_DIR, cat)
        if os.path.exists(c_dir):
            for f in os.listdir(c_dir):
                if not f.endswith(".png"):
                    continue
                if "_walk" in f or "_f" in f:
                    continue
                # Archivos terminados en 1.png o _S.png
                if f.endswith("1.png"):
                    name = f[:-5]
                    if name and name not in catalog[cat]:
                        catalog[cat].append(name)
                elif f.endswith("_S.png"):
                    name = f[:-6]
                    if name and name not in catalog[cat]:
                        catalog[cat].append(name)
            for item in os.listdir(c_dir):
                sub = os.path.join(c_dir, item)
                if os.path.isdir(sub) and item not in catalog[cat]:
                    catalog[cat].append(item)

    hair_dir = os.path.join(OCTO_AVATAR_DIR, "hair")
    if os.path.exists(hair_dir):
        for item in os.listdir(hair_dir):
            sub = os.path.join(hair_dir, item)
            if os.path.isdir(sub) and item not in catalog["hair"]:
                catalog["hair"].append(item)

    return catalog

def load_octo_layer(category: str, item_name: str, direction: int, sub_type: str = None, action: str = "idle", frame: int = 0) -> Image.Image:
    """
    Carga un archivo PNG de capa en la dirección (1..8) especificada.
    - Si action == "walk" y frame en (0..3): Busca {item}{dir}_walk_f{frame+1}.png o {item}_{DIR}_walk{frame+1}.png.
    - Si no existe animación de caminata para esa capa, recurre automáticamente a la base estática.
    """
    if not item_name or item_name == "none":
        return None

    cache_key = f"{category}_{item_name}_{direction}_{sub_type}_{action}_f{frame}"
    if cache_key in _DISK_CACHE:
        return _DISK_CACHE[cache_key]

    dir_initials = {1: "S", 2: "SE", 3: "E", 4: "NE", 5: "N", 6: "NW", 7: "W", 8: "SW"}
    d_init = dir_initials.get(direction, str(direction))

    target_path = None
    candidates = []

    f_num = frame + 1 # 0->1, 1->2, 2->3, 3->4

    if action == "walk":
        candidates.extend([
            f"{item_name}{direction}_walk_f{f_num}.png",
            f"{item_name}_{d_init}_walk{f_num}.png",
            f"{item_name}_{d_init}_walk_f{f_num}.png",
            f"{item_name}{direction}_walk_{f_num}.png",
            f"{item_name}{direction}_walk_f{frame}.png",
            f"{item_name}{direction}_f{frame}.png",
        ])

    # Candidatos base estáticos (Idle / Fallback)
    candidates.extend([
        f"{item_name}{direction}.png",
        f"{item_name}_{d_init}.png",
        f"{direction}.png",
        f"{item_name}{direction}_idle.png",
        f"{item_name}_{d_init}_idle.png"
    ])

    if category == "hair" and sub_type in ("back", "front"):
        base_dir = os.path.join(OCTO_AVATAR_DIR, "hair", item_name, sub_type)
        for fname in candidates:
            p = os.path.join(base_dir, fname)
            if os.path.exists(p):
                target_path = p
                break
    else:
        cat_dir = os.path.join(OCTO_AVATAR_DIR, category)
        sub_cat_dir = os.path.join(cat_dir, item_name)

        for fname in candidates:
            # 1. En cat_dir/{fname} (ej: Avatar/body/female1_walk_f1.png)
            p1 = os.path.join(cat_dir, fname)
            if os.path.exists(p1):
                target_path = p1
                break
            # 2. En cat_dir/{item_name}/{fname}
            p2 = os.path.join(sub_cat_dir, fname)
            if os.path.exists(p2):
                target_path = p2
                break

    if target_path and os.path.exists(target_path):
        try:
            with Image.open(target_path) as img:
                loaded = img.convert("RGBA")
                _DISK_CACHE[cache_key] = loaded
                return loaded
        except Exception:
            return None

    return None

def compose_octo_avatar(config: dict, direction: int = 1, action: str = "idle", frame: int = 0) -> Image.Image:
    """
    Ensambla el avatar completo en 64x128 exactamente con sus capas.
    action: "idle" o "walk"
    frame: 0..3
    """
    body_raw = load_octo_layer("body", config.get("body", {}).get("file", "female"), direction, action=action, frame=frame)
    w, h = body_raw.size if body_raw else (64, 128)

    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # Paletas de color
    skin_rgb = hex_to_rgb(config.get("body", {}).get("color", "#FCD5B5"))
    hair_rgb = hex_to_rgb(config.get("hair", {}).get("color", "#C85A2A"))
    eyes_rgb = hex_to_rgb(config.get("eyes", {}).get("color", "#059669"))
    tops_rgb = hex_to_rgb(config.get("tops", {}).get("color", "#DC2626"))
    bottoms_rgb = hex_to_rgb(config.get("bottoms", {}).get("color", "#2563EB"))
    shoes_rgb = hex_to_rgb(config.get("shoes", {}).get("color", "#78350F"))
    acc_rgb = hex_to_rgb(config.get("accessories", {}).get("color", "#EAB308"))
    # Paleta de cejas (por defecto sincronizada con el color de pelo)
    eyebrow_rgb = hex_to_rgb(config.get("eyebrows", {}).get("color", config.get("hair", {}).get("color", "#C85A2A")))

    def _get_tinted(cat: str, item_name: str, color_rgb: tuple, sub_type: str = None) -> Image.Image:
        raw = load_octo_layer(cat, item_name, direction, sub_type=sub_type, action=action, frame=frame)
        if not raw:
            return None
        color_cat = "skin" if cat in ("body", "head", "nose") else ("hair" if cat == "hair" else ("eyes" if cat == "eyes" else "clothing"))
        return colorize_sprite(raw, color_rgb, category=color_cat, eyebrow_rgb=eyebrow_rgb)

    # 1. HAIR BACK (Pelo Trasero)
    hair_file = config.get("hair", {}).get("file", "long_flow")
    hair_back = _get_tinted("hair", hair_file, hair_rgb, sub_type="back")
    if hair_back: canvas = Image.alpha_composite(canvas, hair_back)

    # 2. BODY BASE (Cuerpo: Detenido o Caminando)
    body_file = config.get("body", {}).get("file", "female")
    body_img = _get_tinted("body", body_file, skin_rgb)
    if body_img: canvas = Image.alpha_composite(canvas, body_img)

    # 3. BOTTOMS (Ropa Inferior)
    bottoms_file = config.get("bottoms", {}).get("file", "none")
    bottoms_img = _get_tinted("bottoms", bottoms_file, bottoms_rgb)
    if bottoms_img:
        canvas = Image.alpha_composite(canvas, bottoms_img)
        # PRE-COMPOSICIÓN DE MANOS: Superpone los píxeles de manos del cuerpo por encima del pantalón
        if body_img:
            hands_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            for y in range(50, 92):
                for x in list(range(0, 25)) + list(range(39, 64)):
                    bp = body_img.getpixel((x, y))
                    if bp[3] > 0:
                        hands_layer.putpixel((x, y), bp)
            canvas = Image.alpha_composite(canvas, hands_layer)

    # 4. SHOES (Calzado)
    shoes_file = config.get("shoes", {}).get("file", "none")
    shoes_img = _get_tinted("shoes", shoes_file, shoes_rgb)
    if shoes_img: canvas = Image.alpha_composite(canvas, shoes_img)

    # 5. TOPS (Ropa Superior)
    tops_file = config.get("tops", {}).get("file", "none")
    tops_img = _get_tinted("tops", tops_file, tops_rgb)
    if tops_img: canvas = Image.alpha_composite(canvas, tops_img)

    # 6. HEAD (Forma de Cabeza)
    head_file = config.get("head", {}).get("file", "oval")
    head_img = _get_tinted("head", head_file, skin_rgb)
    if head_img: canvas = Image.alpha_composite(canvas, head_img)

    # 7. MOUTH (Boca)
    mouth_file = config.get("mouth", {}).get("file", "catmouth")
    raw_mouth = load_octo_layer("mouth", mouth_file, direction, action=action, frame=frame)
    if raw_mouth: canvas = Image.alpha_composite(canvas, raw_mouth)

    # 8. NOSE (Nariz - Sincronizada con el tono de piel)
    nose_file = config.get("nose", {}).get("file", "standard")
    nose_img = _get_tinted("nose", nose_file, skin_rgb)
    if nose_img: canvas = Image.alpha_composite(canvas, nose_img)

    # 9. EYES (Ojos)
    eyes_file = config.get("eyes", {}).get("file", "cateyes")
    eyes_img = _get_tinted("eyes", eyes_file, eyes_rgb)
    if eyes_img: canvas = Image.alpha_composite(canvas, eyes_img)

    # 10. HAIR FRONT (Pelo Delantero)
    hair_front = _get_tinted("hair", hair_file, hair_rgb, sub_type="front")
    if hair_front: canvas = Image.alpha_composite(canvas, hair_front)

    # 11. ACCESSORIES (Accesorios)
    acc_file = config.get("accessories", {}).get("file", "none")
    acc_img = _get_tinted("accessories", acc_file, acc_rgb)
    if acc_img: canvas = Image.alpha_composite(canvas, acc_img)

    return canvas

def get_default_config():
    return {
        "body": {"file": "female", "color": "#FCD5B5"},
        "head": {"file": "oval", "color": "#FCD5B5"},
        "eyes": {"file": "cateyes", "color": "#059669"},
        "eyebrows": {"color": "#C85A2A"},
        "nose": {"file": "standard", "color": "#FCD5B5"},
        "mouth": {"file": "catmouth", "color": "#C44242"},
        "hair": {"file": "long_flow", "color": "#C85A2A"},
        "tops": {"file": "none", "color": "#DC2626"},
        "bottoms": {"file": "none", "color": "#2563EB"},
        "shoes": {"file": "none", "color": "#78350F"},
        "accessories": {"file": "none", "color": "#EAB308"}
    }
