"""Calls PixelLab to turn the lying guide into clean pixel art candidates."""
import base64, io, json, os, sys, time
import requests
from PIL import Image
sys.path.insert(0, r"C:/Users/Asus/ProyectoJuegoDating/CreateSprites")
from pixellab_service import load_pixellab_key  # reads CreateSprites/pixellab_config.json

os.chdir(r"C:/Users/Asus/ProyectoJuegoDating/CreateSprites")  # config file is relative
KEY = load_pixellab_key()
OUT = os.path.dirname(os.path.abspath(__file__))
BASE = "https://api.pixellab.ai/v2"
H = {"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def b64(path):
    buf = io.BytesIO(); Image.open(path).convert("RGBA").save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}

def run(endpoint, payload, tag):
    r = requests.post(f"{BASE}/{endpoint}", headers=H, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        print(tag, "ERROR", r.status_code, r.text[:500]); return
    data = r.json()
    job = data.get("background_job_id")
    while job:
        time.sleep(6)
        j = requests.get(f"{BASE}/background-jobs/{job}", headers=H, timeout=30).json()
        if j.get("status") == "completed": data = j.get("last_response", {}); break
        if j.get("status") == "failed": print(tag, "FAILED", str(j)[:500]); return
    imgs = data.get("images") or ([data["image"]] if "image" in data else [])
    for i, im in enumerate(imgs):
        s = im.get("base64") if isinstance(im, dict) else im
        s = s.split(",", 1)[-1]
        Image.open(io.BytesIO(base64.b64decode(s + "=" * (-len(s) % 4)))).save(f"{OUT}/{tag}_{i}.png")
    print(tag, "saved", len(imgs), "| usage:", {k: v for k, v in data.items() if k in ("usage", "cost", "generations")})

DESC = ("isometric pixel art chibi character lying flat on his back, sleeping relaxed, arms resting along the body, "
        "head at the top-right, feet at the bottom-left, body aligned to the isometric diagonal, "
        "bald mannequin base body in simple underwear, same proportions, outline and shading as the reference sprite, "
        "transparent background, no bed")
W, Hh = 144, 96
which = sys.argv[1:] or ["gen", "edit"]

if "gen" in which:
    run("generate-image-v2", {
        "description": DESC,
        "image_size": {"width": W, "height": Hh},
        "no_background": True,
        "reference_images": [
            {"image": b64(f"{OUT}/ref_mannequin_standing.png"), "size": {"width": 64, "height": 128},
             "usage_description": "the character to draw: same body, head, face and proportions"},
            {"image": b64(f"{OUT}/guide_lieA.png"), "size": {"width": W, "height": Hh},
             "usage_description": "pose and placement guide: copy this lying position and orientation, but redraw it naturally"},
        ],
        "style_image": {"image": b64(f"{OUT}/ref_mannequin_standing.png"), "size": {"width": 64, "height": 128}},
        "seed": 7,
    }, "gen")

if "edit" in which:
    run("edit-images-v2", {
        "method": "edit_with_text",
        "edit_images": [{"image": b64(f"{OUT}/guide_lieA.png"), "width": W, "height": Hh}],
        "image_size": {"width": W, "height": Hh},
        "description": "redraw as a clean pixel art character lying on his back seen from an isometric camera, "
                       "natural foreshortened lying body with volume, fix the distorted head so the face looks up "
                       "naturally, keep the same pose, position, size, outline and colors",
        "no_background": True,
        "seed": 7,
    }, "edit")
