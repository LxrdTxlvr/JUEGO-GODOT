import base64
import struct

# Create 60x40 tilemap
# Tile 0: brick (collision)
# Tile 1: concrete (floor)
# Tile 2: asphalt (floor)
tiles_data = bytearray()
tiles_data.extend(struct.pack('<H', 0))

for y in range(40):
    for x in range(60):
        is_border = (x < 2 or x >= 58 or y < 2 or y >= 38)
        pillars = [
            (14, 12), (15, 12), (14, 13), (15, 13),
            (44, 12), (45, 12), (44, 13), (45, 13),
            (14, 26), (15, 26), (14, 27), (15, 27),
            (44, 26), (45, 26), (44, 27), (45, 27)
        ]
        if is_border or ((x, y) in pillars):
            source_id = 0 # Brick (Wall)
        else:
            center_dist = ((x - 29.5)**2 + (y - 19.5)**2) ** 0.5
            if center_dist < 10:
                source_id = 1
            elif (x % 6 == 0 or y % 6 == 0):
                source_id = 2
            else:
                source_id = 1
        
        cell = struct.pack('<hhhhhh', x, y, source_id, 0, 0, 0)
        tiles_data.extend(cell)

encoded_tiles = base64.b64encode(tiles_data).decode('ascii')

level3_tscn = f'''[gd_scene format=3 uid="uid://c6level3boss"]

[ext_resource type="Script" path="res://scripts/world/level_boss.gd" id="1_bosslevelscript"]
[ext_resource type="PackedScene" uid="uid://bplr2ymk7xw3a" path="res://scenes/entities/player.tscn" id="2_playerscene"]
[ext_resource type="Texture2D" uid="uid://cc4abeqr4iuwe" path="res://assets/generated/tile_brick.png" id="3_brick"]
[ext_resource type="Texture2D" uid="uid://cffey5cndxkkb" path="res://assets/generated/tile_concrete.png" id="4_concrete"]
[ext_resource type="Texture2D" uid="uid://cilxi3ja2e8ok" path="res://assets/generated/tile_asphalt.png" id="5_asphalt"]
[ext_resource type="PackedScene" uid="uid://bvkm6e1uqw1b0" path="res://scenes/entities/enemies/zombie_boss.tscn" id="6_bossscene"]
[ext_resource type="PackedScene" uid="uid://c8mwqk2vtdy1n" path="res://scenes/entities/enemies/zombie_walker.tscn" id="7_walker"]
[ext_resource type="PackedScene" uid="uid://cf17pxrdvrr5g" path="res://scenes/entities/enemies/zombie_runner.tscn" id="8_runner"]
[ext_resource type="PackedScene" uid="uid://b4ntk7vqmhp8e" path="res://scenes/entities/enemies/zombie_brute.tscn" id="9_brute"]
[ext_resource type="PackedScene" uid="uid://cxh8k4nqtvw2m" path="res://scenes/ui/hud.tscn" id="10_hud"]
[ext_resource type="PackedScene" uid="uid://dq7knxm3vtbw2" path="res://scenes/ui/pause_menu.tscn" id="11_pause"]
[ext_resource type="Script" uid="uid://djqelaosj34gm" path="res://scripts/ui/hud.gd" id="12_hudscript"]
[ext_resource type="Script" uid="uid://ms7ph5jp1kqv" path="res://scripts/ui/pause_menu.gd" id="13_pausescript"]
[ext_resource type="Script" uid="uid://cyv13u701hyvn" path="res://scripts/entities/player/player.gd" id="14_playerscript"]
[ext_resource type="PackedScene" uid="uid://cbp1q55k806r2" path="res://scenes/entities/pickups/pickup_weapon.tscn" id="15_weapondrop"]
[ext_resource type="PackedScene" uid="uid://bn2kw9vrtxq4e" path="res://scenes/entities/pickups/pickup_ammo.tscn" id="16_ammodrop"]
[ext_resource type="PackedScene" uid="uid://dqxv1n8bkh2rp" path="res://scenes/entities/pickups/pickup_medkit.tscn" id="17_medkitdrop"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_b0"]
texture = ExtResource("3_brick")
texture_region_size = Vector2i(32, 32)
0:0/0 = 0
0:0/0/physics_layer_0/polygon_0/points = PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_b1"]
texture = ExtResource("4_concrete")
texture_region_size = Vector2i(32, 32)
0:0/0 = 0

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_b2"]
texture = ExtResource("5_asphalt")
texture_region_size = Vector2i(32, 32)
0:0/0 = 0

[sub_resource type="TileSet" id="TileSet_level03"]
tile_size = Vector2i(32, 32)
physics_layer_0/collision_layer = 1
sources/0 = SubResource("TileSetAtlasSource_b0")
sources/1 = SubResource("TileSetAtlasSource_b1")
sources/2 = SubResource("TileSetAtlasSource_b2")

[sub_resource type="RectangleShape2D" id="RectangleShape2D_wall_h"]
size = Vector2(1920, 64)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_wall_v"]
size = Vector2(64, 1280)

[node name="Level03" type="Node2D" groups=["level"]]
script = ExtResource("1_bosslevelscript")
level_name = "Nivel 3: El Núcleo del Titán"
level_tagline = "Frente a frente con la abominación final. ¡Sobrevive a las hordas y acaba con el Titán!"
player = NodePath("Entities/Player")
hud = NodePath("HUD")
player_start = NodePath("PlayerStart")
camera_bounds = Rect2(0, 0, 1920, 1280)
restrict_camera = true
boss_scene = ExtResource("6_bossscene")
boss_spawn_marker = NodePath("BossStart")
walker_scene = ExtResource("7_walker")
runner_scene = ExtResource("8_runner")
brute_scene = ExtResource("9_brute")
wave_interval_seconds = 45.0
zombies_per_wave = 10

[node name="Boundaries" type="StaticBody2D" parent="."]
collision_mask = 0

[node name="CollisionWallTop" type="CollisionShape2D" parent="Boundaries"]
position = Vector2(960, 32)
shape = SubResource("RectangleShape2D_wall_h")

[node name="CollisionWallBottom" type="CollisionShape2D" parent="Boundaries"]
position = Vector2(960, 1248)
shape = SubResource("RectangleShape2D_wall_h")

[node name="CollisionWallLeft" type="CollisionShape2D" parent="Boundaries"]
position = Vector2(32, 640)
shape = SubResource("RectangleShape2D_wall_v")

[node name="CollisionWallRight" type="CollisionShape2D" parent="Boundaries"]
position = Vector2(1888, 640)
shape = SubResource("RectangleShape2D_wall_v")

[node name="World" type="TileMapLayer" parent="."]
z_index = -1
tile_map_data = PackedByteArray("{encoded_tiles}")
tile_set = SubResource("TileSet_level03")

[node name="CanvasModulate" type="CanvasModulate" parent="."]
color = Color(0.85, 0.42, 0.45, 1)

[node name="Entities" type="Node2D" parent="."]
y_sort_enabled = true

[node name="Player" type="CharacterBody2D" parent="Entities" groups=["player"] instance=ExtResource("2_playerscene")]
position = Vector2(960, 950)
collision_layer = 2
motion_mode = 1
script = ExtResource("14_playerscript")
animated_sprite = NodePath("AnimatedSprite2D")
weapon_component = NodePath("WeaponPivot/WeaponComponent")
camera = NodePath("Camera2D")
input_handler = NodePath("DesktopInputHandler")
health_component = NodePath("HealthComponent")
weapon_pivot = NodePath("WeaponPivot")
visual_sprite = NodePath("AnimatedSprite2D")

[node name="Projectiles" type="Node2D" parent="." groups=["projectile_container"]]

[node name="PlayerStart" type="Marker2D" parent="."]
position = Vector2(960, 950)

[node name="BossStart" type="Marker2D" parent="."]
position = Vector2(960, 420)

[node name="PickupWeapon1" type="Area2D" parent="." instance=ExtResource("15_weapondrop")]
position = Vector2(760, 950)

[node name="PickupWeapon2" type="Area2D" parent="." instance=ExtResource("15_weapondrop")]
position = Vector2(1160, 950)

[node name="PickupAmmo1" type="Area2D" parent="." instance=ExtResource("16_ammodrop")]
position = Vector2(660, 950)

[node name="PickupAmmo2" type="Area2D" parent="." instance=ExtResource("16_ammodrop")]
position = Vector2(1260, 950)

[node name="PickupMedkit1" type="Area2D" parent="." instance=ExtResource("17_medkitdrop")]
position = Vector2(960, 1050)

[node name="HUD" type="CanvasLayer" parent="." instance=ExtResource("10_hud")]
layer = 10
script = ExtResource("12_hudscript")
bar_max_width = 276.0

[node name="PauseMenu" type="CanvasLayer" parent="." instance=ExtResource("11_pause")]
layer = 20
script = ExtResource("13_pausescript")
'''

with open('scenes/world/level_03.tscn', 'w', encoding='utf-8') as f:
    f.write(level3_tscn)

print("level_03.tscn written successfully!")
