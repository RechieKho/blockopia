#!/usr/bin/env python3
"""Generates the player sprite sheet and the paper-doll clothing sheets in textures/player/, and the
16x16 inventory icons of the clothing items in textures/.

Run from the pack root:  python3 .dev/tools/gen_player.py
Needs Pillow. Re-running overwrites the generated files.

Every sheet has the layout of bp:player (entities/player.lua): variant "tall" = 128 x 256 frames,
4 facings mirrored = 3 rows (0 front, 1 side facing right, 2 back), and the clips idle (2 frames),
walk (4), run (4), jump (1), fall (1) side by side = 12 columns. The engine draws clothing sheets in
the same billboard with the body's exact frame, so every sheet must keep this layout and size.
Art is drawn on a 32 x 64 grid and scaled up 4x. Clothing is drawn in greys and dyed by the item's
tint (data/items.lua), except the straw hat, which has its own colours.
"""
import os
import re

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "textures")
W, H, SCALE = 32, 64, 4
ROWS = 3
# (clip, frame): bob (body moves down), swing (legs/arms, side view), lift (front view: which leg
# is raised and by how much), arms_up
CLIPS = [("idle", 2), ("walk", 4), ("run", 4), ("jump", 1), ("fall", 1)]

SKIN = (232, 190, 150)
SKIN_DARK = (205, 160, 122)
HAIR = (92, 60, 38)
EYE = (40, 34, 40)
TEE = (226, 226, 230)
TEE_DARK = (190, 190, 198)
SHORTS = (72, 82, 112)
SHOE = (64, 46, 36)

LIGHT, MID, DARK = (238, 238, 238), (206, 206, 206), (160, 160, 160)


def frames():
    for clip, count in CLIPS:
        for f in range(count):
            yield clip, f


def pose(clip, f):
    p = {"bob": 0, "swing": 0, "lift": (0, 0), "arms_up": False}
    if clip == "idle":
        p["bob"] = f
    elif clip in ("walk", "run"):
        amp = 2 if clip == "walk" else 4
        p["swing"] = [0, amp, 0, -amp][f]
        p["bob"] = 1 if f in (0, 2) and clip == "run" else 0
        p["lift"] = [(0, 0), (2, 0), (0, 0), (0, 2)][f] if clip == "walk" else [(0, 0), (3, 0), (0, 0), (0, 3)][f]
    elif clip == "jump":
        p["lift"] = (2, 2)
        p["arms_up"] = True
        p["swing"] = 2
    elif clip == "fall":
        p["arms_up"] = True
    return p


class Canvas:
    def __init__(self, img, ox, oy):
        self.img, self.ox, self.oy = img, ox, oy

    def rect(self, x0, y0, x1, y1, color):
        # inclusive logical rectangle, clipped to the frame
        for y in range(max(0, y0), min(H - 1, y1) + 1):
            for x in range(max(0, x0), min(W - 1, x1) + 1):
                for dy in range(SCALE):
                    for dx in range(SCALE):
                        self.img.putpixel((self.ox + x * SCALE + dx, self.oy + y * SCALE + dy), color + (255,))


def geometry(row, p):
    """Rectangles of every body part for one frame (logical coordinates, inclusive)."""
    b = p["bob"]
    g = {}
    g["head"] = (10, 15 + b, 22, 29 + b) if row != 1 else (11, 15 + b, 21, 29 + b)
    if row == 1:
        g["torso"] = (13, 30 + b, 19, 45 + b)
    else:
        g["torso"] = (11, 30 + b, 21, 45 + b)
    legs = []
    if row == 1:
        s = p["swing"]
        for sign, depth in ((-1, "far"), (1, "near")):
            dx = sign * s
            lift = p["lift"][0 if sign < 0 else 1]
            legs.append({"x0": 14 + dx, "x1": 17 + dx, "y0": 46 + b, "y1": 61 - lift,
                         "foot": (14 + dx, 62 - lift, 19 + dx, 63 - lift), "depth": depth})
    else:
        for i, (x0, x1) in enumerate(((12, 15), (17, 20))):
            lift = p["lift"][i]
            legs.append({"x0": x0, "x1": x1, "y0": 46 + b, "y1": 61 - lift,
                         "foot": (x0 - (1 if i == 0 else 0), 62 - lift, x1 + (1 if i == 1 else 0), 63 - lift),
                         "depth": "near"})
    g["legs"] = legs
    arms = []
    if row == 1:
        s = -p["swing"]
        if p["arms_up"]:
            arms.append((15, 21 + b, 17, 31 + b))
        else:
            arms.append((15 + s, 31 + b, 17 + s, 43 + b))
    else:
        for x0, x1 in ((8, 10), (22, 24)):
            if p["arms_up"]:
                arms.append((x0, 20 + b, x1, 30 + b))
            else:
                arms.append((x0, 31 + b, x1, 43 + b))
    g["arms"] = arms
    return g


def draw_body(c, row, p):
    g = geometry(row, p)
    for leg in g["legs"]:
        dark = leg["depth"] == "far"
        c.rect(leg["x0"], leg["y0"], leg["x1"], leg["y1"], SKIN_DARK if dark else SKIN)
        c.rect(leg["x0"], leg["y0"], leg["x1"], min(leg["y1"], leg["y0"] + 5), SHORTS)
        c.rect(*leg["foot"], SHOE)
    x0, y0, x1, y1 = g["torso"]
    c.rect(x0, y0, x1, y1, TEE)
    c.rect(x0, y1 - 2, x1, y1, SHORTS)
    c.rect(x0, y0, x0, y1 - 3, TEE_DARK)
    for ax0, ay0, ax1, ay1 in g["arms"]:
        c.rect(ax0, ay0, ax1, ay1, SKIN)
        if p["arms_up"]:
            c.rect(ax0, ay1 - 3, ax1, ay1, TEE)
        else:
            c.rect(ax0, ay0, ax1, ay0 + 3, TEE)
    hx0, hy0, hx1, hy1 = g["head"]
    c.rect(hx0, hy0, hx1, hy1, SKIN)
    if row == 0:
        c.rect(hx0, hy0, hx1, hy0 + 3, HAIR)
        c.rect(hx0, hy0, hx0, hy0 + 7, HAIR)
        c.rect(hx1, hy0, hx1, hy0 + 7, HAIR)
        c.rect(13, hy0 + 7, 14, hy0 + 8, EYE)
        c.rect(18, hy0 + 7, 19, hy0 + 8, EYE)
        c.rect(15, hy0 + 11, 17, hy0 + 11, SKIN_DARK)
    elif row == 1:
        c.rect(hx0, hy0, hx1, hy0 + 3, HAIR)
        c.rect(hx0, hy0, hx0 + 4, hy0 + 10, HAIR)
        c.rect(hx1 - 2, hy0 + 7, hx1 - 1, hy0 + 8, EYE)
    else:
        c.rect(hx0, hy0, hx1, hy0 + 11, HAIR)


def draw_shirt(c, row, p):
    g = geometry(row, p)
    x0, y0, x1, y1 = g["torso"]
    c.rect(x0, y0, x1, y1 - 2, LIGHT)
    c.rect(x0, y0, x0, y1 - 2, MID)
    c.rect(x1, y0, x1, y1 - 2, MID)
    c.rect(x0, y1 - 3, x1, y1 - 2, MID)
    if row == 0:
        c.rect(15, y0, 17, y0 + 1, DARK)  # collar
    for ax0, ay0, ax1, ay1 in g["arms"]:
        if p["arms_up"]:
            c.rect(ax0, ay1 - 4, ax1, ay1, MID)
        else:
            c.rect(ax0, ay0, ax1, ay0 + 4, MID)


def draw_trousers(c, row, p):
    g = geometry(row, p)
    x0, _, x1, y1 = g["torso"]
    c.rect(x0, y1 - 2, x1, y1, MID)  # waistband
    for leg in g["legs"]:
        shade = DARK if leg["depth"] == "far" else LIGHT
        c.rect(leg["x0"], leg["y0"], leg["x1"], leg["y1"] - 1, shade)
        c.rect(leg["x0"], leg["y1"] - 2, leg["x1"], leg["y1"] - 1, MID)


def draw_cap(c, row, p):
    g = geometry(row, p)
    hx0, hy0, hx1, _ = g["head"]
    c.rect(hx0, hy0 - 2, hx1, hy0 + 3, LIGHT)
    c.rect(hx0, hy0 + 3, hx1, hy0 + 3, MID)
    if row == 0:
        c.rect(hx0 - 1, hy0 + 4, hx1 + 1, hy0 + 4, DARK)  # brim towards the viewer
        c.rect(15, hy0 - 1, 17, hy0, MID)
    elif row == 1:
        c.rect(hx1, hy0 + 3, hx1 + 4, hy0 + 4, DARK)  # brim to the front (right)
    else:
        c.rect(15, hy0 + 2, 17, hy0 + 3, DARK)  # strap


STRAW = (226, 196, 112)
STRAW_DARK = (184, 150, 74)
BAND = (170, 50, 40)


def draw_straw_hat(c, row, p):
    g = geometry(row, p)
    hx0, hy0, hx1, _ = g["head"]
    mid = (hx0 + hx1) // 2
    c.rect(mid - 4, hy0 - 5, mid + 4, hy0 + 2, STRAW)
    c.rect(mid - 4, hy0, mid + 4, hy0 + 1, BAND)
    c.rect(hx0 - 4, hy0 + 2, hx1 + 4, hy0 + 3, STRAW_DARK)
    c.rect(hx0 - 4, hy0 + 2, hx1 + 4, hy0 + 2, STRAW)


def draw_cape(c, row, p):
    g = geometry(row, p)
    b = p["bob"]
    if row == 1:
        # hangs from the shoulders down the back (left in this view), swaying with the walk
        s = abs(p["swing"]) // 2
        c.rect(9 - s, 31 + b, 13, 58 + b, MID)
        c.rect(9 - s, 31 + b, 10 - s, 58 + b, DARK)
        return
    c.rect(9, 30 + b, 23, 58 + b, LIGHT if row == 2 else MID)
    for x in (12, 16, 20):  # folds
        c.rect(x, 36 + b, x, 58 + b, MID if row == 2 else DARK)
    c.rect(9, 30 + b, 23, 31 + b, DARK)


def sheet(draw):
    cols = sum(n for _, n in CLIPS)
    img = Image.new("RGBA", (cols * W * SCALE, ROWS * H * SCALE), (0, 0, 0, 0))
    for col, (clip, f) in enumerate(frames()):
        for row in range(ROWS):
            draw(Canvas(img, col * W * SCALE, row * H * SCALE), row, pose(clip, f))
    return img


SHEETS = {
    "body": draw_body,
    "shirt": draw_shirt,
    "trousers": draw_trousers,
    "cap": draw_cap,
    "straw_hat": draw_straw_hat,
    "cape": draw_cape,
}


def tinted(rgb, tint):
    return tuple(v * t // 255 for v, t in zip(rgb, tint))


def icon(sheet_name, tint):
    """16x16 inventory icon of a clothing item."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    def r(x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                img.putpixel((x, y), c + (255,))

    light, mid, dark = (tinted(c, tint) for c in (LIGHT, MID, DARK))
    if sheet_name == "shirt":
        r(2, 3, 13, 6, mid)
        r(4, 3, 11, 13, light)
        r(7, 3, 8, 4, dark)
    elif sheet_name == "trousers":
        r(4, 2, 11, 4, mid)
        r(4, 5, 7, 14, light)
        r(8, 5, 11, 14, light)
        r(7, 6, 8, 14, dark)
    elif sheet_name == "cap":
        r(4, 5, 11, 10, light)
        r(4, 10, 14, 11, dark)
    elif sheet_name == "straw_hat":
        r(5, 4, 10, 9, STRAW)
        r(5, 8, 10, 9, BAND)
        r(1, 10, 14, 11, STRAW_DARK)
    elif sheet_name == "cape":
        r(3, 2, 12, 3, dark)
        r(3, 4, 12, 14, light)
        for x in (6, 9):
            r(x, 5, x, 14, mid)
    return img


def clothing_items():
    text = open(os.path.join(ROOT, "data", "items.lua")).read()
    for m in re.finditer(r'\{ kind = "clothing", key = "(\w+)".*?sheet = "(\w+)"(.*)$', text, re.M):
        tint = re.search(r"tint = \{ (\d+), (\d+), (\d+) \}", m.group(3))
        yield m.group(1), m.group(2), tuple(int(v) for v in tint.groups()) if tint else (255, 255, 255)


def main():
    os.makedirs(os.path.join(OUT, "player"), exist_ok=True)
    for name, draw in SHEETS.items():
        sheet(draw).save(os.path.join(OUT, "player", name + ".png"), optimize=True)
    for key, sheet_name, tint in clothing_items():
        icon(sheet_name, tint).save(os.path.join(OUT, key + ".png"))


if __name__ == "__main__":
    main()
