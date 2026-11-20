import os
import struct
import zlib

# Generates:
# 1) 7 Aseprite-ready 224x144 building interior background templates in assets/sprites/interiors/
# 2) 9 Aseprite-ready 96x44 training card illustrations in assets/sprites/cards/


def make_canvas(w: int, h: int, bg=(0, 0, 0, 255)):
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


def make_interior(wall_col, wall_trim, floor_a, floor_b, rug_col):
    w, h = 224, 144
    img = make_canvas(w, h, floor_a)
    # Checkered / planked floor
    for y in range(30, h, 8):
        rect(img, 0, y, w, 1, floor_b)
    for y in range(30, h, 16):
        for x in range(0, w, 24):
            rect(img, x + ((y // 16) % 2) * 12, y, 1, 8, floor_b)
    # Back wall (top 28px)
    rect(img, 0, 0, w, 28, wall_col)
    rect(img, 0, 26, w, 4, wall_trim)
    # Windows on back wall
    for wx in [28, 172]:
        rect(img, wx, 6, 24, 14, (54, 60, 74, 255))
        rect(img, wx + 2, 8, 20, 10, (144, 208, 242, 255))
        rect(img, wx + 11, 8, 2, 10, (54, 60, 74, 255))
    # Center rug
    rect(img, 62, 64, 100, 44, rug_col)
    border(img, 64, 66, 96, 40, (238, 224, 176, 255))
    # Exit doorway mat at bottom center (guide for player artist!)
    rect(img, 96, h - 14, 32, 14, (158, 106, 58, 255))
    border(img, 96, h - 14, 32, 14, (92, 58, 30, 255))
    # Room outer frame
    border(img, 0, 0, w, h, (32, 34, 42, 255))
    return img


interiors = [
    ("home_bg.png", (196, 176, 148, 255), (128, 92, 60, 255), (132, 92, 58, 255), (112, 74, 44, 255), (62, 114, 162, 255)),
    ("clubhouse_bg.png", (72, 98, 142, 255), (42, 60, 94, 255), (46, 70, 112, 255), (38, 58, 96, 255), (186, 152, 54, 255)),
    ("press_center_bg.png", (166, 168, 176, 255), (96, 100, 112, 255), (92, 96, 110, 255), (78, 82, 96, 255), (136, 140, 152, 255)),
    ("gol_cafe_bg.png", (214, 184, 140, 255), (138, 86, 48, 255), (154, 112, 72, 255), (134, 94, 58, 255), (168, 74, 54, 255)),
    ("nightclub_bg.png", (64, 28, 98, 255), (196, 58, 168, 255), (34, 26, 54, 255), (48, 36, 76, 255), (124, 38, 152, 255)),
    ("sport_shop_bg.png", (184, 210, 188, 255), (56, 118, 82, 255), (68, 114, 86, 255), (56, 98, 72, 255), (218, 186, 68, 255)),
    ("corner_cafe_bg.png", (192, 168, 138, 255), (118, 82, 52, 255), (124, 90, 62, 255), (104, 74, 48, 255), (52, 126, 74, 255)),
]
for fname, wc, wt, fa, fb, rc in interiors:
    write_png(os.path.join("assets", "sprites", "interiors", fname), make_interior(wc, wt, fa, fb, rc))


# --- CARD ARTWORK PLACEHOLDERS (96x44) ---
def make_card_art(sky_col, pitch_col, accent_col, style: str):
    w, h = 96, 44
    img = make_canvas(w, h, sky_col)
    # Pitch bottom half
    rect(img, 0, 22, w, 22, pitch_col)
    rect(img, 0, 22, w, 2, (230, 240, 232, 255))

    if style == "freekick":
        # Goal + 3-man wall + curved shot arc + ball
        rect(img, 24, 6, 48, 16, (220, 234, 244, 110))
        border(img, 24, 6, 48, 17, (250, 252, 255, 255))
        for wx in [36, 45, 54]:
            rect(img, wx, 17, 6, 12, (214, 58, 58, 255))
            rect(img, wx + 1, 14, 4, 3, (238, 198, 162, 255))
        # Curved yellow trail
        for px, py in [(48, 36), (56, 30), (62, 22), (65, 13), (67, 10)]:
            rect(img, px, py, 2, 2, accent_col)
        rect(img, 45, 35, 5, 5, (250, 250, 255, 255))
    elif style == "1v1":
        # Blue attacker vs Red defender + lightning
        rect(img, 26, 18, 9, 16, (44, 144, 238, 255))
        rect(img, 28, 13, 5, 5, (240, 202, 166, 255))
        rect(img, 60, 18, 9, 16, (216, 56, 62, 255))
        rect(img, 62, 13, 5, 5, (240, 202, 166, 255))
        rect(img, 44, 31, 6, 6, (252, 252, 255, 255))
        rect(img, 45, 14, 6, 4, accent_col)
    elif style == "weights":
        # Gym room + Barbell
        rect(img, 0, 0, w, h, (44, 50, 64, 255))
        rect(img, 0, 28, w, 16, (68, 72, 86, 255))
        rect(img, 20, 19, 56, 4, (198, 206, 218, 255))
        rect(img, 14, 11, 8, 20, (34, 38, 46, 255))
        rect(img, 23, 14, 5, 14, accent_col)
        rect(img, 74, 11, 8, 20, (34, 38, 46, 255))
        rect(img, 68, 14, 5, 14, accent_col)
    elif style == "rondo":
        # Tactical circle + arrows
        border(img, 26, 10, 44, 26, (242, 248, 242, 255))
        for px, py in [(28, 14), (62, 14), (28, 30), (62, 30)]:
            rect(img, px, py, 6, 6, (46, 156, 242, 255))
        rect(img, 45, 21, 6, 6, (226, 62, 62, 255))
        rect(img, 36, 16, 22, 2, accent_col)
    elif style == "gk_duel":
        # Goal + Goalkeeper diving + ball
        border(img, 18, 6, 60, 18, (250, 252, 255, 255))
        rect(img, 42, 14, 12, 10, (242, 196, 42, 255))
        rect(img, 46, 10, 4, 4, (240, 202, 166, 255))
        rect(img, 46, 33, 5, 5, (252, 252, 255, 255))
        rect(img, 26, 10, 6, 6, accent_col)
    elif style == "hangover":
        # Dizzy purple-amber haze + alarm stars
        rect(img, 0, 0, w, 22, (74, 36, 86, 255))
        rect(img, 40, 14, 16, 16, (224, 192, 158, 255))
        rect(img, 43, 19, 3, 3, (34, 30, 38, 255))
        rect(img, 50, 19, 3, 3, (34, 30, 38, 255))
        for sx, sy in [(26, 8), (64, 9), (32, 18), (60, 17)]:
            rect(img, sx, sy, 4, 4, accent_col)
    elif style == "sprint":
        # Track lanes + speed lines
        for y in [25, 31, 37]:
            rect(img, 0, y, w, 1, (242, 246, 242, 255))
        rect(img, 58, 16, 10, 16, (44, 168, 242, 255))
        for lx, ly in [(18, 20), (26, 24), (20, 28), (34, 22)]:
            rect(img, lx, ly, 18, 2, accent_col)
    else:
        # Scrimmage / default match field
        border(img, 12, 8, 72, 28, (244, 248, 244, 255))
        rect(img, 47, 8, 2, 28, (244, 248, 244, 255))
        rect(img, 45, 19, 6, 6, accent_col)

    border(img, 0, 0, w, h, (24, 28, 36, 255))
    return img


cards = [
    ("card_freekick.png", (58, 124, 188, 255), (42, 134, 62, 255), (255, 224, 72, 255), "freekick"),
    ("card_1v1.png", (62, 136, 196, 255), (44, 138, 66, 255), (255, 212, 64, 255), "1v1"),
    ("card_weights.png", (44, 50, 64, 255), (68, 72, 86, 255), (242, 114, 58, 255), "weights"),
    ("card_rondo.png", (48, 108, 162, 255), (38, 128, 58, 255), (96, 232, 255, 255), "rondo"),
    ("card_gk_duel.png", (52, 116, 178, 255), (42, 134, 62, 255), (255, 96, 78, 255), "gk_duel"),
    ("card_hangover.png", (74, 36, 86, 255), (54, 96, 52, 255), (255, 214, 68, 255), "hangover"),
    ("card_sprint.png", (68, 146, 206, 255), (168, 72, 54, 255), (255, 236, 98, 255), "sprint"),
    ("card_scrimmage.png", (46, 102, 156, 255), (38, 132, 60, 255), (255, 224, 78, 255), "scrimmage"),
    ("card_default.png", (46, 102, 156, 255), (38, 132, 60, 255), (255, 224, 78, 255), "scrimmage"),
]
for fname, sc, pc, ac, st in cards:
    write_png(os.path.join("assets", "sprites", "cards", fname), make_card_art(sc, pc, ac, st))

print("INTERIORS_AND_CARDS_GENERATED_OK")
