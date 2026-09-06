# -*- coding: utf-8 -*-
"""Tabliers reconstruits et ruines, dans le même corridor et le même groupe de rue."""

import math
import random
from .geometrie import _cumul, _le_long, _coupe_boite, D4C
from .reglages import (FOND_ILSE, NAPPE_ILSE, Y_CHAUSSEE, Y_TROTTOIR,
                       PONT_RUINE_BOUT, JEU_CHAUSSEE)


def _cadre(axe, G, raccord=0.0):
    cum = _cumul(axe)
    y0, y1 = G(*axe[0], 0.0)[1], G(*axe[-1], 0.0)[1]
    def poser(s, w, h):
        p, u = _le_long(axe, cum, s)
        x, sol, z = G(p[0] - u[1] * w, p[1] + u[0] * w, 0.0)
        # Le tablier franchit le relief du chenal sur un seul plan.
        y = y0 + (y1 - y0) * s / cum[-1]
        if raccord:
            # Au débouché oblique, chaque bord rejoint le niveau de SA chaussée.
            t = max(0.0, min(1.0, (min(s, cum[-1] - s) - raccord) / 2.0))
            t = t * t * (3 - 2 * t)
            y = sol * (1 - t) + y * t
        return x, y + h, z
    return cum[-1], poser


def _volume(m, dessus, dessous, coul, poser, couvrir=True):
    """Prisme fermé ; ordre local (longueur, travers, hauteur), dessus antihoraire."""
    n = len(dessus)
    for k in range(1, n - 1):
        if couvrir:
            m.triangle(poser(*dessus[0]), poser(*dessus[k]), poser(*dessus[k + 1]), coul)
        m.triangle(poser(*dessous[0]), poser(*dessous[k + 1]), poser(*dessous[k]),
                   tuple(c * .57 for c in coul))
    for k in range(n):
        j = (k + 1) % n
        teinte = tuple(c * (.76 if k % 2 else .88) for c in coul)
        m.triangle(poser(*dessus[k]), poser(*dessous[k]), poser(*dessous[j]), teinte)
        m.triangle(poser(*dessus[k]), poser(*dessous[j]), poser(*dessus[j]), teinte)


def _dalle(m, a, b, gauche, droite, haut, bas, coul, poser, couvrir=True):
    contour = [(a, gauche), (b, gauche), (b, droite), (a, droite)]
    _volume(m, [(s, w, haut) for s, w in contour],
            [(s, w, bas) for s, w in contour], coul, poser, couvrir)


def _garde_corps(m, longueur, demi, poser, casse=False):
    metal = (.075, .115, .105)
    for cote in (-1, 1):
        w = cote * (demi - .22)
        fin = longueur - (1.15 if casse else .35)
        for s in range(max(1, int(fin / 2.0) + 1)):
            x = min(fin, .35 + s * 2.0)
            _dalle(m, x - .055, x + .055, w - .055, w + .055,
                   1.12, .13, metal, poser)
        for h in (.60, 1.12):
            n = 1 if casse else max(1, math.ceil((fin - .2) / 2))
            for k in range(n):
                a, b = .2 + (fin - .2) * k / n, .2 + (fin - .2) * (k + 1) / n
                _dalle(m, a, b, w - .055, w + .055, h, h - .09, metal, poser)


def _pont_neuf(m, axe, larg, ch, coul_tab, coul_ch, coul_par, G, bord=None, chenal=None):
    """Dalle porteuse, trottoirs, corniches, garde-corps et piles élancées."""
    debut = len(m)
    longueur, poser = _cadre(axe, G, raccord=min(8.0, _cumul(axe)[-1] / 4))
    demi = larg / 2.0
    bord = ch / 2 if bord is None else bord
    beton = tuple(min(1.0, c * 1.10) for c in coul_tab)
    coupes = []
    if chenal is not None:
        # Les trois franchissements sont rectilignes : même repère pour chaque coupe.
        _, u = _le_long(axe, _cumul(axe), 0.0)
        def local(p):
            dx, dy = p[0] - axe[0][0], p[1] - axe[0][1]
            return dx * u[0] + dy * u[1], -dx * u[1] + dy * u[0]
        coupes = [(local(p), local(q)) for p, q in chenal.berges_autour(
            min(p[0] for p in axe) - demi, min(p[1] for p in axe) - demi,
            max(p[0] for p in axe) + demi, max(p[1] for p in axe) + demi)]

    def revetement(poly, haut, bas, coul):
        # La berge oblique doit être une arête du revêtement, sinon le sol ressort.
        morceaux = [poly]
        boite = (min(p[0] for p in poly), min(p[1] for p in poly),
                 max(p[0] for p in poly), max(p[1] for p in poly))
        for p, q in coupes:
            if _coupe_boite((p, q), *boite):
                morceaux = [r for mo in morceaux
                            for r in D4C.couper(mo, p, (q[1] - p[1], p[0] - q[0]))]
        for mo in morceaux:
            if len(mo) < 3:
                continue
            if bas is None:
                for k in range(1, len(mo) - 1):
                    m.triangle(poser(*mo[0], haut), poser(*mo[k], haut),
                               poser(*mo[k + 1], haut), coul)
            else:
                _volume(m, [(s, w, haut) for s, w in mo],
                           [(s, w, bas) for s, w in mo], coul, poser)
    # Six mètres de raccord : l'asphalte retrouve la largeur de la rue en douceur.
    rampe = min(6.0, longueur / 3)
    raccord = min(10.0, longueur / 2)
    stations = sorted({0.0, longueur, rampe, longueur - rampe,
                       *(raccord * k / 5 for k in range(1, 6)),
                       *(longueur - raccord * k / 5 for k in range(1, 6)),
                       *(rampe * k / 6 for k in range(1, 6)),
                       *(longueur - rampe * k / 6 for k in range(1, 6))})
    def largeur(s):
        t = min(1.0, min(s, longueur - s) / rampe)
        return bord + (ch / 2 - bord) * t * t * (3 - 2 * t)
    for a, b in zip(stations, stations[1:]):
        # Le revêtement ferme la dalle : un dessus plein traverserait le dévers des accès.
        _dalle(m, a, b, -demi, demi, Y_CHAUSSEE, -.78, beton, poser, couvrir=False)
        wa, wb = largeur(a) + JEU_CHAUSSEE, largeur(b) + JEU_CHAUSSEE
        revetement([(a, -wa), (b, -wb), (b, wb), (a, wa)],
                   Y_CHAUSSEE + .005, None, coul_ch)
        for cote in (-1, 1):
            contour = [(a, cote * wa), (b, cote * wb),
                       (b, cote * demi), (a, cote * demi)]
            if cote < 0:
                contour.reverse()
            revetement(contour, Y_TROTTOIR, Y_CHAUSSEE, coul_tab)
        for cote in (-1, 1):
            w = cote * (demi - .12)
            _dalle(m, a, b, w - .17, w + .17, .18, -.16, beton, poser)
    _garde_corps(m, longueur, demi, poser)
    # Culées courtes ; les piles partagent les travées de plus de vingt mètres.
    for s in (1.1, longueur - 1.1):
        _dalle(m, s - .65, s + .65, -demi + .5, demi - .5,
               -.70, FOND_ILSE - 1.1, coul_par, poser)
    trav = max(1, math.ceil(longueur / 20.0))
    for k in range(1, trav):
        s = longueur * k / trav
        _dalle(m, s - .48, s + .48, -demi + 1.0, demi - 1.0,
               -.74, FOND_ILSE - 1.1, coul_par, poser)
    peinture = (.80, .79, .70)
    for s in range(2, max(3, int(longueur) - 2), 7):
        _dalle(m, s, min(s + 3, longueur - .5), -.07, .07,
               .012, .005, peinture, poser)
    return len(m) - debut


def _acces_pont(m, axe, manque, larg, bord, coul, G, decoupe):
    """Prolonger les trottoirs jusqu'aux carrefours, en épousant leur chaussée."""
    from .voirie import _dessus_trottoir, _bordure
    debut = len(m)
    for bout, rive in ((0, manque[0]), (-1, manque[-1])):
        p = axe[bout]
        longueur = math.dist(p, rive)
        if longueur < .05:
            continue
        u = ((p[0] - rive[0]) / longueur, (p[1] - rive[1]) / longueur)
        def point(s, w):
            return (rive[0] + u[0] * s - u[1] * w,
                    rive[1] + u[1] * s + u[0] * w)
        for cote in (-1, 1):
            # Le palier s'ouvre sur la promenade ; le masque protège les rues voisines.
            ext = larg / 2
            poly = [point(0, cote * (bord + JEU_CHAUSSEE)),
                    point(longueur, cote * (bord + JEU_CHAUSSEE)),
                    point(longueur, cote * (ext + min(2.5, longueur * .4))),
                    point(0, cote * ext)]
            for morceau in decoupe.hors(poly):
                _dessus_trottoir(m, morceau, coul, G)
                centre = tuple(sum(p[k] for p in morceau) / len(morceau) for k in (0, 1))
                for a, b in zip(morceau, morceau[1:] + morceau[:1]):
                    dehors = tuple((a[k] + b[k]) / 2 - centre[k] for k in (0, 1))
                    _bordure(m, a, b, dehors, coul, G)
    return len(m) - debut


def _pont_ruine(m, axe, larg, ch, coul_tab, coul_ch, coul_par, G):
    """Deux arrachements asymétriques : dalle inclinée, béton ouvert et fers tordus."""
    longueur = _cumul(axe)[-1]
    if longueur < 2:
        return 0
    demi = larg / 2.0
    for cote, morceau in enumerate((axe, list(reversed(axe)))):
        _, poser = _cadre(morceau, G)
        rng = random.Random(round(axe[0][0] * 19 + axe[0][1] * 7) + cote * 71)
        bout = min(PONT_RUINE_BOUT, longueur * .23)
        beton = tuple(c * .93 for c in coul_par)
        # L'extrémité partage ses sommets entre les bandes, sans fissure traversante.
        n = max(5, int(larg / 1.8))
        ws = [-demi + larg * k / n for k in range(n + 1)]
        fins = [bout + rng.uniform(-1.45, 1.1) for _ in ws]
        hs = [-rng.uniform(.25, .85) for _ in ws]
        for k in range(n):
            a, b = ws[k:k + 2]
            top = [(0, a, Y_CHAUSSEE), (fins[k], a, hs[k]),
                   (fins[k + 1], b, hs[k + 1]), (0, b, Y_CHAUSSEE)]
            _volume(m, top, [(s, w, h - .72) for s, w, h in top], beton, poser)
            # L'asphalte s'arrache avant le béton, au même plan incliné.
            if abs((a + b) * .5) < ch / 2:
                t = .83
                p = [(0, a, .0), (fins[k] * t, a, hs[k] * t + .02),
                     (fins[k + 1] * t, b, hs[k + 1] * t + .02), (0, b, .0)]
                m.triangle(poser(*p[0]), poser(*p[1]), poser(*p[2]), coul_ch)
                m.triangle(poser(*p[0]), poser(*p[2]), poser(*p[3]), coul_ch)
        _garde_corps(m, max(2.0, bout * .60), demi, poser, True)
        _dalle(m, .2, 1.5, -demi + .45, demi - .45,
               -.65, FOND_ILSE - 1.1, coul_par, poser)
        # Les tiges suivent une cassure, pas une file régulière de clôture.
        for k in range(1, n, 2):
            s, w, h = fins[k], ws[k], hs[k] - .12
            def tordu(x, y, z, h=h, s=s):
                return poser(x, y, z + h + max(0.0, x - s) * .22)
            _dalle(m, s - .18, s + rng.uniform(.65, 1.1), w - .035, w + .035,
                   .035, -.035, (.16, .10, .055), tordu)
        # Éclats affaissés sous la cassure, dans le groupe qui disparaît au chantier fini.
        for _ in range(4):
            s = bout + rng.uniform(.8, 2.6)
            w = rng.uniform(-demi * .75, demi * .75)
            h = NAPPE_ILSE + rng.uniform(-.05, .25) - poser(s, w, 0.0)[1]
            top = [(s - .6, w - .7, h), (s + .8, w - .4, h - .25),
                   (s + .5, w + .8, h - .05), (s - .7, w + .5, h + .2)]
            _volume(m, top, [(x, y, z - 1.0) for x, y, z in top], beton, poser)
    return 2
