"""
gen_unit_sprites.py — generates 16×24 unit sprites for every class in v0.1.

Output : ../assets/sprites/<class_id>_player.png   (blue team)
         ../assets/sprites/<class_id>_enemy.png    (red team)
Layout : Single idle frame, 16×24 px, RGBA with transparent background.
         Units are 16 wide × 24 tall — they sit 8px above their tile, which
         gives them visible heads when standing on 16×16 terrain.

Each class has a distinct silhouette so they're readable at 240×135:
  swordmaster   — slim, tall sword at side
  halberdier    — medium build, lance diagonal
  berserker     — wide, heavy, big axe over shoulder
  sage          — slight build, tome held forward, flowing robe
  paladin       — wide torso (horse implied by lower body)
  lance_armor   — blocky, wide, armour plating
  griffin_knight — compact, wing tips at sides
  (enemies share shapes with slight variation)

Re-run this script to regenerate all sprites.

Usage:
    python3 tools/gen_unit_sprites.py
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from PIL import Image
import palette as P

W, H   = 16, 24
OUT    = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
os.makedirs(OUT, exist_ok=True)


def new_sprite() -> Image.Image:
    return Image.new("RGBA", (W, H), P.TRANSPARENT)


def px(img, x, y, color):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), color)


def row(img, y, x_start, x_end, color):
    for x in range(x_start, x_end + 1):
        px(img, x, y, color)


def col(img, x, y_start, y_end, color):
    for y in range(y_start, y_end + 1):
        px(img, x, y, color)


# ── Generic body builder ───────────────────────────────────────────────────────
# All units share: head (4×4), neck (2px), torso, legs.
# Class-specific detail is layered on top.

def draw_base(c: dict, head_w=4, torso_w=6, leg_w=4) -> Image.Image:
    """Draw a basic humanoid silhouette using palette dict c."""
    img = new_sprite()

    # Head: centred, 4×4
    hx = (W - head_w) // 2
    for y in range(4, 8):
        row(img, y, hx, hx + head_w - 1, c["skin"])
    # Hair (top 2 rows of head)
    for y in range(4, 6):
        row(img, y, hx, hx + head_w - 1, c["hair"])
    # Eye dots
    px(img, hx + 1, 6, P.BLACK)
    px(img, hx + head_w - 2, 6, P.BLACK)

    # Neck
    col(img, W//2 - 1, 8, 9, c["skin"])
    col(img, W//2,     8, 9, c["skin"])

    # Torso
    tx = (W - torso_w) // 2
    for y in range(10, 17):
        row(img, y, tx, tx + torso_w - 1, c["body"])
    # Torso highlight (left column)
    for y in range(10, 17):
        px(img, tx, y, c["light"])
    # Torso shadow (right column)
    for y in range(10, 17):
        px(img, tx + torso_w - 1, y, c["dark"])

    # Arms (hang outside torso)
    col(img, tx - 1, 10, 15, c["body"])
    col(img, tx + torso_w, 10, 15, c["body"])

    # Legs
    lx = (W - leg_w) // 2
    for y in range(17, 23):
        row(img, y, lx, lx + leg_w//2 - 1, c["body"])        # left leg
        row(img, y, lx + leg_w//2 + 1, lx + leg_w - 1, c["body"])  # right leg
    # Boots (darker at foot)
    for y in range(21, 24):
        row(img, y, lx, lx + leg_w//2 - 1, c["dark"])
        row(img, y, lx + leg_w//2 + 1, lx + leg_w - 1, c["dark"])

    # Outline pass — dark border around all opaque pixels
    _outline(img, c["outline"])

    return img


def _outline(img: Image.Image, color: tuple) -> None:
    """1-px dark outline around all non-transparent pixels."""
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


# ── Class-specific overpaints ──────────────────────────────────────────────────

def swordmaster(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=5, leg_w=4)
    # Slim sword at right hip (x=11–12, y=12–22)
    s = c["light"]
    col(img, 11, 12, 22, s)
    px(img, 12, 12, s)
    px(img, 11, 11, s)     # tip
    px(img, 10, 23, c["dark"])  # hilt
    px(img, 11, 23, c["dark"])
    return img


def halberdier(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=6, leg_w=4)
    # Lance diagonally across the body
    h = c["light"]
    for i in range(9):
        px(img, 3+i, 4+i, h)     # shaft diagonal
    # Spear tip
    px(img, 2, 3, h)
    px(img, 3, 3, h)
    # Butt end lower-right
    px(img, 12, 13, c["dark"])
    return img


def berserker(c: dict) -> Image.Image:
    img = draw_base(c, head_w=5, torso_w=8, leg_w=5)
    # Wide axe above right shoulder
    a = c["light"]
    # Handle
    col(img, 13, 6, 16, c["dark"])
    # Axe head
    for y in [5,6,7]:
        row(img, y, 12, 15, a)
    px(img, 11, 6, a)
    px(img, 15, 5, a)
    # Spiked beard / wild hair
    for x in [5,6,7,8,9,10]:
        px(img, x, 4, c["hair"])
    return img


def sage(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=5, leg_w=3)
    # Flowing robe extension below torso
    robe = c["body"]
    for y in range(17, 24):
        width = 3 + (y - 17) // 2
        x0 = (W - width) // 2
        row(img, y, x0, x0 + width - 1, robe)
    # Tome held in left hand
    t = c["light"]
    for y in range(12, 16):
        row(img, y, 2, 4, t)
    px(img, 3, 11, t)  # page
    # Staff tip above head
    col(img, 7, 0, 3, c["light"])
    px(img, 6, 1, c["light"])
    px(img, 8, 1, c["light"])
    return img


def paladin(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=7, leg_w=6)
    # Wider lower body (horse suggested by bulk)
    for y in range(15, 24):
        row(img, y, 3, 12, c["body"])
    for y in range(15, 24):
        px(img, 3, y, c["light"])
        px(img, 12, y, c["dark"])
    # Lance at side
    col(img, 13, 5, 20, c["light"])
    px(img, 14, 5, c["light"])  # tip
    return img


def lance_armor(c: dict) -> Image.Image:
    img = draw_base(c, head_w=5, torso_w=9, leg_w=6)
    # Heavy armour plates over torso — extra layer
    for y in range(10, 18):
        row(img, y, 3, 12, c["body"])
        px(img, 3, y, c["light"])
        px(img, 12, y, c["dark"])
    # Pauldrons (shoulder armour)
    for y in range(9, 13):
        px(img, 2, y, c["light"])
        px(img, 13, y, c["body"])
    # Visor on helmet
    for x in range(6, 10):
        px(img, x, 6, c["dark"])
    # Lance
    col(img, 14, 5, 22, c["light"])
    px(img, 15, 4, c["light"])
    return img


def griffin_knight(c: dict) -> Image.Image:
    img = draw_base(c, head_w=4, torso_w=6, leg_w=4)
    # Wing tips on both sides (suggest griffin)
    wing = c["light"]
    for y in [11,12,13]:
        px(img, 1, y, wing)
        px(img, 14, y, wing)
    px(img, 0, 12, wing)
    px(img, 15, 12, wing)
    px(img, 1, 10, wing)
    px(img, 14, 10, wing)
    # Feather tips (slightly lighter)
    for y in [10,11]:
        px(img, 0, y, c["body"])
        px(img, 15, y, c["body"])
    # Helmet crest
    col(img, 7, 1, 4, c["light"])
    col(img, 8, 2, 4, c["light"])
    return img


# Generic enemies (same shapes, just different palette)
def enemy_soldier(c):   return halberdier(c)
def enemy_fighter(c):   return berserker(c)
def enemy_myrmidon(c):  return swordmaster(c)
def enemy_mage(c):      return sage(c)
def enemy_armor(c):     return lance_armor(c)


def enemy_wyvern(c: dict) -> Image.Image:
    """Wyvern rider — large bat-like wings dominate; small rider on top; dragon body/legs below."""
    img = new_sprite()
    D, Bo, L = c["dark"], c["body"], c["light"]

    # Rider: small head + torso, centered high on the sprite
    for y in range(1, 5):
        row(img, y, 6, 9, c["skin"])
    row(img, 1, 6, 9, c["hair"])
    row(img, 2, 6, 9, c["hair"])
    px(img, 7, 3, P.BLACK)   # eyes
    px(img, 9, 3, P.BLACK)
    for y in range(5, 8):
        row(img, y, 6, 9, Bo)   # rider body

    # Wyvern neck / saddle beneath the rider
    for y in range(6, 9):
        row(img, y, 5, 10, D)

    # Wings: light membrane, symmetric, taper from full width downward
    # Each entry is (left_edge_x, right_edge_x) at that row
    wing_spans = [
        (0, 15), (0, 15), (0, 15),  # y=8,9,10  — full spread
        (1, 14), (2, 13), (3, 12),  # y=11,12,13 — tapering
        (4, 11),                     # y=14       — nearly folded
    ]
    for i, (lx, rx) in enumerate(wing_spans):
        y = 8 + i
        for x in range(lx, 5):         # left membrane (lx to 4)
            px(img, x, y, L)
        for x in range(11, rx + 1):    # right membrane (11 to rx)
            px(img, x, y, L)

    # Wyvern body: dark centre column
    for y in range(8, 20):
        row(img, y, 5, 10, D)
    # Belly highlight
    for y in range(11, 19):
        row(img, y, 6, 9, Bo)

    # Dragon legs: two columns outside the body, y=18..21
    for y in range(18, 22):
        px(img, 3, y, D)
        px(img, 4, y, D)
        px(img, 11, y, D)
        px(img, 12, y, D)

    # Claws spread below legs
    row(img, 21, 1, 4, D)
    row(img, 22, 1, 3, D)
    row(img, 21, 11, 14, D)
    row(img, 22, 12, 14, D)

    # Tail: tapers from body base, shifts slightly
    row(img, 20, 5, 10, D)
    row(img, 21, 5,  9, D)
    row(img, 22, 5,  8, D)
    row(img, 23, 5,  7, D)

    _outline(img, c["outline"])
    return img


# ── Manifest ───────────────────────────────────────────────────────────────────

CLASSES = {
    "swordmaster":    swordmaster,
    "halberdier":     halberdier,
    "berserker":      berserker,
    "sage":           sage,
    "paladin":        paladin,
    "lance_armor":    lance_armor,
    "griffin_knight": griffin_knight,
    "enemy_soldier":  enemy_soldier,
    "enemy_fighter":  enemy_fighter,
    "enemy_myrmidon": enemy_myrmidon,
    "enemy_mage":     enemy_mage,
    "enemy_armor":    enemy_armor,
    "enemy_wyvern":   enemy_wyvern,
}

ENEMY_CLASSES = {
    "enemy_soldier", "enemy_fighter", "enemy_myrmidon",
    "enemy_mage", "enemy_armor", "enemy_wyvern",
}


if __name__ == "__main__":
    generated = []
    for class_id, painter in CLASSES.items():
        # Player version (blue palette, even for enemy classes — used in editor preview)
        img_p = painter(P.UNIT_PLAYER)
        path_p = os.path.join(OUT, f"{class_id}_player.png")
        img_p.save(path_p)

        # Enemy version (red palette)
        img_e = painter(P.UNIT_ENEMY)
        path_e = os.path.join(OUT, f"{class_id}_enemy.png")
        img_e.save(path_e)

        generated.append(class_id)

    print(f"Generated {len(generated) * 2} sprites ({len(generated)} classes × 2 palettes)")
    print("Saved to: assets/sprites/")

    # Also write a preview sheet — all player sprites in a row, then enemies below
    n = len(CLASSES)
    sheet = Image.new("RGBA", (W * n, H * 2), P.TRANSPARENT)
    for i, (cid, painter) in enumerate(CLASSES.items()):
        sheet.paste(painter(P.UNIT_PLAYER), (i * W, 0))
        sheet.paste(painter(P.UNIT_ENEMY),  (i * W, H))
    preview_path = os.path.join(OUT, "_preview_sheet.png")
    sheet.save(preview_path)
    print(f"Preview sheet → {preview_path}")
