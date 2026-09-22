"""Coupe demandée par l'auteur : Ilse, berge naturelle, champs, desserte, bois.

Auteur, 2026-09-18 : la desserte passait entre l'Ilse et les champs ; elle
longe maintenant la lisière. Son tracé (`routes.geojson`, fid 178) est la
limite commune des trois champs et du bois, donc `04b` lui retire sa
demi-chaussée comme à n'importe quel îlot.
"""
import math

from .geometrie import D4C

CHAMPS = (1082, 1083, 1084)
DESSERTE = 178          # la seule route que les trois champs bordent
LIMITE_CULTURE_M = 30.0
# 04b recule chaque bord droit, jamais l'ONGLET : au sommet que deux champs se
# partagent, le joint de la chaussée mordait 0,08 m² de culture.
JEU_ONGLET_M = 0.05


def _reculer(cultures, rives, bords, recul, centre):
    """Coupe les polygones à `recul` mètres de chaque bord, du côté du champ.

    ⚠️ La normale se mesure vers le CENTRE, pas sur le sens de l'anneau :
    l'emprise de `04b` porte une pointe au carrefour 169/170/172, et une
    normale retournée y vidait le champ entier."""
    for a, b in bords:
        longueur = math.dist(a, b)
        if longueur < 1e-6:
            continue
        n = ((a[1] - b[1]) / longueur, (b[0] - a[0]) / longueur)
        if (centre[0] - a[0]) * n[0] + (centre[1] - a[1]) * n[1] < 0:
            n = (-n[0], -n[1])
        p0 = (a[0] + n[0] * recul, a[1] + n[1] * recul)
        suite = []
        for poly in cultures:
            for morceau in D4C.couper(poly, p0, n):
                signe = sum((p[0] - p0[0]) * n[0] + (p[1] - p0[1]) * n[1]
                            for p in morceau) / len(morceau)
                (suite if signe >= -1e-6 else rives).append(morceau)
        cultures = suite
    return cultures


def separer_champ(fid, anneau, relief, desserte):
    """Même découpe pour le champ cultivé, sa rive et sa desserte, sans interstice."""
    if fid not in CHAMPS:
        return [anneau], []
    cultures, rives = [anneau], []
    centre = (sum(p[0] for p in anneau) / len(anneau),
              sum(p[1] for p in anneau) / len(anneau))
    cultures = _reculer(cultures, rives, relief.zones[fid]["riv"],
                        LIMITE_CULTURE_M, centre)
    bords = [(a, b) for part in desserte["parts"] for a, b in zip(part, part[1:])]
    cultures = _reculer(cultures, rives, bords,
                        (desserte["largeur_m"] or 0.0) / 2 - JEU_ONGLET_M, centre)
    return cultures, rives


def axe_en_lisiere(desserte, cx, cy):
    """L'axe de la desserte au repère de Godot, pour déboiser sa chaussée.

    Les arbres du bois sont semés par cellule de plaque, qui ne sait rien de
    la voirie : sans ça la lisière repousse sur la chaussée."""
    return [{"fid": desserte["fid"], "largeur_m": desserte["largeur_m"] or 0.0,
             "points": [[p[0] - cx, cy - p[1]] for p in part]}
            for part in desserte["parts"]]
