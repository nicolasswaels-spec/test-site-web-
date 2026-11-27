"""Retire les balises de métadonnées (APP1 à APP15, commentaires) des JPEG : dans les images
intégrées aux .glb et dans les .jpg extraits. Godot 4.7 (libjpeg-turbo) refuse de décoder les JPEG
écrits par Blender avec ces balises, les modèles se chargent alors sans texture (tout blancs).
Les données d'image ne sont pas réencodées. Usage : python3 clean_glb_jpeg.py <dossier assets>"""
import sys, os, json, struct


def strip_jpeg(b: bytes) -> bytes:
    if b[:2] != b"\xff\xd8":
        return b
    out = bytearray(b[:2])
    i = 2
    while i < len(b) - 4 and b[i] == 0xFF:
        m = b[i + 1]
        if m == 0xDA:          # début des données : on garde tout le reste
            out += b[i:]
            return bytes(out)
        L = int.from_bytes(b[i + 2:i + 4], "big")
        if not (0xE1 <= m <= 0xEF or m == 0xFE):
            out += b[i:i + 2 + L]
        i += 2 + L
    return b


def fix_glb(path: str) -> bool:
    b = open(path, "rb").read()
    if b[:4] != b"glTF":
        return False
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", b[off:off + 4])[0]
    binc = b[off + 8:off + 8 + bl]
    img_views = {im["bufferView"] for im in j.get("images", []) if "bufferView" in im and im.get("mimeType") == "image/jpeg"}
    if not img_views:
        return False
    views = j["bufferViews"]
    order = sorted(range(len(views)), key=lambda k: views[k].get("byteOffset", 0))
    nb = bytearray()
    changed = False
    for k in order:
        v = views[k]
        data = binc[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        if k in img_views:
            d2 = strip_jpeg(data)
            changed |= d2 != data
            data = d2
        while len(nb) % 4:
            nb.append(0)
        v["byteOffset"] = len(nb)
        v["byteLength"] = len(data)
        nb += data
    if not changed:
        return False
    while len(nb) % 4:
        nb.append(0)
    j["buffers"][0]["byteLength"] = len(nb)
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(nb)
    out = b"glTF" + struct.pack("<II", 2, total) + struct.pack("<I", len(js)) + b"JSON" + js + struct.pack("<I", len(nb)) + b"BIN\x00" + bytes(nb)
    open(path, "wb").write(out)
    return True


n_glb = n_jpg = 0
for dp, _, fs in os.walk(sys.argv[1]):
    for f in fs:
        p = os.path.join(dp, f)
        if f.endswith(".glb"):
            n_glb += fix_glb(p)
        elif f.lower().endswith((".jpg", ".jpeg")):
            b = open(p, "rb").read()
            s = strip_jpeg(b)
            if s != b:
                open(p, "wb").write(s)
                n_jpg += 1
print("glb nettoyés :", n_glb, " jpg nettoyés :", n_jpg)
