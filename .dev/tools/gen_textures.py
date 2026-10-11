#!/usr/bin/env python3
"""Generates the placeholder 16x16 textures in textures/ from data/items.lua colours.

Run from the pack root:  python3 .dev/tools/gen_textures.py
Needs Pillow. Re-running overwrites the generated files (it never touches textures/example.png).
Replace any file with real art; the names are what data/items.lua expects.
"""
import os
import random
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "textures")
SIZE = 16


def parse_items():
    text = open(os.path.join(ROOT, "data", "items.lua")).read()
    entries = []
    for m in re.finditer(r"\{ kind = \"(special|species|vending)\", key = \"(\w+)\".*?color = \{ (\d+), (\d+), (\d+) \}", text):
        entries.append((m.group(1), m.group(2), (int(m.group(3)), int(m.group(4)), int(m.group(5)))))
    return entries


def shade(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)


def noisy(color, seed, spread=14):
    rng = random.Random(seed)
    img = Image.new("RGBA", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            img.putpixel((x, y), shade(color, rng.randint(-spread, spread)) + (255,))
    return img


def border(img, color):
    for i in range(SIZE):
        for xy in ((i, 0), (i, SIZE - 1), (0, i), (SIZE - 1, i)):
            img.putpixel(xy, color + (255,))


def save(name, img):
    img.save(os.path.join(OUT, name + ".png"))


def block(key, color):
    img = noisy(color, key)
    border(img, shade(color, -40))
    save(key, img)


def seed(key, color):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    # a packet with the species colour and a green sprout
    for y in range(5, 14):
        for x in range(4, 12):
            img.putpixel((x, y), (225, 215, 190, 255))
    for y in range(7, 12):
        for x in range(6, 10):
            img.putpixel((x, y), color + (255,))
    for y in range(2, 6):
        img.putpixel((8, y), (60, 160, 60, 255))
    img.putpixel((7, 3), (60, 160, 60, 255))
    img.putpixel((9, 4), (60, 160, 60, 255))
    save(key + "_seed", img)


def shrub(key, color, stage):
    # A leafy bush filling the block: leaves get denser as it grows, and a ripe one shows fruit in
    # the species colour. Fully opaque: engines before 0.1.5 had no alpha cutout, so clear texels
    # showed holes of sky through the terrain behind.
    rng = random.Random("%s_s%d" % (key, stage))
    shadow = (28, 74, 32)
    leaf = ((92, 178, 84), (70, 156, 64), (58, 138, 56))[stage]
    density = (0.35, 0.6, 0.8)[stage]
    img = Image.new("RGBA", (SIZE, SIZE), shadow + (255,))
    for y in range(SIZE):
        for x in range(SIZE):
            if rng.random() < density:
                img.putpixel((x, y), shade(leaf, rng.randint(-18, 18)) + (255,))
    border(img, shade(shadow, -12))
    if stage == 2:
        dark = shade(color, -70)
        for (x, y) in ((3, 3), (10, 2), (6, 7), (12, 8), (3, 11), (9, 12)):
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                img.putpixel((x + dx, y + dy), color + (255,))
            img.putpixel((x + 1, y + 1), dark + (255,))
    save("%s_s%d" % (key, stage), img)


def lock(tier, color):
    img = Image.new("RGBA", (SIZE, SIZE), color + (255,))
    border(img, shade(color, -60))
    for y in range(4, 8):
        for x in range(5, 11):
            if y == 4 or x in (5, 10):
                img.putpixel((x, y), (60, 60, 60, 255))
    for y in range(8, 13):
        for x in range(4, 12):
            img.putpixel((x, y), (40, 40, 40, 255))
    img.putpixel((8, 10), color + (255,))
    save("lock_" + tier, img)


def border_post(tier, color):
    # bp:border sprite sheet (entities/border.lua): variant "tall" = 128 x 256 frames, 4 facings
    # mirrored = 3 rows, one frame. A pole in the lock tier's colour with a pennant, the same from
    # every side; transparent around it.
    fw, fh, rows = 128, 256, 3
    img = Image.new("RGBA", (fw, fh * rows), (0, 0, 0, 0))
    dark = shade(color, -70)
    for r in range(rows):
        top = r * fh
        for y in range(top + 20, top + fh):
            for x in range(44, 84):
                edge = x in (44, 45, 46, 81, 82, 83)
                band = ((y - top) // 24) % 2 == 0
                c = dark if edge else (color if band else shade(color, 45))
                img.putpixel((x, y), c + (255,))
        for y in range(top + 20, top + 76):  # pennant
            width = int(44 * (1 - abs((y - top) - 48) / 28.0))
            for x in range(84, 84 + max(0, min(width, 44))):
                img.putpixel((x, y), shade(color, 25) + (255,))
    img.save(os.path.join(OUT, "border_%s.png" % tier))


# 5 x 7 pixel font for the shrub timer labels: just the characters they use.
GLYPHS = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "s": ["00000", "00000", "01111", "10000", "01110", "00001", "11110"],
    "m": ["00000", "00000", "11010", "10101", "10101", "10101", "10101"],
    "h": ["10000", "10000", "10110", "11001", "10001", "10001", "10001"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "i": ["00100", "00000", "01100", "00100", "00100", "00100", "01110"],
    "p": ["00000", "00000", "11110", "10001", "11110", "10000", "10000"],
    "e": ["00000", "00000", "01110", "10001", "11111", "10000", "01110"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
}
LABEL_MAX_HOURS = 99


def label_texts():
    # Must match lib/farm.lua's label_texts().
    return (["Ripe!"] + ["%ds" % n for n in range(1, 60)] + ["%dm" % n for n in range(1, 60)]
            + ["%dh" % n for n in range(1, LABEL_MAX_HOURS + 1)])


def draw_label(img, left, top, fw, fh, text):
    # A dark rounded tag with the text in white (green for "Ripe!"), centred low in the frame.
    gap, pad = 2, 14
    scale = min(9, (fw - 2 * pad - 4) // (len(text) * (5 + gap) - gap))  # "Ripe!" is drawn smaller
    ink = (120, 235, 110, 255) if text == "Ripe!" else (255, 255, 255, 255)
    text_w = len(text) * (5 + gap) * scale - gap * scale
    w, h = text_w + 2 * pad, 7 * scale + 2 * pad
    x0, y0 = left + (fw - w) // 2, top + fh - h - 2
    for y in range(h):
        for x in range(w):
            corner = min(x, w - 1 - x) < 6 and min(y, h - 1 - y) < 6 and \
                (min(x, w - 1 - x) - 6) ** 2 + (min(y, h - 1 - y) - 6) ** 2 > 36
            if not corner:
                edge = min(x, w - 1 - x, y, h - 1 - y) < 3
                img.putpixel((x0 + x, y0 + y), (15, 15, 15, 255) if edge else (45, 45, 45, 255))
    cx = x0 + pad
    for ch in text:
        for gy, row in enumerate(GLYPHS[ch]):
            for gx, bit in enumerate(row):
                if bit == "1":
                    for yy in range(scale):
                        for xx in range(scale):
                            img.putpixel((cx + gx * scale + xx, y0 + pad + gy * scale + yy), ink)
        cx += (5 + gap) * scale


def shrub_timers():
    # bp:shrub_timer labels (entities/shrub_timer.lua), one texture per text: variant "flat" =
    # 256 x 128 frame, 4 facings mirrored = 3 identical rows.
    fw, fh, rows = 256, 128, 3
    out = os.path.join(OUT, "timer")
    os.makedirs(out, exist_ok=True)
    for text in label_texts():
        img = Image.new("RGBA", (fw, fh * rows), (0, 0, 0, 0))
        for r in range(rows):
            draw_label(img, 0, r * fh, fw, fh, text)
        name = "ripe" if text == "Ripe!" else text
        img.save(os.path.join(out, name + ".png"), optimize=True)


def vending(key, color):
    img = noisy(color, key, 6)
    border(img, shade(color, -50))
    for y in range(3, 10):
        for x in range(3, 13):
            img.putpixel((x, y), (200, 230, 240, 255))
    for x in range(3, 13):
        img.putpixel((x, 6), (150, 180, 190, 255))
    for x in range(5, 11):
        img.putpixel((x, 12), (30, 30, 30, 255))
    save(key, img)


def wrench(key, color):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for i in range(3, 13):
        img.putpixel((i, 15 - i), color + (255,))
        img.putpixel((i, 14 - i), shade(color, -40) + (255,))
    for (x, y) in ((11, 2), (12, 2), (13, 3), (13, 4), (12, 4), (11, 3)):
        img.putpixel((x, y), color + (255,))
    save(key, img)


def lava(key, color):
    rng = random.Random(key)
    img = Image.new("RGBA", (SIZE, SIZE))
    for y in range(SIZE):
        for x in range(SIZE):
            d = rng.randint(-30, 40)
            img.putpixel((x, y), (min(255, color[0] + d), max(0, color[1] + d), color[2], 255))
    save(key, img)


def main():
    os.makedirs(OUT, exist_ok=True)
    lock_colors = {"small": (120, 190, 120), "big": (90, 150, 220), "huge": (170, 100, 220), "grand": (240, 190, 40)}
    for kind, key, color in parse_items():
        if kind == "special":
            if key == "wrench":
                wrench(key, color)
            elif key == "lava":
                lava(key, color)
            else:
                block(key, color)
        elif kind == "species":
            block(key, color)
            seed(key, color)
            for stage in range(3):
                shrub(key, color, stage)
        elif kind == "vending":
            vending(key, color)
    for tier, color in lock_colors.items():
        lock(tier, color)
        border_post(tier, color)
    border_post("blocked", (225, 60, 50))  # the preview where a lock cannot go
    shrub_timers()


if __name__ == "__main__":
    main()
