"""Render a transparent, hand-built lantern loop for the Bone & Pick mine.

Run from the repository root:
  blender --background --python art/blender/scripts/render_lantern_flicker.py
"""
from pathlib import Path
import json
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "assets/effects/lantern_flicker"
BLEND_PATH = ROOT / "art/blender/lantern_flicker.blend"
FRAMES = [0.78, 1.04, 0.91, 1.15, 0.86, 1.0]


def color(value, alpha=1.0):
    return tuple(int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4)) + (alpha,)


def material(name, value, emission=0.0, metallic=0.0):
    item = bpy.data.materials.new(name)
    item.use_nodes = True
    bsdf = item.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color(value)
    bsdf.inputs["Roughness"].default_value = 0.42 if metallic else 0.68
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = color(value)
        bsdf.inputs["Emission Strength"].default_value = emission
    return item


def cube(name, location, scale, item, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(item)
    if bevel:
        modifier = obj.modifiers.new("Ink-soft edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    return obj


def cylinder(name, location, radius, depth, item):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(item)
    return obj


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def build_lantern(brass, coal, ember, cream):
    cylinder("LanternTop", (0, 0, 0.92), 0.46, 0.15, brass)
    cylinder("LanternCap", (0, 0, 1.05), 0.19, 0.16, coal)
    cube("LanternBase", (0, 0, -0.76), (0.44, 0.44, 0.10), brass, 0.05)
    for x, y in [(-0.36, -0.12), (0.36, -0.12), (-0.36, 0.12), (0.36, 0.12)]:
        cube("LanternFrame", (x, y, 0.02), (0.055, 0.055, 0.78), coal, 0.025)
    globe = cylinder("LanternGlow", (0, 0, 0.02), 0.34, 1.28, ember)
    globe.scale.x = 0.84
    globe.scale.y = 0.84
    cylinder("LanternWick", (0, 0, -0.18), 0.075, 0.46, cream)
    # Handle arcs give the tiny asset an immediately legible silhouette.
    bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.045, major_segments=16, minor_segments=6, location=(0, 0, 1.16), rotation=(math.pi / 2, 0, 0))
    handle = bpy.context.object
    handle.name = "LanternHandle"
    handle.data.materials.append(brass)
    return globe


def setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    bpy.ops.object.camera_add(location=(3.8, -6.4, 3.2))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.25
    camera.rotation_euler = (Vector((0, 0, 0.12)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    key_data = bpy.data.lights.new("LanternKey", "AREA")
    key_data.energy = 380
    key_data.shape = "DISK"
    key_data.size = 4.0
    key_data.color = color("E8D9B5")[:3]
    key = bpy.data.objects.new("LanternKey", key_data)
    scene.collection.objects.link(key)
    key.location = (2.4, -3.0, 4.8)
    glow_data = bpy.data.lights.new("LanternGlowLight", "POINT")
    glow_data.color = color("E98B3A")[:3]
    glow_data.shadow_soft_size = 2.0
    glow = bpy.data.objects.new("LanternGlowLight", glow_data)
    scene.collection.objects.link(glow)
    glow.location = (0, -0.3, 0.0)
    return glow


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    BLEND_PATH.parent.mkdir(parents=True, exist_ok=True)
    clear_scene()
    brass = material("Worn brass", "D2A75C", metallic=0.55)
    coal = material("Coal ink", "0B1114", metallic=0.15)
    ember = material("Ember glass", "E98B3A", emission=2.0)
    cream = material("Wick cream", "E8D9B5", emission=0.35)
    globe = build_lantern(brass, coal, ember, cream)
    glow = setup_scene()
    scene = bpy.context.scene
    frame_names = []
    for index, intensity in enumerate(FRAMES):
        globe.active_material.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value = 1.5 + intensity * 1.9
        glow.data.energy = 105 + intensity * 105
        globe.scale = (0.84 + intensity * 0.03, 0.84 + intensity * 0.03, 1.0)
        frame_name = "lantern_flicker_%02d.png" % index
        scene.render.filepath = str(OUTPUT / frame_name)
        bpy.ops.render.render(write_still=True)
        frame_names.append(frame_name)
    (OUTPUT / "manifest.json").write_text(json.dumps({"schema_version": 1, "fps": 8, "frames": frame_names}, indent=2) + "\n", encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))


if __name__ == "__main__":
    main()
