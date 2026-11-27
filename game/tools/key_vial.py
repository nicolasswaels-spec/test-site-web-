"""Détoure la fiole OpenArt (fond et intérieur vert chroma) : produit
- vial_frame.png : le verre, le bouchon et les ornements (fond transparent, intérieur du verre
  presque transparent sauf les reflets blancs et les fils dorés),
- vial_mask.png : l'intérieur du verre (là où le jeu dessine le liquide),
et affiche les bornes haut/bas du liquide (en fraction de la hauteur).
Usage : python3 key_vial.py <fiole.png> <dossier de sortie> [largeur]"""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
W = int(sys.argv[3]) if len(sys.argv) > 3 else 256
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32) / 255
r, g, b = a[..., 0], a[..., 1], a[..., 2]
green = np.clip(g - np.maximum(r, b), 0, 1)
# fond : vert vif relié au bord de l'image
bgc = green > 0.45
lab, n = ndimage.label(bgc)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
outside = np.isin(lab, list(border))
outside = ndimage.binary_dilation(outside, iterations=2) & (green > 0.25)
# intérieur du verre : rangées entre le bas du col et le haut du berceau doré, entre les parois
inner_c = (green > 0.12) & ~outside
lab2, n2 = ndimage.label(inner_c)
sizes = ndimage.sum(inner_c, lab2, range(1, n2 + 1))
big = np.isin(lab2, [i + 1 for i, sz in enumerate(sizes) if sz > 0.002 * inner_c.size])
rows = np.nonzero(big.any(1))[0]
y0 = rows.min()
H0, W0 = g.shape
cx = W0 // 2
gold = (r - b > 0.15) & (r > 0.35)
# haut du berceau : première longue suite de pixels dorés sur la colonne centrale sous le verre
y1 = rows.max()
run = 0
for y in range(y0 + 40, H0):
    run = run + 1 if (gold[y, cx - 60:cx + 61].mean() > 0.55) else 0
    if run > 18:
        y1 = y - run
        break
inside = ~outside
inner = np.zeros_like(inside)
# verre droit : parois prises sur une rangée sans fil doré (médiane des rangées du milieu)
Ls, Rs = [], []
for y in range(y0 + (y1 - y0) // 4, y0 + 3 * (y1 - y0) // 4):
    xs_ = np.nonzero(inside[y])[0]
    Ls.append(xs_.min()); Rs.append(xs_.max())
L, R = int(np.median(Ls)), int(np.median(Rs))
wall = int(0.07 * (R - L))
from PIL import ImageDraw
_mi = Image.new("L", (W0, H0), 0)
ImageDraw.Draw(_mi).rounded_rectangle((L + wall, y0 + 6, R - wall, y1 + 30), radius=int((R - L) * 0.22), fill=255)
inner = np.asarray(_mi) > 128
# image du cadre : alpha 0 dehors ; dans le verre, on garde les reflets clairs et l'or, le reste
# devient un léger voile (le liquide se voit derrière)
alpha = np.ones_like(g)
lum = a.mean(axis=2)
keep = np.clip((lum - 0.6) * 4.0, 0, 1)
keep = np.maximum(keep, gold.astype(np.float32))
alpha = np.where(inner, np.maximum(keep, 0.12), alpha)
alpha = np.where(outside, 0.0, alpha)
# retire le vert (despill) : g ramené au max(r, b) là où il dépasse
g2 = np.minimum(g, np.maximum(r, b) * 1.05 + 0.02)
rgb = np.stack([r, g2, b], -1)
frame = np.dstack([rgb, alpha])
fi = Image.fromarray((frame * 255).astype(np.uint8), "RGBA")
ys, xs = np.nonzero(alpha > 0.5)
box = (max(xs.min() - 4, 0), max(ys.min() - 4, 0), min(xs.max() + 5, im.width), min(ys.max() + 5, im.height))
fi = fi.crop(box)
mi = Image.fromarray((inner * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)).crop(box)
H = int(round(fi.height * W / fi.width))
fi = fi.resize((W, H), Image.LANCZOS)
mi = mi.resize((W, H), Image.LANCZOS)
fi.save(out + "/vial_frame.png")
mi.save(out + "/vial_mask.png")
m = np.asarray(mi) > 128
rows = np.nonzero(m.any(1))[0]
print("taille", W, H, "liquide y_top=%.4f y_bot=%.4f" % (rows.min() / H, (rows.max() + 1) / H))
