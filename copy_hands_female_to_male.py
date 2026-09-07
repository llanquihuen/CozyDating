import os
import shutil
import re

TARGET_DIR = r"C:\Users\Asus\ProyectoJuegoDating\frontend\assets\images\OCTOPLAYER\Avatar\body"

def copy_female_hands_to_male():
    if not os.path.exists(TARGET_DIR):
        print(f"Error: El directorio no existe: {TARGET_DIR}")
        return

    files = [
        f for f in os.listdir(TARGET_DIR)
        if "female" in f and "hand" in f and f.endswith(".png")
    ]

    if not files:
        print("No se encontraron archivos de manos female.")
        return

    print(f"Encontrados {len(files)} archivos. Copiando a versión male...")

    for file_name in files:
        male_name = re.sub(r"^female", "male", file_name)
        src = os.path.join(TARGET_DIR, file_name)
        dst = os.path.join(TARGET_DIR, male_name)
        shutil.copy2(src, dst)
        print(f"Copiado: {file_name} -> {male_name}")

    print(f"\n¡Completado! Se copiaron {len(files)} archivos.")

if __name__ == "__main__":
    copy_female_hands_to_male()
