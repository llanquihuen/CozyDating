"""
generate_face_walk_frames.py - Generador de frames de caminata para Ojos, Nariz, Boca, Cabeza, Accesorios y Pelo
Toma los sprites estáticos (1..8) y genera automáticamente los 32 frames de caminata (4 frames x 8 direcciones).
Convención de pantalla: Y positivo (hacia arriba) = -dy en pantalla.
"""

import os
import glob
import shutil
from PIL import Image

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OCTO_AVATAR_DIR = os.path.join(PROJECT_ROOT, "frontend", "assets", "images", "OCTOPLAYER", "Avatar")
ASEPRITE_DOWNLOADS_DIR = r"C:\Users\Asus\Downloads\ASEPRITE ITEMS\OCTOPLAYER\Avatar"

# En coordenadas de imagen/pantalla, Y positivo (hacia arriba) se resta (-dy):
HEAD_WALK_OFFSETS = {
    # dir: [f1, f2, f3, f4]  (dx, dy)
    1: [(0, 0), (0, -3), (0, 0), (-1, -4)],     # Sur (S):      y0, y3(arriba), y0, (y4 arriba, x-1 izq)
    2: [(0, -1), (0, -3), (0, 1), (0, -3)],     # Sureste (SE):  y1(arr), y3(arr), y-1(abj), y3(arr)
    3: [(0, 1), (0, -2), (0, 1), (0, -2)],      # Este (E):      y-1(abj), y2(arr), y-1(abj), y2(arr)
    4: [(-1, 1), (-1, 0), (-1, 2), (-2, -1)],   # Noreste (NE):  (x-1 y-1), x-1, (x-1 y-2), (x-2 y1)
    5: [(-1, 1), (-2, 0), (-2, 3), (-2, -1)],   # Norte (N):    (x-1 y-1), x-2, (x-2 y-3), (x-2 y1)
    6: [(2, 1), (3, 0), (3, 1), (3, -1)],       # Noroeste (NW): (x2 y-1), x3, (x3 y-1), (x3 y1)
    7: [(0, 0), (0, -3), (0, 0), (0, -3)],      # Oeste (W):     0, y3(arr), 0, y3(arr)
    8: [(0, 0), (0, -2), (0, 2), (0, -3)],      # Suroeste (SW): 0, y2(arr), y-2(abj), y3(arr)
}

def shift_image(img: Image.Image, dx: int, dy: int) -> Image.Image:
    w, h = img.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(img, (dx, dy), img)
    return out

def _process_directory_walk_frames(target_dir: str, ase_target_dir: str = None) -> int:
    if not os.path.exists(target_dir):
        return 0

    count_generated = 0
    for root, _, files in os.walk(target_dir):
        rel_path = os.path.relpath(root, target_dir)
        ase_root = os.path.join(ase_target_dir, rel_path) if (ase_target_dir and os.path.exists(ase_target_dir)) else None

        # Filtrar solo archivos estáticos base (ej: normal_lenses1.png a normal_lenses8.png)
        png_files = [f for f in files if f.endswith(".png") and "_walk" not in f and "_f" not in f]

        for fname in png_files:
            without_ext = fname[:-4]
            try:
                dir_num = int(without_ext[-1])
                base_name = without_ext[:-1]
            except ValueError:
                continue

            if dir_num not in HEAD_WALK_OFFSETS:
                continue

            fpath = os.path.join(root, fname)
            try:
                with Image.open(fpath) as img:
                    base_img = img.convert("RGBA")
            except Exception as e:
                print(f"Error al abrir {fpath}: {e}")
                continue

            offsets = HEAD_WALK_OFFSETS[dir_num]
            for f_idx, (dx, dy) in enumerate(offsets):
                f_num = f_idx + 1 # f1, f2, f3, f4
                dest_name = f"{base_name}{dir_num}_walk_f{f_num}.png"
                dest_path = os.path.join(root, dest_name)

                shifted = shift_image(base_img, dx, dy)
                shifted.save(dest_path)
                count_generated += 1

                # Sincronizar también a Downloads si existe la carpeta
                if ase_root and os.path.exists(ase_root):
                    ase_dest = os.path.join(ase_root, dest_name)
                    shifted.save(ase_dest)

    return count_generated

def generate_walk_frames_for_category(category: str):
    cat_dir = os.path.join(OCTO_AVATAR_DIR, category)
    ase_cat_dir = os.path.join(ASEPRITE_DOWNLOADS_DIR, category)
    count = _process_directory_walk_frames(cat_dir, ase_cat_dir)
    print(f"[OK] Creados {count} frames de caminata para '{category}'.")

def generate_walk_frames_for_hair():
    hair_dir = os.path.join(OCTO_AVATAR_DIR, "hair")
    ase_hair_dir = os.path.join(ASEPRITE_DOWNLOADS_DIR, "hair")
    count = _process_directory_walk_frames(hair_dir, ase_hair_dir)
    print(f"[OK] Creados {count} frames de caminata para 'hair' (front y back).")

def regenerate_all_walk_frames():
    print("=== Regenerando frames de caminata para Ojos, Nariz, Boca, Cabeza, Accesorios y Pelo ===")
    generate_walk_frames_for_category("eyes")
    generate_walk_frames_for_category("nose")
    generate_walk_frames_for_category("mouth")
    generate_walk_frames_for_category("head")
    generate_walk_frames_for_category("accessories")
    generate_walk_frames_for_hair()
    print("=== Completado con éxito ===")

if __name__ == "__main__":
    regenerate_all_walk_frames()
