import os
import struct
import zlib

# Generates Aseprite-ready placeholder pixel-art PNGs for buildings, trees, bus, and interior props.
# The user can open any of these PNGs in Aseprite, draw their own art at the same dimensions,
# and overwrite the file — Godot will automatically display the new artwork 1-to-1!


def make_canvas(w: int, h: int, bg=(0, 0, 0, 0)):
    return [[bg for _ in range(w)] for _ in range(h)]


def rect(img, x0: int, y0: int, w: int, h: int, col: tuple):
    H = len(img)
    W = len(img[0])
    for y in range(max(0, y0), min(H, y0 + h)):
        for x in range(max(0, x0), min(W, x0 + w)):
            img[y][x] = col


def border(img, x0: int, y0: int, w: int, h: int, col: tuple):
    rect(img, x0, y0, w, 1, col)
    rect(img, x0, y0 + h - 1, w, 1, col)
    rect(img, x0, y0, 1, h, col)
    rect(img, x0 + w - 1, y0, 1, h, col)


def write_png(path: str, img: list):
    h = len(img)
    w = len(img[0])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = bytearray()
    for row in img:
        raw.append(0)
        for r, g, b, a in row:
            raw.extend((r, g, b, a))

    ihdr = struct.pack("!IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def build_building(w: int, h: int, roof_col, roof_dark, wall_col, accent_col, door_at_top: bool):
    img = make_canvas(w, h)
    # Shadow
    rect(img, 2, h - 4, w - 4, 4, (0, 0, 0, 75))
    # Roof top 34px, Wall bottom (or flipped highlight if door_at_top)
    roof_h = 34
    rect(img, 2, 2, w - 4, roof_h, roof_col)
    for y in range(6, roof_h, 5):
        rect(img, 2, y, w - 4, 1, roof_dark)
    border(img, 2, 2, w - 4, roof_h, roof_dark)

    # Wall body
    wall_y = 2 + roof_h
    wall_h = h - wall_y - 4
    rect(img, 4, wall_y, w - 8, wall_h, wall_col)
    rect(img, 4, wall_y + wall_h - 5, w - 8, 5, (72, 74, 82, 255))
    border(img, 4, wall_y, w - 8, wall_h, (44, 46, 54, 255))

    # Signboard stripe on roof
    rect(img, w // 2 - 26, 12, 52, 12, accent_col)
    border(img, w // 2 - 26, 12, 52, 12, (28, 30, 38, 255))

    # Windows
    win_y = wall_y + 8
    for wx in [14, w - 30]:
        rect(img, wx, win_y, 16, 14, (54, 60, 74, 255))
        rect(img, wx + 2, win_y + 2, 12, 10, (148, 212, 246, 255))
        rect(img, wx + 7, win_y + 2, 2, 10, (54, 60, 74, 255))
        rect(img, wx + 2, win_y + 6, 12, 2, (54, 60, 74, 255))

    # Door (centered horizontally; placed at bottom facade or top-facing entrance cue)
    dx = w // 2 - 10
    if not door_at_top:
        dy = h - 26
        rect(img, dx - 2, dy - 2, 24, 24, (58, 42, 30, 255))
        rect(img, dx, dy, 20, 22, (124, 78, 44, 255))
        rect(img, dx + 2, dy + 2, 16, 8, (152, 104, 64, 255))
        rect(img, dx + 15, dy + 12, 3, 3, (245, 212, 82, 255))
        # Door mat
        rect(img, dx + 2, h - 4, 16, 4, (176, 124, 72, 255))
    else:
        # Top-facing building (south row of town facing north road): entrance canopy + mat at top!
        rect(img, dx - 4, 0, 28, 10, (58, 42, 30, 255))
        rect(img, dx - 2, 0, 24, 8, (232, 194, 78, 255))
        rect(img, dx + 2, 1, 16, 5, (124, 78, 44, 255))
        # Also decorative front glass at bottom
        rect(img, dx, wall_y + 10, 20, 14, (64, 74, 92, 255))
        rect(img, dx + 2, wall_y + 12, 16, 10, (132, 198, 236, 255))
    return img


# 1. Buildings (7 exteriors)
buildings = [
    ("home_ext.png", 112, 80, (172, 68, 56, 255), (126, 44, 36, 255), (226, 212, 186, 255), (242, 218, 128, 255), False),
    ("clubhouse_ext.png", 128, 80, (44, 84, 148, 255), (28, 58, 106, 255), (212, 222, 236, 255), (244, 204, 72, 255), False),
    ("press_ext.png", 112, 80, (78, 88, 106, 255), (52, 60, 74, 255), (218, 214, 202, 255), (234, 224, 182, 255), False),
    ("gol_cafe_ext.png", 112, 80, (186, 102, 48, 255), (140, 72, 30, 255), (232, 214, 184, 255), (248, 196, 86, 255), True),
    ("nightclub_ext.png", 128, 80, (82, 34, 124, 255), (52, 20, 84, 255), (46, 44, 62, 255), (236, 72, 188, 255), True),
    ("sport_shop_ext.png", 112, 80, (42, 126, 84, 255), (28, 88, 58, 255), (218, 230, 218, 255), (112, 232, 148, 255), True),
    ("corner_cafe_ext.png", 112, 80, (138, 92, 54, 255), (98, 62, 34, 255), (224, 210, 186, 255), (168, 224, 144, 255), True),
]
for fname, bw, bh, rc, rd, wc, ac, top_d in buildings:
    write_png(os.path.join("assets", "sprites", "buildings", fname), build_building(bw, bh, rc, rd, wc, ac, top_d))

# 2. Oak Tree (32x48 Stardew style!)
tree = make_canvas(32, 48)
# Ground shadow
rect(tree, 7, 41, 18, 5, (0, 0, 0, 85))
# Trunk
rect(tree, 12, 28, 8, 16, (104, 68, 42, 255))
rect(tree, 13, 28, 3, 15, (128, 88, 56, 255))
rect(tree, 18, 28, 2, 15, (78, 48, 28, 255))
# Canopy layers
rect(tree, 5, 10, 22, 20, (26, 78, 38, 255))
rect(tree, 3, 14, 26, 13, (26, 78, 38, 255))
rect(tree, 7, 5, 18, 22, (36, 104, 48, 255))
rect(tree, 5, 11, 22, 14, (36, 104, 48, 255))
rect(tree, 9, 4, 14, 12, (62, 142, 72, 255))
rect(tree, 7, 9, 12, 8, (82, 168, 88, 255))
rect(tree, 11, 6, 6, 4, (112, 196, 108, 255))
write_png(os.path.join("assets", "sprites", "props", "tree_oak.png"), tree)

# 3. Bus Vehicle (64x36)
bus = make_canvas(64, 36)
rect(bus, 4, 30, 56, 5, (0, 0, 0, 90))
rect(bus, 4, 6, 56, 24, (238, 188, 38, 255))
rect(bus, 4, 19, 56, 4, (206, 148, 24, 255))
border(bus, 4, 6, 56, 24, (64, 48, 16, 255))
for wx in [8, 20, 32, 44]:
    rect(bus, wx, 9, 9, 8, (148, 218, 248, 255))
    border(bus, wx, 9, 9, 8, (54, 62, 76, 255))
rect(bus, 55, 10, 4, 9, (194, 236, 255, 255))
# Wheels
rect(bus, 12, 27, 9, 7, (32, 34, 40, 255))
rect(bus, 15, 29, 3, 3, (164, 170, 182, 255))
rect(bus, 43, 27, 9, 7, (32, 34, 40, 255))
rect(bus, 46, 29, 3, 3, (164, 170, 182, 255))
write_png(os.path.join("assets", "sprites", "props", "bus_vehicle.png"), bus)

# 4. Interior Furniture Props
def make_furniture(w: int, h: int, top_col, body_col, detail_col):
    c = make_canvas(w, h)
    rect(c, 1, h - 3, w - 2, 3, (0, 0, 0, 75))
    rect(c, 1, 1, w - 2, h - 4, body_col)
    rect(c, 2, 2, w - 4, max(6, h // 2 - 2), top_col)
    border(c, 1, 1, w - 2, h - 4, (36, 32, 30, 255))
    rect(c, 5, 4, w - 10, 4, detail_col)
    return c

# Bed (32x24)
bed = make_canvas(32, 24)
rect(bed, 1, 21, 30, 3, (0, 0, 0, 75))
rect(bed, 2, 2, 28, 19, (118, 76, 44, 255))
rect(bed, 4, 4, 10, 15, (238, 242, 248, 255))
rect(bed, 12, 4, 16, 15, (56, 134, 212, 255))
rect(bed, 12, 4, 4, 15, (198, 224, 248, 255))
border(bed, 2, 2, 28, 19, (46, 32, 20, 255))
write_png(os.path.join("assets", "sprites", "props", "bed.png"), bed)

# PC Desk (32x24)
pc = make_furniture(32, 24, (132, 92, 58, 255), (96, 64, 38, 255), (62, 68, 82, 255))
rect(pc, 9, 2, 14, 9, (42, 48, 60, 255))
rect(pc, 10, 3, 12, 7, (76, 218, 252, 255))
rect(pc, 11, 13, 10, 3, (206, 212, 222, 255))
write_png(os.path.join("assets", "sprites", "props", "pc_desk.png"), pc)

# Cafe Counter (64x24)
write_png(os.path.join("assets", "sprites", "props", "cafe_counter.png"),
          make_furniture(64, 24, (176, 122, 74, 255), (124, 80, 46, 255), (238, 218, 174, 255)))

# Card Table (40x28)
ct = make_canvas(40, 28)
rect(ct, 2, 24, 36, 4, (0, 0, 0, 75))
rect(ct, 2, 2, 36, 22, (116, 74, 42, 255))
rect(ct, 5, 5, 30, 16, (34, 128, 68, 255))
border(ct, 2, 2, 36, 22, (48, 30, 18, 255))
# Tiny cards on table
rect(ct, 11, 9, 5, 7, (246, 248, 252, 255))
rect(ct, 24, 11, 5, 7, (246, 248, 252, 255))
write_png(os.path.join("assets", "sprites", "props", "card_table.png"), ct)

# Neon Bar Counter (72x24)
write_png(os.path.join("assets", "sprites", "props", "bar_counter.png"),
          make_furniture(72, 24, (84, 40, 128, 255), (44, 30, 68, 255), (242, 78, 198, 255)))

# Sport Shop Rack (48x24)
write_png(os.path.join("assets", "sprites", "props", "shop_rack.png"),
          make_furniture(48, 24, (64, 152, 98, 255), (44, 96, 68, 255), (248, 212, 76, 255)))

# Press Desk (48x24)
write_png(os.path.join("assets", "sprites", "props", "press_desk.png"),
          make_furniture(48, 24, (148, 152, 164, 255), (86, 92, 108, 255), (244, 240, 218, 255)))

# Negotiation Desk (56x28)
write_png(os.path.join("assets", "sprites", "props", "negotiation_desk.png"),
          make_furniture(56, 28, (134, 82, 48, 255), (92, 54, 32, 255), (244, 222, 136, 255)))

print("WORLD_SPRITES_GENERATED_OK")
