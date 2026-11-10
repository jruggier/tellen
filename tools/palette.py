"""
palette.py — shared colour palette for all sprite generators.

Kept intentionally small: 4–5 shades per hue so the game reads cleanly
at 240×135 scaled to 960×540. All values are (R, G, B, A) tuples, 0–255.
"""

# ── Terrain colours ────────────────────────────────────────────────────────────

TERRAIN = {
    "plain": {
        "base":      (162, 191, 104, 255),   # soft sage green
        "dark":      (130, 158,  80, 255),   # shadow grass
        "light":     (195, 220, 135, 255),   # highlight
        "dot":       (110, 138,  65, 255),   # texture dot
    },
    "forest": {
        "base":      ( 74, 130,  72, 255),   # mid green
        "dark":      ( 45,  95,  50, 255),   # deep canopy
        "light":     (110, 165, 100, 255),   # leaf highlight
        "trunk":     ( 95,  65,  40, 255),   # tree trunk brown
        "ground":    (110, 155,  80, 255),   # forest floor
    },
    "peak": {
        "base":      (145, 135, 120, 255),   # warm grey stone
        "dark":      ( 95,  88,  78, 255),   # crevice shadow
        "light":     (195, 188, 175, 255),   # snow/highlight
        "mid":       (168, 158, 142, 255),   # mid rock face
    },
    "wall": {
        "base":      ( 60,  55,  65, 255),   # dark stone
        "dark":      ( 35,  32,  40, 255),   # deep shadow
        "light":     ( 90,  85,  95, 255),   # mortar highlight
        "mortar":    ( 45,  42,  52, 255),   # mortar line
    },
    "water": {
        "base":      ( 72, 140, 200, 255),   # mid blue
        "dark":      ( 45, 100, 165, 255),   # deep water
        "light":     (140, 195, 230, 255),   # specular highlight
        "foam":      (210, 235, 248, 255),   # white foam
    },
}

# ── Unit colours ───────────────────────────────────────────────────────────────

UNIT_PLAYER = {
    "body":     ( 68, 130, 210, 255),   # blue
    "dark":     ( 42,  88, 155, 255),
    "light":    (130, 185, 240, 255),
    "outline":  ( 20,  50, 110, 255),
    "skin":     (235, 200, 168, 255),
    "hair":     ( 80,  55,  30, 255),
}

UNIT_ENEMY = {
    "body":     (210,  68,  68, 255),   # red
    "dark":     (155,  40,  40, 255),
    "light":    (240, 130, 130, 255),
    "outline":  (110,  20,  20, 255),
    "skin":     (235, 200, 168, 255),
    "hair":     ( 50,  35,  20, 255),
}

# ── UI / shared ────────────────────────────────────────────────────────────────

TRANSPARENT = (0, 0, 0, 0)
WHITE        = (255, 255, 255, 255)
BLACK        = (  0,   0,   0, 255)
