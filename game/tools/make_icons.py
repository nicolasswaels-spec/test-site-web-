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
