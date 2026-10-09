# -*- coding: utf-8 -*-
"""🅿️ La cour des barres et des collectifs : parking peint, voitures garées et
une rangée de boxes de garage, dans la limite des places de l'îlot."""
import math
import random

import palette as PAL
from .geometrie import _boite, _ruban, normale
from .reglages import LARGEUR_LIGNE, PLACE_LONGUEUR, Y_SOL
from .voirie import _allee_parc, _case_parc, _suites, _trame_parc, _traits_parc


# Proposition à juger à l'image (auteur, 2026-10-09) : les tissus dont la cour
# reçoit un parking. Une ligne de plus ici suffit à en équiper un autre.
COURS_PARKING = ("barre_1970", "collectif_1995")
MARGE_COUR = 1.5          # ce qu'une place laisse devant un mur ou un jardin
PART_GARAGES = 0.25       # la part des places de l'îlot rangée en boxes
GARAGES_MIN = 4           # en dessous, une rangée de boxes ne se lit pas
GARAGE_HAUTEUR = 2.4
OCCUPATION = 0.75         # une place sur quatre reste libre
Y_ASPHALTE = Y_SOL + 0.004
Y_LIGNE = Y_SOL + 0.012


def _quad(m, coins, y, coul, G):
    a, b, c, d = coins
    if (b[0] - a[0]) * (d[1] - a[1]) - (b[1] - a[1]) * (d[0] - a[0]) < 0.0:
        a, b, c, d = d, c, b, a
    for p, q, r in ((a, b, c), (a, c, d)):
        m.triangle(G(p[0], p[1], y), G(q[0], q[1], y), G(r[0], r[1], y), coul)


def _porte(m, a, b, dehors, coul, G):
    """Une porte basculante peinte sur la façade, 3 cm devant le mur."""
    ux, uy = b[0] - a[0], b[1] - a[1]
    l = math.hypot(ux, uy)
    ux, uy = ux / l, uy / l
    a = (a[0] + ux * 0.2 + dehors[0] * 0.03, a[1] + uy * 0.2 + dehors[1] * 0.03)
    b = (b[0] - ux * 0.2 + dehors[0] * 0.03, b[1] - uy * 0.2 + dehors[1] * 0.03)
    y0, y1 = Y_SOL, Y_SOL + 2.05
    p, q, r = G(a[0], a[1], y0), G(b[0], b[1], y0), G(b[0], b[1], y1)
    vers = [G(a[0] + dehors[0], a[1] + dehors[1], y0)[k] - p[k] for k in range(3)]
    if sum(n * v for n, v in zip(normale(p, q, r), vers)) < 0.0:
        a, b = b, a
        p, q, r = G(a[0], a[1], y0), G(b[0], b[1], y0), G(b[0], b[1], y1)
    s = G(a[0], a[1], y1)
    m.triangle(p, q, r, coul)
    m.triangle(p, r, s, coul)


def amenager(m, anneau, obstacles, places, graine, G):
    """Peint la cour dans `m` (le groupe de l'îlot doit être ouvert).

    Rend (places peintes, boxes, fentes) ; `fentes` = x, y, z, dx, dz par
    voiture garée, en Godot, pour `trafic.gd`."""
    t = _trame_parc(anneau, obstacles, MARGE_COUR)
    if t is None or not t["cases"] or places <= 0:
        return 0, 0, []
    rangees = {}
    for k, r, j in t["cases"]:
        rangees.setdefault((k, r), []).append(j)
    files = [(k, r, a, b) for (k, r), js in rangees.items()
             for a, b in _suites(sorted(js))]

    # Les boxes : la plus longue file sans vis-à-vis, le dos au mur ou au vide.
    def seule(f):
        k, r, a, b = f
        en_face = set(rangees.get((k, 1 - r), ()))
        return not any(j in en_face for j in range(a, b + 1))

    garages = []
    n_box = max(GARAGES_MIN, int(round(places * PART_GARAGES)))
    candidates = [f for f in files if seule(f) and f[3] - f[2] + 1 >= GARAGES_MIN]
    if candidates and places > GARAGES_MIN:
        k, r, a, b = max(candidates, key=lambda f: f[3] - f[2])
        n_box = min(n_box, b - a + 1, places)
        garages = [(k, r, j) for j in range(a, a + n_box)]
        files.remove((k, r, a, b))
        if a + n_box <= b:
            files.append((k, r, a + n_box, b))

    # Les places : les plus longues files d'abord, jusqu'au compte de l'îlot.
    reste = places - len(garages)
    cases = []
    for k, r, a, b in sorted(files, key=lambda f: (f[2] - f[3], f[0], f[1], f[2])):
        if reste <= 0:
            break
        n = min(reste, b - a + 1)
        cases.extend((k, r, j) for j in range(a, a + n))
        reste -= n
    # Une place seule au milieu d'une cour se lit comme une erreur.
    if not garages and len(cases) < GARAGES_MIN:
        return 0, 0, []

    asphalte = PAL.vers_lineaire(PAL.MINERAL)
    for c in cases:
        _quad(m, _case_parc(t, c)[2], Y_ASPHALTE, asphalte, G)
    for c in cases + garages:
        _quad(m, _allee_parc(t, c), Y_ASPHALTE, asphalte, G)
    marquage = PAL.vers_lineaire(PAL.MARQUAGE)
    for p, q in _traits_parc(t, cases):
        _ruban(m, [p, q], LARGEUR_LIGNE, marquage, G, y=Y_LIGNE, bouts=False)

    rng = random.Random(graine)
    if garages:
        premiere = _case_parc(t, garages[0])
        derniere = _case_parc(t, garages[-1])
        a, b = premiere[2][0], derniere[2][1]
        long_u = math.hypot(b[0] - a[0], b[1] - a[1])
        u = ((b[0] - a[0]) / long_u, (b[1] - a[1]) / long_u)
        coins = premiere[2][:1] + derniere[2][1:3] + premiere[2][3:]
        centre = (sum(p[0] for p in coins) / 4.0, sum(p[1] for p in coins) / 4.0)
        mur = PAL.vers_lineaire(PAL.GARAGE_MUR)
        _boite(m, centre, u, long_u, PLACE_LONGUEUR, Y_SOL, Y_SOL + GARAGE_HAUTEUR,
               mur, G)
        _boite(m, centre, u, long_u + 0.4, PLACE_LONGUEUR + 0.5,
               Y_SOL + GARAGE_HAUTEUR, Y_SOL + GARAGE_HAUTEUR + 0.18,
               PAL.vers_lineaire(PAL.TOIT_PLAT_GRIS), G)
        # Toutes les portes d'une rangée ont la même teinte, sauf celles qu'un
        # propriétaire a changées.
        teinte = rng.choice(PAL.PORTES_GARAGE)
        for c in garages:
            _, dehors, q = _case_parc(t, c)
            bord = q[:2] if c[1] == 0 else q[2:]
            autre = rng.choice(PAL.PORTES_GARAGE) if rng.random() < 0.2 else teinte
            _porte(m, bord[0], bord[1], dehors, PAL.vers_lineaire(autre), G)

    occupees = [c for c in cases if rng.random() < OCCUPATION]
    # Mêlées : quand le parking se vide, il se vide un peu partout à la fois.
    rng.shuffle(occupees)
    fentes = []
    for c in occupees:
        (x, y), (dx, dy), _ = _case_parc(t, c)
        g0 = G(x, y, Y_SOL)
        g1 = G(x + dx, y + dy, Y_SOL)
        fentes.extend([round(g0[0], 2), round(g0[1], 3), round(g0[2], 2),
                       round(g1[0] - g0[0], 3), round(g1[2] - g0[2], 3)])
    return len(cases), len(garages), fentes
