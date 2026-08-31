"""
gemini_asset_generator.py - Generador de Assets Pixel Art 64x128 usando Google Gemini
Permite generar cuerpos base, peinados, rostros, ropa y accesorios en vistas ortogonales e isometricas,
removiendo el fondo automaticamente y escalando con filtrado Nearest-Neighbor para pixel art nitido.
"""

import os
import sys
import json
import io
import math
from PIL import Image

CONFIG_FILE = "gemini_config.json"
ASSETS_DIR = "assets"
RAW_EXPORTS_DIR = "exports/ai_raw"

os.makedirs(RAW_EXPORTS_DIR, exist_ok=True)
os.makedirs(ASSETS_DIR, exist_ok=True)

def load_api_key():
    """Carga la API Key desde el archivo de configuracion o variables de entorno."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if api_key:
        return api_key
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("api_key", "")
        except Exception:
            pass
    return ""

def save_api_key(api_key: str):
    """Guarda la API Key localmente para futuras ejecuciones."""
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump({"api_key": api_key.strip()}, f, indent=2)

def remove_chroma_background(img: Image.Image, chroma_color=(255, 0, 255), threshold=75) -> Image.Image:
    """
    Convierte el fondo de color solido (por defecto Magenta #FF00FF o Verde #00FF00)
    en transparencia alfa limpia para pixel art.
    """
    img = img.convert("RGBA")
    data = img.getdata()
    new_data = []

    cr, cg, cb = chroma_color
    for item in data:
        r, g, b, a = item
        # Distancia euclidiana de color respecto al croma
        dist = math.sqrt((r - cr)**2 + (g - cg)**2 + (b - cb)**2)
        if dist < threshold:
            new_data.append((0, 0, 0, 0)) # 100% Transparente
        else:
            new_data.append((r, g, b, 255))

    img.putdata(new_data)
    return img

def fit_to_pixel_canvas(img: Image.Image, target_width=64, target_height=128) -> Image.Image:
    """
    Recorta el espacio vacio sobrante y escala la imagen manteniendo
    las proporciones con algoritmo Nearest-Neighbor a 64x128.
    """
    bbox = img.getbbox()
    if bbox:
        cropped = img.crop(bbox)
    else:
        cropped = img

    cw, ch = cropped.size
    scale = min(target_width / cw, target_height / ch) * 0.92
    new_w = max(1, int(cw * scale))
    new_h = max(1, int(ch * scale))

    # Escalar sin desenfoque (Nearest Neighbor)
    scaled = cropped.resize((new_w, new_h), resample=Image.Resampling.NEAREST)

    # Pegar centrado en el lienzo final de 64x128
    final_canvas = Image.new("RGBA", (target_width, target_height), (0, 0, 0, 0))
    pos_x = (target_width - new_w) // 2
    pos_y = target_height - new_h - 4 # Apoyado hacia abajo (con 4px de base)
    final_canvas.paste(scaled, (pos_x, max(0, pos_y)), scaled)

    return final_canvas

def generate_image_with_gemini(prompt: str, api_key: str, chroma="magenta") -> Image.Image:
    """Llama a los modelos de generacion visual de Gemini."""
    try:
        from google import genai
    except ImportError:
        raise ImportError("Por favor instala el SDK de Gemini ejecutando: pip install google-genai")

    client = genai.Client(api_key=api_key)

    chroma_name = "solid pure bright magenta (#FF00FF)" if chroma == "magenta" else "solid pure bright green (#00FF00)"

    full_prompt = (
        f"16-bit SNES JRPG pixel art character sprite, {prompt}, "
        f"crisp clean pixels, full body, isolated character sprite, "
        f"completely flat solid {chroma_name} background, no floor shadow, no gradient, single subject."
    )

    print(f"\n[IA] Enviando prompt a Gemini:\n    \"{full_prompt}\"")
    
    # Lista de modelos con capacidad de generacion de imagenes en orden de preferencia
    models_to_try = [
        "gemini-2.5-flash-image",
        "gemini-3.1-flash-image",
        "gemini-3-pro-image"
    ]

    last_error = None
    for model_name in models_to_try:
        try:
            print(f"[*] Conectando con modelo: {model_name}...")
            response = client.models.generate_content(
                model=model_name,
                contents=full_prompt
            )
            for part in response.candidates[0].content.parts:
                if part.inline_data:
                    return Image.open(io.BytesIO(part.inline_data.data)).convert("RGBA")
        except Exception as e:
            last_error = e
            print(f"[!] Error con modelo {model_name}: {e}")

    raise RuntimeError(f"No se pudo generar la imagen con ninguno de los modelos. Error: {last_error}")

# ==============================================================================
# PRESETS DE GENERACION OPTIMIZADOS PARA 64x128
# ==============================================================================
PRESETS = {
    "1": {
        "name": "Cuerpo Base (Maniqui Frente - Para Mazmorras)",
        "prompt": "chibi adventurer base body mannequin, clean anatomy, neutral skin tone, underwear only, standing straight, straight front view",
        "save_path": "assets/body/base/down_frame0.png",
        "category": "body"
    },
    "2": {
        "name": "Cuerpo Base (Maniqui Isometrico Diagonal - Para Lobby)",
        "prompt": "chibi adventurer base body mannequin, clean anatomy, neutral skin tone, underwear only, walking pose, 45 degree isometric angle view looking down-right",
        "save_path": "assets/body/base/isometric_frame0.png",
        "category": "body"
    },
    "3": {
        "name": "Peinado: Trenzas Campestres (Stardew Style)",
        "prompt": "chibi female hairstyle with rustic braids, cute bangs, detailed hair texture, front view, isolated hair asset without face",
        "save_path": "assets/hair/hair_farm_braids/down_frame0.png",
        "category": "hair"
    },
    "4": {
        "name": "Peinado: Corto Puntiagudo de Aventurero (Chrono Style)",
        "prompt": "chibi male spiky anime adventurer haircut, vibrant hair tufts, front view, isolated hair asset without face",
        "save_path": "assets/hair/hair_adventurer_spiky/down_frame0.png",
        "category": "hair"
    },
    "5": {
        "name": "Peinado: Melena Larga Ondulante",
        "prompt": "chibi long flowing hair with natural waves, front view, isolated hair asset without face",
        "save_path": "assets/hair/hair_long_flowing/down_frame0.png",
        "category": "hair"
    },
    "6": {
        "name": "Ropa Superior: Camisa de Franela Campestre",
        "prompt": "chibi red plaid flannel shirt with buttons and rolled sleeves, front view, isolated clothing asset",
        "save_path": "assets/tops/top_flannel_shirt/down_frame0.png",
        "category": "tops"
    },
    "7": {
        "name": "Ropa Superior: Tunica de Viajero / Explorador",
        "prompt": "chibi traveler adventurer leather tunic with belt and brass buckle, front view, isolated clothing asset",
        "save_path": "assets/tops/top_traveler_tunic/down_frame0.png",
        "category": "tops"
    },
    "8": {
        "name": "Ropa Inferior: Overalls / Peto de Granjero",
        "prompt": "chibi denim farmer overalls with straps and front pocket patch, front view, isolated clothing asset",
        "save_path": "assets/bottoms/bottom_farmer_overalls/down_frame0.png",
        "category": "bottoms"
    },
    "9": {
        "name": "Accesorio: Sombrero de Paja",
        "prompt": "chibi wide-brim straw hat with ribbon, front view, isolated hat accessory",
        "save_path": "assets/accessories/acc_straw_hat/down_frame0.png",
        "category": "accessories"
    }
}

def run_cli():
    print("=" * 70)
    print("  GENERADOR DE SPRITES PIXEL ART 64x128 CON GEMINI")
    print("=" * 70)

    api_key = load_api_key()
    if not api_key:
        print("\n[!] No se encontro ninguna Gemini API Key configurada.")
        api_key = input(" Ingresa tu Gemini API Key (de Google AI Studio o Cloud): ").strip()
        if api_key:
            save_api_key(api_key)
            print("[OK] API Key guardada en gemini_config.json")
        else:
            print("[X] Clave vacia. Abortando.")
            sys.exit(1)

    while True:
        print("\nSelecciona que deseas generar:")
        for key, p in PRESETS.items():
            print(f"  [{key}] {p['name']}")
        print("  [C] Prompt Personalizado")
        print("  [K] Cambiar API Key")
        print("  [Q] Salir")

        choice = input("\nOpcion > ").strip().upper()

        if choice == "Q":
            print("Hasta luego!")
            break
        elif choice == "K":
            api_key = input(" Ingresa tu nueva Gemini API Key: ").strip()
            if api_key:
                save_api_key(api_key)
                print("[OK] API Key actualizada.")
            continue

        if choice in PRESETS:
            preset = PRESETS[choice]
            prompt = preset["prompt"]
            save_path = preset["save_path"]
        elif choice == "C":
            prompt = input(" Describe el sprite a generar (en ingles para mejor resultado): ").strip()
            if not prompt:
                continue
            save_rel = input(" Nombre del archivo de guardado (ej: assets/hair/custom_hair.png): ").strip()
            save_path = save_rel if save_rel else "exports/ai_raw/custom_sprite_64x128.png"
        else:
            print("[!] Opcion no valida.")
            continue

        try:
            print("\n Conectando con Gemini...")
            raw_img = generate_image_with_gemini(prompt, api_key, chroma="magenta")

            # Guardar copia en alta resolucion para inspeccion
            base_name = os.path.splitext(os.path.basename(save_path))[0]
            raw_path = os.path.join(RAW_EXPORTS_DIR, f"{base_name}_hd_raw.png")
            raw_img.save(raw_path)
            print(f"[OK] Imagen HD original guardada en: {raw_path}")

            # Procesar transparencia y reducir a 64x128
            print(" Removiendo fondo y aplicando pixelado 64x128...")
            transparent_img = remove_chroma_background(raw_img, chroma_color=(255, 0, 255), threshold=75)
            final_sprite = fit_to_pixel_canvas(transparent_img, target_width=64, target_height=128)

            # Crear directorios y guardar
            os.makedirs(os.path.dirname(save_path), exist_ok=True)
            final_sprite.save(save_path)
            print(f"[OK] Sprite listo! Guardado exitosamente en: {save_path}")
            print(f"     Tamano exacto: {final_sprite.size} RGBA")

        except Exception as e:
            print(f"\n[X] Error durante la generacion: {e}")

if __name__ == "__main__":
    run_cli()
