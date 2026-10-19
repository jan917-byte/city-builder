"""Écrin extérieur de Wehrau : forêt mixte, relief et nuages.

Le rectangle jouable et ses données restent exclus de cette géométrie.
"""
import math
import random

import palette as PAL
from .geometrie import Maillage, normale


PORTEE = 3600.0
PAS = 65.0
PAS_FIL = 20.0       # m entre deux stations du cours extérieur
GRAINE = 917


def fondu(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def _alea(i, j, graine=GRAINE):
    n = (i * 374761393 + j * 668265263 + graine * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFFFF) / 16777216.0


def bruit(x, z, graine=GRAINE):
    """Bruit de valeur lissé, période 1 : même recette que les shaders."""
    i, j = math.floor(x), math.floor(z)
    u, v = x - i, z - j
    u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
    a, b = _alea(i, j, graine), _alea(i + 1, j, graine)
    c, d = _alea(i, j + 1, graine), _alea(i + 1, j + 1, graine)
    return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v


def rides(x, z):
    """Crêtes et ravines : bruit replié en V, multifractal — chaque octave ne
    s'imprime que sur la crête de la précédente, les fonds restent lisses."""
    somme, amp, f, poids = 0.0, 1.0, 1.0, 1.0
    for o in range(3):
        n = 1.0 - abs(2.0 * bruit(x * f, z * f, GRAINE + o) - 1.0)
        n = n * n * poids
        poids = min(1.0, n * 1.8)
        somme += amp * n
        amp *= 0.5
        f *= 2.07
    return somme / 1.5


def ondule(x, z, graine):
    """Deux octaves arrondies, centrées : collines de piémont, pas de crête."""
    return (bruit(x, z, graine) + 0.5 * bruit(x * 2.1, z * 2.1, graine + 1)) / 1.5 - 0.5


# 🌲 La limite des arbres, en mètres au-dessus du fond de vallée : au-dessus,
# chaume et rocher — des ballons vosgiens, pas des Alpes (pas de neige).
LIMITE_ARBRES = 330.0


def limite_arbres(x, z):
    return LIMITE_ARBRES + 140.0 * (bruit(x / 420.0, z / 420.0, GRAINE + 7) - 0.5)


def clairiere(x, z):
    """< 0 dans une clairière du bois, qui garde sa prairie et perd ses arbres."""
    return bruit(x / 230.0 + 3.1, z / 230.0 - 7.7, GRAINE + 11) - 0.24


def repartir(arbres, eau=None):
    """Les arbres du décor rangés par ESSENCE selon l'altitude et le peuplement :
    le sapin monte avec le versant et vit en taches, le feuillu tient le bas,
    le peuplier la rive. Ajoute la teinte du peuplement (6e nombre).
    `eau(x, z)` : distance au cours d'eau, ou None."""
    out = [[], [], []]
    for liste in arbres:
        for a in liste:
            x, y, z = a[0], a[1], a[2]
            tache = bruit(x / 260.0, z / 260.0, GRAINE + 3)
            sapin = max(0.0, min(1.0, (y - 40.0) / 320.0 + (tache - 0.5) * 1.1))
            h = _alea(int(x * 7.0), int(z * 7.0), GRAINE + 5)
            if h < sapin:
                essence = 1
            elif eau is not None and eau(x, z) < 45.0 and h > 0.72:
                essence = 2
            else:
                essence = 0
            teinte = 0.84 + 0.30 * bruit(x / 95.0, z / 95.0, GRAINE + 9) + 0.08 * (h - 0.5)
            out[essence].append(list(a[:5]) + [round(teinte, 3)])
    return out


def cours(largeur, profondeur, chenal, cx, cy):
    """Les bouts du chenal prolongés en méandres jusqu'au bout du monde :
    (quadrilatères de rive, stations (centre, demi-largeur, sens de l'aval))."""
    hx, hz = largeur / 2, profondeur / 2
    rng = random.Random(GRAINE)
    # Les sorties sont les deux bouchons du chenal sur le bord de la carte.
    # Chaque sortie devient un cours en méandres, débité tous les PAS_FIL m :
    # l'amplitude part de zéro au bord pour tomber pile sur le chenal dessiné.
    canaux = []          # quadrilatères de rive, pour trouer le sol
    fils = []            # (centre, demi-largeur, sens de l'aval) par station
    for a, b in chenal.berges:
        p, q = (a[0] - cx, cy - a[1]), (b[0] - cx, cy - b[1])
        cote = next((k for k, ok in enumerate([
            p[0] < -hx + 3 and q[0] < -hx + 3,
            p[1] > hz - 3 and q[1] > hz - 3,
            p[0] > hx - 3 and q[0] > hx - 3,
            p[1] < -hz + 3 and q[1] < -hz + 3]) if ok), None)
        if cote is None:
            continue
        mx, mz = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
        largeur_eau = math.dist(p, q)
        if largeur_eau < 12:
            continue
        phase = rng.uniform(0, math.tau)
        dehors = {0: (-1, 0), 1: (0, 1), 2: (1, 0), 3: (0, -1)}[cote]
        centres = []
        for k in range(int(3900 / PAS_FIL) + 1):
            t = k * PAS_FIL
            amp = 150 * fondu(0, 650, t)
            ecart = amp * (math.sin(t / 260 + phase) - math.sin(phase) * (1 - fondu(0, 650, t))
                           + 0.35 * math.sin(t / 115 + 2 * phase))
            x, z = mx + dehors[0] * t, mz + dehors[1] * t
            centres.append((x - dehors[1] * ecart, z + dehors[0] * ecart,
                            largeur_eau / 2 * (1 + 0.12 * math.sin(t / 310 + phase))))
        rails = []
        for k, (x, z, w) in enumerate(centres):
            a0, a1 = centres[max(k - 1, 0)], centres[min(k + 1, len(centres) - 1)]
            tx, tz = a1[0] - a0[0], a1[1] - a0[1]
            n = math.hypot(tx, tz)
            tx, tz = tx / n, tz / n
            # L'Ilse coule du sud au nord (89), −z dans Godot, à l'amont comme à l'aval.
            sens = (tx, tz) if tz <= 0 else (-tx, -tz)
            rails.append(((x - tz * w, z + tx * w), (x + tz * w, z - tx * w)))
            fils.append(((x, z), w, sens))
        for (a, b), (c, d) in zip(rails, rails[1:]):
            canaux.append([a, b, d, c])
    return canaux, fils


# ⛰️ LA VALLÉE (auteur, 2026-10-19 : « les montagnes doivent s'approcher de la
# ville de manière bien plus naturelle, avec la rivière »). UN relief pour tout
# le monde, plaque comprise : nul sur ce qu'occupe l'homme — ville, champs,
# rivière —, il monte avec la distance à cette empreinte. La vallée suit donc
# le cours d'eau, et le pied des versants vient border les champs.
VALLEE_PAS = 40.0
PLAINE_M = (50.0, 260.0)    # fond plat au-delà de l'empreinte, selon l'endroit
MONTEE_M = 1500.0           # du pied du versant à la pleine montagne


class Vallee(object):
    """Hauteur ajoutée au sol, en coordonnées SOURCE (`hauteur(x, y)`).
    `occupe(p)` : le point source est-il sous un îlot ? `fils` : `cours()`."""

    def __init__(self, largeur, profondeur, cx, cy, fils, occupe):
        import heapq
        self.cx, self.cy = cx, cy
        hx, hz = largeur / 2, profondeur / 2
        n = int((PORTEE + 300) // VALLEE_PAS)
        self.n = n
        P = VALLEE_PAS
        dist = {}
        for i in range(-n, n + 1):
            for j in range(-n, n + 1):
                x, z = i * P, j * P
                if abs(x) <= hx and abs(z) <= hz and occupe((cx + x, cy - z)):
                    dist[(i, j)] = 0.0
        for (x, z), _w, _s in fils:
            dist[(round(x / P), round(z / P))] = 0.0
        tas = [(0.0, k) for k in dist]
        heapq.heapify(tas)
        while tas:
            d, (i, j) = heapq.heappop(tas)
            if d > dist[(i, j)]:
                continue
            for di in (-1, 0, 1):
                for dj in (-1, 0, 1):
                    k = (i + di, j + dj)
                    if abs(k[0]) > n or abs(k[1]) > n:
                        continue
                    nd = d + P * (1.414 if di and dj else 1.0)
                    if nd < dist.get(k, 1e9):
                        dist[k] = nd
                        heapq.heappush(tas, (nd, k))
        self.grille = {k: self._brut(k[0] * P, k[1] * P, d) for k, d in dist.items()}
        print("  vallée : relief procédural, %d mailles de %.0f m, sommet %.0f m"
              % (len(self.grille), P, max(self.grille.values())))

    @staticmethod
    def _brut(x, z, d):
        # Multiplicatif : nul SUR l'empreinte, quel que soit le bruit.
        d *= 0.70 + 0.60 * bruit(x / 260, z / 260, GRAINE + 50)
        plaine = PLAINE_M[0] + (PLAINE_M[1] - PLAINE_M[0]) * bruit(x / 700, z / 700, GRAINE + 51)
        t = fondu(plaine, plaine + MONTEE_M, d)
        if t <= 0:
            return 0.0
        wx = x + 380 * (bruit(x / 900, z / 900, GRAINE + 22) - 0.5)
        wz = z + 380 * (bruit(x / 900 + 7.3, z / 900, GRAINE + 23) - 0.5)
        crete = rides(wx / 1300, wz / 1300)
        sommets = 0.6 + 0.8 * bruit(x / 1700, z / 1700, GRAINE + 24)
        # Le fond des ravines descend presque au pied : des éperons, pas une marche.
        h = t ** 1.35 * (60 + 500 * crete * sommets)
        # Le piémont : des croupes rondes dès le bord de la plaine.
        h += 45 * fondu(plaine, plaine + 500, d) * max(0.0, ondule(x / 420, z / 420, GRAINE + 25) + 0.2)
        return h

    def hauteur(self, x, y):
        u, v = (x - self.cx) / VALLEE_PAS, (self.cy - y) / VALLEE_PAS
        i, j = math.floor(u), math.floor(v)
        fu, fv = u - i, v - j
        g = self.grille.get
        return ((g((i, j), 0.0) * (1 - fu) + g((i + 1, j), 0.0) * fu) * (1 - fv)
                + (g((i, j + 1), 0.0) * (1 - fu) + g((i + 1, j + 1), 0.0) * fu) * fv)


def paysage(largeur, profondeur, chenal, cx, cy, massifs=None, dessin=None):
    """`dessin` : le `Couvert` de la plaque, dont le bord est prolongé."""
    hx, hz = largeur / 2, profondeur / 2
    canaux, fils = cours(largeur, profondeur, chenal, cx, cy)
    rng = random.Random(GRAINE + 1)
    # Index des stations, 100 m de maille : la distance au fil se lit
    # ~150 000 fois (sol et normales), une boucle sur 400 stations ne tient pas.
    grille = {}
    for k, ((x, z), w, _) in enumerate(fils):
        for gx in range(int((x - 260) // 100), int((x + 260) // 100) + 1):
            for gz in range(int((z - 260) // 100), int((z + 260) // 100) + 1):
                grille.setdefault((gx, gz), []).append(k)

    def distance(x, z):
        return math.hypot(max(abs(x) - hx, 0), max(abs(z) - hz, 0))

    def bord_riviere(x, z):
        dist = 1e9
        for k in grille.get((int(x // 100), int(z // 100)), ()):
            (px, pz), w, _ = fils[k]
            dist = min(dist, math.hypot(x - px, z - pz) - w)
        return dist

    def massif(x, z):
        return massifs.hauteur(cx + x, cy - z) if massifs is not None else 0.0

    memo = {}

    def altitude(x, z, rive=None):
        cle = (x, z)
        exacte = rive is None
        if exacte and cle in memo:
            return memo[cle]
        if exacte:
            rive = chenal.niveau_rive(cx + x, cy - z)
        berge = bord_riviere(x, z)
        fond = rive - 0.045
        h = -2.4 + (fond + 2.4) * fondu(0, 12, berge) + massif(x, z)
        if exacte and len(memo) < 400000:
            memo[cle] = h
        return h

    def altitude_loin(x, z):
        """Pour les semis : la rive (±1 m) lue sur une ligne tous les 5 m,
        sans quoi chaque arbre refait une coupe de la rivière."""
        return altitude(x, z, chenal.niveau_rive(cx + x, cy - round(z / 5.0) * 5.0))

    def pente(x, z, alt=altitude):
        gx = alt(x + 8, z) - alt(x - 8, z)
        gz = alt(x, z + 8) - alt(x, z - 8)
        return math.hypot(gx, gz) / 16.0

    teintes = {g: PAL.vers_lineaire(c) for g, c in PAL.DECOR.items()}

    def foret_dessin(x, z):
        """Le couvert de la plaque, lu au point du bord le plus proche."""
        if dessin is None:
            return 1.0
        bx, bz = max(-hx + 1, min(hx - 1, x)), max(-hz + 1, min(hz - 1, z))
        return dessin.foret(cx + bx, cy - bz)

    def bord(x, z):
        """0 contre le dessin, 1 au-delà, en festons — et nul AU bord, sinon
        le bruit y ouvre une marche droite le long du rectangle."""
        return fondu(0, 420, distance(x, z) * (0.45 + 1.1 * bruit(x / 170, z / 170, GRAINE + 42)))

    def couvert(x, z, h, raide):
        """0 = pré, 1 = forêt. Le fond plat se fauche, la pente se boise, et
        plus haut plus dense : la limite suit le relief et festonne."""
        sauvage = (0.50 * fondu(12, 150, h) + 0.30 * fondu(250, 1300, distance(x, z))
                   + 0.30 * fondu(0.18, 0.45, raide)
                   + 0.55 * (bruit(x / 330, z / 330, GRAINE + 40) - 0.5)
                   + 0.25 * (bruit(x / 110, z / 110, GRAINE + 41) - 0.5))
        return fondu(0.24, 0.42, sauvage)

    def sol_dessin(f):
        return tuple(a + (b - a) * f for a, b in zip(teintes["pre"], teintes["bois"]))

    def couleur(x, z, sommet=None):
        if sommet is None:
            return sol_dessin(foret_dessin(x, z))
        x, z = sommet
        h = altitude(x, z)
        raide = pente(x, z)
        f = couvert(x, z, h, raide)
        prairie = tuple(a + (b - a) * fondu(40, 260, h)
                        for a, b in zip(teintes["pre"], teintes["relief"]))
        c = tuple(a + (b - a) * f for a, b in zip(prairie, teintes["bois"]))
        melange = [
            (teintes["relief"], f * fondu(0.02, -0.04, clairiere(x, z))),
            (teintes["alpage"], fondu(-30, 45, h - limite_arbres(x, z))),
            (teintes["roche"], max(fondu(0.80, 1.10, raide), 0.55 * fondu(520, 640, h))),
        ]
        for teinte, k in melange:
            c = tuple(a * (1 - k) + b * k for a, b in zip(c, teinte))
        k = bord(x, z)
        if k >= 1:
            return c
        return tuple(a * (1 - k) + b * k for a, b in zip(sol_dessin(foret_dessin(x, z)), c))

    sol, eau = Maillage(), Maillage()

    def axe(a, b):
        # 🔴 Une grille COMMUNE aux quatre bandes, bords de carte compris : deux
        # bandes débitées chacune à son pas ne partagent pas leurs sommets, et
        # le versant se fendait le long de x = ±hx.
        fixes = {a, b} | {v for v in (-hx, hx, -hz, hz) if a < v < b}
        pas = [k * PAS for k in range(math.ceil(a / PAS), math.floor(b / PAS) + 1)
               if a < k * PAS < b and all(abs(k * PAS - f) > 8.0 for f in fixes)]
        return sorted(fixes | set(pas))

    def point(x, z):
        return (x, altitude(x, z), z)

    boites = [(min(p[0] for p in c), min(p[1] for p in c),
               max(p[0] for p in c), max(p[1] for p in c)) for c in canaux]
    index_canaux = {}
    for k, (xa, za, xb, zb) in enumerate(boites):
        for gx in range(int(xa // 100), int(xb // 100) + 1):
            for gz in range(int(za // 100), int(zb // 100) + 1):
                index_canaux.setdefault((gx, gz), []).append(k)

    def bande(x0, x1, z0, z1):
        from .geometrie import D4C, dedans, _coupe_boite
        zs, xs = axe(z0, z1), axe(x0, x1)
        for za, zb in zip(zs, zs[1:]):
            for xa, xb in zip(xs, xs[1:]):
                vus = {k for gx in range(int(xa // 100), int(xb // 100) + 1)
                       for gz in range(int(za // 100), int(zb // 100) + 1)
                       for k in index_canaux.get((gx, gz), ())}
                proches = [canaux[k] for k in vus if boites[k][0] <= xb and boites[k][2] >= xa
                           and boites[k][1] <= zb and boites[k][3] >= za]
                pieces = [[(xa, za), (xb, za), (xb, zb), (xa, zb)]]
                for canal in proches:
                    # Les deux rives seulement : une coupe en travers du cours
                    # se prolonge à travers la maille et fend le versant.
                    for a, b in (canal[1:3], (canal[3], canal[0])):
                        if _coupe_boite((a, b), xa, za, xb, zb):
                            pieces = [p for mo in pieces for p in D4C.couper(mo, a, (b[1]-a[1], a[0]-b[0]))]
                pt = point
                if len(pieces) > 1:
                    # 🔴 Un sommet de coupe sur le bord de la maille n'existe pas
                    # chez la voisine : pris à l'altitude exacte il ouvre une
                    # fente. Hors de la rive, il suit donc le plan des coins.
                    h = [altitude(xa, za), altitude(xb, za), altitude(xa, zb), altitude(xb, zb)]

                    def pt(x, z, h=h, xa=xa, xb=xb, za=za, zb=zb):
                        if bord_riviere(x, z) < 3:
                            return point(x, z)
                        u, v = (x - xa) / (xb - xa), (z - za) / (zb - za)
                        return (x, (h[0] * (1 - u) + h[1] * u) * (1 - v)
                                + (h[2] * (1 - u) + h[3] * u) * v, z)
                for mo in pieces:
                    centre = (sum(p[0] for p in mo)/len(mo), sum(p[1] for p in mo)/len(mo))
                    if any(dedans(c + c[:1], centre) for c in proches):
                        continue
                    for k in range(1, len(mo)-1):
                        a, b, c = mo[0], mo[k+1], mo[k]
                        sol.triangle(pt(*a), pt(*b), pt(*c), None, couleurs=[
                            couleur(*centre, sommet=a), couleur(*centre, sommet=b),
                            couleur(*centre, sommet=c)])

    bande(-PORTEE, -hx, -PORTEE, PORTEE)
    bande(hx, PORTEE, -PORTEE, PORTEE)
    bande(-hx, hx, -PORTEE, -hz)
    bande(-hx, hx, hz, PORTEE)
    # La nappe en quatre bandes par station : UV et UV2 comme dans la ville
    # (distance à la rive + 1, sens de l'aval), le même shader les lit.
    coul_eau = PAL.vers_lineaire("#68adb3")
    for (c0, w0, f0), (c1, w1, f1) in zip(fils, fils[1:]):
        if math.dist(c0, c1) > PAS_FIL * 1.5:
            continue                                   # d'une sortie à l'autre
        n0 = (f0[1], -f0[0])
        n1 = (f1[1], -f1[0])
        cran = (-1.0, -0.5, 0.0, 0.5, 1.0)
        for sa, sb in zip(cran, cran[1:]):
            pts = []
            for (cx0, cz0), w, n, s_ in ((c0, w0, n0, sa), (c0, w0, n0, sb),
                                         (c1, w1, n1, sb), (c1, w1, n1, sa)):
                pts.append(((cx0 + n[0] * w * s_, -2.0, cz0 + n[1] * w * s_),
                            (round((1 - abs(s_)) * w + 1, 2), 0.0)))
            sens = [f0, f0, f1, f1]
            (pa, ua), (pb, ub), (pc, uc), (pd, ud) = pts
            # Face vers le haut : l'ordre se vérifie sur la normale.
            if normale(pa, pb, pc)[1] > 0:
                eau.triangle(pa, pb, pc, coul_eau, facade=[ua, ub, uc], uv2s=sens[:3])
                eau.triangle(pa, pc, pd, coul_eau, facade=[ua, uc, ud], uv2s=[sens[0], sens[2], sens[3]])
            else:
                eau.triangle(pa, pc, pb, coul_eau, facade=[ua, uc, ub], uv2s=[sens[0], sens[2], sens[1]])
                eau.triangle(pa, pd, pc, coul_eau, facade=[ua, ud, uc], uv2s=[sens[0], sens[3], sens[2]])
    # Normales continues, lues à l'échelle de la maille (±20 m) : lues à ±1 m,
    # la crête plus fine que 65 m éclairait chaque facette à part, en cristaux
    # sous la neige. La rive garde ±1 m, sa marche fait 12 m.
    for k, (x, _, z) in enumerate(sol.v):
        e = 1.0 if bord_riviere(x, z) < 40 else 20.0
        nx = altitude(x - e, z) - altitude(x + e, z)
        nz = altitude(x, z - e) - altitude(x, z + e)
        norme = math.sqrt(nx * nx + 4 * e * e + nz * nz)
        sol.n[k] = (nx / norme, 2 * e / norme, nz / norme)

    # 🌲 La forêt en peuplements : clairières, limite des arbres, pas de semis
    # sur le rocher. Au loin, moins d'arbres mais plus grands — la brume finit
    # le travail. L'essence est choisie plus tard, par `repartir`.
    arbres = [[], []]
    # 19 m de pas : le bois dessiné en porte un pour 260 m², une forêt plus
    # claire dehors se lisait comme un second bord.
    for z0 in range(-3000, 3000, 19):
        for x0 in range(-3000, 3000, 19):
            x, z = x0 + rng.uniform(-9, 9), z0 + rng.uniform(-9, 9)
            tirage = rng.random()
            echelle = rng.uniform(1.15, 1.95)
            lacet = rng.uniform(0, math.tau)
            d = distance(x, z)
            if d <= 0:
                continue
            dens = 0.95 - 0.55 * fondu(700, 1700, d) - 0.17 * fondu(1800, 2700, d)
            if tirage > dens:
                continue
            riv = bord_riviere(x, z)
            if riv < 9:
                continue
            alt = altitude_loin(x, z)
            raide = pente(x, z, altitude_loin)
            f = couvert(x, z, alt, raide)
            f *= 0.08 + 0.92 * fondu(-0.03, 0.03, clairiere(x, z))
            # Hors du bois : bosquets, arbres isolés, et le cordon de la rive.
            bocage = (0.03 + 0.30 * fondu(0.62, 0.80, bruit(x / 70, z / 70, GRAINE + 43))
                      + 0.55 * fondu(60, 25, riv))
            garde = f + (1 - f) * bocage
            k = bord(x, z)
            if k < 1:
                fd = foret_dessin(x, z)
                garde = garde * k + (fd + (1 - fd) * bocage) * (1 - k)
            haut = fondu(-40, 30, alt - limite_arbres(x, z))
            garde *= (1 - 0.94 * haut) * (1 - fondu(0.55, 0.85, raide))
            if tirage > dens * garde:
                continue
            echelle *= (0.8 + 0.2 * f) * (1 + 0.45 * fondu(1600, 2700, d))
            arbres[0].append([round(x, 2), round(alt, 2), round(z, 2),
                              round(echelle, 3), round(lacet, 3)])

    # ☁️ Des bancs en volumes bas, pas des aplats : ils posent une ombre sur
    # le versant, et c'est elle qui dit l'altitude vue d'en haut.
    nuages = []
    for cote in (-1, 1):
        for k in range(12):
            x = cote * (hx + rng.uniform(570, 1450))
            z = -2350 + k * 425 + rng.uniform(-120, 120)
            nuages.append([x, altitude(x, z) + rng.uniform(70, 150), z,
                           rng.uniform(260, 460), rng.uniform(40, 70), rng.random()])
    print("  vallée : %d triangles de sol, %d arbres extérieurs, %d bancs de nuages"
          % (len(sol), sum(map(len, arbres)), len(nuages)))
    return {"demi_emprise": [hx, hz], "sol": sol.json(), "eau": eau.json(),
            "arbres": arbres,
            "nuages": nuages, "nuage": _nuage()}, bord_riviere


def _nuage():
    """Six boules à vingt faces, écrasées : un cumulus de maquette, à plat
    dessous. Taille unité — l'instance donne longueur et épaisseur."""
    m = Maillage()
    t = (1 + 5 ** 0.5) / 2
    ico = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t),
           (0, -1, -t), (0, 1, -t), (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9),
             (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2),
             (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
             (8, 6, 7), (9, 8, 1)]
    boules = [(0.0, 0.0, 0.0, 0.34), (0.28, -0.05, 0.08, 0.26), (-0.30, -0.06, -0.04, 0.25),
              (0.10, 0.10, -0.12, 0.24), (-0.08, 0.02, 0.16, 0.22), (0.44, -0.14, -0.06, 0.16)]
    n0 = math.sqrt(1 + t * t)
    for bx, by, bz, r in boules:
        for f in faces:
            p = [(bx + ico[i][0] / n0 * r, max(by + ico[i][1] / n0 * r * 0.62, -0.12),
                  bz + ico[i][2] / n0 * r * 0.8) for i in f]
            # L'icosaèdre est émis dans le sens trigonométrique vu du dehors.
            m.triangle(p[0], p[2], p[1], (1, 1, 1))
            # Normales rayonnantes : à facettes, le banc sortait en papier froissé.
            for k, q in zip(range(len(m.v) - 3, len(m.v)), m.v[-3:]):
                nx, ny, nz = q[0] - bx, (q[1] - by) / 0.62, (q[2] - bz) / 0.8
                n = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
                m.n[k] = (nx / n, ny / n, nz / n)
    return m.json()
