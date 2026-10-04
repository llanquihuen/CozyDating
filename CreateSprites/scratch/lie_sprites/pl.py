"""Thin PixelLab v2 helpers for the lying-sprite work (edit / generate with background-job polling)."""
import base64, io, os, sys, time
import requests
from PIL import Image

sys.path.insert(0, r"C:/Users/Asus/ProyectoJuegoDating/CreateSprites")
_cwd = os.getcwd()
os.chdir(r"C:/Users/Asus/ProyectoJuegoDating/CreateSprites")  # pixellab_config.json is relative
from pixellab_service import load_pixellab_key
KEY = load_pixellab_key()
os.chdir(_cwd)

OUT = os.path.dirname(os.path.abspath(__file__))
BASE = "https://api.pixellab.ai/v2"
H = {"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"}

def b64(img):
    if isinstance(img, str):
        img = Image.open(os.path.join(OUT, img))
    buf = io.BytesIO(); img.convert("RGBA").save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}

def _run(endpoint, payload, tag):
    r = requests.post(f"{BASE}/{endpoint}", headers=H, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{tag}: {r.status_code} {r.text[:500]}")
    data = r.json()
    job = data.get("background_job_id")
    while job:
        time.sleep(6)
        j = requests.get(f"{BASE}/background-jobs/{job}", headers=H, timeout=30).json()
        if j.get("status") == "completed":
            data = j.get("last_response", {}); break
        if j.get("status") == "failed":
            raise RuntimeError(f"{tag} failed: {str(j)[:500]}")
    imgs = data.get("images") or ([data["image"]] if "image" in data else [])
    paths = []
    for i, im in enumerate(imgs):
        s = (im.get("base64") if isinstance(im, dict) else im).split(",", 1)[-1]
        p = os.path.join(OUT, f"{tag}_{i}.png")
        Image.open(io.BytesIO(base64.b64decode(s + "=" * (-len(s) % 4)))).save(p)
        paths.append(p)
    print(tag, "->", len(paths), "images")
    return paths

def edit(images, description, tag, size=(128, 96), seed=7):
    return _run("edit-images-v2", {
        "method": "edit_with_text",
        "edit_images": [{"image": b64(i), "width": size[0], "height": size[1]} for i in images],
        "image_size": {"width": size[0], "height": size[1]},
        "description": description, "no_background": True, "seed": seed,
    }, tag)

def generate(description, refs, tag, size=(128, 96), style=None, seed=7):
    """refs: list of (image, (w,h), usage_description)."""
    p = {
        "description": description, "image_size": {"width": size[0], "height": size[1]},
        "no_background": True, "seed": seed,
        "reference_images": [{"image": b64(i), "size": {"width": s[0], "height": s[1]}, "usage_description": u}
                             for i, s, u in refs],
    }
    if style:
        p["style_image"] = {"image": b64(style[0]), "size": {"width": style[1][0], "height": style[1][1]}}
    return _run("generate-image-v2", p, tag)
