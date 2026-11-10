"""
gen_cutscene_bg.py — 320×180 pixel-art background for the Map 01 opening cutscene.

Scene: a grassy plain at afternoon — rolling hills, distant mountains,
a small village in the background, a dirt road winding toward it,
tree clusters flanking the path.

Output: ../assets/cutscenes/map_01_bg.png

Usage:
    python3 tools/gen_cutscene_bg.py
"""

import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image

W, H = 320, 180
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "cutscenes")
os.makedirs(OUT_DIR, exist_ok=True)
OUT = os.path.join(OUT_DIR, "map_01_bg.png")

_img = Image.new("RGBA", (W, H), (0, 0, 0, 255))

def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        _img.putpixel((x, y), c if len(c) == 4 else c + (255,))

def hrow(y, x0, x1, c):
    for x in range(x0, x1 + 1): put(x, y, c)

def vcol(x, y0, y1, c):
    for y in range(y0, y1 + 1): put(x, y, c)

def block(x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1): hrow(y, x0, x1, c)

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


# ── Palette ───────────────────────────────────────────────────────────────────
SKY_TOP  = (108, 158, 210)
SKY_HRZ  = (185, 215, 238)
CLOUD    = (238, 244, 252)
CLOUD_S  = (205, 220, 238)
MTN      = (112, 108, 142)
MTN_L    = (145, 140, 168)
MTN_SNOW = (222, 222, 235)
HILL_F   = (82,  132, 78)
HILL_M   = (105, 158, 92)
GRASS    = (128, 175, 92)
GRASS_D  = (95,  138, 65)
GRASS_H  = (155, 200, 108)
DIRT     = (168, 140, 98)
DIRT_D   = (135, 108, 72)
VIL_W    = (195, 178, 148)
VIL_S    = (152, 135, 108)
VIL_R    = (145, 85,  58)
VIL_RS   = (105, 58,  38)
VIL_DK   = (62,  48,  35)
TRUNK    = (85,  58,  28)
CANOPY   = (68,  120, 65)
CAN_H    = (95,  150, 85)
CAN_D    = (45,  88,  42)


# ── Sky gradient ──────────────────────────────────────────────────────────────
for y in range(72):
    t = y / 72.0
    hrow(y, 0, W - 1, lerp(SKY_TOP, SKY_HRZ, t))


# ── Clouds ────────────────────────────────────────────────────────────────────
def cloud_puff(cx, cy, rx, ry):
    for dy in range(-ry, ry // 2 + 1):
        for dx in range(-rx, rx + 1):
            if (dx / rx) ** 2 + (dy / ry) ** 2 < 1.0:
                c = CLOUD if dy < ry // 4 else CLOUD_S
                put(cx + dx, cy + dy, c)

# Cloud left
cloud_puff(85,  15, 14, 8)
cloud_puff(100, 13, 16, 9)
cloud_puff(118, 16, 12, 7)

# Cloud right
cloud_puff(232, 20, 12, 7)
cloud_puff(248, 18, 14, 8)
cloud_puff(263, 21, 11, 6)


# ── Mountains ─────────────────────────────────────────────────────────────────
# Three peaks; for each pixel, find if it's below the mountain outline.
PEAKS = [(75, 44, 0.88), (148, 40, 0.82), (205, 46, 0.90)]

def mtn_threshold(x):
    """Y value of mountain outline at x (lower = taller)."""
    return min(pk_y + abs(x - pk_x) * sp for pk_x, pk_y, sp in PEAKS)

for y in range(38, 78):
    for x in range(W):
        thresh = mtn_threshold(x)
        if y > thresh:
            nearest = min(PEAKS, key=lambda p: abs(x - p[0]))
            shade = MTN if x < nearest[0] else MTN_L
            put(x, y, shade)

# Snow caps
for pk_x, pk_y, sp in PEAKS:
    for dy in range(10):
        hw = max(0, 5 - dy)
        for dx in range(-hw, hw + 1):
            if mtn_threshold(pk_x + dx) >= pk_y + dy:
                put(pk_x + dx, pk_y + dy, MTN_SNOW)


# ── Far hills (rolling, sine-based) ──────────────────────────────────────────
for y in range(65, 95):
    for x in range(W):
        hill_y = 74 + int(7 * math.sin(x * 0.022 + 0.8)) \
                    + int(3 * math.sin(x * 0.058 + 2.1))
        if y > hill_y:
            t = min(1.0, (y - hill_y) / 18.0)
            put(x, y, lerp(HILL_F, HILL_M, t))


# ── Mid-ground grass ──────────────────────────────────────────────────────────
block(0, 90, W - 1, H - 1, GRASS)
# Subtle stripe texture
for y in range(90, H):
    for x in range(W):
        if (x * 3 + y) % 9 == 0:
            put(x, y, GRASS_D)
        elif (x + y * 2) % 15 == 0:
            put(x, y, GRASS_H)


# ── Village buildings (x≈165..240, y≈92..115) ────────────────────────────────
def building(x0, y0, bw, bh, rh):
    """Draw a building: wall + peaked roof + door + window."""
    # Wall
    block(x0, y0 + rh, x0 + bw - 1, y0 + bh - 1, VIL_W)
    vcol(x0 + bw - 1, y0 + rh, y0 + bh - 1, VIL_S)   # right shadow
    # Roof (triangle, filled row by row)
    mid = x0 + bw // 2
    for ri in range(rh):
        t = ri / rh
        hw = int(bw // 2 * t)
        hrow(y0 + ri, mid - hw, mid + hw, VIL_R)
        put(mid - hw, y0 + ri, VIL_RS)
        put(mid + hw, y0 + ri, VIL_RS)
    # Door
    dx = x0 + bw // 2 - 1
    block(dx, y0 + bh - 6, dx + 2, y0 + bh - 1, VIL_DK)
    # Window (left of door)
    block(x0 + 2, y0 + rh + 3, x0 + 5, y0 + rh + 6, VIL_DK)

building(165, 93, 24, 22, 9)    # main house
building(193, 97, 18, 18, 7)    # smaller house
building(215, 94, 22, 21, 8)    # third house

# Chimney on main house
vcol(170, 87, 95, VIL_S)
vcol(171, 87, 95, VIL_W)


# ── Dirt road ─────────────────────────────────────────────────────────────────
# Starts wide at bottom (center ~x=130), curves toward village (cx~192, y~115)
ROAD_TOP_Y  = 110
ROAD_TOP_CX = 192
ROAD_TOP_HW = 6
ROAD_BOT_CX = 118
ROAD_BOT_HW = 38

for y in range(ROAD_TOP_Y, H):
    t = (y - ROAD_TOP_Y) / (H - ROAD_TOP_Y)   # 0 at village, 1 at bottom
    cx = int(ROAD_TOP_CX + (ROAD_BOT_CX - ROAD_TOP_CX) * t)
    hw = int(ROAD_TOP_HW + (ROAD_BOT_HW - ROAD_TOP_HW) * t)
    hrow(y, cx - hw, cx + hw, DIRT)
    put(cx - hw, y, DIRT_D)
    put(cx + hw, y, DIRT_D)
    # Wheel ruts
    if (y % 5) < 2:
        put(cx - hw // 3, y, DIRT_D)
        put(cx + hw // 3, y, DIRT_D)


# ── Foreground dark grass band ────────────────────────────────────────────────
for y in range(148, H):
    hrow(y, 0, W - 1, GRASS_D)
for y in range(148, H):
    for x in range(0, W, 5):
        if (x * 2 + y * 3) % 13 == 0:
            put(x,     y, GRASS)
            put(x + 1, y, GRASS)


# ── Trees ─────────────────────────────────────────────────────────────────────
def tree(cx, base_y, height=26, crown_r=13):
    trunk_top = base_y - height // 3
    vcol(cx,     trunk_top, base_y, TRUNK)
    vcol(cx + 1, trunk_top, base_y, TRUNK)
    # Three layers of canopy, staggered
    for layer in range(3):
        cy = trunk_top - layer * (height // 5)
        r  = max(4, crown_r - layer * 3)
        for dy in range(-r, r // 3 + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy < r * r * 0.92:
                    shade = CAN_H if (dy < -r // 3 and abs(dx) < r * 0.55) \
                            else (CAN_D if dy >= 0 or abs(dx) > r * 0.72 \
                            else CANOPY)
                    put(cx + dx, cy + dy, shade)

# Left grove
tree(18,  122, 30, 14)
tree(36,  118, 26, 12)
tree(8,   132, 22, 11)
tree(52,  120, 22, 11)
tree(62,  128, 18, 9)

# Right grove
tree(285, 120, 28, 13)
tree(302, 126, 24, 12)
tree(272, 127, 20, 10)
tree(308, 118, 18, 9)

_img.save(OUT)
print(f"Saved → {OUT}  ({W}×{H})")
