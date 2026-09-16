# -*- coding: utf-8 -*-
"""Dépôt spatial de la crue, identique au champ qui calcule les dégâts."""

import math
from importlib import import_module


def carte_boue(ilots, routes, chenal, cx, cy, pas=3.0, champ=None):
    champ = champ or import_module("04e_crue").ChampCrue(chenal.rivieres)
    points = [p for d in ilots.values() for p in d["brut"]]
    x0 = min(p[0] for p in points) - 15.0
    y0 = min(p[1] for p in points) - 15.0
    nx = math.ceil((max(p[0] for p in points) + 15.0 - x0) / pas) + 1
    ny = math.ceil((max(p[1] for p in points) + 15.0 - y0) / pas) + 1
    pixels = []
    # Le Z de Godot parcourt la carte à l'inverse du Y source.
    for j in range(ny - 1, -1, -1):
        y = y0 + j * pas
        for i in range(nx):
            x = x0 + i * pas
            h = min(1.0, champ.ouverture((x, y)) / 6.0)
            rive = chenal.niveau_rive(x, y, False)
            pixels.extend((round(h * 255), round((rive + 1) * 127.5)))
    return {"taille": [nx, ny], "repere": [x0 - cx, cy - (y0 + (ny - 1) * pas),
                                              (nx - 1) * pas, (ny - 1) * pas],
            "pixels": pixels}
