import os
import struct
import zlib

# Generates 3 new Aseprite-ready home decoration prop PNGs in assets/sprites/props/


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


# 1. Home Gym Corner (32x24)
gym = make_canvas(32, 24)
rect(gym, 2, 20, 28, 3, (0, 0, 0, 75))
rect(gym, 3, 14, 26, 7, (58, 66, 82, 255))
rect(gym, 5, 11, 22, 4, (192, 58, 52, 255))
rect(gym, 6, 5, 20, 2, (206, 214, 224, 255))
rect(gym, 4, 2, 4, 9, (34, 38, 46, 255))
rect(gym, 24, 2, 4, 9, (34, 38, 46, 255))
write_png(os.path.join("assets", "sprites", "props", "home_gym.png"), gym)

# 2. Arcade TV & Console (32x24)
tv = make_canvas(32, 24)
rect(tv, 2, 20, 28, 3, (0, 0, 0, 75))
rect(tv, 3, 12, 26, 9, (98, 66, 42, 255))
border(tv, 3, 12, 26, 9, (48, 32, 20, 255))
rect(tv, 6, 2, 20, 12, (36, 40, 52, 255))
rect(tv, 8, 4, 16, 8, (64, 198, 138, 255))
rect(tv, 11, 6, 4, 4, (252, 224, 72, 255))
rect(tv, 18, 7, 3, 3, (242, 86, 124, 255))
write_png(os.path.join("assets", "sprites", "props", "arcade_tv.png"), tv)

# 3. Trophy Shelf (28x28)
tr = make_canvas(28, 28)
rect(tr, 2, 24, 24, 3, (0, 0, 0, 75))
rect(tr, 3, 2, 22, 23, (124, 82, 48, 255))
border(tr, 3, 2, 22, 23, (58, 36, 20, 255))
rect(tr, 5, 11, 18, 2, (84, 54, 30, 255))
rect(tr, 5, 19, 18, 2, (84, 54, 30, 255))
# Gold trophies
rect(tr, 8, 5, 4, 5, (250, 212, 58, 255))
rect(tr, 16, 5, 4, 5, (230, 236, 244, 255))
rect(tr, 12, 13, 4, 5, (250, 212, 58, 255))
write_png(os.path.join("assets", "sprites", "props", "trophy_shelf.png"), tr)

print("PHASE6_PROPS_OK")
