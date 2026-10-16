import base64
import struct
import re

# Grid 60 cols x 40 rows = 2400 tiles
# Tile size = 32x32
# Total size = 1920 x 1280
# Tile 0: brick (collision)
# Tile 1: concrete (floor)
# Tile 2: asphalt (floor)

tiles_data = bytearray()
# Format version 0
tiles_data.extend(struct.pack('<H', 0))

for y in range(40):
    for x in range(60):
        # Perimeter 2 tiles thick
        is_border = (x < 2 or x >= 58 or y < 2 or y >= 38)
        
        # Pillars inside the arena for tactical combat/cover
        is_pillar = False
        pillars = [
            (14, 12), (15, 12), (14, 13), (15, 13),
            (44, 12), (45, 12), (44, 13), (45, 13),
            (14, 26), (15, 26), (14, 27), (15, 27),
            (44, 26), (45, 26), (44, 27), (45, 27)
        ]
        if (x, y) in pillars:
            is_pillar = True

        if is_border or is_pillar:
            source_id = 0 # Brick (Wall)
        else:
            center_dist = ((x - 29.5)**2 + (y - 19.5)**2) ** 0.5
            if center_dist < 10:
                source_id = 1 # concrete arena center
            elif (x % 6 == 0 or y % 6 == 0):
                source_id = 2 # asphalt grid line
            else:
                source_id = 1 # concrete
        
        # 12 bytes per cell: x, y, source_id, atlas_x, atlas_y, alternative_tile
        cell = struct.pack('<hhhhhh', x, y, source_id, 0, 0, 0)
        tiles_data.extend(cell)

encoded = base64.b64encode(tiles_data).decode('ascii')
print(f"Total cells: {40 * 60}, total bytes: {len(tiles_data)}, encoded length: {len(encoded)}")

with open('scenes/world/level_03.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

new_content = re.sub(
    r'tile_map_data = PackedByteArray\("[^"]+"\)',
    f'tile_map_data = PackedByteArray("{encoded}")',
    content
)

with open('scenes/world/level_03.tscn', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("level_03.tscn updated successfully!")
