# Génère les icônes de ressources (128 px, fond transparent), dessinées à la main en PIL.
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter
OUT = sys.argv[1]
S = 512  # dessin en grand puis réduction (anticrénelage)

def glow(img, color, radius, strength=1.0):
    a = img.split()[3].filter(ImageFilter.GaussianBlur(radius))
    g = Image.new("RGBA", img.size, color + (0,))
    g.putalpha(a.point(lambda v: int(min(255, v * strength))))
    return Image.alpha_composite(g, img)

def log_icon(magic):
    random.seed(3)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # bûche couchée en diagonale : corps (écorce) + bout (cernes)
    bark_dark, bark = ((52, 34, 24), (96, 62, 38)) if not magic else ((30, 40, 28), (70, 66, 40))
    cx0, cy0, cx1, cy1, r = 150, 330, 370, 190, 95
    ang = math.atan2(cy1 - cy0, cx1 - cx0)
    nx, ny = -math.sin(ang), math.cos(ang)
    poly = [(cx0 + nx * r, cy0 + ny * r), (cx1 + nx * r, cy1 + ny * r), (cx1 - nx * r, cy1 - ny * r), (cx0 - nx * r, cy0 - ny * r)]
    d.polygon(poly, fill=bark)
    # stries d'écorce
    for k in range(-4, 5):
        o = k * r / 5.0
        d.line([(cx0 + nx * o - 10, cy0 + ny * o), (cx1 + nx * o - 30, cy1 + ny * o)], fill=bark_dark, width=9)
    d.ellipse([cx0 - r * 0.92, cy0 - r, cx0 + r * 0.92, cy0 + r], fill=bark_dark)
    # bout de la bûche avec cernes
    end = (cx1, cy1)
    d.ellipse([end[0] - r * 0.92, end[1] - r, end[0] + r * 0.92, end[1] + r], fill=(70, 45, 28))
    for i, rr in enumerate([0.85, 0.66, 0.46, 0.27, 0.1]):
        col = (214, 168, 112) if i % 2 == 0 else (180, 132, 82)
        if magic:
            col = (150, 230, 190) if i % 2 == 0 else (90, 190, 150)
        d.ellipse([end[0] - r * 0.92 * rr, end[1] - r * rr, end[0] + r * 0.92 * rr, end[1] + r * rr], fill=col)
    if magic:
        # mousse sur le dessus de l'écorce
        for i in range(70):
            t = random.random()
            px = cx0 + (cx1 - cx0) * t - nx * r * random.uniform(0.55, 1.05)
            py = cy0 + (cy1 - cy0) * t - ny * r * random.uniform(0.55, 1.05)
            rad = random.uniform(14, 30)
            g = random.randint(120, 190)
            d.ellipse([px - rad, py - rad * 0.8, px + rad, py + rad * 0.8], fill=(40, g, 60))
        for i in range(25):
            t = random.random()
            px = cx0 + (cx1 - cx0) * t - nx * r * random.uniform(0.7, 1.0)
            py = cy0 + (cy1 - cy0) * t - ny * r * random.uniform(0.7, 1.0)
            d.ellipse([px - 6, py - 6, px + 6, py + 6], fill=(190, 255, 200))
        im = glow(im, (80, 255, 170), 28, 2.2)
    return im

def rock_icon(magic):
    random.seed(7)
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(110, 360), (150, 210), (260, 120), (380, 170), (420, 300), (360, 400), (210, 420)]
    base = (112, 112, 136) if not magic else (70, 60, 110)
    d.polygon(pts, fill=base)
    c = (265, 290)
    shades = [(150, 150, 176), (128, 128, 154), (90, 90, 112), (76, 76, 96), (100, 100, 124), (138, 138, 162), (118, 118, 142)]
    if magic:
        shades = [(110, 96, 170), (92, 80, 150), (58, 50, 98), (48, 40, 84), (70, 60, 120), (100, 88, 160), (84, 72, 136)]
    for i in range(len(pts)):
        d.polygon([c, pts[i], pts[(i + 1) % len(pts)]], fill=shades[i])
    d.line(pts + [pts[0]], fill=(40, 40, 52) if not magic else (30, 24, 60), width=8)
    if magic:
        # cristaux lumineux qui sortent de la pierre
        for (bx, by, h, w, a) in [(250, 200, 170, 46, -0.15), (320, 230, 120, 36, 0.45), (190, 240, 110, 32, -0.6)]:
            tipx, tipy = bx + math.sin(a) * h, by - math.cos(a) * h
            lx, ly = bx - math.cos(a) * w, by - math.sin(a) * w
            rx, ry = bx + math.cos(a) * w, by + math.sin(a) * w
            d.polygon([(lx, ly), (tipx, tipy), (rx, ry)], fill=(140, 200, 255))
            d.polygon([(bx, by), (tipx, tipy), (rx, ry)], fill=(200, 160, 255))
            d.line([(bx, by), (tipx, tipy)], fill=(245, 240, 255), width=5)
        im = glow(im, (170, 120, 255), 28, 2.2)
    return im

def gear_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c, R, r = (256, 256), 170, 130
    pts = []
    for i in range(48):
        a = i / 48 * math.tau
        rad = R if (i // 3) % 2 == 0 else r
        pts.append((c[0] + math.cos(a) * rad, c[1] + math.sin(a) * rad))
    d.polygon(pts, fill=(150, 170, 190))
    d.ellipse([c[0] - 115, c[1] - 115, c[0] + 115, c[1] + 115], fill=(110, 128, 150))
    d.ellipse([c[0] - 55, c[1] - 55, c[0] + 55, c[1] + 55], fill=(0, 0, 0, 0))
    d.line([(150, 170), (210, 150)], fill=(220, 235, 245), width=14)
    return im

def save(im, name):
    # contour sombre pour la lisibilité sur tous les fonds
    a = im.split()[3].filter(ImageFilter.MaxFilter(13))
    o = Image.new("RGBA", im.size, (8, 6, 20, 0)); o.putalpha(a.point(lambda v: int(v * 0.55)))
    im = Image.alpha_composite(o, im)
    im.resize((128, 128), Image.LANCZOS).save(f"{OUT}/{name}.png")

save(log_icon(False), "wood")
save(log_icon(True), "magic_wood")
save(rock_icon(False), "stone")
save(rock_icon(True), "magic_stone")
save(gear_icon(), "coins")


# ------------------------------------------------------------------ os
def _bone(d, x0, y0, x1, y1, w, col, shade):
    ang = math.atan2(y1 - y0, x1 - x0)
    nx, ny = -math.sin(ang), math.cos(ang)
    poly = [(x0 + nx * w, y0 + ny * w), (x1 + nx * w, y1 + ny * w), (x1 - nx * w, y1 - ny * w), (x0 - nx * w, y0 - ny * w)]
    d.polygon(poly, fill=col)
    for (cx, cy) in [(x0, y0), (x1, y1)]:
        for s in (1, -1):
            px, py = cx + nx * w * 0.95 * s, cy + ny * w * 0.95 * s
            r = w * 1.15
            d.ellipse([px - r, py - r, px + r, py + r], fill=col)
    d.line([(x0 + nx * w * 0.4, y0 + ny * w * 0.4), (x1 + nx * w * 0.4, y1 + ny * w * 0.4)], fill=shade, width=max(4, int(w * 0.35)))

def bone_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    _bone(d, 140, 370, 372, 142, 42, (236, 226, 200), (200, 186, 152))
    return im

def big_bone_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    _bone(d, 160, 352, 352, 160, 56, (240, 222, 178), (196, 170, 120))
    d.line([(250, 230), (275, 262), (262, 290)], fill=(120, 96, 70), width=9)
    return glow(im, (255, 200, 90), 22, 1.6)

def arrow_bone_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    # tige en os + pointe taillée + empennage
    _bone(d, 130, 382, 330, 182, 22, (232, 222, 196), (196, 182, 150))
    tip = [(318, 150), (420, 92), (362, 194)]
    d.polygon(tip, fill=(214, 204, 176))
    d.line([tip[0], tip[1], tip[2]], fill=(150, 136, 110), width=6)
    for k in range(3):
        o = k * 26
        d.polygon([(150 + o, 362 - o), (98 + o, 350 - o), (128 + o, 398 - o)], fill=(110, 160, 80))
    return im

def bone_pile_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    random.seed(11)
    for (a, b, c2, e, w) in [(90, 420, 330, 330, 30), (180, 430, 430, 380, 32), (100, 340, 360, 420, 28), (170, 300, 420, 340, 30), (200, 380, 300, 250, 26)]:
        _bone(d, a, b, c2, e, w, (236, 224, 194), (196, 180, 146))
    # crâne
    d.ellipse([190, 130, 330, 260], fill=(244, 236, 214))
    d.rounded_rectangle([220, 230, 300, 290], 14, fill=(244, 236, 214))
    d.ellipse([214, 180, 252, 220], fill=(40, 30, 36)); d.ellipse([268, 180, 306, 220], fill=(40, 30, 36))
    d.polygon([(258, 222), (250, 244), (266, 244)], fill=(40, 30, 36))
    for x in range(232, 296, 14):
        d.line([(x, 262), (x, 286)], fill=(150, 136, 120), width=4)
    return glow(im, (255, 170, 80), 26, 1.8)

# ------------------------------------------------------------------ armes (silhouettes stylisées)
def _poly(d, pts, col, outline=(20, 16, 30)):
    d.polygon(pts, fill=col)
    d.line(pts + [pts[0]], fill=outline, width=7)

def pistol_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    _poly(d, [(110, 170), (420, 170), (420, 240), (250, 240), (230, 350), (150, 350), (170, 240), (110, 240)], (70, 74, 92))
    _poly(d, [(110, 150), (400, 150), (400, 178), (110, 178)], (120, 126, 150))
    d.rectangle([240, 245, 262, 290], outline=(20, 16, 30), width=7)
    d.rectangle([160, 260, 210, 330], fill=(110, 70, 45))
    return im

def rifle_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    _poly(d, [(40, 220), (150, 200), (330, 200), (470, 205), (470, 232), (330, 240), (290, 250), (300, 330), (255, 335), (240, 255), (190, 255), (175, 300), (60, 290)], (66, 70, 84))
    _poly(d, [(210, 255), (250, 255), (262, 345), (222, 350)], (52, 54, 66))  # chargeur
    _poly(d, [(200, 165), (300, 165), (300, 195), (200, 195)], (40, 44, 56))   # viseur
    d.rectangle([330, 206, 440, 226], fill=(150, 104, 62))
    d.rectangle([60, 230, 150, 280], fill=(150, 104, 62))
    return im

def cryo_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    _poly(d, [(60, 200), (330, 180), (420, 200), (420, 270), (330, 290), (250, 290), (240, 360), (180, 360), (190, 290), (60, 280)], (70, 90, 120))
    d.ellipse([120, 200, 240, 270], fill=(120, 230, 255))
    d.rectangle([420, 214, 470, 256], fill=(160, 240, 255))
    for k in range(3):
        x = 270 + k * 40
        d.line([(x, 190), (x, 280)], fill=(40, 60, 90), width=8)
    return glow(im, (120, 220, 255), 22, 1.6)

def axe_icon():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.line([(150, 430), (360, 110)], fill=(20, 16, 30), width=46)
    d.line([(150, 430), (360, 110)], fill=(140, 92, 52), width=32)
    _poly(d, [(300, 120), (430, 70), (460, 210), (340, 220)], (180, 190, 205))
    d.line([(430, 74), (458, 206)], fill=(240, 245, 255), width=10)
    return im

for f, n in [(bone_icon, "bone"), (big_bone_icon, "big_bone"), (arrow_bone_icon, "arrow_bone"), (bone_pile_icon, "bone_pile"),
             (pistol_icon, "w_pistol"), (rifle_icon, "w_rifle"), (cryo_icon, "w_cryo"), (axe_icon, "w_axe")]:
    save(f(), n)
