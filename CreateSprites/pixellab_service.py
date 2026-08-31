"""
pixellab_service.py - Servicio de integración directa con PixelLab API v2
Soporta:
- Generación de sprites estáticos 64x128 con /create-image-bitforge y /create-image-pixflux.
- Generación de animaciones 64x128 con /animate-with-text-v2 y sondeo automático de background-jobs.
- Base64 estándar limpio (evita error 500 'Incorrect padding').
- Compatibilidad total con planes de suscripción mensual ('generations') y saldo prepago ('usd').
"""

import os
import json
import base64
import io
import math
import time
import requests
from PIL import Image

CONFIG_FILE = "pixellab_config.json"
OCTO_AVATAR_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "frontend", "assets", "images", "OCTOPLAYER", "Avatar"))
BASE_URL = "https://api.pixellab.ai/v2"

def load_pixellab_key() -> str:
    api_key = os.environ.get("PIXELLAB_API_KEY") or os.environ.get("PIXELLAB_SECRET")
    if api_key:
        return api_key.strip()
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("api_key", "").strip()
        except Exception:
            pass
    return ""

def save_pixellab_key(api_key: str):
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump({"api_key": api_key.strip()}, f, indent=2)

def pil_to_base64_payload(img: Image.Image) -> dict:
    """
    Convierte una imagen PIL a Base64 puro para PixelLab API (sin prefijo data URI para evitar error 500 padding).
    """
    buffered = io.BytesIO()
    img.convert("RGBA").save(buffered, format="PNG")
    b64_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
    return {
        "type": "base64",
        "base64": b64_str,
        "format": "png"
    }

def base64_payload_to_pil(b64_data: str) -> Image.Image:
    if "," in b64_data:
        b64_data = b64_data.split(",", 1)[1]
    # Limpiar espacios en blanco
    b64_data = b64_data.strip()
    # Ajustar padding si fuera necesario
    pad_needed = len(b64_data) % 4
    if pad_needed != 0:
        b64_data += "=" * (4 - pad_needed)
    img_bytes = base64.b64decode(b64_data)
    return Image.open(io.BytesIO(img_bytes)).convert("RGBA")

def isolate_layer_from_base(generated_img: Image.Image, base_img: Image.Image) -> Image.Image:
    gen = generated_img.convert("RGBA")
    base = base_img.convert("RGBA").resize(gen.size, resample=Image.Resampling.NEAREST)

    gen_data = gen.getdata()
    base_data = base.getdata()

    out_data = []
    for g_pix, b_pix in zip(gen_data, base_data):
        gr, gg, gb, ga = g_pix
        br, bg, bb, ba = b_pix

        if ga == 0:
            out_data.append((0, 0, 0, 0))
            continue

        if ba == 0 and ga > 0:
            out_data.append((gr, gg, gb, ga))
            continue

        dist = math.sqrt((gr - br)**2 + (gg - bg)**2 + (gb - bb)**2)
        if dist > 35:
            out_data.append((gr, gg, gb, ga))
        else:
            out_data.append((0, 0, 0, 0))

    out_img = Image.new("RGBA", gen.size, (0, 0, 0, 0))
    out_img.putdata(out_data)
    return out_img

class PixelLabClient:
    def __init__(self, api_key: str = None):
        self.api_key = (api_key or load_pixellab_key()).strip()

    def _get_headers(self) -> dict:
        if not self.api_key:
            raise ValueError("Por favor ingresa tu API Key de PixelLab.")
        return {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json"
        }

    def test_connection(self) -> dict:
        if not self.api_key or len(self.api_key) < 5:
            return {"success": False, "message": "API Key vacía o demasiado corta."}

        try:
            resp = requests.get(f"{BASE_URL}/balance", headers=self._get_headers(), timeout=12)
            if resp.status_code == 200:
                data = resp.json()
                if "generations" in data:
                    gen_count = data["generations"]
                    return {
                        "success": True,
                        "message": f"Conectado a PixelLab. Suscripción activa ({gen_count} generaciones restantes).",
                        "balance": gen_count
                    }
                elif "balance" in data:
                    bal = data["balance"]
                    return {
                        "success": True,
                        "message": f"Conectado a PixelLab. Saldo disponible: {bal}",
                        "balance": bal
                    }
                elif "usd" in data:
                    usd_val = data["usd"]
                    return {
                        "success": True,
                        "message": f"Conectado a PixelLab. Saldo: ${usd_val:.2f} USD",
                        "balance": usd_val
                    }
                else:
                    return {
                        "success": True,
                        "message": "Conectado a PixelLab con éxito.",
                        "balance": str(data)
                    }
            elif resp.status_code == 401:
                return {"success": False, "message": "API Key inválida. Revisa tu token en pixellab.ai"}
            else:
                return {"success": False, "message": f"Error del servidor PixelLab ({resp.status_code}): {resp.text}"}
        except Exception as e:
            return {"success": False, "message": f"Error de red al conectar con PixelLab: {e}"}

    def _poll_background_job(self, job_id: str, max_wait_sec: int = 90) -> dict:
        headers = self._get_headers()
        start_time = time.time()

        while time.time() - start_time < max_wait_sec:
            time.sleep(2.5)
            res = requests.get(f"{BASE_URL}/background-jobs/{job_id}", headers=headers, timeout=15)
            if res.status_code == 200:
                job_data = res.json()
                status = job_data.get("status")
                if status == "completed":
                    return job_data.get("last_response", {})
                elif status == "failed":
                    raise RuntimeError(f"El trabajo de animación en PixelLab falló: {job_data}")
            elif res.status_code == 401:
                raise RuntimeError("API Token no autorizado durante el procesamiento.")
        raise TimeoutError("El trabajo de animación en PixelLab excedió el tiempo límite de espera.")

    def generate_layer_sprite(self, prompt: str, category: str, base_image: Image.Image, direction_idx: int) -> Image.Image:
        dir_map = {
            1: ("south", False),
            2: ("south_east", True),
            3: ("east", False),
            4: ("north_east", True),
            5: ("north", False),
            6: ("north_west", True),
            7: ("west", False),
            8: ("south_west", True)
        }
        dir_name, is_iso = dir_map.get(direction_idx, ("south", False))

        full_prompt = f"16-bit SNES pixel art {category}: {prompt}, clean transparent background"

        payload = {
            "description": full_prompt,
            "image_size": {"width": 64, "height": 128},
            "init_image": pil_to_base64_payload(base_image),
            "init_image_strength": 250,
            "no_background": True,
            "isometric": is_iso,
            "direction": dir_name
        }

        try:
            resp = requests.post(f"{BASE_URL}/create-image-bitforge", headers=self._get_headers(), json=payload, timeout=60)
            if resp.status_code != 200:
                resp = requests.post(f"{BASE_URL}/create-image-pixflux", headers=self._get_headers(), json=payload, timeout=60)

            if resp.status_code == 200:
                res_data = resp.json()
                b64_raw = None

                if "image" in res_data and isinstance(res_data["image"], dict):
                    b64_raw = res_data["image"].get("base64")
                elif "images" in res_data and len(res_data["images"]) > 0:
                    b64_raw = res_data["images"][0].get("base64") if isinstance(res_data["images"][0], dict) else res_data["images"][0]

                if not b64_raw:
                    raise RuntimeError(f"PixelLab no devolvió imagen en la respuesta: {res_data}")

                gen_img = base64_payload_to_pil(b64_raw)
                return isolate_layer_from_base(gen_img, base_image)
            else:
                raise RuntimeError(f"PixelLab API devolvió error {resp.status_code}: {resp.text}")

        except Exception as e:
            raise RuntimeError(f"Error en generación PixelLab: {e}")

    def generate_animated_walk_cycle(self, prompt: str, category: str, base_image: Image.Image, direction_idx: int, frame_count: int = 4) -> list:
        dir_map = {
            1: "south",
            2: "south-east",
            3: "east",
            4: "north-east",
            5: "north",
            6: "north-west",
            7: "west",
            8: "south-west"
        }
        dir_name = dir_map.get(direction_idx, "south")

        payload = {
            "reference_image": pil_to_base64_payload(base_image),
            "reference_image_size": {"width": 64, "height": 128},
            "action": "walk",
            "image_size": {"width": 64, "height": 128},
            "direction": dir_name,
            "no_background": True
        }

        try:
            resp = requests.post(f"{BASE_URL}/animate-with-text-v2", headers=self._get_headers(), json=payload, timeout=45)

            raw_frames = []

            if resp.status_code == 202:
                job_info = resp.json()
                job_id = job_info.get("background_job_id")
                if not job_id:
                    raise RuntimeError(f"Respuesta 202 sin job_id: {job_info}")

                last_res = self._poll_background_job(job_id)

                if "images" in last_res and isinstance(last_res["images"], list):
                    for item in last_res["images"]:
                        b64 = item.get("base64") if isinstance(item, dict) else item
                        raw_frames.append(base64_payload_to_pil(b64))
                elif "frames" in last_res and isinstance(last_res["frames"], list):
                    for item in last_res["frames"]:
                        b64 = item.get("base64") if isinstance(item, dict) else item
                        raw_frames.append(base64_payload_to_pil(b64))
                elif "image" in last_res:
                    b64 = last_res["image"].get("base64") if isinstance(last_res["image"], dict) else last_res["image"]
                    sheet = base64_payload_to_pil(b64)
                    sw, sh = sheet.size
                    cell_w = sw // frame_count
                    for i in range(frame_count):
                        box = (i * cell_w, 0, (i + 1) * cell_w, sh)
                        cell = sheet.crop(box).resize((64, 128), resample=Image.Resampling.NEAREST)
                        raw_frames.append(cell)

            elif resp.status_code == 200:
                res_data = resp.json()
                if "images" in res_data and isinstance(res_data["images"], list):
                    for item in res_data["images"]:
                        b64 = item.get("base64") if isinstance(item, dict) else item
                        raw_frames.append(base64_payload_to_pil(b64))

            else:
                raise RuntimeError(f"PixelLab API devolvió status {resp.status_code}: {resp.text}")

            if not raw_frames:
                raise RuntimeError("PixelLab no devolvió frames de animación en la respuesta final.")

            isolated_frames = [isolate_layer_from_base(f, base_image) for f in raw_frames]

            while len(isolated_frames) < frame_count and isolated_frames:
                isolated_frames.append(isolated_frames[-1])

            return isolated_frames[:frame_count]

        except Exception as e:
            raise RuntimeError(f"Error en animación PixelLab: {e}")

    def save_item_to_octoplayer(self, category: str, item_name: str, images_by_direction: dict):
        clean_name = item_name.strip().lower().replace(" ", "_")

        if category == "hair":
            hair_base_dir = os.path.join(OCTO_AVATAR_DIR, "hair", clean_name)
            back_dir = os.path.join(hair_base_dir, "back")
            front_dir = os.path.join(hair_base_dir, "front")
            os.makedirs(back_dir, exist_ok=True)
            os.makedirs(front_dir, exist_ok=True)

            for d_idx, data in images_by_direction.items():
                if isinstance(data, list):
                    for f_idx, f_img in enumerate(data):
                        dest_f = os.path.join(front_dir, f"{clean_name}{d_idx}_walk_f{f_idx+1}.png")
                        f_img.save(dest_f)
                        if f_idx == 0:
                            f_img.save(os.path.join(front_dir, f"{clean_name}{d_idx}.png"))
                elif isinstance(data, Image.Image):
                    data.save(os.path.join(front_dir, f"{clean_name}{d_idx}.png"))
        else:
            cat_dir = os.path.join(OCTO_AVATAR_DIR, category)
            os.makedirs(cat_dir, exist_ok=True)

            for d_idx, data in images_by_direction.items():
                if isinstance(data, list):
                    for f_idx, f_img in enumerate(data):
                        dest_f = os.path.join(cat_dir, f"{clean_name}{d_idx}_walk_f{f_idx+1}.png")
                        f_img.save(dest_f)
                        if f_idx == 0:
                            f_img.save(os.path.join(cat_dir, f"{clean_name}{d_idx}.png"))
                elif isinstance(data, Image.Image):
                    dest = os.path.join(cat_dir, f"{clean_name}{d_idx}.png")
                    data.save(dest)

        return True
