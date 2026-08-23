"""Build and render the Bone & Pick isometric mine environment.

Run from the repository root:
  blender --background --python art/blender/scripts/build_bone_and_pick.py
"""
from pathlib import Path
import json
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
BLEND_PATH = ROOT / "art/blender/bone_and_pick_environment.blend"
OUTPUT = ROOT / "assets/environment/bone_and_pick"
PALETTE = {
    "coal": "0B1114", "slate": "16242B", "paper": "E8D9B5",
    "brass": "D2A75C", "union_red": "A54138", "teal": "79B7B0", "ember": "E98B3A",
}
LAYER_ORDER = [("ground", -40), ("midground", -30), ("structure", -20), ("foreground", -10)]


def rgba(hex_color, alpha=1.0):
    return tuple(int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)) + (alpha,)


def material(name, color, metallic=0.0, roughness=0.72, emission=0.0):
    item = bpy.data.materials.new(name)
    item.diffuse_color = rgba(color)
    item.use_nodes = True
    bsdf = item.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba(color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = rgba(color)
        bsdf.inputs["Emission Strength"].default_value = emission
    return item


def link_layer(obj, layer):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    COLLECTIONS[layer].objects.link(obj)
    obj["environment_layer"] = layer
    return obj


def cube(name, layer, location, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft carved edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(mat)
    return link_layer(obj, layer)


def cylinder(name, layer, location, radius, depth, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return link_layer(obj, layer)


def beam_between(name, layer, first, second, radius, mat):
    first, second = Vector(first), Vector(second)
    delta = second - first
    obj = cylinder(name, layer, (first + second) / 2, radius, delta.length, mat)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(delta.normalized())
    return obj


def light(name, location, color, energy, radius):
    data = bpy.data.lights.new(name, "POINT")
    data.color = rgba(color)[:3]
    data.energy = energy
    data.shadow_soft_size = radius
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def build_environment(materials):
    slate, coal = materials["slate"], materials["coal"]
    brass, paper = materials["brass"], materials["paper"]
    timber, red, teal, ember = materials["timber"], materials["union_red"], materials["teal"], materials["ember"]
    # Ground: a seven-by-five working floor, each slab reads as a 2:1 diamond from the fixed camera.
    for y in range(5):
        for x in range(7):
            tile = cube("Floor_%02d_%02d" % (x, y), "ground", ((x - 3) * 2.0, (y - 2) * 2.0, -0.18), (0.96, 0.96, 0.12), slate, 0.05)
            tile.data.materials.append(coal if (x + y) % 2 else slate)
    # Uneven mine faces.
    for index, position in enumerate([(-7.7, 1.4, 1.6), (7.8, -0.4, 1.8), (-3.5, 5.7, 1.5)]):
        rock = cube("RockFace_%02d" % index, "structure", position, (1.0 + index * 0.25, 0.9, 1.6), coal, 0.18)
        rock.rotation_euler.z = math.radians(14 * (index - 1))
    # Timber braces and rails establish the Bone & Pick landmarks.
    for index, x in enumerate([-5.7, -2.4, 3.1, 5.9]):
        beam_between("TimberPost_%02d" % index, "structure", (x, 3.7, 0), (x, 3.7, 3.8), 0.16, timber)
        beam_between("TimberCross_%02d" % index, "structure", (x - 0.8, 3.7, 3.5), (x + 0.8, 3.7, 3.5), 0.13, timber)
    for offset in [-0.34, 0.34]:
        beam_between("Rail_%s" % offset, "midground", (-6.0, -3.2 + offset, 0.08), (5.7, 1.4 + offset, 0.08), 0.06, brass)
    for step in range(9):
        x = -5.5 + step * 1.35
        beam_between("Sleeper_%02d" % step, "midground", (x, -3.5, 0.01), (x, -2.8, 0.01), 0.1, timber)
    cart = cube("OreCart", "midground", (-1.5, -1.35, 0.65), (1.0, 0.62, 0.52), red, 0.1)
    for dx in [-0.65, 0.65]:
        cylinder("CartWheel_%s" % dx, "midground", (-1.5 + dx, -1.35, 0.18), 0.28, 0.16, coal, (math.pi / 2, 0, 0))
    # Lanterns, alarm, and workbench give the worker simulation readable landmarks.
    for index, point in enumerate([(-4.5, -0.2, 2.25), (0.5, 3.0, 2.1), (4.7, -1.2, 2.45)]):
        beam_between("LanternChain_%02d" % index, "structure", (point[0], point[1], 3.6), point, 0.035, brass)
        cylinder("Lantern_%02d" % index, "structure", point, 0.22, 0.38, ember)
        light("LanternLight_%02d" % index, point, PALETTE["ember"], 320, 2.6)
    cylinder("AlarmPost", "structure", (6.0, 2.25, 1.15), 0.16, 2.2, brass)
    cylinder("AlarmBell", "structure", (6.0, 2.25, 2.35), 0.38, 0.22, red)
    cube("WorkBench", "midground", (-5.5, 0.7, 0.65), (0.95, 0.45, 0.55), timber, 0.05)
    # Accessibility-safe dressing: teal fume patch is decorative only; Godot retains hatched overlay/text.
    fumes = cube("FumeDecal", "ground", (0.0, 0.4, -0.02), (1.6, 1.1, 0.015), teal, 0.08)
    fumes.data.materials[0].diffuse_color = rgba(PALETTE["teal"], 0.32)
    for index, point in enumerate([(2.4, 2.9, 0.32), (2.9, 2.4, 0.25), (3.35, 2.7, 0.4)]):
        cube("CaveInRubble_%02d" % index, "midground", point, (0.35, 0.3, point[2]), coal, 0.08)
    for index, point in enumerate([(-7.2, -3.8, 1.7), (7.3, 4.0, 1.9), (0.0, 5.7, 1.4)]):
        cube("ForegroundRock_%02d" % index, "foreground", point, (1.15, 0.7, 1.75), coal, 0.2)


def setup_camera_and_lights():
    bpy.ops.object.camera_add(location=(14, -18, 16))
    camera = bpy.context.object
    camera.name = "DungeonUnionIsoCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 22.0
    camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera
    light("KeyWarm", (3, -4, 12), PALETTE["paper"], 950, 7.0)
    data = bpy.data.lights.new("MineFill", "SUN")
    data.energy = 1.2
    sun = bpy.data.objects.new("MineFill", data)
    bpy.context.scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(28), math.radians(-18), math.radians(-35))


def render_layers():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 2048
    scene.render.resolution_y = 2048
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    renderable = [obj for obj in scene.objects if obj.get("environment_layer")]
    for layer, _ in LAYER_ORDER:
        for obj in renderable:
            obj.hide_render = obj.get("environment_layer") != layer
        scene.render.filepath = str(OUTPUT / (layer + ".png"))
        bpy.ops.render.render(write_still=True)
    for obj in renderable:
        obj.hide_render = False


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    clear_scene()
    global COLLECTIONS
    COLLECTIONS = {}
    for name, _ in LAYER_ORDER:
        collection = bpy.data.collections.new(name.upper())
        bpy.context.scene.collection.children.link(collection)
        COLLECTIONS[name] = collection
    materials = {name: material("DU_" + name, color, metallic=0.35 if name == "brass" else 0.0, emission=1.1 if name == "ember" else 0.0) for name, color in PALETTE.items()}
    materials["timber"] = material("DU_timber", "684636")
    build_environment(materials)
    setup_camera_and_lights()
    render_layers()
    manifest = {"schema_version": 1, "canvas_size": [2048, 2048], "world_anchor": [0, 0], "layers": [{"id": name, "file": name + ".png", "z_index": z_index, "anchor": [0, 0], "size": [2048, 2048]} for name, z_index in LAYER_ORDER]}
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))


if __name__ == "__main__":
    main()
