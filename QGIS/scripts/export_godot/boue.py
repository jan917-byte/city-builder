# -*- coding: utf-8 -*-
"""Dépôt spatial de la crue, identique au champ qui calcule les dégâts."""

import math
from importlib import import_module


def carte_boue(ilots, routes, chenal, cx, cy, pas=3.0, champ=None):
    crue = import_module("04e_crue")
    champ = champ or crue.ChampCrue(chenal.rivieres)
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
            "pixels": pixels,
            "annonce": _carte_annonce(champ, crue.NIVEAU_ANNONCE_M, chenal,
                                      x0 - MARGE_ANNONCE_M, y0 - MARGE_ANNONCE_M,
                                      nx * pas + 2 * MARGE_ANNONCE_M,
                                      ny * pas + 2 * MARGE_ANNONCE_M, cx, cy)}


# La crue annoncée sort de l'enveloppe des îlots, par la campagne : sans cette
# marge, la carte se coupait net au sud.
MARGE_ANNONCE_M = 120.0


# 🌊 LA PROCHAINE CRUE, pour la carte des dangers : `ChampCrue.annonce`, que
# `04e` lit au centre de chaque bâtiment, sur toute la ville. 12 m et non 3 : le champ est
# linéaire en distance à l'eau, et 47 µs le point (mesuré) font 20 s à 3 m.
def _carte_annonce(champ, niveau, chenal, x0, y0, largeur, hauteur, cx, cy,
                   pas=12.0):
    nx = math.ceil(largeur / pas) + 1
    ny = math.ceil(hauteur / pas) + 1
    pixels = []
    for j in range(ny - 1, -1, -1):
        y = y0 + j * pas
        for i in range(nx):
            h = champ.annonce((x0 + i * pas, y), niveau) / niveau
            pixels.append(round(max(0.0, min(1.0, h)) * 255))
    ysud, ynord = chenal._y_rive
    # `fil` en Z de Godot : 0 à l'amont (sud), 1 à l'aval, comme `position_fil_eau`.
    return {"taille": [nx, ny], "niveau_m": niveau, "fil_z": [cy - ysud, cy - ynord],
            "repere": [x0 - cx, cy - (y0 + (ny - 1) * pas),
                       (nx - 1) * pas, (ny - 1) * pas],
            "pixels": pixels}
