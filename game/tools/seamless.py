"""Rend une texture OpenArt parfaitement répétable : les raccords (bords) sont amenés au centre,
adoucis sur une bande étroite, puis remis en place ; réduite à la taille voulue.
Usage : python3 seamless.py <entrée.png> <sortie.jpg> [taille]"""
import sys
import numpy as np
from PIL import Image, ImageFilter

src, out = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32)
h, w = a.shape[:2]
r = np.roll(a, (h // 2, w // 2), axis=(0, 1))
bl = np.asarray(Image.fromarray(r.astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(np.float32)
band = 28
yy, xx = np.mgrid[0:h, 0:w]
d = np.minimum(np.abs(xx - w // 2), np.abs(yy - h // 2)).astype(np.float32)
m = np.clip(1.0 - d / band, 0, 1)[..., None]
r = r * (1 - m) + bl * m
a = np.roll(r, (-(h // 2), -(w // 2)), axis=(0, 1))
Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).resize((size, size), Image.LANCZOS).save(out, quality=90)
print("ok", out)
