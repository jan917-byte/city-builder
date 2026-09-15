# -*- coding: utf-8 -*-
"""Reliefs et végétation des formes SVG ; le décor extérieur prolonge leurs bords."""
import math
import random

import palette as PAL
from apercu_carte import dedans


# Un arbre pour 260 m² : la lisière doit se lire d'en haut sans que la forêt
# devienne un champ d'instances. 109 ha de bois dessinés = ~4 200 arbres.
M2_PAR_ARBRE_BOIS = 260.0
GRAINE = 6021


class Decor(object):
    """Les formes dessinées, interrogeables par point.

    Le test est une boîte englobante puis un point-dans-polygone : la plaque
    pose ~40 000 questions, et les massifs ont des centaines de sommets."""

    def __init__(self, entites):
        self.formes = []
        for genre, anneau in entites:
            if len(anneau) < 3:
                continue
            ferme = list(anneau) + [anneau[0]]
            xs = [p[0] for p in anneau]
            ys = [p[1] for p in anneau]
            self.formes.append((genre, min(xs), min(ys), max(xs), max(ys), ferme))
        # Le bois se pose SUR le massif : il est interrogé d'abord, sinon une
        # forêt de versant ressort en caillou.
        self.formes.sort(key=lambda f: f[0] != "bois")

    def genre(self, p):
        x, y = p
        for genre, x0, y0, x1, y1, ferme in self.formes:
            if x0 <= x <= x1 and y0 <= y <= y1 and dedans(ferme, p):
                return genre
        return None

    def __len__(self):
        return len(self.formes)


def couleurs():
    """La teinte de plaque de chaque genre, déjà linéarisée."""
    return {g: PAL.vers_lineaire(c) for g, c in PAL.DECOR.items()}


def semer(cellules, relief, y_plaque, facteur, G, massifs=None, densite=1.0):
    """Les arbres du bois dessiné, en coordonnées Godot, prêts à rejoindre les
    instances de `paysage.py` — donc sans ombre portée et sans coût de rendu
    par arbre.

    `cellules` sont les mailles de plaque tombées en `bois` : semer dedans
    plutôt que dans l'anneau évite de retirer ce que la ville recouvre, et la
    forêt s'arrête d'elle-même au bord du champ."""
    rng = random.Random(GRAINE)
    out = [[], []]
    for cel in cellules:
        xs = [p[0] for p in cel]
        ys = [p[1] for p in cel]
        aire = (max(xs) - min(xs)) * (max(ys) - min(ys))
        n = aire / M2_PAR_ARBRE_BOIS * densite
        # La partie décimale tirée au sort : sans elle une maille de 16 m sur
        # 260 m² par arbre ne porterait jamais le moindre arbre.
        n = int(n) + (1 if rng.random() < n - int(n) else 0)
        for _ in range(n):
            x = rng.uniform(min(xs), max(xs))
            y = rng.uniform(min(ys), max(ys))
            alt = y_plaque + (relief.z(x, y) * facteur if relief else 0.0)
            # Le massif soulève la plaque : un arbre qui l'ignore reste planté
            # à l'altitude de la vallée, donc enterré dans le versant.
            if massifs is not None:
                alt += massifs.hauteur(x, y)
            p = G(x, y, alt)
            # Essence 1 = le conifère de `paysage.py` : majoritaire en versant.
            espece = 1 if rng.random() < 0.42 else 0
            out[espece].append([round(p[0], 2), round(p[1], 2), round(p[2], 2),
                                round(rng.uniform(0.85, 1.5), 3),
                                round(rng.uniform(0, math.tau), 3)])
    return out


# Une haie tous les 19 m : au-delà la ligne se lit comme des arbres isolés, en
# deçà elle fait un mur opaque sur une carte où un champ fait 200 m de large.
PAS_HAIE = 19.0


def haies(domaines, relief, y_plaque, facteur, G, dans_ville=None,
          massifs=None):
    """La bordure d'un DOMAINE, semée d'arbres — la ferme n'a pas de bâtiment
    dessiné, et c'est la haie qui la rend lisible d'en haut.

    Sans elle, 11 domaines tracés dans Illustrator n'existent nulle part à
    l'écran : leur contour est une géométrie de la source qui ne portait rien.
    `dans_ville` écarte les points qui tomberaient sur du bâti ou une rue."""
    rng = random.Random(GRAINE + 1)
    out = [[], []]
    for _nom, anneau in domaines:
        boucle = list(anneau) + [anneau[0]]
        reste = 0.0
        for a, b in zip(boucle, boucle[1:]):
            long = math.hypot(b[0] - a[0], b[1] - a[1])
            if long < 1e-9:
                continue
            d = reste
            while d < long:
                t = d / long
                x = a[0] + (b[0] - a[0]) * t + rng.uniform(-2.5, 2.5)
                y = a[1] + (b[1] - a[1]) * t + rng.uniform(-2.5, 2.5)
                d += PAS_HAIE
                if dans_ville is not None and dans_ville((x, y)):
                    continue
                alt = y_plaque + (relief.z(x, y) * facteur if relief else 0.0)
                if massifs is not None:
                    alt += massifs.hauteur(x, y)
                p = G(x, y, alt)
                out[0].append([round(p[0], 2), round(p[1], 2), round(p[2], 2),
                               round(rng.uniform(0.6, 1.0), 3),
                               round(rng.uniform(0, math.tau), 3)])
            reste = d - long
    return out


# 🎚️ LEVEL DESIGN — la hauteur d'un massif dessiné sans `altitude_m`. Le fond
# de vallée de `paysage.py` monte à ~420 m : 90 m raccorde la plaque à ses
# crêtes sans écraser une ville de 15 m de haut. La montée court sur 320 m, soit
# 16° — un versant, pas une falaise.
MASSIF_ALTITUDE_M = 90.0
MASSIF_MONTEE_M = 320.0
# La hauteur est échantillonnée sur cette maille puis interpolée : la distance
# exacte au bord coûte un parcours d'arêtes, et la plaque pose 30 000 questions.
MAILLE_HAUTEUR = 40.0


class Massifs(object):
    """Le relief des massifs DESSINÉS — nul partout ailleurs.

    🔴 IL DOIT VALOIR 0 SUR LE BORD DU MASSIF. Le champ voisin, lui, reste à
    l'altitude de la ville : une marche au contact se verrait de partout, et
    c'est pour ça que la montée part du contour et non du centre."""

    def __init__(self, entites, defaut=MASSIF_ALTITUDE_M):
        self.formes = []
        self.sans_altitude = 0
        for genre, anneau, altitude in entites:
            if genre != "relief" or len(anneau) < 3:
                continue
            if altitude is None:
                self.sans_altitude += 1
            self.formes.append((list(anneau) + [anneau[0]],
                                float(altitude) if altitude else defaut))
        self.grille = {}
        self.x0 = self.y0 = 0.0

    def preparer(self):
        """La grille de hauteur, une fois, sur l'étendue des massifs eux-mêmes.

        🔴 PAS SUR CELLE DE LA PLAQUE : le dôme doit être le MÊME des deux
        côtés du bord du monde. Calculé sur la plaque seule, il était tranché
        net à sa limite et la vallée reprenait 90 m plus bas — une falaise
        droite en travers du décor (2026-09-15)."""
        if not self.formes:
            return
        xs = [p[0] for ferme, _a in self.formes for p in ferme]
        ys = [p[1] for ferme, _a in self.formes for p in ferme]
        x0, y0 = min(xs) - MAILLE_HAUTEUR, min(ys) - MAILLE_HAUTEUR
        x1, y1 = max(xs) + MAILLE_HAUTEUR, max(ys) + MAILLE_HAUTEUR
        self.x0, self.y0 = x0, y0
        self.nx = int((x1 - x0) / MAILLE_HAUTEUR) + 2
        self.ny = int((y1 - y0) / MAILLE_HAUTEUR) + 2
        self.grille = [[self._brut(x0 + i * MAILLE_HAUTEUR,
                                   y0 + j * MAILLE_HAUTEUR)
                        for i in range(self.nx)] for j in range(self.ny)]

    def _brut(self, x, y):
        h = 0.0
        for ferme, alt in self.formes:
            if not dedans(ferme, (x, y)):
                continue
            d = min(_d_point_seg((x, y), a, b)
                    for a, b in zip(ferme, ferme[1:]))
            t = min(1.0, d / MASSIF_MONTEE_M)
            # Le plateau uniforme devient une succession de croupes, sous le plafond dessiné.
            croupe = .78 + .14 * math.sin(x / 170 + y / 220) + .08 * math.sin(y / 95 - x / 270)
            h = max(h, alt * t * t * (3.0 - 2.0 * t) * croupe)
        return h

    def hauteur(self, x, y):
        if not self.grille:
            return 0.0
        u = (x - self.x0) / MAILLE_HAUTEUR
        v = (y - self.y0) / MAILLE_HAUTEUR
        i, j = int(u), int(v)
        if i < 0 or j < 0 or i + 1 >= self.nx or j + 1 >= self.ny:
            return 0.0
        fu, fv = u - i, v - j
        g = self.grille
        return ((g[j][i] * (1 - fu) + g[j][i + 1] * fu) * (1 - fv)
                + (g[j + 1][i] * (1 - fu) + g[j + 1][i + 1] * fu) * fv)

    def __len__(self):
        return len(self.formes)


def _d_point_seg(p, a, b):
    vx, vy = b[0] - a[0], b[1] - a[1]
    n = vx * vx + vy * vy
    if n < 1e-12:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    t = max(0.0, min(1.0, ((p[0] - a[0]) * vx + (p[1] - a[1]) * vy) / n))
    return math.hypot(p[0] - a[0] - t * vx, p[1] - a[1] - t * vy)


def cap_plaque(m, anneau, y, coul, G, relief, facteur, massifs):
    """La maille de plaque, posée comme `_cap_plat` mais SOULEVÉE par le massif
    dessiné. La hauteur est prise SOMMET PAR SOMMET : au centre de la maille,
    deux mailles voisines se sépareraient d'une marche de leur écart."""
    from .geometrie import trianguler

    def alt(p):
        h = y + (relief.z(p[0], p[1]) * facteur if relief is not None else 0.0)
        return h + massifs.hauteur(p[0], p[1])

    for ia, ib, ic in trianguler(anneau):
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        m.triangle(G(a[0], a[1], alt(a)), G(b[0], b[1], alt(b)),
                   G(c[0], c[1], alt(c)), coul)
