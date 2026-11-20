import os
import struct
import zlib

# Generates a crisp 128x64 (8x4 tiles of 16x16) Stardew-inspired pixel-art tileset PNG.
# Drop-in Aseprite replacement path: res://assets/tilesets/town_tiles_16x16.png

TILE = 16
COLS = 8
ROWS = 4
W = COLS * TILE
H = ROWS * TILE

pixels = [[(0, 0, 0, 0) for _ in range(W)] for _ in range(H)]


def set_px(tx: int, ty: int, x: int, y: int, col: tuple):
    gx = tx * TILE + x
    gy = ty * TILE + y
    if 0 <= gx < W and 0 <= gy < H:
        pixels[gy][gx] = col


def fill_tile(tx: int, ty: int, col: tuple):
    for y in range(TILE):
        for x in range(TILE):
            set_px(tx, ty, x, y, col)


def rect(tx: int, ty: int, x0: int, y0: int, w: int, h: int, col: tuple):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            set_px(tx, ty, x, y, col)


# --- ROW 0: GROUND ---
# (0,0) Grass Base
GRASS_A = (46, 128, 66, 255)
GRASS_B = (40, 114, 58, 255)
GRASS_HI = (64, 152, 82, 255)
fill_tile(0, 0, GRASS_A)
for x, y in [(2, 3), (11, 6), (5, 12), (13, 13), (8, 2)]:
    set_px(0, 0, x, y, GRASS_B)
for x, y in [(3, 4), (10, 10), (14, 3)]:
    set_px(0, 0, x, y, GRASS_HI)

# (1,0) Grass Tufted
fill_tile(1, 0, GRASS_A)
for bx, by in [(3, 5), (10, 11), (11, 4)]:
    set_px(1, 0, bx, by, GRASS_B)
    set_px(1, 0, bx + 1, by - 1, GRASS_HI)
    set_px(1, 0, bx - 1, by - 1, GRASS_HI)
    set_px(1, 0, bx, by - 2, GRASS_HI)

# (2,0) Grass Flowers
fill_tile(2, 0, GRASS_A)
for fx, fy, fc in [(4, 5, (250, 224, 92, 255)), (11, 4, (248, 126, 156, 255)), (8, 12, (245, 248, 255, 255))]:
    set_px(2, 0, fx, fy + 1, GRASS_B)
    set_px(2, 0, fx, fy, fc)
    set_px(2, 0, fx - 1, fy, fc)
    set_px(2, 0, fx + 1, fy, fc)
    set_px(2, 0, fx, fy - 1, fc)
    set_px(2, 0, fx, fy, (255, 190, 48, 255))

# (3,0) Dirt Path
DIRT_A = (146, 114, 78, 255)
DIRT_B = (128, 98, 66, 255)
DIRT_HI = (166, 134, 96, 255)
fill_tile(3, 0, DIRT_A)
for x, y in [(2, 2), (9, 5), (4, 11), (12, 13), (14, 4)]:
    set_px(3, 0, x, y, DIRT_B)
for x, y in [(6, 3), (11, 9), (3, 14)]:
    set_px(3, 0, x, y, DIRT_HI)

# (4,0) Asphalt Road
ROAD_A = (62, 68, 78, 255)
ROAD_B = (54, 60, 70, 255)
ROAD_HI = (74, 80, 92, 255)
fill_tile(4, 0, ROAD_A)
for x, y in [(1, 2), (7, 6), (13, 4), (4, 12), (10, 14)]:
    set_px(4, 0, x, y, ROAD_B)
for x, y in [(3, 9), (12, 10), (8, 2)]:
    set_px(4, 0, x, y, ROAD_HI)

# (5,0) Asphalt Center Dashed Line (Horizontal)
fill_tile(5, 0, ROAD_A)
rect(5, 0, 2, 7, 10, 2, (238, 224, 152, 255))
for x, y in [(1, 2), (13, 12), (5, 14)]:
    set_px(5, 0, x, y, ROAD_B)

# (6,0) Plaza Cobble / Sidewalk
COB_A = (124, 130, 142, 255)
COB_B = (104, 110, 122, 255)
COB_HI = (144, 150, 162, 255)
fill_tile(6, 0, COB_A)
for y in [0, 8]:
    rect(6, 0, 0, y, 16, 1, COB_B)
for x, y in [(7, 0), (15, 0), (3, 8), (11, 8)]:
    rect(6, 0, x, y, 1, 8, COB_B)
rect(6, 0, 1, 1, 5, 1, COB_HI)
rect(6, 0, 9, 1, 5, 1, COB_HI)
rect(6, 0, 5, 9, 5, 1, COB_HI)

# (7,0) Warm Wooden Floorboards (Home)
WOOD_A = (138, 96, 62, 255)
WOOD_B = (114, 76, 46, 255)
WOOD_HI = (158, 114, 78, 255)
fill_tile(7, 0, WOOD_A)
for y in [0, 4, 8, 12]:
    rect(7, 0, 0, y, 16, 1, WOOD_B)
    rect(7, 0, 1, y + 1, 14, 1, WOOD_HI)
set_px(7, 0, 6, 2, WOOD_B)
set_px(7, 0, 12, 6, WOOD_B)
set_px(7, 0, 4, 10, WOOD_B)
set_px(7, 0, 10, 14, WOOD_B)

# --- ROW 1: ROOFS & WALLS ---
roof_colors = [
    ((166, 68, 56, 255), (134, 48, 40, 255), (194, 92, 78, 255)),     # (0,1) Home Red
    ((48, 86, 144, 255), (34, 64, 112, 255), (72, 114, 178, 255)),    # (1,1) Clubhouse Blue
    ((74, 86, 106, 255), (56, 66, 84, 255), (96, 110, 134, 255)),     # (2,1) Press Slate
    ((184, 106, 52, 255), (146, 80, 36, 255), (212, 132, 74, 255)),   # (3,1) Gol Cafe
    ((92, 42, 136, 255), (68, 28, 104, 255), (148, 72, 204, 255)),    # (4,1) Nightclub Neon
    ((46, 124, 86, 255), (32, 94, 64, 255), (68, 152, 110, 255)),     # (5,1) Sport Shop
    ((136, 94, 58, 255), (104, 70, 40, 255), (164, 118, 78, 255)),    # (6,1) Corner Cafe
]
for idx, (base, dark, hi) in enumerate(roof_colors):
    fill_tile(idx, 1, base)
    for y in range(0, 16, 4):
        rect(idx, 1, 0, y + 3, 16, 1, dark)
        for x in range((y // 4) % 2 * 4, 16, 8):
            set_px(idx, 1, x, y + 1, hi)
            set_px(idx, 1, x + 1, y + 1, hi)

# (7,1) Cream Plaster Wall
WALL_A = (218, 206, 184, 255)
WALL_B = (188, 176, 154, 255)
fill_tile(7, 1, WALL_A)
rect(7, 1, 0, 13, 16, 3, WALL_B)
rect(7, 1, 0, 0, 16, 1, WALL_B)

# --- ROW 2: PROPS & NATURE ---
# (0,2) Tree Canopy (Transparent bg)
TREE_DARK = (26, 78, 38, 255)
TREE_MID = (38, 106, 52, 255)
TREE_HI = (68, 148, 78, 255)
TRUNK = (108, 72, 44, 255)
rect(0, 2, 6, 11, 4, 5, TRUNK)
rect(0, 2, 3, 2, 10, 10, TREE_DARK)
rect(0, 2, 2, 4, 12, 6, TREE_DARK)
rect(0, 2, 3, 3, 10, 7, TREE_MID)
rect(0, 2, 4, 2, 8, 5, TREE_HI)
rect(0, 2, 5, 3, 4, 2, (94, 176, 98, 255))

# (1,2) Hedge Bush (Transparent bg)
rect(1, 2, 1, 4, 14, 10, TREE_DARK)
rect(1, 2, 2, 3, 12, 9, TREE_MID)
rect(1, 2, 3, 4, 10, 4, TREE_HI)
set_px(1, 2, 5, 6, (242, 98, 122, 255))
set_px(1, 2, 11, 7, (248, 224, 92, 255))

# (2,2) Street Lamp (Transparent bg)
rect(2, 2, 7, 4, 2, 11, (72, 78, 88, 255))
rect(2, 2, 5, 14, 6, 2, (52, 56, 64, 255))
rect(2, 2, 5, 1, 6, 4, (255, 232, 128, 255))
rect(2, 2, 6, 2, 4, 2, (255, 252, 214, 255))

# (3,2) Park Bench (Transparent bg)
rect(3, 2, 2, 6, 12, 3, (148, 98, 56, 255))
rect(3, 2, 2, 10, 12, 2, (124, 80, 44, 255))
rect(3, 2, 3, 12, 2, 3, (64, 68, 76, 255))
rect(3, 2, 11, 12, 2, 3, (64, 68, 76, 255))

# (4,2) Decorative Pond Water
fill_tile(4, 2, (46, 124, 176, 255))
rect(4, 2, 2, 4, 5, 1, (92, 174, 224, 255))
rect(4, 2, 8, 11, 6, 1, (92, 174, 224, 255))

# (5,2) Cafe Patio Checker Tile
fill_tile(5, 2, (176, 148, 118, 255))
rect(5, 2, 0, 0, 8, 8, (194, 168, 138, 255))
rect(5, 2, 8, 8, 8, 8, (194, 168, 138, 255))

# (6,2) Pitch Stripe A
fill_tile(6, 2, (44, 142, 68, 255))
# (7,2) Pitch Stripe B
fill_tile(7, 2, (36, 124, 58, 255))

# --- ROW 3: ACCENTS ---
# (0,3) Asphalt Curb Top
fill_tile(0, 3, ROAD_A)
rect(0, 3, 0, 0, 16, 2, (164, 168, 176, 255))
rect(0, 3, 0, 2, 16, 1, (98, 104, 114, 255))

# (1,3) Asphalt Curb Bottom
fill_tile(1, 3, ROAD_A)
rect(1, 3, 0, 14, 16, 2, (164, 168, 176, 255))
rect(1, 3, 0, 13, 16, 1, (98, 104, 114, 255))

# (2,3) Crosswalk Vertical Stripes
fill_tile(2, 3, ROAD_A)
for x in [2, 7, 12]:
    rect(2, 3, x, 2, 3, 12, (230, 234, 240, 255))

# (3,3) Flowerbed Border
fill_tile(3, 3, (116, 82, 54, 255))
rect(3, 3, 1, 1, 14, 14, (86, 58, 38, 255))
for fx, fy, fc in [(4, 5, (250, 110, 130, 255)), (11, 6, (255, 224, 88, 255)), (7, 11, (148, 198, 255, 255))]:
    rect(3, 3, fx, fy, 2, 2, fc)

# (4,3) Dark Alley Cobble
AL_A = (56, 58, 72, 255)
AL_B = (42, 44, 56, 255)
fill_tile(4, 3, AL_A)
rect(4, 3, 0, 0, 16, 1, AL_B)
rect(4, 3, 0, 8, 16, 1, AL_B)
rect(4, 3, 7, 0, 1, 8, AL_B)
rect(4, 3, 13, 8, 1, 8, AL_B)

# (5,3) Bus Lane Yellow Marking
fill_tile(5, 3, ROAD_A)
rect(5, 3, 1, 2, 14, 2, (242, 196, 46, 255))
rect(5, 3, 1, 12, 14, 2, (242, 196, 46, 255))

# (6,3) Door Mat (Transparent bg)
rect(6, 3, 2, 5, 12, 7, (148, 92, 52, 255))
rect(6, 3, 3, 6, 10, 5, (186, 128, 76, 255))

# (7,3) Building Window (Transparent bg)
rect(7, 3, 3, 3, 10, 10, (56, 62, 76, 255))
rect(7, 3, 4, 4, 8, 8, (132, 196, 238, 255))
rect(7, 3, 7, 4, 2, 8, (56, 62, 76, 255))
rect(7, 3, 4, 7, 8, 2, (56, 62, 76, 255))


def write_png(path: str, width: int, height: int, rgba_rows: list):
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = bytearray()
    for row in rgba_rows:
        raw.append(0)
        for r, g, b, a in row:
            raw.extend((r, g, b, a))

    ihdr = struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


out_path = os.path.join("assets", "tilesets", "town_tiles_16x16.png")
write_png(out_path, W, H, pixels)
print("GENERATED:", out_path, f"{W}x{H}")
