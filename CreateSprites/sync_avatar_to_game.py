"""
sync_avatar_to_game.py - Sincronizador automático de assets de Avatar a Flutter
=============================================================================
Este script realiza el paso 3 (y opcionalmente el paso 2) de forma automática:
1. Escanea todos los assets de OCTOPLAYER/Avatar (ojos, nariz, boca, pelo, accesorios, etc.).
2. Genera los frames de caminata faltantes llamando a generate_face_walk_frames.
3. Actualiza pubspec.yaml con las carpetas de pelo nuevas (front y back).
4. Actualiza avatar_config.dart con las listas de estilos disponibles y hairsWithBack.
5. Actualiza modular_avatar_component.dart para soportar las capas traseras de pelo automáticamente.
"""

import os
import re
import sys
from typing import Dict, List, Set, Tuple

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
AVATAR_ASSETS_DIR = os.path.join(PROJECT_ROOT, "frontend", "assets", "images", "OCTOPLAYER", "Avatar")
PUBSPEC_PATH = os.path.join(PROJECT_ROOT, "frontend", "pubspec.yaml")
AVATAR_CONFIG_PATH = os.path.join(PROJECT_ROOT, "frontend", "lib", "core", "models", "avatar_config.dart")
MODULAR_AVATAR_PATH = os.path.join(PROJECT_ROOT, "frontend", "lib", "features", "avatar", "components", "modular_avatar_component.dart")

NAME_LABELS: Dict[str, str] = {
    # Ojos
    "cateyes": "Ojos Felinos 🐱",
    "relax": "Ojos Relajados 🍃",
    "closedeyes": "Ojos Cerrados 😌",
    # Nariz
    "standard": "Nariz Estándar",
    "small": "Nariz Pequeña",
    "subtle": "Nariz Sutil",
    # Boca
    "catmouth": "Boca Gatito 🐱",
    "smile": "Sonrisa Dulce 😊",
    "smirk": "Sonrisa Pícara 😏",
    "biglips": "Labios Grandes 💋",
    # Pelo
    "long_flow": "Melena Fluida",
    "flow": "Cabello Flow",
    "comb_over": "Raya al Lado / Comb Over",
    "bangs": "Flequillo / Bangs",
    "braids": "Trenzas / Braids",
    "twintails": "Dos Coletas / Twintails 👧",
    # Accesorios
    "nice_lenses": "Gafas Modernas 🕶️",
    "normal_lenses": "Lentes Clásicos 👓",
    "freckles": "Pecas ✨",
    # Tops / Bottoms / Shoes
    "jacket": "Chaqueta",
    "jeans": "Jeans Clásicos",
    "boots": "Botas de Cuero 🥾",
}

def scan_flat_category(cat_name: str) -> List[str]:
    cat_dir = os.path.join(AVATAR_ASSETS_DIR, cat_name)
    if not os.path.exists(cat_dir):
        return []
    items: Set[str] = set()
    for f in os.listdir(cat_dir):
        if not f.endswith(".png"):
            continue
        # Ignorar frames de caminata, sentarse o internos
        if "_walk" in f or "_sit" in f or "_f" in f or "hands" in f:
            continue
        if f.endswith("1.png"):
            items.add(f[:-5])
        elif f.endswith("_S.png"):
            items.add(f[:-6])
    return sorted(list(items))

def scan_hair_styles() -> Tuple[List[str], List[str]]:
    hair_dir = os.path.join(AVATAR_ASSETS_DIR, "hair")
    if not os.path.exists(hair_dir):
        return [], []
    styles: List[str] = []
    with_back: List[str] = []
    for item in sorted(os.listdir(hair_dir)):
        sub = os.path.join(hair_dir, item)
        if os.path.isdir(sub):
            styles.append(item)
            back_dir = os.path.join(sub, "back")
            if os.path.isdir(back_dir):
                pngs = [f for f in os.listdir(back_dir) if f.endswith(".png")]
                if pngs:
                    with_back.append(item)
    return styles, with_back

def update_pubspec(hair_styles: List[str]) -> bool:
    if not os.path.exists(PUBSPEC_PATH):
        print(f"[ERROR] No se encontró {PUBSPEC_PATH}")
        return False

    with open(PUBSPEC_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines()

    hair_entries_to_add = []
    for h in hair_styles:
        front_path = f"assets/images/OCTOPLAYER/Avatar/hair/{h}/front/"
        back_path = f"assets/images/OCTOPLAYER/Avatar/hair/{h}/back/"
        
        front_full = os.path.join(AVATAR_ASSETS_DIR, "hair", h, "front")
        back_full = os.path.join(AVATAR_ASSETS_DIR, "hair", h, "back")

        if os.path.exists(front_full) and any(f.endswith(".png") for f in os.listdir(front_full)):
            if front_path not in content:
                hair_entries_to_add.append(f"    - {front_path}")
        if os.path.exists(back_full) and any(f.endswith(".png") for f in os.listdir(back_full)):
            if back_path not in content:
                hair_entries_to_add.append(f"    - {back_path}")

    # Limpiar líneas vacías de back agregadas si no tienen png
    clean_lines = []
    for line in lines:
        if "Avatar/hair/" in line and "/back/" in line:
            # Extraer el hair name
            m = re.search(r"Avatar/hair/([^/]+)/back/", line)
            if m:
                h_name = m.group(1)
                b_dir = os.path.join(AVATAR_ASSETS_DIR, "hair", h_name, "back")
                if not os.path.exists(b_dir) or not any(f.endswith(".png") for f in os.listdir(b_dir)):
                    print(f"  - Removido de pubspec.yaml carpeta vacía: {line.strip()}")
                    continue
        clean_lines.append(line)
    lines = clean_lines

    if not hair_entries_to_add and len(lines) == len(content.splitlines()):
        print("[INFO] pubspec.yaml ya tiene todas las carpetas de pelo registradas.")
        return False

    final_lines = []
    inserted = False
    for line in lines:
        if "assets/images/OCTOPLAYER/Avatar/tops/" in line and not inserted:
            for entry in hair_entries_to_add:
                final_lines.append(entry)
                print(f"  + Agregado a pubspec.yaml: {entry.strip()}")
            inserted = True
        final_lines.append(line)

    if not inserted:
        for entry in hair_entries_to_add:
            final_lines.append(entry)

    with open(PUBSPEC_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(final_lines) + "\n")

    print("[OK] pubspec.yaml actualizado.")
    return True

def format_dart_list(items: List[str], include_none: bool = False) -> str:
    cleaned = list(dict.fromkeys(items))
    if include_none:
        if "none" in cleaned:
            cleaned.remove("none")
        cleaned.append("none")
    lines = ["[\n"]
    for it in cleaned:
        lines.append(f"    '{it}',\n")
    lines.append("  ]")
    return "".join(lines)

def update_avatar_config(catalog: Dict[str, List[str]], hairs_with_back: List[str]) -> bool:
    if not os.path.exists(AVATAR_CONFIG_PATH):
        print(f"[ERROR] No se encontró {AVATAR_CONFIG_PATH}")
        return False

    with open(AVATAR_CONFIG_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Asegurar hairsWithBack
    back_list_str = format_dart_list(hairs_with_back, include_none=False)
    if "static const List<String> hairsWithBack" in content:
        content = re.sub(
            r"static const List<String> hairsWithBack = \[.*?\];",
            f"static const List<String> hairsWithBack = {back_list_str};",
            content,
            flags=re.DOTALL
        )
    else:
        insertion = f"  static const List<String> hairsWithBack = {back_list_str};\n\n"
        content = content.replace("  static const List<String> availableEyeStyles =", insertion + "  static const List<String> availableEyeStyles =")

    # 2. Actualizar availableEyeStyles
    eyes_list_str = format_dart_list(catalog["eyes"], include_none=False)
    content = re.sub(
        r"static const List<String> availableEyeStyles = \[.*?\];",
        f"static const List<String> availableEyeStyles = {eyes_list_str};",
        content,
        flags=re.DOTALL
    )

    # 3. Actualizar availableNoseStyles
    nose_list_str = format_dart_list(catalog["nose"], include_none=False)
    content = re.sub(
        r"static const List<String> availableNoseStyles = \[.*?\];",
        f"static const List<String> availableNoseStyles = {nose_list_str};",
        content,
        flags=re.DOTALL
    )

    # 4. Actualizar availableMouthStyles
    mouth_list_str = format_dart_list(catalog["mouth"], include_none=False)
    content = re.sub(
        r"static const List<String> availableMouthStyles = \[.*?\];",
        f"static const List<String> availableMouthStyles = {mouth_list_str};",
        content,
        flags=re.DOTALL
    )

    # 5. Actualizar availableHairStyles
    hair_list_str = format_dart_list(catalog["hair"], include_none=True)
    content = re.sub(
        r"static const List<String> availableHairStyles = \[.*?\];",
        f"static const List<String> availableHairStyles = {hair_list_str};",
        content,
        flags=re.DOTALL
    )

    # 6. Actualizar availableAccessoryStyles
    acc_list_str = format_dart_list(["none"] + catalog["accessories"], include_none=False)
    content = re.sub(
        r"static const List<String> availableAccessoryStyles = \[.*?\];",
        f"static const List<String> availableAccessoryStyles = {acc_list_str};",
        content,
        flags=re.DOTALL
    )

    # 7. Actualizar formatName con casos faltantes
    all_items = set(catalog["eyes"] + catalog["nose"] + catalog["mouth"] + catalog["hair"] + catalog["accessories"])
    cases_to_add = []
    for item in sorted(all_items):
        case_pattern = f"case '{item}':"
        if case_pattern not in content:
            label = NAME_LABELS.get(item, item.replace("_", " ").title())
            cases_to_add.append(f"      case '{item}': return '{label}';")

    if cases_to_add:
        insertion_code = "\n".join(cases_to_add) + "\n"
        content = content.replace("      default:", f"{insertion_code}\n      default:")
        print(f"  + Agregados {len(cases_to_add)} casos nuevos a formatName() en avatar_config.dart.")

    with open(AVATAR_CONFIG_PATH, "w", encoding="utf-8") as f:
        f.write(content)

    print("[OK] avatar_config.dart actualizado exitosamente.")
    return True

def update_modular_avatar_component() -> bool:
    if not os.path.exists(MODULAR_AVATAR_PATH):
        return False

    with open(MODULAR_AVATAR_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    old_condition = "if (hair == 'long_flow' || hair == 'flow')"
    new_condition = "if (AvatarConfig.hairsWithBack.contains(hair))"

    if old_condition in content:
        content = content.replace(old_condition, new_condition)
        with open(MODULAR_AVATAR_PATH, "w", encoding="utf-8") as f:
            f.write(content)
        print("[OK] modular_avatar_component.dart actualizado para usar AvatarConfig.hairsWithBack.")
        return True
    return False

def sync_all(generate_walk: bool = True):
    print("=" * 60)
    print(" SINCRONIZADOR DE AVATARES OCTOPLAYER A FLUTTER")
    print("=" * 60)

    if generate_walk:
        try:
            import generate_face_walk_frames
            print("\n>> Paso 2: Generando frames de caminata faltantes...")
            generate_face_walk_frames.regenerate_all_walk_frames()
        except Exception as e:
            print(f"[AVISO] No se pudo ejecutar generate_face_walk_frames: {e}")

    print("\n>> Paso 3: Escaneando catálogo de assets...")
    catalog = {
        "eyes": scan_flat_category("eyes"),
        "nose": scan_flat_category("nose"),
        "mouth": scan_flat_category("mouth"),
        "accessories": scan_flat_category("accessories"),
        "tops": scan_flat_category("tops"),
        "bottoms": scan_flat_category("bottoms"),
        "shoes": scan_flat_category("shoes"),
        "head": scan_flat_category("head"),
    }
    hair_styles, hairs_with_back = scan_hair_styles()
    catalog["hair"] = hair_styles

    print(f"  - Ojos ({len(catalog['eyes'])}): {', '.join(catalog['eyes'])}")
    print(f"  - Nariz ({len(catalog['nose'])}): {', '.join(catalog['nose'])}")
    print(f"  - Boca ({len(catalog['mouth'])}): {', '.join(catalog['mouth'])}")
    print(f"  - Pelo ({len(catalog['hair'])}): {', '.join(catalog['hair'])} (Con capa trasera: {', '.join(hairs_with_back)})")
    print(f"  - Accesorios ({len(catalog['accessories'])}): {', '.join(catalog['accessories'])}")

    print("\n>> Actualizando archivos del juego...")
    update_pubspec(hair_styles)
    update_avatar_config(catalog, hairs_with_back)
    update_modular_avatar_component()

    print("\n" + "=" * 60)
    print(" [LISTO] ¡Todos los elementos están sincronizados en el juego!")
    print("=" * 60)

if __name__ == "__main__":
    skip_walk = "--no-walk" in sys.argv
    sync_all(generate_walk=not skip_walk)
