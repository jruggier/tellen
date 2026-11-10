"""
gen_sprites_hd.py — 2× resolution sprites for all game assets.

Units   : 32×48  (was 16×24) — 2-px eyes, shading, forearm skin, class weapons
Weapons : 16×16  (was 8×8)   — 2-px strokes, grip/blade detail
Terrain : 32×32  (was 16×16) — richer texture fills

Output  : assets/sprites/_preview/hd/   ← originals NOT touched
Preview : assets/sprites/_preview/hd/_preview_sheet_hd.png (4× nearest-neighbour)

Usage:
    python3 tools/gen_sprites_hd.py
"""

import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import palette as P

UW, UH = 32, 48
WW, WH = 16, 16
TW, TH = 32, 32
SCALE  = 4

PREV = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "_preview", "hd")
os.makedirs(PREV, exist_ok=True)

TR   = (0, 0, 0, 0)
BK   = (15, 15, 25, 220)
SIL  = (215, 220, 232, 255)   # silver
SIL2 = (148, 155, 172, 255)   # silver shadow
GLD  = (228, 190, 55,  255)   # gold
GLD2 = (155, 128, 32,  255)   # gold shadow
WD   = (132, 88,  42,  255)   # wood brown
WD2  = (82,  52,  22,  255)   # wood shadow
LIPS = (175, 110, 95,  255)
NOSE = (210, 170, 140, 255)   # slightly darker skin for nose dot


# ── Per-class palettes ────────────────────────────────────────────────────────

def _pal(base, hair, hair2, eye, acc):
    return {**base, "hair": hair, "hair2": hair2, "eye": eye, "acc": acc}

_B = P.UNIT_PLAYER
_E = P.UNIT_ENEMY

CPAL = {
    "swordmaster":    _pal(_B, (220,215,195,255), (158,153,132,255), (100,170,230,255), (228,190,55,255)),
    "halberdier":     _pal(_B, (100,60,20,255),   (62,36,10,255),    (78,140,58,255),   (185,185,195,255)),
    "berserker":      _pal(_B, (55,32,12,255),     (28,15,5,255),     (200,80,48,255),   (118,82,32,255)),
    "sage":           _pal(_B, (200,160,78,255),   (145,108,42,255),  (130,78,180,255),  (168,118,205,255)),
    "paladin":        _pal(_B, (200,180,120,255),  (145,128,78,255),  (68,118,78,255),   (225,185,52,255)),
    "lance_armor":    _pal(_B, (48,48,52,255),     (26,26,30,255),    (172,182,198,255), (195,195,205,255)),
    "griffin_knight": _pal(_B, (175,72,72,255),    (118,42,42,255),   (220,158,48,255),  (212,228,242,255)),
}
EPAL = _pal(_E, (50,35,20,255), (26,16,6,255), (200,58,58,255), (142,32,32,255))


# ── Draw helpers ──────────────────────────────────────────────────────────────

def _new(w, h): return Image.new("RGBA", (w, h), TR)
def _px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height: img.putpixel((x,y), c)
def _row(img, y, x0, x1, c):
    for x in range(x0, x1+1): _px(img, x, y, c)
def _col(img, x, y0, y1, c):
    for y in range(y0, y1+1): _px(img, x, y, c)
def _rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1+1): _row(img, y, x0, x1, c)
def _outline(img, color=BK):
    src = img.copy(); W, H = img.width, img.height
    for y in range(H):
        for x in range(W):
            if src.getpixel((x,y))[3] == 0:
                for dx,dy in ((-1,0),(1,0),(0,-1),(0,1)):
                    nx,ny = x+dx, y+dy
                    if 0<=nx<W and 0<=ny<H and src.getpixel((nx,ny))[3]>0:
                        img.putpixel((x,y), color); break
def _nn(img, s): return img.resize((img.width*s, img.height*s), Image.NEAREST)


# ── Unit base (NO outline — caller adds it after class details) ───────────────

def draw_base_hd(c, head_w=8, torso_w=10, leg_w=8):
    img = _new(UW, UH)
    hx = (UW - head_w) // 2
    tx = (UW - torso_w) // 2
    lx = (UW - leg_w)   // 2
    half = leg_w // 2
    eye  = c.get("eye",   (100,150,200,255))
    hair = c.get("hair",  c["body"])
    hr2  = c.get("hair2", c["dark"])

    # ── Hair (y=4..7)
    _rect(img, hx, 4, hx+head_w-1, 7, hair)
    for y in range(4, 8):
        _px(img, hx, y, hr2); _px(img, hx+head_w-1, y, hr2)

    # ── Face (y=8..15)
    _rect(img, hx, 8, hx+head_w-1, 15, c["skin"])
    for y in range(8, 12):                            # hair framing
        _px(img, hx,           y, hair)
        _px(img, hx+1,         y, hr2)
        _px(img, hx+head_w-1,  y, hair)
        _px(img, hx+head_w-2,  y, hr2)

    lxe = hx + 2          # left-eye start
    rxe = hx + head_w - 4 # right-eye start (2px wide each)

    # Eyebrows (y=9)
    _px(img, lxe,   9, hr2); _px(img, lxe+1, 9, hr2)
    _px(img, rxe,   9, hr2); _px(img, rxe+1, 9, hr2)

    # Eyes (y=10..11)
    _px(img, lxe,   10, P.BLACK); _px(img, lxe+1,  10, eye)
    _px(img, lxe,   11, P.BLACK)
    _px(img, rxe,   10, P.BLACK); _px(img, rxe+1,  10, eye)
    _px(img, rxe,   11, P.BLACK)

    # Nose (y=12)
    _px(img, hx+head_w//2, 12, NOSE)

    # Mouth (y=13)
    cx = hx + head_w//2
    _px(img, cx-1, 13, LIPS); _px(img, cx, 13, LIPS); _px(img, cx+1, 13, LIPS)

    # ── Neck (y=16..18)
    _rect(img, 14, 16, 17, 18, c["skin"])

    # ── Torso (y=19..34)
    _rect(img, tx, 19, tx+torso_w-1, 34, c["body"])
    for y in range(19, 35):
        _px(img, tx,           y, c["light"]); _px(img, tx+1,           y, c["light"])
        _px(img, tx+torso_w-1, y, c["dark"]);  _px(img, tx+torso_w-2,   y, c["dark"])

    # ── Arms (y=19..32, 2px wide; forearm skin y=29..32)
    for y in range(19, 33):
        bc = c["skin"] if y >= 29 else c["body"]
        _px(img, tx-1, y, bc); _px(img, tx-2, y, bc)
        _px(img, tx+torso_w, y, bc); _px(img, tx+torso_w+1, y, bc)

    # ── Legs (y=35..47, gap at center)
    for y in range(35, 48):
        _row(img, y, lx,        lx+half-1,   c["body"])
        _row(img, y, lx+half+1, lx+leg_w-1,  c["body"])
    for y in range(35, 48):
        _px(img, lx+half-1, y, c["dark"]); _px(img, lx+half+1, y, c["dark"])
    for y in range(43, 48):
        _row(img, y, lx,        lx+half-1,   c["dark"])
        _row(img, y, lx+half+1, lx+leg_w-1,  c["dark"])

    return img


# ── Class painters ────────────────────────────────────────────────────────────

def swordmaster_hd(c):
    # Slim, silver-haired; gold scarf; long sword at right hip.
    img = draw_base_hd(c, head_w=8, torso_w=8, leg_w=7)
    acc = c.get("acc", GLD)
    # Longer hair strands to y=13
    for y in range(12, 14):
        _px(img, 12, y, c.get("hair", c["body"]))
        _px(img, 19, y, c.get("hair", c["body"]))
    # Gold scarf at neck
    _row(img, 16, 12, 19, acc); _row(img, 17, 12, 19, acc); _row(img, 18, 12, 19, acc)
    # Sword blade: x=22, y=19..44 (1px); tip at y=17
    _col(img, 22, 17, 44, SIL); _col(img, 23, 17, 42, SIL)
    # Sword crossguard at y=27
    _row(img, 26, 19, 25, SIL2); _row(img, 27, 19, 25, SIL)
    # Grip (wood, y=28..34)
    _col(img, 22, 28, 34, WD); _col(img, 23, 28, 34, WD2)
    _outline(img, c["outline"]); return img


def halberdier_hd(c):
    # Medium build; silver left pauldron; diagonal lance.
    img = draw_base_hd(c, head_w=8, torso_w=10, leg_w=8)
    acc = c.get("acc", SIL)
    # Pauldron on left shoulder (x=9..12, y=19..24)
    _rect(img, 9, 19, 12, 24, acc)
    for y in range(19, 25): _px(img, 9, y, SIL); _px(img, 12, y, SIL2)
    # Diagonal lance (2px wide; WD shaft, SIL tip)
    for i in range(22): _px(img, 3+i, 3+i, WD); _px(img, 4+i, 3+i, WD)
    # Spear tip (silver triangle)
    _px(img, 2, 2, SIL); _px(img, 3, 2, SIL); _px(img, 1, 3, SIL)
    _px(img, 2, 3, SIL); _px(img, 3, 3, SIL)
    # Butt end
    _px(img, 26, 25, WD2); _px(img, 25, 25, WD2)
    _outline(img, c["outline"]); return img


def berserker_hd(c):
    # Massive; wild spiked hair; bare arms; large axe over right shoulder.
    img = draw_base_hd(c, head_w=9, torso_w=14, leg_w=9)
    # Wild hair spikes above head (y=0..3)
    spikes = [(11,0),(13,0),(15,1),(17,0),(19,0),(11,1),(13,2),(17,2),(19,1)]
    for x,y in spikes: _px(img, x, y, c.get("hair", c["body"]))
    # Bare arms (overwrite with skin)
    tx = (UW-14)//2  # tx=9
    for y in range(19, 34):
        _px(img, tx-1, y, c["skin"]); _px(img, tx-2, y, c["skin"])
        _px(img, tx+14, y, c["skin"]); _px(img, tx+15, y, c["skin"])
    # Scar/angry brow (overwrite eyebrows to be angled)
    hx = (UW-9)//2  # hx=11
    _px(img, hx+2, 9, c.get("hair2", c["dark"])); _px(img, hx+3, 8, c.get("hair2", c["dark"]))
    _px(img, hx+5, 8, c.get("hair2", c["dark"])); _px(img, hx+6, 9, c.get("hair2", c["dark"]))
    # Big axe right side: handle at x=24, head y=5..14
    _col(img, 24, 10, 30, WD); _col(img, 25, 10, 30, WD2)  # handle
    _rect(img, 22, 5, 28, 14, c["acc"] if "acc" in c else (200,140,60,255))  # blade
    for y in range(5, 15): _px(img, 22, y, (240,185,90,255))  # edge highlight
    _px(img, 28, 5, WD2); _px(img, 28, 14, WD2)              # back edge shadow
    _outline(img, c["outline"]); return img


def sage_hd(c):
    # Slight build; hood; staff above; open tome in left hand; robe flare.
    img = draw_base_hd(c, head_w=8, torso_w=8, leg_w=6)
    acc = c.get("acc", (168,118,205,255))
    # Hood (covers hair, leaves face 9..15 clear)
    hx = (UW-8)//2  # hx=12
    _rect(img, hx-1, 4, hx+8, 10, acc)  # hood over hair
    for y in range(4, 11):              # hood outline/shadow
        _px(img, hx-1, y, c.get("hair2", c["dark"]))
        _px(img, hx+8, y, c.get("hair2", c["dark"]))
    # Restore face skin (y=9..15) that hood might have overwritten
    _rect(img, hx+1, 9, hx+6, 15, c["skin"])
    # Staff tip above head (x=15..16, y=0..3) with gold orb
    _col(img, 15, 0, 3, WD); _col(img, 16, 0, 3, WD)
    _px(img, 14, 0, GLD); _px(img, 15, 0, GLD); _px(img, 16, 0, GLD); _px(img, 17, 0, GLD)
    _px(img, 15, 1, (250,235,110,255))  # bright orb centre
    # Tome in left hand (x=3..8, y=26..33)
    _rect(img, 3, 26, 8, 33, (85,115,230,255))  # cover
    _col(img, 3, 26, 33, (55,75,165,255))        # spine
    _rect(img, 4, 27, 7, 32, (205,215,255,255))  # pages
    _px(img, 5, 29, GLD); _px(img, 6, 29, GLD)  # magic glyph
    # Robe flare (y=35..47, grows wider each 2 rows)
    lx = (UW-6)//2  # lx=13
    for y in range(35, 48):
        extra = (y - 35) // 2
        x0 = max(0,  lx - extra)
        x1 = min(31, lx + 5 + extra)
        _row(img, y, x0, x1, c["body"])
        _px(img, x0, y, c["light"]); _px(img, x1, y, c["dark"])
    _outline(img, c["outline"]); return img


def paladin_hd(c):
    # Wide build; gold chest; mounted bulk y>=30; lance to right.
    img = draw_base_hd(c, head_w=8, torso_w=12, leg_w=10)
    acc = c.get("acc", GLD)
    # Gold chest plate (y=21..28, centred)
    _rect(img, 13, 21, 18, 28, acc)
    for y in range(21, 29):
        _px(img, 13, y, (250,235,110,255)); _px(img, 18, y, GLD2)
    # Mounted lower body (wide block replaces slim legs)
    _rect(img, 8, 30, 23, 47, c["body"])
    for y in range(30, 48):
        _px(img, 8, y, c["light"]); _px(img, 9, y, c["light"])
        _px(img, 22, y, c["dark"]); _px(img, 23, y, c["dark"])
    for y in range(42, 48):
        _row(img, y, 8, 23, c["dark"])  # boots/hooves
    # Lance at right side: x=25..26, y=5..44; tip at y=3,4
    _col(img, 25, 10, 44, WD); _col(img, 26, 10, 44, WD2)
    _px(img, 24, 7, SIL); _px(img, 25, 6, SIL); _px(img, 25, 5, SIL)
    _px(img, 25, 4, SIL); _px(img, 26, 7, SIL)
    _outline(img, c["outline"]); return img


def lance_armor_hd(c):
    # Heaviest build; full helm visor; pauldrons; silver cross; lance.
    img = draw_base_hd(c, head_w=9, torso_w=14, leg_w=10)
    acc = c.get("acc", SIL)
    hx = (UW-9)//2  # hx=11
    # Full helm: overwrite hair with body/acc color
    _rect(img, hx-1, 4, hx+9, 8, c["body"])
    for y in range(4, 9):
        _px(img, hx-1, y, c["light"]); _px(img, hx+9, y, c["dark"])
    # T-visor slit on face
    _row(img, 10, hx, hx+8, c["dark"]); _row(img, 11, hx, hx+8, c["dark"])
    _col(img, hx+4, 9, 13, c["dark"])  # vertical centre
    # Left pauldron (x=7..11, y=20..26)
    _rect(img, 7, 20, 11, 26, c["body"])
    for y in range(20,27): _px(img, 7, y, c["light"]); _px(img, 11, y, c["dark"])
    # Right pauldron (x=20..24, y=20..26)
    _rect(img, 20, 20, 24, 26, c["body"])
    for y in range(20,27): _px(img, 20, y, c["light"]); _px(img, 24, y, c["dark"])
    # Silver cross on chest
    tx = (UW-14)//2  # tx=9
    _col(img, 15, 19, 34, acc); _col(img, 16, 19, 34, acc)
    _row(img, 25, 11, 20, acc); _row(img, 26, 11, 20, acc)
    # Lance (x=26..27, y=6..44); tip y=4..5
    _col(img, 26, 11, 44, WD); _col(img, 27, 11, 44, WD2)
    _px(img, 25, 9, SIL); _px(img, 26, 8, SIL); _px(img, 26, 7, SIL)
    _px(img, 26, 6, SIL); _px(img, 27, 9, SIL); _px(img, 26, 5, SIL)
    _outline(img, c["outline"]); return img


def griffin_knight_hd(c):
    # Compact; helmet crest; white wing feathers at sides; short cape.
    img = draw_base_hd(c, head_w=8, torso_w=10, leg_w=7)
    acc = c.get("acc", (212,228,242,255))  # white-blue wing feathers
    # Helmet crest (y=0..4, x=15..16, gold)
    _col(img, 15, 0, 4, GLD); _col(img, 16, 0, 4, GLD)
    _px(img, 14, 1, GLD); _px(img, 17, 1, GLD)
    # Overwrite hair top with helmet body
    hx = (UW-8)//2  # hx=12
    _rect(img, hx, 4, hx+7, 7, c["body"])
    for y in range(4,8):
        _px(img, hx, y, c["light"]); _px(img, hx+7, y, c["dark"])
    # Wing feathers left side (x=0..3, y=19..30)
    wing_rows = [(0,3),(0,3),(1,3),(1,2),(2,3),(1,2),(0,2),(0,1),(1,2),(0,1),(0,1),(0,0)]
    for i, (x0,x1) in enumerate(wing_rows):
        _row(img, 19+i, x0, x1, acc)
        if i < 4: _px(img, x0, 19+i, P.WHITE)  # highlight tips
    # Wing feathers right side (mirror)
    for i, (x0,x1) in enumerate(wing_rows):
        _row(img, 19+i, 31-x1, 31-x0, acc)
        if i < 4: _px(img, 31-x0, 19+i, P.WHITE)
    # Cape (y=19..34, x=10..11 and x=20..21 behind torso sides)
    for y in range(19, 35):
        _px(img, 10, y, c["dark"]); _px(img, 20, y, c["dark"])
    _outline(img, c["outline"]); return img


def _enemy_wyvern_hd(c):
    # Wyvern rider from scratch: rider top, bat wings mid, dragon body + tail.
    img = _new(UW, UH)
    skin = c["skin"]; bo = c["body"]; dk = c["dark"]; lt = c["light"]
    hair = c.get("hair", c["dark"])

    # Rider: small head+torso at top-centre (y=2..10, x=12..19)
    _rect(img, 12, 2, 19, 5, skin)  # head
    _row(img, 2, 12, 19, hair); _row(img, 3, 12, 19, hair)  # hair
    _px(img, 14, 4, P.BLACK); _px(img, 17, 4, P.BLACK)  # eyes
    _rect(img, 11, 6, 20, 10, bo)  # torso
    for y in range(6,11):
        _px(img, 11, y, lt); _px(img, 20, y, dk)

    # Wyvern neck/saddle (y=10..13, x=10..21, dark)
    _rect(img, 10, 10, 21, 13, dk)
    for y in range(10,14):
        _px(img, 10, y, bo); _px(img, 21, y, bo)

    # Wings: light membrane, symmetric, full spread at y=14..20, tapering to y=26
    wing_spans = [
        (0,31),(0,31),(0,31),(0,31),  # y=14..17 full
        (1,30),(2,29),(3,28),(4,27),  # y=18..21 taper
        (5,26),(6,25),(7,24),(8,23),  # y=22..25 taper
        (9,22),                        # y=26
    ]
    for i,(lw,rw) in enumerate(wing_spans):
        y = 14+i
        for x in range(lw, 10):    _px(img, x, y, lt)   # left membrane
        for x in range(22, rw+1):  _px(img, x, y, lt)   # right membrane
        # Wing vein
        if i < 8:
            _px(img, lw+1, y, bo); _px(img, rw-1, y, bo)

    # Dragon body (dark centre, y=14..36)
    _rect(img, 10, 14, 21, 36, dk)
    _rect(img, 12, 16, 19, 34, bo)   # belly highlight
    for y in range(17, 34): _px(img, 12, y, lt); _px(img, 19, y, dk)

    # Dragon legs (x=6..9 and x=22..25, y=34..40)
    _rect(img,  6, 34,  9, 40, dk)
    _rect(img, 22, 34, 25, 40, dk)
    # Claws
    for x in range(3, 10):  _px(img, x, 41, dk)
    for x in range(3, 8):   _px(img, x, 42, dk)
    for x in range(22, 29): _px(img, x, 41, dk)
    for x in range(24, 29): _px(img, x, 42, dk)

    # Tail: tapers right from body base
    for i in range(8):
        w2 = max(1, 3-i//2)
        _row(img, 37+i, 10-i, 10-i+w2, dk)

    _outline(img, c["outline"]); return img


PLAYER_CLASSES = {
    "swordmaster":    swordmaster_hd,
    "halberdier":     halberdier_hd,
    "berserker":      berserker_hd,
    "sage":           sage_hd,
    "paladin":        paladin_hd,
    "lance_armor":    lance_armor_hd,
    "griffin_knight": griffin_knight_hd,
}
ENEMY_CLASSES = {
    "enemy_soldier":  halberdier_hd,
    "enemy_fighter":  berserker_hd,
    "enemy_myrmidon": swordmaster_hd,
    "enemy_mage":     sage_hd,
    "enemy_armor":    lance_armor_hd,
    "enemy_wyvern":   _enemy_wyvern_hd,
}


# ── Weapon painters (16×16) ───────────────────────────────────────────────────

def _wpx(img, x, y, c): _px(img, x, y, c)
def _wrow(img, y, x0, x1, c): _row(img, y, x0, x1, c)
def _wcol(img, x, y0, y1, c): _col(img, x, y0, y1, c)
def _wrect(img, x0, y0, x1, y1, c): _rect(img, x0, y0, x1, y1, c)

def wsword():
    img = _new(WW, WH)
    # Blade: 2px wide, y=0..9
    _wcol(img, 6, 0, 9, SIL); _wcol(img, 7, 0, 9, SIL)
    _px(img, 6, 1, P.WHITE)                              # shine
    _wrow(img, 10, 3, 10, SIL2)                         # crossguard
    _wrow(img, 10, 4, 9, SIL)
    # Grip (2px, wood)
    _wcol(img, 6, 11, 13, WD); _wcol(img, 7, 11, 13, WD2)
    _wrow(img, 14, 5, 8, WD2)                            # pommel
    _outline(img); return img

def wlance():
    img = _new(WW, WH)
    # Tip (diamond): y=0..3
    _px(img, 7, 0, SIL); _px(img, 8, 0, SIL)
    _wrow(img, 1, 6, 9, SIL); _wrow(img, 2, 5, 10, SIL)
    _wrow(img, 3, 6, 9, SIL)
    _px(img, 6, 1, P.WHITE)   # shine
    # Shaft
    _wcol(img, 7, 4, 14, WD); _wcol(img, 8, 4, 14, WD2)
    _wrow(img, 15, 6, 9, WD2)  # butt cap
    _outline(img); return img

def waxe():
    img = _new(WW, WH)
    # Handle
    _wcol(img, 9, 3, 15, WD); _wcol(img, 10, 3, 15, WD2)
    _wrow(img, 15, 8, 11, WD2)  # butt
    # Axe head (crescent left)
    ONG = (210,135,50,255); ONG2 = (155,90,28,255)
    _wrect(img, 2, 1, 8, 9, ONG)
    _wcol(img, 2, 1, 9, (240,175,88,255))   # edge highlight
    _wrect(img, 4, 3, 7, 7, ONG2)           # head shadow notch
    _px(img, 2, 1, (245,195,110,255))        # top highlight
    _outline(img); return img

def wbow():
    img = _new(WW, WH)
    GRN = (98,188,78,255); GRN2 = (62,120,45,255)
    # Bow limb (curved left)
    for i,(x,y) in enumerate([(2,0),(1,1),(1,2),(1,3),(1,4),(1,5),(1,6),(1,7),(1,8),(1,9),(1,10),(1,11),(2,12),(3,13)]):
        _px(img, x, y, GRN)
        _px(img, x+1, y, GRN2)
    # Grip (darker centre)
    _wpx(img, 1, 5, GRN2); _wpx(img, 1, 6, GRN2); _wpx(img, 1, 7, GRN2)
    # Bowstring (right)
    _wcol(img, 10, 1, 12, SIL2)
    # Nocking points
    _px(img, 2, 1, GRN); _px(img, 2, 12, GRN)
    _outline(img); return img

def wtome():
    img = _new(WW, WH)
    BLU = (85,115,230,255); BLD = (55,75,165,255); PGE = (205,215,255,255)
    # Cover
    _wrect(img, 2, 1, 12, 14, BLU)
    # Spine
    _wcol(img, 2, 1, 14, BLD); _wcol(img, 3, 1, 14, BLD)
    # Pages
    _wrect(img, 4, 2, 11, 13, PGE)
    # Text lines on pages
    for y in [4,6,8,10,12]: _wrow(img, y, 5, 10, (185,198,235,255))
    # Gold glyph
    _px(img, 7, 7, GLD); _px(img, 8, 7, GLD)
    _px(img, 7, 6, GLD2); _px(img, 7, 8, GLD2)
    _px(img, 6, 7, GLD2); _px(img, 9, 7, GLD2)
    _outline(img); return img

def wstaff():
    img = _new(WW, WH)
    # Shaft
    _wcol(img, 7, 4, 14, WD); _wcol(img, 8, 4, 14, WD2)
    _wrow(img, 15, 6, 9, WD2)  # base
    # Gold orb at top
    _wrect(img, 5, 1, 10, 4, GLD)
    _px(img, 5, 2, GLD2); _px(img, 10, 2, GLD2)    # orb shading
    _px(img, 7, 1, (255,245,120,255))               # bright highlight
    _px(img, 6, 0, GLD2); _px(img, 9, 0, GLD2)     # top arc
    _wrow(img, 0, 7, 8, (255,248,130,255))          # orb tip glow
    _outline(img); return img

def wbrawl():
    img = _new(WW, WH)
    BRN = (140,95,50,255)
    SKN = (215,175,130,255)
    # Fist/gauntlet
    _wrect(img, 2, 3, 11, 9, BRN)
    # Knuckle row (skin)
    _wrow(img, 3, 2, 11, SKN)
    # Individual knuckle dots
    for x in [3,5,7,9]: _px(img, x, 3, (240,205,165,255))
    # Thumb
    _wrect(img, 11, 3, 13, 6, BRN)
    _px(img, 13, 4, SKN)
    # Wrist
    _wrect(img, 4, 10, 9, 13, BRN)
    _wcol(img, 4, 11, 13, WD2)  # wrist shadow side
    # Metal plate detail
    _wrow(img, 5, 3, 10, (165,118,62,255))  # plate line
    _outline(img); return img

def wdagger():
    img = _new(WW, WH)
    # Diagonal blade (2px wide, top-right to bottom-left)
    pairs = [(10,0),(9,1),(8,2),(7,3),(6,4),(5,5),(4,6)]
    for x,y in pairs:
        _px(img, x, y, SIL); _px(img, x-1, y, SIL)
        _px(img, x, y+1, SIL)
    _px(img, 10, 0, P.WHITE)   # shine
    # Guard
    _wrow(img, 7, 2, 6, SIL2)
    # Hilt
    _wcol(img, 3, 8, 11, WD); _wcol(img, 2, 8, 11, WD2)
    _wrow(img, 12, 1, 4, WD2)  # pommel
    _outline(img); return img

WEAPONS = {
    "sword":  wsword,  "lance": wlance, "axe":   waxe,  "bow":    wbow,
    "tome":   wtome,   "staff": wstaff, "brawl": wbrawl, "dagger": wdagger,
}


# ── Terrain painters (32×32) ──────────────────────────────────────────────────

def tplain():
    img = _new(TW, TH)
    c = P.TERRAIN["plain"]
    img.paste(c["base"], (0, 0, TW, TH))
    for y in range(TH):
        for x in range(TW):
            if (x+y) % 4 == 0:    img.putpixel((x,y), c["dark"])
            elif (x+y) % 10 == 0: img.putpixel((x,y), c["light"])
    dots = [(5,5),(13,2),(21,8),(28,12),(7,18),(17,22),(25,28),(3,28),(11,14)]
    for x,y in dots: _px(img, x, y, c["dot"]); _px(img, x+1, y, c["dot"])
    return img

def tforest():
    img = _new(TW, TH)
    c = P.TERRAIN["forest"]
    img.paste(c["ground"], (0, 0, TW, TH))
    # Two-tree layout
    for cx in [10, 22]:
        # Canopy
        for dy in range(-7, 3):
            w2 = max(1, 6 - abs(dy) // 1)
            _row(img, 10+dy, cx-w2, cx+w2, c["base"])
        _row(img, 3, cx-2, cx+2, c["light"])   # top highlight
        _row(img, 4, cx-4, cx-2, c["light"])
        _row(img, 10, cx+3, cx+5, c["dark"])   # bottom shadow
        # Trunk
        _col(img, cx-1, 13, 24, c["trunk"])
        _col(img, cx,   13, 24, c["trunk"])
        # Roots
        for rx in [-2,1]: _px(img, cx+rx, 25, c["trunk"])
    return img

def tpeak():
    img = _new(TW, TH)
    c = P.TERRAIN["peak"]
    img.paste(c["base"], (0, 0, TW, TH))
    # Left face (dark)
    for y in range(TH):
        for x in range(TW):
            d = abs(x - 14)
            if y > max(4, 18 - d * 1) and x <= 14: img.putpixel((x,y), c["dark"])
    # Right face (mid)
    for y in range(TH):
        for x in range(TW):
            d = abs(x - 14)
            if y > max(4, 18 - d * 1) and x > 14: img.putpixel((x,y), c["mid"])
    # Snow caps
    for x,y in [(13,5),(14,5),(13,6),(14,6),(12,7),(15,7),(11,8),(13,8),(14,8),(16,8),
                (24,8),(25,8),(24,9),(25,9),(23,10),(26,10)]:
        if 0<=x<TW and 0<=y<TH: img.putpixel((x,y), c["light"])
    # Sky rows stay base (clear y=0..4)
    for x in range(TW):
        for y in range(5): img.putpixel((x,y), c["base"])
    return img

def twall():
    img = _new(TW, TH)
    c = P.TERRAIN["wall"]
    img.paste(c["base"], (0, 0, TW, TH))
    # Mortar: horizontal lines every 8px
    for y in [8, 16, 24]:
        _row(img, y, 0, 31, c["mortar"])
    # Mortar: vertical, alternating offset
    for y in range(TH):
        if y in range(0,8) or y in range(17,24):
            for x in [16]: _px(img, x, y, c["mortar"])
        elif y in range(9,16) or y in range(25,32):
            for x in [8, 24]: _px(img, x, y, c["mortar"])
    # Highlight top of each brick row
    for x in range(TW):
        for y in range(TH):
            if img.getpixel((x,y)) == c["base"]:
                if y > 0 and img.getpixel((x,y-1)) == c["mortar"]:
                    img.putpixel((x,y), c["light"])
    return img

def twater():
    img = _new(TW, TH)
    c = P.TERRAIN["water"]
    img.paste(c["base"], (0, 0, TW, TH))
    # Wave lines
    for y in [2, 8, 14, 20, 26]:
        for x in range(0, TW, 3): _px(img, x, y, c["dark"]); _px(img, x+1, y, c["dark"])
    for y in [5, 11, 17, 23, 29]:
        for x in range(1, TW, 5):
            _px(img, x, y, c["light"]); _px(img, x+1, y, c["light"]); _px(img, x+2, y, c["light"])
    # Foam dots
    foam_pts = [(3,5),(10,11),(18,17),(26,23),(6,23),(22,5),(14,29),(2,17),(28,11)]
    for x,y in foam_pts: _px(img, x, y, c["foam"]); _px(img, x+1, y, c["foam"])
    return img

TERRAINS = [tplain, tforest, tpeak, twall, twater]
TNAMES   = ["plain","forest","peak","wall","water"]


# ── Main: generate + preview sheet ───────────────────────────────────────────

if __name__ == "__main__":
    print("Generating HD sprites …")

    # Player units
    for cid, painter in PLAYER_CLASSES.items():
        pal = CPAL[cid]
        img = painter(pal)
        path = os.path.join(PREV, f"{cid}_player_hd.png")
        img.save(path); print(f"  [unit] {cid}_player → {path}")

    # Enemy units
    for cid, painter in ENEMY_CLASSES.items():
        img = painter(EPAL)
        path = os.path.join(PREV, f"{cid}_enemy_hd.png")
        img.save(path); print(f"  [unit] {cid}_enemy  → {path}")

    # Weapons
    for wname, painter in WEAPONS.items():
        img = painter()
        path = os.path.join(PREV, f"weapon_{wname}_hd.png")
        img.save(path); print(f"  [wpn]  weapon_{wname} → {path}")

    # Terrain
    terrain_imgs = []
    for name, painter in zip(TNAMES, TERRAINS):
        img = painter()
        path = os.path.join(PREV, f"terrain_{name}_hd.png")
        img.save(path); print(f"  [terr] terrain_{name} → {path}")
        terrain_imgs.append(img)

    # ── Preview sheet ────────────────────────────────────────────────────────
    # Row 0: 7 player units (32×48)
    # Row 1: 6 enemy units  (32×48)
    # Row 2: 8 weapons      (16×16) — centred, shown at 2× for readability
    # Row 3: 5 terrain      (32×32)
    # 4px gap between rows; 4px border all sides; dark background.

    BORDER = 4; GAP = 4
    COLS   = max(len(PLAYER_CLASSES), len(ENEMY_CLASSES))  # 7
    CELL   = UW                                             # 32
    W2     = COLS * CELL + BORDER * 2

    # Heights per row
    WEAPON_SCALE = 2   # show weapons at 2× so they're readable
    ROW_H = [UH, UH, WH*WEAPON_SCALE, TH]
    total_h = sum(ROW_H) + GAP * (len(ROW_H)-1) + BORDER*2

    BG = (28, 28, 38, 255)
    sheet = Image.new("RGBA", (W2, total_h), BG)

    y_cursor = BORDER

    # Player units
    for i,(cid,painter) in enumerate(PLAYER_CLASSES.items()):
        img = painter(CPAL[cid])
        sheet.paste(img, (BORDER + i*CELL, y_cursor), img)
    y_cursor += UH + GAP

    # Enemy units
    for i,(cid,painter) in enumerate(ENEMY_CLASSES.items()):
        img = painter(EPAL)
        sheet.paste(img, (BORDER + i*CELL, y_cursor), img)
    y_cursor += UH + GAP

    # Weapons (shown at 2×)
    for i,(_,painter) in enumerate(WEAPONS.items()):
        img = _nn(painter(), WEAPON_SCALE)
        sheet.paste(img, (BORDER + i*CELL, y_cursor), img)
    y_cursor += WH*WEAPON_SCALE + GAP

    # Terrain
    for i,img in enumerate(terrain_imgs):
        sheet.paste(img, (BORDER + i*CELL, y_cursor), img)

    # Final 4× upscale (nearest-neighbor) for easy review
    preview = _nn(sheet, SCALE)
    sheet_path = os.path.join(PREV, "_preview_sheet_hd.png")
    preview.save(sheet_path)
    print(f"\nPreview sheet (4×) → {sheet_path}")
    print(f"  Sheet size: {preview.width}×{preview.height} px")
