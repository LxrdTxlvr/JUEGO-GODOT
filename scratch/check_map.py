import base64
import struct
import re

with open('scenes/world/level_03.tscn', 'r', encoding='utf-8') as f:
    text3 = f.read()

m3 = re.search(r'tile_map_data = PackedByteArray\("([^"]+)"\)', text3)
d3 = base64.b64decode(m3.group(1))

tiles = {}
for i in range(2, len(d3), 12):
    x, y, src, ax, ay, alt = struct.unpack('<hhhhhh', d3[i:i+12])
    tiles[(x, y)] = src

from collections import Counter
counts = Counter(src for (x, y), src in tiles.items())
print("Tile sources count:", counts)

# Godot 4.x TileMapLayer format:
# Header: format version (2 bytes)
# For each coordinate:
# Usually formatted as packed cell data.
# Let's inspect bytes in d3
print("d3 first 20 bytes:", list(d3[:20]))
# In Godot 4.3+, format is: format_version(uint16), then cells.
# If format_version == 0:
# cell is x(i16), y(i16), source_id(i16), atlas_coords_x(i16), atlas_coords_y(i16), alternative_tile(i16) -> 12 bytes
fmt = struct.unpack('<H', d3[:2])[0]
print("format version:", fmt)
tiles = []
for i in range(2, len(d3), 12):
    x, y, src, ax, ay, alt = struct.unpack('<hhhhhh', d3[i:i+12])
    tiles.append((x, y, src))

xs = [t[0] for t in tiles]
ys = [t[1] for t in tiles]
print(f"Total tiles: {len(tiles)}")
print(f"X: {min(xs)} to {max(xs)}, Y: {min(ys)} to {max(ys)}")
print(f"Pixel bounds: X=[{min(xs)*32}, {(max(xs)+1)*32}], Y=[{min(ys)*32}, {(max(ys)+1)*32}]")
# Let's see what tiles are walls (src == 0 has collision)
wall_tiles = [t for t in tiles if t[2] == 0]
print(f"Wall tiles count: {len(wall_tiles)}")
for t in wall_tiles[:20]:
    print(t)
# Check if borders (x=0, x=59, y=0, y=27) have wall tiles
border_x0 = [t for t in tiles if t[0] == 0 and t[2] == 0]
border_x59 = [t for t in tiles if t[0] == 59 and t[2] == 0]
border_y0 = [t for t in tiles if t[1] == 0 and t[2] == 0]
border_y27 = [t for t in tiles if t[1] == 27 and t[2] == 0]
print("Border walls:", len(border_x0), len(border_x59), len(border_y0), len(border_y27))



