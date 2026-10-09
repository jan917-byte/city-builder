# -*- coding: utf-8 -*-
"""🚪 Le bâtiment en retrait de la rue a une entrée : porte, seuil, auvent, et
une allée de la porte au trottoir (auteur, 2026-10-09).
Flaggable (90) : géométrie vue du joueur ; voie sans IA, seuil et auvent
modélisés dans Blender, le code ne garde que le placement."""
import math

from apercu_carte import dedans
from .cours import _porte as _porte_peinte
from .geometrie import _boite, _ruban
from .reglages import (
    ACCES_LARGEUR,
    ACCES_OUVERTURE,
    FACADE_AVEUGLE,
    FACADE_BANDEAU,
    FACADE_LOGEMENT,
    FACADE_PORTE,
    HAIE_LARGEUR,
    Y_SOL,
    facades,
    facades_m,
)

RETRAIT_MIN = 1.0       # en deçà, la porte donne sur le trottoir
SANS_ENTREE = ("equipement", "friche_industrielle")   # parvis du campus, quais
IMMEUBLES = ("collectif_1995", "barre_1970", "ilot_compact")
ALLEE_IMMEUBLE = 2.0
MUR_ENTREE_MIN = 3.0    # un mur plus court ne reçoit pas d'entrée déplacée
DETOUR_MUR = 4.0        # ce qu'on paie, en mètres d'allée, pour changer de mur
DETOUR_VOISIN = 3.0     # … pour finir devant la parcelle d'à côté
DETOUR_COUDE = 2.0      # … pour un coude
Y_ALLEE = Y_SOL + 0.015
SEUIL = (0.9, 0.15)     # profondeur, hauteur
AUVENT = {False: (0.9, 0.7, 2.30), True: (1.5, 1.6, 2.40)}  # profondeur, débord, sous-face

# ⚠️ Recopie la trame de `materiaux.gd` (ENTRAXE_MIN/MAX, marge 0,32, porte à
# la travée floor(alea·n)) : changer l'un sans l'autre décroche l'allée de la porte.
ENTRAXE = (2.75, 3.70)
MARGE_TRAME = 0.32


def _porte_shader(a, b, alea, famille):
    """(t le long du mur, demi-largeur) de la porte que le shader peint."""
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    # Le JSON arrondit UV2 au millième : le shader voit ce tirage-là.
    alea = round(famille + min(alea, 0.998), 3) - famille
    vise = ENTRAXE[0] + (ENTRAXE[1] - ENTRAXE[0]) * alea
    utile = max(L - 2.0 * MARGE_TRAME, 0.60)
    n = max(1.0, math.floor(utile / vise + 0.5))
    pas = utile / n
    t = MARGE_TRAME + (math.floor(alea * n) + 0.5) * pas
    return t / L, 0.5 * min(1.10, pas * 0.42)


def _proche(p, a, b, marge=0.0):
    """Le point de [a, b] le plus proche de p, à `marge` des deux bouts."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    if L < 1e-9:
        return a
    m = min(marge, L / 2.0)
    t = max(m, min(L - m, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L))
    return (a[0] + dx * t / L, a[1] + dy * t / L)


class Obstacles:
    """Les murs d'un îlot, avec leur boîte : une allée n'en traverse aucun."""

    def __init__(self, anneaux, ilot):
        self.boites = []
        for an in anneaux:
            xs = [p[0] for p in an]
            ys = [p[1] for p in an]
            self.boites.append((min(xs), max(xs), min(ys), max(ys),
                                list(an) + [an[0]]))
        self.ilot = list(ilot) + [ilot[0]]

    def libre(self, route, demi):
        """Le ruban de la route, échantillonné tous les 50 cm sur trois files.
        Les 30 premiers cm touchent la façade, les 60 derniers le bord de l'îlot."""
        total = sum(math.hypot(q[0] - p[0], q[1] - p[1])
                    for p, q in zip(route, route[1:]))
        fait = 0.0
        for p, q in zip(route, route[1:]):
            dx, dy = q[0] - p[0], q[1] - p[1]
            L = math.hypot(dx, dy)
            if L < 1e-9:
                continue
            nx, ny = -dy / L, dx / L
            pas = max(1, int(L / 0.5))
            for j in range(pas + 1):
                s = fait + L * j / float(pas)
                if s < 0.3:
                    continue
                for c in (-demi * 0.9, 0.0, demi * 0.9):
                    x = p[0] + dx * j / float(pas) + nx * c
                    y = p[1] + dy * j / float(pas) + ny * c
                    if total - s > 0.6 and not dedans(self.ilot, (x, y)):
                        return False
                    for x0, x1, y0, y1, an in self.boites:
                        if x0 <= x <= x1 and y0 <= y <= y1 and dedans(an, (x, y)):
                            return False
            fait += L
        return True


def _routes(porte, dehors, cible):
    """Droite, puis en équerre : on sort de la façade, on longe, on arrive."""
    yield [porte, cible], 0.0
    t = (cible[0] - porte[0]) * dehors[0] + (cible[1] - porte[1]) * dehors[1]
    if t > 0.5:
        coude = (porte[0] + dehors[0] * t, porte[1] + dehors[1] * t)
        yield [porte, coude, cible], DETOUR_COUDE


def placer(emp, genres, alea, famille, parcelle, rues_parcelle, bords, obs, st):
    """L'entrée de ce bâtiment, ou None s'il donne sur la rue ou n'en veut pas.

    `genres` est corrigé sur place quand la porte change de mur. `bords` :
    les arêtes de l'îlot et des venelles, donc la rue."""
    if st in SANS_ENTREE:
        return None
    immeuble = st in IMMEUBLES
    demi_allee = (ALLEE_IMMEUBLE if immeuble else ACCES_LARGEUR) / 2.0
    n = len(emp)

    def porte_sur(i):
        a, b = emp[i], emp[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if genres[i] == FACADE_BANDEAU:
            t, demi = 0.5, 1.3
        else:
            t, demi = _porte_shader(a, b, alea, famille)
        u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        # Anneau trigonométrique : le dehors est à droite du parcours.
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), \
            (u[1], -u[0]), u, demi

    def vers_rue(p):
        return min(math.hypot(q[0] - p[0], q[1] - p[1])
                   for q in (_proche(p, a, b) for a, b in bords))

    actuelle = [i for i, g in enumerate(genres) if g == FACADE_PORTE]
    if actuelle:
        if vers_rue(porte_sur(actuelle[0])[0]) <= RETRAIT_MIN:
            return None
    elif min(vers_rue(p) for p in emp) <= RETRAIT_MIN:
        return None

    # Les murs qui peuvent porter l'entrée : la porte d'abord, sinon tout mur
    # percé assez long. La barre garde sa bande filante, sa porte est peinte.
    murs = []
    for i, g in enumerate(genres):
        a, b = emp[i], emp[(i + 1) % n]
        if g == FACADE_AVEUGLE:
            continue
        if i in actuelle:
            murs.append((i, 0.0))
        elif math.hypot(b[0] - a[0], b[1] - a[1]) >= MUR_ENTREE_MIN:
            murs.append((i, DETOUR_MUR))

    pavillon = st == "pavillonnaire"
    candidats = []
    for i, cout_mur in murs:
        porte, dehors, u, demi = porte_sur(i)
        cibles = [(_proche(porte, a, b, ACCES_OUVERTURE / 2.0 + HAIE_LARGEUR),
                   k, 0.0) for k, (a, b) in rues_parcelle]
        # Le pavillon ne sort que par son portail : la haie ferme le reste.
        if not pavillon:
            cibles += [(_proche(porte, a, b, demi_allee), None, DETOUR_VOISIN)
                       for a, b in bords]
        for cible, k, cout_cible in cibles:
            for route, cout_route in _routes(porte, dehors, cible):
                # L'allée part DEVANT la porte, jamais le long du mur.
                v = (route[1][0] - porte[0], route[1][1] - porte[1])
                if v[0] * dehors[0] + v[1] * dehors[1] < 0.5 * math.hypot(*v):
                    continue
                longueur = sum(math.hypot(q[0] - p[0], q[1] - p[1])
                               for p, q in zip(route, route[1:]))
                candidats.append((longueur + cout_mur + cout_cible + cout_route,
                                  i, porte, dehors, u, demi, route, k, longueur))
    candidats.sort(key=lambda c: c[0])
    for _, i, porte, dehors, u, demi, route, k, longueur in candidats:
        if obs.libre(route, demi_allee):
            break
    else:
        return {"route": None}
    e = {"mur": i, "porte": porte, "dehors": dehors, "u": u, "demi": demi,
         "route": route, "arete": k, "longueur": longueur,
         "immeuble": immeuble, "peinte": genres[i] == FACADE_BANDEAU,
         "deplacee": i not in actuelle}
    if e["deplacee"] and not e["peinte"]:
        for j in actuelle:
            _changer(emp, genres, j, FACADE_LOGEMENT)
        _changer(emp, genres, i, FACADE_PORTE)
    return e


def _changer(emp, genres, i, g):
    """Change le genre d'un mur, et le compte rendu des façades avec lui."""
    a, b = emp[i], emp[(i + 1) % len(emp)]
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    facades[genres[i]] -= 1
    facades_m[genres[i]] -= L
    genres[i] = g
    facades[g] += 1
    facades_m[g] += L


def emprise_allee(e):
    """Les rectangles de l'allée : ni place de parking ni arbre n'y tombe."""
    demi = (ALLEE_IMMEUBLE if e["immeuble"] else ACCES_LARGEUR) / 2.0
    out = []
    for p, q in zip(e["route"], e["route"][1:]):
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = math.hypot(dx, dy)
        if L < 1e-9:
            continue
        nx, ny = -dy / L * demi, dx / L * demi
        ux, uy = dx / L * demi, dy / L * demi
        out.append([(p[0] - ux + nx, p[1] - uy + ny), (p[0] - ux - nx, p[1] - uy - ny),
                    (q[0] + ux - nx, q[1] + uy - ny), (q[0] + ux + nx, q[1] + uy + ny)])
    return out


def allee(m, e, coul, G):
    """L'allée, au sol de l'îlot."""
    larg = ALLEE_IMMEUBLE if e["immeuble"] else ACCES_LARGEUR
    _ruban(m, e["route"], larg, coul, G, y=Y_ALLEE, bouts=False)


def entree(m, e, coul_seuil, coul_auvent, coul_porte, G):
    """Le seuil, l'auvent, et la porte vitrée de la barre (sa bande n'en a pas)."""
    p, (nx, ny), u, demi = e["porte"], e["dehors"], e["u"], e["demi"]
    prof, pente = SEUIL
    c = (p[0] + nx * prof / 2.0, p[1] + ny * prof / 2.0)
    n = _boite(m, c, u, 2.0 * demi + 0.6, prof, Y_SOL - 0.05, Y_SOL + pente,
               coul_seuil, G)
    prof, deborde, y = AUVENT[e["immeuble"]]
    c = (p[0] + nx * prof / 2.0, p[1] + ny * prof / 2.0)
    n += _boite(m, c, u, 2.0 * demi + deborde, prof, y, y + 0.12, coul_auvent, G)
    if e["peinte"]:
        a = (p[0] - u[0] * (demi + 0.2), p[1] - u[1] * (demi + 0.2))
        b = (p[0] + u[0] * (demi + 0.2), p[1] + u[1] * (demi + 0.2))
        _porte_peinte(m, a, b, (nx, ny), coul_porte, G)
        n += 2
    return n
