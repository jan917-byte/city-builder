"""Écrin extérieur de Wehrau : forêt mixte, relief et nuages.

Le rectangle jouable et ses données restent exclus de cette géométrie.
"""
import math
import random

import palette as PAL
from .geometrie import Maillage


PORTEE = 3600.0
PAS = 65.0
GRAINE = 917


def fondu(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def paysage(largeur, profondeur, chenal, cx, cy, massifs=None, dessin=None, sorties=None):
    hx, hz = largeur / 2, profondeur / 2
    rng = random.Random(GRAINE)
    # Les sorties sont les deux bouchons du chenal sur le bord de la carte.
    canaux = []
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
        rails = []
        for k in range(10):
            t = k * 430.0
            virage = 90 * math.sin(t / 620)
            x = (-hx - t if cote == 0 else hx + t) if cote in (0, 2) else mx + virage
            z = (hz + t if cote == 1 else -hz - t) if cote in (1, 3) else mz + virage
            rails.append(((x, z - largeur_eau / 2), (x, z + largeur_eau / 2)) if cote in (0, 2)
                         else ((x - largeur_eau / 2, z), (x + largeur_eau / 2, z)))
        for (a, b), (c, d) in zip(rails, rails[1:]):
            canaux.append([a, b, d, c])

    def distance(x, z):
        return math.hypot(max(abs(x) - hx, 0), max(abs(z) - hz, 0))

    def bord_riviere(x, z):
        dist = 1e9
        for a, b, c, d in canaux:
            px, pz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            qx, qz = (c[0] + d[0]) / 2, (c[1] + d[1]) / 2
            vx, vz = qx - px, qz - pz
            t = max(0, min(1, ((x-px)*vx + (z-pz)*vz) / (vx*vx+vz*vz)))
            dist = min(dist, math.hypot(x-px-t*vx, z-pz-t*vz) - math.dist(a,b)/2)
        return dist

    def massif(x, z):
        if massifs is None:
            return 0.0
        # Le bord du dessin devient un versant continu, jamais un second fond de vallée.
        bx, bz = max(-hx, min(hx, x)), max(-hz, min(hz, z))
        return max(massifs.hauteur(cx + x, cy - z),
                   massifs.hauteur(cx + bx, cy - bz))

    def altitude(x, z):
        d = distance(x, z)
        rive = chenal.niveau_rive(cx + x, cy - z)
        cote = fondu(220, 780, abs(x - 65 * math.sin(z / 520)))
        collines = 0.70 + 0.19 * math.sin(z / 285 + x / 730) + 0.11 * math.cos(z / 131 - x / 270)
        cretes = 420 * math.exp(-((abs(x) - hx - 740 - 160 * math.sin(z / 430)) / 480) ** 2)
        arriere = 270 * fondu(1050, 2100, d)
        relief = (cretes * collines + arriere) * cote * fondu(130, 580, d)
        relief += 13 * fondu(0, 250, d) * (1 + math.sin(x / 155 + z / 210)) * cote
        berge = bord_riviere(x, z)
        fond = rive - 0.045 + relief * fondu(0, 190, berge)
        return -2.4 + (fond + 2.4) * fondu(0, 12, berge) + massif(x, z)

    teintes = {g: PAL.vers_lineaire(c) for g, c in PAL.DECOR.items()}

    def genre(x, z):
        if dessin is None:
            return "bois"
        bx, bz = max(-hx, min(hx, x)), max(-hz, min(hz, z))
        return (dessin.genre((cx + x, cy - z))
                or dessin.genre((cx + bx, cy - bz)) or "bois")

    def couleur(x, z):
        base = teintes[genre(x, z)]
        t = fondu(0, 550, distance(x, z))
        return tuple(c * (1 - t) + f * t for c, f in zip(base, teintes["bois"]))

    sol, eau = Maillage(), Maillage()

    def axe(a, b):
        n = math.ceil((b - a) / PAS)
        return [a + (b - a) * k / n for k in range(n + 1)]

    def point(x, z):
        return (x, altitude(x, z), z)

    def bande(x0, x1, z0, z1):
        from .geometrie import D4C, dedans, _coupe_boite
        zs, xs = axe(z0, z1), axe(x0, x1)
        for za, zb in zip(zs, zs[1:]):
            for xa, xb in zip(xs, xs[1:]):
                proches = [c for c in canaux if min(p[0] for p in c) <= xb
                           and max(p[0] for p in c) >= xa and min(p[1] for p in c) <= zb
                           and max(p[1] for p in c) >= za]
                pieces = [[(xa, za), (xb, za), (xb, zb), (xa, zb)]]
                for canal in proches:
                    for a, b in zip(canal, canal[1:] + canal[:1]):
                        if _coupe_boite((a, b), xa, za, xb, zb):
                            pieces = [p for mo in pieces for p in D4C.couper(mo, a, (b[1]-a[1], a[0]-b[0]))]
                for mo in pieces:
                    centre = (sum(p[0] for p in mo)/len(mo), sum(p[1] for p in mo)/len(mo))
                    if any(dedans(c + c[:1], centre) for c in proches):
                        continue
                    for k in range(1, len(mo)-1):
                        sol.triangle(point(*mo[0]), point(*mo[k+1]), point(*mo[k]), couleur(*centre))

    bande(-PORTEE, -hx, -PORTEE, PORTEE)
    bande(hx, PORTEE, -PORTEE, PORTEE)
    bande(-hx, hx, -PORTEE, -hz)
    bande(-hx, hx, hz, PORTEE)
    from .geometrie import aire_signee
    for canal in canaux:
        if aire_signee(canal) < 0:
            canal = list(reversed(canal))
        for k in (1, 2):
            eau.triangle((canal[0][0], -2, canal[0][1]),
                         (canal[k+1][0], -2, canal[k+1][1]),
                         (canal[k][0], -2, canal[k][1]), PAL.vers_lineaire("#68adb3"))
    # Normales continues : le relief doit lire des versants, pas des facettes.
    for k, (x, _, z) in enumerate(sol.v):
        nx = altitude(x - 1, z) - altitude(x + 1, z)
        nz = altitude(x, z - 1) - altitude(x, z + 1)
        norme = math.sqrt(nx * nx + 4 + nz * nz)
        sol.n[k] = (nx / norme, 2 / norme, nz / norme)

    # Les sorties franchissent aussi la couture du décor et se perdent dans la brume.
    from .sorties import Surface
    from .geometrie import _ruban, _densifier
    surface = Surface([sol])
    routes_m, accotements, axes = Maillage(), Maillage(), []
    for route in (sorties or {}).get("axes", []):
        p = route["points"][-1]
        cote = route["cote"]
        vx, vy = [(-1, 0), (0, -1), (1, 0), (0, 1)][cote]
        precedent = route["points"][-2]
        lateral = max(-.8, min(.8, ((p[0] - precedent[0]) * vy - (p[1] - precedent[1]) * vx)
                              / max(.01, (p[0] - precedent[0]) * vx + (p[1] - precedent[1]) * vy)))
        ligne = [p]
        for t in range(8, 3600, 8):
            ecart = lateral * 120 * (1 - math.exp(-t / 120))
            x, y = p[0] + vx * t + vy * ecart, p[1] + vy * t - vx * ecart
            if max(abs(x - cx), abs(cy - y)) >= PORTEE - 8:
                break
            # L'Ilse peut méandrer hors cadre : la route garde sa rive.
            for _ in range(80):
                if bord_riviere(x - cx, cy - y) > route["largeur_m"] / 2 + 10:
                    break
                essais = [(x + vy * 3, y - vx * 3), (x - vy * 3, y + vx * 3)]
                x, y = max(essais, key=lambda q: bord_riviere(q[0] - cx, cy - q[1]))
            ligne.append((x, y))
        ligne = _densifier(ligne, 3.0)
        def proj(x, y, h):
            x, z = x - cx, cy - y
            return (x, surface.hauteur(x, z, altitude(x, z)) + .16 + h, z)
        large = route["largeur_m"]
        for bande in range(4):
            _ruban(routes_m, ligne, large / 4, PAL.vers_lineaire(PAL.MINERAL), proj, 0,
                   decal=-large / 2 + large / 4 * (bande + .5), bouts=False)
        for cote_acc in (-1, 1):
            _ruban(accotements, ligne, .75, PAL.vers_lineaire("#899571"), proj, -.025,
                   decal=cote_acc * (large / 2 + .375), bouts=False)
        axes.append({"fid": route["fid"], "largeur_m": large,
                     "points": [[p[0] - cx, cy - p[1]] for p in ligne]})

    arbres = [[], []]
    for z0 in range(-1950, 1950, 25):
        for x0 in range(-1950, 1950, 25):
            x, z = x0 + rng.uniform(-12, 12), z0 + rng.uniform(-12, 12)
            d = distance(x, z)
            if d <= 0 or rng.random() > 0.92 - 0.68 * fondu(600, 1600, d):
                continue
            if bord_riviere(x, z) < 22:
                continue
            espece = int(rng.random() < 0.35 + 0.4 * fondu(200, 650, d))
            arbres[espece].append([round(x, 2), round(altitude(x, z), 2), round(z, 2),
                                  round(rng.uniform(1.15, 1.95), 3), round(rng.uniform(0, math.tau), 3)])

    nuages = []
    for cote in (-1, 1):
        for k in range(12):
            x = cote * (hx + rng.uniform(570, 1450))
            z = -2350 + k * 425 + rng.uniform(-120, 120)
            nuages.append([x, altitude(x, z) + rng.uniform(50, 125), z,
                           rng.uniform(430, 760), rng.uniform(110, 180), rng.random()])
    quad = Maillage()
    quad.triangle((-0.5, -0.5, 0), (0.5, -0.5, 0), (0.5, 0.5, 0), (1, 1, 1))
    quad.triangle((-0.5, -0.5, 0), (0.5, 0.5, 0), (-0.5, 0.5, 0), (1, 1, 1))
    print("  vallée : %d triangles de sol, %d arbres extérieurs, %d bancs de nuages"
          % (len(sol), sum(map(len, arbres)), len(nuages)))
    return {"demi_emprise": [hx, hz], "sol": sol.json(), "eau": eau.json(),
            "sorties_exterieures": {"sol": routes_m.json(), "accotements": accotements.json(), "axes": axes},
            "arbres": arbres, "modeles": [_arbre(False), _arbre(True)],
            "nuages": nuages, "quad": quad.json()}


def _arbre(sapin):
    m = Maillage()
    # Silhouettes de fond : 30/40 triangles, sans branches ni ombres projetées.
    anneaux = [(1.5, 1.0), (3.0, 4.5), (8.0, 5.2), (12.5, 0.0)]
    if sapin:
        anneaux = [(0, 0.5), (2, 0.5), (2.1, 4.5), (8, 2.8), (17, 0)]
    for (ya, ra), (yb, rb) in zip(anneaux, anneaux[1:]):
        for k in range(5):
            a, b = k * math.tau / 5, (k + 1) * math.tau / 5
            p, q = (ra * math.cos(a), ya, ra * math.sin(a)), (ra * math.cos(b), ya, ra * math.sin(b))
            r, s = (rb * math.cos(b), yb, rb * math.sin(b)), (rb * math.cos(a), yb, rb * math.sin(a))
            m.triangle(p, s, r, (1, 1, 1))
            m.triangle(p, r, q, (1, 1, 1))
    return m.json()
