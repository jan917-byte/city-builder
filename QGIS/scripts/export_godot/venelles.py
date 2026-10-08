# -*- coding: utf-8 -*-
"""🚶 La trace d'une venelle pas encore aménagée : herbe, herbe foulée, terre.
Posée AU-DESSUS du pavé de `07` ; Godot la cache quand le joueur aménage."""

import math

from apercu_carte import dedans
from .geometrie import _ruban, _sol
from .reglages import (
    VENELLE_FOULEE_M,
    VENELLE_ONDULATION_M,
    VENELLE_PERIODE_M,
    VENELLE_TERRE_M,
    Y_SOL,
)

PAS_M = 0.5


def _axe_dedans(couloir, ligne, graine, ondulation):
    """Les morceaux de l'axe qui tombent dans le couloir, ondulés.
    La ligne de l'auteur déborde sur le trottoir : on la coupe au couloir."""
    ferme = list(couloir) + [couloir[0]]
    morceaux, courant = [], []
    s0 = 0.0
    phase = (graine % 97) / 97.0 * 2.0 * math.pi
    for a, b in zip(ligne, ligne[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 1e-6:
            continue
        ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        n = max(1, int(L / PAS_M))
        for k in range(n + 1):
            s = L * k / n
            o = ondulation * math.sin(
                2.0 * math.pi * (s0 + s) / VENELLE_PERIODE_M + phase)
            p = (a[0] + ux * s - uy * o, a[1] + uy * s + ux * o)
            if dedans(ferme, p):
                courant.append(p)
            elif courant:
                morceaux.append(courant)
                courant = []
        s0 += L
    if courant:
        morceaux.append(courant)
    return [m for m in morceaux if len(m) >= 2]


def trace(m, couloir, lignes, coul_herbe, coul_foulee, coul_terre, G, graine):
    """Émet la trace d'UN couloir ; `lignes` : [(axe, largeur)].
    Rend la longueur de terre battue posée."""
    _sol(m, couloir, coul_herbe, G, y=Y_SOL + 0.01)
    longueur = 0.0
    for ligne, largeur in lignes:
        # Tout tient dans la largeur : sinon la foulée mord le trottoir.
        ond = min(VENELLE_ONDULATION_M, largeur * 0.1)
        foulee = min(VENELLE_FOULEE_M, largeur - 0.2 - 2.0 * ond)
        for pts in _axe_dedans(couloir, ligne, graine, ond):
            _ruban(m, pts, foulee, coul_foulee, G,
                   y=Y_SOL + 0.02, bouts=False)
            _ruban(m, pts, VENELLE_TERRE_M, coul_terre, G,
                   y=Y_SOL + 0.03, bouts=False)
            longueur += sum(math.hypot(q[0] - p[0], q[1] - p[1])
                            for p, q in zip(pts, pts[1:]))
    return longueur
