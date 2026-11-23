#!/usr/bin/env python3
"""LEVERAGE asset pipeline - Blender headless FBX -> GLB conversion with
uniform scale normalization. Writes into leverage/assets/<category>/.
Run: blender --background --python scripts/asset_pipeline.py
"""
import bpy
import mathutils
import os

OUT = "/home/z/my-project/leverage/assets"

R = "/home/z/my-project/tools/assets_raw"

## out name -> (fbx path, target size of longest dimension in meters, category)
MANIFEST = {
    # vehicles
    "sedan":     (R + "/cars/cars_FBX_NormalCar1.fbx", 4.6, "vehicles"),
    "hatch":     (R + "/cars/cars_FBX_NormalCar2.fbx", 4.0, "vehicles"),
    "suv":       (R + "/cars/cars_FBX_SUV.fbx", 4.9, "vehicles"),
    "sport":     (R + "/cars/cars_FBX_SportsCar.fbx", 4.5, "vehicles"),
    "sport2":    (R + "/cars/cars_FBX_SportsCar2.fbx", 4.5, "vehicles"),
    "taxi":      (R + "/cars/cars_FBX_Taxi.fbx", 4.6, "vehicles"),
    "cop":       (R + "/cars/cars_FBX_Cop.fbx", 4.7, "vehicles"),
    # weapons
    "pistol":    (R + "/ultimate_guns/ultimate_guns_FBX_Pistol_1.fbx", 0.30, "weapons"),
    "pistol2":   (R + "/ultimate_guns/ultimate_guns_FBX_Pistol_2.fbx", 0.30, "weapons"),
    "smg":       (R + "/ultimate_guns/ultimate_guns_FBX_Pistol_3.fbx", 0.55, "weapons"),
    "rifle":     (R + "/ultimate_guns/ultimate_guns_FBX_AssaultRifle_1.fbx", 0.95, "weapons"),
    "bullpup":   (R + "/ultimate_guns/ultimate_guns_FBX_Bullpup_1.fbx", 0.85, "weapons"),
    # textured buildings
    "b1story":   (R + "/ultimate_textured_buildings/ultimate_textured_buildings_Textured Models_Finished Textured Buildings_FBX_1Story.fbx", 12.0, "buildings"),
    "b2story":   (R + "/ultimate_textured_buildings/ultimate_textured_buildings_Textured Models_Finished Textured Buildings_FBX_2Story.fbx", 12.0, "buildings"),
    "b2bal":     (R + "/ultimate_textured_buildings/ultimate_textured_buildings_Textured Models_Finished Textured Buildings_FBX_2Story_Balcony.fbx", 12.0, "buildings"),
    "b2sign":    (R + "/ultimate_textured_buildings/ultimate_textured_buildings_Textured Models_Finished Textured Buildings_FBX_2Story_Sign.fbx", 12.0, "buildings"),
    "b2wide":    (R + "/ultimate_textured_buildings/ultimate_textured_buildings_Textured Models_Finished Textured Buildings_FBX_2Story_Wide.fbx", 16.0, "buildings"),
    "b3bal":     (R + "/ultimate_textured_buildings/ultimate_textured_buildings_Textured Models_Finished Textured Buildings_FBX_3Story_Balcony.fbx", 15.0, "buildings"),
    "b3slim":    (R + "/ultimate_textured_buildings/ultimate_textured_buildings_Textured Models_Finished Textured Buildings_FBX_3Story_Slim.fbx", 15.0, "buildings"),
    # simple buildings
    "bank":      (R + "/simple_buildings/simple_buildings_FBX_Bank.fbx", 14.0, "buildings"),
    "shop":      (R + "/simple_buildings/simple_buildings_FBX_Shop.fbx", 10.0, "buildings"),
    "hospital":  (R + "/simple_buildings/simple_buildings_FBX_Hospital.fbx", 18.0, "buildings"),
    "house":     (R + "/simple_buildings/simple_buildings_FBX_House.fbx", 10.0, "buildings"),
    "house2":    (R + "/simple_buildings/simple_buildings_FBX_House2.fbx", 10.0, "buildings"),
    "flat":      (R + "/simple_buildings/simple_buildings_FBX_Flat.fbx", 12.0, "buildings"),
    "flat2":     (R + "/simple_buildings/simple_buildings_FBX_Flat2.fbx", 12.0, "buildings"),
    # street props
    "streetlight":  (R + "/modular_streets/modular_streets_FBX_Streetlight_Single.fbx", 6.0, "props"),
    "streetlight_d": (R + "/modular_streets/modular_streets_FBX_Streetlight_Double.fbx", 6.0, "props"),
    "trafficlight": (R + "/modular_streets/modular_streets_FBX_TrafficLight.fbx", 4.2, "props"),
    "sign_stop":    (R + "/modular_streets/modular_streets_FBX_Sign_Stop.fbx", 2.0, "props"),
    "sign_nopark":  (R + "/modular_streets/modular_streets_FBX_Sign_NoParking.fbx", 2.0, "props"),
    "cone":         (R + "/public_transport/public_transport_FBX_TrafficCone.fbx", 0.7, "props"),
    # interiors
    "table":     (R + "/furniture/furniture_FBX_Table.fbx", 1.6, "interiors"),
    "coffeetable": (R + "/furniture/furniture_FBX_CoffeeTable.fbx", 1.0, "interiors"),
    "chair":     (R + "/furniture/furniture_FBX_Chair.fbx", 1.0, "interiors"),
    "sofa":      (R + "/furniture/furniture_FBX_Sofa.fbx", 2.0, "interiors"),
    "bookcase":  (R + "/furniture/furniture_FBX_BookCase.fbx", 2.0, "interiors"),
    "bed":       (R + "/furniture/furniture_FBX_Bed.fbx", 2.2, "interiors"),
    "bedking":   (R + "/furniture/furniture_FBX_BedKing.fbx", 2.4, "interiors"),
    "lamp":      (R + "/ultimate_home_interior/ultimate_home_interior_FBX_Light_Stand1.fbx", 1.5, "interiors"),
    "stool":     (R + "/ultimate_home_interior/ultimate_home_interior_FBX_Stool.fbx", 0.8, "interiors"),
    "shelf":     (R + "/ultimate_home_interior/ultimate_home_interior_FBX_Shelf_1.fbx", 1.6, "interiors"),
    "tv":        (R + "/ultimate_home_interior/ultimate_home_interior_FBX_Bookshelf.fbx", 1.2, "interiors"),
    "plant":     (R + "/ultimate_home_interior/ultimate_home_interior_FBX_Houseplant_1.fbx", 1.4, "interiors"),
}


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_fbx(path):
    bpy.ops.import_scene.fbx(filepath=path)


def bbox_dims():
    corners = []
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            for corner in obj.bound_box:
                corners.append(obj.matrix_world @ mathutils.Vector(corner))
    if not corners:
        return None
    lo = mathutils.Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    hi = mathutils.Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    return lo, hi


def main():
    report = []
    for out_name, spec in MANIFEST.items():
        fbx_path, target, category = spec
        if not os.path.exists(fbx_path):
            report.append((out_name, "MISSING-SOURCE"))
            continue
        clear_scene()
        try:
            import_fbx(fbx_path)
        except Exception as e:
            report.append((out_name, "IMPORT-FAIL %s" % e))
            continue
        bb = bbox_dims()
        if bb is None:
            report.append((out_name, "EMPTY"))
            continue
        lo, hi = bb
        dims = hi - lo
        cur = max(dims.x, dims.y, dims.z)
        if cur <= 0:
            report.append((out_name, "DEGENERATE"))
            continue
        scale = target / cur
        for obj in bpy.data.objects:
            obj.scale = (obj.scale.x * scale, obj.scale.y * scale, obj.scale.z * scale)
        bpy.context.view_layer.update()
        # re-ground to z=0
        bb = bbox_dims()
        lo, hi = bb
        for obj in bpy.data.objects:
            obj.location.z -= lo.z
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        out_dir = os.path.join(OUT, category)
        os.makedirs(out_dir, exist_ok=True)
        path = os.path.join(out_dir, out_name + ".glb")
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format='GLB',
            export_yup=True,
            export_apply=False,
            export_materials='EXPORT',
            export_animations=False,
        )
        report.append((out_name, "OK x%.3f -> %s/%s.glb" % (scale, category, out_name)))
    for r in report:
        print("PIPELINE:", r[0], "|", r[1])


main()
