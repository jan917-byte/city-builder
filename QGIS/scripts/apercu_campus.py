# -*- coding: utf-8 -*-
"""Le plan du campus vu du dessus, numéroté, grille de 10 m depuis la croisée.

    python QGIS/scripts/apercu_campus.py   → QGIS/rendus/wehrau_campus_plan.png

Les numéros sont ceux de `PLAN` (export_godot/campus.py), dans l'ordre : on corrige la table devant l'image."""

import os
import sqlite3
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.dirname(os.path.dirname(ICI))
sys.path.insert(0, ICI)

from PIL import Image, ImageDraw, ImageFont  # noqa: E402
from apercu_carte import gpkg_vers_wkb, lire_wkb  # noqa: E402
from export_godot import campus as C  # noqa: E402

ECHELLE, COTE = 7, 1000
NOMS = {36: "Université", 77: "Bibliothèque", 78: "Institut"}
TEINTES = {36: (89, 99, 112), 77: (111, 156, 136), 78: (200, 196, 186)}


def anneaux(blob):
    out = []
    def descendre(x):
        if isinstance(x, (list, tuple)) and x and isinstance(x[0], (list, tuple)) \
                and len(x[0]) == 2 and isinstance(x[0][0], float):
            out.append([tuple(p) for p in x])
        elif isinstance(x, (list, tuple)):
            for y in x:
                descendre(y)
    descendre(lire_wkb(gpkg_vers_wkb(blob)))
    return out


def main():
    con = sqlite3.connect(os.path.join(RACINE, "QGIS", "data", "travail", "wehrau.gpkg"))
    centre = (C.ORIGINE[0] + 20, C.ORIGINE[1] - 3)
    def T(p):
        return (COTE / 2 + (p[0] - centre[0]) * ECHELLE, COTE / 2 - (p[1] - centre[1]) * ECHELLE)
    im = Image.new("RGB", (COTE, COTE), (246, 244, 238))
    d = ImageDraw.Draw(im)
    try:
        police = ImageFont.truetype("arial.ttf", 22)
        petite = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        police = petite = ImageFont.load_default()
    ilots = {}
    for fid, g in con.execute("SELECT fid, geom FROM ilots"):
        an = anneaux(g)[0]
        an = an[:-1] if an[0] == an[-1] else an
        if fid in C.CAMPUS:
            ilots[fid] = an
        d.polygon([T(p) for p in an], fill=(196, 222, 178) if fid in C.CAMPUS else (232, 230, 224),
                  outline=(170, 170, 170))
    for g, larg in con.execute("SELECT geom, largeur_m FROM routes"):
        for ligne in anneaux(g):
            d.line([T(p) for p in ligne], fill=(150, 150, 165), width=max(2, int((larg or 6) * 2)))
    for k in range(-80, 81, 10):
        for a, b in [((k, -80), (k, 80)), ((-80, k), (80, k))]:
            d.line([T((C.ORIGINE[0] + a[0], C.ORIGINE[1] + a[1])),
                    T((C.ORIGINE[0] + b[0], C.ORIGINE[1] + b[1]))], fill=(228, 200, 200))
    for f in C.CAMPUS:
        for s in C.sols(f, ilots):
            d.polygon([T(p) for p in s], fill=(214, 206, 188))
    n = 0
    for f in C.CAMPUS:
        for an, niv, _, (porte, _) in C.batiments(f):
            n += 1
            d.polygon([T(p) for p in an], fill=TEINTES[f], outline=(40, 40, 40))
            x, y = T((sum(p[0] for p in an) / 4, sum(p[1] for p in an) / 4))
            d.ellipse([x - 17, y - 17, x + 17, y + 17], fill="white", outline=(40, 40, 40))
            d.text((x, y), str(n), fill=(20, 20, 20), font=police, anchor="mm")
            d.text((x, y + 26), "%d niv." % niv, fill=(40, 40, 40) if f == 78 else "white", font=petite, anchor="mm")
            px, py = T(porte)
            d.ellipse([px - 5, py - 5, px + 5, py + 5], fill=(200, 40, 40))
    for i, f in enumerate(C.CAMPUS):
        d.rectangle([20, 20 + i * 30, 40, 40 + i * 30], fill=TEINTES[f], outline=(40, 40, 40))
        d.text((50, 30 + i * 30), NOMS[f], fill=(20, 20, 20), font=petite, anchor="lm")
    d.ellipse([22, 117, 32, 127], fill=(200, 40, 40))
    d.text((50, 122), "entrée", fill=(20, 20, 20), font=petite, anchor="lm")
    d.text((20, COTE - 30), "grille : 10 m depuis la croisée des allées", fill=(120, 120, 120), font=petite)
    sortie = os.path.join(RACINE, "QGIS", "rendus", "wehrau_campus_plan.png")
    im.save(sortie)
    print("plan du campus → %s (%d bâtiments)" % (sortie, n))


if __name__ == "__main__":
    main()
