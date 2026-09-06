# -*- coding: utf-8 -*-
"""Dépôt visuel de crue, partagé par les surfaces ; aucun effet de simulation."""

import math
from apercu_carte import dedans
from .geometrie import _d_point_seg


def carte_boue(ilots, routes, chenal, cx, cy, pas=3.0):
    points = [p for d in ilots.values() for p in d["brut"]]
    x0 = min(p[0] for p in points) - 15.0
    y0 = min(p[1] for p in points) - 15.0
    nx = math.ceil((max(p[0] for p in points) + 15.0 - x0) / pas) + 1
    ny = math.ceil((max(p[1] for p in points) + 15.0 - y0) / pas) + 1
    valeurs = [0.0] * (nx * ny)

    def cellules(xa, ya, xb, yb):
        for j in range(max(0, int((ya - y0) / pas)), min(ny, math.ceil((yb - y0) / pas) + 1)):
            for i in range(max(0, int((xa - x0) / pas)), min(nx, math.ceil((xb - x0) / pas) + 1)):
                yield i, j, (x0 + i * pas, y0 + j * pas)

    for d in ilots.values():
        h = d.get("hauteur_eau_max") or 0.0
        if h <= .1 or d["sous_type"] == "riviere":
            continue
        an = d["brut"]
        for i, j, p in cellules(min(p[0] for p in an), min(p[1] for p in an),
                                max(p[0] for p in an), max(p[1] for p in an)):
            if dedans(an + [an[0]], p):
                valeurs[j * nx + i] = max(valeurs[j * nx + i], h)
    for d in routes:
        # La hauteur d'un pont vient de son milieu, pas de ses deux rives.
        if d.get("etat_crue") in ("coupe", "fragile"):
            continue
        h = d.get("hauteur_eau") or 0.0
        if h <= .1:
            continue
        demi = (d["largeur_m"] or 0.0) / 2.0
        for part in d["parts"]:
            for a, b in zip(part, part[1:]):
                for i, j, p in cellules(min(a[0], b[0]) - demi, min(a[1], b[1]) - demi,
                                        max(a[0], b[0]) + demi, max(a[1], b[1]) + demi):
                    if _d_point_seg(p, a, b) <= demi:
                        valeurs[j * nx + i] = max(valeurs[j * nx + i], h)
    # Flou séparable de six mètres, avant la déformation des contours par le shader.
    for dx, dy in ((1, 0), (0, 1)):
        suite = []
        for j in range(ny):
            for i in range(nx):
                suite.append(sum(valeurs[min(ny - 1, max(0, j + dy * k)) * nx
                                          + min(nx - 1, max(0, i + dx * k))] * w
                                 for k, w in ((-2, 1), (-1, 2), (0, 3), (1, 2), (2, 1))) / 9.0)
        valeurs = suite
    pixels = []
    # Le Z de Godot parcourt la carte à l'inverse du Y source.
    for j in range(ny - 1, -1, -1):
        for i in range(nx):
            h = min(1.0, valeurs[j * nx + i] / 6.0)
            rive = chenal.niveau_rive(x0 + i * pas, y0 + j * pas, False)
            pixels.extend((round(h * 255), round((rive + 1) * 127.5)))
    return {"taille": [nx, ny], "repere": [x0 - cx, cy - (y0 + (ny - 1) * pas),
                                              (nx - 1) * pas, (ny - 1) * pas],
            "pixels": pixels}
