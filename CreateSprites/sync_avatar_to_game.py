"""
sync_avatar_to_game.py - Sincronizador automático de assets de Avatar a Flutter
=============================================================================
Este script realiza el paso 3 (y opcionalmente el paso 2) de forma automática:
1. Escanea todos los assets de OCTOPLAYER/Avatar (ojos, nariz, boca, pelo, marcas, accesorios, etc.).
   - Marcas corporales (pecas, lunares, tatuajes...): carpeta plana marks/.
   - Accesorios: una subcarpeta por espacio, accessories/<slot>/ (hat, glasses, bag, headband).
2. Genera los frames de caminata faltantes llamando a generate_face_walk_frames.
3. Actualiza pubspec.yaml con las carpetas de pelo nuevas (front y back) y de accesorios por espacio.
4. Agrega a avatar_catalog.dart los estilos nuevos (neutros y para ambos cuerpos: revisar luego su
   audience/fits a mano) y avisa de ítems del catálogo sin sprites o con capa trasera desalineada.
   Nunca borra ni modifica entradas existentes.
"""

import os
import re
import sys
from typing import Dict, List, Set, Tuple

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
AVATAR_ASSETS_DIR = os.path.join(PROJECT_ROOT, "frontend", "assets", "images", "OCTOPLAYER", "Avatar")
PUBSPEC_PATH = os.path.join(PROJECT_ROOT, "frontend", "pubspec.yaml")
AVATAR_CATALOG_PATH = os.path.join(PROJECT_ROOT, "frontend", "lib", "core", "models", "avatar_catalog.dart")

# Carpeta escaneada -> slot de AvatarCatalog (en Dart la constante se llama igual que su valor).
CATALOG_SLOTS: Dict[str, str] = {
    "eyes": "eyes", "nose": "nose", "mouth": "mouth", "hair": "hair",
    "tops": "top", "bottoms": "bottom", "shoes": "shoes", "marks": "mark", "makeup/blush": "blush",
}
BODY_TYPES = ("female", "male")
# Slots painted at load time over the eyes/mouth (face_makeup.dart): they have no sprites.
RUNTIME_SLOTS = {"eyeshadow", "lipstick"}
ITEM_RE = re.compile(r"AvatarItem\((\w+|'[^']*'),\s*'([^']+)'")

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
    # Marcas
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
        if "_walk" in f or "_sit" in f or re.search(r"_f\d", f) or "hands" in f:
            continue
        if f.endswith("1.png"):
            items.add(f[:-5])
        elif f.endswith("_S.png"):
            items.add(f[:-6])
    # body-fitted clothes (<style>_female1.png / <style>_male1.png) are versions of <style>
    for body in BODY_TYPES:
        items = {i[:-len(body) - 1] if i.endswith(f"_{body}") else i for i in items}
    return sorted(list(items))

def scan_accessory_slots() -> Dict[str, List[str]]:
    """accessories/<slot>/<style>N.png -> {slot: [styles]} (solo espacios con sprites)."""
    acc_dir = os.path.join(AVATAR_ASSETS_DIR, "accessories")
    if not os.path.exists(acc_dir):
        return {}
    slots: Dict[str, List[str]] = {}
    for slot in sorted(os.listdir(acc_dir)):
        if os.path.isdir(os.path.join(acc_dir, slot)):
            styles = scan_flat_category(os.path.join("accessories", slot))
            if styles:
                slots[slot] = styles
    return slots

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

def update_pubspec(hair_styles: List[str], accessory_slots: List[str]) -> bool:
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

    for slot in accessory_slots:
        slot_path = f"assets/images/OCTOPLAYER/Avatar/accessories/{slot}/"
        if slot_path not in content:
            hair_entries_to_add.append(f"    - {slot_path}")

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
        print("[INFO] pubspec.yaml ya tiene todas las carpetas de pelo y accesorios registradas.")
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

def update_avatar_catalog(catalog: Dict[str, List[str]], hairs_with_back: List[str], accessory_slots: Dict[str, List[str]]) -> bool:
    if not os.path.exists(AVATAR_CATALOG_PATH):
        print(f"[ERROR] No se encontró {AVATAR_CATALOG_PATH}")
        return False

    with open(AVATAR_CATALOG_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    start = content.find("static const List<AvatarItem> items = [")
    end = content.find("\n  ];", start)
    if start < 0 or end < 0:
        print("[ERROR] No se encontró la lista AvatarCatalog.items en avatar_catalog.dart")
        return False
    items_block = content[start:end]
    existing = {(slot.strip("'"), item_id) for slot, item_id in ITEM_RE.findall(items_block)}

    scanned: List[Tuple[str, str]] = [(CATALOG_SLOTS[cat], item) for cat in CATALOG_SLOTS for item in catalog.get(cat, [])]
    scanned += [(slot, style) for slot, styles in accessory_slots.items() for style in styles]

    new_lines = []
    for slot, item in scanned:
        if (slot, item) in existing:
            continue
        slot_expr = slot if slot in CATALOG_SLOTS.values() else f"'{slot}'"
        label = NAME_LABELS.get(item, item.replace("_", " ").title()).replace("'", "\\'")
        back = ", hasBack: true" if slot == "hair" and item in hairs_with_back else ""
        new_lines.append(f"    AvatarItem({slot_expr}, '{item}', '{label}'{back}),")

    for slot, item in sorted(existing - set(scanned)):
        if slot in RUNTIME_SLOTS:
            continue
        print(f"[AVISO] '{slot}/{item}' está en el catálogo pero no tiene sprites.")
    for line in items_block.splitlines():
        m = ITEM_RE.search(line)
        if m and m.group(1) == "hair":
            in_catalog, on_disk = "hasBack: true" in line, m.group(2) in hairs_with_back
            if in_catalog != on_disk:
                print(f"[AVISO] Pelo '{m.group(2)}': hasBack en el catálogo = {in_catalog}, capa back/ en disco = {on_disk}.")
    slot_order = content.split("accessorySlots = [", 1)[-1].split("];", 1)[0]
    unknown_slots = [s for s in accessory_slots if f"'{s}'" not in slot_order]
    if unknown_slots:
        print(f"[AVISO] Espacios de accesorio sin orden de dibujo en AvatarCatalog.accessorySlots: {', '.join(unknown_slots)}")

    if not new_lines:
        print("[OK] avatar_catalog.dart ya contiene todos los estilos.")
        return True

    block = "\n\n    // Agregados por sync_avatar_to_game.py: neutros y para ambos cuerpos hasta revisarlos.\n" + "\n".join(new_lines)
    content = content[:end] + block + content[end:]
    with open(AVATAR_CATALOG_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"[OK] {len(new_lines)} estilos nuevos agregados a avatar_catalog.dart (revisa audience/fits):")
    for line in new_lines:
        print("   " + line.strip())
    return True

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
        "marks": scan_flat_category("marks"),
        "tops": scan_flat_category("tops"),
        "bottoms": scan_flat_category("bottoms"),
        "shoes": scan_flat_category("shoes"),
        "head": scan_flat_category("head"),
        "makeup/blush": scan_flat_category(os.path.join("makeup", "blush")),
    }
    accessory_slots = scan_accessory_slots()
    hair_styles, hairs_with_back = scan_hair_styles()
    catalog["hair"] = hair_styles

    print(f"  - Ojos ({len(catalog['eyes'])}): {', '.join(catalog['eyes'])}")
    print(f"  - Nariz ({len(catalog['nose'])}): {', '.join(catalog['nose'])}")
    print(f"  - Boca ({len(catalog['mouth'])}): {', '.join(catalog['mouth'])}")
    print(f"  - Pelo ({len(catalog['hair'])}): {', '.join(catalog['hair'])} (Con capa trasera: {', '.join(hairs_with_back)})")
    print(f"  - Marcas ({len(catalog['marks'])}): {', '.join(catalog['marks'])}")
    for slot, styles in accessory_slots.items():
        print(f"  - Accesorios/{slot} ({len(styles)}): {', '.join(styles)}")

    print("\n>> Actualizando archivos del juego...")
    update_pubspec(hair_styles, list(accessory_slots))
    update_avatar_catalog(catalog, hairs_with_back, accessory_slots)

    print("\n" + "=" * 60)
    print(" [LISTO] ¡Todos los elementos están sincronizados en el juego!")
    print("=" * 60)

if __name__ == "__main__":
    skip_walk = "--no-walk" in sys.argv
    sync_all(generate_walk=not skip_walk)
