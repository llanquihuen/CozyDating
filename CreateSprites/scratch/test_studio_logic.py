import sys
import os
import json

sys.path.insert(0, os.path.abspath("CreateSprites"))
import furniture_inspector_engine as fie

catalog = fie.scan_new_added_furniture()
print("Total scanned items:", len(catalog))

for test_id in ["table", "dining_table_2x2", "gaming_pc_desk", "side_table", "table_lamp"]:
    item = catalog.get(test_id)
    if not item:
        print(f"{test_id}: NOT FOUND")
        continue
    spots_data = item.get("surface_spots", [])
    if isinstance(spots_data, dict):
        spots = spots_data.get(0, spots_data.get("0", []))
    else:
        spots = spots_data
    print(f"{test_id}: footprint={item.get('footprint')}, supports_surface={item.get('supports_surface')}, spots_count={len(spots)}")
    for s in spots:
        print(f"   -> spot {s.get('spot')}: sub_cell={s.get('sub_cell')}, offset={s.get('offset')}, item={s.get('item')}")

# Test render table
table_item = catalog.get("table")
rot0_spots = table_item.get("rotations", {}).get(0, {}).get("surface_spots") or table_item.get("surface_spots", {}).get(0, [])
img = fie.render_furniture_scene(
    furniture_item=table_item,
    rot=0,
    surface_spots=rot0_spots,
    active_surface_spot_idx=0,
    show_all_surface_items=True,
    show_surface_markers=True,
    catalog_lookup=catalog
)
os.makedirs("CreateSprites/scratch", exist_ok=True)
img.save("CreateSprites/scratch/test_table_render_multi.png")
print("Rendered table to CreateSprites/scratch/test_table_render_multi.png successfully!")

# Test render surface item table_lamp on dining_table_2x2
lamp_item = catalog.get("table_lamp")
dining_table = catalog.get("dining_table_2x2")
dt_spots = dining_table.get("rotations", {}).get(0, {}).get("surface_spots") or dining_table.get("surface_spots", {}).get(0, [])
img_lamp = fie.render_furniture_scene(
    furniture_item=lamp_item,
    rot=0,
    surface_support_item=dining_table,
    surface_spots=dt_spots,
    active_surface_spot_idx=2,
    show_surface_markers=True,
    catalog_lookup=catalog
)
img_lamp.save("CreateSprites/scratch/test_lamp_on_dining_table.png")
print("Rendered lamp on dining_table_2x2 to CreateSprites/scratch/test_lamp_on_dining_table.png successfully!")

# Test JSON generation
code = fie.generate_surface_spots_json_code("dining_table_2x2", 24, dt_spots)
print("Generated JSON:\n", code)
