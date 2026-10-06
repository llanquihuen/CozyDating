"""Big front (S) + SE views of each new style for detail checks."""
import sys
from PIL import Image, ImageDraw
sys.path.insert(0, r"C:/Users/Asus/ProyectoJuegoDating/CreateSprites")
sys.path.insert(0, r"C:/Users/Asus/ProyectoJuegoDating/CreateSprites/face_pipeline")
import octo_engine
from face_sheet import base_config
from make_faces import EYES, MOUTHS

CROP, Z = (12, 18, 52, 48), 10
looks = [("female", "#FCD5B5", "bangs"), ("male", "#7A4522", "comb_over"), ("female", "#A56635", "long_flow")]
rows = [("eyes", n) for n in EYES] + [("mouth", n) for n in MOUTHS]
cw, ch = (CROP[2]-CROP[0])*Z, (CROP[3]-CROP[1])*Z
out = Image.new("RGB", (cw*len(looks)*2, ch*len(rows)), (40, 42, 54))
for r, (layer, name) in enumerate(rows):
    for c, (body, skin, hair) in enumerate(looks):
        for k, d in enumerate((1, 2)):
            cfg = base_config(body, skin, hair); cfg[layer] = {**cfg.get(layer, {}), "file": name}
            im = octo_engine.compose_octo_avatar(cfg, direction=d).crop(CROP).resize((cw, ch), Image.NEAREST)
            out.paste(im, ((c*2+k)*cw, r*ch), im)
out.save(sys.argv[1] if len(sys.argv) > 1 else "face_pipeline/_zoom.png")
