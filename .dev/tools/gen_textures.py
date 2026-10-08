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
    # Fully opaque on purpose: the engine draws pack blocks in its opaque pass with no alpha cutout,
    # so a transparent texel would hide the terrain behind it (it shows the sky instead). A shrub
    # is a leafy bush filling the block: leaves get denser as it grows, and a ripe one shows fruit
    # in the species colour.
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


if __name__ == "__main__":
    main()
