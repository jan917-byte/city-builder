# -*- coding: utf-8 -*-
"""Le campus dessiné à la main : bâtiments, allées et placette (auteur, 2026-10-08).

Lu par `04c` (une parcelle par îlot), `04d` (les empreintes) et `07` (étages, façades, sols).
🎚️ `PLAN` est du level design : une proposition, à corriger devant `wehrau_campus_plan.png`."""

import math

CAMPUS = (36, 77, 78)

# La croisée des trois îlots, sommet commun de 36, 77 et 78 (EPSG:25832).
ORIGINE = (500259.36, 5600502.76)

# Mètres depuis la croisée, x vers l'est, y vers le nord :
# (x0, x1, y0, y1, façade tournée vers N|S|E|O, niveaux). Le plus grand de l'îlot porte l'entrée d'honneur.
PLAN = {
    36: [  # université : l'Aula au fond, deux ailes sur l'allée
        (19.0, 43.0, 25.0, 41.0, "S", 3),
        (6.0, 17.0, 5.0, 22.0, "S", 2),
        (44.0, 55.0, 5.0, 22.0, "S", 2),
    ],
    77: [  # bibliothèque : la salle de lecture, la réserve au nord
        (-32.0, -10.0, -22.0, 4.0, "E", 3),
        (-20.0, -7.0, 14.0, 32.0, "E", 2),
    ],
    78: [  # institut : trois laboratoires (le troisième demandé le 2026-10-08)
        (8.0, 34.0, -22.0, -6.0, "N", 3),
        (38.0, 49.0, -26.0, -6.0, "N", 3),
        (12.0, 40.0, -52.0, -38.0, "O", 2),
    ],
}

ALLEE_LARGEUR = 4.0     # sur chaque limite commune, moitié de chaque côté
PLACE_RAYON = 8.0       # la placette octogonale de la croisée
PARVIS_LARGEUR = 2.5    # de la porte à l'allée ; abandonné s'il bute sur un mur
PARVIS_MAX = 35.0

_FACES = {"N": (0.0, 1.0), "S": (0.0, -1.0), "E": (1.0, 0.0), "O": (-1.0, 0.0)}


def _monde(x, y):
    return (ORIGINE[0] + x, ORIGINE[1] + y)


def batiments(fid):
    """[(anneau CCW, niveaux, cible de la façade, (porte, direction))] d'un îlot du campus."""
    out = []
    for x0, x1, y0, y1, face, niv in PLAN.get(fid, ()):
        anneau = [_monde(x0, y0), _monde(x1, y0), _monde(x1, y1), _monde(x0, y1)]
        d = _FACES[face]
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        demi = abs(d[0]) * (x1 - x0) / 2 + abs(d[1]) * (y1 - y0) / 2
        porte = _monde(cx + d[0] * demi, cy + d[1] * demi)
        cible = _monde(cx + d[0] * 100.0, cy + d[1] * 100.0)
        out.append((anneau, float(niv), cible, (porte, d)))
    return out


def du_plan(fid, emp):
    """L'entrée de `batiments(fid)` dont l'empreinte est `emp` (centre le plus proche)."""
    c = (sum(p[0] for p in emp) / len(emp), sum(p[1] for p in emp) / len(emp))
    return min(batiments(fid), key=lambda b: math.dist(c, (
        sum(p[0] for p in b[0]) / 4, sum(p[1] for p in b[0]) / 4)))


def _dist_segment(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy or 1e-9)))
    return math.dist(p, (a[0] + t * dx, a[1] + t * dy))


def _sur_bord(p, anneau, tol=0.3):
    return any(_dist_segment(p, anneau[i], anneau[(i + 1) % len(anneau)]) < tol
               for i in range(len(anneau)))


def _rectangle(a, b, largeur, rallonge=0.0):
    ux, uy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(ux, uy)
    ux, uy = ux / L, uy / L
    a = (a[0] - ux * rallonge, a[1] - uy * rallonge)
    b = (b[0] + ux * rallonge, b[1] + uy * rallonge)
    nx, ny = -uy * largeur / 2, ux * largeur / 2
    return [(a[0] - nx, a[1] - ny), (b[0] - nx, b[1] - ny),
            (b[0] + nx, b[1] + ny), (a[0] + nx, a[1] + ny)]


def _ccw(poly):
    s = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
            for i in range(len(poly)))
    return poly if s > 0 else poly[::-1]


def _decouper(sujet, coupe):
    """Sutherland-Hodgman : `sujet` (quelconque) dans `coupe` (convexe)."""
    coupe = _ccw(coupe)
    out = list(sujet)
    for i in range(len(coupe)):
        a, b = coupe[i], coupe[(i + 1) % len(coupe)]
        def cote(p):
            return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        entree, out = out, []
        for k in range(len(entree)):
            p, q = entree[k], entree[(k + 1) % len(entree)]
            sp, sq = cote(p), cote(q)
            if sp >= 0:
                out.append(p)
            if (sp >= 0) != (sq >= 0):
                t = sp / (sp - sq)
                out.append((p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])))
        if not out:
            return []
    return out


def _dedans(poly, p):
    c = False
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        if (a[1] > p[1]) != (b[1] > p[1]) and \
                p[0] < a[0] + (p[1] - a[1]) * (b[0] - a[0]) / (b[1] - a[1]):
            c = not c
    return c


def allees(anneaux):
    """Les bandes convexes des allées (limites communes) et de la placette, toutes îlots confondus.
    `anneaux` : {fid: anneau de l'îlot} pour les trois îlots du campus."""
    bandes = []
    for f, an in anneaux.items():
        autres = [a for g, a in anneaux.items() if g != f]
        for i in range(len(an)):
            a, b = an[i], an[(i + 1) % len(an)]
            mil = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
            if math.dist(a, b) > 1.0 and all(any(_sur_bord(p, o) for o in autres) for p in (a, b, mil)):
                bandes.append(_rectangle(a, b, ALLEE_LARGEUR, ALLEE_LARGEUR / 2))
    r = PLACE_RAYON / math.cos(math.pi / 8)
    bandes.append([(ORIGINE[0] + r * math.cos(math.pi / 8 + k * math.pi / 4),
                    ORIGINE[1] + r * math.sin(math.pi / 8 + k * math.pi / 4)) for k in range(8)])
    return bandes


def sols(fid, anneaux):
    """Les morceaux d'allée, de placette et de parvis qui tombent dans l'îlot `fid`."""
    bandes = allees(anneaux)
    an = anneaux[fid]
    murs = [b[0] for b in batiments(fid)]
    out = [m for m in (_decouper(an, b) for b in bandes) if len(m) >= 3]
    for _, _, _, (porte, d) in batiments(fid):
        for pas in range(1, int(PARVIS_MAX * 2)):
            q = (porte[0] + d[0] * pas / 2, porte[1] + d[1] * pas / 2)
            if not _dedans(an, q) or any(_dedans(m, q) for m in murs):
                break
            if any(_dedans(b, q) for b in bandes):
                fin = (q[0] + d[0], q[1] + d[1])
                parvis = _decouper(an, _rectangle(porte, fin, PARVIS_LARGEUR))
                if len(parvis) >= 3:
                    out.append(parvis)
                break
    return out
