"""
gen_unit_sprites_v2.py — regenerates player sprites with per-class palettes.

Each player class now has a distinct hair colour, skin tone, and body shade
so units are immediately readable at small sizes beyond silhouette alone.
Enemy palettes are unchanged (still uniform red).

Output : ../assets/sprites/_preview/<class_id>_player.png
         ../assets/sprites/_preview/_preview_sheet.png

Outputs go to _preview/ — originals in assets/sprites/ are NOT touched.
Review the preview sheet, then copy files over to replace the originals.

Usage:
    python3 tools/gen_unit_sprites_v2.py
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from PIL import Image
import palette as P

W, H   = 16, 24
OUT    = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "_preview")
os.makedirs(OUT, exist_ok=True)

TRANSPARENT = P.TRANSPARENT
BLACK       = P.BLACK


# ── Per-class player palettes ─────────────────────────────────────────────────
# All share "team blue" as the dominant body hue, but each has a unique
# hair colour and a slightly shifted body/skin to read differently at a glance.

CLASS_PALETTES: dict[str, dict] = {
    # Swordmaster — lord/hero. Platinum hair, warm skin, royal blue.
    "swordmaster": {
        "body":    ( 60, 120, 210, 255),
        "dark":    ( 35,  75, 155, 255),
        "light":   (210, 195, 100, 255),   # gold highlight (sword glint)
        "outline": ( 18,  45, 105, 255),
        "skin":    (240, 208, 175, 255),
        "hair":    (230, 225, 210, 255),   # platinum / silver-white
    },
    # Halberdier — soldier. Dark auburn hair, tanned skin, teal-blue armour.
    "halberdier": {
        "body":    ( 45, 148, 160, 255),   # teal-blue
        "dark":    ( 28,  98, 110, 255),
        "light":   (120, 210, 220, 255),
        "outline": ( 15,  55,  65, 255),
        "skin":    (210, 170, 130, 255),   # tanned
        "hair":    (140,  55,  30, 255),   # deep auburn
    },
    # Berserker — brawler. Vivid orange hair, dark tan, navy armour.
    "berserker": {
        "body":    ( 40,  80, 175, 255),   # deep navy
        "dark":    ( 22,  48, 118, 255),
        "light":   ( 95, 140, 220, 255),
        "outline": ( 12,  28,  80, 255),
        "skin":    (195, 150, 105, 255),   # dark tan
        "hair":    (230, 100,  20, 255),   # vivid orange
    },
    # Sage — mage. White-lavender hair, pale skin, violet-blue robe.
    "sage": {
        "body":    (110,  85, 195, 255),   # violet-blue
        "dark":    ( 70,  50, 145, 255),
        "light":   (195, 175, 240, 255),   # pale lavender
        "outline": ( 40,  25,  95, 255),
        "skin":    (245, 220, 200, 255),   # pale
        "hair":    (225, 215, 240, 255),   # white-lavender
    },
    # Paladin — knight. Dark brown hair, medium skin, royal blue + gold.
    "paladin": {
        "body":    ( 60, 110, 200, 255),   # royal blue
        "dark":    ( 35,  68, 148, 255),
        "light":   (215, 180,  55, 255),   # gold plate highlight
        "outline": ( 18,  38, 100, 255),
        "skin":    (225, 190, 155, 255),
        "hair":    ( 65,  38,  18, 255),   # very dark brown
    },
    # Lance Armor — heavy infantry. Grey hair, weathered skin, slate-steel armour.
    "lance_armor": {
        "body":    ( 85, 110, 148, 255),   # slate-steel blue
        "dark":    ( 52,  72, 105, 255),
        "light":   (185, 200, 218, 255),   # silver
        "outline": ( 28,  40,  65, 255),
        "skin":    (200, 172, 145, 255),   # weathered
        "hair":    (165, 165, 165, 255),   # iron grey
    },
    # Griffin Knight — flier. Warm blonde hair, light skin, sky-blue armour.
    "griffin_knight": {
        "body":    ( 68, 165, 225, 255),   # sky blue
        "dark":    ( 40, 115, 175, 255),
        "light":   (240, 235, 210, 255),   # cream / feather white
        "outline": ( 20,  70, 120, 255),
        "skin":    (242, 212, 178, 255),   # light
        "hair":    (215, 185,  80, 255),   # warm blonde
    },
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def new_sprite() -> Image.Image:
    return Image.new("RGBA", (W, H), TRANSPARENT)


def px(img, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), color)


def row(img, y, x_start, x_end, color):
    for x in range(x_start, x_end + 1):
        px(img, x, y, color)


def col(img, x, y_start, y_end, color):
    for y in range(y_start, y_end + 1):
        px(img, x, y, color)


def _outline(img: Image.Image, color: tuple) -> None:
    src = img.copy()
    for y in range(H):
        for x in range(W):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in [(-1,0),(1,0),(0,-1),(0,1)]:
                    nx, ny = x+dx, y+dy
                    if 0 <= nx < W and 0 <= ny < H:
                        if src.getpixel((nx, ny))[3] > 0:
                            img.putpixel((x, y), color)
                            break


# ── Generic body builder ──────────────────────────────────────────────────────

def draw_base(c: dict, head_w=4, torso_w=6, leg_w=4) -> Image.Image:
    img = new_sprite()

    hx = (W - head_w) // 2
    for y in range(4, 8):
        row(img, y, hx, hx + head_w - 1, c["skin"])
    for y in range(4, 6):
        row(img, y, hx, hx + head_w - 1, c["hair"])
    px(img, hx + 1, 6, BLACK)
    px(img, hx + head_w - 2, 6, BLACK)

    col(img, W//2 - 1, 8, 9, c["skin"])
    col(img, W//2,     8, 9, c["skin"])

    tx = (W - torso_w) // 2
    for y in range(10, 17):
        row(img, y, tx, tx + torso_w - 1, c["body"])
    for y in range(10, 17):
        px(img, tx, y, c["light"])
    for y in range(10, 17):
        px(img, tx + torso_w - 1, y, c["dark"])

    col(img, tx - 1, 10, 15, c["body"])
    col(img, tx + torso_w, 10, 15, c["body"])

    lx = (W - leg_w) // 2
    for y in range(17, 23):
        row(img, y, lx, lx + leg_w//2 - 1, c["body"])
        row(img, y, lx + leg_w//2 + 1, lx + leg_w - 1, c["body"])
    for y in range(21, 24):
        row(img, y, lx, lx + leg_w//2 - 1, c["dark"])
        row(img, y, lx + leg_w//2 + 1, lx + leg_w - 1, c["dark"])

    _outline(img, c["outline"])
    return img


# ── Class painters ────────────────────────────────────────────────────────────

def swordmaster(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=5, leg_w=4)
    # Slim sword — gold/light hilt, bright blade
    s = c["light"]
    col(img, 11, 12, 22, s)
    px(img, 12, 12, s)
    px(img, 11, 11, s)
    # Crossguard highlight (swordmaster distinction: gold crossguard)
    px(img, 10, 14, c["light"])
    px(img, 12, 14, c["light"])
    px(img, 10, 23, c["dark"])
    px(img, 11, 23, c["dark"])
    # Scarf / collar accent (distinctive lord detail)
    row(img, 9, 6, 9, c["light"])
    return img


def halberdier(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=6, leg_w=4)
    h = c["light"]
    for i in range(9):
        px(img, 3+i, 4+i, h)
    px(img, 2, 3, h)
    px(img, 3, 3, h)
    # Larger spear tip — two-pixel wide for readability
    px(img, 1, 2, h)
    px(img, 2, 2, h)
    px(img, 12, 13, c["dark"])
    # Belt stripe (distinctive colour band)
    row(img, 16, 5, 10, c["dark"])
    return img


def berserker(c: dict) -> Image.Image:
    img = draw_base(c, head_w=5, torso_w=8, leg_w=5)
    a = c["light"]
    col(img, 13, 6, 16, c["dark"])
    for y in [5,6,7]:
        row(img, y, 12, 15, a)
    px(img, 11, 6, a)
    px(img, 15, 5, a)
    # Wild hair — more pronounced spikes on the big head
    for x in [4,5,6,7,8,9,10]:
        px(img, x, 4, c["hair"])
    px(img, 4, 5, c["hair"])   # sideburn
    px(img, 10, 5, c["hair"])
    # Bare arms — skin tone showing (warrior detail)
    col(img, 3, 11, 14, c["skin"])
    col(img, 12, 11, 14, c["skin"])
    return img


def sage(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=5, leg_w=3)
    robe = c["body"]
    for y in range(17, 24):
        width = 3 + (y - 17) // 2
        x0 = (W - width) // 2
        row(img, y, x0, x0 + width - 1, robe)
    # Robe hem highlight (lavender trim)
    for y in range(22, 24):
        width = 3 + (y - 17) // 2
        x0 = (W - width) // 2
        px(img, x0, y, c["light"])
        px(img, x0 + width - 1, y, c["light"])
    # Tome
    t = c["light"]
    for y in range(12, 16):
        row(img, y, 2, 4, t)
    px(img, 3, 11, t)
    # Staff (taller, with orb at top)
    col(img, 7, 0, 3, c["light"])
    px(img, 6, 1, c["light"])
    px(img, 8, 1, c["light"])
    px(img, 6, 0, c["light"])   # orb wider at top
    px(img, 8, 0, c["light"])
    # Hood suggestion — extra hair row covering forehead more
    row(img, 4, 6, 9, c["hair"])
    row(img, 3, 6, 9, c["hair"])   # hood above head
    return img


def paladin(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=7, leg_w=6)
    for y in range(15, 24):
        row(img, y, 3, 12, c["body"])
    for y in range(15, 24):
        px(img, 3, y, c["light"])
        px(img, 12, y, c["dark"])
    # Lance — gold tip for paladin distinction
    col(img, 13, 5, 20, c["body"])
    px(img, 13, 4, c["light"])   # gold tip
    px(img, 14, 4, c["light"])
    px(img, 14, 5, c["light"])
    # Gold chest plate stripe
    row(img, 11, 5, 11, c["light"])
    row(img, 12, 5, 11, c["light"])
    return img


def lance_armor(c: dict) -> Image.Image:
    img = draw_base(c, head_w=5, torso_w=9, leg_w=6)
    for y in range(10, 18):
        row(img, y, 3, 12, c["body"])
        px(img, 3, y, c["light"])
        px(img, 12, y, c["dark"])
    # Pauldrons
    for y in range(9, 13):
        px(img, 2, y, c["light"])
        px(img, 13, y, c["body"])
    # Full visor (closes more of the face — distinctive armour look)
    for x in range(5, 11):
        px(img, x, 5, c["dark"])
    for x in range(6, 10):
        px(img, x, 6, c["dark"])
    # Silver chest cross
    col(img, 7, 10, 17, c["light"])
    row(img, 13, 3, 12, c["light"])
    # Lance — silver
    col(img, 14, 5, 22, c["light"])
    px(img, 15, 4, c["light"])
    px(img, 13, 4, c["light"])
    return img


def griffin_knight(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=6, leg_w=4)
    wing = c["light"]   # cream/feather-white wings
    # Wider wing spread — more feather detail
    for y in [10,11,12,13,14]:
        px(img, 1, y, wing)
        px(img, 14, y, wing)
    px(img, 0, 11, wing)
    px(img, 0, 12, wing)
    px(img, 15, 11, wing)
    px(img, 15, 12, wing)
    # Feather barbs suggestion
    px(img, 0, 10, c["body"])
    px(img, 15, 10, c["body"])
    px(img, 1, 9, c["body"])
    px(img, 14, 9, c["body"])
    # Tall helmet crest — two columns, more visible
    col(img, 6, 0, 3, c["light"])
    col(img, 7, 0, 3, c["light"])
    col(img, 8, 1, 4, c["light"])
    # Scarf/cape trailing — sky blue detail
    for y in range(14, 18):
        px(img, 2, y, c["body"])
        px(img, 13, y, c["body"])
    return img


# ── Manifest ──────────────────────────────────────────────────────────────────

PLAYER_CLASSES = [
    ("swordmaster",    swordmaster),
    ("halberdier",     halberdier),
    ("berserker",      berserker),
    ("sage",           sage),
    ("paladin",        paladin),
    ("lance_armor",    lance_armor),
    ("griffin_knight", griffin_knight),
]


if __name__ == "__main__":
    generated = []
    for class_id, painter in PLAYER_CLASSES:
        c = CLASS_PALETTES[class_id]
        img = painter(c)
        path = os.path.join(OUT, f"{class_id}_player.png")
        img.save(path)
        generated.append((class_id, path))
        print(f"  {class_id:20s} → {path}")

    print(f"\nGenerated {len(generated)} player sprites → assets/sprites/_preview/")

    # Preview sheet — all new player sprites in a single row
    n = len(PLAYER_CLASSES)
    sheet = Image.new("RGBA", (W * n, H), TRANSPARENT)
    for i, (class_id, painter) in enumerate(PLAYER_CLASSES):
        c = CLASS_PALETTES[class_id]
        sheet.paste(painter(c), (i * W, 0))

    sheet_path = os.path.join(OUT, "_preview_sheet_v2.png")
    sheet.save(sheet_path)
    print(f"Preview sheet → {sheet_path}")
    print("\nClass order (left to right):")
    for i, (cid, _) in enumerate(PLAYER_CLASSES):
        print(f"  {i}: {cid}")
