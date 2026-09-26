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
    """Crêtes et ravines : un bruit replié en V, trois octaves."""
    somme, amp, f = 0.0, 1.0, 1.0
    for o in range(3):
        n = 1.0 - abs(2.0 * bruit(x * f, z * f, GRAINE + o) - 1.0)
        somme += amp * n * n
        amp *= 0.5
        f *= 2.03
    return somme / 1.75


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


def paysage(largeur, profondeur, chenal, cx, cy, massifs=None, dessin=None):
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
            # L'Ilse coule vers le sud, +z dans Godot, à l'amont comme à l'aval.
            sens = (tx, tz) if tz >= 0 else (-tx, -tz)
            rails.append(((x - tz * w, z + tx * w), (x + tz * w, z - tx * w)))
            fils.append(((x, z), w, sens))
        for (a, b), (c, d) in zip(rails, rails[1:]):
            canaux.append([a, b, d, c])
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
        if massifs is None:
            return 0.0
        # Le bord du dessin devient un versant continu, jamais un second fond de vallée.
        bx, bz = max(-hx, min(hx, x)), max(-hz, min(hz, z))
        return max(massifs.hauteur(cx + x, cy - z),
                   massifs.hauteur(cx + bx, cy - bz))

    memo = {}

    def altitude(x, z, rive=None):
        cle = (x, z)
        exacte = rive is None
        if exacte and cle in memo:
            return memo[cle]
        d = distance(x, z)
        if exacte:
            rive = chenal.niveau_rive(cx + x, cy - z)
        cote = fondu(220, 780, abs(x - 65 * math.sin(z / 520)))
        collines = 0.70 + 0.19 * math.sin(z / 285 + x / 730) + 0.11 * math.cos(z / 131 - x / 270)
        cretes = 420 * math.exp(-((abs(x) - hx - 740 - 160 * math.sin(z / 430)) / 480) ** 2)
        arriere = 270 * fondu(1050, 2100, d)
        relief = (cretes * collines + arriere) * cote * fondu(130, 580, d)
        relief += 13 * fondu(0, 250, d) * (1 + math.sin(x / 155 + z / 210)) * cote
        # Les ravines ne touchent que la montagne : le fond de vallée reste lisse.
        relief += 150 * rides(x / 560, z / 560) * cote * fondu(260, 950, d)
        berge = bord_riviere(x, z)
        fond = rive - 0.045 + relief * fondu(0, 190, berge)
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

    def genre(x, z):
        if dessin is None:
            return "bois"
        bx, bz = max(-hx, min(hx, x)), max(-hz, min(hz, z))
        return (dessin.genre((cx + x, cy - z))
                or dessin.genre((cx + bx, cy - bz)) or "bois")

    def couleur(x, z, sommet=None):
        base = teintes[genre(x, z)]
        t = fondu(0, 550, distance(x, z))
        c = tuple(c * (1 - t) + f * t for c, f in zip(base, teintes["bois"]))
        if sommet is None:
            return c
        # Le genre dessiné se lit au centre de la facette ; chaume, roche et
        # clairière au SOMMET, donc en fondu d'une facette à l'autre — lues au
        # centre, les clairières sortaient en carreaux de 65 m.
        x, z = sommet
        h = altitude(x, z)
        loin = fondu(150, 500, distance(x, z))
        melange = [
            (teintes["relief"], loin * fondu(0.02, -0.04, clairiere(x, z))),
            (teintes["alpage"], loin * fondu(-30, 45, h - limite_arbres(x, z))),
            (teintes["roche"], loin * max(fondu(0.80, 1.10, pente(x, z)),
                                          0.55 * fondu(500, 600, h))),
        ]
        for teinte, k in melange:
            c = tuple(a * (1 - k) + b * k for a, b in zip(c, teinte))
        return c

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
    # Normales continues : le relief doit lire des versants, pas des facettes.
    for k, (x, _, z) in enumerate(sol.v):
        nx = altitude(x - 1, z) - altitude(x + 1, z)
        nz = altitude(x, z - 1) - altitude(x, z + 1)
        norme = math.sqrt(nx * nx + 4 + nz * nz)
        sol.n[k] = (nx / norme, 2 / norme, nz / norme)

    # 🌲 La forêt en peuplements : clairières, limite des arbres, pas de semis
    # sur le rocher. Au loin, moins d'arbres mais plus grands — la brume finit
    # le travail. L'essence est choisie plus tard, par `repartir`.
    arbres = [[], []]
    for z0 in range(-3000, 3000, 26):
        for x0 in range(-3000, 3000, 26):
            x, z = x0 + rng.uniform(-12, 12), z0 + rng.uniform(-12, 12)
            tirage = rng.random()
            echelle = rng.uniform(1.15, 1.95)
            lacet = rng.uniform(0, math.tau)
            d = distance(x, z)
            if d <= 0:
                continue
            dens = 0.92 - 0.55 * fondu(600, 1600, d) - 0.17 * fondu(1800, 2700, d)
            dens *= 0.08 + 0.92 * fondu(-0.03, 0.03, clairiere(x, z))
            if tirage > dens or bord_riviere(x, z) < 9:
                continue
            alt = altitude_loin(x, z)
            haut = fondu(-40, 30, alt - limite_arbres(x, z))
            raide = fondu(0.55, 0.85, pente(x, z, altitude_loin))
            if tirage > dens * (1 - 0.94 * haut) * (1 - raide):
                continue
            echelle *= 1 + 0.45 * fondu(1600, 2700, d)
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
            "arbres": arbres, "modeles": [_arbre("feuillu"), _arbre("sapin"), _arbre("peuplier")],
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


def _arbre(genre):
    m = Maillage()
    # Silhouettes de fond : 30/40 triangles, sans branches ni ombres projetées.
    anneaux = {
        "feuillu": [(1.5, 1.0), (3.0, 4.5), (8.0, 5.2), (12.5, 0.0)],
        "sapin": [(0, 0.5), (2, 0.5), (2.1, 4.5), (8, 2.8), (17, 0)],
        # Le peuplier : une colonne, lisible de loin au bord de l'eau.
        "peuplier": [(0, 0.4), (2.2, 0.4), (2.4, 2.0), (9, 2.7), (16, 1.6), (20, 0)],
    }[genre]
    for (ya, ra), (yb, rb) in zip(anneaux, anneaux[1:]):
        for k in range(5):
            a, b = k * math.tau / 5, (k + 1) * math.tau / 5
            p, q = (ra * math.cos(a), ya, ra * math.sin(a)), (ra * math.cos(b), ya, ra * math.sin(b))
            r, s = (rb * math.cos(b), yb, rb * math.sin(b)), (rb * math.cos(a), yb, rb * math.sin(a))
            m.triangle(p, s, r, (1, 1, 1))
            m.triangle(p, r, q, (1, 1, 1))
    return m.json()
