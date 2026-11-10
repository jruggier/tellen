"""
gen_weapon_sprites.py — 8×8 weapon-type icon sprites for the in-battle overlay.

Each icon represents a weapon TYPE (not individual weapon), displayed as a
small sprite overlaid on the unit so the player can see what weapon is equipped
at a glance.  The sprite changes when the player cycles weapons with Q/R.

Output : ../assets/sprites/weapon_<type>.png
Types  : sword, lance, axe, bow, tome, staff, brawl, dagger

Usage:
    python3 tools/gen_weapon_sprites.py
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from PIL import Image

W, H = 8, 8
OUT  = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
os.makedirs(OUT, exist_ok=True)

T   = (0,   0,   0,   0)    # transparent
BK  = (15,  15,  25,  220)  # soft dark outline

# Colour palette
SV  = (215, 220, 230, 255)  # silver blade
SH  = (150, 155, 170, 255)  # silver shadow
GLD = (230, 195,  60, 255)  # gold orb / engrave
GLD2= (160, 130,  35, 255)  # gold shadow
BRN = (140,  95,  50, 255)  # wood / leather brown
BD  = ( 90,  60,  28, 255)  # brown shadow
ONG = (210, 135,  50, 255)  # axe head orange-metal
BLU = ( 85, 115, 230, 255)  # tome blue
BLD = ( 55,  75, 165, 255)  # tome shadow
PGE = (205, 215, 255, 255)  # page white-blue
SKN = (215, 175, 130, 255)  # skin knuckle
GRN = (100, 190,  80, 255)  # bow limb


def new_img() -> Image.Image:
    return Image.new("RGBA", (W, H), T)


def px(img: Image.Image, x: int, y: int, c: tuple) -> None:
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), c)


def outline(img: Image.Image) -> None:
    """Soft 1-px dark outline around all non-transparent pixels."""
    src = img.copy()
    for y in range(H):
        for x in range(W):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H:
                        if src.getpixel((nx, ny))[3] > 0:
                            img.putpixel((x, y), BK)
                            break


# ── Icon painters ──────────────────────────────────────────────────────────────

def weapon_sword() -> Image.Image:
    img = new_img()
    # Vertical blade, tip at top, crossguard at y=5, hilt below.
    for y in range(5):          # blade
        px(img, 3, y, SV)
    px(img, 3, 1, (235, 240, 250, 255))  # shine on blade
    for x in range(1, 6):      # crossguard
        px(img, x, 5, SH)
    px(img, 3, 5, SV)          # centre brightened
    px(img, 3, 6, BRN)         # hilt top
    px(img, 3, 7, BD)          # hilt bottom
    outline(img)
    return img


def weapon_lance() -> Image.Image:
    img = new_img()
    # Spear tip at top (triangular), shaft going down.
    px(img, 3, 0, SV)
    px(img, 2, 1, SV); px(img, 3, 1, SV); px(img, 4, 1, SV)
    px(img, 3, 2, SV)
    for y in range(3, 8):      # shaft
        px(img, 3, y, BRN)
    px(img, 3, 7, BD)
    # Shine on tip
    px(img, 2, 1, (235, 240, 250, 255))
    outline(img)
    return img


def weapon_axe() -> Image.Image:
    img = new_img()
    # Handle: x=4, y=2-7
    for y in range(2, 8):
        px(img, 4, y, BRN)
    px(img, 4, 7, BD)
    # Axe head (crescent on left side)
    for y in range(0, 5):
        px(img, 2, y, ONG)
        px(img, 3, y, ONG)
    px(img, 1, 1, ONG); px(img, 1, 2, ONG); px(img, 1, 3, ONG)
    px(img, 2, 0, (230, 165, 80, 255))   # top highlight
    px(img, 2, 4, (180, 110, 40, 255))   # bottom shadow
    # Blade edge shine
    px(img, 1, 2, (240, 175, 90, 255))
    outline(img)
    return img


def weapon_bow() -> Image.Image:
    img = new_img()
    # Left limb arc
    bow = [(1,0),(0,1),(0,2),(0,3),(0,4),(0,5),(0,6),(1,7)]
    for (x, y) in bow:
        px(img, x, y, GRN)
    px(img, 2, 0, GRN); px(img, 2, 7, GRN)
    # Grip (darker centre)
    px(img, 0, 3, BD); px(img, 0, 4, BD)
    # Bowstring (right side, thin)
    for y in range(1, 7):
        px(img, 5, y, SH)
    # Nocks
    px(img, 2, 1, GRN); px(img, 2, 6, GRN)
    outline(img)
    return img


def weapon_tome() -> Image.Image:
    img = new_img()
    # Book cover
    for y in range(1, 7):
        for x in range(1, 6):
            px(img, x, y, BLU)
    # Spine
    for y in range(1, 7):
        px(img, 1, y, BLD)
    # Pages
    for y in range(2, 6):
        for x in range(2, 5):
            px(img, x, y, PGE)
    # Magic glyph in centre (gold)
    px(img, 3, 3, GLD)
    px(img, 2, 3, GLD2); px(img, 4, 3, GLD2)
    px(img, 3, 2, GLD2); px(img, 3, 4, GLD2)
    outline(img)
    return img


def weapon_staff() -> Image.Image:
    img = new_img()
    # Shaft
    for y in range(3, 8):
        px(img, 3, y, BRN)
    px(img, 3, 7, BD)
    # Gold orb at top
    px(img, 3, 0, (250, 235, 110, 255))   # bright centre
    px(img, 2, 1, GLD); px(img, 3, 1, GLD); px(img, 4, 1, GLD)
    px(img, 3, 2, GLD)
    px(img, 2, 0, GLD2); px(img, 4, 0, GLD2)
    outline(img)
    return img


def weapon_brawl() -> Image.Image:
    img = new_img()
    # Fist / gauntlet
    for y in range(2, 6):
        for x in range(1, 6):
            px(img, x, y, BRN)
    # Knuckle row highlight
    for x in range(1, 6):
        px(img, x, 2, SKN)
    # Thumb (right side)
    px(img, 5, 2, SKN); px(img, 5, 3, SKN)
    # Wrist
    for x in range(2, 5):
        px(img, x, 6, BRN)
        px(img, x, 7, BD)
    # Metal plate highlight
    px(img, 2, 2, (240, 200, 160, 255))
    px(img, 4, 2, (240, 200, 160, 255))
    outline(img)
    return img


def weapon_dagger() -> Image.Image:
    img = new_img()
    # Short diagonal blade (top-right to bottom-left)
    px(img, 5, 0, SV); px(img, 4, 0, SV)
    px(img, 4, 1, SV); px(img, 3, 1, SV)
    px(img, 3, 2, SV); px(img, 2, 2, SV)
    # Shine
    px(img, 4, 0, (240, 245, 255, 255))
    # Guard
    px(img, 1, 3, SH); px(img, 2, 3, SH); px(img, 3, 3, SH)
    # Hilt
    px(img, 1, 4, BRN); px(img, 1, 5, BRN)
    px(img, 1, 6, BD)
    outline(img)
    return img


# ── Manifest ──────────────────────────────────────────────────────────────────

WEAPONS = {
    "sword":  weapon_sword,
    "lance":  weapon_lance,
    "axe":    weapon_axe,
    "bow":    weapon_bow,
    "tome":   weapon_tome,
    "staff":  weapon_staff,
    "brawl":  weapon_brawl,
    "dagger": weapon_dagger,
}


if __name__ == "__main__":
    print("Generating weapon sprites …")
    for name, fn in WEAPONS.items():
        path = os.path.join(OUT, f"weapon_{name}.png")
        fn().save(path)
        print(f"  {name:8s} → {path}")
    print(f"Done — {len(WEAPONS)} weapon sprites saved to assets/sprites/")
