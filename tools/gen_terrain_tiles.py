"""
gen_terrain_tiles.py — generates terrain_tiles.png for the battle TileMapLayer.

Output : ../assets/tilesets/terrain_tiles.png
Layout : 5 tiles wide × 1 tile tall, laid out left→right in this order:
            0=plain  1=forest  2=peak  3=wall  4=water
Tile size: 16×16 px, transparent background for unused pixels.

Re-run this script whenever you want to update the tile art.
The tile index order MUST stay stable — battle.gd hardcodes TERRAIN_TILE_ID.

Usage:
    python3 tools/gen_terrain_tiles.py
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from PIL import Image, ImageDraw
import palette as P

TILE  = 16
COUNT = 5   # plain, forest, peak, wall, water

OUT_DIR  = os.path.join(os.path.dirname(__file__), "..", "assets", "tilesets")
OUT_FILE = os.path.join(OUT_DIR, "terrain_tiles.png")

os.makedirs(OUT_DIR, exist_ok=True)


def new_tile() -> Image.Image:
    return Image.new("RGBA", (TILE, TILE), P.TRANSPARENT)


def px(img: Image.Image, x: int, y: int, color: tuple) -> None:
    img.putpixel((x, y), color)


# ── Tile painters ──────────────────────────────────────────────────────────────

def draw_plain() -> Image.Image:
    img = new_tile()
    c = P.TERRAIN["plain"]
    # Fill base colour
    img.paste(c["base"], (0, 0, TILE, TILE))
    # Subtle checkerboard shading for ground texture
    for y in range(TILE):
        for x in range(TILE):
            if (x + y) % 4 == 0:
                img.putpixel((x, y), c["dark"])
            elif (x + y) % 6 == 0:
                img.putpixel((x, y), c["light"])
    # Scatter a few grass dots
    for pos in [(3,3),(7,1),(11,5),(5,9),(13,11),(2,13),(9,12),(14,6)]:
        px(img, pos[0], pos[1], c["dot"])
    return img


def draw_forest() -> Image.Image:
    img = new_tile()
    c = P.TERRAIN["forest"]
    # Ground base
    img.paste(c["ground"], (0, 0, TILE, TILE))
    # Large tree canopy (roughly centred)
    # Canopy — filled triangle-ish shape using pixel blocks
    canopy = [
        (6,1),(7,1),(8,1),
        (4,2),(5,2),(6,2),(7,2),(8,2),(9,2),(10,2),
        (3,3),(4,3),(5,3),(6,3),(7,3),(8,3),(9,3),(10,3),(11,3),
        (3,4),(4,4),(5,4),(6,4),(7,4),(8,4),(9,4),(10,4),(11,4),
        (4,5),(5,5),(6,5),(7,5),(8,5),(9,5),(10,5),
        (5,6),(6,6),(7,6),(8,6),(9,6),
    ]
    for x, y in canopy:
        img.putpixel((x, y), c["base"])
    # Highlights on canopy top-left
    for x, y in [(6,1),(7,1),(4,2),(5,2),(3,3),(4,3)]:
        img.putpixel((x, y), c["light"])
    # Dark shadow bottom-right of canopy
    for x, y in [(10,4),(11,4),(9,5),(10,5),(8,6),(9,6)]:
        img.putpixel((x, y), c["dark"])
    # Trunk
    for y in range(7, 13):
        img.putpixel((7, y), c["trunk"])
        img.putpixel((8, y), c["trunk"])
    # Roots at base
    for x, y in [(6,12),(9,12),(5,13),(10,13)]:
        img.putpixel((x, y), c["trunk"])
    return img


def draw_peak() -> Image.Image:
    img = new_tile()
    c = P.TERRAIN["peak"]
    # Base fill
    img.paste(c["base"], (0, 0, TILE, TILE))
    # Mountain silhouette: two peaks
    mountain = [
        # left peak
        (3,8),(4,7),(5,6),(6,5),(7,4),(7,3),
        (8,3),(8,4),(9,5),(10,6),(11,7),
        # right peak (smaller)
        (10,6),(11,5),(12,4),(13,5),(14,6),
    ]
    draw = ImageDraw.Draw(img)
    # Fill left mountain face (dark)
    for y in range(TILE):
        for x in range(TILE):
            if y > 8 - abs(x - 7) * 1 and x < 8:
                img.putpixel((x, y), c["dark"])
    # Fill right of mountain (mid)
    for y in range(TILE):
        for x in range(TILE):
            if y > 8 - abs(x - 7) * 1 and x >= 8:
                img.putpixel((x, y), c["mid"])
    # Snow caps
    for x, y in [(7,3),(8,3),(7,4),(8,4),(6,5),(9,5),(12,4),(13,5)]:
        if 0 <= x < TILE and 0 <= y < TILE:
            img.putpixel((x, y), c["light"])
    # Top-row sky fill stays base
    for x in range(TILE):
        for y in range(3):
            img.putpixel((x, y), c["base"])
    return img


def draw_wall() -> Image.Image:
    img = new_tile()
    c = P.TERRAIN["wall"]
    # Fill dark base
    img.paste(c["base"], (0, 0, TILE, TILE))
    # Brick pattern: 4×3 bricks with mortar lines
    # Horizontal mortar lines at y=4,8,12
    for x in range(TILE):
        for y in [4, 8, 12]:
            img.putpixel((x, y), c["mortar"])
    # Vertical mortar: alternating offset rows
    #  Row 0–3:  joints at x=8
    #  Row 5–7:  joints at x=4, x=12
    #  Row 9–11: joints at x=8
    #  Row 13–15: joints at x=4,12
    for y in range(TILE):
        if y in range(0, 4) or y in range(9, 12):
            for x in [8]:
                img.putpixel((x, y), c["mortar"])
        elif y in range(5, 8) or y in range(13, 16):
            for x in [4, 12]:
                img.putpixel((x, y), c["mortar"])
    # Highlight top-left edge of each brick
    for x in range(TILE):
        for y in range(TILE):
            if img.getpixel((x, y)) == c["base"]:
                # top edge of brick row
                if y > 0 and img.getpixel((x, y-1)) == c["mortar"]:
                    img.putpixel((x, y), c["light"])
    return img


def draw_water() -> Image.Image:
    img = new_tile()
    c = P.TERRAIN["water"]
    # Fill base
    img.paste(c["base"], (0, 0, TILE, TILE))
    # Horizontal wave lines — alternating dark/light
    wave_dark  = [1, 5, 9, 13]
    wave_light = [3, 7, 11, 15]
    for y in wave_dark:
        for x in range(0, TILE, 2):
            if x < TILE:
                img.putpixel((x, y), c["dark"])
    for y in wave_light:
        for x in range(1, TILE, 4):
            if x < TILE:
                img.putpixel((x, y), c["light"])
            if x+1 < TILE:
                img.putpixel((x+1, y), c["light"])
    # Foam dots scattered
    for pos in [(2,3),(6,7),(10,11),(14,15),(4,9),(12,1)]:
        if 0 <= pos[0] < TILE and 0 <= pos[1] < TILE:
            img.putpixel(pos, c["foam"])
    return img


# ── Assemble strip ─────────────────────────────────────────────────────────────

TILE_PAINTERS = [draw_plain, draw_forest, draw_peak, draw_wall, draw_water]
TILE_NAMES    = ["plain", "forest", "peak", "wall", "water"]

strip = Image.new("RGBA", (TILE * COUNT, TILE), P.TRANSPARENT)

for i, painter in enumerate(TILE_PAINTERS):
    tile_img = painter()
    strip.paste(tile_img, (i * TILE, 0))

strip.save(OUT_FILE)
print(f"Saved {COUNT} tiles → {OUT_FILE}")
print("Tile indices:  " + "  ".join(f"{i}={n}" for i, n in enumerate(TILE_NAMES)))
