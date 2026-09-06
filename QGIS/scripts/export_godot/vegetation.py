# -*- coding: utf-8 -*-
"""Semis déterministes des arbres et des alignements."""


import math
from apercu_carte import dedans
from importlib import import_module
from .geometrie import (
    aire_signee,
)
from .reglages import (
    CANOPEE_ALIGNEMENT_MAX,
    ESPACEMENT_ALIGNEMENT,
    M2_PAR_ARBRE,
)

D4 = import_module("04_deriver_attributs")


def _semer(anneau, d, rng, relief=None, interdit=None):
    """Le semis d'arbres d'un îlot de sol. Densité dérivée de `canopee`,
    graine fixe : le même export donne toujours la même forêt.

    ⚠️ Le pied de l'arbre suit le talus. Sans ça, les arbres de rive des
    champs 3, 5, 6 et 8 resteraient plantés à 0 — une rangée en lévitation
    au-dessus de la pente, et c'est l'endroit de la carte qu'on regarde.

    `interdit` est un anneau FERMÉ d'où le semis est exclu : la trame de
    stationnement de la place, où un arbre pousserait au milieu d'une place
    peinte. Un rejet de plus dans une boucle qui n'en avait qu'un — la
    position reste tirée, elle n'est pas corrigée."""
    surf = abs(aire_signee(anneau))
    n = int(round((d["canopee"] or 0.0) * surf / M2_PAR_ARBRE))
    if n <= 0:
        return []
    xs = [p[0] for p in anneau]
    ys = [p[1] for p in anneau]
    ferme = list(anneau) + [anneau[0]]
    out = []
    essais = 0
    while len(out) < n and essais < n * 40:
        essais += 1
        x = rng.uniform(min(xs), max(xs))
        y = rng.uniform(min(ys), max(ys))
        if not dedans(ferme, (x, y)):
            continue
        if interdit is not None and dedans(interdit, (x, y)):
            continue
        # Un parc, un bois de rive ou une lisière : le conifère y est courant.
        out.append([x, y, 0.0 if relief is None else relief.z(x, y),
                    rng.uniform(0.75, 1.35), rng.uniform(0.0, 6.2832),
                    1 if rng.random() < 0.24 else 0])
    return out


def _alignement(d, rng):
    """TOUS les emplacements d'alignement d'un tronçon — ceux qui existeraient
    si on plantait — chacun avec le **seuil de canopée** à partir duquel il est
    occupé. Sortie : [x, y, alt, échelle, lacet, seuil].

    ⚠ Ce n'est plus ce que faisait cette fonction. Avant, elle ne sortait que
    les arbres de t0 et leur POSITION dépendait de la densité
    (`t = L·(k+0,5)/n`) : faire monter la canopée redistribuait tout, rien ne
    poussait, l'alignement sautait d'un endroit à l'autre. Maintenant les
    positions sont fixes et seul le seuil décide — un arbre planté reste où il
    est, et les suivants se glissent entre.

    Un tronçon n'est plantable que s'il reste au moins 1 m entre la chaussée et
    la limite d'emprise. Les ruelles du cœur ancien ne le sont jamais : l'effet
    est spatialement inégal par construction, et c'est le sujet."""
    larg = d["largeur_m"] or 0.0
    if larg <= 0.0:
        return []
    ch = min(D4.EMPRISE_CIRCULATION.get(d["hierarchie"], 8.5), larg)
    marge = (larg - ch) / 2.0
    if marge < 1.0:
        return []                               # pas la place d'un arbre
    out = []
    for part in d["parts"]:
        for a, b in zip(part, part[1:]):
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy)
            if L < 1e-9:
                continue
            ux, uy = dx / L, dy / L
            # Le nombre d'EMPLACEMENTS est la densité maximale — un arbre tous
            # les ESPACEMENT_ALIGNEMENT mètres — et ne dépend d'aucune canopée.
            # C'est le SEUIL, plus bas, qui décide lesquels sont occupés.
            n = int(L / ESPACEMENT_ALIGNEMENT)
            for k in range(n):
                t = L * (k + 0.5) / max(1, n)
                cote = 1.0 if rng.random() < 0.5 else -1.0
                ox = -uy * cote * (ch / 2.0 + marge / 2.0)
                oy = ux * cote * (ch / 2.0 + marge / 2.0)
                x, y = a[0] + ux * t + ox, a[1] + uy * t + oy
                # Seuil uniforme sur [0, CANOPEE_ALIGNEMENT_MAX] : à canopée
                # `c`, la part occupée vaut `c / MAX`. À MAX, tout est planté.
                out.append([x, y, 0.0,
                            rng.uniform(0.8, 1.2), rng.uniform(0.0, 6.2832),
                            rng.uniform(0.0, CANOPEE_ALIGNEMENT_MAX)])
    return out
