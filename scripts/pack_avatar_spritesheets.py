import os
from PIL import Image

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC_64 = os.path.join(BASE_DIR, "CreateSprites", "assets")
SRC_32 = os.path.join(BASE_DIR, "CreateSprites", "assets_32x64")
DST_BASE = os.path.join(BASE_DIR, "frontend", "assets", "images", "avatar")

DIRECTIONS = ["down", "up", "left", "right"]
FRAME_COUNT = 4

def pack_item_spritesheet(item_folder):
    sample_path = os.path.join(item_folder, "down_frame0.png")
    if not os.path.exists(sample_path):
        return None
    
    with Image.open(sample_path) as sample_img:
        fw, fh = sample_img.size

    sheet = Image.new("RGBA", (fw * FRAME_COUNT, fh * len(DIRECTIONS)), (0, 0, 0, 0))

    for row, direction in enumerate(DIRECTIONS):
        for col in range(FRAME_COUNT):
            frame_filename = f"{direction}_frame{col}.png"
            frame_path = os.path.join(item_folder, frame_filename)
            if os.path.exists(frame_path):
                with Image.open(frame_path) as frame_img:
                    sheet.paste(frame_img, (col * fw, row * fh))
            else:
                print(f"Warning: Missing frame {frame_path}")

    return sheet

def process_source(src_dir, dst_dir, label):
    print(f"\n--- Packing {label} from {src_dir} to {dst_dir} ---")
    if not os.path.exists(src_dir):
        print(f"Directory {src_dir} does not exist. Skipping.")
        return 0

    os.makedirs(dst_dir, exist_ok=True)
    categories = [d for d in os.listdir(src_dir) if os.path.isdir(os.path.join(src_dir, d))]

    total_packed = 0
    for category in categories:
        cat_src = os.path.join(src_dir, category)
        cat_dst = os.path.join(dst_dir, category)
        os.makedirs(cat_dst, exist_ok=True)

        items = [d for d in os.listdir(cat_src) if os.path.isdir(os.path.join(cat_src, d))]
        for item in items:
            item_src = os.path.join(cat_src, item)
            spritesheet = pack_item_spritesheet(item_src)
            if spritesheet is not None:
                out_filename = f"{item}.png"
                out_path = os.path.join(cat_dst, out_filename)
                spritesheet.save(out_path, "PNG")
                total_packed += 1
                # print(f"  [OK] {category}/{item} -> {spritesheet.size[0]}x{spritesheet.size[1]}")

    print(f"Packed {total_packed} spritesheets for {label}.")
    return total_packed

def process_all():
    # 1. Pack 64x128 into avatar/64x128/ and avatar/ (for backwards compatibility)
    process_source(SRC_64, os.path.join(DST_BASE, "64x128"), "64x128")
    process_source(SRC_64, DST_BASE, "64x128 Root")
    # 2. Pack 32x64 into avatar/32x64/
    process_source(SRC_32, os.path.join(DST_BASE, "32x64"), "32x64 Pixelated")

if __name__ == "__main__":
    process_all()
