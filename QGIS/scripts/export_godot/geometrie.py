# -*- coding: utf-8 -*-
"""Primitives, terrain et calculs géométriques partagés."""


import math
import random
from apercu_carte import dedans
from importlib import import_module
from .reglages import (
    BORD_EAU_TOL,
    FOND_ILSE,
    LIMITE_MITRE_RUBAN,
    M2_PAR_ARBRE_JARDIN,
    NAPPE_ILSE,
    PARAPET_H,
    PART_JARDINS_ARBORES,
    RIVE_DROITE_Y,
    RIVE_GAUCHE_Y,
    TALUS_BAS,
    TALUS_LARGEUR,
    TALUS_PAS,
    Y_CHAUSSEE,
    Y_SOL,
)

D4C = import_module("04c_parcelles")


# ================================================================== le chenal

class Chenal(object):
    """L'Ilse creusée dans une carte plate — et la plaque de sol qu'elle troue.

    Il n'y a plus de champ d'altitude : le sol est à 0 partout, et le seul
    relief est ce chenal à murs verticaux. Cette classe ne sait donc faire que
    deux choses, et c'est le but :
      · dire quelles ARÊTES sont des berges (les autres sont les coupures entre
        deux îlots de rivière, au milieu de l'eau — il ne faut pas y bâtir un
        mur) ;
      · DÉCOUPER la plaque de sol le long de ces berges, à l'exact.

    ⚠️ Le découpage, et c'est le seul endroit un peu retors : une maille que la
    berge traverse est coupée par la DROITE de chaque arête de berge qui la
    traverse, puis on ne garde que les morceaux dont le centre est hors de
    l'eau. La coupe ne fait que subdiviser — c'est le test d'appartenance qui
    décide, jamais la droite. Une droite qui mord trop loin ne peut donc pas
    manger du sol : le morceau qu'elle détache est simplement gardé.
    """

    def __init__(self, anneaux_riviere):
        self.rivieres = [list(a) + [a[0]] for a in anneaux_riviere]
        # Les arêtes qui apparaissent DEUX FOIS sont des limites entre deux
        # îlots de rivière : elles traversent l'eau, elles ne sont pas des
        # berges. Six îlots d'eau bout à bout en produisent cinq.
        compte = {}
        brut = []
        for a in anneaux_riviere:
            for i in range(len(a)):
                p, q = a[i], a[(i + 1) % len(a)]
                if math.hypot(q[0] - p[0], q[1] - p[1]) < 1e-9:
                    continue
                cle = tuple(sorted((_cle(p), _cle(q))))
                compte[cle] = compte.get(cle, 0) + 1
                brut.append((p, q, cle))
        self.cles_berges = {c for c, k in compte.items() if k == 1}
        self.berges = [(p, q) for p, q, c in brut if compte[c] == 1]
        self.internes = len(brut) - len(self.berges)
        # Index par maille : sans lui, chaque maille de la plaque teste les
        # ~200 arêtes de berge une par une.
        self.pas = 40.0
        self.idx = {}
        self._coupes_rive = {}
        ys = [p[1] for a in self.rivieres for p in a]
        self._y_rive = (min(ys), max(ys)) if ys else (0.0, 0.0)
        for k, (p, q) in enumerate(self.berges):
            for cx in range(int(min(p[0], q[0]) // self.pas),
                            int(max(p[0], q[0]) // self.pas) + 1):
                for cy in range(int(min(p[1], q[1]) // self.pas),
                                int(max(p[1], q[1]) // self.pas) + 1):
                    self.idx.setdefault((cx, cy), []).append(k)

    def dans_eau(self, p):
        return any(dedans(r, p) for r in self.rivieres)

    def fil(self, y):
        """La position le long de l'eau, 0 à l'amont et 1 à l'aval — même
        définition qu'en `04` (`position_fil_eau`), sur les mêmes sommets."""
        ysud, ynord = self._y_rive
        return 0.0 if ynord <= ysud else max(0.0, min(1.0,
            (ynord - y) / (ynord - ysud)))

    def niveau_rive(self, x, y, eau_plate=True):
        """Décalage vertical des deux rives ; l'eau reste horizontale.

        L'Ilse coule vers le sud : face à l'aval, sa rive gauche est à l'est.
        Une coupe horizontale donne son milieu local même dans le grand S.
        """
        # La coupe doit passer par le sommet : l'arrondi à 25 cm le noyait.
        cle = min(max(y, self._y_rive[0] + 1e-4), self._y_rive[1] - 1e-4)
        coupe = self._coupes_rive.get(cle)
        if coupe is None:
            yc = cle
            xs = []
            for a in self.rivieres:
                for p, q in zip(a, a[1:]):
                    if (p[1] <= yc < q[1]) or (q[1] <= yc < p[1]):
                        t = (yc - p[1]) / (q[1] - p[1])
                        xs.append(p[0] + (q[0] - p[0]) * t)
            coupe = (min(xs), max(xs)) if len(xs) >= 2 else (x, x)
            self._coupes_rive[cle] = coupe
        gauche_x, droite_x = coupe
        if eau_plate and gauche_x + 1e-5 < x < droite_x - 1e-5:
            return 0.0
        milieu = (gauche_x + droite_x) / 2.0
        return RIVE_GAUCHE_Y if x > milieu else RIVE_DROITE_Y

    def est_berge(self, a, b):
        return tuple(sorted((_cle(a), _cle(b)))) in self.cles_berges

    def _orienter_rives(self):
        """Chaque arête de rive reçoit le sens de l'aval : les deux rives sont
        deux chaînes, parcourues depuis leur bout nord. Tient dans le grand S,
        où une arête peut courir d'est en ouest."""
        ysud, ynord = self._y_rive
        bord = lambda p: min(abs(p[1] - ysud), abs(p[1] - ynord)) < 0.5  # noqa: E731
        # Le bouchon au bord de la carte traverse l'eau : ce n'est pas une rive.
        self._rives = [k for k, (p, q) in enumerate(self.berges)
                       if not (bord(p) and bord(q))]
        garde = set(self._rives)
        voisins = {}
        for k in self._rives:
            p, q = self.berges[k]
            for s in (_cle(p), _cle(q)):
                voisins.setdefault(s, []).append(k)
        self._aval = {}
        for k in self._rives:
            if k in self._aval:
                continue
            # La composante de k, puis son bout le plus au nord.
            comp, pile = {k}, [k]
            while pile:
                e = pile.pop()
                for s in map(_cle, self.berges[e]):
                    for f in voisins[s]:
                        if f not in comp:
                            comp.add(f)
                            pile.append(f)
            bouts = [s for e in comp for s in map(_cle, self.berges[e])
                     if len(voisins[s]) == 1]
            if not bouts:
                bouts = [max((s for e in comp for s in map(_cle, self.berges[e])),
                             key=lambda s: s[1])]
            s = max(bouts, key=lambda s: s[1])
            prec = None
            for _ in range(len(comp)):
                suite = [f for f in voisins[s] if f != prec and f in comp
                         and f not in self._aval]
                if not suite:
                    break
                e = suite[0]
                p, q = self.berges[e]
                a, b = (p, q) if _cle(p) == s else (q, p)
                L = math.hypot(b[0] - a[0], b[1] - a[1])
                self._aval[e] = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
                s, prec = _cle(b), e
            # Un nœud à trois arêtes coupe la marche : le reste prend le sud.
            for e in comp:
                if e not in self._aval:
                    p, q = self.berges[e]
                    L = math.hypot(q[0] - p[0], q[1] - p[1])
                    sg = -1.0 if q[1] > p[1] else 1.0
                    self._aval[e] = (sg * (q[0] - p[0]) / L, sg * (q[1] - p[1]) / L)
        self._garde = garde

    def courant(self, x, y, portee=40.0):
        """(distance à la rive la plus proche, sens de l'aval en carte)."""
        if not hasattr(self, "_aval"):
            self._orienter_rives()
        vus = []
        for p, q in self.berges_autour(x - portee, y - portee,
                                       x + portee, y + portee):
            k = self._index_berge(p, q)
            if k not in self._garde:
                continue
            vus.append((_dist_segment((x, y), p, q), self._aval[k]))
        if not vus:
            return portee, 0.0, -1.0
        d0 = min(d for d, _ in vus)
        tx = ty = 0.0
        for d, (ax, ay) in vus:
            if d <= d0 + 4.0:
                w = 1.0 / (d + 1.0)
                tx += ax * w
                ty += ay * w
        n = math.hypot(tx, ty) or 1.0
        return d0, tx / n, ty / n

    def _index_berge(self, p, q):
        if not hasattr(self, "_ids"):
            self._ids = {tuple(sorted((_cle(a), _cle(b)))): k
                         for k, (a, b) in enumerate(self.berges)}
        return self._ids[tuple(sorted((_cle(p), _cle(q))))]

    def niveau_voirie(self, x, y):
        """Un ouvrage relie les terrasses ; toucher l'eau ne le rabaisse pas à zéro."""
        niveau = self.niveau_rive(x, y, False)
        cle = min(max(y, self._y_rive[0] + 1e-4), self._y_rive[1] - 1e-4)
        gauche, droite = self._coupes_rive[cle]
        if droite - gauche < 1e-6 or not gauche < x < droite:
            return niveau
        t = (x - gauche) / (droite - gauche)
        return RIVE_DROITE_Y * (1.0 - t) + RIVE_GAUCHE_Y * t

    def berges_autour(self, x0, y0, x1, y1):
        """Les arêtes de berge qui peuvent traverser la maille."""
        vus = set()
        for cx in range(int(x0 // self.pas), int(x1 // self.pas) + 1):
            for cy in range(int(y0 // self.pas), int(y1 // self.pas) + 1):
                vus.update(self.idx.get((cx, cy), ()))
        return [self.berges[k] for k in vus]

    def plaque(self, x0, y0, x1, y1, pas, relief=None):
        """Le sol : des morceaux plats à 0, troués là où passe le chenal.

        `relief` ne creuse rien ici — il dit seulement OÙ la maille de 16 m est
        trop grossière. Sous un talus elle est redébitée sur la grille absolue
        de `TALUS_PAS` : c'est la même grille que celle du talus lui-même, donc
        les deux surfaces tombent sur les mêmes sommets et l'une ne peut pas
        ressortir de l'autre.
        """
        out = []
        approx = 0
        nx = int(math.ceil((x1 - x0) / pas))
        ny = int(math.ceil((y1 - y0) / pas))
        for j in range(ny):
            for i in range(nx):
                ax, ay = x0 + i * pas, y0 + j * pas
                bx, by = min(ax + pas, x1), min(ay + pas, y1)
                maille = [(ax, ay), (bx, ay), (bx, by), (ax, by)]
                if relief is not None and relief.boite_active(ax, ay, bx, by):
                    cellules = _grille(maille, TALUS_PAS)
                else:
                    cellules = [maille]
                for cel in cellules:
                    cx0 = min(p[0] for p in cel)
                    cy0 = min(p[1] for p in cel)
                    cx1 = max(p[0] for p in cel)
                    cy1 = max(p[1] for p in cel)
                    proches = [s for s in self.berges_autour(cx0, cy0, cx1, cy1)
                               if _coupe_boite(s, cx0, cy0, cx1, cy1)]
                    if not proches:
                        c = (sum(p[0] for p in cel) / len(cel),
                             sum(p[1] for p in cel) / len(cel))
                        if not self.dans_eau(c):
                            out.append(cel)
                        continue
                    if len(proches) > 1:
                        approx += 1
                    morceaux = [cel]
                    for (p, q) in proches:
                        nrm = (q[1] - p[1], -(q[0] - p[0]))
                        suite = []
                        for mo in morceaux:
                            suite.extend(D4C.couper(mo, p, nrm))
                        morceaux = suite
                    for mo in morceaux:
                        if len(mo) < 3:
                            continue
                        c = (sum(p[0] for p in mo) / len(mo),
                             sum(p[1] for p in mo) / len(mo))
                        if not self.dans_eau(c):
                            out.append(mo)
        return out, approx


def _cle(p):
    return (round(p[0], 4), round(p[1], 4))


def _dist_segment(m, p, q):
    vx, vy = q[0] - p[0], q[1] - p[1]
    L2 = vx * vx + vy * vy
    t = 0.0 if L2 < 1e-12 else max(0.0, min(1.0, ((m[0] - p[0]) * vx
                                                + (m[1] - p[1]) * vy) / L2))
    return math.hypot(m[0] - p[0] - t * vx, m[1] - p[1] - t * vy)


def _coupe_boite(seg, x0, y0, x1, y1):
    """L'arête passe-t-elle dans la maille ? Test de boîtes, volontairement
    large : une arête gardée pour rien ne coûte qu'une coupe sans effet."""
    (px, py), (qx, qy) = seg
    return not (max(px, qx) < x0 or min(px, qx) > x1
                or max(py, qy) < y0 or min(py, qy) > y1)


class Relief(object):
    """La descente des champs vers l'Ilse — la seule chose qui ne soit pas
    plate sur la carte, avec le chenal lui-même.

    UNE SEULE FONCTION, `z(x, y)`, et tout ce qui touche le sol la lit : la
    plaque, le champ, ses bandes de fauche, ses arbres, et le haut du mur de
    quai. C'est ce qui garantit qu'aucune de ces surfaces ne peut se fendre
    sur une autre — elles partagent la même vérité, pas une recopie.

        z = CREUX · f(distance à l'eau) · g(distance aux autres bords)

    · `f` descend de 1 au bord de l'eau à 0 à `TALUS_LARGEUR` : c'est la pente
      dessinée par l'auteur, droite, avec sa cassure en haut.
    · `g` la REMONTE à 0 dès qu'on approche d'un autre bord du champ, sur la
      même distance. C'est elle qui fait tout le travail difficile, et sans
      elle il aurait fallu trois cas particuliers :
        — au raccord ville/champ, le talus se relève sur 10 m et le mur de
          quai sort du sol tout seul, au lieu d'une marche de 2 m ;
        — un pont qui traverse un champ garde sa terre à 0 de part et d'autre :
          la route est un couloir DEHORS de l'emprise, donc `g` s'y annule ;
        — rien ne déborde jamais de l'emprise du champ, donc ni la voirie ni
          les trottoirs n'ont à savoir que le relief existe.

    ⚠️ Le creux est mesuré depuis `Y_SOL`, pas depuis 0 : la surface du champ
    est ce qui doit toucher l'eau, pas le plan de référence.
    """

    CREUX = TALUS_BAS - Y_SOL          # −2,20 m

    def __init__(self, chenal, champs):
        """`champs` : {fid: anneau d'emprise ouvert} des îlots `champ`."""
        self.chenal = chenal
        self.zones = {}
        bords = {}
        for an in champs.values():
            for a, b in zip(an, an[1:] + an[:1]):
                cle = tuple(sorted((_cle(a), _cle(b))))
                bords[cle] = bords.get(cle, 0) + 1
        for fid in sorted(champs):
            an = list(champs[fid])
            n = len(an)
            riv, autres = [], []
            for i in range(n):
                a, b = an[i], an[(i + 1) % n]
                if math.hypot(b[0] - a[0], b[1] - a[1]) < 1e-9:
                    continue
                if _sur_la_berge(a, b, chenal):
                    riv.append((a, b))
                elif bords[tuple(sorted((_cle(a), _cle(b))))] == 1:
                    autres.append((a, b))
            if not riv:
                continue
            sens = 1.0 if aire_signee(an) > 0.0 else -1.0
            lignes = []
            for (a, b) in riv:
                dx, dy = b[0] - a[0], b[1] - a[1]
                L = math.hypot(dx, dy)
                # Normale INTÉRIEURE : à gauche de a→b si l'anneau est
                # trigonométrique. On mesure le sens au lieu de le supposer —
                # une normale retournée mettrait le talus dans la rivière.
                nx, ny = sens * (-dy / L), sens * (dx / L)
                lignes.append(((a[0] + nx * TALUS_LARGEUR,
                                a[1] + ny * TALUS_LARGEUR), (nx, ny)))
            xs = [p[0] for p in an]
            ys = [p[1] for p in an]
            self.zones[fid] = {
                "ferme": an + [an[0]],
                "riv": riv, "autres": autres, "lignes": lignes,
                "boite": (min(xs), min(ys), max(xs), max(ys)),
                "longueur": sum(math.hypot(b[0] - a[0], b[1] - a[1])
                                for a, b in riv),
            }

    # -- lecture -----------------------------------------------------------

    def z(self, x, y):
        """Le creusement au point, ≤ 0. Hors d'un champ riverain : 0,0 pile."""
        if not self.zones:
            return 0.0
        p = (x, y)
        val = 0.0
        for z in self.zones.values():
            bx0, by0, bx1, by1 = z["boite"]
            if x < bx0 or x > bx1 or y < by0 or y > by1:
                continue
            d = _d_segments(p, z["riv"])
            if d >= TALUS_LARGEUR:
                continue
            # 🔴 PIÈGE PAYÉ LE 2026-08-18, et il se voyait à l'écran : un point
            # POSÉ SUR la rive n'est ni dedans ni dehors pour `dedans()`, et il
            # ressortait à 0 pendant que ses voisins descendaient à −2,20. La
            # plaque et le talus sont justement coupés SUR cette ligne : la
            # berge se hérissait de dents grises d'un mètre, une par sommet.
            # Le bord de l'eau appartient au champ, point.
            if d > 0.05 and not dedans(z["ferme"], p):
                continue
            f = 1.0 - d / TALUS_LARGEUR
            g = 1.0
            if z["autres"]:
                g = min(1.0, _d_segments(p, z["autres"]) / TALUS_LARGEUR)
            # Les deux terrasses rejoignent la même nappe, malgré leur ±1 m.
            creux = self.CREUX - self.chenal.niveau_rive(x, y, False)
            val = min(val, creux * f * g)
        return val

    def boite_active(self, x0, y0, x1, y1):
        """La boîte touche-t-elle un talus ? Sert à décider d'un débit fin,
        jamais à décider d'une altitude.

        ⚠️ VRAIE DISTANCE au segment, et pas recouvrement de boîtes. Mesuré le
        2026-08-18 : le test par boîtes faisait passer la plaque de 8 000 à
        28 000 triangles, parce que la rive du champ 3 est une diagonale de
        266 m dont la boîte englobante couvre un quart de la carte."""
        for z in self.zones.values():
            bx0, by0, bx1, by1 = z["boite"]
            # La boîte du CHAMP en plus de la distance à sa rive : sans elle on
            # débitait aussi la plaque au milieu de l'eau et sur le quai d'en
            # face, où le relief vaut 0 — 3 000 triangles pour rien.
            if x1 < bx0 or x0 > bx1 or y1 < by0 or y0 > by1:
                continue
            for (a, b) in z["riv"]:
                if _d_boite_segment(x0, y0, x1, y1, a, b) < TALUS_LARGEUR:
                    return True
        return False

    # -- découpe -----------------------------------------------------------

    def trier(self, fid, morceau):
        """Coupe un morceau de champ par les droites de haut de talus et rend
        [(morceau, en_pente)]. Les deux familles sortent de LA MÊME découpe :
        elles pavent le champ exactement, sans recouvrement ni fente."""
        z = self.zones.get(fid)
        if z is None:
            return [(morceau, False)]
        morceaux = [morceau]
        for (p0, nrm) in z["lignes"]:
            suite = []
            for mo in morceaux:
                suite.extend(D4C.couper(mo, p0, nrm))
            morceaux = suite
        out = []
        for mo in morceaux:
            if len(mo) < 3:
                continue
            c = (sum(p[0] for p in mo) / len(mo),
                 sum(p[1] for p in mo) / len(mo))
            out.append((mo, _d_segments(c, z["riv"]) < TALUS_LARGEUR))
        return out

    def mesures(self):
        return (len(self.zones),
                sum(z["longueur"] for z in self.zones.values()))


def _sur_la_berge(a, b, chenal):
    """L'arête (a, b) est-elle posée sur la berge ? Les trois points testés —
    les deux bouts ET le milieu — évitent qu'une arête qui touche la rive par
    un seul sommet passe pour une rive entière."""
    x0, x1 = min(a[0], b[0]) - 1.0, max(a[0], b[0]) + 1.0
    y0, y1 = min(a[1], b[1]) - 1.0, max(a[1], b[1]) + 1.0
    proches = chenal.berges_autour(x0, y0, x1, y1)
    if not proches:
        return False
    m = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
    return all(_d_segments(p, proches) < BORD_EAU_TOL for p in (a, b, m))


def _d_segments(p, segs):
    return min(_d_point_seg(p, a, b) for a, b in segs)


def _d_boite_segment(x0, y0, x1, y1, a, b):
    """Distance d'une boîte à un segment. 0 s'ils se coupent — testé par les
    quatre côtés de la boîte, sans quoi un segment qui la traverse de part en
    part passerait pour lointain (aucun de ses bouts n'est dedans, et les coins
    peuvent être plus loin que le seuil)."""
    coins = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    for k in range(4):
        if _se_croisent(a, b, coins[k], coins[(k + 1) % 4]):
            return 0.0
    d = min(_d_point_seg(c, a, b) for c in coins)
    for p in (a, b):
        d = min(d, math.hypot(max(x0 - p[0], 0.0, p[0] - x1),
                              max(y0 - p[1], 0.0, p[1] - y1)))
    return d


def _se_croisent(a, b, c, d):
    def cote(p, q, r):
        v = (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
        return (v > 1e-12) - (v < -1e-12)
    return (cote(a, b, c) * cote(a, b, d) <= 0
            and cote(c, d, a) * cote(c, d, b) <= 0)


def _d_point_seg(p, a, b):
    ax, ay = b[0] - a[0], b[1] - a[1]
    ll = ax * ax + ay * ay
    u = 0.0 if ll < 1e-12 else max(0.0, min(
        1.0, ((p[0] - a[0]) * ax + (p[1] - a[1]) * ay) / ll))
    return math.hypot(p[0] - (a[0] + u * ax), p[1] - (a[1] + u * ay))


def _grille(anneau, pas):
    """Débite un morceau sur la grille ABSOLUE de `pas` mètres.

    ⚠️ ABSOLUE, et c'est tout l'intérêt : la plaque et le talus ne sont pas
    coupés par les mêmes droites (l'un par les berges, l'autre par les hauts
    de talus), mais leurs sommets tombent sur les mêmes lignes. Une grille
    relative au morceau ferait deux échantillonnages décalés du même relief,
    et l'un ressortirait de l'autre à la cassure du haut.
    """
    morceaux = [anneau]
    for axe in (0, 1):
        vals = [p[axe] for p in anneau]
        for k in range(int(math.floor(min(vals) / pas)) + 1,
                       int(math.ceil(max(vals) / pas))):
            s = k * pas
            p0 = (s, 0.0) if axe == 0 else (0.0, s)
            nrm = (1.0, 0.0) if axe == 0 else (0.0, 1.0)
            suite = []
            for mo in morceaux:
                suite.extend(D4C.couper(mo, p0, nrm))
            morceaux = suite
    return [m for m in morceaux if len(m) >= 3]


# ================================================================== géométrie

def aire_signee(anneau):
    s = 0.0
    n = len(anneau)
    for i in range(n):
        x1, y1 = anneau[i]
        x2, y2 = anneau[(i + 1) % n]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def trianguler(anneau):
    """Découpage en oreilles d'un polygone simple. Retourne des triplets
    d'indices dans `anneau`.

    Les 69 anneaux sont simples (contrôlé par 04b : 69/69), donc pas besoin
    d'un algorithme robuste aux auto-intersections."""
    n = len(anneau)
    if n < 3:
        return []
    idx = list(range(n))
    if aire_signee(anneau) < 0:                # on travaille en trigonométrique
        idx.reverse()
    tris = []
    garde = 0
    while len(idx) > 3 and garde < 4 * n:
        garde += 1
        coupe = False
        for k in range(len(idx)):
            ia = idx[(k - 1) % len(idx)]
            ib = idx[k]
            ic = idx[(k + 1) % len(idx)]
            a, b, c = anneau[ia], anneau[ib], anneau[ic]
            aire2 = ((b[0] - a[0]) * (c[1] - a[1])
                     - (c[0] - a[0]) * (b[1] - a[1]))
            if aire2 <= 1e-9:                  # sommet réflexe ou plat
                continue
            if any(_dans_triangle(anneau[i], a, b, c)
                   for i in idx if i not in (ia, ib, ic)):
                continue
            tris.append((ia, ib, ic))
            idx.pop(k)
            coupe = True
            break
        if not coupe:
            break
    if len(idx) == 3:
        tris.append(tuple(idx))
    return tris


def _dans_triangle(p, a, b, c):
    d1 = (p[0] - b[0]) * (a[1] - b[1]) - (a[0] - b[0]) * (p[1] - b[1])
    d2 = (p[0] - c[0]) * (b[1] - c[1]) - (b[0] - c[0]) * (p[1] - c[1])
    d3 = (p[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (p[1] - a[1])
    neg = (d1 < -1e-12) or (d2 < -1e-12) or (d3 < -1e-12)
    pos = (d1 > 1e-12) or (d2 > 1e-12) or (d3 > 1e-12)
    return not (neg and pos)


def normale(p, q, r):
    ux, uy, uz = q[0] - p[0], q[1] - p[1], q[2] - p[2]
    vx, vy, vz = r[0] - p[0], r[1] - p[1], r[2] - p[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    L = math.sqrt(nx * nx + ny * ny + nz * nz)
    if L < 1e-12:
        return (0.0, 1.0, 0.0)
    return (nx / L, ny / L, nz / L)


class Maillage(object):
    """Un tas de triangles à plat : sommets, normales, couleurs, indices.
    Godot le recopie tel quel dans un `ArrayMesh`."""

    def __init__(self):
        self.v = []
        self.n = []
        self.c = []
        self.uv = []
        # 🪟 UV2 ne sert qu'aux MURS, et seulement depuis le 2026-08-18 : il
        # porte (genre de percement, tirage du bâtiment). Il n'est écrit dans
        # le JSON que si un mur l'a rempli — sans ça le terrain, les sols et
        # la voirie traîneraient chacun un tableau de zéros.
        self.uv2 = []
        # 🏢 LE CANAL DE LA SURÉLÉVATION, (rang, monte, plafond). `rang` est
        # la place du bâtiment dans l'ordre de montée de son îlot ; `monte` dit
        # si CE sommet-ci suit le toit ou reste au sol ; `plafond` est l'égout
        # D'ORIGINE en Y monde — c'est lui qui sépare l'ancien de l'ajouté, et
        # donc ce que le shader peint en bardage. Rempli seulement pendant
        # qu'un bâtiment s'émet, par `self.dense` — le reste du maillage (sols,
        # jardins, haies, venelles) sort à zéro et ne bouge jamais.
        self.d = []
        self.dense = None
        self.i = []
        # Les plages d'indices, un groupe par objet. Godot en refait un nœud
        # par îlot et par tronçon — c'est ce qui rend la ville CLIQUABLE, et
        # c'est aussi ce qui permet de la teinter objet par objet.
        self.groupes = []
        self._fid = None
        self._debut = 0

    def marque(self, fid):
        """Ouvre un groupe. Les triangles émis jusqu'au prochain `marque()`
        appartiennent à `fid`. Les triangles émis SANS groupe ouvert n'en ont
        aucun — ils resteront dans le maillage fusionné, sans être cliquables."""
        self.fermer()
        self._fid = fid
        self._debut = len(self.i)

    def fermer(self):
        if self._fid is not None and len(self.i) > self._debut:
            self.groupes.append([self._fid, self._debut,
                                 len(self.i) - self._debut])
        self._fid = None

    def triangle(self, p, q, r, coul, ao=(1.0, 1.0, 1.0), axe_toit=None,
                 facade=None, genre=None, uv2s=None, couleurs=None):
        """Émet un triangle dont la normale main droite est celle de (p, q, r).

        ⚠ MAIS LES SOMMETS SORTENT DANS L'ORDRE p, r, q.

        Godot considère les faces AVANT en sens HORAIRE — l'inverse de la
        convention main droite. Émis dans l'ordre naturel, tout ce qui regarde
        la caméra est pris pour du dos et disparaît : mesuré, les toits et le
        terrain entier étaient cullés, et les bâtiments ne se voyaient plus que
        par leurs murs. La normale, elle, reste celle de (p, q, r) : c'est elle
        qui éclaire, et elle est juste."""
        nn = normale(p, q, r)
        base = len(self.v)
        # ⚠ L'ordre de sortie est p, r, q (voir ci-dessus) : `facade` est
        # donnée dans l'ordre NATUREL p, q, r, d'où l'indice porté ici. Sans
        # lui, un mur sortirait avec ses coordonnées de façade permutées et
        # les travées partiraient de travers.
        for s, f, k in ((p, ao[0], 0), (r, ao[2], 2), (q, ao[1], 1)):
            self.v.append(s)
            self.n.append(nn)
            # RGB = la teinte déjà occluse ; ALPHA = l'occlusion seule.
            # Garder le facteur séparément coûte un float par sommet et permet
            # de repeindre un objet en calque thématique sans perdre ce qui le
            # POSE au sol — l'AO bakée est la fondation, pas un décor
            # (Direction artistique l.21). Aucun matériau du projet n'active la
            # transparence : ce canal est libre.
            # `couleurs` : une teinte par sommet, ordre naturel (le versant).
            cs = coul if couleurs is None else couleurs[k]
            self.c.append((cs[0] * f, cs[1] * f, cs[2] * f, f))
            # UV ne porte pas une texture : sur les seules faces de toiture,
            # il porte l'axe du bâtiment en XZ Godot. Le shader peut ainsi
            # aligner sa recette de panneaux sur le faîtage et reconnaître
            # qu'il travaille bien pan par pan. (0, 0) signifie « pas un toit ».
            # UV ne porte pas une texture. Deux usages, exclusifs :
            #   toit → l'axe du bâtiment en XZ Godot, un vecteur UNITAIRE ;
            #   mur  → (u, L) : mètres le long de la façade depuis son coin,
            #          et longueur totale de CETTE façade.
            # C'est la longueur qui sépare les deux dans le shader : aucune
            # composante d'un vecteur unitaire ne passe 1, et 07 refuse de
            # percer une façade de moins de FACADE_MIN (2 m).
            if facade is not None:
                self.uv.append(facade[k])
            else:
                self.uv.append((0.0, 0.0) if axe_toit is None else axe_toit)
            # `uv2s` : un UV2 par sommet, ordre naturel — le courant de l'eau.
            self.uv2.append(uv2s[k] if uv2s is not None
                            else (0.0, 0.0) if genre is None else genre)
            # Le seuil est en Y MONDE, posé par l'appelant un demi-mètre sous
            # l'égout : entre le pied du mur et lui, un bâtiment n'a aucun
            # sommet, donc le test ne peut pas se tromper de moitié de mur.
            self.d.append((0.0, 0.0, 0.0) if self.dense is None
                          else (self.dense[0],
                                1.0 if s[1] >= self.dense[1] else 0.0,
                                self.dense[2]))
        self.i.extend((base, base + 1, base + 2))

    def json(self, prec=2):
        self.fermer()
        d = {
            "v": [[round(c, prec) for c in s] for s in self.v],
            "n": [[round(c, 3) for c in s] for s in self.n],
            "c": [[round(c, 3) for c in s] for s in self.c],
            "uv": [[round(c, 4) for c in s] for s in self.uv],
            "i": self.i,
            "g": self.groupes,
        }
        # Un maillage sans un seul mur percé n'emporte pas la colonne : Godot
        # laisse alors UV2 à zéro, ce qui est exactement « pas une façade ».
        if any(g[0] or g[1] for g in self.uv2):
            d["uv2"] = [[round(c, 3) for c in s] for s in self.uv2]
        # Même règle : seul le maillage des masses porte la colonne.
        if any(g[1] for g in self.d):
            d["dense"] = [[round(c, 4) for c in s] for s in self.d]
        return d

    def __len__(self):
        return len(self.i) // 3


def _cap_plat(m, anneau, y, coul, G, relief=None, facteur=1.0):
    """Un cap horizontal — ou suivant le talus si `relief` est donné.

    `facteur` enfonce la surface en proportion du creux : c'est ce que la
    plaque de sol utilise pour rester sous le champ sans qu'il faille faire
    coïncider deux découpages."""
    if relief is None:
        alt = lambda p: y                                  # noqa: E731
    else:
        alt = lambda p: y + relief.z(p[0], p[1]) * facteur  # noqa: E731
    for ia, ib, ic in trianguler(anneau):
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        m.triangle(G(a[0], a[1], alt(a)), G(b[0], b[1], alt(b)),
                   G(c[0], c[1], alt(c)), coul)


NAPPE_PAS = 8.0      # m : sous ce pas, le dégradé de rive ne se voit plus


def _nappe(m, anneau, chenal, coul, G):
    """La nappe redébitée sur une grille de NAPPE_PAS, découpée par l'anneau
    comme la plaque de sol l'est par les berges. UV = (distance à la rive + 1,
    0), UV2 = sens de l'aval en XZ Godot : le shader de l'eau en tire la
    profondeur, l'écume et le courant. UV nul = eau sans rive connue.
    ⚠ Pas de bissection des triangles de l'anneau : ses oreilles sont des
    lamelles de 300 m, et la ville sortait à 418 000 sommets d'eau."""
    cache = {}

    def lire(p):
        k = _cle(p)
        if k not in cache:
            d, tx, ty = chenal.courant(p[0], p[1])
            cache[k] = (G(p[0], p[1], NAPPE_ILSE), (round(d + 1.0, 2), 0.0),
                        (round(tx, 3), round(-ty, 3)))
        return cache[k]

    ferme = list(anneau) + [anneau[0]]
    aretes = list(zip(ferme, ferme[1:]))
    index = {}
    for k, (p, q) in enumerate(aretes):
        for gx in range(int(min(p[0], q[0]) // NAPPE_PAS),
                        int(max(p[0], q[0]) // NAPPE_PAS) + 1):
            for gy in range(int(min(p[1], q[1]) // NAPPE_PAS),
                            int(max(p[1], q[1]) // NAPPE_PAS) + 1):
                index.setdefault((gx, gy), []).append(k)
    xs = [p[0] for p in anneau]
    ys = [p[1] for p in anneau]
    for gy in range(int(min(ys) // NAPPE_PAS), int(max(ys) // NAPPE_PAS) + 1):
        for gx in range(int(min(xs) // NAPPE_PAS), int(max(xs) // NAPPE_PAS) + 1):
            ax, ay = gx * NAPPE_PAS, gy * NAPPE_PAS
            bx, by = ax + NAPPE_PAS, ay + NAPPE_PAS
            morceaux = [[(ax, ay), (bx, ay), (bx, by), (ax, by)]]
            for k in index.get((gx, gy), ()):
                p, q = aretes[k]
                nrm = (q[1] - p[1], -(q[0] - p[0]))
                morceaux = [x for mo in morceaux for x in D4C.couper(mo, p, nrm)]
            for mo in morceaux:
                if len(mo) < 3:
                    continue
                c = (sum(p[0] for p in mo) / len(mo), sum(p[1] for p in mo) / len(mo))
                if not dedans(ferme, c):
                    continue
                if aire_signee(mo) < 0:
                    mo = list(reversed(mo))
                sommets = [lire(p) for p in mo]
                for j in range(1, len(mo) - 1):
                    (pa, ua, fa), (pb, ub, fb), (pc, uc, fc) =                         sommets[0], sommets[j], sommets[j + 1]
                    m.triangle(pa, pb, pc, coul, facade=[ua, ub, uc],
                               uv2s=[fa, fb, fc])


def _chenal_eau(m_eau, m_dur, anneau, chenal, coul_eau, coul_mur, G,
                relief=None, niveau_rive=None, passages=None):
    """Un îlot d'eau : le fond du chenal, la nappe, et les murs de berge.

    ⚠️ Deux maillages, et ce n'est pas un détail : la NAPPE part dans le
    maillage d'eau, qui a un matériau lisse et une couleur unique ; le FOND et
    les MURS partent avec le sol, dont le matériau lit la couleur des sommets.
    Mis dans l'eau, un mur de quai serait bleu et brillant.

    Les murs ne sont posés que sur les arêtes qui SÉPARENT l'eau de la ville.
    Six îlots d'eau bout à bout partagent cinq arêtes en travers du courant :
    y bâtir un mur mettrait cinq barrages dans la rivière.

    Renvoie (murs émis, murs qui regardent bien vers l'eau) — un mur de quai
    tourné vers la ville serait invisible, et ça ne se devine pas.

    🔄 LE HAUT DU MUR SUIT LE SOL depuis le 2026-08-18, au lieu d'être posé à
    `Y_TERRAIN`. Une seule règle — *le mur monte jusqu'à la surface du sol* —
    et elle fait les deux bords d'eau que l'auteur a dessinés : 2,6 m de quai
    droit là où la ville tient la rive, une lèvre noyée de 45 cm là où le champ
    descend déjà au ras de l'eau. Elle répare aussi une fente qui existait
    avant le talus : le haut du mur était 15 cm SOUS les caps d'îlot et 8 cm
    sous l'asphalte, donc une rue de quai surplombait le vide."""
    m = m_dur
    _cap_plat(m_dur, anneau, FOND_ILSE, coul_mur, G)      # le fond
    _nappe(m_eau, anneau, chenal, coul_eau, G)            # la nappe

    ok = tot = 0
    n = len(anneau)
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        if not chenal.est_berge(a, b):
            continue
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 1e-9:
            continue
        tot += 1
        # Une arête droite ne se débite que si un talus la longe : ailleurs le
        # haut est horizontal et deux triangles suffisent.
        k = 1
        if relief is not None and relief.boite_active(
                min(a[0], b[0]), min(a[1], b[1]),
                max(a[0], b[0]), max(a[1], b[1])):
            k = max(1, int(math.ceil(L / TALUS_PAS)))
        stations = {j / k for j in range(k + 1)}
        libres = [(0.0, 1.0)]
        if passages is not None:
            libres = [(math.dist(a, p) / L, math.dist(a, q) / L)
                      for p, q in passages.segments(a, b)]
            stations.update(t for intervalle in libres for t in intervalle)
        stations = sorted(stations)
        for j, (t0, t1) in enumerate(zip(stations, stations[1:])):
            p = (a[0] + dx * t0, a[1] + dy * t0)
            q = (a[0] + dx * t1, a[1] + dy * t1)
            # Pris SUR la ligne de berge, sans écart vers la terre : c'est
            # exactement là que le sol du champ s'arrête, donc le haut du mur
            # et le bord du talus tombent au même millimètre.
            hp = hq = Y_SOL
            if relief is not None:
                hp += relief.z(p[0], p[1])
                hq += relief.z(q[0], q[1])
            if not any(lo <= (t0 + t1) / 2 <= hi for lo, hi in libres):
                # Sous l'ouvrage, le mur s'arrête sous la dalle, pas au-dessus de l'asphalte.
                hp, hq = min(hp, Y_CHAUSSEE - .8), min(hq, Y_CHAUSSEE - .8)
            if niveau_rive is not None:
                niveau = niveau_rive((p[0] + q[0]) / 2.0,
                                     (p[1] + q[1]) / 2.0)
                hp += niveau
                hq += niveau
            # Le mur regarde l'EAU, pas la ville : on parcourt l'arête à
            # l'envers de ce que fait un mur de bâtiment, ce qui retourne
            # la face.
            pa_h, pb_h = G(p[0], p[1], hp), G(q[0], q[1], hq)
            pa_b, pb_b = G(p[0], p[1], FOND_ILSE), G(q[0], q[1], FOND_ILSE)
            m.triangle(pb_b, pa_b, pa_h, coul_mur)
            m.triangle(pb_b, pa_h, pb_h, coul_mur)
            if j == 0:
                nn = normale(pb_b, pa_b, pa_h)
                if (nn[0] * dy + nn[2] * dx) / L < -0.9:
                    ok += 1
    return ok, tot


def _sol(m, anneau, coul, G, relief=None, y=Y_SOL):
    """Un cap posé sur la plaque, SANS AUCUN MUR — donc impossible à lire
    comme un bâtiment raté. Il sert les îlots à hauteur nulle (champs, parc,
    jardins, la place du marché), les jardins et venelles d'un pâté, et le
    sol nu de l'îlot bâti lui-même, posé plus bas par `y`.

    🔄 Il était SUBDIVISÉ pour suivre un champ d'altitude, puis strictement
    plat une fois la carte aplatie. Il redevient échantillonné — mais sur le
    seul relief qui reste, et seulement là où il existe : `relief.z` vaut 0,0
    pile partout ailleurs, donc la ville ne bouge pas d'un millimètre."""
    for ia, ib, ic in trianguler(anneau):
        a, b, c = anneau[ia], anneau[ib], anneau[ic]
        ya = yb = yc = y
        if relief is not None:
            ya += relief.z(a[0], a[1])
            yb += relief.z(b[0], b[1])
            yc += relief.z(c[0], c[1])
        m.triangle(G(a[0], a[1], ya), G(b[0], b[1], yb),
                   G(c[0], c[1], yc), coul)


def _decaler(anneau, dist):
    """L'anneau décalé de `dist` mètres vers l'EXTÉRIEUR, coin par coin.

    Le décalage se fait sur la bissectrice des deux normales sortantes, donc
    la longueur du décalage à un coin vaut `dist / sin(θ/2)` : c'est ce qui
    fait que les deux pans se rejoignent exactement sur l'arête, sans fente ni
    recouvrement. La formule tenue ici est `(n0 + n1) / (1 + n0·n1)`.

    ⚠️ LE PLAFOND N'EST PAS DÉCORATIF. Sur un coin très fermé, `1 + n0·n1`
    tend vers zéro et le sommet part à l'infini — un seul coin suffirait à
    envoyer un triangle à l'autre bout de la ville. `_ecorner` borne déjà les
    angles à 70,2° en amont (soit un décalage de 1,74·dist), mais ce code ne
    doit pas dépendre d'un réglage fait ailleurs.
    """
    n = len(anneau)
    # 🔴 LE SENS DU PARCOURS SE MESURE, il ne se suppose pas. Un anneau horaire
    # décalé avec la normale d'un anneau trigonométrique rentre au lieu de
    # sortir : le toit passerait SOUS le mur, et le défaut serait invisible sur
    # les 95 % de bâtiments dont l'anneau est dans le bon sens.
    signe = 1.0 if aire_signee(anneau) > 0.0 else -1.0
    nrm = []
    for i in range(n):
        a, b = anneau[i], anneau[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        nrm.append(None if L < 1e-9
                   else (signe * dy / L, -signe * dx / L))
    if all(v is None for v in nrm):
        return list(anneau)
    for i in range(n):                     # une arête nulle hérite du voisin
        if nrm[i] is None:
            nrm[i] = next(nrm[(i + k) % n] for k in range(1, n + 1)
                          if nrm[(i + k) % n] is not None)

    out = []
    for i in range(n):
        n0 = nrm[(i - 1) % n]              # l'arête qui arrive
        n1 = nrm[i]                        # l'arête qui repart
        k = 1.0 + n0[0] * n1[0] + n0[1] * n1[1]
        mx, my = n0[0] + n1[0], n0[1] + n1[1]
        if k > 0.32:
            mx, my = mx / k, my / k
        else:
            L = math.hypot(mx, my)         # coin fermé : on borne à 2,5·dist
            mx, my = (n1[0] * 2.5, n1[1] * 2.5) if L < 1e-9 \
                else (mx / L * 2.5, my / L * 2.5)
        out.append((anneau[i][0] + dist * mx, anneau[i][1] + dist * my))
    return out


def _point_proche(p, a, b):
    """Le point du segment [a, b] le plus proche de `p`."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dy * dy
    if L2 < 1e-18:
        return a
    t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2
    t = max(0.0, min(1.0, t))
    return (a[0] + t * dx, a[1] + t * dy)


def _convexe(anneau, tol=1e-6):
    """Tous les virages tournent-ils dans le même sens ?"""
    n = len(anneau)
    signe = 0
    for i in range(n):
        a, b, c = anneau[i], anneau[(i + 1) % n], anneau[(i + 2) % n]
        cr = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])
        if abs(cr) < tol:
            continue
        s = 1 if cr > 0 else -1
        if signe == 0:
            signe = s
        elif s != signe:
            return False
    return True


def _degenere(tri, seuil=1e-7):
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri
    ux, uy, uz = bx - ax, by - ay, bz - az
    vx, vy, vz = cx - ax, cy - ay, cz - az
    nx = uy * vz - uz * vy
    ny = uz * vx - ux * vz
    nz = ux * vy - uy * vx
    return (nx * nx + ny * ny + nz * nz) < seuil


def _graine_lieu(anneau):
    """Une graine tirée de la POSITION, pas d'un rang — décision 35. Déplacer
    une ligne de la table `BATI` ne doit pas rebattre toute la ville."""
    cx = sum(p[0] for p in anneau) / len(anneau)
    cy = sum(p[1] for p in anneau) / len(anneau)
    return abs((int(round(cx * 100.0)) * 73856093)
               ^ (int(round(cy * 100.0)) * 19349663))


def _semer_jardin(anneau, aire, batiments=()):
    """Les arbres d'un jardin. Tous les jardins verts n'en ont pas : c'est le
    « pas tous » de la consigne, et c'est ce qui empêche le cœur d'îlot de
    ressembler à un tapis."""
    r = random.Random(_graine_lieu(anneau) ^ 0x5EED)
    if r.random() > PART_JARDINS_ARBORES:
        return []
    n = max(1, int(aire / M2_PAR_ARBRE_JARDIN))
    xs = [p[0] for p in anneau]
    ys = [p[1] for p in anneau]
    ferme = list(anneau) + [anneau[0]]
    out = []
    essais = 0
    while len(out) < n and essais < n * 40:
        essais += 1
        x = r.uniform(min(xs), max(xs))
        y = r.uniform(min(ys), max(ys))
        if not dedans(ferme, (x, y)):
            continue
        if any(dedans(list(emp) + [emp[0]], (x, y)) for emp in batiments):
            continue
        # 🌲 Le 6e nombre est l'ESSENCE : 0 feuillu, 1 conifère, 6 fruitier.
        # Un jardin de ville compte peu de conifères — un thuya, un sapin
        # planté trop près du mur — et beaucoup de pommiers. Le fruitier est
        # tiré du LIEU, pas de `r` : un tirage de plus déplacerait les arbres.
        conifere = r.random() < 0.12
        out.append([x, y, 0.0,
                    r.uniform(0.55, 0.95), r.uniform(0.0, 6.2832),
                    1 if conifere else (6 if _tirage_lieu(x, y) < 0.5 else 0)])
    return out


def _tirage_lieu(x, y, graine=0x7A11):
    """Un nombre de [0, 1[ tiré de la POSITION : même lieu, même essence."""
    n = (int(x * 7.0) * 374761393 + int(y * 7.0) * 668265263 + graine) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFF) / 16777216.0


# 🌳 Les essences de la ville, mêmes codes que `constructeur.gd`.
FEUILLU, CONIFERE, BUISSON, BOULEAU, PEUPLIER, FRUITIER, SAULE = 0, 1, 3, 4, 5, 6, 7


def varier_essence(x, y, essence, eau_m=None):
    """Le feuillu générique devient saule ou peuplier au bord de l'eau, parfois
    bouleau ailleurs ; sur une rive rendue, un buisson sur trois est un saule.
    Tiré du lieu : la même ville plante les mêmes essences."""
    t = _tirage_lieu(x, y)
    if essence == BUISSON:
        return SAULE if t < 0.30 else BUISSON
    if essence != FEUILLU:
        return essence
    if eau_m is not None and eau_m < 30.0:
        return SAULE if t < 0.35 else PEUPLIER if t < 0.60 else FEUILLU
    return BOULEAU if t > 0.86 else FEUILLU


def _unite(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L = math.hypot(dx, dy)
    return None if L < 1e-9 else (dx / L, dy / L)


def _aire_xy(poly):
    s = 0.0
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def _axe_ruban(pts, demi_largeur, bouts=True):
    """L'axe net réellement couvert par un ruban.

    Les chaussées prolongent leurs deux bouts d'une demi-largeur pour fermer
    les carrefours. Le contrôle des arbres doit lire exactement ces mêmes
    bouts, sinon il protège le segment source tout en laissant un tronc dans
    le carré d'asphalte ajouté à l'intersection.
    """
    net = [pts[0]]
    for p in pts[1:]:
        if math.hypot(p[0] - net[-1][0], p[1] - net[-1][1]) > 1e-6:
            net.append(p)
    if len(net) < 2:
        return []
    if bouts:
        u0, u1 = _unite(net[0], net[1]), _unite(net[-2], net[-1])
        net[0] = (net[0][0] - u0[0] * demi_largeur,
                  net[0][1] - u0[1] * demi_largeur)
        net[-1] = (net[-1][0] + u1[0] * demi_largeur,
                   net[-1][1] + u1[1] * demi_largeur)
    return net


def _onglets(net):
    """Les vecteurs d'ONGLET d'une polyligne : le point à la distance latérale
    `w` du sommet `i` est `net[i] + onglets[i] * w`, et deux arêtes voisines
    décalées de `w` se rejoignent dessus au lieu de se croiser.

    Sa longueur vaut 1/cos(demi-angle), donc il s'envole quand la cassure
    approche 180° — d'où l'écrêtage. Les arcs, eux, ne cassent que de
    PAS_ARC_DEG.

    🔄 SORTI DE `_ruban` LE 2026-08-18, quand le mur de quai est arrivé. Le mur
    doit s'appuyer exactement sur le bord de l'asphalte ; un second calcul de
    décalage aurait dérivé au premier changement, et une fente de deux
    centimètres entre une chaussée et son mur, c'est un trait de vide sur toute
    la longueur du quai."""
    n = len(net)
    dec = []
    for i in range(n):
        ua = _unite(net[i - 1], net[i]) if i > 0 else None
        ub = _unite(net[i], net[i + 1]) if i < n - 1 else None
        ua = ua or ub
        ub = ub or ua
        na, nb = (-ua[1], ua[0]), (-ub[1], ub[0])
        d = 1.0 + na[0] * nb[0] + na[1] * nb[1]
        if d < 1e-6:
            mx, my = na
        else:
            mx, my = (na[0] + nb[0]) / d, (na[1] + nb[1]) / d
            L = math.hypot(mx, my)
            if L > LIMITE_MITRE_RUBAN:
                mx, my = mx / L * LIMITE_MITRE_RUBAN, my / L * LIMITE_MITRE_RUBAN
        dec.append((mx, my))
    return dec


def _ruban(m, pts, larg, coul, G, y=None, decal=0.0, bouts=True):
    """Un ruban le long d'une polyligne, joints en ONGLET.

    La chaussée s'en sert, et depuis le 2026-08-18 le MARQUAGE aussi :
    une ligne blanche est un ruban de 15 cm, une bande de passage piéton
    un ruban de 50 cm. `decal` la pousse latéralement (ligne de rive),
    `bouts` désactive la rallonge de remplissage des carrefours — une
    ligne qui se rallongerait toute seule déborderait dans le carrefour
    qu'on vient justement de lui interdire.

    🔄 ELLE ÉMETTAIT UN QUADRILATÈRE PAR SEGMENT, chacun rallongé d'une
    demi-largeur pour que les carrefours se remplissent au lieu d'afficher une
    croix pâle. Sur une droite c'est exactement la même chose ; sur un ARC,
    les rallonges débordaient de la courbe et le bord sortait en dents de
    scie. Les deux BOUTS gardent la rallonge — c'est elle qui remplit les
    carrefours, et là on la veut.

    🔄 ET ELLE ÉTAIT ÉCLAIRÉE À L'ENVERS. Toutes ses normales pointaient vers
    le BAS — mesuré : 3 060 triangles sur 3 060 —, donc la ville roulait sur
    un asphalte qui ne recevait que la lumière ambiante. Le sol des îlots,
    lui, était dans le bon sens depuis toujours : d'où l'écart de valeur entre
    une rue et une cour, qu'on prenait pour un choix de palette.

    🔄 Elle était aussi découpée tous les 20 m pour suivre la pente. La carte
    étant plate, elle reste à 0 sur toute sa longueur — et au-dessus du chenal
    elle passe donc au-dessus du vide. C'est ça, le pont : aucune ligne de
    code du projet ne parle de tablier."""
    h = larg / 2.0
    if y is None:
        y = Y_CHAUSSEE
    net = _axe_ruban(pts, h, bouts)
    if len(net) < 2:
        return 0

    n = len(net)
    dec = _onglets(net)

    # `dec` est l'ONGLET UNITAIRE : le bord gauche est à `decal - h` le long de
    # lui, le droit à `decal + h`. Sans décalage on retombe sur ±h, donc sur la
    # chaussée centrée d'avant.
    for i in range(n - 1):
        g0 = (net[i][0] + dec[i][0] * (decal - h),
              net[i][1] + dec[i][1] * (decal - h))
        d0 = (net[i][0] + dec[i][0] * (decal + h),
              net[i][1] + dec[i][1] * (decal + h))
        g1 = (net[i + 1][0] + dec[i + 1][0] * (decal - h),
              net[i + 1][1] + dec[i + 1][1] * (decal - h))
        d1 = (net[i + 1][0] + dec[i + 1][0] * (decal + h),
              net[i + 1][1] + dec[i + 1][1] * (decal + h))
        # Sens TRIGONOMÉTRIQUE dans le repère source : après G(), qui inverse
        # Z, il donne une normale vers le HAUT. C'est ce que `_sol` fait
        # depuis toujours, et c'est ce que la chaussée ne faisait pas.
        m.triangle(G(g0[0], g0[1], y), G(g1[0], g1[1], y),
                   G(d1[0], d1[1], y), coul)
        m.triangle(G(g0[0], g0[1], y), G(d1[0], d1[1], y),
                   G(d0[0], d0[1], y), coul)
    return 2 * (n - 1)


# --------------------------------- le bord de l'eau : le quai porté et le pont

def _densifier(pts, pas):
    """La même polyligne, avec un sommet au moins tous les `pas` mètres.

    Le mur de quai a besoin d'un débit plus fin que la chaussée : sa distance à
    l'axe CHANGE le long de la rue (il colle à la berge là où elle est dehors,
    au bord de l'asphalte là où elle est dessous), et une variation ne peut se
    lire qu'entre deux sommets."""
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        k = max(1, int(math.ceil(L / pas)))
        for j in range(1, k + 1):
            out.append((a[0] + (b[0] - a[0]) * j / k,
                        a[1] + (b[1] - a[1]) * j / k))
    return out


def _bande3d(m, A, B, coul, G, vers, ao=None):
    """La surface réglée entre deux polylignes de même longueur, en (x, y, alt).

    ⚠️ LE SENS DE PARCOURS EST MESURÉ, PAS SUPPOSÉ. Le mur d'un quai de rive
    gauche se parcourt à l'envers de celui d'une rive droite, et une face à
    l'envers est cullée : le mur disparaît, et le trou ne se voit qu'à l'écran.
    On calcule donc la normale du premier quad et on retourne toute la bande si
    elle ne regarde pas où on lui demande.

    `vers` est donné dans le repère GODOT : l'inversion de Z change la
    chiralité, donc raisonner dans le repère source se paierait deux fois.

    `ao` : l'occlusion des deux rives, (côté A, côté B). Elle suit le
    retournement, sinon une bande inversée sortirait son ombre à l'envers."""
    oa, ob = ao if ao else (1.0, 1.0)
    quads = []
    for i in range(len(A) - 1):
        a0, a1, b1, b0 = A[i], A[i + 1], B[i + 1], B[i]
        # Un quad écrasé arrive pour de bon : la bande de quai est de largeur
        # nulle là où la berge est déjà dehors. Deux triangles d'aire nulle
        # donnent une normale arbitraire et une arête qui scintille.
        if (math.hypot(a0[0] - b0[0], a0[1] - b0[1]) < 0.02
                and math.hypot(a1[0] - b1[0], a1[1] - b1[1]) < 0.02
                and abs(a0[2] - b0[2]) < 0.02 and abs(a1[2] - b1[2]) < 0.02):
            continue
        if (math.hypot(a0[0] - a1[0], a0[1] - a1[1]) < 1e-6
                and math.hypot(b0[0] - b1[0], b0[1] - b1[1]) < 1e-6):
            continue
        quads.append((a0, a1, b1, b0))
    if not quads:
        return 0
    a0, a1, b1, b0 = quads[0]
    nn = normale(G(*a0), G(*a1), G(*b1))
    if nn[0] * vers[0] + nn[1] * vers[1] + nn[2] * vers[2] < 0.0:
        quads = [(q[3], q[2], q[1], q[0]) for q in quads]
        oa, ob = ob, oa
    for a0, a1, b1, b0 in quads:
        m.triangle(G(*a0), G(*a1), G(*b1), coul, (oa, oa, ob))
        m.triangle(G(*a0), G(*b1), G(*b0), coul, (oa, ob, ob))
    return 2 * len(quads)


def _boite(m, c, u, long_u, long_v, y_bas, y_haut, coul, G):
    """Une boîte posée à plat, alignée sur `u` : quatre murs et un chapeau.

    C'est la forme d'une souche de cheminée comme d'une pile de pont — un
    parallélépipède orienté. `_cheminee` s'en sert avec sa taille à elle."""
    ux, uy = u
    vx, vy = -uy, ux
    a, b = long_u / 2.0, long_v / 2.0
    coins = [(c[0] + ux * sa * a + vx * sb * b,
              c[1] + uy * sa * a + vy * sb * b)
             for sa, sb in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    if aire_signee(coins) < 0.0:
        coins.reverse()
    n = 0
    for i in range(4):
        p, q = coins[i], coins[(i + 1) % 4]
        m.triangle(G(p[0], p[1], y_bas), G(q[0], q[1], y_bas),
                   G(q[0], q[1], y_haut), coul)
        m.triangle(G(p[0], p[1], y_bas), G(q[0], q[1], y_haut),
                   G(p[0], p[1], y_haut), coul)
        n += 2
    for ia, ib, ic in trianguler(coins):
        p, q, r = coins[ia], coins[ib], coins[ic]
        m.triangle(G(p[0], p[1], y_haut), G(q[0], q[1], y_haut),
                   G(r[0], r[1], y_haut), coul)
        n += 1
    return n


def _parapet(m, ext, inte, dehors, coul, coul_chap, G, y_bas=Y_SOL):
    """LE MURET DE 1 M ENTRE LA ROUTE ET L'EAU — le mur que l'auteur a demandé.

    Trois surfaces, et une seule recette pour le quai comme pour le pont : la
    face extérieure, le chaperon, la face intérieure. Ses deux bouts sont
    fermés — 40 cm sur 1 m, c'est peu, mais un parapet de pont finit en l'air
    sur sa culée et on verrait le jour à travers.

    Le chaperon est plus clair que le corps : vu d'en haut, c'est LUI qui dit
    qu'il y a une barrière. Un muret d'une seule teinte se confond avec le mur
    de quai qu'il surmonte, et la ville retrouve un bord d'eau franc — ce qu'on
    est justement en train de corriger."""
    y_h = y_bas + PARAPET_H
    n = _bande3d(m, [(p[0], p[1], y_h) for p in ext],
                 [(p[0], p[1], y_bas) for p in ext], coul, G, dehors)
    n += _bande3d(m, [(p[0], p[1], y_h) for p in inte],
                  [(p[0], p[1], y_bas) for p in inte], coul, G,
                  (-dehors[0], -dehors[1], -dehors[2]))
    n += _bande3d(m, [(p[0], p[1], y_h) for p in ext],
                  [(p[0], p[1], y_h) for p in inte], coul_chap, G, (0.0, 1.0, 0.0))
    for k in (0, -1):
        u = _unite(ext[1], ext[0]) if k == 0 else _unite(ext[-2], ext[-1])
        if u is None:
            continue
        n += _bande3d(m, [(ext[k][0], ext[k][1], y_h),
                          (inte[k][0], inte[k][1], y_h)],
                      [(ext[k][0], ext[k][1], y_bas),
                       (inte[k][0], inte[k][1], y_bas)],
                      coul, G, (u[0], 0.0, -u[1]))
    return n


# ------------------------------------------------- le marquage au sol

def _cumul(pts):
    """Les abscisses curvilignes d'une polyligne : `cum[i]` = distance du
    départ au sommet i. C'est le repère de TOUT le marquage — les traits, les
    zones interdites et les passages piétons sont des intervalles dessus."""
    cum = [0.0]
    for i in range(1, len(pts)):
        cum.append(cum[-1] + math.hypot(pts[i][0] - pts[i - 1][0],
                                        pts[i][1] - pts[i - 1][1]))
    return cum


def _le_long(pts, cum, s):
    """Le point à l'abscisse `s`, et la direction unitaire locale."""
    s = max(0.0, min(cum[-1], s))
    i = 0
    while i < len(cum) - 2 and cum[i + 1] < s:
        i += 1
    t = (s - cum[i]) / max(cum[i + 1] - cum[i], 1e-9)
    u = _unite(pts[i], pts[i + 1]) or (1.0, 0.0)
    return ((pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t,
             pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t), u)


def _tronquer(pts, cum, s0, s1):
    """La sous-polyligne entre deux abscisses, bornes interpolées. Les sommets
    intermédiaires sont GARDÉS : c'est ce qui fait qu'un trait plein posé dans
    un virage suit l'arc au lieu de le couper à la corde."""
    if s1 - s0 < 1e-6:
        return []
    a, _ = _le_long(pts, cum, s0)
    b, _ = _le_long(pts, cum, s1)
    out = [a]
    for i in range(len(pts)):
        if s0 + 1e-6 < cum[i] < s1 - 1e-6:
            out.append(pts[i])
    out.append(b)
    return out


def _fusionner(intervalles):
    """Des intervalles triés et sans recouvrement."""
    out = []
    for a, b in sorted(intervalles):
        if b - a < 1e-6:
            continue
        if out and a <= out[-1][1] + 1e-6:
            out[-1][1] = max(out[-1][1], b)
        else:
            out.append([a, b])
    return out


def _complement(L, bloques):
    """Ce qui reste de [0, L] une fois les zones interdites retirées."""
    out, s = [], 0.0
    for a, b in bloques:
        if a > s:
            out.append((s, min(a, L)))
        s = max(s, b)
    if s < L:
        out.append((s, L))
    return [(a, b) for a, b in out if b - a > 1e-6]


def _croiser(iv, autres):
    """L'intersection d'un intervalle avec une liste d'intervalles."""
    out = []
    for a, b in autres:
        x, y = max(iv[0], a), min(iv[1], b)
        if y - x > 1e-6:
            out.append((x, y))
    return out
