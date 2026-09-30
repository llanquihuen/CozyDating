import os
import sys
from PIL import Image, ImageDraw

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import furniture_inspector_engine as fie
import octo_engine

catalog = fie.scan_new_added_furniture()

print("Available chairs:", [k for k, v in catalog.items() if v.get("is_chair")])
print("Available surfaces:", [k for k, v in catalog.items() if v.get("footprint") == "surface"])

# Test 1: simple_chair rot 0
chair = catalog.get("simple_chair")
config = octo_engine.get_default_config()
spot = fie.DEFAULT_SEAT_CONFIGS.get("simple_chair", {}).get(0, [{}])[0]

img_chair = fie.render_furniture_scene(
    furniture_item=chair,
    rot=0,
    show_tiles=True,
    show_subcells=True,
    show_origin=True,
    show_avatar=True,
    avatar_config=config,
    seat_spot=spot,
    zoom=1
)
img_chair.save("CreateSprites/scratch/test_chair_calib.png")
print("Saved test_chair_calib.png")

# Test 2: table_lamp on side_table
lamp = catalog.get("table_lamp")
side_table = catalog.get("side_table")
img_lamp = fie.render_furniture_scene(
    furniture_item=lamp,
    rot=0,
    sprite_offset=(-32, -57),
    surface_support_item=side_table,
    surface_height=22,
    show_tiles=True,
    show_origin=True,
    zoom=1
)
img_lamp.save("CreateSprites/scratch/test_lamp_calib.png")
print("Saved test_lamp_calib.png")
