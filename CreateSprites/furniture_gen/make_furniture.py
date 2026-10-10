"""Furniture with the exact room geometry, finished by PixelLab.

Each piece starts as a BLOCKOUT drawn here: flat-shaded isometric boxes on the catalog canvas that
fill the footprint exactly (128 px per tile drawn at 0.5x, the same anchor and sprite offset the game
uses), with the main features marked (doors, basin, burners...). PixelLab edit-images-v2 turns the
blockouts into detailed pixel art in ONE call per piece (front view rot0 and back view rot2 edited
together, plus a finished catalog piece as a style anchor), so both views are the same object and the
footprint stays exact. rot1 / rot3 are mirrors of rot0 / rot2, as for the existing furniture.

  python make_furniture.py --blockout kitchen_sink      # preview the blockouts (no credits)
  python make_furniture.py --gen kitchen_sink [--seed 3]
  python make_furniture.py --sheet                      # every generation over its footprint
  python make_furniture.py --build kitchen_sink=kitchen_sink_s3
  python make_furniture.py --genimg tea_set_table [--seed 3]    # small pieces: candidates + sheet
  python make_furniture.py --place tea_set_table=tea_set_table_g3_5

Raw generations stay in gen/ so --build never spends credits. --build writes
frontend/assets/images/furniture/established_furniture/<id>_rot{0..3}.png (+ <id>.png = rot0).
"""
import base64
import io
import json
import os
import sys
import time

import requests
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # CreateSprites
REPO = os.path.dirname(ROOT)
GEN = os.path.join(HERE, "gen")
EST = os.path.join(REPO, "frontend", "assets", "images", "furniture", "established_furniture")
NEW_ADDED = os.path.join(REPO, "frontend", "assets", "images", "furniture", "new_added")
API = "https://api.pixellab.ai/v2"

# Canvas and sprite offset per footprint, as in the catalog (world units; the sprite is drawn at 0.5x).
GEOMETRY = {
    "1x1": {"canvas": (128, 128), "offset": (-32, -48), "tiles": (1, 1)},
    "2x2": {"canvas": (256, 192), "offset": (-64, -44), "tiles": (2, 2)},
    # a 1x2 piece taller than the 192x144 canvas (canopy bed): 96 px more on top, offset 48 higher
    "1x2_tall": {"canvas": (192, 240), "offset": (-64, -84), "tiles": (1, 2)},
    "1x2": {"canvas": (192, 144), "offset": (-64, -36), "tiles": (1, 2)},
}

STYLE_ANCHOR = "kitchen_fridge_sm_rot0.png"  # a finished piece: palette, outline and shading to match

PIECES = {
    "kitchen_sink": {
        "footprint": "1x1",
        "height": 20,  # counter top, world units (= catalog surface_height)
        "front": "kitchen sink base cabinet with two wooden doors with small metal handles",
        "top": "white stone counter top with a stainless steel sink basin and a curved chrome faucet "
               "at the back edge",
        "back": "plain wooden back panel of the cabinet",
        "features": ["doors", "basin", "faucet"],
    },
    "kitchen_stove": {
        "footprint": "1x1",
        "height": 22,
        "front": "stainless steel kitchen range with an oven door with a glass window and a handle, "
                 "control knobs above the door",
        "top": "black cooktop with four gas burners and cast iron grates, a low back splash panel",
        "back": "plain brushed steel back panel of the stove",
        "features": ["oven", "burners"],
    },
    "dining_table_2x2": {
        "footprint": "2x2",
        "kind": "table",
        "height": 22,       # table top (= catalog surface_height)
        "symmetric": True,  # rot2 = rot0
        "reference": "closet_rot0.png",  # wood grain; its own art is the weak one
        "front": "solid oak dining table",
        "top": "warm wooden table top with planks",
        "back": "",
        "features": [],
    },
    # batch 3: the look comes from a chosen --genimg candidate ("gen:<name>"), the shape from here
    "home_theater_tv": {
        "footprint": "1x1",
        "kind": "boxes",
        "reference": "gen:home_theater_tv_g3_0",
        "boxes": [  # x0, y0, x1, y1, z0, z1, colour, front feature
            (0.06, 0.22, 0.94, 0.78, 0, 12, (140, 95, 55), "shelves"),
            (0.04, 0.42, 0.96, 0.50, 12, 34, (45, 45, 55), "screen"),
        ],
    },
    # style pilot (room-art-plan phase 3)
    "canopy_bed": {
        "footprint": "1x2_tall",
        "kind": "canopy",
        "reference": "gen:canopy_bed_g3_3",
        # decoration for now: rot2 = rot0. Asked for the head end, PixelLab kept drawing the foot end
        # (canopy_bed_back candidates); the real back view comes with the lying art, made per view.
        "symmetric": True,
    },
    "crt_tv_console": {
        "footprint": "1x1",
        "kind": "boxes",
        "reference": "gen:crt_tv_console_g3_1",
        "reference_back": "gen:crt_tv_console_back_g3_0",
        "boxes": [
            (0.06, 0.12, 0.94, 0.88, 0, 12, (120, 80, 150), "shelves"),
            (0.16, 0.24, 0.84, 0.80, 12, 36, (200, 195, 180), "crt"),
        ],
    },
    # phase 4: Coquette
    "vanity_table": {
        "footprint": "1x1",
        "kind": "boxes",
        "reference": "gen:vanity_table_g3_0",
        "reference_back": "gen:vanity_table_back_g3_0",
        "boxes": [
            (0.08, 0.30, 0.92, 0.80, 0, 18, (235, 220, 225), "drawers"),
            (0.18, 0.30, 0.82, 0.38, 18, 38, (240, 228, 232), "mirror"),
        ],
    },
    "heart_rug": {
        "footprint": "2x2",
        "kind": "heart",
        "symmetric": True,  # a rug: the heart stays upright to the camera in every rotation
        "reference": "gen:heart_rug_g3_0",
    },
    # phase 4: Retro 90s
    "inflatable_chair": {
        "footprint": "1x1",
        "kind": "shape",              # the blockout is an existing sprite's silhouette
        "shape": "plush_armchair",    # same seat spots and front-layer mask as the armchair
        "seat": True,
        "reference": "gen:inflatable_chair_g3_0",
        "reference_back": "gen:inflatable_chair_back_g3_0",
    },
    # phase 4: Metal / Goth
    "velvet_armchair": {
        "footprint": "1x1",
        "kind": "shape",
        "shape": "plush_armchair",
        "seat": True,
        "reference": "gen:velvet_armchair_g3_0",
        "reference_back": "gen:velvet_armchair_back_g3_0",
    },
    "gothic_canopy_bed": {
        "footprint": "1x2_tall",
        "kind": "canopy",
        "symmetric": True,  # decoration, like the Coquette canopy bed
        "reference": "gen:gothic_canopy_bed_g3_1",
    },
    # phase 4: Rústico
    "log_bed": {
        "footprint": "1x2",
        "kind": "shape",
        "shape": "single_high_bed",
        "symmetric": True,  # decoration, like the canopy beds
        "reference": "gen:log_bed_g3_0",
    },
    "stone_fountain": {
        "footprint": "2x2",
        "kind": "fountain",
        "symmetric": True,
        "reference": "gen:stone_fountain_g3_0",
    },
}

# Small pieces with no footprint to fill (tabletop objects, plants, floor cushions): generated new
# with generate-image-v2 (a finished sprite as the style image, so the pixel size matches; several
# candidates per call) and placed with their base where the current art stands (anchor = bottom
# centre of the opaque art, in canvas pixels). Symmetric enough that rot2 = rot0.
IMG_PIECES = {
    "tea_set_table": {
        "size": (48, 48), "style": "coffee_mug_rot0.png", "canvas": (128, 128), "anchor": (64, 91),
        "desc": "japanese matcha tea set on a small round bamboo tray: a green ceramic teapot, two small "
                "tea cups and a bamboo whisk, isometric view from above at a 30 degree angle",
    },
    "vinyl_record_player": {
        "size": (48, 48), "style": "coffee_mug_rot0.png", "canvas": (128, 128), "anchor": (64, 89),
        "desc": "retro vinyl record player turntable in a wooden case with a black vinyl record and a "
                "silver tone arm, open lid, isometric view from above at a 30 degree angle",
    },
    "monstera_plant_pot": {
        "size": (96, 112), "style": "floor_plant_sm_rot0.png", "canvas": (128, 176), "anchor": (62, 168),
        "desc": "monstera deliciosa house plant with big split leaves in a terracotta pot, isometric view",
    },
    "pet_dog_bed": {
        "size": (80, 64), "style": "plush_armchair_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "round plush dog bed with a soft raised rim and a cushion, a small bone toy on it, "
                "isometric view from above at a 30 degree angle, lying on the floor",
    },
    "yoga_mat_floor": {
        "size": (80, 56), "style": "simple_sofa_rot0.png", "canvas": (128, 128), "anchor": (64, 116),
        "desc": "teal yoga mat unrolled flat on the floor with one end rolled up, a small pink water "
                "bottle beside it, isometric view from above at a 30 degree angle",
    },
    # batch 3
    "bbq_grill": {
        "size": (72, 80), "style": "kitchen_stove_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "round black kettle barbecue grill with a domed lid, a handle and three legs with "
                "wheels, isometric view",
    },
    "cat_tree_tower": {
        "size": (72, 112), "style": "plush_armchair_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "tall cat tree tower with beige carpeted platforms, sisal rope scratching posts, a small "
                "cat house cube and a hanging toy ball, isometric view",
    },
    "acoustic_guitar_stand": {
        "size": (40, 84), "style": "table_rot0.png", "canvas": (128, 176), "anchor": (62, 168),
        "desc": "acoustic guitar standing upright on a small black guitar stand on the floor, "
                "warm honey wood body, isometric view",
    },
    "espresso_machine": {
        "size": (48, 48), "style": "coffee_mug_rot0.png", "canvas": (128, 128), "anchor": (62, 87),
        "desc": "small stainless steel espresso coffee machine with a portafilter and a little coffee "
                "cup under the spout, isometric view from above at a 30 degree angle",
    },
    "polaroid_camera_table": {
        "size": (40, 40), "style": "coffee_mug_rot0.png", "canvas": (128, 128), "anchor": (62, 89),
        "desc": "white vintage instant polaroid camera with a rainbow stripe and two printed photos "
                "beside it, isometric view from above at a 30 degree angle",
    },
    "boardgame_box_set": {
        "size": (48, 40), "style": "coffee_mug_rot0.png", "canvas": (128, 128), "anchor": (68, 89),
        "desc": "stack of two board game boxes with a red twenty sided die and a few game pieces "
                "beside them, isometric view from above at a 30 degree angle",
    },
    "home_theater_tv": {
        "size": (112, 112), "style": "gaming_pc_desk_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "flat screen television on a low wooden media console with two open shelves, isometric "
                "view, the screen faces the lower left",
    },
    "stone_fountain": {
        "size": (200, 150), "style": "fireplace_rot0.png", "canvas": (256, 192), "anchor": (128, 170),
        "desc": "round stone garden fountain: a wide circular stone basin full of clear blue water, a "
                "central stone pedestal with a small top bowl and a water spout, isometric view",
    },
    "canopy_bed": {
        "size": (160, 160), "style": "single_high_bed_rot0.png", "canvas": (192, 240), "anchor": (96, 230),
        "desc": "coquette style single canopy bed: white wooden four poster frame, sheer pastel pink "
                "canopy drapes tied with pink bows, pink quilted bedspread, white frilly pillows, "
                "isometric view, the bed's length runs from the upper right to the lower left",
    },
    "crt_tv_console": {
        "size": (112, 112), "style": "home_theater_tv_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "1990s chunky beige CRT television on a small purple TV stand with a retro game console "
                "and controller on the shelf below, memphis style, isometric view, the screen faces "
                "the lower left",
    },
    # back views of asymmetric pieces: the chosen front candidate is the style image (same palette)
    "canopy_bed_back": {
        "size": (160, 160), "style": "gen:canopy_bed_g3_3", "canvas": (192, 240), "anchor": (96, 230),
        "desc": "the same pink coquette canopy bed seen from the head end: the white padded headboard "
                "with a pink bow in the foreground, the pillows right behind it, the bed running away "
                "to the upper right, isometric view",
    },
    "crt_tv_console_back": {
        "size": (112, 112), "style": "gen:crt_tv_console_g3_1", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "the same 1990s beige CRT television on its purple memphis TV stand seen from behind: "
                "the rounded back of the tube with vent slots and cables, the plain back panel of the "
                "stand, no screen visible, isometric view",
    },
    # phase 4: Coquette (the canopy bed is the style image so the set shares its palette)
    "vanity_table": {
        "size": (112, 112), "style": "canopy_bed_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "coquette white wooden vanity dressing table with an oval mirror framed by pink bows, "
                "two small drawers, perfume bottles and a lipstick on top, isometric view, the mirror "
                "faces the lower left",
    },
    "vanity_table_back": {
        "size": (112, 112), "style": "gen:vanity_table_g3_0", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "the same white coquette vanity table seen from behind: the plain white back of the oval "
                "mirror frame with a pink bow on top, the plain back panel of the table, isometric view",
    },
    "heart_rug": {
        "size": (160, 112), "style": "canopy_bed_rot0.png", "canvas": (256, 192), "anchor": (128, 170),
        "desc": "fluffy pastel pink heart shaped shag rug with a white ruffled edge lying flat on the "
                "floor, isometric view from above",
    },
    "flower_vase_pink": {
        "size": (48, 48), "style": "coffee_mug_rot0.png", "canvas": (64, 64), "anchor": (34, 60),
        "desc": "small white ceramic vase with pink roses and white baby breath flowers and a pink "
                "ribbon bow, isometric view",
    },
    "plush_teddy": {
        "size": (48, 48), "style": "coffee_mug_rot0.png", "canvas": (64, 64), "anchor": (34, 60),
        "desc": "small soft pastel pink teddy bear plush toy sitting, with a white bow around its neck, "
                "isometric view",
    },
    "wall_bow_garland": {
        "wall": True, "size": (60, 40), "style": "canopy_bed_rot0.png", "canvas": (128, 128), "center_y": 40,
        "desc": "garland of small pink satin bows and white pearls hanging in a gentle curve, seen "
                "straight from the front, flat front view, no perspective",
    },
    # phase 4: Retro 90s (the CRT TV is the style image so the set shares its palette)
    "inflatable_chair": {
        "size": (112, 112), "style": "crt_tv_console_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "1990s inflatable armchair made of glossy translucent purple and teal vinyl tubes, puffy "
                "round armrests and backrest, isometric view, the seat faces the lower left",
    },
    "inflatable_chair_back": {
        "size": (112, 112), "style": "gen:inflatable_chair_g3_0", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "the same 1990s inflatable vinyl armchair seen from behind: the puffy round backrest "
                "tube in front, the armrests on both sides, isometric view",
    },
    "boombox_radio": {
        "size": (48, 48), "style": "crt_tv_console_rot0.png", "canvas": (64, 64), "anchor": (34, 60),
        "desc": "1990s silver boombox stereo cassette player with two round speakers, a handle on top "
                "and colorful buttons, isometric view",
    },
    "memphis_rug": {
        "size": (160, 112), "style": "crt_tv_console_rot0.png", "canvas": (256, 192), "anchor": (128, 170),
        "desc": "rectangular 1990s memphis pattern rug with teal squiggles, yellow triangles, pink dots "
                "and black confetti on a white background lying flat on the floor, isometric view from "
                "above",
    },
    "wall_cassette_rack": {
        "wall": True, "size": (56, 56), "style": "crt_tv_console_rot0.png", "canvas": (128, 128), "center_y": 52,
        "desc": "small purple wall rack full of colorful 1990s audio cassette tapes in three rows, seen "
                "straight from the front, flat front view, no perspective",
    },
    "wall_poster_90s": {
        "wall": True, "size": (48, 64), "style": "crt_tv_console_rot0.png", "canvas": (128, 128), "center_y": 50,
        "opaque": True,  # the poster fills the image; background removal would erase the paper
        "desc": "1990s retro poster filling the whole image edge to edge: a neon pink and teal memphis "
                "pattern background with a cassette tape and a yellow smiley face, a thin white border, "
                "no text, flat front view, no perspective",
    },
    # phase 4: Metal / Goth
    "velvet_armchair": {
        "size": (112, 112), "style": "plush_armchair_rot0.png", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "gothic wingback armchair upholstered in deep crimson velvet with black carved wooden "
                "legs and tufted buttons, isometric view, the seat faces the lower left",
    },
    "velvet_armchair_back": {
        "size": (112, 112), "style": "gen:velvet_armchair_g3_0", "canvas": (128, 128), "anchor": (64, 118),
        "desc": "the same gothic crimson velvet wingback armchair seen from behind: the tall tufted "
                "backrest in front, black carved wooden frame, isometric view",
    },
    "gothic_canopy_bed": {
        "size": (160, 160), "style": "canopy_bed_rot0.png", "canvas": (192, 240), "anchor": (96, 230),
        "desc": "gothic single canopy bed: black carved wooden four poster frame with spires, deep red "
                "velvet drapes tied with black ropes, black and crimson bedspread, dark purple pillows, "
                "isometric view, the bed's length runs from the upper right to the lower left",
    },
    "candelabra_floor_sm": {
        "size": (40, 96), "style": "floor_lamp_sm_rot0.png", "canvas": (128, 176), "anchor": (62, 168),
        "desc": "tall black wrought iron gothic floor candelabra with five lit white candles and "
                "dripping wax, isometric view",
    },
    "electric_guitar_stand_sm": {
        "size": (40, 84), "style": "acoustic_guitar_stand_rot0.png", "canvas": (128, 176), "anchor": (62, 168),
        "desc": "black flying v electric guitar with red details standing upright on a small black "
                "guitar stand on the floor, isometric view",
    },
    "red_velvet_rug": {
        "size": (168, 112), "style": "plush_armchair_rot0.png", "canvas": (256, 192), "anchor": (128, 172),
        "desc": "rectangular deep red persian rug with an ornate black and gold gothic pattern and "
                "fringed ends lying flat on the floor, isometric view from above",
    },
    "stained_glass_window": {
        "wall": True, "size": (56, 96), "style": "curtained_window_n.png", "canvas": (128, 160), "center_y": 71,
        "desc": "tall gothic arched stained glass window with a deep purple, crimson and blue rose "
                "pattern in a black stone frame, seen straight from the front, flat front view, no "
                "perspective",
    },
    # phase 4: Rústico (wood from the closet, fabric from the armchair)
    "log_bed": {
        "size": (160, 120), "style": "closet_rot0.png", "canvas": (192, 144), "anchor": (96, 138),
        "desc": "rustic single bed made of thick round pine logs with a log headboard, a red and green "
                "plaid wool blanket, white pillows and a knitted throw, isometric view, the bed's length "
                "runs from the upper right to the lower left",
    },
    "lantern_table": {
        "size": (40, 48), "style": "coffee_mug_rot0.png", "canvas": (64, 64), "anchor": (34, 60),
        "desc": "old black iron camping oil lantern with a glowing warm flame behind the glass and a "
                "wire handle, isometric view",
    },
    "firewood_stack_sm": {
        "size": (56, 56), "style": "fireplace_rot0.png", "canvas": (128, 176), "anchor": (62, 168),
        "desc": "neat stack of split firewood logs in a small black iron log holder, isometric view",
    },
    "plaid_rug": {
        "size": (168, 112), "style": "plush_armchair_rot0.png", "canvas": (256, 192), "anchor": (128, 172),
        "desc": "rectangular red and dark green tartan plaid wool rug with fringed ends lying flat on "
                "the floor, isometric view from above",
    },
    "wall_plush_deer_head": {
        "wall": True, "size": (64, 64), "style": "closet_rot0.png", "canvas": (128, 128), "center_y": 48,
        "desc": "cute plush toy deer head with soft felt antlers mounted on a round wooden plaque, seen "
                "straight from the front, flat front view, no perspective",
    },
    # wall pieces: generated flat (front view), slanted here like the wall panels; _w is the mirror.
    # "center_y": vertical centre of the art in the 128x128 wall sprite (where the old art was).
    "wall_clock": {
        "wall": True, "size": (40, 72), "style": "closet_rot0.png", "canvas": (128, 128), "center_y": 50,
        "desc": "wooden pendulum wall clock seen straight from the front, a round white face with black "
                "hands, a brass pendulum in a glass case below, flat front view, no perspective",
    },
    "wall_world_map": {
        "wall": True, "size": (56, 48), "style": "closet_rot0.png", "canvas": (128, 128), "center_y": 52,
        "desc": "framed world map poster with red pins and a few small travel photos pinned to it, seen "
                "straight from the front, flat front view, no perspective",
    },
    "hanging_shelf_wall": {
        "wall": True, "size": (60, 40), "style": "closet_rot0.png", "canvas": (128, 128), "center_y": 81,
        "desc": "small wooden wall shelf on two brackets holding a few books, a little potted plant and "
                "a candle, seen straight from the front, flat front view, no perspective",
    },
    "curtained_window": {
        "wall": True, "size": (72, 96), "style": "closet_rot0.png", "canvas": (128, 160), "center_y": 71,
        # taller canvas: slanted, the window is 132 px high (same centre as the old 128 sprite at 55)
        "desc": "window with a white wooden frame and four glass panes showing a blue sky, red curtains "
                "tied to both sides on a curtain rod, seen straight from the front, flat front view, "
                "no perspective",
    },
}

def _key():
    cwd = os.getcwd()
    os.chdir(ROOT)  # pixellab_config.json is relative
    sys.path.insert(0, ROOT)
    try:
        from pixellab_service import load_pixellab_key
        return load_pixellab_key()
    finally:
        os.chdir(cwd)


def _b64(img):
    buf = io.BytesIO()
    img.convert("RGBA").save(buf, "PNG")
    return {"type": "base64", "base64": base64.b64encode(buf.getvalue()).decode(), "format": "png"}


def _decode(s):
    s = s["base64"] if isinstance(s, dict) else s
    s = s.split(",", 1)[-1]
    return Image.open(io.BytesIO(base64.b64decode(s + "=" * (-len(s) % 4)))).convert("RGBA")


# ------------------------------------------------------------------ geometry
def to_px(geo, x, y, z=0.0):
    """Grid point (x, y) at height z (world units) -> sprite pixel, like the game's sprite offset."""
    ox, oy = geo["offset"]
    sx = (x - y) * 32
    sy = (x + y) * 16 - 16 - z
    return ((sx - ox) * 2, (sy - oy) * 2)


def footprint_poly(geo, z=0.0):
    w, h = geo["tiles"]
    return [to_px(geo, *p, z) for p in ((0, 0), (w, 0), (w, h), (0, h))]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def quad(a, b, c, d, u0, u1, v0, v1):
    """Sub-rectangle of the quad a-b-c-d (a-b along u, a-d along v)."""
    def at(u, v):
        return lerp(lerp(a, b, u), lerp(d, c, u), v)
    return [at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1)]


def blockout(pid, view):
    """Flat-shaded box filling the footprint; view 0 = front faces the viewer's left (rot0),
    view 2 = back view (front faces away)."""
    p = PIECES[pid]
    if p.get("kind") == "table":
        return blockout_table(pid)
    if p.get("kind") == "boxes":
        return blockout_boxes(pid, view)
    if p.get("kind") == "fountain":
        return blockout_fountain(pid)
    if p.get("kind") == "canopy":
        return blockout_canopy(pid, view)
    if p.get("kind") == "heart":
        return blockout_heart(pid, view)
    if p.get("kind") == "shape":
        return Image.open(os.path.join(EST, f"{p['shape']}_rot{view}.png")).convert("RGBA")
    geo = GEOMETRY[p["footprint"]]
    w, h = geo["tiles"]
    z = p["height"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top = footprint_poly(geo, z)          # (0,0) (w,0) (w,h) (0,h) at counter height
    base = footprint_poly(geo, 0)
    # visible side faces: left = edge (0,h)-(w,h) ... the faces toward the viewer are y=h (left) and
    # x=w (right)
    left = [top[3], top[2], base[2], base[3]]
    right = [top[2], top[1], base[1], base[2]]
    steel = "stove" in pid
    body_l, body_r = ((150, 155, 165), (120, 125, 135)) if steel else ((150, 100, 60), (115, 75, 45))
    d.polygon(left, fill=body_l + (255,))
    d.polygon(right, fill=body_r + (255,))
    d.polygon(top, fill=((40, 40, 45, 255) if steel else (235, 235, 230, 255)))
    ink = (60, 40, 30, 255)
    feats = p["features"]
    if view == 0:
        if "doors" in feats:
            for u0, u1 in ((0.08, 0.48), (0.52, 0.92)):
                d.polygon(quad(*left, u0, u1, 0.15, 0.9), outline=ink)
                hx, hy = lerp(*quad(*left, u0, u1, 0.3, 0.3)[:2], 0.85 if u0 < 0.5 else 0.15)
                d.rectangle((hx - 1, hy - 3, hx, hy + 3), fill=(200, 200, 205, 255))
        if "oven" in feats:
            d.polygon(quad(*left, 0.1, 0.9, 0.3, 0.92), fill=(60, 60, 70, 255), outline=ink)
            d.polygon(quad(*left, 0.2, 0.8, 0.42, 0.8), fill=(25, 25, 35, 255))
            for u in (0.2, 0.4, 0.6, 0.8):
                x, y = quad(*left, u, u, 0.12, 0.12)[0]
                d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(30, 30, 30, 255))
    if "basin" in feats:
        d.polygon(quad(*top, 0.3, 0.75, 0.25, 0.75), fill=(170, 175, 185, 255), outline=(110, 115, 125, 255))
    if "faucet" in feats:
        # at the back edge: the front is the y = h face, so the back is the y = 0 edge
        bx, by = lerp(top[0], top[1], 0.5)
        bx, by = lerp((bx, by), lerp(top[3], top[2], 0.5), 0.15)
        d.line((bx, by, bx, by - 14), fill=(190, 195, 205, 255), width=2)
        d.line((bx, by - 14, bx + 8, by - 10), fill=(190, 195, 205, 255), width=2)
    if "burners" in feats:
        for u, v in ((0.3, 0.3), (0.7, 0.3), (0.3, 0.7), (0.7, 0.7)):
            x, y = quad(*top, u, u, v, v)[0]
            d.ellipse((x - 7, y - 4, x + 7, y + 4), outline=(120, 120, 125, 255), width=2)
        d.polygon([top[0], top[1], (top[1][0], top[1][1] - 10), (top[0][0], top[0][1] - 10)],
                  fill=(150, 155, 165, 255))
    if view == 2:
        # back view: the same object turned 180 degrees = rot0 mirrored through the centre, but
        # with the plain back panel where the front was. Draw rot0's top turned and plain sides.
        im = im.transpose(Image.ROTATE_180)
        im = blockout_back(pid, im)
    return im


def blockout_table(pid, inset=0.06, thick=4, leg=0.12):
    """Table: a top slab over the whole footprint (slightly inset) on four corner legs."""
    p = PIECES[pid]
    geo = GEOMETRY[p["footprint"]]
    w, h = geo["tiles"]
    z = p["height"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wood_l, wood_r, wood_t, ink = (140, 90, 50, 255), (110, 70, 40, 255), (175, 120, 70, 255), (70, 45, 25, 255)

    def box(x0, y0, x1, y1, z0, z1, fill_t=wood_t):
        t = [to_px(geo, x, y, z1) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        b = [to_px(geo, x, y, z0) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        d.polygon([t[3], t[2], b[2], b[3]], fill=wood_l)
        d.polygon([t[2], t[1], b[1], b[2]], fill=wood_r)
        d.polygon(t, fill=fill_t)

    i = inset
    # back legs first, then the front ones, then the top
    legs = [(i, i), (w - i - leg, i), (i, h - i - leg), (w - i - leg, h - i - leg)]
    for lx, ly in sorted(legs, key=lambda q: q[0] + q[1]):
        box(lx, ly, lx + leg, ly + leg, 0, z - thick)
    box(i, i, w - i, h - i, z - thick, z)
    # plank joints along the table
    for k in range(1, 5):
        y = i + (h - 2 * i) * k / 5
        d.line([to_px(geo, i, y, z), to_px(geo, w - i, y, z)], fill=(140, 92, 52, 255), width=1)
    return im


def blockout_boxes(pid, view):
    """Stacked boxes (x0, y0, x1, y1, z0, z1, colour, front_feature) in tile units. The front is the
    y1 face (the viewer's lower left in rot0). view 2 turns the piece 180 degrees: the boxes are
    mirrored through the footprint centre and the front features face away (not drawn)."""
    p = PIECES[pid]
    geo = GEOMETRY[p["footprint"]]
    w, h = geo["tiles"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    boxes = p["boxes"]
    if view == 2:
        boxes = [(w - x1, h - y1, w - x0, h - y0, z0, z1, c, None) for x0, y0, x1, y1, z0, z1, c, _ in boxes]
    for x0, y0, x1, y1, z0, z1, col, feat in sorted(boxes, key=lambda b: (b[4], b[0] + b[1])):
        t = [to_px(geo, x, y, z1) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        b = [to_px(geo, x, y, z0) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        left = [t[3], t[2], b[2], b[3]]
        d.polygon(left, fill=col + (255,))
        d.polygon([t[2], t[1], b[1], b[2]], fill=tuple(int(c * 0.78) for c in col) + (255,))
        d.polygon(t, fill=tuple(min(255, int(c * 1.15)) for c in col) + (255,))
        if feat == "screen":
            d.polygon(quad(*left, 0.06, 0.94, 0.08, 0.9), fill=(30, 60, 110, 255))
        elif feat == "mirror":
            d.polygon(quad(*left, 0.14, 0.86, 0.1, 0.9), fill=(170, 200, 220, 255))
        elif feat == "drawers":
            for u0, u1 in ((0.06, 0.3), (0.7, 0.94)):
                d.polygon(quad(*left, u0, u1, 0.2, 0.75), outline=(150, 120, 130, 255))
        elif feat == "crt":
            d.polygon(quad(*left, 0.12, 0.88, 0.12, 0.82), fill=(35, 45, 60, 255))
            d.polygon(quad(*left, 0.2, 0.5, 0.2, 0.35), fill=(90, 120, 150, 255))
        elif feat == "shelves":
            d.polygon(quad(*left, 0.08, 0.46, 0.2, 0.8), fill=(60, 40, 25, 255))
            d.polygon(quad(*left, 0.54, 0.92, 0.2, 0.8), fill=(60, 40, 25, 255))
    return im


def blockout_canopy(pid, view):
    """Bed (frame, mattress, pillows at the head, y = 0 end) with four corner posts and a canopy
    frame on top. view 2 turns it 180 degrees (head at the near end)."""
    p = PIECES[pid]
    geo = GEOMETRY[p["footprint"]]
    w, h = geo["tiles"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def box(x0, y0, x1, y1, z0, z1, col):
        if view == 2:
            x0, y0, x1, y1 = w - x1, h - y1, w - x0, h - y0
        t = [to_px(geo, x, y, z1) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        b = [to_px(geo, x, y, z0) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
        d.polygon([t[3], t[2], b[2], b[3]], fill=col + (255,))
        d.polygon([t[2], t[1], b[1], b[2]], fill=tuple(int(c * 0.8) for c in col) + (255,))
        d.polygon(t, fill=tuple(min(255, int(c * 1.12)) for c in col) + (255,))

    frame, sheet, pillow, post, drape = (235, 215, 220), (245, 180, 200), (255, 245, 248), (240, 225, 228), (250, 205, 220)
    i, pw, top = 0.05, 0.08, 64
    parts = [
        (i, i, w - i, h - i, 0, 8, frame),               # bed frame
        (i + 0.03, i + 0.03, w - i - 0.03, h - i - 0.03, 8, 15, sheet),  # mattress and covers
        (i + 0.12, i + 0.08, w - i - 0.12, i + 0.32, 15, 19, pillow),     # pillows at the head
        (i, i, w - i, i + 0.07, 0, 30, frame),           # headboard
    ]
    posts = [(i, i), (w - i - pw, i), (i, h - i - pw), (w - i - pw, h - i - pw)]
    # far posts first, then the bed, then the near posts, then the canopy
    far = [q for q in posts if (q[0] + q[1]) < (w + h) / 2]
    near = [q for q in posts if q not in far]
    for x, y in far:
        box(x, y, x + pw, y + pw, 0, top, post)
    for part in parts:
        box(*part)
    for x, y in near:
        box(x, y, x + pw, y + pw, 0, top, post)
    # canopy: four rails joining the post tops (the drapes come from the reference)
    r = 0.05
    for rail in ((i, i, w - i, i + r), (i, h - i - r, w - i, h - i), (i, i, i + r, h - i), (w - i - r, i, w - i, h - i)):
        box(*rail, top - 3, top + 1, drape)
    return im


def blockout_heart(pid, view):
    """A flat heart lying on the floor, centred on the footprint, upright to the camera: the tip
    points at the viewer in rot0 and away in rot2."""
    import math
    p = PIECES[pid]
    geo = GEOMETRY[p["footprint"]]
    w, h = geo["tiles"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    sign = 1 if view == 0 else -1
    k = 1.15 * min(w, h) / 2 / 24.0
    r2 = math.sqrt(0.5)
    pts = []
    for n in range(120):
        t = 2 * math.pi * n / 120
        hx = 16 * math.sin(t) ** 3
        hy = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        # upright to the camera: the heart's right is the screen's right (grid (1, -1)) and its tip
        # points at the viewer (grid (1, 1)) in rot0, away from it in rot2
        a, b = sign * hx * k, -sign * (hy + 3) * k
        pts.append((w / 2 + (a + b) * r2, h / 2 + (b - a) * r2))
    d.polygon([to_px(geo, x, y, 0) for x, y in pts], fill=(220, 150, 175, 255))
    d.polygon([to_px(geo, x, y, 2) for x, y in pts], fill=(245, 185, 205, 255), outline=(255, 245, 250, 255))
    return im


def circle(geo, cx, cy, r, z, n=48, start=0.0, end=6.2832):
    import math
    return [to_px(geo, cx + r * math.cos(a), cy + r * math.sin(a), z)
            for a in (start + (end - start) * k / n for k in range(n + 1))]


def blockout_fountain(pid):
    """Round basin with a central pedestal and top bowl, centred on the footprint."""
    import math
    p = PIECES[pid]
    geo = GEOMETRY[p["footprint"]]
    w, h = geo["tiles"]
    cx, cy = w / 2, h / 2
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    stone, stone_d, stone_l, water = (150, 150, 145), (110, 110, 108), (185, 183, 175), (80, 150, 210)

    def cylinder(r, z0, z1, side, top):
        # front half of the side (angles 0..pi face the viewer: +x/+y), then the top disc
        d.polygon(circle(geo, cx, cy, r, z1, start=-math.pi / 4, end=3 * math.pi / 4)
                  + circle(geo, cx, cy, r, z0, start=-math.pi / 4, end=3 * math.pi / 4)[::-1],
                  fill=side + (255,))
        d.polygon(circle(geo, cx, cy, r, z1), fill=top + (255,))

    R = 0.95 * min(w, h) / 2
    cylinder(R, 0, 10, stone_d, stone_l)
    d.polygon(circle(geo, cx, cy, R * 0.85, 10), fill=water + (255,))
    cylinder(0.12 * min(w, h), 6, 26, stone_d, stone)
    cylinder(0.25 * min(w, h), 26, 30, stone_d, stone_l)
    d.polygon(circle(geo, cx, cy, 0.25 * min(w, h) * 0.75, 30), fill=water + (255,))
    sx, sy = to_px(geo, cx, cy, 30)
    d.line((sx, sy, sx, sy - 12), fill=(200, 230, 255, 255), width=2)
    return im


def blockout_back(pid, _unused):
    p = PIECES[pid]
    geo = GEOMETRY[p["footprint"]]
    z = p["height"]
    im = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top = footprint_poly(geo, z)
    base = footprint_poly(geo, 0)
    left = [top[3], top[2], base[2], base[3]]
    right = [top[2], top[1], base[1], base[2]]
    steel = "stove" in pid
    body_l, body_r = ((150, 155, 165), (120, 125, 135)) if steel else ((150, 100, 60), (115, 75, 45))
    d.polygon(left, fill=body_l + (255,))
    d.polygon(right, fill=body_r + (255,))
    d.polygon(top, fill=((40, 40, 45, 255) if steel else (235, 235, 230, 255)))
    feats = p["features"]
    if "basin" in feats:
        d.polygon(quad(*top, 0.25, 0.7, 0.25, 0.75), fill=(170, 175, 185, 255), outline=(110, 115, 125, 255))
    if "faucet" in feats:
        # the back edge is now the near-left side (y = h)
        bx, by = lerp(top[3], top[2], 0.5)
        bx, by = lerp((bx, by), lerp(top[0], top[1], 0.5), 0.12)
        d.line((bx, by, bx, by - 14), fill=(190, 195, 205, 255), width=2)
        d.line((bx, by - 14, bx + 8, by - 18), fill=(190, 195, 205, 255), width=2)
    if "burners" in feats:
        for u, v in ((0.3, 0.3), (0.7, 0.3), (0.3, 0.7), (0.7, 0.7)):
            x, y = quad(*top, u, u, v, v)[0]
            d.ellipse((x - 7, y - 4, x + 7, y + 4), outline=(120, 120, 125, 255), width=2)
        d.polygon([top[3], top[2], (top[2][0], top[2][1] - 10), (top[3][0], top[3][1] - 10)],
                  fill=(150, 155, 165, 255))
    return im


# ------------------------------------------------------------------ generation
def prompt(pid):
    p = PIECES[pid]
    return (f"isometric pixel art furniture for a cozy room game. Frame 1: {p['front']}, {p['top']}, "
            f"seen from the front. Frame 2: the same piece seen from behind: {p['back']}, {p['top']}. "
            "Keep the exact box shape, size and position of each frame, fill the whole box, detailed "
            "shading and texture, selective outline, same palette and style as frame 3. Frame 3 stays "
            "the same.")


def generate_ref(pid, seed=None, ref=None):
    """edit_with_reference: the blockouts take the look of a finished sprite (by default the piece's
    current rot0), keeping their own shape."""
    os.makedirs(GEN, exist_ok=True)
    geo = GEOMETRY[PIECES[pid]["footprint"]]
    symmetric = PIECES[pid].get("symmetric")
    frames = [blockout(pid, 0)] if symmetric else [blockout(pid, 0), blockout(pid, 2)]
    ref = ref or PIECES[pid].get("reference") or f"{pid}_rot0.png"
    refim = _ref_image(ref)
    if PIECES[pid].get("reference_back") and not symmetric:
        # each view with its own reference (a single shared one gets copied into the back view)
        return _generate_ref_views(pid, seed, frames, refim, _ref_image(PIECES[pid]["reference_back"]))
    w, h = geo["canvas"]
    # Over 128 px edit-images-v2 takes ONE frame per call: put both views side by side in a single
    # image (up to 512 wide) so they are still edited together, then split the result.
    packed = len(frames) > 1 and max(w, h) > 128 and w * len(frames) <= 512
    if packed:
        sheet_im = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            sheet_im.alpha_composite(f, (i * w, 0))
        frames, (fw, fh) = [sheet_im], sheet_im.size
    else:
        fw, fh = w, h
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    payload = {
        "method": "edit_with_reference",
        "edit_images": [{"image": _b64(f), "width": fw, "height": fh} for f in frames],
        "image_size": {"width": fw, "height": fh},
        "reference_image": {"image": _b64(refim), "width": refim.width, "height": refim.height},
        "no_background": True,
    }
    if seed is not None:
        payload["seed"] = seed
    data = _run(headers, "edit-images-v2", payload, pid)
    images = data.get("images") or []
    if packed and images:
        whole = _decode(images[0])
        images = []
        for i in range(whole.width // w):
            buf = io.BytesIO()
            whole.crop((i * w, 0, (i + 1) * w, h)).save(buf, "PNG")
            images.append(base64.b64encode(buf.getvalue()).decode())
    tag = "rs" + (str(seed) if seed is not None else time.strftime("%H%M%S"))
    for i, s in enumerate(images[:2]):
        _decode(s).save(os.path.join(GEN, f"{pid}_{tag}_r{2 * i}.png"))
    if symmetric and images:
        _decode(images[0]).save(os.path.join(GEN, f"{pid}_{tag}_r2.png"))
    print(pid, tag, "got", len(images), "images")


def _ref_image(ref):
    """A catalog sprite by file name, or a chosen --genimg candidate as "gen:<name>", cropped."""
    if ref.startswith("gen:"):
        im = Image.open(os.path.join(GEN, ref[4:] + ".png")).convert("RGBA")
    else:
        im = Image.open(os.path.join(EST, ref)).convert("RGBA")
    return im.crop(im.getchannel("A").getbbox())


def _generate_ref_views(pid, seed, frames, ref_front, ref_back):
    geo = GEOMETRY[PIECES[pid]["footprint"]]
    w, h = geo["canvas"]
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    tag = "rv" + (str(seed) if seed is not None else time.strftime("%H%M%S"))
    for r, frame, refim in ((0, frames[0], ref_front), (2, frames[1], ref_back)):
        payload = {
            "method": "edit_with_reference",
            "edit_images": [{"image": _b64(frame), "width": w, "height": h}],
            "image_size": {"width": w, "height": h},
            "reference_image": {"image": _b64(refim), "width": refim.width, "height": refim.height},
            "no_background": True,
        }
        if seed is not None:
            payload["seed"] = seed
        data = _run(headers, "edit-images-v2", payload, pid)
        _decode((data.get("images") or [])[0]).save(os.path.join(GEN, f"{pid}_{tag}_r{r}.png"))
    print(pid, tag, "views generated with separate references")


def _run(headers, endpoint, payload, label):
    r = requests.post(f"{API}/{endpoint}", headers=headers, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{r.status_code} {r.text[:500]}")
    job = r.json().get("background_job_id")
    for _ in range(100):
        time.sleep(6)
        try:
            j = requests.get(f"{API}/background-jobs/{job}", headers=headers, timeout=30).json()
        except requests.RequestException:
            continue
        if j.get("status") == "completed":
            return j.get("last_response", {})
        if j.get("status") == "failed":
            raise RuntimeError(json.dumps(j)[:500])
    raise RuntimeError(f"{label}: job {job} still running")


def generate(pid, seed=None):
    os.makedirs(GEN, exist_ok=True)
    geo = GEOMETRY[PIECES[pid]["footprint"]]
    frames = [blockout(pid, 0), blockout(pid, 2)]
    anchor = Image.open(os.path.join(EST, STYLE_ANCHOR)).convert("RGBA")
    if anchor.size != geo["canvas"]:
        c = Image.new("RGBA", geo["canvas"], (0, 0, 0, 0))
        c.alpha_composite(anchor.crop((0, max(0, anchor.height - geo["canvas"][1]), anchor.width,
                                       anchor.height)), (0, 0))
        anchor = c
    frames.append(anchor)
    for i, f in enumerate(frames):
        f.save(os.path.join(GEN, f"_input_{pid}_{i}.png"))
    w, h = geo["canvas"]
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    payload = {
        "method": "edit_with_text",
        "edit_images": [{"image": _b64(f), "width": w, "height": h} for f in frames],
        "image_size": {"width": w, "height": h},
        "description": prompt(pid),
        "no_background": True,
    }
    if seed is not None:
        payload["seed"] = seed
    r = requests.post(f"{API}/edit-images-v2", headers=headers, json=payload, timeout=60)
    if r.status_code not in (200, 202):
        raise RuntimeError(f"{r.status_code} {r.text[:500]}")
    job = r.json().get("background_job_id")
    for _ in range(100):
        time.sleep(6)
        try:
            j = requests.get(f"{API}/background-jobs/{job}", headers=headers, timeout=30).json()
        except requests.RequestException:
            continue
        if j.get("status") == "completed":
            data = j.get("last_response", {})
            break
        if j.get("status") == "failed":
            raise RuntimeError(json.dumps(j)[:500])
    else:
        raise RuntimeError(f"{pid}: job {job} still running")
    images = data.get("images") or []
    tag = f"s{seed}" if seed is not None else time.strftime("t%H%M%S")
    for i, s in enumerate(images[:2]):
        _decode(s).save(os.path.join(GEN, f"{pid}_{tag}_r{2 * i}.png"))
    print(pid, tag, "got", len(images), "images")


# ------------------------------------------------------------------ review / build
def on_footprint(pid, im, scale=3):
    geo = GEOMETRY[PIECES[pid]["footprint"]]
    bg = Image.new("RGBA", geo["canvas"], (34, 36, 48, 255))
    d = ImageDraw.Draw(bg)
    d.polygon(footprint_poly(geo), fill=(255, 45, 154, 90), outline=(255, 45, 154, 255))
    bg.alpha_composite(im)
    return bg.resize((bg.width * scale, bg.height * scale), Image.NEAREST)


def preview_blockout(pid):
    ims = [on_footprint(pid, blockout(pid, v)) for v in (0, 2)]
    out = Image.new("RGBA", (sum(i.width for i in ims) + 8, ims[0].height), (0, 0, 0, 255))
    x = 0
    for i in ims:
        out.alpha_composite(i, (x, 0))
        x += i.width + 8
    out.save(os.path.join(GEN, f"_blockout_{pid}.png"))
    print("saved", f"gen/_blockout_{pid}.png")


def sheet():
    names = sorted({f.rsplit("_r", 1)[0] for f in os.listdir(GEN)
                    if not f.startswith("_") and f.endswith(("_r0.png", "_r2.png"))
                    and any(f.startswith(p + "_") for p in PIECES)})
    rows = []
    for n in names:
        pid = next(p for p in sorted(PIECES, key=len, reverse=True) if n.startswith(p + "_"))
        cur = [Image.open(os.path.join(EST, f"{pid}_rot{r}.png")).convert("RGBA") for r in (0, 2)]
        new = [Image.open(os.path.join(GEN, f"{n}_r{r}.png")).convert("RGBA") for r in (0, 2)]
        cells = [on_footprint(pid, im, 2) for im in cur + new]
        row = Image.new("RGBA", (sum(c.width + 6 for c in cells), cells[0].height + 16), (12, 14, 21, 255))
        ImageDraw.Draw(row).text((4, 2), f"{n}: actual rot0, rot2 | nuevo rot0, rot2", fill=(255, 230, 120, 255))
        x = 0
        for c in cells:
            row.alpha_composite(c, (x, 16))
            x += c.width + 6
        rows.append(row)
    out = Image.new("RGBA", (max(r.width for r in rows), sum(r.height for r in rows)), (12, 14, 21, 255))
    y = 0
    for r in rows:
        out.alpha_composite(r, (0, y))
        y += r.height
    out.save(os.path.join(GEN, "_sheet.png"))
    print("sheet:", len(rows))


def build(pid, name):
    r0 = Image.open(os.path.join(GEN, f"{name}_r0.png")).convert("RGBA")
    r2 = Image.open(os.path.join(GEN, f"{name}_r2.png")).convert("RGBA")
    sys.path.insert(0, os.path.join(ROOT, "face_pipeline"))
    from convert_selout import convert_colour
    r0, r2 = convert_colour(r0), convert_colour(r2)
    views = {0: r0, 1: r0.transpose(Image.FLIP_LEFT_RIGHT), 2: r2, 3: r2.transpose(Image.FLIP_LEFT_RIGHT)}
    n = write_views(pid, views)
    if PIECES[pid].get("seat"):
        write_files(seat_fronts(pid, views))
    print("built", pid, "from", name, f"(+{n} in new_added)")


# New pieces' catalog entries (name, zone, footprint, canvas, sprite offset, surface height).
NEW_CATALOG = {
    "canopy_bed": ("Cama con Dosel", "bedroom", "1x2", [192, 240], [-64, -84], 0),
    "crt_tv_console": ("Tele de Tubo con Consola", "living", "1x1", [128, 128], [-32, -48], 0),
    "vanity_table": ("Tocador con Espejo", "bedroom", "1x1", [128, 128], [-32, -48], 18),
    "heart_rug": ("Alfombra Corazón", "living", "2x2", [256, 192], [-64, -44], 0),
    "flower_vase_pink": ("Florero de Rosas", "decor", "surface", [64, 64], [-32, -48], 0),
    "plush_teddy": ("Osito de Peluche", "decor", "surface", [64, 64], [-32, -48], 0),
    "wall_bow_garland": ("Guirnalda de Moños", "decor", "wall_n", [128, 128], [-32, -48], 0),
    "inflatable_chair": ("Sillón Inflable", "living", "1x1", [128, 128], [-32, -48], 0),
    "boombox_radio": ("Radiocasete", "decor", "surface", [64, 64], [-32, -48], 0),
    "memphis_rug": ("Alfombra Memphis", "living", "2x2", [256, 192], [-64, -44], 0),
    "wall_cassette_rack": ("Repisa de Casetes", "decor", "wall_n", [128, 128], [-32, -48], 0),
    "wall_poster_90s": ("Póster Noventero", "decor", "wall_n", [128, 128], [-32, -48], 0),
    "velvet_armchair": ("Sillón de Terciopelo", "living", "1x1", [128, 128], [-32, -48], 0),
    "gothic_canopy_bed": ("Cama con Dosel Gótica", "bedroom", "1x2", [192, 240], [-64, -84], 0),
    "candelabra_floor_sm": ("Candelabro de Pie (0.5x0.5)", "living", "0.5x0.5", [128, 176], [-32, -44], 0),
    "electric_guitar_stand_sm": ("Guitarra Eléctrica (0.5x0.5)", "living", "0.5x0.5", [128, 176], [-32, -44], 0),
    "red_velvet_rug": ("Alfombra Roja", "living", "2x2", [256, 192], [-64, -44], 0),
    "stained_glass_window": ("Vitral Gótico", "decor", "wall_n", [128, 160], [-32, -48], 0),
    "log_bed": ("Cama de Troncos", "bedroom", "1x2", [192, 144], [-64, -36], 0),
    "lantern_table": ("Farol de Aceite", "decor", "surface", [64, 64], [-32, -48], 0),
    "firewood_stack_sm": ("Leña Apilada (0.5x0.5)", "living", "0.5x0.5", [128, 176], [-32, -44], 0),
    "plaid_rug": ("Alfombra Escocesa", "living", "2x2", [256, 192], [-64, -44], 0),
    "wall_plush_deer_head": ("Ciervo de Peluche", "decor", "wall_n", [128, 128], [-32, -48], 0),
}
CATALOG = os.path.join(REPO, "frontend", "assets", "images", "furniture", "furniture_catalog.json")


def add_catalog(pid):
    """Writes the piece's entry in furniture_catalog.json, in the sync's format (2-space indent, no
    trailing newline), without touching the other entries."""
    name, zone, fp, canvas, offset, surf = NEW_CATALOG[pid]
    data = json.load(open(CATALOG, encoding="utf-8"))
    if fp == "wall_n":
        views = [(0, f"{pid}_n", f"{name} (Norte)", "wall_n"), (1, f"{pid}_w", f"{name} (Oeste)", "wall_w")]
    else:
        views = [(r, f"{pid}_rot{r}", f"{name} Rot {r}", fp) for r in range(4)]
    rots = {}
    for r, rid, rname, rfp in views:
        rots[str(r)] = {"id": rid, "name": rname, "footprint": rfp, "rot": r, "canvas_size": canvas,
                        "sprite_offset": offset, "surface_height": surf, "supports_surface": surf > 0,
                        "surface_offset": [0, 0], "asset_path": f"furniture/established_furniture/{rid}.png"}
    data[pid] = {"name": name, "zone": zone, "footprint": fp, "surface_height": surf,
                 "supports_surface": surf > 0, "surface_offset": [0, 0], "canvas_size": canvas,
                 "sprite_offset": offset, "has_table_magnet": False, "rotations": rots}
    with open(CATALOG, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(data, indent=2, ensure_ascii=False))
    print("catalog:", pid)


def seat_fronts(pid, views):
    """Front layers of a seat (drawn over the sitter): for the front views, the pixels of the new
    sprite under the shape piece's own front layer (grown by 2 px); seen from behind (rot2/3) the
    backrest covers the sitter, so the whole sprite."""
    from PIL import ImageFilter
    shape = PIECES[pid]["shape"]
    out = {}
    for r, im in views.items():
        if r in (2, 3):
            out[f"{pid}_rot{r}_front.png"] = im
            continue
        mask = Image.open(os.path.join(EST, f"{shape}_rot{r}_front.png")).getchannel("A")
        mask = mask.point(lambda a: 255 if a > 40 else 0).filter(ImageFilter.MaxFilter(5))
        # down to the bottom in the arm's columns: under the near arm the chair is in front of the
        # sitter too (the new piece's arm may sit lower than the shape piece's)
        px = mask.load()
        for x in range(mask.width):
            top = next((y for y in range(mask.height) if px[x, y]), None)
            if top is not None:
                for y in range(top, mask.height):
                    px[x, y] = 255
        front = Image.new("RGBA", im.size, (0, 0, 0, 0))
        front.paste(im, (0, 0), mask)
        out[f"{pid}_rot{r}_front.png"] = front
    return out


def write_views(pid, views):
    """views: rot -> image. Writes established_furniture/<pid>_rot*.png (+ <pid>.png = rot0) and
    replaces the copies in new_added/ (the sync's sources), or the next sync_furniture_assets.py
    would copy the old art back. Returns how many new_added/ files were replaced."""
    files = {f"{pid}_rot{r}.png": im for r, im in views.items()}
    files[f"{pid}.png"] = views[0]
    return write_files(files)


def write_files(files):
    """file name -> image, into established_furniture/ and over any copy in new_added/."""
    sources = {}
    for root, _, names in os.walk(NEW_ADDED):
        for n in names:
            if n in files:
                sources[n] = os.path.join(root, n)
    for n, im in files.items():
        im.save(os.path.join(EST, n))
        if n in sources:
            im.save(sources[n])
    return len(sources)


# ------------------------------------------------------------------ small pieces / restyle
def generate_img(pid, seed=None):
    spec = IMG_PIECES[pid]
    os.makedirs(GEN, exist_ok=True)
    style = _ref_image(spec["style"])
    headers = {"Authorization": f"Bearer {_key()}", "Content-Type": "application/json"}
    payload = {
        "description": f"{spec['desc']}. Single object, pixel art game furniture sprite, selective "
                       "outline, detailed shading, no shadow on the ground, transparent background",
        "image_size": {"width": spec["size"][0], "height": spec["size"][1]},
        "no_background": not spec.get("opaque"),
        "style_image": {"image": _b64(style), "size": {"width": style.width, "height": style.height}},
        "style_options": {"color_palette": False, "outline": True, "detail": True, "shading": True},
    }
    if seed is not None:
        payload["seed"] = seed
    data = _run(headers, "generate-image-v2", payload, pid)
    images = data.get("images") or ([data["image"]] if data.get("image") else [])
    tag = "g" + (str(seed) if seed is not None else time.strftime("%H%M%S"))
    for i, im in enumerate(images):
        _decode(im).save(os.path.join(GEN, f"{pid}_{tag}_{i}.png"))
    print(pid, tag, "got", len(images), "candidates")


def drop_specks(art, keep=0.04):
    """Clears opaque blobs not connected to the object (generations sometimes add a stray piece
    below it): every 8-connected blob smaller than `keep` of the largest one is removed."""
    a = art.getchannel("A").load()
    w, h = art.size
    seen, blobs = set(), []
    for y in range(h):
        for x in range(w):
            if a[x, y] > 40 and (x, y) not in seen:
                stack, blob = [(x, y)], []
                seen.add((x, y))
                while stack:
                    px, py = stack.pop()
                    blob.append((px, py))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            q = (px + dx, py + dy)
                            if 0 <= q[0] < w and 0 <= q[1] < h and q not in seen and a[q] > 40:
                                seen.add(q)
                                stack.append(q)
                blobs.append(blob)
    if len(blobs) < 2:
        return art
    big = max(len(b) for b in blobs)
    out = art.copy()
    px = out.load()
    for b in blobs:
        if len(b) < keep * big:
            for p in b:
                px[p] = (0, 0, 0, 0)
    return out


def place(pid, art):
    """Art cropped to its opaque bbox, its bottom centre on the piece's anchor."""
    spec = IMG_PIECES[pid]
    art = drop_specks(art)
    art = art.crop(art.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox())
    canvas = Image.new("RGBA", spec["canvas"], (0, 0, 0, 0))
    if spec.get("wall"):
        # north wall: slanted like the wall panels (column c drops c // 2 rows, whole pixels, no
        # resampling), centred on the wall panel (x = 64 of the sprite) at the old art's height
        slanted = Image.new("RGBA", (art.width, art.height + art.width // 2), (0, 0, 0, 0))
        for c in range(art.width):
            slanted.paste(art.crop((c, 0, c + 1, art.height)), (c, c // 2))
        x = round(canvas.width / 2 - art.width / 2)
        x -= x % 2  # keep the slant steps on the wall's own 2-pixel grid
        canvas.alpha_composite(slanted, (x, round(spec["center_y"] - slanted.height / 2)))
        return canvas
    ax, ay = spec["anchor"]
    canvas.alpha_composite(art, (round(ax - art.width / 2), ay - art.height))
    return canvas


def candidates_sheet(pid):
    files = sorted(f for f in os.listdir(GEN) if f.startswith(pid + "_g") and f.endswith(".png"))
    spec = IMG_PIECES[pid]
    cur_path = os.path.join(EST, f"{pid}_n.png" if spec.get("wall") else f"{pid}_rot0.png")
    if os.path.exists(cur_path):
        cur = Image.open(cur_path).convert("RGBA")
    elif pid.endswith("_back") and pid[:-5] in PIECES:  # back view candidates: the back blockout
        cur = blockout(pid[:-5], 2)
    elif pid in PIECES:  # a new piece: show its blockout instead
        cur = blockout(pid, 0)
    else:  # a new small piece: nothing to compare with
        cur = Image.new("RGBA", spec["canvas"], (0, 0, 0, 0))
    if cur.size != spec["canvas"]:
        c = Image.new("RGBA", spec["canvas"], (0, 0, 0, 0))
        c.alpha_composite(cur, ((c.width - cur.width) // 2, c.height - cur.height))
        cur = c
    cells = [("actual", cur)] + [(f[len(pid) + 1:-4], place(pid, Image.open(os.path.join(GEN, f)).convert("RGBA")))
                                 for f in files]
    sc = 3
    cw, ch = spec["canvas"][0] * sc, spec["canvas"][1] * sc
    cols = 6
    out = Image.new("RGBA", (cols * (cw + 4), ((len(cells) + cols - 1) // cols) * (ch + 16)), (12, 14, 21, 255))
    d = ImageDraw.Draw(out)
    for i, (name, im) in enumerate(cells):
        bg = Image.new("RGBA", im.size, (40, 42, 55, 255))
        bg.alpha_composite(im)
        x, y = (i % cols) * (cw + 4), (i // cols) * (ch + 16)
        out.alpha_composite(bg.resize((cw, ch), Image.NEAREST), (x, y + 16))
        d.text((x + 2, y + 2), name, fill=(255, 230, 120, 255))
    out.save(os.path.join(GEN, f"_cand_{pid}.png"))
    print("saved", f"gen/_cand_{pid}.png", len(cells) - 1, "candidates")


def build_placed(pid, name):
    sys.path.insert(0, os.path.join(ROOT, "face_pipeline"))
    from convert_selout import convert_colour
    im = convert_colour(place(pid, Image.open(os.path.join(GEN, name + ".png")).convert("RGBA")))
    m = im.transpose(Image.FLIP_LEFT_RIGHT)
    if IMG_PIECES[pid].get("wall"):
        n = write_files({f"{pid}_n.png": im, f"{pid}_w.png": m, f"{pid}.png": im})
    else:
        n = write_views(pid, {0: im, 1: m, 2: im, 3: m})
    print("built", pid, "from", name, f"(+{n} in new_added)")


if __name__ == "__main__":
    args = sys.argv[1:]
    if "--blockout" in args:
        for pid in args[args.index("--blockout") + 1].split(","):
            preview_blockout(pid)
    elif "--genimg" in args:
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        for pid in args[args.index("--genimg") + 1].split(","):
            generate_img(pid, seed)
            candidates_sheet(pid)
    elif "--catalog" in args:
        for pid in args[args.index("--catalog") + 1].split(","):
            add_catalog(pid)
    elif "--cands" in args:
        for pid in args[args.index("--cands") + 1].split(","):
            candidates_sheet(pid)
    elif "--place" in args:
        for pair in args[args.index("--place") + 1:]:
            pid, name = pair.split("=")
            build_placed(pid, name)
    elif "--genref" in args:
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        for pid in args[args.index("--genref") + 1].split(","):
            generate_ref(pid, seed)
    elif "--gen" in args:
        seed = int(args[args.index("--seed") + 1]) if "--seed" in args else None
        for pid in args[args.index("--gen") + 1].split(","):
            generate(pid, seed)
    elif "--sheet" in args:
        sheet()
    elif "--build" in args:
        for pair in args[args.index("--build") + 1:]:
            pid, name = pair.split("=")
            build(pid, name)
    else:
        print(__doc__)
