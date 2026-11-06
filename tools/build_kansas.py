#!/usr/bin/env python3
"""Generate Kansas farmyard scene + packed actors (B&W primitives)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KANSAS = ROOT / "regions" / "kansas"
DOROTHY = ROOT / "actors" / "dorothy"
KANSAS.mkdir(parents=True, exist_ok=True)


def mat(name, c, rough=0.85, metal=0.0):
    r, g, b = c
    return f"""[sub_resource type="StandardMaterial3D" id="{name}"]
albedo_color = Color({r}, {g}, {b}, 1)
roughness = {rough}
metallic = {metal}
"""


def box_mesh(name, sx, sy, sz):
    return f"""[sub_resource type="BoxMesh" id="{name}"]
size = Vector3({sx}, {sy}, {sz})
"""


def cyl_mesh(name, top, bot, h):
    return f"""[sub_resource type="CylinderMesh" id="{name}"]
top_radius = {top}
bottom_radius = {bot}
height = {h}
"""


def sphere_mesh(name, r):
    return f"""[sub_resource type="SphereMesh" id="{name}"]
radius = {r}
height = {r * 2}
"""


def write_kansas_player():
    path = DOROTHY / "kansas_player.tscn"
    content = f"""[gd_scene load_steps=12 format=3]

[ext_resource type="Script" path="res://actors/dorothy/kansas_controller.gd" id="1_script"]

[sub_resource type="CapsuleShape3D" id="Shape_body"]
radius = 0.26
height = 1.28

{mat("Mat_dress", (0.45, 0.45, 0.48), 0.8)}
{cyl_mesh("Mesh_dress", 0.3, 0.4, 0.58)}
{mat("Mat_apron", (0.78, 0.78, 0.8), 0.7)}
{box_mesh("Mesh_apron", 0.34, 0.42, 0.06)}
{mat("Mat_skin", (0.72, 0.72, 0.74), 0.6)}
{sphere_mesh("Mesh_head", 0.15)}
{mat("Mat_hair", (0.18, 0.18, 0.2), 0.85)}
{sphere_mesh("Mesh_hair", 0.155)}
{mat("Mat_shoe", (0.25, 0.25, 0.27), 0.7)}
{box_mesh("Mesh_shoe", 0.12, 0.07, 0.22)}

[node name="Player" type="CharacterBody3D" groups=["player"]]
collision_layer = 2
collision_mask = 1
script = ExtResource("1_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.64, 0)
shape = SubResource("Shape_body")

[node name="Visual" type="Node3D" parent="."]

[node name="Dress" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.48, 0)
mesh = SubResource("Mesh_dress")
surface_material_override/0 = SubResource("Mat_dress")

[node name="Apron" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.52, -0.18)
mesh = SubResource("Mesh_apron")
surface_material_override/0 = SubResource("Mat_apron")

[node name="Head" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.02, 0)
mesh = SubResource("Mesh_head")
surface_material_override/0 = SubResource("Mat_skin")

[node name="Hair" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.14, -0.02)
mesh = SubResource("Mesh_hair")
surface_material_override/0 = SubResource("Mat_hair")

[node name="PigtailL" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(0.55, 0, 0, 0, 0.9, 0, 0, 0, 0.55, -0.18, 0.92, 0.02)
mesh = SubResource("Mesh_hair")
surface_material_override/0 = SubResource("Mat_hair")

[node name="PigtailR" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(0.55, 0, 0, 0, 0.9, 0, 0, 0, 0.55, 0.18, 0.92, 0.02)
mesh = SubResource("Mesh_hair")
surface_material_override/0 = SubResource("Mat_hair")

[node name="ShoeL" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.1, 0.05, -0.04)
mesh = SubResource("Mesh_shoe")
surface_material_override/0 = SubResource("Mat_shoe")

[node name="ShoeR" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.1, 0.05, -0.04)
mesh = SubResource("Mesh_shoe")
surface_material_override/0 = SubResource("Mat_shoe")

[node name="CameraPivot" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.15, 0)

[node name="SpringArm3D" type="SpringArm3D" parent="CameraPivot"]
transform = Transform3D(1, 0, 0, 0, 0.96, 0.28, 0, -0.28, 0.96, 0, 0, 0)
spring_length = 5.0
margin = 0.2
collision_mask = 0

[node name="Camera3D" type="Camera3D" parent="CameraPivot/SpringArm3D"]
current = true
fov = 58.0
"""
    path.write_text(content)
    print("wrote", path)


def write_debris():
    path = KANSAS / "debris.tscn"
    content = f"""[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://regions/kansas/debris.gd" id="1_script"]

[sub_resource type="BoxShape3D" id="Shape"]
size = Vector3(0.9, 0.5, 1.4)

{mat("Mat_wood", (0.35, 0.35, 0.36), 0.9)}
{box_mesh("Mesh_plank", 0.9, 0.5, 1.4)}

[node name="Debris" type="Area3D"]
collision_layer = 0
collision_mask = 2
script = ExtResource("1_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("Shape")

[node name="Mesh" type="MeshInstance3D" parent="."]
mesh = SubResource("Mesh_plank")
surface_material_override/0 = SubResource("Mat_wood")
"""
    path.write_text(content)
    print("wrote", path)


def write_toto():
    path = KANSAS / "toto.tscn"
    content = f"""[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://regions/kansas/toto.gd" id="1_script"]

[sub_resource type="SphereShape3D" id="Shape"]
radius = 0.22

{mat("Mat_fur", (0.22, 0.22, 0.24), 0.85)}
{sphere_mesh("Mesh_body", 0.18)}
{mat("Mat_ear", (0.15, 0.15, 0.16), 0.8)}
{sphere_mesh("Mesh_ear", 0.07)}

[node name="Toto" type="CharacterBody3D" groups=["toto"]]
collision_layer = 2
collision_mask = 1
script = ExtResource("1_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.18, 0)
shape = SubResource("Shape")

[node name="Visual" type="Node3D" parent="."]

[node name="Body" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1.2, 0, 0, 0, 0.9, 0, 0, 0, 1.4, 0, 0.18, 0)
mesh = SubResource("Mesh_body")
surface_material_override/0 = SubResource("Mat_fur")

[node name="Head" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(0.85, 0, 0, 0, 0.85, 0, 0, 0, 0.85, 0, 0.32, -0.18)
mesh = SubResource("Mesh_body")
surface_material_override/0 = SubResource("Mat_fur")

[node name="EarL" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -0.1, 0.4, -0.16)
mesh = SubResource("Mesh_ear")
surface_material_override/0 = SubResource("Mat_ear")

[node name="EarR" type="MeshInstance3D" parent="Visual"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.1, 0.4, -0.16)
mesh = SubResource("Mesh_ear")
surface_material_override/0 = SubResource("Mat_ear")
"""
    path.write_text(content)
    print("wrote", path)


def write_basket():
    path = KANSAS / "basket.tscn"
    content = f"""[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://regions/kansas/basket.gd" id="1_script"]

[sub_resource type="SphereShape3D" id="Shape"]
radius = 0.7

{mat("Mat_wicker", (0.4, 0.4, 0.42), 0.9)}
{box_mesh("Mesh_basket", 0.35, 0.22, 0.3)}

[node name="Basket" type="Area3D"]
collision_layer = 0
collision_mask = 2
script = ExtResource("1_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("Shape")

[node name="Mesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.12, 0)
mesh = SubResource("Mesh_basket")
surface_material_override/0 = SubResource("Mat_wicker")
"""
    path.write_text(content)
    print("wrote", path)


def solid(name, mesh_id, mat_id, x, y, z, sx=1, sy=1, sz=1, show=True):
    vis = "" if show else "visible = false\n"
    return f"""
[node name="{name}" type="StaticBody3D" parent="."]
transform = Transform3D({sx}, 0, 0, 0, {sy}, 0, 0, 0, {sz}, {x}, {y}, {z})
collision_layer = 1
collision_mask = 0
{vis}
[node name="Mesh" type="MeshInstance3D" parent="{name}"]
mesh = SubResource("{mesh_id}")
surface_material_override/0 = SubResource("{mat_id}")

[node name="Col" type="CollisionShape3D" parent="{name}"]
shape = SubResource("Shape_box")
"""


def write_farmyard():
    # Shared box shape unit 1x1x1 — scale via node transform
    parts = []
    mats = []
    mats.append(mat("Mat_ground", (0.38, 0.38, 0.4), 0.95))
    mats.append(mat("Mat_dirt", (0.28, 0.28, 0.3), 0.95))
    mats.append(mat("Mat_wood", (0.32, 0.32, 0.34), 0.9))
    mats.append(mat("Mat_roof", (0.22, 0.22, 0.24), 0.85))
    mats.append(mat("Mat_fence", (0.4, 0.4, 0.42), 0.9))
    mats.append(mat("Mat_dead", (0.3, 0.3, 0.31), 0.92))

    meshes = []
    meshes.append(box_mesh("Mesh_unit", 1, 1, 1))
    meshes.append(cyl_mesh("Mesh_post", 0.08, 0.1, 1.2))

    shapes = """[sub_resource type="BoxShape3D" id="Shape_box"]
size = Vector3(1, 1, 1)

[sub_resource type="Environment" id="Env"]
background_mode = 1
background_color = Color(0.55, 0.55, 0.58, 1)
ambient_light_source = 2
ambient_light_color = Color(0.7, 0.7, 0.72, 1)
ambient_light_energy = 0.85
tonemap_mode = 2
adjustment_enabled = true
adjustment_saturation = 0.0
adjustment_contrast = 1.15
fog_enabled = true
fog_light_color = Color(0.6, 0.6, 0.62, 1)
fog_density = 0.012
"""

    # Build fence segments
    fence_nodes = []
    # Perimeter broken fences
    fences = [
        # name, x, y, z, sx, sy, sz, rot_y approx via scale flip not needed
        ("FenceN1", -8, 0.45, -14, 6, 0.9, 0.12),
        ("FenceN2", 4, 0.35, -13.5, 4, 0.7, 0.12),
        ("FenceE1", 16, 0.4, -4, 0.12, 0.8, 8),
        ("FenceE2", 15.5, 0.25, 8, 0.12, 0.5, 5),
        ("FenceW1", -16, 0.4, 0, 0.12, 0.85, 10),
        ("FenceS1", -4, 0.3, 16, 7, 0.6, 0.12),
        ("FenceBroken", 2, 0.2, 6, 2.5, 0.4, 0.15),
        ("FenceLean", -6, 0.35, 4, 0.15, 0.7, 3),
    ]
    for name, x, y, z, sx, sy, sz in fences:
        fence_nodes.append(f"""
[node name="{name}" type="StaticBody3D" parent="."]
transform = Transform3D({sx}, 0, 0, 0, {sy}, 0, 0, 0, {sz}, {x}, {y}, {z})
collision_layer = 1

[node name="Mesh" type="MeshInstance3D" parent="{name}"]
mesh = SubResource("Mesh_unit")
surface_material_override/0 = SubResource("Mat_fence")

[node name="Col" type="CollisionShape3D" parent="{name}"]
shape = SubResource("Shape_box")
""")

    # Farmhouse composite
    house = f"""
[node name="Farmhouse" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -2, 0, -8)

[node name="Body" type="StaticBody3D" parent="Farmhouse"]
transform = Transform3D(7, 0, 0, 0, 4.2, 0, 0, 0, 5.5, 0, 2.1, 0)
collision_layer = 1

[node name="Mesh" type="MeshInstance3D" parent="Farmhouse/Body"]
mesh = SubResource("Mesh_unit")
surface_material_override/0 = SubResource("Mat_wood")

[node name="Col" type="CollisionShape3D" parent="Farmhouse/Body"]
shape = SubResource("Shape_box")

[node name="Roof" type="StaticBody3D" parent="Farmhouse"]
transform = Transform3D(8, 0, 0, 0, 1.2, 0, 0, 0, 6.5, 0, 4.6, 0)
collision_layer = 1

[node name="Mesh" type="MeshInstance3D" parent="Farmhouse/Roof"]
mesh = SubResource("Mesh_unit")
surface_material_override/0 = SubResource("Mat_roof")

[node name="Col" type="CollisionShape3D" parent="Farmhouse/Roof"]
shape = SubResource("Shape_box")

[node name="Porch" type="StaticBody3D" parent="Farmhouse"]
transform = Transform3D(3.5, 0, 0, 0, 0.25, 0, 0, 0, 2, 0, 0.12, 3.2)
collision_layer = 1

[node name="Mesh" type="MeshInstance3D" parent="Farmhouse/Porch"]
mesh = SubResource("Mesh_unit")
surface_material_override/0 = SubResource("Mat_wood")

[node name="Col" type="CollisionShape3D" parent="Farmhouse/Porch"]
shape = SubResource("Shape_box")
"""

    dead_trees = ""
    for i, (x, z) in enumerate([(-12, -6), (10, -10), (12, 4), (-14, 10)]):
        dead_trees += f"""
[node name="DeadTree{i}" type="StaticBody3D" parent="."]
transform = Transform3D(0.35, 0, 0, 0, 2.8, 0, 0, 0, 0.35, {x}, 1.4, {z})
collision_layer = 1

[node name="Mesh" type="MeshInstance3D" parent="DeadTree{i}"]
mesh = SubResource("Mesh_unit")
surface_material_override/0 = SubResource("Mat_dead")

[node name="Col" type="CollisionShape3D" parent="DeadTree{i}"]
shape = SubResource("Shape_box")
"""

    content = f"""[gd_scene load_steps=20 format=3]

[ext_resource type="Script" path="res://regions/kansas/farmyard.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://actors/dorothy/kansas_player.tscn" id="pack_player"]
[ext_resource type="PackedScene" path="res://regions/kansas/basket.tscn" id="pack_basket"]
[ext_resource type="PackedScene" path="res://regions/kansas/toto.tscn" id="pack_toto"]
[ext_resource type="PackedScene" path="res://ui/play_hud.tscn" id="pack_hud"]

{''.join(mats)}
{''.join(meshes)}
{shapes}

[node name="Farmyard" type="Node3D"]
script = ExtResource("1_script")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.8, -0.4, 0.4, 0, 0.7, 0.7, -0.5, -0.55, 0.65, 0, 12, 0)
light_color = Color(0.85, 0.85, 0.88, 1)
light_energy = 0.9
shadow_enabled = true

[node name="Ground" type="StaticBody3D" parent="."]
transform = Transform3D(48, 0, 0, 0, 0.2, 0, 0, 0, 48, 0, -0.1, 0)
collision_layer = 1

[node name="Mesh" type="MeshInstance3D" parent="Ground"]
mesh = SubResource("Mesh_unit")
surface_material_override/0 = SubResource("Mat_ground")

[node name="Col" type="CollisionShape3D" parent="Ground"]
shape = SubResource("Shape_box")

[node name="DirtPatch" type="MeshInstance3D" parent="."]
transform = Transform3D(12, 0, 0, 0, 0.05, 0, 0, 0, 10, 2, 0.02, 2)
mesh = SubResource("Mesh_unit")
surface_material_override/0 = SubResource("Mat_dirt")
{house}
{''.join(fence_nodes)}
{dead_trees}

[node name="Player" parent="." instance=ExtResource("pack_player")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4, 0.05, 10)

[node name="Basket" parent="." instance=ExtResource("pack_basket")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -5, 0.05, 3)

[node name="Toto" parent="." instance=ExtResource("pack_toto")]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 8, 0.05, -2)

[node name="PlayHUD" parent="." instance=ExtResource("pack_hud")]
"""
    path = KANSAS / "farmyard.tscn"
    path.write_text(content)
    print("wrote", path)


if __name__ == "__main__":
    write_kansas_player()
    write_debris()
    write_toto()
    write_basket()
    write_farmyard()
    print("OK")
