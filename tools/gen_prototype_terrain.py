"""
gen_prototype_terrain.py: placeholder terrain tiles for the Tactics Core grid.

Output : ../game/tilesets/prototype_terrain.png
Layout : one row of 16x16 tiles, in this order (index = atlas x coordinate):
         0 plains, 1 road, 2 forest, 3 ruins, 4 hill, 5 fort, 6 water, 7 wall, 8 doorway
Each tile has a distinct pattern as well as a color, so terrain is readable
without relying on color alone. Re-run after editing; Godot re-imports the PNG.
The atlas coordinates are referenced by game/tilesets/prototype_terrain.tres,
so keep the order stable (append new terrain at the end).

Usage: python3 tools/gen_prototype_terrain.py
"""
import os
from PIL import Image

T = 16
ORDER = ["plains", "road", "forest", "ruins", "hill", "fort", "water", "wall", "doorway"]
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "tilesets", "prototype_terrain.png")

GRASS = (126, 168, 88)
GRASS_D = (98, 140, 66)
GRASS_L = (160, 196, 112)


def fill(img, ox, color):
    for y in range(T):
        for x in range(T):
            img.putpixel((ox + x, y), color)


def px(img, ox, x, y, color):
    if 0 <= x < T and 0 <= y < T:
        img.putpixel((ox + x, y), color)


def rect(img, ox, x0, y0, x1, y1, color):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, ox, x, y, color)


def plains(img, ox):
    fill(img, ox, GRASS)
    for (x, y) in [(2, 3), (9, 2), (13, 6), (5, 9), (11, 12), (2, 13), (7, 14)]:
        px(img, ox, x, y, GRASS_D)
        px(img, ox, x + 1, y - 1, GRASS_L)


def road(img, ox):
    fill(img, ox, GRASS)
    rect(img, ox, 0, 4, 15, 11, (196, 170, 118))
    rect(img, ox, 0, 4, 15, 4, (160, 136, 92))
    rect(img, ox, 0, 11, 15, 11, (160, 136, 92))
    for x in (1, 6, 11):
        rect(img, ox, x, 7, x + 2, 8, (222, 202, 156))


def forest(img, ox):
    fill(img, ox, GRASS_D)
    for (cx, cy) in [(4, 5), (11, 4), (7, 11), (13, 12)]:
        rect(img, ox, cx - 2, cy - 2, cx + 2, cy + 1, (52, 104, 56))
        rect(img, ox, cx - 1, cy - 3, cx + 1, cy - 3, (52, 104, 56))
        px(img, ox, cx - 1, cy - 2, (84, 140, 80))
        px(img, ox, cx, cy + 2, (96, 66, 40))


def ruins(img, ox):
    fill(img, ox, GRASS)
    stone, dark, light = (150, 146, 136), (104, 100, 92), (190, 186, 176)
    for (x0, y0, x1, y1) in [(1, 2, 5, 5), (9, 1, 14, 3), (3, 9, 7, 13), (10, 8, 13, 13)]:
        rect(img, ox, x0, y0, x1, y1, stone)
        rect(img, ox, x0, y1, x1, y1, dark)
        px(img, ox, x0, y0, light)
    px(img, ox, 12, 10, dark)
    px(img, ox, 5, 11, dark)


def hill(img, ox):
    fill(img, ox, GRASS)
    for (cx, cy, r) in [(5, 9, 5), (11, 7, 4)]:
        for y in range(T):
            for x in range(T):
                if (x - cx) ** 2 + ((y - cy) * 1.6) ** 2 <= r * r:
                    shade = (150, 150, 92) if x < cx else (122, 124, 74)
                    px(img, ox, x, y, shade)
    for x in range(1, 10):
        px(img, ox, x, 12, (100, 102, 60))


def fort(img, ox):
    fill(img, ox, GRASS)
    wall, dark, light = (168, 160, 150), (112, 106, 98), (206, 200, 190)
    rect(img, ox, 2, 4, 13, 14, wall)
    for x in range(2, 14, 3):
        rect(img, ox, x, 2, x + 1, 3, wall)
    rect(img, ox, 2, 14, 13, 14, dark)
    rect(img, ox, 6, 9, 9, 14, (70, 54, 40))
    rect(img, ox, 2, 4, 13, 4, light)
    rect(img, ox, 12, 0, 12, 4, (90, 80, 70))
    rect(img, ox, 13, 0, 15, 1, (212, 72, 64))


def water(img, ox):
    fill(img, ox, (64, 112, 184))
    for (x0, y) in [(1, 3), (8, 6), (3, 10), (10, 13)]:
        for i in range(4):
            px(img, ox, x0 + i, y - (1 if i in (1, 2) else 0), (132, 176, 224))


def wall(img, ox):
    fill(img, ox, (84, 80, 88))
    mortar = (58, 54, 62)
    for y in (3, 7, 11, 15):
        rect(img, ox, 0, y, 15, y, mortar)
    for row, y0 in enumerate((0, 4, 8, 12)):
        offset = 0 if row % 2 == 0 else 4
        for x in range(offset, T, 8):
            rect(img, ox, x, y0, x, y0 + 2, mortar)
    for (x, y) in [(2, 1), (10, 5), (5, 9), (13, 13)]:
        px(img, ox, x, y, (112, 108, 116))


def doorway(img, ox):
    wall(img, ox)
    rect(img, ox, 4, 3, 11, 15, (196, 170, 118))
    rect(img, ox, 4, 3, 11, 3, (140, 110, 70))
    rect(img, ox, 3, 3, 3, 15, (140, 110, 70))
    rect(img, ox, 12, 3, 12, 15, (140, 110, 70))


DRAW = {"plains": plains, "road": road, "forest": forest, "ruins": ruins, "hill": hill,
        "fort": fort, "water": water, "wall": wall, "doorway": doorway}

if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img = Image.new("RGBA", (T * len(ORDER), T), (0, 0, 0, 0))
    for i, name in enumerate(ORDER):
        DRAW[name](img, i * T)
    img.save(OUT)
    print(f"Saved {len(ORDER)} tiles -> {os.path.abspath(OUT)}")
