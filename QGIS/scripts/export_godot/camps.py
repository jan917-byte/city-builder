"""Les emplacements de containers d'un champ, semés une fois pour toutes.

🏕️ MÊME PRINCIPE QUE LES ALIGNEMENTS D'ARBRES : la chaîne sème les places, la
maquette n'en montre que les N premières selon le nombre de sinistrés logés.
Aucune géométrie n'est décidée à l'exécution, donc le camp ne coûte pas un
triangle de plus quand il grandit.
"""
import math

from .geometrie import _decaler
from .reglages import CAMP_BORD_M, CAMP_CONTAINER_M, CAMP_PLAFOND


def _dedans(anneau, p):
    """Lancer de rayon — un point est-il dans l'anneau ?"""
    x, y = p
    dedans = False
    n = len(anneau)
    for i in range(n):
        ax, ay = anneau[i]
        bx, by = anneau[(i + 1) % n]
        if (ay > y) != (by > y) and \
                x < (bx - ax) * (y - ay) / (by - ay) + ax:
            dedans = not dedans
    return dedans


def emplacements(anneau, entree):
    """Les places d'un champ, rangées depuis l'accès.

    La grille suit le GRAND CÔTÉ du champ, comme les bandes de fauche : un
    camp posé de travers sur un champ en lanière se verrait tout de suite.
    `entree` est le point d'où les gens arrivent (le bord de route le plus
    proche) : les places s'occupent depuis lui, donc un camp à moitié plein
    reste un camp, pas une poussière de boîtes.

    Rend une liste de [x, y_source, angle] en repère SOURCE ; c'est `07` qui
    la passe en repère Godot.
    """
    if len(anneau) < 3:
        return []
    a, b = max(zip(anneau, anneau[1:] + anneau[:1]),
               key=lambda ab: math.dist(*ab))
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    ux, uy = math.cos(ang), math.sin(ang)
    vx, vy = -uy, ux

    # Le bord reste libre : un container contre la haie n'a ni accès ni recul,
    # et la marge absorbe au passage l'arrondi du décalage sur un coin fermé.
    inte = _decaler(anneau, -CAMP_BORD_M)
    if len(inte) < 3:
        return []

    pu = [p[0] * ux + p[1] * uy for p in inte]
    pv = [p[0] * vx + p[1] * vy for p in inte]
    pas_u, pas_v = CAMP_CONTAINER_M
    places = []
    u = min(pu) + pas_u / 2.0
    while u < max(pu) and len(places) < CAMP_PLAFOND * 4:
        v = min(pv) + pas_v / 2.0
        while v < max(pv) and len(places) < CAMP_PLAFOND * 4:
            p = (u * ux + v * vx, u * uy + v * vy)
            # Les quatre coins dedans, pas seulement le centre : sinon un
            # container déborde du champ sur un bord oblique, et c'est la
            # première chose qu'on voit.
            coins = [(p[0] + du * ux + dv * vx, p[1] + du * uy + dv * vy)
                     for du in (-pas_u / 2.4, pas_u / 2.4)
                     for dv in (-pas_v / 2.4, pas_v / 2.4)]
            if all(_dedans(inte, c) for c in coins):
                places.append((p, ang))
            v += pas_v
        u += pas_u
    if entree is not None:
        places.sort(key=lambda t: math.dist(t[0], entree))
    return [[round(p[0], 2), round(p[1], 2), round(g, 4)]
            for p, g in places[:CAMP_PLAFOND]]
